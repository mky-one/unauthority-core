# Installation Guide

Build Unauthority from source or download pre-built binaries.

**Version:** v1.0.6-testnet

---

## Pre-built Binaries

### Wallet App

| Platform | Download |
|----------|----------|
| macOS | [UAT-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |
| Windows | [UAT-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |
| Linux | [UAT-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |

### Validator Dashboard

| Platform | Download |
|----------|----------|
| macOS | [UAT-Validator-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) |
| Windows | [UAT-Validator-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) |
| Linux | [UAT-Validator-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.6-testnet) |

---

## Build from Source

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Rust | 1.75+ | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Protobuf | 3.x+ | macOS: `brew install protobuf` · Linux: `apt install protobuf-compiler` |
| Flutter | 3.5+ | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |

### Rust Node

```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core

# Build all binaries (uat-node, uat-cli, genesis_generator)
cargo build --release

# Binaries in target/release/
ls target/release/uat-node target/release/uat-cli target/release/genesis_generator
```

### Flutter Wallet

```bash
cd flutter_wallet

# Build native Rust crypto library (required for Dilithium5)
cd native/uat_crypto_ffi
cargo build --release
cd ../..

# Build Flutter app
flutter pub get
flutter build macos --release    # or: linux, windows
```

The built app is in `build/macos/Build/Products/Release/`.

### Flutter Validator Dashboard

```bash
cd flutter_validator

# Build native Rust crypto library
cd native/uat_crypto_ffi
cargo build --release
cd ../..

flutter pub get
flutter build macos --release    # or: linux, windows
```

---

## Run Tests

```bash
# Full test suite (240 tests)
cargo test --workspace --all-features --exclude uat-vm

# Individual crates
cargo test -p uat-core          # Core: ledger, accounts, supply (55 tests)
cargo test -p uat-consensus     # aBFT, voting, slashing (43 tests)
cargo test -p uat-crypto        # Dilithium5, address derivation (30 tests)
cargo test -p uat-network       # P2P, fee scaling, rewards (57 tests)
cargo test -p uat-node          # Node integration (13 tests)
cargo test -p uat-vm            # WASM virtual machine (20 tests)

# Doc tests
cargo test --doc --workspace
```

---

## Verify Installation

```bash
# Check node version
./target/release/uat-node --version
# uat-node 1.0.6

# Run a dev-mode testnet node
./target/release/uat-node --dev

# Check health
curl http://127.0.0.1:3030/health
# {"status":"healthy"}

# Check node info
curl http://127.0.0.1:3030/node-info
```

---

## macOS Gatekeeper

Apple blocks unsigned apps. After installing a pre-built `.dmg`:

```bash
xattr -cr /Applications/UAT\ Wallet.app
xattr -cr /Applications/flutter_validator.app
```

Or: **System Settings → Privacy & Security → Open Anyway**.

---

## Directory Structure After Build

```
target/release/
├── uat-node               # Full validator node binary
├── uat-cli                # Command-line interface
└── genesis_generator      # Genesis block generator

flutter_wallet/build/      # Wallet app (platform-specific)
flutter_validator/build/   # Validator dashboard (platform-specific)
```
