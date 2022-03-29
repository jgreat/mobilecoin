#!/bin/bash

# exit if anything fails.
if [[ ${ENTRYPOINT_DEBUG} == "true" ]]; then
    set -ex
else
    set -e
fi

/usr/bin/go-grpc-gateway \
    -grpc-server-endpoint "${GRPC_SERVER_ENDPOINT}" \
    "${GRPC_INSECURE}" \
    -http-server-listen "${HTTP_SERVER_LISTEN}"

wait -n
