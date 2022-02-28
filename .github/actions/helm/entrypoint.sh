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
    kubeconfig_url=$(curl --retry 5 -sSLf -H "${auth_header}" "${INPUT_RANCHER_URL}/v3/clusters/?name=${INPUT_RANCHER_CLUSTER}" | jq -r .data[0].actions.generateKubeconfig)

    echo "-- Write kubeconfig to default location"
    mkdir -p ~/.kube
    curl --retry 5 -sSLf -H "${auth_header}" -X POST "${kubeconfig_url}" | jq -r .config > ~/.kube/config
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
            cluster=$(curl --retry 5 -sSLf -H "${auth_header}" "${INPUT_RANCHER_URL}/v3/clusters/?name=${INPUT_RANCHER_CLUSTER}") 

            namespaces_url=$(echo "${cluster}" | jq -r .data[0].links.namespaces)
            projects_url=$(echo "${cluster}" | jq -r .data[0].links.projects)

            # Get Default project id
            echo "-- Query Rancher for Default project id"
            default_project=$(curl --retry 5 -sSLf -H "${auth_header}" "${projects_url}?name=Default")
            default_project_id=$(echo "${default_project}" | jq -r .data[0].id)

            # Add namespace to Default project
            echo "-- Add ${INPUT_NAMESPACE} to Default project ${default_project_id}"
            curl --retry 5 -sSLf -H "${auth_header}" \
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
            for r in ${releases}
            do 
                if [ "${r}" == "${INPUT_RELEASE_NAME}" ]
                then
                    echo "-- Deleting release ${INPUT_RELEASE_NAME}"
                    helm delete "${INPUT_RELEASE_NAME}" -n "${INPUT_NAMESPACE}" --wait --timeout="${INPUT_CHART_WAIT_TIMEOUT}"
                fi
            done
            ;;
        rancher-delete-pvcs)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE

            pvcs=$(kubectl get pvc -n "${INPUT_NAMESPACE}" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
            for p in $pvcs
            do
                echo "-- Delete PVC ${p}"
                kubectl delete pvc "${p}" -n "${INPUT_NAMESPACE}" --now --wait --request-timeout=5m --ignore-not-found
            done
            ;;
        rancher-helm-deploy)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_RELEASE_NAME
            is_set INPUT_CHART_VERSION
            is_set INPUT_CHART_NAME
            is_set INPUT_CHART_WAIT_TIMEOUT

            echo "-- Add chart repo ${INPUT_CHART_REPO}"
            repo_name=$(dd bs=10 count=1 if=/dev/urandom | base64 | tr -d +/=)
            echo "-- Repo random name ${repo_name}"
            helm repo add "${repo_name}" "${INPUT_CHART_REPO}"
            helm repo update

            sets=$(echo -n "${INPUT_CHART_SET}" | tr '\n' ' ')

            if [ -n "${INPUT_CHART_VALUES}" ]
            then
                echo "-- deploy ${INPUT_CHART_NAME} with values."
                helm upgrade "${INPUT_RELEASE_NAME}" "${repo_name}/${INPUT_CHART_NAME}" \
                -i --wait --timeout="${INPUT_CHART_WAIT_TIMEOUT}" \
                -f "${INPUT_CHART_VALUES}" \
                --namespace "${INPUT_NAMESPACE}" \
                --version "${INPUT_CHART_VERSION}" ${sets}
            else
                echo "-- deploy ${INPUT_CHART_NAME}"
                helm upgrade "${INPUT_RELEASE_NAME}" "${repo_name}/${INPUT_CHART_NAME}" \
                -i --wait --timeout="${INPUT_CHART_WAIT_TIMEOUT}" \
                --namespace "${INPUT_NAMESPACE}" \
                --version "${INPUT_CHART_VERSION}" ${sets}
            fi
            ;;
        fog-recovery-migrate)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_INGEST_COLOR

            instance="fog-ingest-${INPUT_INGEST_COLOR}"
            peers=("${instance}-0.${instance}" "${instance}-1.${instance}")

            echo "-- Get toolbox pod"
            toolbox=$(kubectl get pods -n "${INPUT_NAMESPACE}" -l "app.kubernetes.io/instance=${instance}" -l app=toolbox -o=name)

            command="fog-sql-recovery-db-migrations"
            kubectl exec -n "${INPUT_NAMESPACE}" "${toolbox}" -- /bin/bash -c "${command}"
            ;;
        fog-ingest-activate)
            rancher_get_kubeconfig
            is_set INPUT_NAMESPACE
            is_set INPUT_INGEST_COLOR
            
            if [ "${INPUT_INGEST_COLOR}" == "blue" ]
            then
                flipside="green"
            else
                flipside="blue"
            fi

            instance="fog-ingest-${INPUT_INGEST_COLOR}"
            peers=("${instance}-0.${instance}" "${instance}-1.${instance}")

            flipside_instance="fog-ingest-${flipside}"
            flipside_peers=("${flipside_instance}-0.${flipside_instance}" "${flipside_instance}-1.${flipside_instance}")

            echo "-- Primary Peers: ${INPUT_INGEST_COLOR} ${peers[*]}"
            echo "-- Flipside Peers: ${flipside} ${flipside_peers[*]}"

            echo "-- Get toolbox pod"
            toolbox=$(kubectl get pods -n "${INPUT_NAMESPACE}" -l "app.kubernetes.io/instance=${instance}" -l app=toolbox -o=name)

            echo "-- Check for flipside ingest"
            flipside_pods=$(kubectl get pods -n "${INPUT_NAMESPACE}" -l "app.kubernetes.io/instance=${flipside_instance}" -l app=fog-ingest -o=name)

            if [ -n "${flipside_pods}" ]
            then
                echo "-- Looking for Active flipside ingest"
                for p in "${flipside_peers[@]}"
                do
                    command="fog_ingest_client --uri 'insecure-fog-ingest://${p}:3226' get-status 2>/dev/null | jq -r .mode"
                    mode=$(kubectl exec -n "${INPUT_NAMESPACE}" "${toolbox}" -- /bin/bash -c "${command}")

                    if [ "${mode}" == "Active" ]
                    then
                        echo "-- ${p} Active ingest found, retiring."
                        command="fog_ingest_client --uri 'insecure-fog-ingest://${p}:3226' retire 2>/dev/null | jq -r ."
                        mode=$(kubectl exec -n "${INPUT_NAMESPACE}" "${toolbox}" -- /bin/bash -c "${command}")
                    fi
                done
            else
                echo "-- No Active flipside ingest found"
            fi

            echo "-- Check Primary for active ingest"
            for p in "${peers[@]}"
            do
                command="fog_ingest_client --uri 'insecure-fog-ingest://${p}:3226' get-status 2>/dev/null | jq -r .mode"
                mode=$(kubectl exec -n "${INPUT_NAMESPACE}" "${toolbox}" -- /bin/bash -c "${command}")

                if [ "${mode}" == "Active" ]
                then
                    echo "-- Active ingest found, no action needed."
                    exit 0
                fi
            done

            echo "-- No Active Primary ingest found. Activating ingest 0."
            command="fog_ingest_client --uri 'insecure-fog-ingest:${instance}-0.${instance}//:3226' activate 2>/dev/null | jq -r ."
            kubectl exec -n "${INPUT_NAMESPACE}" "${toolbox}" -- /bin/bash -c "${command}"
            ;;
        *)
            error_exit "Command ${INPUT_ACTION} not recognized"
            ;;
    esac
else
    # Run arbitrary commands
    exec "$@"
fi
