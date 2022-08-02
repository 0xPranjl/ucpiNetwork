#!/bin/bash

set -euvo pipefail

rm -rf ~/.ucpid/*
rm -rf /opt/ucpi/.sgx_ucpis/*

ucpid config chain-id ucpidev-1
ucpid config keyring-backend test

ucpid init banana --chain-id ucpidev-1

cp ~/node_key.json ~/.ucpid/config/node_key.json
perl -i -pe 's/"stake"/ "uucpi"/g' ~/.ucpid/config/genesis.json

ucpid keys add a
ucpid keys add b
ucpid keys add c
ucpid keys add d

ucpid add-genesis-account "$(ucpid keys show -a a)" 1000000000000000000uucpi

ucpid gentx a 1000000uucpi --chain-id ucpidev-1

ucpid collect-gentxs
ucpid validate-genesis

ucpid init-bootstrap
ucpid validate-genesis

source /opt/sgxsdk/environment && RUST_BACKTRACE=1 ucpid start --rpc.laddr tcp://0.0.0.0:26657 --bootstrap
