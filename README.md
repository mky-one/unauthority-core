# Unauthority (LOS) — Lattice Of Sovereignty

**A 100% Immutable, Permissionless, and Decentralized Blockchain.**

[![Build](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Tests](https://img.shields.io/badge/tests-462-blue)]()
[![Rust](https://img.shields.io/badge/rust-2024--edition-orange)]()
[![License](https://img.shields.io/badge/license-AGPL--3.0-purple)]()
[![Version](https://img.shields.io/badge/version-1.0.9-blue)]()

## Overview

Unauthority is a post-quantum secure, block-lattice (DAG) blockchain with aBFT consensus, designed to operate exclusively over the Tor network. Every validator hosts a `.onion` hidden service — no DNS, no clearnet, no central point of failure.

| Property | Value |
|---|---|
| **Ticker** | LOS |
| **Atomic Unit** | CIL (1 LOS = 10¹¹ CIL) |
| **Total Supply** | 21,936,236 LOS (Fixed) |
| **Consensus** | aBFT (Asynchronous Byzantine Fault Tolerance) |
| **Structure** | Block-Lattice (DAG) + Global State |
| **Cryptography** | Dilithium5 (Post-Quantum) + SHA-3 |
| **Network** | Tor Hidden Services (.onion) exclusively |

## Architecture

```
unauthority-core/
├── crates/
│   ├── los-node/         # Main validator binary (REST API + gRPC + P2P gossip)
│   ├── los-core/         # Blockchain primitives (Block, Tx, Ledger, Oracle)
│   ├── los-consensus/    # aBFT consensus, checkpointing, slashing
│   ├── los-network/      # P2P networking, Tor transport, fee scaling
│   ├── los-crypto/       # Dilithium5 key generation, signing, verification
│   ├── los-vm/           # WASM Virtual Machine (smart contracts)
│   └── los-cli/          # Command-line wallet & node management
├── flutter_wallet/       # Mobile/Desktop wallet (Flutter + Rust via FRB)
├── flutter_validator/    # Validator dashboard (Flutter + Rust via FRB)
├── genesis/              # Genesis block generator
├── examples/contracts/   # Sample WASM smart contracts
└── testnet-genesis/      # Testnet wallet configuration
```

## Token Economics

| Allocation | Amount | Percentage |
|---|---|---|
| **Public (Proof-of-Burn)** | 21,258,413 LOS | ~96.9% |
| **Dev Treasury 1** | 428,113 LOS | ~1.95% |
| **Dev Treasury 2** | 245,710 LOS | ~1.12% |
| **Bootstrap Validators (4×1,000)** | 4,000 LOS | ~0.02% |
| **Total** | **21,936,236 LOS** | **100%** |

### Validator Rewards
- **Pool:** 500,000 LOS (Non-inflationary, from total supply)
- **Rate:** 5,000 LOS/epoch, halving every 48 epochs
- **Formula:** `reward_i = budget × √stake_i / Σ√stake_all` (Integer sqrt only)
- **Eligibility:** Min 1,000 LOS stake, ≥95% uptime

### Anti-Whale Protection
- Quadratic Voting: `√Stake` instead of raw stake
- Dynamic Fee Scaling based on network congestion
- Burn rate limits per address

## Quick Start

### Prerequisites
- Rust 1.75+ with `cargo`
- Tor (for mainnet/testnet network connectivity)

### Build
```bash
# Testnet build (default)
cargo build --release

# Mainnet build
cargo build --release -p los-node -p los-cli --features los-core/mainnet
```

### Run a Validator Node
```bash
# Set required environment variables
export LOS_WALLET_PASSWORD='your-secure-password'
export LOS_NODE_ID='my-validator'
export LOS_TESTNET_LEVEL='consensus'  # functional | consensus | production
export LOS_BOOTSTRAP_NODES='peer1.onion:4001,peer2.onion:4001'

# Start the node
./target/release/los-node --port 3030 --data-dir node_data/my-validator
```

### CLI Flags
| Flag | Description | Default |
|---|---|---|
| `--port <PORT>` | REST API port | 3030 |
| `--data-dir <DIR>` | Data storage directory | `node_data/node-{port}/` |
| `--node-id <ID>` | Node identifier | `node-{port}` |
| `--json-log` | Machine-readable JSON output (for Flutter) | off |
| `--config <FILE>` | Load config from TOML file | none |

### Environment Variables
| Variable | Required | Description |
|---|---|---|
| `LOS_WALLET_PASSWORD` | **Mainnet only** | Wallet encryption password |
| `LOS_NODE_ID` | No | Node identifier (default: `node-{port}`) |
| `LOS_BOOTSTRAP_NODES` | No | Comma-separated peer addresses |
| `LOS_TESTNET_LEVEL` | No | `functional`, `consensus` (default), or `production` |
| `LOS_ONION_ADDRESS` | No | This node's .onion address |
| `LOS_SOCKS5_PROXY` | No | Tor SOCKS5 proxy (e.g. `socks5h://127.0.0.1:9050`) |
| `LOS_BIND_ALL` | No | Set `1` to bind to 0.0.0.0 instead of 127.0.0.1 |

### Port Scheme
| Service | Port | Formula |
|---|---|---|
| REST API | 3030 | `--port` value |
| gRPC | 23030 | REST + 20,000 |
| P2P Gossip | 4001 | Via libp2p |

## API Endpoints

The REST API exposes 33+ endpoints. See [docs/API_REFERENCE.md](docs/API_REFERENCE.md) for full documentation.

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Node status & API index |
| GET | `/health` | Health check |
| GET | `/node-info` | Node info (version, block count, peers) |
| GET | `/bal/{address}` | Balance in CIL |
| GET | `/balance/{address}` | Balance in CIL (alias) |
| GET | `/supply` | Total/circulating supply |
| GET | `/history/{address}` | Transaction history |
| GET | `/block` | Latest block |
| GET | `/block/{hash}` | Block by hash |
| GET | `/blocks/recent` | Recent blocks |
| GET | `/transaction/{hash}` | Transaction by hash |
| GET | `/search/{query}` | Search blocks/accounts |
| GET | `/validators` | Active validators list |
| GET | `/consensus` | aBFT consensus status |
| GET | `/reward-info` | Reward pool & epoch info |
| GET | `/slashing` | Slashing status |
| GET | `/slashing/{address}` | Slashing profile for validator |
| GET | `/metrics` | Prometheus metrics |
| GET | `/fee-estimate/{amount}` | Fee estimate |
| GET | `/whoami` | This node's address |
| GET | `/account/{address}` | Full account details |
| GET | `/peers` | Connected peers |
| GET | `/network/peers` | Network peer discovery |
| GET | `/mempool/stats` | Mempool statistics |
| GET | `/sync` | Ledger sync (GZIP compressed) |
| POST | `/send` | Send LOS transaction |
| POST | `/burn` | Proof-of-Burn (ETH/BTC → LOS) |
| POST | `/faucet` | Testnet faucet |
| POST | `/register-validator` | Register as validator |
| POST | `/unregister-validator` | Unregister validator |
| POST | `/deploy-contract` | Deploy WASM contract |
| POST | `/call-contract` | Call WASM contract |
| GET | `/contract/{id}` | Get contract state |
| POST | `/reset-burn-txid` | Reset stuck burn (testnet) |

## Testnet Levels

| Level | Signatures | Consensus | Oracle | Faucet | Use Case |
|---|---|---|---|---|---|
| `functional` | Skipped | Off | Mock prices | On | Single-node dev |
| `consensus` | Validated | On (aBFT) | Mock prices | On | Multi-node testing |
| `production` | Validated | On (aBFT) | Live oracles | Off | Mainnet simulation |

## Documentation

- [API Reference](docs/API_REFERENCE.md) — Full REST & gRPC API documentation
- [Architecture](docs/ARCHITECTURE.md) — System design and crate structure
- [Validator Guide](docs/VALIDATOR_GUIDE.md) — Running a validator node
- [Tor Setup](docs/TOR_SETUP.md) — Tor hidden service configuration
- [Whitepaper](docs/WHITEPAPER.md) — Technical whitepaper

## License

AGPL-3.0 — See [LICENSE](LICENSE)
