#!/bin/bash

set -e

mkdir -p /tmp/strategies/keys

for i in {0..4}
do
    cp /tmp/sample-data/keys/*_${i}.* /tmp/strategies/keys
done

cp /test/mobilecoind/strategies/* /tmp/strategies

pushd /tmp/strategies || exit 1

echo "-- Install requirements"
echo ""
pip3 install -r requirements.txt

echo ""
echo "-- Set up proto files"
echo ""
python3 -m grpc_tools.protoc \
    -I"/proto/api" \
    --python_out=. "/proto/api/external.proto"

python3 -m grpc_tools.protoc \
    -I"/proto/api" \
    --python_out=. "/proto/api/blockchain.proto"

python3 -m grpc_tools.protoc \
    -I"/proto/api/proto" \
    -I"/proto/mobilecoind/proto" \
    -I"/proto/consensus/proto" \
    --python_out=. --grpc_python_out=. "/proto/mobilecoind/mobilecoind_api.proto"

echo ""
echo "-- Run test_client.py"
echo ""
python3 test_client.py \
    --key-dir ./keys \
    --mobilecoind-host "mobilecoind" \
    --mobilecoind-port 3229

popd || exit 1
