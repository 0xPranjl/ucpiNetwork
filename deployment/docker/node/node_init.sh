#!/usr/bin/env bash
set -euv

# REGISTRATION_SERVICE=
# export RPC_URL="bootstrap:26657"
# export CHAINID="ucpidev-1"
# export PERSISTENT_PEERS="115aa0a629f5d70dd1d464bc7e42799e00f4edae@bootstrap:26656"

# init the node
# rm -rf ~/.ucpi*

# rm -rf ~/.ucpid
file=/root/.ucpid/config/attestation_cert.der
if [ ! -e "$file" ]
then
  rm -rf ~/.ucpid/* || true

  mkdir -p /root/.ucpid/.node
  # ucpid config keyring-backend test
  ucpid config node tcp://"$RPC_URL"
  ucpid config chain-id "$CHAINID"
#  export ucpi_NETWORK_CHAIN_ID=$CHAINID
#  export ucpi_NETWORK_KEYRING_BACKEND=test
  # ucpid init "$(hostname)" --chain-id enigma-testnet || true

  ucpid init "$MONIKER" --chain-id "$CHAINID"

  # cp /tmp/.ucpid/keyring-test /root/.ucpid/ -r

  echo "Initializing chain: $CHAINID with node moniker: $(hostname)"

  sed -i 's/persistent_peers = ""/persistent_peers = "'"$PERSISTENT_PEERS"'"/g' ~/.ucpid/config/config.toml
  echo "Set persistent_peers: $PERSISTENT_PEERS"

  # Open RPC port to all interfaces
  perl -i -pe 's/laddr = .+?26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ~/.ucpid/config/config.toml

  # Open P2P port to all interfaces
  perl -i -pe 's/laddr = .+?26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ~/.ucpid/config/config.toml

  echo "Waiting for bootstrap to start..."
  sleep 10

  ucpid init-enclave

  PUBLIC_KEY=$(ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der 2> /dev/null | cut -c 3- )

  echo "Public key: $(ucpid parse /opt/ucpi/.sgx_ucpis/attestation_cert.der 2> /dev/null | cut -c 3- )"

  cp /opt/ucpi/.sgx_ucpis/attestation_cert.der /root/.ucpid/config/

  openssl base64 -A -in attestation_cert.der -out b64_cert
  # ucpid tx register auth attestation_cert.der --from a --gas-prices 0.25uucpi -y

  curl -G --data-urlencode "cert=$(cat b64_cert)" http://"$REGISTRATION_SERVICE"/register

  sleep 20

  SEED=$(ucpid q register seed "$PUBLIC_KEY"  2> /dev/null | cut -c 3-)
  echo "SEED: $SEED"

  ucpid q register ucpi-network-params 2> /dev/null

  ucpid configure-ucpi node-master-cert.der "$SEED"

  curl http://"$RPC_URL"/genesis | jq -r .result.genesis > /root/.ucpid/config/genesis.json

  echo "Downloaded genesis file from $RPC_URL "

  ucpid validate-genesis

  ucpid config node tcp://localhost:26657

fi
ucpid start
