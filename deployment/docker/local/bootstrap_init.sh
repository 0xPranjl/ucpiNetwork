#!/bin/bash
set -euo pipefail

file=~/.ucpid/config/genesis.json
if [ ! -e "$file" ]
then
  # init the node
  rm -rf ~/.ucpid/*
  rm -rf ~/.ucpicli/*
  rm -rf ~/.sgx_ucpis/*
  ucpicli config chain-id enigma-pub-testnet-3
  ucpicli config output json
#  ucpicli config indent true
#  ucpicli config trust-node true
  ucpicli config keyring-backend test

  ucpid init banana --chain-id enigma-pub-testnet-3

  cp ~/node_key.json ~/.ucpid/config/node_key.json

  perl -i -pe 's/"stake"/"uucpi"/g' ~/.ucpid/config/genesis.json

  perl -i -pe 's/"1814400s"/"80s"/g' ~/.ucpid/config/genesis.json

  ucpicli keys add a
  ucpicli keys add b
  ucpicli keys add c
  ucpicli keys add d

  ucpid add-genesis-account "$(ucpicli keys show -a a)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpicli keys show -a b)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpicli keys show -a c)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpicli keys show -a d)" 1000000000000000000uucpi


  ucpid gentx a 1000000uucpi --keyring-backend test --chain-id enigma-pub-testnet-3
  # These fail for some reason:
  # ucpid gentx --name b --keyring-backend test --amount 1000000uucpi
  # ucpid gentx --name c --keyring-backend test --amount 1000000uucpi
  # ucpid gentx --name d --keyring-backend test --amount 1000000uucpi

  ucpid collect-gentxs
  ucpid validate-genesis

  ucpid init-bootstrap
  ucpid validate-genesis
fi

# sleep infinity
source /opt/sgxsdk/environment && RUST_BACKTRACE=1 ucpid start --rpc.laddr tcp://0.0.0.0:26657 --bootstrap
