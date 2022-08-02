#!/bin/sh

set -o errexit

CHAINID=$1
GENACCT=$2

if [ -z "$1" ]; then
  echo "Need to input chain id..."
  exit 1
fi

rm -rf ~/.ucpid

# Build genesis file incl account for passed address
coins="10000000000uucpi,100000000000stake"
ucpid init --chain-id $CHAINID $CHAINID
ucpid keys add validator --keyring-backend="test"
ucpid add-genesis-account $(ucpid keys show validator -a --keyring-backend="test") $coins

if [ ! -z "$2" ]; then
  ucpid add-genesis-account $GENACCT $coins
fi

ucpid gentx validator 5000000000uucpi --keyring-backend="test" --chain-id $CHAINID
ucpid collect-gentxs

# Set proper defaults and change ports
sed -i 's#"tcp://127.0.0.1:26657"#"tcp://0.0.0.0:26657"#g' ~/.ucpid/config/config.toml
sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' ~/.ucpid/config/config.toml
sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' ~/.ucpid/config/config.toml
sed -i 's/index_all_keys = false/index_all_keys = true/g' ~/.ucpid/config/config.toml
perl -i -pe 's/"stake"/ "uucpi"/g' ~/.ucpid/config/genesis.json

# Start the ucpid
ucpid start --pruning=nothing --bootstrap