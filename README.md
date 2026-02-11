# Unauthority (UAT) — The Sovereign Machine

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![Tests](https://img.shields.io/badge/Tests-226%20Passing-brightgreen.svg)]()
[![CI](https://github.com/unauthoritymky-6236/unauthority-core/actions/workflows/ci.yml/badge.svg)](https://github.com/unauthoritymky-6236/unauthority-core/actions)

A truly decentralized, permissionless blockchain with zero admin keys, instant finality, and post-quantum security.

> **Testnet is LIVE.** Download the apps below and start testing.

---

## Download

Pre-built desktop apps for all platforms. No Tor Browser or command-line needed.

### UAT Wallet (send, receive, burn-to-mint)

| Platform | Download | Install |
|----------|----------|---------|
| macOS | [UAT-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) | Open DMG → drag to Applications |
| Windows | [UAT-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) | Extract → run `flutter_wallet.exe` |
| Linux | [UAT-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) | Extract → run `./run.sh` |

### UAT Validator Dashboard (monitor node, manage keys)

| Platform | Download | Install |
|----------|----------|---------|
| macOS | [UAT-Validator-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) | Open DMG → drag to Applications |
| Windows | [UAT-Validator-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) | Extract → run `flutter_validator.exe` |
| Linux | [UAT-Validator-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) | Extract → run `./run.sh` |

Both apps include **built-in Tor** connectivity and **CRYSTALS-Dilithium5** post-quantum cryptography. No external dependencies required.

> **macOS users:** Apple will block the app on first launch ("cannot verify"). Fix:
> ```bash
> xattr -cr /Applications/UAT\ Wallet.app
> xattr -cr /Applications/flutter_validator.app
> ```
> Or: **System Settings → Privacy & Security → Open Anyway**

---

## What is Unauthority?

Unauthority is a Layer-1 blockchain built from scratch in Rust. It is designed to be **100% immutable** — no admin keys, no pause function, no upgradability. Once deployed, the chain runs autonomously.

### Key Properties

| Property | Detail |
|----------|--------|
| **Total Supply** | 21,936,236 UAT (fixed forever, no inflation) |
| **Smallest Unit** | 1 VOID (1 UAT = 100,000,000,000 VOID) |
| **Consensus** | aBFT — Asynchronous Byzantine Fault Tolerance |
| **Finality** | < 3 seconds |
| **Cryptography** | CRYSTALS-Dilithium5 (post-quantum secure) |
| **Smart Contracts** | WASM via Unauthority Virtual Machine (UVM) |
| **Network Privacy** | All traffic via Tor Hidden Services |
| **Distribution** | 93% public (Proof-of-Burn), 7% dev treasury |
| **Validator Rewards** | Epoch-based (24h), quadratic √stake, halving schedule |

### Anti-Whale Economics

- **Quadratic Voting** — voting power = √(stake), not linear
- **Dynamic Fee Scaling** — fees increase x2/x4/x8 for spam bursts
- **Burn Limits** — max 10 UAT minted per block via Proof-of-Burn
- **Reward Fairness** — validator rewards use √stake, preventing whale dominance

---

## Quick Start

### For Users (Wallet)

1. Download the **UAT Wallet** from the table above
2. Install and open
3. Click **"Create New Wallet"** — save your 24-word seed phrase securely
4. Go to **Faucet** tab → click **"Request UAT"** (5,000 UAT per claim, testnet only)
5. Go to **Send** tab → enter a recipient address and amount → send

The wallet connects to the testnet automatically via Tor.

### For Validators

1. Download the **UAT Validator Dashboard** from the table above
2. To run your own node, see [Validator Guide](docs/VALIDATOR_GUIDE.md)
3. Minimum stake: 1,000 UAT

### Build from Source

```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core

# Build the Rust node
cargo build --release --bin uat-node

# Build the Flutter wallet
cd flutter_wallet && flutter pub get && flutter build macos --release

# Build the Flutter validator dashboard
cd ../flutter_validator && flutter pub get && flutter build macos --release
```

Replace `macos` with `linux` or `windows` as needed.

---

## REST API

Every UAT node exposes these endpoints. Default port: `3030`.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/node-info` | GET | Chain metadata, supply, height, validators |
| `/health` | GET | Node health status |
| `/bal/{address}` | GET | Balance in UAT and VOID |
| `/balance/{address}` | GET | Balance (alias) |
| `/account/{address}` | GET | Account details + recent transactions |
| `/history/{address}` | GET | Full transaction history |
| `/validators` | GET | Active validators with stake amounts |
| `/peers` | GET | Connected P2P peers |
| `/block` | GET | Latest block |
| `/block/{height}` | GET | Block at specific height |
| `/block/{hash}` | GET | Block by hash |
| `/transaction/{hash}` | GET | Transaction by hash |
| `/search/{query}` | GET | Search blocks, transactions, addresses |
| `/blocks/recent` | GET | Last N blocks |
| `/supply` | GET | Total and circulating supply |
| `/metrics` | GET | Prometheus-format metrics |
| `/whoami` | GET | Node's own signing address |
| `/consensus` | GET | aBFT consensus parameters and safety status |
| `/slashing` | GET | Network slashing statistics |
| `/slashing/{address}` | GET | Slashing profile for a validator |
| `/reward-info` | GET | Validator reward pool status, epoch info, per-validator stats |
| `/fee-estimate` | GET | Dynamic fee estimate for transactions |
| `/faucet` | POST | Claim testnet tokens (5,000 UAT, 1hr cooldown) |
| `/send` | POST | Submit signed transaction |
| `/burn` | POST | Submit Proof-of-Burn mint |
| `/deploy-contract` | POST | Deploy WASM smart contract |
| `/call-contract` | POST | Call a deployed contract |

Full API documentation: [docs/API_REFERENCE.md](docs/API_REFERENCE.md)

---

## Architecture

```
unauthority-core/
├── crates/
│   ├── uat-core/          # Blockchain core — ledger, accounts, supply math, validator rewards
│   ├── uat-crypto/        # Post-quantum crypto — Dilithium5, address derivation
│   ├── uat-consensus/     # aBFT consensus — voting, slashing, checkpoints
│   ├── uat-network/       # P2P networking — fee scaling, Tor transport
│   ├── uat-vm/            # Smart contract engine — WASM/wasmer runtime
│   ├── uat-node/          # Full node binary — REST API + gRPC server
│   └── uat-cli/           # Command-line interface
├── flutter_wallet/        # Desktop wallet app (Flutter + Dilithium5 FFI)
├── flutter_validator/     # Desktop validator dashboard (Flutter + Dilithium5 FFI)
├── genesis/               # Genesis block generator
├── testnet-genesis/       # Pre-funded testnet wallets
├── examples/contracts/    # Smart contract examples
├── docs/                  # Documentation
└── dev_docs/              # Internal developer notes
```

Both Flutter apps use native Rust FFI to call Dilithium5 functions compiled per platform (`.dylib` on macOS, `.so` on Linux, `.dll` on Windows).

---

## Genesis Allocation

| Component | UAT | Percentage |
|-----------|-----|-----------|
| **Public Distribution** (Proof-of-Burn) | 20,400,700 | 93% |
| **Dev Treasury** (8 wallets) | 1,535,536 | 7% |
| **Total** | **21,936,236** | **100%** |

A **Validator Reward Pool** of 2,193,623 UAT (~10% of total supply) is reserved within the public distribution for epoch-based validator incentives. This pool uses a halving schedule and does not increase total supply.

Bootstrap validators (4 nodes × 1,000 UAT each) are funded from Treasury Wallet #8.

---

## Security

- **Zero Admin Keys** — no pause, no upgrade, no kill switch
- **Integer-Only Math** — no floating-point anywhere in consensus or supply
- **Automated Slashing** — double-signing = 100% stake burn + permanent ban; downtime = 1%/epoch
- **Sentry Architecture** — public shield nodes + private validator core
- **P2P Encryption** — Noise Protocol Framework
- **Rate Limiting** — 100 req/sec per IP, per-endpoint cooldowns
- **Memory Safety** — `Zeroize` for all private keys in memory

---

## Testing

```bash
cargo test --workspace              # All 240 tests
cargo test -p uat-core              # Core crate (69 tests, incl. reward system)
cargo test -p uat-consensus         # Consensus (43 tests)
cargo test -p uat-crypto            # Cryptography (30 tests)
cargo test -p uat-network           # Network (57 tests)
cargo test -p uat-vm                # Smart contracts / WASM (20 tests)
cargo test -p uat-node              # Node integration (13 tests)
```

CI runs automatically on every push: format check, clippy, full test suite, security audit, release build, integration tests, and VM tests.

---

## Documentation

| Document | For |
|----------|-----|
| [JOIN_TESTNET.md](docs/JOIN_TESTNET.md) | **Quick start for public users** |
| [WALLET_GUIDE.md](docs/WALLET_GUIDE.md) | Complete wallet features guide |
| [INSTALLATION.md](docs/INSTALLATION.md) | Build from source on all platforms |
| [VALIDATOR_GUIDE.md](docs/VALIDATOR_GUIDE.md) | Run a validator node |
| [API_REFERENCE.md](docs/API_REFERENCE.md) | REST & gRPC API docs (27 endpoints) |
| [CLI_REFERENCE.md](docs/CLI_REFERENCE.md) | `uat-cli` command reference |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical architecture & diagrams |
| [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) | Docker Compose deployment |
| [TOR_SETUP.md](docs/TOR_SETUP.md) | Tor hidden service setup |
| [WHITEPAPER.md](docs/WHITEPAPER.md) | Full technical whitepaper |

---

## License

MIT — see [LICENSE](LICENSE)

---

Built with Rust | Powered by aBFT | Secured by Dilithium5
