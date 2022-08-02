#!/bin/bash

file=~/.ucpid/config/genesis.json
if [ ! -e "$file" ]; then
  # init the node
  rm -rf ~/.ucpid/*
  rm -rf /opt/ucpi/.sgx_ucpis/*

  chain_id=${CHAINID:-supernova-1}

  mkdir -p ./.sgx_ucpis
  ucpid config chain-id "$chain_id"
  ucpid config keyring-backend test

  # export ucpi_NETWORK_CHAIN_ID=ucpidev-1
  # export ucpi_NETWORK_KEYRING_BACKEND=test
  ucpid init banana --chain-id "$chain_id"


  cp ~/node_key.json ~/.ucpid/config/node_key.json
  perl -i -pe 's/"stake"/"uucpi"/g' ~/.ucpid/config/genesis.json
  perl -i -pe 's/"172800000000000"/"90000000000"/g' ~/.ucpid/config/genesis.json # voting period 2 days -> 90 seconds

  ucpid keys add a
  ucpid keys add b
  ucpid keys add c
  ucpid keys add d

  ucpid add-genesis-account "$(ucpid keys show -a a)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpid keys show -a b)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpid keys show -a c)" 1000000000000000000uucpi
#  ucpid add-genesis-account "$(ucpid keys show -a d)" 1000000000000000000uucpi


  ucpid gentx a 1000000uucpi --chain-id "$chain_id"
#  ucpid gentx b 1000000uucpi --keyring-backend test
#  ucpid gentx c 1000000uucpi --keyring-backend test
#  ucpid gentx d 1000000uucpi --keyring-backend test

  ucpid collect-gentxs
  ucpid validate-genesis

#  ucpid init-enclave
  ucpid init-bootstrap
#  cp new_node_seed_exchange_keypair.sealed .sgx_ucpis
  ucpid validate-genesis

  perl -i -pe 's/max_subscription_clients.+/max_subscription_clients = 100/' ~/.ucpid/config/config.toml
  perl -i -pe 's/max_subscriptions_per_client.+/max_subscriptions_per_client = 50/' ~/.ucpid/config/config.toml
fi

lcp --proxyUrl http://localhost:1317 --port 1337 --proxyPartial '' &

# sleep infinity
source /opt/sgxsdk/environment && RUST_BACKTRACE=1 ucpid start --rpc.laddr tcp://0.0.0.0:26657 --bootstrap