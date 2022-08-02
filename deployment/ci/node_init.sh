#!/usr/bin/env bash

set -euvo pipefail

# init the node
# rm -rf ~/.ucpi*
#ucpicli config chain-id enigma-testnet
#ucpicli config output json
#ucpicli config indent true
#ucpicli config trust-node true
#ucpicli config keyring-backend test
rm -rf ~/.ucpid

mkdir -p /root/.ucpid/.node
ucpid config keyring-backend test
ucpid config node tcp://bootstrap:26657
ucpid config chain-id ucpidev-1

ucpid init "$(hostname)" --chain-id ucpidev-1 || true

PERSISTENT_PEERS="115aa0a629f5d70dd1d464bc7e42799e00f4edae@bootstrap:26656"

sed -i 's/persistent_peers = ""/persistent_peers = "'$PERSISTENT_PEERS'"/g' ~/.ucpid/config/config.toml
echo "Set persistent_peers: $PERSISTENT_PEERS"

echo "Waiting for bootstrap to start..."
sleep 20

cp /tmp/.ucpid/keyring-test /root/.ucpid/ -r

ucpid init-enclave

PUBLIC_KEY=$(ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der 2> /dev/null | cut -c 3- )

echo "Public key: $(ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der 2> /dev/null | cut -c 3- )"

ucpid tx register auth /opt/ucpi/.sgx_ucpis/attestation_cert.der -y --from a --gas-prices 0.25uucpi

sleep 10

SEED=$(ucpid q register seed "$PUBLIC_KEY" 2> /dev/null | cut -c 3-)
echo "SEED: $SEED"

ucpid q register ucpi-network-params 2> /dev/null

ucpid configure-ucpi node-master-cert.der "$SEED"

cp /tmp/.ucpid/config/genesis.json /root/.ucpid/config/genesis.json

ucpid validate-genesis

ucpid config node tcp://localhost:26657

RUST_BACKTRACE=1 ucpid start &

./wasmi-sgx-test.sh
