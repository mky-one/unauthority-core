# Unauthority (UAT) - The Sovereign Machine

> 100% Immutable, Permissionless, and Decentralized Blockchain  
> Zero Admin Keys • Fixed Supply • Asynchronous Byzantine Fault Tolerance

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Consensus](https://img.shields.io/badge/consensus-aBFT-blue)]()
[![Supply](https://img.shields.io/badge/supply-21.936M%20UAT-orange)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## ⚠️ MAJOR UPDATE: USD Migration (Feb 4, 2026)

**Reason:** Identity preservation & economic viability  
**Status:** ✅ COMPLETE

All IDR (Indonesian Rupiah) references have been replaced with USD (US Dollar) to:
1. **Preserve Anonymity**: Remove geographic fingerprints (Bitcoin-style anonymous launch)
2. **Improve Economics**: 1 UAT = $0.01 (155x more expensive to attack than Rp1 = $0.000065)
3. **Global Appeal**: USD = universal standard vs regional currency

**Breaking Changes:**
- REST API: `total_burned_idr` → `total_burned_usd`
- gRPC: `eth_price_idr` → `eth_price_usd`, `btc_price_idr` → `btc_price_usd`
- Oracle: Indodax (Indonesian exchange) removed, Kraken (global) added

**Details:** See [USD_MIGRATION.md](USD_MIGRATION.md)

---

## 🎉 NEW: Public Wallet (Feb 4, 2026)

**✅ COMPLETE** - Full-featured Electron Desktop App for burning BTC/ETH to mint UAT!

### Features
- 🔑 Create/import HD wallet (12-word seed phrase)
- 🔥 Burn BTC/ETH with QR codes
- 💸 Send/receive UAT (<3 sec finality)
- 📊 Real-time balance & oracle prices
- 📜 Transaction history
- 🔒 100% local, 100% private (no server)

### Quick Start
```bash
cd frontend-wallet
npm install
npm run dev
# Opens at http://localhost:5173
```

**Full Documentation:** [frontend-wallet/README.md](frontend-wallet/README.md)  
**Setup Guide:** [WALLET_COMPLETE.md](WALLET_COMPLETE.md)

---

## 🚀 Quick Start

### 1. Generate Genesis (11 Wallets)
```bash
cargo run -p genesis
```
**Output:** 8 Dev Wallets + 3 Bootstrap Validator Nodes with private keys

### 2. Setup Validators
```bash
bash scripts/setup_validators.sh
```
**Creates:** validator-{1,2,3}/ directories with unique configs

### 3. Start Network
```bash
# Terminal 1
source node_data/validator-1/.env && cargo run -p uat-node -- --config node_data/validator-1/validator.toml

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

```
┌─────────────────────────────────────────────────────────────┐
│              UNAUTHORITY (UAT) NETWORK                      │
│                  The Sovereign Machine                      │
└─────────────────────────────────────────────────────────────┘
         │
         ├─────────────── GENESIS (11 Wallets)
         │                ├─ 8 Dev/Treasury Wallets
         │                │  ├─ Dev #1-7: 191,942 UAT each
         │                │  └─ Dev #8: 188,942 UAT (reduced)
         │                └─ 3 Bootstrap Validators
         │                   ├─ Validator-1: 1,000 UAT
         │                   ├─ Validator-2: 1,000 UAT
         │                   └─ Validator-3: 1,000 UAT
         │
         ├─────────────── CONSENSUS (aBFT)
         │                ├─ Asynchronous Byzantine Fault Tolerance
         │                ├─ <3 second finality
         │                ├─ 1/3 + 1 Byzantine threshold
         │                └─ Quadratic voting (√Stake)
         │
         ├─────────────── NETWORK SECURITY
         │                ├─ Sentry Node Architecture
         │                │  ├─ Public: DDoS shield (Port 30333+)
         │                │  └─ Private: Validator signing (Port 30331+)
         │                ├─ P2P Encryption (Noise Protocol)
         │                ├─ IP Blacklisting & Rate Limiting
         │                └─ Connection Tracking
         │
         ├─────────────── ANTI-WHALE MECHANISMS
         │                ├─ Dynamic Fee Scaling (x2, x4, x8)
         │                ├─ Burn Limits per Block (10 UAT max via PoB)
         │                ├─ Quadratic Voting (prevents whale dominance)
         │                └─ Spam Detection (10 tx/sec threshold)
         │
         ├─────────────── SMART CONTRACTS (UVM)
         │                ├─ WASM-based execution
         │                ├─ Permissionless deployment
         │                ├─ Multi-language support
         │                │  ├─ Rust
         │                │  ├─ C++
         │                │  ├─ Go
         │                │  └─ AssemblyScript
         │                ├─ Real WASM runtime (wasmer 4.3)
         │                └─ Gas metering (5 VOI per instruction)
         │
         ├─────────────── ECONOMIC SECURITY
         │                ├─ Fixed Supply (21.936M UAT)
         │                ├─ No Inflation (zero minting post-genesis)
         │                ├─ Transaction Fees → Validators (100%)
         │                ├─ Validator Rewards = Gas collected
         │                ├─ Proof-of-Burn Distribution (PoB)
         │                │  ├─ Accept: BTC, ETH (decentralized)
         │                │  └─ Reject: USDT, USDC, XRP (centralized)
         │                └─ Bonding Curve (scarcity increases price)
         │
         └─────────────── APIS
                          ├─ REST API (13 endpoints)
                          │  ├─ /balance
                          │  ├─ /send
                          │  ├─ /burn
                          │  ├─ /deploy-contract
                          │  ├─ /call-contract
                          │  └─ ...
                          └─ gRPC (8 services)
                             ├─ GetBalance
                             ├─ GetAccount
                             ├─ SendTransaction
                             └─ ...
```

---

## 📦 Project Structure

```
unauthority-core/
├── genesis/                          # Genesis generator (11 wallets)
│   ├── src/main.rs                  # Generates 8 dev + 3 bootstrap nodes
│   ├── Cargo.toml                   # Dependencies (rand, sha3, chrono, serde_json)
│   └── genesis_config.json          # Output: immutable state
│
├── crates/                          # Modular architecture
│   ├── uat-core/                   # Ledger, accounts, supply
│   │   ├── src/
│   │   │   ├── lib.rs              # Core types & ledger
│   │   │   ├── distribution.rs     # PoB distribution logic
│   │   │   └── validator_config.rs # TOML/env config loading
│   │   └── Cargo.toml
│   │
│   ├── uat-crypto/                # Post-quantum cryptography
│   │   ├── src/lib.rs             # Keypair generation, signing
│   │   └── Cargo.toml             # pqcrypto-dilithium
│   │
│   ├── uat-network/               # P2P, fee scaling, encryption
│   │   └── Cargo.toml
│   │
│   ├── uat-node/                 # Main validator node
│   │   ├── src/
│   │   │   ├── main.rs           # Entry point, 13 REST endpoints
│   │   │   ├── validator_rewards.rs  # Gas fee distribution
│   │   │   ├── genesis.rs        # Genesis loading
│   │   │   ├── oracle.rs         # Oracle consensus
│   │   │   ├── sentry.rs         # Sentry + Validator node
│   │   │   └── grpc_api.rs       # gRPC services (8 methods)
│   │   └── Cargo.toml
│   │
│   ├── uat-consensus/            # aBFT Byzantine consensus
│   │   └── Cargo.toml            # Asynchronous BFT impl
│   │
│   └── uat-vm/                   # WASM smart contracts
│       ├── src/lib.rs            # WasmEngine with real wasmer
│       └── Cargo.toml            # wasmer 4.3, cranelift
│
├── scripts/
│   ├── setup_validators.sh        # Auto-configure 3 validators
│   ├── verify_genesis.sh          # Verify 11-wallet structure
│   ├── start_validator.sh         # Start individual validator
│   └── bootstrap_genesis.sh       # One-command setup
│
├── node_data/                     # Validator node directories
│   ├── validator-1/               # Bootstrap Node #1 (1,000 UAT)
│   │   ├── blockchain/
│   │   ├── logs/
│   │   ├── validator.toml         # Config with unique address
│   │   ├── private_key.hex        # Validator signing key
│   │   ├── genesis_config.json    # Copy from genesis
│   │   └── .env                   # Environment variables
│   ├── validator-2/               # Bootstrap Node #2 (1,000 UAT)
│   │   └── ...
│   └── validator-3/               # Bootstrap Node #3 (1,000 UAT)
│       └── ...
│
├── docs/                          # Documentation
│   └── WHITEPAPER.md
│
├── api_docs/                      # API documentation
│   └── API_REFERENCE.md           # REST + gRPC endpoints
│
├── Cargo.toml                     # Workspace manifest
├── Cargo.lock                     # Dependency lock file
├── README.md                      # This file
├── LICENSE                        # MIT License
├── GENESIS_IMPLEMENTATION_REPORT.md
├── GENESIS_QUICK_START.md
└── TASK_1_GENESIS_COMPLETION.md
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
