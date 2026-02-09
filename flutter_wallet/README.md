# UAT Wallet

Desktop wallet for the **Unauthority (UAT)** blockchain. Send, receive, and burn-to-mint UAT tokens with post-quantum security.

## Features

- **Create / Import Wallet** — generate new keys or recover from 24-word BIP39 seed phrase
- **Send & Receive UAT** — instant transactions with < 3 second finality
- **Proof-of-Burn** — burn BTC/ETH to mint UAT tokens
- **Faucet** — claim 100 testnet UAT (1 hour cooldown)
- **Address Book** — save frequently used addresses
- **Transaction History** — view all past transactions
- **QR Code** — share your address via QR
- **Built-in Tor** — connects to .onion testnet automatically, no Tor Browser needed
- **CRYSTALS-Dilithium5** — post-quantum digital signatures via native Rust FFI

## Download

Pre-built releases for macOS, Windows, and Linux:

**[Download from GitHub Releases](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.1-testnet)**

| Platform | File |
|----------|------|
| macOS | `UAT-Wallet-*-macos.dmg` |
| Windows | `UAT-Wallet-*-windows-x64.zip` |
| Linux | `UAT-Wallet-*-linux-x64.tar.gz` |

> **macOS:** Apple blocks unsigned apps. After install, run:
> `xattr -cr /Applications/UAT\ Wallet.app`
> Or: System Settings → Privacy & Security → Open Anyway

## Build from Source

### Prerequisites

- Flutter 3.27+ (`flutter --version`)
- Rust 1.75+ (`rustc --version`)

### Steps

```bash
# 1. Build the Dilithium5 native library
cd native/uat_crypto_ffi
cargo build --release
cd ../..

# 2. Get Flutter dependencies
flutter pub get

# 3. Build for your platform
flutter build macos --release    # macOS
flutter build linux --release    # Linux
flutter build windows --release  # Windows
```

The native library (`libuat_crypto_ffi.dylib` / `.so` / `.dll`) must be placed alongside the built app. See the GitHub Actions workflow for platform-specific bundling steps.

## Connect to Testnet

The wallet auto-connects via Tor. If you need to configure manually:

1. Open the app → **Settings** tab
2. Enter the node endpoint:
   ```
   http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
   ```
3. Click **Test Connection** → **Save & Reconnect**

For local development, use `http://localhost:3030` instead.

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
│   └── uat_crypto_ffi/        # Rust FFI crate for Dilithium5
├── assets/                    # Icons, images
└── test/                      # Widget tests
```

## License

MIT
