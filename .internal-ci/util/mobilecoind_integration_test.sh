#!/bin/bash

set -e

export GRPC_DEFAULT_SSL_ROOTS_FILE_PATH="/etc/ssl/certs/ca-certificates.crt"

mkdir -p .tmp/strategies/keys

for i in {0..4}
do
    cp sample_data/keys/*_${i}.* .tmp/strategies/keys
done

cp mobilecoind/strategies/* .tmp/strategies

pushd .tmp/strategies || exit 1

echo "-- Install requirements"
echo ""
pip3 install -r requirements.txt

echo ""
echo "-- Set up proto files"
echo ""
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

echo ""
echo "-- Run test_client.py"
echo ""
python3 test_client.py \
    --key-dir ./keys \
    --mobilecoind-host "${MOBILECOIND_HOST}" \
    --mobilecoind-port 443

popd || exit 1
