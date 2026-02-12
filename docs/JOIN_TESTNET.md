# Join the LOS Testnet

Quick start guide — from zero to sending tokens in 5 minutes.

**Version:** v1.0.6-testnet

---

## 1. Download the Wallet

Pre-built desktop apps with built-in Tor and Dilithium5 cryptography. No external dependencies.

| Platform | Download |
|----------|----------|
| macOS | [LOS-Wallet-macos.dmg](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |
| Windows | [LOS-Wallet-windows-x64.zip](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |
| Linux | [LOS-Wallet-linux-x64.tar.gz](https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/wallet-v1.0.6-testnet) |

### macOS: Remove Gatekeeper Block

Apple blocks unsigned apps. After installing, run:

```bash
xattr -cr /Applications/LOS\ Wallet.app
```

Or: **System Settings → Privacy & Security → Open Anyway**.

---

## 2. Create a Wallet

1. Open the app
2. Click **Create New Wallet**
3. **Write down your 24-word seed phrase on paper** — this is your only backup
4. Confirm the seed phrase when prompted

Your address starts with `LOS` (e.g., `LOSBwXk9...`). This is derived from a CRYSTALS-Dilithium5 post-quantum keypair.

---

## 3. Get Testnet Tokens

Go to the **Faucet** tab and click **Request LOS**.

- **Amount:** 5,000 LOS per claim
- **Cooldown:** 1 hour per address
- **Network:** Testnet only (CHAIN_ID = 2)

---

## 4. Send Tokens

1. Go to the **Send** tab
2. Enter a recipient `LOS...` address
3. Enter amount (e.g., `100`)
4. Click **Send**

The wallet constructs a block-lattice Send block, signs it with Dilithium5, performs 16-bit PoW, and broadcasts to the network via Tor.

---

## 5. Verify via API

Check any balance through Tor:

```bash
# Via Tor SOCKS5 proxy (port 9052 or 9150 for Tor Browser)
curl --socks5-hostname 127.0.0.1:9052 \
  http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/bal/YOUR_ADDRESS

# Local node (if running one)
curl http://127.0.0.1:3030/bal/YOUR_ADDRESS
```

---

## 6. Bootstrap Nodes

The testnet runs 4 validators accessible via Tor hidden services:

| Node | .onion Address |
|------|---------------|
| Validator 1 | `ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion` |
| Validator 2 | `5yvqf4sdbif4pegxgrgfq5ksv3gqqpt27x2xzx5nvrmdqmsrk4mnkgad.onion` |
| Validator 3 | `3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion` |
| Validator 4 | `yapub6hgjr3eyxnxzvgd4yejt7rkhwlmaivdpy6757o3tr5iicckgjyd.onion` |

The wallet auto-connects to these nodes. No configuration needed.

---

## 7. Run Your Own Validator (Optional)

See [VALIDATOR_GUIDE.md](VALIDATOR_GUIDE.md) for full instructions.

Quick start:

```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core
cargo build --release --bin los-node
./target/release/los-node --dev
```

Minimum stake: 1,000 LOS.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Cannot verify app" on macOS | `xattr -cr /Applications/LOS\ Wallet.app` |
| Wallet won't connect | Ensure Tor is running — the app auto-installs it on first launch |
| Faucet says "rate limited" | Wait 1 hour between claims |
| Balance shows 0 after faucet | Wait ~3 seconds for finality, then refresh |
| Address doesn't start with LOS | Update to v1.0.6 — older versions had incompatible address format |

---

## Technical Details

| Property | Value |
|----------|-------|
| Network | Testnet (CHAIN_ID = 2) |
| Finality | < 3 seconds |
| Consensus | aBFT (Asynchronous Byzantine Fault Tolerance) |
| Cryptography | CRYSTALS-Dilithium5 (NIST Level 5, post-quantum) |
| Address format | Version `0x4A` + BLAKE2b-160 + Base58Check + `LOS` prefix |
| Unit | 1 LOS = 10^11 CIL |
| Minimum fee | 0.001 LOS (100,000 CIL) |
| PoW | 16 leading zero bits (anti-spam, not consensus) |
