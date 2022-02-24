#!/bin/bash

set -o errexit
set -o pipefail

error_exit()
{
    msg="${1}"

    echo "${msg}" 1>&2
    exit 1
}

echo_exit()
{
    msg="${1}"

    echo "${msg}"
    exit 0
}

is_set()
{
    var_name="${1}"

    if [ -z "${!var_name}" ]; then
        error_exit "${var_name} is not set."
    fi
}

rancher_get_kubeconfig()
{
    is_set INPUT_RANCHER_URL
    is_set INPUT_RANCHER_TOKEN
    is_set INPUT_RANCHER_CLUSTER

    echo "-- Get kubeconfig for ${INPUT_RANCHER_CLUSTER} ${INPUT_RANCHER_URL}"
    auth_header="Authorization: Bearer ${INPUT_RANCHER_TOKEN}"
    kubeconfig_url=$(curl -sSLf -H "${auth_header}" "${INPUT_RANCHER_URL}/v3/clusters/?name=${INPUT_RANCHER_CLUSTER}" | jq -r .data[0].actions.generateKubeconfig)

    echo "-- Write kubeconfig to default location"
    mkdir -p ~/.kube
    curl -sSLf -H "${auth_header}" -X POST "${kubeconfig_url}" | jq -r .config > ~/.kube/config
}

echo "Installed Plugins"
helm plugin list

if [ -n "${INPUT_ACTION}" ]
then
    case "${INPUT_ACTION}" in
        s3-publish)
            is_set INPUT_CHART_APP_VERSION
            is_set INPUT_CHART_PATH
            is_set INPUT_CHART_VERSION
            is_set INPUT_AWS_ACCESS_KEY_ID
            is_set INPUT_AWS_DEFAULT_REGION
            is_set INPUT_AWS_SECRET_ACCESS_KEY
            is_set INPUT_CHART_REPO

            # Convert input to AWS env vars.
            export AWS_ACCESS_KEY_ID="${INPUT_AWS_ACCESS_KEY_ID}"
            export AWS_DEFAULT_REGION="${INPUT_AWS_DEFAULT_REGION}"
            export AWS_SECRET_ACCESS_KEY="${INPUT_AWS_SECRET_ACCESS_KEY}"

            if [ "${INPUT_CHART_SIGN}" == "true" ]
            then
                is_set INPUT_CHART_PGP_KEYRING_PATH
                is_set INPUT_CHART_PGP_KEY_NAME
            fi

            echo "-- Create chart tmp dir - .tmp/charts"
            mkdir -p ".tmp/charts"

            echo "-- Updating chart dependencies"
            helm dependency update "${INPUT_CHART_PATH}"

            if [ "${INPUT_CHART_SIGN}" == "true" ]
            then
                echo "-- Package and sign chart with provided pgp key"
                helm package "${INPUT_CHART_PATH}" \
                    -d ".tmp/charts" \
                    --app-version="${CHART_APP_VERSION}" \
                    --version="${INPUT_CHART_VERSION}" \
                    --sign \
                    --keyring="${INPUT_CHART_PGP_KEYRING_PATH}" \
                    --key="${INPUT_CHART_PGP_KEY}"
            else 
                echo "-- Package unsigned chart"
                helm package "${INPUT_CHART_PATH}" \
                    -d ".tmp/charts" \
                    --app-version="${INPUT_CHART_APP_VERSION}" \
                    --version="${INPUT_CHART_VERSION}"
            fi

            echo "-- Add chart repo ${INPUT_CHART_REPO}"
            helm repo add repo "${INPUT_CHART_REPO}"

            echo "-- Push chart"
            chart_name=$(basename "${INPUT_CHART_PATH}")
            helm s3 push --relative --force ".tmp/charts/${chart_name}-${INPUT_CHART_VERSION}.tgz" repo
            ;;

        rancher-namespace-delete)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE

            echo "-- Deleting ${INPUT_NAMESPACE} namespace from ${INPUT_RANCHER_CLUSTER}"
            kubectl delete ns "${INPUT_NAMESPACE}" --now --wait --request-timeout=5m --ignore-not-found
            ;;

        rancher-namespace-create)
            # Create a namespace in the default project so we get all the default configs and secrets
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_RANCHER_PROJECT

            echo "-- Create namespace ${INPUT_NAMESPACE}"
            # Don't sweat it if the namespace already exists.
            kubectl create ns "${INPUT_NAMESPACE}" || echo "Namespace already exists"

            auth_header="Authorization: Bearer ${INPUT_RANCHER_TOKEN}"

            # Add namespace to Default project
            # Get cluster data and resource links
            echo "-- Query Rancher for cluster info"
            cluster=$(curl -sSLf -H "${auth_header}" "${INPUT_RANCHER_URL}/v3/clusters/?name=${INPUT_RANCHER_CLUSTER}") 

            namespaces_url=$(echo "${cluster}" | jq -r .data[0].links.namespaces)
            projects_url=$(echo "${cluster}" | jq -r .data[0].links.projects)

            # Get Default project id
            echo "-- Query Rancher for Default project id"
            default_project=$(curl -sSLf -H "${auth_header}" "${projects_url}?name=Default")
            default_project_id=$(echo "${default_project}" | jq -r .data[0].id)

            # Add namespace to Default project
            echo "-- Add ${INPUT_NAMESPACE} to Default project ${default_project_id}"
            curl -sSLf -H "${auth_header}" \
                -H 'Accept: application/json' \
                -H 'Content-Type: application/json' \
                -X POST "${namespaces_url}/${INPUT_NAMESPACE}?action=move" \
                -d "{\"projectId\":\"${default_project_id}\"}"
            ;;
        rancher-delete-release)
            # Delete a helm release
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_RELEASE_NAME

            kubectl get ns "${INPUT_NAMESPACE}" || echo_exit "Namespace doesn't exist"

            echo "-- Get release list"
            releases=$(helm list -q -n "${INPUT_NAMESPACE}")
            if [[ "${releases}" =~ /^${INPUT_RELEASE_NAME}$/ ]]
            then
                echo "-- Deleting release ${INPUT_RELEASE_NAME}"
                helm delete "${INPUT_RELEASE_NAME}" -n "${INPUT_NAMESPACE}"
            else
                echo "-- Release not found"
            fi
            ;;
        rancher-delete-pvcs)
            echo "delete some pvcs"
            ;;
        rancher-helm-deploy)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_RELEASE_NAME
            is_set INPUT_CHART_VERSION
            is_set INPUT_CHART_NAME

            echo "-- Add chart repo ${INPUT_CHART_REPO}"
            helm repo add repo "${INPUT_CHART_REPO}"
            helm repo update

            if [ -n "${INPUT_CHART_VALUES}" ]
            then
                echo "-- deploy ${INPUT_CHART_NAME} with values."
                helm upgrade "${INPUT_RELEASE_NAME}" "repo/${INPUT_CHART_NAME}" \
                -i --wait --timeout=20m \
                -f "${INPUT_CHART_VALUES}" \
                --namespace "${INPUT_NAMESPACE}" \
                --version "${INPUT_CHART_VERSION}" ${INPUT_CHART_SET}
            else
                echo "-- deploy ${INPUT_CHART_NAME}"
                helm upgrade "${INPUT_RELEASE_NAME}" "repo/${INPUT_CHART_NAME}" \
                -i --wait --timeout=20m \
                --namespace "${INPUT_NAMESPACE}" \
                --version "${INPUT_CHART_VERSION}" ${INPUT_CHART_SET}
            fi
            ;;
        *)
            error_exit "Command ${INPUT_ACTION} not recognized"
            ;;
    esac
else
    # Run arbitrary commands
    exec "$@"
fi
