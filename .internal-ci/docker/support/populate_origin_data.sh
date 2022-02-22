#!/bin/bash

# populate_origin_data.sh
#
# Generate ledger/data.mdb for development builds
# TODO: Restore ledger/data.mdb for persistent builds.

set -e

is_set()
{
  var_name="${1}"

  if [ -z "${!var_name}" ]; then
    echo "${var_name} is not set."
    exit 1
  fi
}

is_set FOG_AUTHORITY_ROOT_CA_CERT_PATH
is_set FOG_REPORT_URL

mkdir -p sample_data/ledger
mkdir -p sample_data/keys

BIN_PATH=${BIN_PATH:-"target/release"}
REAL_BIN_PATH=$(realpath "${BIN_PATH}")

pushd sample_data || exit 1

"${REAL_BIN_PATH}/sample-keys" --num 1000 \
    --fog-report-url "${FOG_REPORT_URL}" \
    --fog-authority-root "${FOG_AUTHORITY_ROOT_CA_CERT_PATH}"

"${REAL_BIN_PATH}/generate-sample-ledger" --txs 100

# sample-keys --num 500 \
#     --fog-report-url fog://fog.${NETWORK_FROM_BRANCH}.mobilecoin.com \
#     --fog-authority-root /fog-authority-roots/${NETWORK_FROM_BRANCH}_ok_rsa_head.pem \
#     --output-dir ./fog_keys

rm -f ./ledger/lock.mdb

popd || exit 1
