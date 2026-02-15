# LOS Wallet

Desktop wallet for the **Unauthority (LOS)** blockchain. Send, receive, and burn-to-mint LOS tokens with post-quantum security.

## Features

- **Create / Import Wallet** — generate new keys or recover from 24-word BIP39 seed phrase
- **Send & Receive LOS** — instant transactions with < 3 second finality
- **Proof-of-Burn** — burn BTC/ETH to mint LOS tokens
- **Faucet** — claim 100 testnet LOS (1 hour cooldown)
- **Address Book** — save frequently used addresses
- **Transaction History** — view all past transactions
- **QR Code** — share your address via QR
- **Built-in Tor** — auto-downloads Tor Expert Bundle (no Tor Browser needed)
- **CRYSTALS-Dilithium5** — post-quantum digital signatures via native Rust FFI
- **Multi-Platform** — macOS (Intel + Apple Silicon), Linux, Windows

## Download

Pre-built releases for macOS, Windows, and Linux:

**[Download from GitHub Releases](https://github.com/monkey-one/unauthority-core/releases/tag/wallet-v1.0.8-testnet)**

| Platform | File |
|----------|------|
| macOS | `LOS-Wallet-1.0.8-testnet-macos.dmg` |
| Windows | `LOS-Wallet-1.0.8-testnet-windows-x64.zip` |
| Linux | `LOS-Wallet-1.0.8-testnet-linux-x64.tar.gz` |

> **macOS:** If blocked, run: `xattr -d com.apple.quarantine /Applications/LOS\ Wallet.app`  
> Or: System Settings → Privacy & Security → Open Anyway
>
> **Windows:** Click "More info" → "Run anyway" if SmartScreen blocks the app.  
> **Linux:** Run via `run.sh` (sets `LD_LIBRARY_PATH` for native library).
>
> **First Launch:** The wallet auto-downloads Tor Expert Bundle (~20MB, 1-2 min).

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

The native library (`liblos_crypto_ffi.dylib` / `.so` / `.dll`) must be placed alongside the built app. See the GitHub Actions workflow for platform-specific bundling steps.

## Connect to Testnet

The wallet **auto-connects** to testnet peers via Tor (no configuration needed). Tor downloads automatically on first launch.

### Manual Configuration (Optional)

If auto-discovery fails:

1. Open the app → **Settings** tab
2. Enter a peer endpoint manually (e.g., `http://<peer-onion-address>:3030`)
3. Click **Test Connection** → **Save & Reconnect**

For local development, use `http://localhost:3030` instead.

**See also:** [Testnet Quick Start Guide](../TESTNET_QUICKSTART.md)

## Project Structure

```
flutter_wallet/
├── lib/
│   ├── main.dart              # App entry point
│   ├── constants/             # API URLs, theme colors
│   ├── models/                # Data models
│   ├── screens/               # UI screens (dashboard, send, burn, etc.)
│   ├── services/              # API, wallet, Dilithium5, Tor services
│   └── widgets/               # Reusable UI components
├── native/
│   └── los_crypto_ffi/        # Rust FFI crate for Dilithium5
├── assets/                    # Icons, images
└── test/                      # Widget tests
```

## License

MIT
