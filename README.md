# 🔗 Unauthority (UAT) - The Sovereign Machine

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)]()

**A truly decentralized, permissionless blockchain with zero admin keys, instant finality, and post-quantum security.**

---

## 🎯 Key Features

- **100% Immutable** - No admin keys, no pause function, no upgradability
- **< 3 Second Finality** - Asynchronous Byzantine Fault Tolerance (aBFT)
- **Post-Quantum Ready** - CRYSTALS-Dilithium signature support
- **Fixed Supply** - 21,936,236 UAT (no inflation, ever)
- **Proof-of-Burn Distribution** - 93% public allocation via BTC/ETH burning
- **Smart Contracts** - WASM-based Unauthority Virtual Machine (UVM)
- **Anti-Whale Economics** - Quadratic voting + dynamic fee scaling

---

## 📊 Quick Stats

| Metric | Value |
|--------|-------|
| **Total Supply** | 21,936,236 UAT (fixed) |
| **Dev Allocation** | 7% (1,535,536 UAT) |
| **Public Distribution** | 93% (20,400,700 UAT via PoB) |
| **Consensus** | aBFT with slashing |
| **Block Time** | ~1 second |
| **Finality** | < 3 seconds |
| **Min Validator Stake** | 1,000 UAT |

---

## 🚀 Quick Start

### For Users (Public Wallet)

```bash
# Download desktop app from GitHub Releases
# macOS: Unauthority-Wallet.dmg
# Windows: Unauthority-Wallet-Setup.exe
# Linux: Unauthority-Wallet.AppImage

# Or run from source:
cd frontend-wallet
npm install
npm run dev
```

### For Validators

```bash
# 1. Build backend
cargo build --release --bin uat-node

# 2. Generate genesis (bootstrap nodes only)
cd genesis && cargo run --release

# 3. Start validator
./start.sh

# 4. Open dashboard
cd frontend-validator
npm install && npm run dev
# Visit: http://localhost:5173
```

# Terminal 2
source node_data/validator-2/.env && cargo run -p uat-node -- --config node_data/validator-2/validator.toml

# Terminal 3
source node_data/validator-3/.env && cargo run -p uat-node -- --config node_data/validator-3/validator.toml
```

---

## 📊 Genesis Allocation (11 Wallets)

### Dev/Treasury Wallets (8 total)
| Wallet | Balance | Type |
|--------|---------|------|
| Dev #1-7 | 191,942 UAT each | Treasury |
| Dev #8 | 188,942 UAT | Treasury (reduced) |
| **Dev Total** | **1,343,594 + 188,942** | **1,532,536 UAT** |

### Bootstrap Validator Nodes (3 total)
| Node | Stake | Status |
|------|-------|--------|
| Validator #1 | 1,000 UAT | Active |
| Validator #2 | 1,000 UAT | Active |
| Validator #3 | 1,000 UAT | Active |
| **Validator Total** | **3,000 UAT** | **From Dev #8** |

### Total Supply
| Component | UAT | VOI (Void) | Pct |
|-----------|-----|-----------|-----|
| **Dev Supply** | **1,535,536** | **153,553,600,000,000** | **7.0%** |
| Public Supply (PoB) | 20,400,700 | 2,040,070,000,000,000 | 93.0% |
| **TOTAL** | **21,936,236** | **2,193,623,600,000,000** | **100.0%** |

**Key:** Dev Wallet #8 has 3,000 UAT deducted (3 nodes × 1,000 UAT each)

---

## ⚙️ Core Specifications

| Feature | Specification |
|---------|----------------|
| **Ticker** | UAT |
| **Total Supply** | 21,936,236 UAT (Fixed/Immutable) |
| **Smallest Unit** | 1 VOI (1 UAT = 100,000,000 VOI) |
| **Consensus** | aBFT (<3s finality) |
| **Cryptography** | Post-Quantum Safe (Dilithium-ready) |
| **Smart Contracts** | WASM (Rust, C++, Go, AssemblyScript) |
| **Validator Min Stake** | 1,000 UAT |
| **Transaction Fee** | Dynamic (base + spam scaling) |
| **Sentry Architecture** | Yes (DDoS protection) |
| **P2P Encryption** | Noise Protocol Framework |

---

## 🏗️ Architecture

### Network Layer
- **Consensus:** aBFT (Asynchronous Byzantine Fault Tolerance)
- **Finality:** < 3 seconds
- **Security:** Sentry node architecture + P2P encryption (Noise Protocol)
- **Voting:** Quadratic (√Stake) - prevents whale dominance

### Economic Layer
- **Supply:** 21,936,236 UAT (fixed, no inflation)
- **Distribution:** 93% public via Proof-of-Burn (BTC/ETH only)
- **Fees:** Dynamic scaling (x2, x4, x8) for spam prevention
- **Rewards:** 100% gas fees to validators

### Smart Contract Layer (UVM)
- **Runtime:** WASM-based (wasmer 4.3)
- **Languages:** Rust, C++, Go, AssemblyScript
- **Deployment:** Permissionless
- **Gas:** 5 VOI per instruction

### API Layer
- **REST:** 13 endpoints (`/balance`, `/send`, `/deploy-contract`, etc.)
- **gRPC:** 8 services for high-performance clients
- **Rate Limiting:** 100 req/sec per IP

---

## 📦 Project Structure

```
unauthority-core/
├── crates/                     # Rust workspace
│   ├── uat-core/              # Blockchain core (ledger, accounts, supply)
│   ├── uat-crypto/            # Post-quantum cryptography
│   ├── uat-consensus/         # aBFT consensus implementation
│   ├── uat-network/           # P2P networking + encryption
│   ├── uat-vm/                # Smart contract engine (WASM)
│   ├── uat-node/              # Full node (REST API + gRPC)
│   └── uat-cli/               # Command-line interface
├── genesis/                    # Genesis generator (11 wallets)
├── frontend-validator/         # Validator dashboard (Electron)
├── frontend-wallet/            # Public wallet (Electron)
├── examples/contracts/         # Smart contract examples
├── docs/                       # Documentation
├── api_docs/                   # API reference
├── scripts/                    # Deployment scripts
├── node_data/                  # Validator data directories
│   ├── validator-1/           # Bootstrap node #1 (1,000 UAT)
│   ├── validator-2/           # Bootstrap node #2 (1,000 UAT)
│   └── validator-3/           # Bootstrap node #3 (1,000 UAT)
└── Cargo.toml                  # Workspace manifest
```

---

## 🔐 Security Model

### Genesis Security
- ✅ **Zero Admin Keys:** No pause/upgrade functions
- ✅ **Fixed Supply:** 21.936M UAT (immutable)
- ✅ **11 Distinct Wallets:** 8 dev + 3 bootstrap nodes
- ✅ **Private Key Isolation:** Each validator has unique keypair
- ✅ **Encrypted Configuration:** validator.toml with PSK tunnels

### Network Security
- ✅ **Sentry Architecture:** Public shield + Private validator
- ✅ **P2P Encryption:** Noise Protocol Framework
- ✅ **DDoS Protection:** Rate limiting, connection limits, IP blacklist
- ✅ **Automated Slashing:**
  - Double-signing: 100% stake burn + permanent ban
  - Downtime: 1% per epoch
- ✅ **Validator Whitelisting:** Trusted sentry peer list

### Cryptographic Security
- ✅ **Post-Quantum Ready:** Keccak256 (migrable to CRYSTALS-Dilithium)
- ✅ **Private Key Generation:** Random seed + hash derivation
- ✅ **Address Format:** UAT + first 40 chars of Keccak256(pubkey)
- ✅ **Integer Math Only:** No floating-point errors in supply

### Economic Security
- ✅ **Anti-Whale Mechanisms:** Quadratic voting, fee scaling
- ✅ **Burn Limits:** Max 10 UAT per block via PoB
- ✅ **No Inflation:** Supply fixed at genesis
- ✅ **Validator Incentives:** 100% of gas fees to proposer

---

## 🧪 Testing

```bash
# Run all tests
cargo test

# Run specific crate tests
cargo test -p uat-core
cargo test -p uat-consensus
cargo test -p uat-vm

# Test with verbose output
cargo test -- --nocapture

# Test with single thread (less noise)
cargo test -- --test-threads=1

# Run only integration tests
cargo test --test '*'

# Run sentry node tests (10 tests)
cargo test -p uat-node sentry

# Run consensus tests (17 tests)
cargo test -p uat-consensus
```

**Current Status:** 159+ tests passing ✅

---

## 🚀 Deployment

### Local Development
```bash
# Terminal 1: Validator 1
cargo run -p uat-node -- --config node_data/validator-1/validator.toml

# Terminal 2: Validator 2
cargo run -p uat-node -- --config node_data/validator-2/validator.toml

# Terminal 3: Validator 3
cargo run -p uat-node -- --config node_data/validator-3/validator.toml
```

### Production Deployment
```bash
# Build release binary
cargo build --release -p uat-node

# Run with sentry node
./target/release/uat-node \
  --config /etc/uat/validator.toml \
  --sentry-mode public \
  --listen 0.0.0.0:30333
```

---

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [GENESIS_IMPLEMENTATION_REPORT.md](GENESIS_IMPLEMENTATION_REPORT.md) | Complete genesis guide (11 wallets, allocation details) |
| [GENESIS_QUICK_START.md](GENESIS_QUICK_START.md) | Quick reference for genesis generation |
| [TASK_1_GENESIS_COMPLETION.md](TASK_1_GENESIS_COMPLETION.md) | Deliverables checklist |
| [docs/WHITEPAPER.md](docs/WHITEPAPER.md) | Technical whitepaper |
| [api_docs/API_REFERENCE.md](api_docs/API_REFERENCE.md) | REST/gRPC API documentation |
| [validator.toml](validator.toml) | Validator configuration template |

---

## 🤝 Contributing

Unauthority is open-source and permissionless:
- 🔓 **Deploy smart contracts** (no whitelist required)
- 🔓 **Run validator nodes** (minimum 1,000 UAT stake)
- 🔓 **Submit proposals** (on-chain governance)
- 🔓 **Review code** (all code auditable, no secrets)

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file

---

## 🔗 Quick Links

- **Documentation:** [docs/](docs/)
- **API Reference:** [api_docs/](api_docs/)
- **Genesis Guide:** [GENESIS_QUICK_START.md](GENESIS_QUICK_START.md)
- **Whitepaper:** [docs/WHITEPAPER.md](docs/WHITEPAPER.md)

---

**Built with Rust 🦀 | Powered by aBFT ⚡ | Secured by Post-Quantum Crypto 🔐**

**Genesis Allocation:** 11 wallets • 1,535,536 UAT • Zero Remainder Protocol ✓
