# Installation Guide

Complete guide for installing and running Unauthority on all platforms.

---

## Quick Start (End Users)

Download pre-built desktop apps — no command line needed.

### UAT Wallet

| Platform | Download | How to Install |
|----------|----------|----------------|
| **macOS** | [UAT-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/v1.0.0-testnet) | Open DMG, drag to Applications |
| **Windows** | [UAT-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/v1.0.0-testnet) | Extract zip, run `flutter_wallet.exe` |
| **Linux** | [UAT-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/v1.0.0-testnet) | Extract, run `./run.sh` |

### UAT Validator Dashboard

| Platform | Download | How to Install |
|----------|----------|----------------|
| **macOS** | [UAT-Validator-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.0-testnet) | Open DMG, drag to Applications |
| **Windows** | [UAT-Validator-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.0-testnet) | Extract zip, run `flutter_validator.exe` |
| **Linux** | [UAT-Validator-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.0-testnet) | Extract, run `./run.sh` |

### macOS "Unidentified Developer" Warning

If macOS blocks the app:
```bash
xattr -d com.apple.quarantine /Applications/UAT\ Wallet.app
# or for validator:
xattr -d com.apple.quarantine /Applications/flutter_validator.app
```

### First Launch

1. Open the Wallet app
2. Create a new wallet (or import with seed phrase)
3. Go to Settings and set the node URL to your local testnet or the public .onion address
4. Use the in-app faucet to request test UAT

---

## Build from Source (Developers & Validators)

### Prerequisites

| Tool | Minimum Version | Install |
|------|-----------------|---------|
| Rust | 1.75+ | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Git | any | `brew install git` / `apt install git` |
| Flutter | 3.10+ | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) (for wallet/validator apps) |

### Build the Validator Node

```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core

# Build release binary
cargo build --release -p uat-node

# Verify
./target/release/uat-node --help 2>&1 || echo "Binary built at target/release/uat-node"
```

### Build the Flutter Wallet

```bash
cd flutter_wallet

# Install dependencies
flutter pub get

# Build for your platform
flutter build macos    # macOS
flutter build linux    # Linux
flutter build windows  # Windows
```

### Build the Flutter Validator Dashboard

```bash
cd flutter_validator

# Install dependencies
flutter pub get

# Build for your platform
flutter build macos    # macOS
flutter build linux    # Linux
flutter build windows  # Windows
```

---

## Run a Local Testnet

### Quick Start (4 validators)

```bash
chmod +x start.sh stop.sh
./start.sh
```

This starts 4 validators on ports 3030-3033. See [dev_docs/TESTNET_RUN_GUIDE.md](../dev_docs/TESTNET_RUN_GUIDE.md) for detailed instructions.

### Single Node (dev mode)

```bash
export UAT_TESTNET_LEVEL=functional
export UAT_NODE_ID=validator-1
./target/release/uat-node 3030
```

### Verify

```bash
curl -s http://localhost:3030/node-info | jq .
curl -s http://localhost:3030/supply | jq .
```

---

## Tor Integration (Privacy)

The wallet apps have **bundled Tor** — no extra setup needed for end users.

For validators running a node behind Tor:

```bash
# Install Tor
brew install tor        # macOS
sudo apt install tor    # Ubuntu/Debian

# Create hidden service config
mkdir -p ~/.tor-uat
cat > ~/.tor-uat/torrc << 'EOF'
HiddenServiceDir ~/.tor-uat/hidden_service
HiddenServicePort 80 127.0.0.1:3030
SocksPort 0
DataDirectory ~/.tor-uat/data
EOF

# Start Tor
tor -f ~/.tor-uat/torrc &

# Get your .onion address (after ~30 seconds)
cat ~/.tor-uat/hidden_service/hostname
```

---

## System Requirements

### Wallet App (End User)

| | Minimum |
|--|---------|
| OS | Windows 10, macOS 11+, Ubuntu 20.04+ |
| RAM | 2 GB |
| Disk | 200 MB |

### Validator Node

| | Recommended |
|--|-------------|
| OS | Linux (Ubuntu 22.04 LTS) |
| CPU | 4 cores |
| RAM | 8 GB |
| Disk | 50 GB SSD |
| Network | 10 Mbps upload |
| Uptime | 99.9% |

---

## Troubleshooting

### Node won't start - port in use
```bash
lsof -i :3030
pkill -f uat-node
```

### Database lock error
```bash
./stop.sh
rm -f node_data/validator-1/uat_database/LOCK
./start.sh
```

### Build fails
```bash
rustup update
cargo clean
cargo build --release -p uat-node
```

### Wallet shows "Node Offline"
Check the node URL in Settings. For local testnet: `http://localhost:3030`

---

## Links

| | |
|--|--|
| Releases | https://github.com/unauthoritymky-6236/unauthority-core/releases |
| API Reference | [api_docs/API_REFERENCE.md](../api_docs/API_REFERENCE.md) |
| Testnet Guide | [dev_docs/TESTNET_RUN_GUIDE.md](../dev_docs/TESTNET_RUN_GUIDE.md) |
| Whitepaper | [docs/WHITEPAPER.md](WHITEPAPER.md) |
