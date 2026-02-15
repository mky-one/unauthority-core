# 🧅 Unauthority Testnet — Bootstrap Node Information

**Status:** ✅ **ONLINE** (Fresh Start — Genesis Block)  
**Launch Date:** February 15, 2026  
**Network:** Tor Hidden Services (.onion) exclusively

---

## 📡 Bootstrap Validators (All 4 Online)

| ID | Tor API Endpoint (.onion) | P2P Port |
|----|---------------------------|----------|
| **Validator 1** | `http://drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion` | 4001 |
| **Validator 2** | `http://kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion` | 4001 |
| **Validator 3** | `http://w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion` | 4001 |
| **Validator 4** | `http://xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion` | 4001 |

**Note:** All validators host their own Tor hidden services. No clearnet access.

---

## 🔗 Peer Discovery Bootstrap List

**For Flutter Wallet / Validator Dashboard:**

Add this to your `network_config.json` or use it in the app settings:

```json
{
  "bootstrap_peers": [
    "drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion:4001",
    "kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion:4001",
    "w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion:4001",
    "xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion:4001"
  ],
  "tor_socks_proxy": "socks5h://127.0.0.1:9050"
}
```

**For los-node CLI:**

```bash
export LOS_BOOTSTRAP_NODES="drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion:4001,kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion:4001,w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion:4001,xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion:4001"

los-node --port 3030 --data-dir ~/.los-node --node-id my-validator
```

---

## 🌐 Network Configuration

| Property | Value |
|----------|-------|
| **Chain ID** | `los-testnet` |
| **Consensus** | aBFT (Asynchronous Byzantine Fault Tolerance) |
| **Block Time** | ~2-5 seconds finality |
| **Epoch Duration** | ~10 minutes (100 blocks) |
| **Min Validator Stake** | 1,000 LOS |
| **Total Supply** | 21,936,236 LOS (fixed) |
| **Genesis Accounts** | 6 (2 Dev Treasury + 4 Bootstrap Nodes) |

---

## 🔐 Genesis Allocation

| Address | Role | Balance (LOS) |
|---------|------|---------------|
| **Dev Treasury 1** | Funding | 428,113 LOS |
| **Dev Treasury 2** | Operations | 245,710 LOS |
| **Bootstrap Node 1** | Validator | 1,000 LOS |
| **Bootstrap Node 2** | Validator | 1,000 LOS |
| **Bootstrap Node 3** | Validator | 1,000 LOS |
| **Bootstrap Node 4** | Validator | 1,000 LOS |
| **Public Distribution** | Faucet / PoB | 21,258,413 LOS |

---

## 🚀 How to Join the Testnet

### Option 1: Flutter Wallet (GUI)

1. **Download:** [Latest Release](https://github.com/monkey-one/unauthority-core/releases/tag/wallet-v1.0.8-testnet) (macOS/Linux/Windows)
2. **Install & Launch** (Tor auto-downloads on first run)
3. **Request Testnet LOS:** Click "Faucet" in wallet → Get 1,000 LOS (1 per address/hour)
4. **Connect:** Wallet auto-discovers bootstrap peers via Tor

### Option 2: Flutter Validator Dashboard (GUI + Node)

1. **Download:** [Latest Release](https://github.com/monkey-one/unauthority-core/releases/tag/validator-v1.0.10-testnet) (includes bundled `los-node` binary)
2. **Install & Launch**
3. **Import/Generate Keys**
4. **Click "START NODE"** → Dashboard launches bundled validator binary
5. **Register as Validator:** Requires 1,000 LOS stake

### Option 3: los-node CLI (Headless)

```bash
# Clone repo
git clone https://github.com/monkey-one/unauthority-core.git
cd unauthority-core

# Build
cargo build --release -p los-node

# Run with bootstrap peers
export LOS_BOOTSTRAP_NODES="drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion:4001,kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion:4001,w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion:4001,xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion:4001"
export LOS_TESTNET_LEVEL="consensus"

./target/release/los-node \
  --port 3030 \
  --data-dir ~/.los-node \
  --node-id my-validator
```

**Note:** Ensure Tor is running on your system (e.g., `brew install tor && tor`).

---

## 🧪 Test the Network

### Check Bootstrap Node Health

**Via Tor (using your local Tor SOCKS proxy):**

```bash
# Using curl with Tor SOCKS5
curl -x socks5h://127.0.0.1:9050 \
  http://drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "chain": {
    "id": "los-testnet",
    "blocks": 0,
    "accounts": 6
  },
  "version": "1.0.9"
}
```

### Check Peer List

```bash
curl -x socks5h://127.0.0.1:9050 \
  http://drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion/peers
```

Should show 4 validators with `.onion` addresses.

---

## 🎁 Testnet Faucet

**Via Wallet GUI:** Click "Request Testnet LOS" button → Get 1,000 LOS instantly.

**Via API:**
```bash
curl -X POST -x socks5h://127.0.0.1:9050 \
  http://drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion/faucet \
  -H "Content-Type: application/json" \
  -d '{"address": "LOSYourAddressHere..."}'
```

**Rate Limit:** 1,000 LOS per address per hour.

---

## 📚 Documentation

- **[Testnet Quick Start](TESTNET_QUICKSTART.md)** — Installation guide for wallet & validator
- **[API Reference](docs/API_REFERENCE.md)** — All 33+ REST endpoints
- **[Validator Guide](docs/VALIDATOR_GUIDE.md)** — Technical validator setup
- **[Tor Setup](docs/TOR_SETUP.md)** — Advanced Tor configuration
- **[Platform Notes](PLATFORM_NOTES.md)** — Windows/Linux/macOS specific issues

---

## 🐛 Issues or Questions?

- **GitHub Issues:** [Report bugs](https://github.com/monkey-one/unauthority-core/issues)
- **GitHub Discussions:** [Ask questions](https://github.com/monkey-one/unauthority-core/discussions)

---

**Happy Testing!** 🎉

_This testnet is for development and testing only. Testnet LOS tokens have no real-world value._
