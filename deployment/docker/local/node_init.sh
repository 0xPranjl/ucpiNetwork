#!/usr/bin/env bash

set -euvo pipefail

# init the node
# rm -rf ~/.ucpi*
#ucpicli config chain-id enigma-testnet
#ucpicli config output json
#ucpicli config indent true
#ucpicli config trust-node true
#ucpicli config keyring-backend test
# rm -rf ~/.ucpid

mkdir -p /root/.ucpid/.node
ucpid config keyring-backend test
ucpid config node http://bootstrap:26657
ucpid config chain-id enigma-pub-testnet-3

mkdir -p /root/.ucpid/.node

ucpid init "$(hostname)" --chain-id enigma-pub-testnet-3 || true

PERSISTENT_PEERS=115aa0a629f5d70dd1d464bc7e42799e00f4edae@bootstrap:26656

sed -i 's/persistent_peers = ""/persistent_peers = "'$PERSISTENT_PEERS'"/g' ~/.ucpid/config/config.toml
sed -i 's/trust_period = "168h0m0s"/trust_period = "168h"/g' ~/.ucpid/config/config.toml
echo "Set persistent_peers: $PERSISTENT_PEERS"

echo "Waiting for bootstrap to start..."
sleep 20

ucpicli q block 1

cp /tmp/.ucpid/keyring-test /root/.ucpid/ -r

# MASTER_KEY="$(ucpicli q register ucpi-network-params 2> /dev/null | cut -c 3- )"

#echo "Master key: $MASTER_KEY"

ucpid init-enclave --reset

PUBLIC_KEY=$(ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der | cut -c 3- )

echo "Public key: $PUBLIC_KEY"

ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der
cat /opt/ucpi/.sgx_ucpis/attestation_cert.der
tx_hash="$(ucpicli tx register auth /opt/ucpi/.sgx_ucpis/attestation_cert.der -y --from a --gas-prices 0.25uucpi | jq -r '.txhash')"

#ucpicli q tx "$tx_hash"
sleep 15
ucpicli q tx "$tx_hash"

SEED="$(ucpicli q register seed "$PUBLIC_KEY" | cut -c 3-)"
echo "SEED: $SEED"
#exit

ucpicli q register ucpi-network-params

ucpid configure-ucpi node-master-cert.der "$SEED"

cp /tmp/.ucpid/config/genesis.json /root/.ucpid/config/genesis.json

ucpid validate-genesis

RUST_BACKTRACE=1 ucpid start --rpc.laddr tcp://0.0.0.0:26657

# ./wasmi-sgx-test.sh
