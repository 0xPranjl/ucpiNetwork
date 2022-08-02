#!/bin/bash

file=~/.ucpid/config/genesis.json
if [ ! -e "$file" ]
then
  # init the node
  rm -rf ~/.ucpid/*
  rm -rf /opt/ucpi/.sgx_ucpis/*

  chain_id=${CHAINID:-ucpidev-1}

  mkdir -p ./.sgx_ucpis
  ucpid config chain-id "$chain_id"
  ucpid config output json
  ucpid config keyring-backend test

  # export ucpi_NETWORK_CHAIN_ID=ucpidev-1
  # export ucpi_NETWORK_KEYRING_BACKEND=test
  ucpid init banana --chain-id "$chain_id"


  cp ~/node_key.json ~/.ucpid/config/node_key.json
  perl -i -pe 's/"stake"/"uucpi"/g' ~/.ucpid/config/genesis.json
  perl -i -pe 's/"172800s"/"90s"/g' ~/.ucpid/config/genesis.json # voting period 2 days -> 90 seconds
  perl -i -pe 's/"1814400s"/"80s"/g' ~/.ucpid/config/genesis.json # voting period 2 days -> 90 seconds

  perl -i -pe 's/enable-unsafe-cors = false/enable-unsafe-cors = true/g' ~/.ucpid/config/app.toml # enable cors

  a_mnemonic="grant rice replace explain federal release fix clever romance raise often wild taxi quarter soccer fiber love must tape steak together observe swap guitar"
  b_mnemonic="jelly shadow frog dirt dragon use armed praise universe win jungle close inmate rain oil canvas beauty pioneer chef soccer icon dizzy thunder meadow"
  c_mnemonic="chair love bleak wonder skirt permit say assist aunt credit roast size obtain minute throw sand usual age smart exact enough room shadow charge"
  d_mnemonic="word twist toast cloth movie predict advance crumble escape whale sail such angry muffin balcony keen move employ cook valve hurt glimpse breeze brick"
  
  echo $a_mnemonic | ucpid keys add a --recover
  echo $b_mnemonic | ucpid keys add b --recover
  echo $c_mnemonic | ucpid keys add c --recover
  echo $d_mnemonic | ucpid keys add d --recover

  ucpid add-genesis-account "$(ucpid keys show -a a)" 1000000000000000000uucpi
  ucpid add-genesis-account "$(ucpid keys show -a b)" 1000000000000000000uucpi
  ucpid add-genesis-account "$(ucpid keys show -a c)" 1000000000000000000uucpi
  ucpid add-genesis-account "$(ucpid keys show -a d)" 1000000000000000000uucpi


  ucpid gentx a 1000000uucpi --chain-id "$chain_id"
  ucpid gentx b 1000000uucpi --chain-id "$chain_id"
  ucpid gentx c 1000000uucpi --chain-id "$chain_id"
  ucpid gentx d 1000000uucpi --chain-id "$chain_id"

  ucpid collect-gentxs
  ucpid validate-genesis

#  ucpid init-enclave
  ucpid init-bootstrap
#  cp new_node_seed_exchange_keypair.sealed .sgx_ucpis
  ucpid validate-genesis
fi

# Setup CORS for LCD & gRPC-web
perl -i -pe 's;address = "tcp://0.0.0.0:1317";address = "tcp://0.0.0.0:1316";' .ucpid/config/app.toml
perl -i -pe 's/enable-unsafe-cors = false/enable-unsafe-cors = true/' .ucpid/config/app.toml
lcp --proxyUrl http://localhost:1316 --port 1317 --proxyPartial '' &

# Setup faucet
setsid node faucet_server.js &

# Setup ucpicli
cp $(which ucpid) $(dirname $(which ucpid))/ucpicli

source /opt/sgxsdk/environment && RUST_BACKTRACE=1 LOG_LEVEL=INFO ucpid start --rpc.laddr tcp://0.0.0.0:26657 --bootstrap

