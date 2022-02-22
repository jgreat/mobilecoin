#!/bin/bash
# This script publishes a helm chart to the designated S3 bucket.

set -e

location=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# shellcheck disable=SC1091 # Shellcheck doesn't like variable source path.
. "${location}/source.sh"

# Make sure variables are set
is_set AWS_ACCESS_KEY_ID
is_set AWS_DEFAULT_REGION
is_set AWS_SECRET_ACCESS_KEY
is_set BUCKET
is_set CHART_APP_VERSION
is_set CHART_PATH
is_set CHART_VERSION

if [ "${CHART_SIGN}" == "true" ]
then
    is_set CHART_PGP_KEYRING_PATH
    is_set CHART_PGP_KEY_NAME
fi

echo "Create chart tmp dir - ${TMPDIR}/charts"
mkdir -p "${TMPDIR}/charts"

if [ "${CHART_SIGN}" == "true" ]
then
    echo "Package and sign chart with provided pgp key"
    helm package "${CHART_PATH}" \
        -d "${TMPDIR}/charts" \
        --app-version="${CHART_APP_VERSION}" \
        --version="${CHART_VERSION}" \
        --sign \
        --keyring="${CHART_PGP_KEYRING_PATH}" \
        --key="${CHART_PGP_KEY}"
else 
    echo "Package unsigned chart"
    helm package "${CHART_PATH}" \
        -d "${TMPDIR}/charts" \
        --app-version="${CHART_APP_VERSION}" \
        --version="${CHART_VERSION}"
fi

echo "Install s3 plugin"
helm plugin install https://github.com/hypnoglow/helm-s3.git

echo "Add chart s3 repo"
helm repo add my-repo "s3://${BUCKET}"

echo "Push chart"
chart_name=$(basename "${CHART_PATH}")
helm s3 push "${TMPDIR}/charts/${chart_name}-${CHART_VERSION}.tgz" my-repo
