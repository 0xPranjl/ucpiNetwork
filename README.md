![Secret Network](/logo.png)

<p align="center">
Secret Network secures the decentralized web
</p>

# What is Secret Network?

For better background, before reading this guide you might want to check out Cosmos' guide upgrading from `cosmoshub-2` to `cosmoshub-3`.

Secret Network is a blockchain-based, open-source protocol that lets anyone perform computations on encrypted data, bringing privacy to smart contracts and public blockchains. Our mission: improve the adoption and usability of decentralized technologies, for the benefit of all.

Mainnet is out! Get the latest release at https://github.com/enigmampc/SecretNetwork/releases/latest.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0) [![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

2. Inside `new_genesis.json` Rename `chain_id` from `enigma-1` to the new agreed upon Chain ID.

- Homepage: https://scrt.network
- Forum: https://forum.scrt.network
- Discord: https://discord.com/invite/SJK32GY
- Blog: https://blog.scrt.network
- Twitter: https://twitter.com/SecretNetwork
- Main Chat: https://chat.scrt.network/channel/general
- Telegram Channel: https://t.me/SCRTnetwork
- Community Secret Nodes Telegram: https://t.me/secretnodes

4. Compile the new `scrt` binaries with `make deb` (or distribute them precompiled).

Secret Network is secured by the SCRT coin (Secret), which is used for fees, staking, and governance. Transactions, validators, governance proposals, and more can be viewed using the following Secret Network block explorers:

- [Cashmaney](https://explorer.cashmaney.com)
- [SecretScan](https://secretscan.io)
- [Puzzle](https://puzzle-staging.secretnodes.org/enigma/chains/enigma-1)

# Wallets

- [Ledger Nano S and Ledger Nano X](/docs/ledger-nano-s.md)
- [Math Wallet](https://mathwallet.org/web/enigma)

   ```bash
   sudo dpkg -i precompiled_scrt_package.deb # install scrtd & scrtcli and setup scrt-node.service

- [An Update on the Encryption Protocol](https://forum.enigma.co/t/an-update-on-the-encryption-protocol/1641)
- [Hard Forks and Network Upgrades](https://forum.enigma.co/t/hard-forks-and-network-upgrades/1670)
- [Don’t trust, verify (an untrusted host)](https://forum.scrt.network/t/dont-trust-verify-an-untrusted-host/1669)
- [Secret Contracts on Secret Network](https://forum.enigma.co/t/secret-contracts-on-enigma-blockchain/1284)
- [Network key management/agreement](https://forum.enigma.co/t/network-key-management-agreement/1324)
- [Input/Output/State Encryption/Decryption protocol](https://forum.enigma.co/t/input-output-state-encryption-decryption-protocol/1325)
- [Why the Cosmos move doesn’t mean we’re leaving Ethereum](https://forum.enigma.co/t/why-the-cosmos-move-doesnt-mean-were-leaving-ethereum/1301)
- [(Dev discussion/Issue) WASM implementation](https://forum.enigma.co/t/dev-discussion-issue-wasm-implementation/1303)

6. Setup the new node/validaor:

- https://api.chainofsecrets.org

   # import old config files to the new node
   cp ~/.enigmad/config/{app.toml,config.toml,addrbook.json} ~/.scrtd/config

   # import node's & validator's private keys to the new node
   cp ~/.enigmad/config/{priv_validator_key.json,node_key.json} ~/.scrtd/config

   # set new_genesis.json from step 3 as the genesis.json of the new chain
   cp new_genesis.json ~/.scrtd/config/genesis.json

- [For Blockchain developers](/docs/dev/for-enigma-blockchain-devs.md)
- [How to be a mainnet genesis validator](/docs/genesis/genesis-validator-mainnet.md)

# License

SecretNetwork is free software: you can redistribute it and/or modify it under the terms of the [GNU Affero General Public License](LICENSE) as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. The GNU Affero General Public License is based on the GNU GPL, but has an additional term to allow users who interact with the licensed software over a network to receive the source for that program.
