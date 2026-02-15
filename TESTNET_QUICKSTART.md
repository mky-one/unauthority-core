# 🚀 Unauthority Testnet — Quick Start Guide

**Welcome to the Unauthority (LOS) Testnet!**  
This guide will help you install and run the LOS Wallet or Validator Dashboard in minutes — no coding required.

---

## 📥 Download

### Latest Testnet Releases
- **Validator v1.0.10-testnet** — [Download](https://github.com/monkey-one/unauthority-core/releases/tag/validator-v1.0.10-testnet)
- **Wallet v1.0.8-testnet** — [Download](https://github.com/monkey-one/unauthority-core/releases/tag/wallet-v1.0.8-testnet)

### Choose Your Platform
| Platform | Validator | Wallet |
|----------|-----------|--------|
| **macOS** (Intel/Apple Silicon) | `LOS-Validator-1.0.10-testnet-macos.dmg` | `LOS-Wallet-1.0.8-testnet-macos.dmg` |
| **Linux** (x86_64) | `LOS-Validator-1.0.10-testnet-linux-x64.tar.gz` | `LOS-Wallet-1.0.8-testnet-linux-x64.tar.gz` |
| **Windows** (x86_64) | `LOS-Validator-1.0.10-testnet-windows-x64.zip` | `LOS-Wallet-1.0.8-testnet-windows-x64.zip` |

---

## 🔐 LOS Wallet — Installation

### macOS
1. **Download** `LOS-Wallet-1.0.8-testnet-macos.dmg`
2. **Open** the DMG file
3. **Drag** "LOS Wallet.app" to Applications folder
4. **Remove Quarantine** (run in Terminal):
   ```bash
   xattr -cr /Applications/LOS\ Wallet.app
   ```
5. **Launch** from Applications
6. **Done!** Tor downloads automatically on first run (~1-2 min)

> **Why?** macOS Gatekeeper blocks unsigned apps. The `xattr -cr` command removes all quarantine attributes.

### Linux
1. **Download** `LOS-Wallet-1.0.8-testnet-linux-x64.tar.gz`
2. **Extract:**
   ```bash
   tar -xzf LOS-Wallet-1.0.8-testnet-linux-x64.tar.gz
   cd bundle
   ```
3. **Make executable:**
   ```bash
   chmod +x run.sh flutter_wallet
   ```
4. **Run:**
   ```bash
   ./run.sh
   ```
5. **Done!** Tor downloads automatically on first run (~1-2 min)

**Note:** On first launch, the wallet may prompt for permissions to download Tor Expert Bundle (~20MB) from torproject.org.

### Windows
1. **Download** `LOS-Wallet-1.0.8-testnet-windows-x64.zip`
2. **Extract** to `C:\LOS-Wallet\` (or any folder)
3. **Right-click** `flutter_wallet.exe` → **Properties** → **Unblock** checkbox → **OK**
4. **Run** `flutter_wallet.exe`
5. **If Windows SmartScreen appears:** Click "More info" → "Run anyway"
6. **Done!** Tor downloads automatically on first run (~1-2 min)

> **Why?** Windows SmartScreen blocks unsigned apps downloaded from the internet. The "Unblock" checkbox marks the file as safe.

---

## 🖥️ LOS Validator Dashboard — Installation

### macOS
1. **Download** `LOS-Validator-1.0.10-testnet-macos.dmg`
2. **Open** the DMG file
3. **Drag** "LOS Validator Node.app" to Applications folder
4. **Remove Quarantine** (run in Terminal):
   ```bash
   xattr -cr /Applications/LOS\ Validator\ Node.app
   ```
5. **Launch** from Applications
6. **Done!** The dashboard includes a bundled `los-node` binary — no separate installation needed.

> **Why?** macOS Gatekeeper blocks unsigned apps. The `xattr -cr` command removes all quarantine attributes.

### Linux
1. **Download** `LOS-Validator-1.0.10-testnet-linux-x64.tar.gz`
2. **Extract:**
   ```bash
   tar -xzf LOS-Validator-1.0.10-testnet-linux-x64.tar.gz
   cd bundle
   ```
3. **Make executable:**
   ```bash
   chmod +x run.sh flutter_validator los-node
   ```
4. **Run:**
   ```bash
   ./run.sh
   ```
5. **Done!** The bundled `los-node` binary starts automatically when you click "START NODE".

### Windows
1. **Download** `LOS-Validator-1.0.10-testnet-windows-x64.zip`
2. **Extract** to `C:\LOS-Validator\` (or any folder)
3. **Right-click** `flutter_validator.exe` → **Properties** → **Unblock** checkbox → **OK**
4. **Right-click** `los-node.exe` → **Properties** → **Unblock** checkbox → **OK**
5. **Run** `flutter_validator.exe`
6. **If Windows SmartScreen appears:** Click "More info" → "Run anyway"
7. **Done!** The bundled `los-node.exe` starts automatically when you click "START NODE".

> **Why?** Windows SmartScreen blocks unsigned apps. The "Unblock" checkbox marks files as safe.

---

## 🧪 First Run — What to Expect

### LOS Wallet
1. **Setup Wizard:**
   - Create new wallet or import existing (BIP39 24-word seed phrase)
   - Wallet generates a **Dilithium5** post-quantum key pair automatically
   - Your address starts with `LOS...` (52 characters)

2. **Tor Connection:**
   - First launch: Wallet downloads Tor Expert Bundle (~20MB, 1-2 min)
   - Subsequent launches: Tor starts in ~10 seconds
   - All traffic routes through Tor (.onion peers only)

3. **Testnet Faucet:**
   - Click "**Request Testnet LOS**" in the wallet
   - Receive 1,000 LOS for testing (rate limit: 1 request per address per hour)

4. **Send/Receive:**
   - Copy your address (top of screen) to receive
   - Use "Send" tab to transfer LOS to other addresses
   - Transactions finalize in ~2-5 seconds (aBFT consensus)

### LOS Validator Dashboard
1. **Setup Wizard:**
   - Import validator keys or generate new ones
   - Min stake: **1,000 LOS** required to register as validator

2. **Start Node:**
   - Click "**START NODE**" — the bundled `los-node` binary launches automatically
   - Tor auto-downloads (~1-2 min on first run)
   - Node generates a unique `.onion` address for P2P networking

3. **Register Validator:**
   - Click "**REGISTER VALIDATOR**" in the dashboard
   - Requires 1,000 LOS stake + small transaction fee
   - Validator becomes active in the next epoch (~10 min)

4. **Monitor:**
   - Dashboard shows: blocks produced, peers, uptime, reward earnings
   - Current epoch, countdown to next reward distribution
   - Slashing penalties (if any)

---

## 🔥 Proof-of-Burn (ETH/BTC → LOS)

The testnet supports **Proof-of-Burn** to acquire LOS:

1. **Navigate to "Burn" tab** in the wallet
2. **Choose:** ETH or BTC
3. **Send funds** to the burn address shown (use **testnet** faucets for free test ETH/BTC)
4. **Submit proof** (transaction hash) via the wallet
5. **Receive LOS** at 1:1 rate after 6 confirmations

**Testnet Burn Addresses:**
- ETH Burn: `0x000000000000000000000000000000000000dEaD`
- BTC Burn: `1BitcoinEaterAddressDontSendf59kuE`

**Note:** For testnet, use Sepolia (ETH) or Bitcoin Testnet faucets to get free test coins.

---

## 🌐 Network Info

| Property | Value |
|---|---|
| **Network** | Tor Hidden Services (.onion) exclusively |
| **Consensus** | aBFT (Asynchronous Byzantine Fault Tolerance) |
| **Block Time** | ~2-5 seconds finality |
| **Epoch Duration** | ~10 minutes (100 blocks) |
| **Token Name** | LOS (Lattice Of Sovereignty) |
| **Atomic Unit** | CIL (1 LOS = 100,000,000,000 CIL) |
| **Testnet Supply** | 21,936,236 LOS (fixed, same as mainnet) |
| **Min Validator Stake** | 1,000 LOS |
| **Faucet Limit** | 1,000 LOS per address per hour |

### Bootstrap Peers (Auto-configured)
The wallet and validator automatically connect to testnet peers via Tor:
- `peer1.onion:4001`
- `peer2.onion:4001`
- `peer3.onion:4001`
- `peer4.onion:4001`

**No manual Tor setup required** — the apps handle everything automatically.

---

## ❓ FAQ

### 1. **Do I need to install Tor manually?**
**No.** The wallet and validator auto-download Tor Expert Bundle from torproject.org on first launch. No configuration needed.

### 2. **Is the testnet secure?**
Yes, the testnet uses the same **Dilithium5 post-quantum cryptography** and **aBFT consensus** as mainnet. However, testnet tokens have **no real value**.

### 3. **Can I run multiple validators on one machine?**
Yes, but each validator needs a unique port:
- Validator 1: Default ports (3030 REST, 4001 P2P)
- Validator 2: Set custom ports via node control options

### 4. **What happens if my validator goes offline?**
- **≥95% uptime required** to earn rewards
- Offline validators are marked as inactive after 2 epochs
- **Slashing:** Persistent downtime may result in stake penalties (not yet active on testnet)

### 5. **How do I backup my wallet?**
- **BIP39 Seed Phrase:** 24 words shown during wallet creation
- **Write it down** and store securely (paper, not digital)
- Can restore wallet on any device with the seed phrase

### 6. **Windows/Linux: "Tor download failed"?**
If auto-download fails (firewall/antivirus), manually install Tor:
- **Linux:** `sudo apt install tor` or download from [torproject.org](https://www.torproject.org/download/)
- **Windows:** Download [Tor Expert Bundle](https://dist.torproject.org/torbrowser/), extract to `C:\Tor\`

Then restart the wallet/validator — it will detect system Tor automatically.

---

## 🐛 Troubleshooting

### Wallet/Validator won't start
- **macOS:** Delete `~/Library/Application Support/los-*` and restart
- **Linux:** Delete `~/.local/share/los-*` and restart
- **Windows:** Delete `%APPDATA%\\los-*` and restart

### "Insufficient balance" error
- Use the **Testnet Faucet** in the wallet to get 1,000 LOS
- Wait 10-15 seconds for transaction to finalize
- Check balance via "Account" tab

### Tor connection stuck at "Bootstrapping"
- Check firewall: Allow outbound connections on port 9050/9150
- On Linux: Ensure `libglib2.0-0` is installed (`sudo apt install libglib2.0-0`)
- On Windows: Disable Windows Firewall temporarily to test

### Validator not earning rewards
- Verify registration: Dashboard → Validators tab → Check "Status: Active"
- Min stake requirement: 1,000 LOS
- Uptime requirement: ≥95% online time per epoch
- Wait 1-2 epochs (~20 min) for rewards to appear

---

## 📚 Additional Resources

- **API Documentation:** [docs/API_REFERENCE.md](docs/API_REFERENCE.md)
- **Validator Guide:** [docs/VALIDATOR_GUIDE.md](docs/VALIDATOR_GUIDE.md)
- **Tor Setup (Advanced):** [docs/TOR_SETUP.md](docs/TOR_SETUP.md)
- **Whitepaper:** [docs/WHITEPAPER.md](docs/WHITEPAPER.md)
- **GitHub Releases:** [https://github.com/monkey-one/unauthority-core/releases](https://github.com/monkey-one/unauthority-core/releases)

---

## 💬 Community & Support

- **GitHub Issues:** [Report bugs](https://github.com/monkey-one/unauthority-core/issues)
- **Discussions:** [Feature requests & Q&A](https://github.com/monkey-one/unauthority-core/discussions)

**Happy Testing!** 🎉
