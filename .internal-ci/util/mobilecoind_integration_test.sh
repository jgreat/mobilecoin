#!/bin/bash

set -e

mkdir -p .tmp/strategies/keys

ls -al sample_data/keys/

for i in {0..4}
do
    cp "sample_data/keys/*_${i}.*" .tmp/strategies/keys
done

cp mobilecoind/strategies/* .tmp/strategies

pushd .tmp/strategies || exit 1

pip3 install -r requirements.txt

python3 -m grpc_tools.protoc \
    -I"${GITHUB_WORKSPACE}/api/proto" \
    --python_out=. "${GITHUB_WORKSPACE}/api/proto/external.proto"

python3 -m grpc_tools.protoc \
    -I"${GITHUB_WORKSPACE}/api/proto" \
    --python_out=. "${GITHUB_WORKSPACE}/api/proto/blockchain.proto"

python3 -m grpc_tools.protoc \
    -I"${GITHUB_WORKSPACE}/api/proto" \
    -I"${GITHUB_WORKSPACE}/mobilecoind/api/proto" \
    -I"${GITHUB_WORKSPACE}/consensus/api/proto" \
    --python_out=. --grpc_python_out=. "${GITHUB_WORKSPACE}/mobilecoind/api/proto/mobilecoind_api.proto"

python3 test_client.py \
    --key-dir ./keys \
    --mobilecoind-host "${MOBILECOIND_HOST}" \
    --mobilecoind-port 443

popd || exit 1
