# Unauthority Public Wallet

**Burn BTC/ETH to Mint UAT - 100% Local, 100% Private**

Electron Desktop App for the Unauthority blockchain. Create wallets, burn Bitcoin/Ethereum to receive UAT tokens, and manage your crypto assets without any server or hosting.

## 🚀 Features

### ✅ Wallet Management
- **Create New Wallet**: Generate HD wallet with 12-word seed phrase (BIP39/BIP44)
- **Import Wallet**: From seed phrase or private key
- **Secure Storage**: Private keys never leave your device
- **UAT Address Format**: Human-readable "UAT..." addresses

### 🔥 Proof-of-Burn Distribution
- **Burn BTC or ETH**: Send to burn address, submit TXID
- **QR Code Generation**: Easy mobile wallet scanning
- **Oracle Price Consensus**: Fair USD-based valuation
- **Bonding Curve**: Early participants get more UAT (scarcity model)
- **Validator Verification**: Decentralized TXID verification

### 💸 Send & Receive
- **Fast Transfers**: <3 second finality (aBFT consensus)
- **Block-Lattice Architecture**: Each account has own chain
- **Real-time Balance**: Auto-refresh every 5 seconds
- **Transaction History**: Full audit trail

### 📊 Dashboard
- **Live Balance**: VOI and UAT format
- **Network Stats**: Total supply, remaining supply, burned amount
- **Oracle Prices**: Real-time BTC/ETH prices
- **Node Status**: Connection indicator

## 🛠️ Installation

### Prerequisites
- Node.js 18+ and npm
- Running Unauthority node (backend)

### Setup

```bash
# Navigate to wallet directory
cd frontend-wallet

# Install dependencies
npm install

# Development mode (with hot reload)
npm run dev

# Or run as Electron app
npm run electron:dev
```

### Build Standalone App

```bash
# Build for your platform
npm run electron:build

# Platform-specific builds
npm run electron:build:mac    # macOS (.dmg)
npm run electron:build:win    # Windows (.exe)
npm run electron:build:linux  # Linux (.AppImage)
```

Built apps will be in `dist/` folder.

## 🔌 Backend Connection

The wallet connects to your local Unauthority node:

```bash
API Endpoint: http://localhost:3030
```

**Start your node first:**

```bash
cd /path/to/unauthority-core
cargo build --release
./target/release/uat-node 3030
```

## 📖 Usage Guide

### 1. Create New Wallet

1. Click **"Create New Wallet"**
2. Write down your 12-word seed phrase on paper (**NEVER digitally**)
3. Store in safe place (safe, vault, etc.)
4. Confirm backup checkbox
5. Access your wallet

**⚠️ CRITICAL:** Loss of seed phrase = permanent loss of funds!

### 2. Burn BTC/ETH to Get UAT

1. Go to **"Burn to Mint"** tab
2. Select BTC or ETH
3. **Step 1:** Send coins to burn address (scan QR code or copy address)
4. Wait for blockchain confirmations (6+ for BTC, 12+ for ETH)
5. **Step 2:** Submit your transaction ID (TXID)
6. Validators verify burn automatically
7. UAT minted to your wallet

**Burn Addresses:**
- BTC: `1BitcoinEaterAddressDontSendf59kuE` *(example, check latest)*
- ETH: `0x000000000000000000000000000000000000dEaD`

**Pricing:**
- 1 UAT = $0.01 USD (starting price)
- Oracle consensus: CoinGecko, CryptoCompare, Kraken
- Bonding curve: Early burns get more UAT per dollar

### 3. Send UAT

1. Go to **"Send"** tab
2. Enter recipient UAT address
3. Enter amount
4. Click "Send UAT"
5. Transaction finalizes in <3 seconds

### 4. View History

- Go to **"History"** tab
- See all transactions (send, receive, burn)
- Refresh button for latest data

## 🔒 Security

### Privacy Features
- **100% Local Execution**: No data sent to any server
- **No Telemetry**: Zero tracking or analytics
- **Private Keys**: Never stored in plaintext
- **Seed Phrase**: User responsible for backup

### Best Practices
1. **Never share** seed phrase or private key
2. **Backup offline** (paper, steel plate)
3. **Verify addresses** before sending
4. **Test with small amounts** first
5. **Keep software updated**

### Warnings
- ⚠️ Unauthority team will **NEVER** ask for your seed phrase
- ⚠️ Burn transactions are **IRREVERSIBLE**
- ⚠️ Always verify burn address (phishing risk)
- ⚠️ Use hardware wallet for large amounts (future feature)

## 🏗️ Technical Architecture

### Stack
- **Frontend**: React 18 + TypeScript
- **UI Framework**: Tailwind CSS
- **Desktop**: Electron 28
- **Build Tool**: Vite
- **State Management**: Zustand
- **HD Wallet**: BIP39/BIP44 (tiny-secp256k1)
- **QR Codes**: qrcode.react
- **HTTP Client**: Axios

### Wallet Derivation
```
BIP39 Mnemonic (12 words)
  └─> BIP32 Seed
      └─> m/44'/236'/0'/0/0 (UAT coin type: 236)
          └─> Private Key + Public Key
              └─> UAT Address = "UAT" + base58check(pubkey_hash)
```

### API Endpoints Used
- `GET /balance/:address` - Get account balance
- `GET /node-info` - Network stats, oracle prices
- `POST /burn` - Submit burn transaction
- `POST /send` - Send UAT transfer
- `GET /history/:address` - Transaction history

## 📦 Project Structure

```
frontend-wallet/
├── src/
│   ├── components/
│   │   ├── WalletSetup.tsx      # Create/import wallet
│   │   ├── Dashboard.tsx        # Balance & wallet info
│   │   ├── BurnInterface.tsx    # PoB burn UI
│   │   ├── SendInterface.tsx    # Send transactions
│   │   └── HistoryView.tsx      # Transaction history
│   ├── utils/
│   │   ├── wallet.ts            # HD wallet generation
│   │   └── api.ts               # REST API client
│   ├── store/
│   │   └── walletStore.ts       # Zustand state
│   ├── App.tsx                  # Main app
│   └── main.tsx                 # React entry
├── electron/
│   └── main.js                  # Electron main process
├── package.json
└── README.md
```

## 🐛 Troubleshooting

### "Node Offline" Error
**Solution:** Start Unauthority node first
```bash
./target/release/uat-node 3030
```

### "Invalid Seed Phrase"
- Check for typos
- Ensure 12 words (not 24)
- Words must be from BIP39 wordlist

### Balance Not Updating
- Wait 5 seconds (auto-refresh)
- Click refresh button manually
- Check node is running

### Burn Transaction Failed
- Verify TXID is correct
- Wait for enough confirmations (6+ BTC, 12+ ETH)
- Check burn address matches exactly

## 🚀 Deployment Options

### Option 1: Electron Desktop App (RECOMMENDED)
- Download `.dmg` / `.exe` / `.AppImage` from releases
- Double-click to install
- 100% local, zero privacy risk

### Option 2: IPFS Hosting (Decentralized)
```bash
npm run build
# Upload dist/ folder to IPFS via Pinata
# Access via: gateway.ipfs.io/ipfs/Qm...
```

### Option 3: Self-Hosted
```bash
npm run build
cd dist
python3 -m http.server 8080
# Open: http://localhost:8080
```

## 📝 License

MIT License - See main repository

## ⚠️ Disclaimer

**USE AT YOUR OWN RISK**

- Unauthority is experimental blockchain technology
- Burning cryptocurrency is **irreversible**
- Always test with small amounts first
- Not financial advice
- No warranty or guarantee provided

---

**For technical support:** Check main repository issues  
**For security reports:** (security contact TBD)

Built with ❤️ for the Unauthority community
