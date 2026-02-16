# Unauthority (LOS) — Lattice Of Sovereignty

**A 100% Immutable, Permissionless, and Decentralized Blockchain.**

[![CI](https://github.com/mky-one/unauthority-core/actions/workflows/ci.yml/badge.svg)](https://github.com/mky-one/unauthority-core/actions)
[![Rust](https://img.shields.io/badge/rust-2024--edition-orange)]()
[![License](https://img.shields.io/badge/license-AGPL--3.0-purple)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.9-blue)]()

---

## What is Unauthority?

Unauthority is a post-quantum secure, block-lattice (DAG) blockchain with aBFT consensus that operates **exclusively over the Tor network**. Every validator hosts a `.onion` hidden service — no DNS, no clearnet, no central point of failure.

| Property | Value |
|---|---|
| **Ticker** | LOS |
| **Atomic Unit** | CIL (1 LOS = 10¹¹ CIL) |
| **Total Supply** | 21,936,236 LOS (Fixed, non-inflationary) |
| **Consensus** | aBFT (Asynchronous Byzantine Fault Tolerance) |
| **Structure** | Block-Lattice (DAG) + Global State |
| **Cryptography** | Dilithium5 (Post-Quantum) + SHA-3 |
| **Network** | Tor Hidden Services (.onion) exclusively |
| **Smart Contracts** | WASM via UVM (Unauthority Virtual Machine) |

---

## Why Unauthority?

- **Post-Quantum Secure** — Dilithium5 (NIST standard) resists both classical and quantum attacks
- **Tor-Native** — All traffic over `.onion`. No IP addresses exposed, ever
- **DAG Architecture** — Parallel account processing, no global block contention
- **Fair Distribution** — 96.5% public via Proof-of-Burn, only 3.5% dev allocation
- **Anti-Whale** — Quadratic voting (`√Stake`) prevents stake centralization
- **Integer Math Only** — Zero floating-point in consensus. Fully deterministic across all nodes

---

## Quick Start

### Run a Validator (3 steps)

```bash
# 1. Install Tor
sudo apt install -y tor && sudo systemctl enable --now tor   # Linux
brew install tor && brew services start tor                    # macOS

# 2. Build from source
git clone https://github.com/mky-one/unauthority-core.git
cd unauthority-core && ./install.sh --mainnet

# 3. Run
export LOS_WALLET_PASSWORD='your-strong-password'
./target/release/los-node --port 3030 --data-dir /opt/los-node
```

**That's it.** The node automatically:
- Discovers bootstrap peers from genesis config (4 genesis validators)
- Detects Tor SOCKS5 proxy at `127.0.0.1:9050`
- Generates a Dilithium5 post-quantum wallet on first run
- Connects to the network and begins syncing

For full setup with Tor hidden service, systemd service, and monitoring, see the [Validator Guide](docs/VALIDATOR_GUIDE.md).

### Use the Wallet

Download the Flutter wallet app for macOS, Linux, or Windows from [Releases](https://github.com/mky-one/unauthority-core/releases). The wallet bundles Tor internally — no separate Tor installation required.

---

## Architecture

```
unauthority-core/
├── crates/
│   ├── los-node/         # Validator binary (REST + gRPC + P2P + consensus)
│   ├── los-core/         # Blockchain primitives (Block, Tx, Ledger, Oracle)
│   ├── los-consensus/    # aBFT consensus, checkpointing, slashing
│   ├── los-network/      # Tor transport, P2P encryption, fee scaling
│   ├── los-crypto/       # Dilithium5 keygen, signing, verification
│   ├── los-vm/           # WASM smart contract engine (UVM)
│   ├── los-cli/          # Command-line wallet & node management
│   └── los-sdk/          # SDK for external integrations
├── flutter_wallet/       # Mobile/Desktop user wallet (Flutter + Rust via FRB)
├── flutter_validator/    # Validator dashboard app (Flutter + Rust via FRB)
├── genesis/              # Genesis block generator & configuration
├── examples/contracts/   # Sample WASM smart contracts (DEX, Token, Oracle)
└── tests/                # Integration & E2E test suites
```

See [Architecture Deep Dive](docs/ARCHITECTURE.md) for detailed crate documentation and data flow.

---

## Token Economics

| Allocation | Amount (LOS) | Percentage |
|---|---|---|
| **Public (Proof-of-Burn)** | 21,158,413 | ~96.5% |
| **Dev Treasury** | 773,823 | ~3.5% |
| **Bootstrap Validators (4×1,000)** | 4,000 | ~0.02% |
| **Total** | **21,936,236** | **100%** |

### How to Acquire LOS

LOS tokens are acquired through **Proof-of-Burn**: burn ETH or BTC to a provably unspendable address, and receive LOS proportional to the USD value burned. Burns are verified by multi-validator oracle consensus using pure integer arithmetic.

| Asset | Burn Address |
|---|---|
| ETH | `0x000000000000000000000000000000000000dEaD` |
| BTC | `1BitcoinEaterAddressDontSendf59kuE` |

### Validator Rewards

- **Pool:** 500,000 LOS (non-inflationary, from total supply)
- **Per Epoch:** 5,000 LOS, halving every 48 epochs
- **Formula:** `reward = budget × √(stake) / Σ√(all_stakes)` (integer sqrt only)
- **Eligibility:** Min 1,000 LOS stake, ≥95% uptime

---

## API Overview

The validator node exposes a REST API (35+ endpoints) and a gRPC API.

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/node-info` | Node version, peers, block count |
| GET | `/supply` | Total, circulating, and burned supply |
| GET | `/bal/{address}` | Account balance |
| GET | `/account/{address}` | Full account details + history |
| GET | `/history/{address}` | Transaction history |
| GET | `/validators` | Active validator list with stake info |
| GET | `/consensus` | aBFT consensus status and safety |
| GET | `/peers` | Connected peers + validator endpoints |
| GET | `/block` | Latest block |
| GET | `/blocks/recent` | Recent blocks |
| GET | `/reward-info` | Reward pool & epoch info |
| GET | `/metrics` | Prometheus-compatible metrics |
| POST | `/send` | Send LOS transaction |
| POST | `/burn` | Proof-of-Burn (ETH/BTC → LOS) |
| POST | `/register-validator` | Register as network validator |
| POST | `/deploy-contract` | Deploy WASM smart contract |
| POST | `/call-contract` | Execute smart contract function |

Full documentation with request/response examples: [API Reference](docs/API_REFERENCE.md)

---

## Node Configuration

### CLI Flags

```bash
./target/release/los-node [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `--port <PORT>` | REST API listen port | `3030` |
| `--data-dir <DIR>` | Data storage directory | `node_data/node-{port}/` |
| `--node-id <ID>` | Node identifier for logs | `node-{port}` |
| `--json-log` | JSON log output (for Flutter dashboard) | off |
| `--config <FILE>` | Load config from TOML file | none |

### Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `LOS_WALLET_PASSWORD` | **Mainnet** | — | Wallet encryption password |
| `LOS_ONION_ADDRESS` | No | Auto-read from Tor | Your `.onion` address |
| `LOS_SOCKS5_PROXY` | No | Auto-detect `127.0.0.1:9050` | Tor SOCKS5 proxy address |
| `LOS_BOOTSTRAP_NODES` | No | Auto from genesis config | Comma-separated `host:port` peers |
| `LOS_NODE_ID` | No | `node-{port}` | Node identifier |
| `LOS_BIND_ALL` | No | `0` | Set `1` to bind to `0.0.0.0` |
| `LOS_P2P_PORT` | No | REST+1000 | P2P gossip listen port |
| `LOS_TESTNET_LEVEL` | No | `consensus` | Testnet mode: `functional`/`consensus`/`production` |

### Port Scheme

| Service | Port | Derivation |
|---|---|---|
| REST API | 3030 | `--port` value |
| P2P Gossip | 4030 | REST + 1000 |
| gRPC | 23030 | REST + 20000 |

---

## Documentation

### For Users & Node Operators
| Document | Description |
|---|---|
| [Validator Guide](docs/VALIDATOR_GUIDE.md) | Complete setup: build, Tor, systemd, monitoring, rewards |
| [API Reference](docs/API_REFERENCE.md) | All 35+ REST & gRPC endpoints with examples |
| [Tor Setup](docs/TOR_SETUP.md) | Tor hidden service configuration & troubleshooting |
| [Whitepaper](docs/WHITEPAPER.md) | Technical whitepaper: design, consensus, economics |
| [Architecture](docs/ARCHITECTURE.md) | System design, crate map, data flow diagrams |

### For Developers
| Document | Description |
|---|---|
| [Developer Guide](dev_docs/DEVELOPER_GUIDE.md) | Build, test, contribute, CI pipeline |
| [Crate Reference](dev_docs/CRATE_REFERENCE.md) | Every module in every crate, documented |
| [Consensus Deep Dive](dev_docs/CONSENSUS.md) | aBFT rounds, voting, finalization internals |
| [Smart Contracts](dev_docs/SMART_CONTRACTS.md) | UVM, USP-01 token standard, WASM contracts |
| [Gossip Protocol](dev_docs/GOSSIP_PROTOCOL.md) | P2P message formats, signing, broadcast flow |
| [Genesis Configuration](dev_docs/GENESIS.md) | Genesis format, allocation, tooling |

---

## Build & Test

```bash
# Build (testnet, default)
cargo build --release

# Build (mainnet — strict mode: no faucet, enforced signatures)
cargo build --release -p los-node --features mainnet

# Run all tests (208 tests)
cargo test --release --workspace --all-features

# Run clippy (zero warnings enforced)
cargo clippy --workspace --all-features -- -D warnings

# Run specific crate tests
cargo test --release -p los-core
cargo test --release -p los-consensus
cargo test --release -p los-crypto
```

---

## License

AGPL-3.0 — See [LICENSE](LICENSE)
