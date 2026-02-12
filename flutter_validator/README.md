# LOS Validator Node

Validator node dashboard for **Unauthority (LOS)** blockchain. Track node status, manage keys, and monitor consensus participation.

## Features

- **Live Dashboard** — real-time validator stats, uptime, and peer connections
- **Key Management** — generate or import validator keys with BIP39 seed phrases
- **Node Monitoring** — block height, finality times, transaction throughput
- **Slashing Alerts** — track penalties and validator health
- **Consensus Status** — aBFT safety parameters and quorum tracking
- **Built-in Tor** — connects to .onion nodes automatically
- **CRYSTALS-Dilithium5** — post-quantum digital signatures via native Rust FFI

## Download

Pre-built releases for macOS, Windows, and Linux:

**[Download from GitHub Releases](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.1-testnet)**

| Platform | File |
|----------|------|
| macOS | `LOS-Validator-*-macos.dmg` |
| Windows | `LOS-Validator-*-windows-x64.zip` |
| Linux | `LOS-Validator-*-linux-x64.tar.gz` |

> **macOS:** Apple blocks unsigned apps. After install, run:
> `xattr -cr /Applications/LOS\ Validator\ Node.app`
> Or: System Settings → Privacy & Security → Open Anyway

## Build from Source

### Prerequisites

- Flutter 3.27+ (`flutter --version`)
- Rust 1.75+ (`rustc --version`)

### Steps

```bash
# 1. Build the Dilithium5 native library
cd native/los_crypto_ffi
cargo build --release
cd ../..

# 2. Get Flutter dependencies
flutter pub get

# 3. Build for your platform
flutter build macos --release    # macOS
flutter build linux --release    # Linux
flutter build windows --release  # Windows
```

## Connect to a Node

1. Open the app
2. Go to **Settings**
3. Enter your node endpoint:
   - Local node: `http://localhost:3030`
   - Tor testnet: `http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion`
4. Click **Test Connection** → **Save**

## Running a Validator

To run your own validator node, see the [Testnet Run Guide](../dev_docs/TESTNET_RUN_GUIDE.md).

Minimum stake requirement: **1,000 LOS**.

## Project Structure

```
flutter_validator/
├── lib/
│   ├── main.dart              # App entry point
│   ├── constants/             # API URLs, theme colors
│   ├── models/                # Data models
│   ├── screens/               # Dashboard, settings, etc.
│   ├── services/              # API, wallet, Dilithium5, Tor services
│   └── widgets/               # Reusable UI components
├── native/
│   └── los_crypto_ffi/        # Rust FFI crate for Dilithium5
└── test/                      # Widget tests
```

## License

MIT
