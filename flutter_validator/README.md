# LOS Validator Node

Validator node dashboard for **Unauthority (LOS)** blockchain. Track node status, manage keys, and monitor consensus participation.

## Features

- **Live Dashboard** — real-time validator stats, uptime, and peer connections
- **Key Management** — generate or import validator keys with BIP39 seed phrases
- **Node Monitoring** — block height, finality times, transaction throughput
- **Slashing Alerts** — track penalties and validator health
- **Consensus Status** — aBFT safety parameters and quorum tracking
- **Bundled los-node** — includes full validator binary (no separate install needed)
- **Built-in Tor** — auto-downloads Tor Expert Bundle (no Tor Browser needed)
- **CRYSTALS-Dilithium5** — post-quantum digital signatures via native Rust FFI

## Download

Pre-built releases for macOS, Windows, and Linux:

**[Download from GitHub Releases](https://github.com/monkey-one/unauthority-core/releases/tag/validator-v1.0.10-testnet)**

| Platform | File |
|----------|------|
| macOS | `LOS-Validator-1.0.10-testnet-macos.dmg` |
| Windows | `LOS-Validator-1.0.10-testnet-windows-x64.zip` |
| Linux | `LOS-Validator-1.0.10-testnet-linux-x64.tar.gz` |

> **macOS:** If blocked, run: `xattr -d com.apple.quarantine /Applications/LOS\ Validator\ Node.app`  
> Or: System Settings → Privacy & Security → Open Anyway
>
> **Windows:** Click "More info" → "Run anyway" if SmartScreen blocks the app.  
> **Linux:** Run via `run.sh` (sets `LD_LIBRARY_PATH` for native library).
>
> **First Launch:** The dashboard auto-downloads Tor Expert Bundle (~20MB, 1-2 min).
>
> **Bundled Binary:** The validator includes `los-node` (full validator binary) — no separate installation needed. Click "START NODE" in the dashboard to launch.

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

The dashboard **auto-connects** to testnet peers via Tor (no configuration needed). When you click "START NODE", the bundled `los-node` binary launches automatically.

### Manual Configuration (Optional)

To connect to a remote node instead of the bundled binary:

1. Open the app → **Settings**
2. Enter your node endpoint:
   - Local node: `http://localhost:3030`
   - Remote testnet peer: `http://<peer-onion-address>:3030`
3. Click **Test Connection** → **Save**

**See also:** [Testnet Quick Start Guide](../TESTNET_QUICKSTART.md)

## Running a Validator

The dashboard includes a bundled `los-node` binary — no separate installation needed.

**Quick Start:**
1. Open the validator dashboard
2. Import or generate validator keys
3. Click "**START NODE**" to launch the bundled binary
4. Register as a validator (requires **1,000 LOS** minimum stake)
5. Monitor consensus participation in the dashboard

**See also:**
- [Testnet Quick Start Guide](../TESTNET_QUICKSTART.md)
- [Validator Guide (Technical)](../docs/VALIDATOR_GUIDE.md)

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
