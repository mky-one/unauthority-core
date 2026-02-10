# Wallet Guide

Using the UAT Wallet — create wallets, send tokens, burn-to-mint, and manage accounts.

**Version:** v1.0.3-testnet

---

## Download

| Platform | Download |
|----------|----------|
| macOS | [UAT-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |
| Windows | [UAT-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |
| Linux | [UAT-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |

Built-in Tor + CRYSTALS-Dilithium5. No external dependencies.

macOS: `xattr -cr /Applications/UAT\ Wallet.app` after first install.

---

## Create a New Wallet

1. Open the app
2. Click **Create New Wallet**
3. A **24-word BIP39 seed phrase** is generated
4. **Write it down on paper** — this is your only backup
5. Confirm the phrase to verify you saved it

Behind the scenes:
- Seed phrase → BIP39 64-byte seed
- Seed → deterministic Dilithium5 keypair (via `flutter_rust_bridge` FFI to native Rust)
- Public key → BLAKE2b-160 → Base58Check → `UAT` prefix = your address

---

## Import an Existing Wallet

1. Click **Import Wallet**
2. Enter your 24-word (or 12-word) seed phrase
3. The same address is deterministically regenerated

Both 12-word and 24-word BIP39 mnemonics are supported. The same mnemonic produces the same address on every platform (Rust node, Flutter wallet, Flutter validator).

---

## Send Tokens

1. Go to **Send** tab
2. Enter recipient `UAT...` address
3. Enter amount in UAT
4. Click **Send**

The wallet constructs a block-lattice Send block:
- Computes `signing_hash` = Keccak-256(chain_id + account + previous + representative + balance + link + fee + timestamp)
- Signs with Dilithium5 via native FFI
- Performs 16-bit PoW (anti-spam)
- Broadcasts to node via Tor

**Minimum fee**: 0.001 UAT (100,000 VOID)

---

## Receive Tokens

1. Go to **Receive** tab
2. Share your `UAT...` address (or QR code) with the sender
3. Incoming transactions appear automatically after network finality (~3 seconds)

---

## Testnet Faucet

1. Go to **Faucet** tab
2. Click **Request UAT**
3. Receive **5,000 UAT** per claim

Rate limit: 1 claim per hour per address.

---

## Proof-of-Burn Minting

UAT is minted by verifiably burning ETH or BTC:

1. Go to **Burn** tab
2. Burn ETH to `0x000000000000000000000000000000000000dead` (or BTC to `1BitcoinEaterAddressDontSendf59kuE`)
3. Enter the burn transaction ID
4. Submit — oracle consensus verifies the burn
5. UAT is minted proportionally at market rate

Mint rate: 1 UAT = $0.01 (10,000 micro-USD). Calculated with integer-only math.

---

## Transaction History

Go to **History** tab to see all sent and received transactions with:
- Type (Send/Receive/Mint)
- Amount (UAT)
- Timestamp
- Block hash
- Counterparty address

Click any transaction to see full details.

---

## Settings

- **Network**: Testnet (CHAIN_ID = 2) or Mainnet (CHAIN_ID = 1)
- **Node URL**: Auto-configured for testnet .onion bootstraps
- **Tor**: Built-in — no configuration needed
- **Export wallet**: Backup encrypted wallet file

---

## Security Architecture

| Layer | Implementation |
|-------|---------------|
| **Key generation** | Native Rust FFI — BIP39 → Dilithium5 (never in Dart) |
| **Signatures** | Native Rust FFI — Dilithium5 sign/verify |
| **Key storage** | FlutterSecureStorage (iOS Keychain / Android Keystore / OS credential store) |
| **Memory** | Seed bytes zeroed after use in both Rust and Dart |
| **Network** | All API calls routed through Tor SOCKS5 proxy |
| **Addresses** | BLAKE2b-160 + Base58Check with version byte + `UAT` prefix |

### Dilithium5 FFI

The wallet uses `flutter_rust_bridge` to call a native Rust library (`libuat_crypto_ffi`):

| Function | Purpose |
|----------|---------|
| `generateKeypair()` | Random Dilithium5 keypair |
| `generateKeypairFromSeed(seed)` | Deterministic keypair from BIP39 seed |
| `sign(message, secretKey)` | Sign data with Dilithium5 |
| `verify(message, signature, publicKey)` | Verify Dilithium5 signature |
| `publicKeyToAddress(publicKey)` | Derive UAT address from public key |
| `validateAddress(address)` | Validate UAT address checksum |

The native library is compiled per platform:
- macOS: `libuat_crypto_ffi.dylib`
- Linux: `libuat_crypto_ffi.so`
- Windows: `uat_crypto_ffi.dll`

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Cannot verify app" on macOS | `xattr -cr /Applications/UAT\ Wallet.app` |
| Wallet won't connect | Ensure Tor is running — app auto-installs on first launch |
| Balance not updating | Wait ~3 seconds for aBFT finality, then refresh |
| Seed phrase not accepted | Ensure all words are valid BIP39 English words |
| "Native library not found" | Rebuild with `cd native/uat_crypto_ffi && cargo build --release` |
| Send fails | Check balance covers amount + 0.001 UAT fee |

---

## Technical Details

| Property | Value |
|----------|-------|
| Signature scheme | CRYSTALS-Dilithium5 (NIST Level 5) |
| Key derivation | BIP39 → SHA-256 domain separation → ChaCha20 → Dilithium5 |
| Address format | Version `0x4A` + BLAKE2b-160 + Base58Check + `UAT` prefix |
| Block hash | Keccak-256 |
| PoW | 16 leading zero bits (anti-spam, not consensus) |
| Unit | 1 UAT = 10^11 VOID (100,000,000,000) |
| Min fee | 0.001 UAT (100,000 VOID) |
| Chain ID | Testnet = 2, Mainnet = 1 |
