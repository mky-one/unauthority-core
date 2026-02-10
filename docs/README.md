# Unauthority Documentation

All documentation for the Unauthority (UAT) blockchain — v1.0.3-testnet.

## User Guides

| Document | Description |
|----------|-------------|
| [JOIN_TESTNET.md](JOIN_TESTNET.md) | Quick start — download wallet, get testnet UAT, send tokens |
| [INSTALLATION.md](INSTALLATION.md) | Build from source on macOS/Linux/Windows |
| [WALLET_GUIDE.md](WALLET_GUIDE.md) | Complete wallet features: create, send, receive, burn-to-mint |

## Operator Guides

| Document | Description |
|----------|-------------|
| [VALIDATOR_GUIDE.md](VALIDATOR_GUIDE.md) | Run a validator node — setup, staking, monitoring |
| [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) | Deploy 4-node testnet via Docker Compose |
| [TOR_SETUP.md](TOR_SETUP.md) | Configure Tor hidden services for node privacy |

## Technical Reference

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design — crates, block-lattice, aBFT, crypto |
| [API_REFERENCE.md](API_REFERENCE.md) | All 27 REST endpoints + 8 gRPC RPCs |
| [CLI_REFERENCE.md](CLI_REFERENCE.md) | `uat-cli` command reference |
| [WHITEPAPER.md](WHITEPAPER.md) | Full technical whitepaper |

## Configuration Files

| File | Purpose |
|------|---------|
| [`genesis_config.json`](../genesis_config.json) | Mainnet genesis allocation (21,936,236 UAT) |
| [`testnet-genesis/testnet_wallets.json`](../testnet-genesis/testnet_wallets.json) | Testnet wallets with BIP39 seeds |
| [`validator.toml`](../validator.toml) | Validator node configuration template |
| [`docker-compose.yml`](../docker-compose.yml) | 4-node Docker deployment |
| [`testnet-tor-info.json`](../testnet-tor-info.json) | Tor .onion addresses for bootstrap nodes |

## Developer Documentation

Internal audit logs, fix summaries, and implementation notes are in [`dev_docs/`](../dev_docs/).
