#!/bin/bash

set -euv

function wait_for_tx () {
    until (ucpid q tx "$1" &> /dev/null)
    do
        echo "$2"
        sleep 1
    done
}

until (ucpid status 2>&1 | jq -e '(.SyncInfo.latest_block_height | tonumber) > 0' &>/dev/null); do
    echo "Waiting for chain to start..."
    sleep 1
done

sleep 5

# store wasm code on-chain so we could later instantiate it
export STORE_TX_HASH=$(
    yes |
    ucpid tx compute store erc20.wasm --from a --gas 1200000 --gas-prices 0.25uucpi --output json |
    jq -r .txhash
)

wait_for_tx "$STORE_TX_HASH" "Waiting for store to finish on-chain..."

# test storing of wasm code (this doesn't touch sgx yet)
ucpid q tx "$STORE_TX_HASH" --output json |
    jq -e '.logs[].events[].attributes[] | select(.key == "code_id" and .value == "1")'

# init the contract (ocall_init + write_db + canonicalize_address)
# a is a tendermint address (will be used in transfer: https://github.com/CosmWasm/cosmwasm-examples/blob/f2f0568ebc90d812bcfaa0ef5eb1da149a951552/erc20/src/contract.rs#L110)
# ucpi1f395p0gg67mmfd5zcqvpnp9cxnu0hg6rjep44t is just a random address
# balances are set to 108 & 53 at init
INIT_TX_HASH=$(
    yes |
        ucpid tx compute instantiate 1 "{\"decimals\":10,\"initial_balances\":[{\"address\":\"$(ucpid keys show a -a)\",\"amount\":\"108\"},{\"address\":\"ucpi1f395p0gg67mmfd5zcqvpnp9cxnu0hg6rjep44t\",\"amount\":\"53\"}],\"name\":\"ReuvenPersonalRustCoin\",\"symbol\":\"RPRC\"}" --label RPRCCoin --output json --gas-prices 0.25uucpi --from a |
        jq -r .txhash
)

wait_for_tx "$INIT_TX_HASH" "Waiting for instantiate to finish on-chain..."

export CONTRACT_ADDRESS=$(
    ucpid q tx "$INIT_TX_HASH" --output json |
        jq -er '.logs[].events[].attributes[] | select(.key == "contract_address") | .value' |
        head -1
)

# test balances after init (ocall_query + read_db + canonicalize_address)
ucpid q compute query "$CONTRACT_ADDRESS" "{\"balance\":{\"address\":\"$(ucpid keys show a -a)\"}}" --output json |
    jq -e '.balance == "108"'
ucpid q compute query "$CONTRACT_ADDRESS" "{\"balance\":{\"address\":\"ucpi1f395p0gg67mmfd5zcqvpnp9cxnu0hg6rjep44t\"}}" --output json |
    jq -e '.balance == "53"'

# transfer 10 balance (ocall_handle + read_db + write_db + humanize_address + canonicalize_address)
TRANSFER_TX_HASH=$(
    yes |
        ucpid tx compute execute --from a "$CONTRACT_ADDRESS" '{"transfer":{"amount":"10","recipient":"ucpi1f395p0gg67mmfd5zcqvpnp9cxnu0hg6rjep44t"}}' --gas-prices 0.25uucpi --output json 2> /dev/null |
        jq -r .txhash
)

wait_for_tx "$TRANSFER_TX_HASH" "Waiting for transfer to finish on-chain..."

# test balances after transfer (ocall_query + read_db)
ucpid q compute query "$CONTRACT_ADDRESS" "{\"balance\":{\"address\":\"$(ucpid keys show a -a)\"}}" --output json |
    jq -e '.balance == "98"'
ucpid q compute query "$CONTRACT_ADDRESS" "{\"balance\":{\"address\":\"ucpi1f395p0gg67mmfd5zcqvpnp9cxnu0hg6rjep44t\"}}" --output json |
    jq -e '.balance == "63"'

(ucpid q compute query "$CONTRACT_ADDRESS" "{\"balance\":{\"address\":\"ucpi1zzzzzzzzzzzzzzzzzz\"}}" --output json || true) 2>&1 | grep -c 'canonicalize_address errored: invalid checksum'

echo "All is done. Yay!"

