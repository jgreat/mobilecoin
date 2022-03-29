#!/bin/bash

cat << EOF
--- Namespace ---

${NAMESPACE}

--- Version ---

--- Consensus Endpoints ---

node1.${NAMESPACE}.development.mobilecoin.com
node2.${NAMESPACE}.development.mobilecoin.com
node3.${NAMESPACE}.development.mobilecoin.com
node4.${NAMESPACE}.development.mobilecoin.com
node5.${NAMESPACE}.development.mobilecoin.com

--- Consensus S3 Buckets ---

https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node1.${NAMESPACE}.development.mobilecoin.com/
https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node2.${NAMESPACE}.development.mobilecoin.com/
https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node3.${NAMESPACE}.development.mobilecoin.com/
https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node4.${NAMESPACE}.development.mobilecoin.com/
https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node5.${NAMESPACE}.development.mobilecoin.com/

--- Fog Endpoint ---

fog.${NAMESPACE}.development.mobilecoin.com

--- mobilecoind ---

Connect to mobilecoind API with K8s port forwarding

kubectl -n ${NAMESPACE} port-forward service/mobilecoind 3229:3229

Connect to http://localhost:3229

--- mobilecoind config options ---

--peer mc://node1.release-1-2-0-ci-3.development.mobilecoin.com:443/ \
--tx-source-url https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node1.release-1-2-0-ci-3.development.mobilecoin.com/ \
--peer mc://node2.release-1-2-0-ci-3.development.mobilecoin.com:443/ \
--tx-source-url https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node2.release-1-2-0-ci-3.development.mobilecoin.com/ \
--peer mc://node3.release-1-2-0-ci-3.development.mobilecoin.com:443/ \
--tx-source-url https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node3.release-1-2-0-ci-3.development.mobilecoin.com/ \
--peer mc://node4.release-1-2-0-ci-3.development.mobilecoin.com:443/ \
--tx-source-url https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node4.release-1-2-0-ci-3.development.mobilecoin.com/ \
--peer mc://node5.release-1-2-0-ci-3.development.mobilecoin.com:443/ \
--tx-source-url https://s3-eu-central-1.amazonaws.com/mobilecoin.eu.development.chain/node5.release-1-2-0-ci-3.development.mobilecoin.com/ \
--poll-interval 1 \
--quorum-set '{ "threshold": 3, "members": [{"args":"node1.release-1-2-0-ci-3.development.mobilecoin.com:443","type":"Node"},{"args":"node2.release-1-2-0-ci-3.development.mobilecoin.com:443","type":"Node"},{"args":"node3.release-1-2-0-ci-3.development.mobilecoin.com:443","type":"Node"},{"args":"node4.release-1-2-0-ci-3.development.mobilecoin.com:443","type":"Node"},{"args":"node5.release-1-2-0-ci-3.development.mobilecoin.com:443","type":"Node"}] }'

--- Get key seeds ---

Seeds for wallets are randomly generated for the environment. You can get the seeds from the secret in the deployment and use sample-keys binary to recreate the keys for testing.

Initial Keys Seed:

kubectl -n ${NAMESPACE} get secrets sample-keys-seeds -ojsonpath='{.data.INITIAL_KEYS_SEED}' | base64 -d

Fog Keys Seed:

kubectl -n ${NAMESPACE} get secrets sample-keys-seeds -ojsonpath='{.data.FOG_KEYS_SEED}' | base64 -d

Regenerate keys to /tmp/sample_keys:

docker run \
--env FOG_REPORT_URL="fog://fog.${NAMESPACE}.development.mobilecoin.com" \
--env FOG_AUTHORITY_ROOT_CA_CERT="\$(cat fog_root_authority_ca_cert.pem)" \
--env FOG_KEYS_SEED="\$(kubectl -n ${NAMESPACE} get secrets sample-keys-seeds -ojsonpath='{.data.FOG_KEYS_SEED}' | base64 -d)" \
--env INITIAL_KEYS_SEED="\$(kubectl -n ${NAMESPACE} get secrets sample-keys-seeds -ojsonpath='{.data.INITIAL_KEYS_SEED}' | base64 -d)" \
-v /tmp/sample_data:/tmp/sample_data \
${DOCKER_ORG}/bootstrap-tools:${PREVIOUS_RELEASE} \
.internal-ci/util/populate_origin_data

--- Charts ---

--- Docker Images ---

Can we do links to the binaries/css files?

EOF