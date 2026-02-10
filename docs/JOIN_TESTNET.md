# Join the UAT Testnet

> **Version:** v1.0.3-testnet | **Last updated:** February 10, 2026

This guide will get you connected to the Unauthority testnet in under 5 minutes.

---

## 1. Download the Wallet

Pre-built desktop apps with **built-in Tor** and **Dilithium5 post-quantum crypto**. No extra software needed.

| Platform | Download |
|----------|----------|
| macOS | [UAT-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |
| Windows | [UAT-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |
| Linux | [UAT-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.3-testnet) |

> **macOS first launch:** Apple may block the app. Fix with:
> ```bash
> xattr -cr /Applications/UAT\ Wallet.app
> ```
> Or go to **System Settings → Privacy & Security → Open Anyway**.

---

## 2. Create a Wallet

1. Open the UAT Wallet app
2. Click **"Create New Wallet"**
3. Write down your **24-word seed phrase** on paper — this is your only backup!
4. Confirm the seed phrase when prompted
5. Your UAT address will appear (starts with `UAT...`)

> **Seed phrase security:** Anyone with your 24 words can access your funds. Store offline. Never share.

> **12 or 24 words?** Both are supported. 24 words (256-bit entropy) is recommended for post-quantum safety.

---

## 3. Connect to the Testnet

The wallet connects automatically via Tor to the bootstrap validators:

| Validator | Onion Address |
|-----------|---------------|
| Node 1 | `u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion` |
| Node 2 | `5yvqf4sdbif4pegxgrgfq5ksv3gqqpt27x2xzx5nvrmdqmsrk4mnkgad.onion` |
| Node 3 | `3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion` |
| Node 4 | `7pka6rdrnvd7qjrn4qdbfmcqgl5qb7v2yqopgxaiqyqbrlawcl6yruad.onion` |

If the app does not auto-connect, go to **Settings** and set the node endpoint to one of the addresses above.

---

## 4. Get Testnet Tokens (Faucet)

1. Copy your wallet address
2. Go to the **Faucet** tab in the app (or use the API below)
3. Request tokens — you'll receive **5,000 UAT** per request (limit: once per hour)

**API method** (using curl + Tor):
```bash
curl --socks5-hostname 127.0.0.1:9050 \
  -X POST http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion/faucet \
  -H "Content-Type: application/json" \
  -d '{"address": "YOUR_UAT_ADDRESS_HERE"}'
```

---

## 5. Send a Transaction

1. Go to the **Send** tab
2. Enter the recipient's UAT address
3. Enter the amount (e.g., `10`)
4. Click **Send**
5. Transaction confirms in **< 3 seconds**

---

## Run a Validator Node (Optional)

Want to help secure the network? Run a validator.

### Requirements

- macOS, Linux, or Windows
- 4 GB RAM, 10 GB disk space
- Stable internet connection
- Minimum stake: **1,000 UAT**

### Quick Start

**Option A: Download the Validator Dashboard (GUI)**

| Platform | Download |
|----------|----------|
| macOS | [UAT-Validator-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.3-testnet) |
| Windows | [UAT-Validator-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.3-testnet) |
| Linux | [UAT-Validator-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/validator-v1.0.3-testnet) |

1. Open the Validator Dashboard
2. Click **"Generate Keys"** or **"Import Seed Phrase"**
3. Fund the validator address with at least 1,000 UAT
4. The node will sync and begin validating automatically

**Option B: Build from Source**

```bash
# Prerequisites: Rust 1.75+, Git
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core

# Build
cargo build --release -p uat-node

# Run (single node, testnet mode)
./target/release/uat-node --dev
```

Configuration: edit `validator.toml` — see [docs/VALIDATOR_GUIDE.md](docs/VALIDATOR_GUIDE.md) for details.

### Run a Local Testnet (4 Validators)

```bash
# Start 4-node local testnet
./start.sh

# Check node health
curl http://127.0.0.1:3030/health

# Stop
./stop.sh
```

---

## Import a Genesis Wallet (Testnet Only)

The testnet ships with 12 pre-funded wallets (8 treasury + 4 validators).
Since v1.0.3, seed phrases are **deterministic** — importing a genesis seed phrase in the wallet app will produce the exact same address and keypair.

To import:
1. Open UAT Wallet → **"Import Existing Wallet"**
2. Paste one of the testnet seed phrases from [testnet-genesis/testnet_wallets.json](testnet-genesis/testnet_wallets.json)
3. The wallet will derive the same Dilithium5 keypair and show the correct balance

> **WARNING:** These are PUBLIC testnet seeds. Never use them on mainnet.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App won't open (macOS) | `xattr -cr /Applications/UAT\ Wallet.app` |
| "Connection failed" | Tor may be starting up — wait 30 seconds and retry |
| Balance shows 0 | Check that you're connected to the testnet (look for green status dot) |
| Transaction stuck | Ensure the node endpoint is reachable, try a different bootstrap node |
| Faucet rate limited | Faucet allows 1 request per hour per address |

---

## Key Technical Details

| Property | Value |
|----------|-------|
| Cryptography | CRYSTALS-Dilithium5 (post-quantum, NIST standard) |
| Address format | `UAT` + Base58Check(BLAKE2b-160 hash of public key) |
| Seed phrase | BIP39 standard, 24 words (256-bit entropy) |
| Consensus | aBFT with < 3s finality |
| Total supply | 21,936,236 UAT (fixed forever) |
| Smallest unit | 1 VOID = 10⁻¹¹ UAT |
| Network | All traffic via Tor Hidden Services |

---

## Links

- [GitHub Repository](https://github.com/unauthoritymky-6236/unauthority-core)
- [Whitepaper](docs/WHITEPAPER.md)
- [Validator Guide](docs/VALIDATOR_GUIDE.md)
- [API Reference](api_docs/API_REFERENCE.md)
- [Installation (Build from Source)](docs/INSTALLATION.md)
