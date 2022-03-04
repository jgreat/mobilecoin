#!/bin/bash
# Entrypoint script to set up testing environment in bootstrap(toolbox) container.

mkdir -p /tmp/sample-data
ln -s /var/lib/mobilecoin/origin_data/ledger /tmp/sample-data/ledger

if [ -f "/sample-data/keys.tar.gz" ]
then
    tar xzf /sample-data/keys.tar.gz -C /tmp/sample-data
fi

if [ -f "/sample-data/fog_keys.tar.gz" ]
then
    tar xzf /sample-data/fog_keys.tar.gz -C /tmp/sample-data
fi

exec "$@"