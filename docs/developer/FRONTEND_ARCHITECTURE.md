# 🎨 UNAUTHORITY FRONTEND ARCHITECTURE & REQUIREMENTS

**Date:** February 3, 2026  
**Status:** Planning Phase  
**Priority:** Critical for mass adoption

---

## 📊 CURRENT STATE vs REQUIREMENTS

### Current (Implemented)
- ✅ Backend: Rust blockchain with REST API + gRPC
- ✅ Node Operation: CLI-based (`cargo run --config validator.toml`)
- ✅ Developer Access: REST/gRPC endpoints available
- ❌ User-Friendly UI: **NOT IMPLEMENTED**
- ❌ Non-Technical Access: **BLOCKED**

### Required for Production
- ⏳ **Validator Dashboard** - UI for node operators to monitor/manage stakes
- ⏳ **Public Wallet & Burn UI** - Interface for users to create wallets & burn BTC/ETH for UAT

---

## 🎯 FRONTEND #1: VALIDATOR DASHBOARD

### Target Users
- Node operators (people running validator nodes)
- Mix of technical and semi-technical users
- Need: Visual monitoring & stake management

### Core Responsibilities
1. Connect to validator node REST API (localhost:3030+)
2. Display node status, stake, rewards, peers
3. Manage validator configuration
4. Track slashing & downtime
5. Claim rewards

### Technology Stack
```
Frontend Framework:  React.js or Vue.js (TypeScript recommended)
Build Tool:         Vite or Next.js
State Management:   Redux or Pinia
UI Library:         Tailwind CSS or Material Design
API Client:         Axios (REST calls)
Real-time:          WebSocket or polling (5-10 sec)
Port:              localhost:5173 (dev) or custom production port
```

### Feature Breakdown

#### 1️⃣ Dashboard Overview
```
┌─────────────────────────────────────────────────┐
│ VALIDATOR DASHBOARD - Node Status              │
├─────────────────────────────────────────────────┤
│                                                  │
│ 🟢 Node Status: RUNNING                         │
│ 📊 Block Height: 45,231 | Finality: 2.8s      │
│ 💰 Stake: 1,000 UAT (1 validator)              │
│ 📈 APR: 12.5% | YTD Rewards: 145.23 UAT      │
│ ⏱️  Uptime: 99.98% | Slashing: None           │
│                                                  │
├─────────────────────────────────────────────────┤
│ Network: 3 Active Validators | 3,000 UAT Total│
│ Next Block: ~2s | Difficulty: 2.1M            │
└─────────────────────────────────────────────────┘
```

**API Calls:**
- `GET /node-info` - Get node metadata
- `GET /block` or `GET /latest-block` - Current block
- `GET /balance` - Validator stake
- `GET /validators` - All active validators

#### 2️⃣ Stake Management
```
┌─────────────────────────────────────────────────┐
│ STAKE MANAGEMENT                                │
├─────────────────────────────────────────────────┤
│                                                  │
│ Current Stake: 1,000 UAT                        │
│ Minimum Allowed: 1,000 UAT (locked)           │
│ Rewards Earned: 145.23 UAT (claimable)         │
│                                                  │
│ [Increase Stake] [Decrease Stake] [Claim $$]  │
│                                                  │
│ Amount: [____________] UAT                     │
│ [CONFIRM] [CANCEL]                             │
│                                                  │
└─────────────────────────────────────────────────┘
```

**API Calls:**
- `GET /balance` - Get current stake
- `POST /send` - Send transaction (claim rewards)

#### 3️⃣ Rewards Tracking
```
Chart showing:
- Daily rewards collected
- Gas fees from transactions
- Historical APY
- Reward distribution per block
```

**API Calls:**
- `GET /block` - Check validator who earned block
- Query historical blocks to calculate rewards

#### 4️⃣ Network Monitoring
```
Connected Peers:
├─ Validator-1: /ip4/127.0.0.1/tcp/30333 (latency: 2ms)
├─ Validator-2: /ip4/127.0.0.1/tcp/30334 (latency: 3ms)
└─ Validator-3: /ip4/127.0.0.1/tcp/30335 (latency: 2ms)

Block Propagation: 45ms average
Mempool Size: 234 pending transactions
Network Health: 🟢 EXCELLENT
```

**API Calls:**
- `GET /peers` - Connected peers
- `GET /block` - Block propagation time

#### 5️⃣ Security & Alerts
```
⚠️ Warnings:
- Low storage: 2 GB remaining
- Downtime this epoch: 0s
- Slashing incidents: None

✅ Good to know:
- Private key last backed up: 2 days ago
- Next slashing check: 6h 42m
- Sentry node: HEALTHY
```

### Configuration Schema
```typescript
interface ValidatorDashboardConfig {
  nodeRestUrl: string;        // http://localhost:3030
  nodeGrpcUrl?: string;       // localhost:50051 (optional)
  refreshInterval: number;    // 5000 (ms)
  validatorAddress: string;   // UAT...
  theme: 'light' | 'dark';
  notifications: {
    slashing: boolean;
    downtime: boolean;
    rewards: boolean;
  }
}
```

---

## 🎨 FRONTEND #2: PUBLIC WALLET & BURN INTERFACE

### Target Users
- General public (non-technical)
- People wanting to participate in Proof-of-Burn distribution
- Need: Simple wallet + burn interface

### Core Responsibilities
1. Create/import wallets
2. Display UAT balance
3. Burn BTC/ETH for UAT
4. Track transactions
5. Send/receive UAT

### Technology Stack
```
Frontend Framework:  React.js or Vue.js (TypeScript)
Build Tool:         Vite or Next.js
Wallet Library:     BIP39 (HD wallets) + ethers.js/web3.js
QR Code:            qrcode.react
State Management:   Context API or Zustand
UI Library:         Tailwind CSS or Material Design
Storage:            Encrypted localStorage for wallets
Port:              localhost:5174 (dev) or custom production
```

### Feature Breakdown

#### 1️⃣ Wallet Creation & Import
```
┌─────────────────────────────────────────────────┐
│ CREATE WALLET                                    │
├─────────────────────────────────────────────────┤
│                                                  │
│ [New Wallet] [Import Wallet]                   │
│                                                  │
│ Seed Phrase (Write down & store safely):       │
│ abandon ability able about above absent         │
│ absolute absorb abstract abuse access          │
│ accident account accuse achieve acid acoustic  │
│                                                  │
│ ✅ I have written down my seed phrase         │
│                                                  │
│ Password (optional): [_______________]         │
│                                                  │
│ [CREATE WALLET]                                │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Logic:**
- Generate HD wallet using BIP39/BIP44
- Display seed phrase (BIP39 mnemonic)
- Optional password protection
- Store encrypted in localStorage
- Never send to backend

#### 2️⃣ Wallet Dashboard
```
┌─────────────────────────────────────────────────┐
│ MY WALLET                                        │
├─────────────────────────────────────────────────┤
│                                                  │
│ Address: UATc9ded817bf20a33a4696580df6adc4e  │
│ ✓ Copy | 🔗 Explorer                          │
│                                                  │
│ BALANCE: 125.50 UAT                           │
│          12,550,000,000 VOI                    │
│                                                  │
│ [Burn BTC/ETH] [Send UAT] [Receive]           │
│                                                  │
│ Recent Transactions:                            │
│ ├─ Received: +10 UAT (2 days ago)             │
│ ├─ Sent: -2.5 UAT (5 days ago)                │
│ └─ Burned BTC: +5.23 UAT (1 week ago)         │
│                                                  │
└─────────────────────────────────────────────────┘
```

**API Calls:**
- `GET /balance/:address` - Get balance
- `GET /account/:address` - Get account details

#### 3️⃣ Proof-of-Burn Interface
```
┌─────────────────────────────────────────────────┐
│ BURN CRYPTO FOR UAT                             │
├─────────────────────────────────────────────────┤
│                                                  │
│ Select Asset:                                   │
│ ◉ Bitcoin (BTC)  ○ Ethereum (ETH)             │
│                                                  │
│ Send to Address: 1A1z7agoat...8Yr7ad         │
│ 📱 [SHOW QR]                                  │
│                                                  │
│ Amount Tracker:                                 │
│ BTC Sent:  0 / ? (waiting for confirmations)  │
│                                                  │
│ Expected UAT: 0.00 (bonding curve: 0.0021)   │
│                                                  │
│ Note: Minimum 0.001 BTC / 0.01 ETH            │
│ Your Address: UATc9ded817bf20a...            │
│                                                  │
│ ℹ️ How it works:                              │
│ 1. Send BTC/ETH to address above              │
│ 2. We monitor the blockchain                  │
│ 3. UAT credited after 6 confirmations        │
│ 4. Rate determined by bonding curve           │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Features:**
- QR code for deposit address (using qrcode.react)
- Real-time BTC/ETH price monitoring
- Bonding curve calculator
- Confirmation tracker
- Accepted assets: BTC, ETH (decentralized only)
- Rejected: USDT, USDC, XRP

**API Calls:**
- `GET /node-info` - Get current bonding curve rate
- `GET /block` - Track burn confirmations
- Display format from oracle (via REST API)

#### 4️⃣ Send UAT
```
┌─────────────────────────────────────────────────┐
│ SEND UAT                                        │
├─────────────────────────────────────────────────┤
│                                                  │
│ To Address: [UATc9ded817bf...            ]     │
│ 📋 [PASTE]  🎯 [SCAN QR]                     │
│                                                  │
│ Amount: [10.50] UAT                          │
│                                                  │
│ Fee: 0.001 UAT                                │
│ Total: 10.501 UAT                             │
│                                                  │
│ Message (optional): [________________]         │
│                                                  │
│ [SEND] [CANCEL]                               │
│                                                  │
└─────────────────────────────────────────────────┘
```

**API Calls:**
- `POST /send` - Send transaction
- `GET /balance` - Update balance after send

#### 5️⃣ Receive UAT
```
┌─────────────────────────────────────────────────┐
│ RECEIVE UAT                                     │
├─────────────────────────────────────────────────┤
│                                                  │
│ Your Address: UATc9ded817bf20a33a4696...     │
│                                                  │
│ Share this QR code:                            │
│ ┌─────────────────────────┐                   │
│ │                         │                   │
│ │    [QR Code Image]      │                   │
│ │                         │                   │
│ └─────────────────────────┘                   │
│                                                  │
│ [Copy Address] [Share via Email/Message]      │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Configuration Schema
```typescript
interface WalletConfig {
  networkId: number;        // 1 (Unauthority mainnet)
  restUrl: string;          // https://api.uat.network
  oracleUrl?: string;       // For bonding curve
  theme: 'light' | 'dark';
  currency: 'UAT' | 'VOI';  // Display preference
  notifications: {
    transactions: boolean;
    burns: boolean;
    lowBalance: boolean;
  }
}

interface StoredWallet {
  address: string;
  encryptedSeed: string;    // Encrypted BIP39 seed
  publicKey: string;
  createdAt: timestamp;
  label?: string;           // User-given name
}
```

---

## 🏗️ Project Structure

```
unauthority-frontend/
├── validator-dashboard/               # Frontend #1
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── StakeManager.tsx
│   │   │   ├── RewardsChart.tsx
│   │   │   ├── PeerMonitor.tsx
│   │   │   └── Alerts.tsx
│   │   ├── services/
│   │   │   └── validatorApi.ts        # REST API calls
│   │   ├── types/
│   │   │   └── validator.ts
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
│
├── public-wallet/                     # Frontend #2
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── WalletDashboard.tsx
│   │   │   ├── CreateWallet.tsx
│   │   │   ├── ImportWallet.tsx
│   │   │   ├── BurnInterface.tsx
│   │   │   ├── SendTransaction.tsx
│   │   │   └── ReceiveUAT.tsx
│   │   ├── services/
│   │   │   ├── walletService.ts       # HD wallet generation
│   │   │   ├── uatApi.ts              # REST API calls
│   │   │   └── bondingCurve.ts        # Bonding curve calc
│   │   ├── types/
│   │   │   └── wallet.ts
│   │   ├── hooks/
│   │   │   ├── useWallet.ts
│   │   │   └── useBalance.ts
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
│
└── README.md
```

---

## 📋 Dependencies Reference

### Validator Dashboard
```json
{
  "react": "^18.2.0",
  "react-dom": "^18.2.0",
  "typescript": "^5.0.0",
  "axios": "^1.4.0",
  "recharts": "^2.7.0",         // Charts for rewards
  "zustand": "^4.3.0",          // State management
  "tailwindcss": "^3.3.0"        // Styling
}
```

### Public Wallet & Burn
```json
{
  "react": "^18.2.0",
  "react-dom": "^18.2.0",
  "typescript": "^5.0.0",
  "axios": "^1.4.0",
  "@scure/bip39": "^1.2.0",      // Seed phrase generation
  "@scure/bip32": "^1.3.0",      // HD wallet derivation
  "qrcode.react": "^1.0.0",      // QR code generation
  "ethers": "^6.4.0",            // Track ETH burns
  "zustand": "^4.3.0",           // State management
  "tailwindcss": "^3.3.0"        // Styling
}
```

---

## 🔐 Security Considerations

### Validator Dashboard
- ✅ Runs on localhost (no remote exposure during dev)
- ✅ Only reads node status (no sensitive data)
- ✅ JWT tokens for production (optional)
- ⚠️ Never expose private validator keys

### Public Wallet
- ✅ **Private keys NEVER leave device** (client-side only)
- ✅ **Seed phrases encrypted in localStorage**
- ✅ Optional password protection
- ✅ Clear warnings about security
- ✅ No backend wallet storage
- ⚠️ Recommend users to use hardware wallets (future integration)

---

## � Privacy-First Deployment Options

**CRITICAL PRINCIPLE:** Per Unauthority philosophy (100% Decentralized & Permissionless), NO centralized server or VPS needed.

### Option 1: ✅ **Desktop Application (RECOMMENDED)**
**Technology:** Electron (Node.js + Chromium wrapper)
**Deployment:** 
- Users download `.exe` / `.dmg` / `.AppImage` from GitHub Releases
- App runs 100% locally on user's machine
- Connects directly to public Full Nodes (via REST API)
- Zero data sent to dev servers

**Pros:**
- ✅ Maximum privacy (no hosting needed)
- ✅ No privacy risk - all data local
- ✅ Works offline (except when need to call REST API)
- ✅ Easy updates via GitHub releases
- ✅ Native file system access (for wallet backups)

**Cons:**
- ⚠️ Larger download (~200MB)
- ⚠️ Platform-specific builds needed (Windows, Mac, Linux)

**Build Steps:**
```bash
# Validator Dashboard
npm run build:validator-desktop  # → validator-dashboard-1.0.0.exe, .dmg, .AppImage

# Public Wallet
npm run build:wallet-desktop     # → uat-wallet-1.0.0.exe, .dmg, .AppImage
```

---

### Option 2: ✅ **Web3 Wallet Browser Extension**
**Technology:** Manifest V3 browser extension (like MetaMask)
**Deployment:**
- Upload to Chrome Web Store, Firefox Add-ons, Edge Add-ons (free)
- Users install as browser extension
- 100% local execution

**Pros:**
- ✅ No hosting needed
- ✅ Seamless browser integration
- ✅ Smaller download
- ✅ Auto-updates via store
- ✅ Great for casual users

**Cons:**
- ⚠️ Browser-only (not ideal for validators)
- ⚠️ Store approval process ~1-2 weeks

---

### Option 3: ✅ **Self-Hosted Static Site (User Runs Locally)**
**Technology:** React SPA bundled as static HTML/CSS/JS
**Deployment:**
- Users clone GitHub repo
- Run `npm run build` locally → static files in `dist/`
- Users open `dist/index.html` in browser (no server needed!)
- OR host on their own machine: `python -m http.server 8080`

**Pros:**
- ✅ Zero hosting cost
- ✅ 100% user control
- ✅ Source code transparent (open-source audit)
- ✅ Works on any OS (just need Node.js)

**Cons:**
- ⚠️ Requires technical knowledge
- ⚠️ Not ideal for non-technical users

**Setup:**
```bash
# User runs locally
git clone https://github.com/unauthority/validator-dashboard.git
cd validator-dashboard
npm install && npm run build

# Either:
# Option A: Open in browser directly
open dist/index.html

# Option B: Serve locally (no internet needed!)
python3 -m http.server 8080
# Visit: http://localhost:8080
```

---

### Option 4: ✅ **IPFS/Web3 Hosting (Decentralized CDN)**
**Technology:** IPFS (InterPlanetary File System) or Arweave
**Deployment:**
- Build static site → upload to IPFS (via Pinata, Nft.storage, etc - FREE tier available)
- Users access via: `https://gateway.ipfs.io/ipfs/QmXxxx...` 
- OR use: `https://ipfs.io/ipfs/QmXxxx...`
- NO server needed - files distributed globally

**Pros:**
- ✅ No server/VPS needed
- ✅ Files immutable (can't be modified)
- ✅ Decentralized distribution
- ✅ Works if internet censored
- ✅ FREE (Pinata free tier: 1GB)

**Cons:**
- ⚠️ Slightly slower than CDN
- ⚠️ Need to re-pin if update (new IPFS hash)

**Setup:**
```bash
# Upload to IPFS (Pinata)
npm run build
# Then drag dist/ folder to Pinata.cloud
# Get IPFS hash: QmXxxx...
# Users access at: pinata.cloud/ipfs/QmXxxx...
```

---

### Option 5: ✅ **Hybrid: Desktop + GitHub Releases**
**BEST FOR SECURITY CONSCIOUS DEVS**

**Deployment:**
1. Build Electron app locally (on air-gapped machine if paranoid)
2. Sign with dev certificate
3. Push `.exe` / `.dmg` / `.AppImage` to GitHub Releases (free)
4. Users download & verify signature
5. Run locally with no internet (except REST API calls)

**Pros:**
- ✅ Maximum privacy
- ✅ No hosting at all
- ✅ Signature verification (users can verify dev authenticity)
- ✅ Automatic updates via GitHub

**Deployment Flow:**
```
Dev builds Electron app locally
    ↓
Signs with dev certificate (e.g., Apple Dev Certificate)
    ↓
Uploads to GitHub Releases
    ↓
User downloads .dmg / .exe / .AppImage
    ↓
User verifies signature (optional but recommended)
    ↓
App runs 100% locally
    ↓
App connects to public Full Nodes (REST API only)
```

---

## �🚀 Development Timeline

### Phase 1: Validator Dashboard (3-4 weeks)
- Week 1: Setup, API integration, basic dashboard
- Week 2: Stake management, rewards tracking
- Week 3: Network monitoring, alerts
- Week 4: Testing, polishing, documentation

### Phase 2: Public Wallet & Burn (4-5 weeks)
- Week 1: Setup, HD wallet generation, import
- Week 2: Burn interface, BTC/ETH tracking
- Week 3: Send/receive UAT functionality
- Week 4: Transaction history, security
- Week 5: Testing, polishing, mainnet readiness

### Phase 3: Network Explorer (Optional, 4+ weeks)
- Block explorer
- Transaction details
- Validator statistics
- Rich list

---

## ✅ Acceptance Criteria

### Validator Dashboard DONE when:
- [ ] Connects to REST API successfully
- [ ] Displays node status, block height, balance
- [ ] Shows active peer list with latency
- [ ] Tracks rewards accumulated per block
- [ ] Manages stake (increase/decrease)
- [ ] Shows uptime & slashing status
- [ ] All forms are responsive & mobile-friendly
- [ ] Error handling for API failures
- [ ] Tests pass (80%+ coverage)

### Public Wallet DONE when:
- [ ] Create wallet (BIP39 seed phrase)
- [ ] Import wallet (from seed/private key)
- [ ] Display UAT balance in real-time
- [ ] Burn BTC/ETH with QR code
- [ ] Track burn confirmations
- [ ] Send/receive UAT
- [ ] Transaction history with filters
- [ ] All responsive & mobile-friendly
- [ ] Private keys stay on device
- [ ] Tests pass (80%+ coverage)

---

## 📞 Integration Points

**Backend Endpoints Needed:**
```
GET  /balance              - User/validator balance
GET  /account/:address     - Account details
GET  /block                - Current block info
GET  /latest-block         - Latest finalized block
GET  /validators           - All active validators
GET  /peers                - Connected peers
GET  /node-info            - Node metadata & oracle data
GET  /blocks/:height       - Block by height
POST /send                 - Send transaction

(All endpoints already exist in REST API!)
```

---

## 🔐 Privacy & Security Model

**No Centralized Server Needed:**
- App connects directly to **Public Full Nodes** (decentralized)
- User wallets stored **locally only** (client-side)
- Private keys **NEVER leave device**
- No login required (address-based only)
- No user data collected/stored anywhere

**Connection Flow:**
```
User's App (Validator Dashboard or Wallet)
    ↓
Connects to: http://node1.unauthority.com:8080 (Public Full Node)
    ↓
GET /balance?address=UAT... 
POST /send (signed transaction)
    ↓
No data sent to dev servers (except REST API calls)
    ↓
User has full privacy ✅
```

---

## 📋 RECOMMENDED DEPLOYMENT FOR UAT

**Primary:** ✅ **Electron Desktop App** (Option 1)
- Build once, run anywhere (Windows/Mac/Linux)
- All data stays local
- Smallest privacy attack surface
- Best user experience for validators

**Secondary:** ✅ **IPFS Hosting** (Option 4)
- For users who prefer web access
- Decentralized, no server risk
- Immutable (can't be hacked)

**Tertiary:** ✅ **GitHub Releases** (Option 5)
- Self-hosted by dev team
- Users can verify signatures
- Zero hosting cost

---

**Status:** Ready for development  
**Next Step:** Choose deployment strategy (recommend Option 1 + Option 4) → assign frontend team → start Phase 1 (Validator Dashboard)
