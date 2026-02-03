# PROMPT MASTER: PROYEK BLOCKCHAIN UNAUTHORITY (UAT) - THE SOVEREIGN MACHINE (FINAL v9.0)

**Role:** Bertindaklah sebagai Senior Blockchain Architect dan Lead Developer dengan spesialisasi pada Distributed Systems, Game Theory, dan Cryptography.

**Misi:** Membangun blockchain "Unauthority" (UAT) yang 100% Immutable, Permissionless, dan Decentralized. Sistem ini harus tahan sensor, tidak memiliki fungsi "Admin Keys", dan memiliki ekonomi yang berkelanjutan tanpa inflasi supply.

---

## 1. IDENTITAS & SPESIFIKASI (CORE)
* **Nama Proyek:** Unauthority
* **Ticker:** UAT
* **Satuan Terkecil:** 1 UAT = 100.000.000 Void (VOI)
* **Total Supply:** 21.936.236 UAT (Fixed/Hard-coded). Tidak ada minting baru setelah genesis.
* **Struktur Data:** Block-Lattice (DAG) + Global State untuk Smart Contract.
* **Konsensus:** Asynchronous Byzantine Fault Tolerance (aBFT). Finalitas < 3 detik.
* **Kriptografi:** Post-Quantum Secure (CRYSTALS-Dilithium).

## 2. SMART CONTRACT & API (PERMISSIONLESS)
* **Engine:** Unauthority Virtual Machine (UVM) berbasis WASM.
* **Sifat:** Permissionless. Deploy kontrak tanpa whitelist/izin.
* **Bahasa:** Mendukung Rust, C++, AssemblyScript, dan Go.
* **API Access:** Full Node menyediakan REST API & gRPC lengkap untuk eksternal developer.

## 3. DISTRIBUSI OTOMATIS (93% PUBLIC - PURE DECENTRALIZED)
* **Alokasi Publik:** 20.400.700 UAT.
* **Mekanisme:** Proof-of-Burn (PoB).
* **Aset Diterima:** BTC & ETH (Desentralis Only).
* **Aset Ditolak:** USDT, USDC, XRP (Centralized Assets).
* **Rumus Kelangkaan:** Bonding curve yang membuat UAT semakin sulit didapat seiring sisa supply menipis.
* **Oracle:** Decentralized Medianizer Oracle.

## 4. MEKANISME ANTI-WHALE (KEADILAN JARINGAN)
* **Dynamic Fee Scaling:** Biaya gas naik eksponensial (x2, x4) jika satu alamat melakukan spamming transaksi dalam waktu singkat.
* **Validator Voting Cap (Quadratic Voting):**
    * Rumus: $VotingPower = \sqrt{TotalStake}$.
    * Tujuan: Mencegah satu entitas kaya menguasai konsensus (1 Node 1000 UAT < 10 Node 100 UAT).
* **Burn Limit per Block:** Membatasi jumlah UAT yang bisa didapat lewat PoB per blok waktu.

## 5. VALIDATOR REWARDS & EKONOMI (NON-INFLATIONARY)
* **Transaction Fees (Gas) as Reward:** 100% Biaya Gas diberikan kepada Validator yang memfinalisasi blok. Tidak ada koin baru (Fixed Supply).
* **Minimum Staking Requirement:** Untuk menjadi Validator aktif, node wajib mengunci (Stake) minimal 1.000 UAT.
* **Priority Tipping:** User dapat memberikan tip tambahan (Priority Fee) untuk prioritas transaksi.

## 6. KEAMANAN VALIDATOR NODE (INFRASTRUCTURE)
* **Sentry Node Architecture:**
    * *Validator Node (Private):* Terhubung ke Sentry via VPN/P2P terenkripsi. IP tersembunyi.
    * *Sentry Node (Public):* Shield publik menghadapi DDoS.
* **Automated Slashing:** Double Signing (Slash 100% & Ban) dan Extended Downtime (Slash 1%).
* **P2P Encryption:** Noise Protocol Framework untuk seluruh komunikasi antar node.

## 7. ALOKASI DEV & GENESIS (7% DEV)
* **Dev Supply:** 1.535.536 UAT (dibagi rata sampai habis untuk 8 wallet dev, lalu wallet ke 8 akan dikurangi 3000 UAT untuk 3 wallet node yang ,masing-masing akan diisi 1000 UAT).
* **Distribusi:** 11 Wallet Permanen (3 untuk Node Awal masing-masing berisi 1000 UAT yang diambil dari wallet dev yang ke 8, 8 untuk Treasury).
* **Zero Admin:** Tidak ada kunci admin atau fungsi "Pause" pada jaringan.

## 8. TUGAS DAN OUTPUT YANG DIMINTA - BACKEND
1. **Struktur Proyek:** Susun struktur direktori proyek Rust (Workspace architecture). ✅ COMPLETE
2. **Genesis Generator (genesis_generator.rs):** Buat script inisialisasi blok awal. Wajib generate 11 pasang Key (8 Dev + 3 Bootstrap Node) dan cetak ke terminal (sekali saja) agar bisa dicatat manual. ✅ COMPLETE
3. **Logic Validator Reward:** Tuliskan fungsi Rust tentang bagaimana biaya transaksi (Gas) dihitung dan ditransfer otomatis ke akun Validator. ✅ COMPLETE
4. **Konfigurasi Node (validator.toml):** Buat contoh file config yang memisahkan `public_sentry_addr` dan `private_signer_addr`. ✅ COMPLETE
5. **REST API & gRPC:** Implement 13 REST endpoints + 8 gRPC services untuk akses eksternal. ✅ COMPLETE
6. **Smart Contract Engine (UVM):** WASM-based dengan wasmer runtime. ✅ COMPLETE
7. **Consensus (aBFT):** Asynchronous Byzantine Fault Tolerance <3 detik. ✅ COMPLETE
8. **Anti-Whale Mechanisms:** Dynamic fee scaling, quadratic voting, burn limits. ✅ COMPLETE

---

## 9. FRONTEND REQUIREMENTS (USER INTERFACE LAYER)

**REQUIREMENT:** Dua frontend dibutuhkan untuk accessibility dan mass adoption.

### 9.1 VALIDATOR DASHBOARD (Node Operators)
**Tujuan:** UI untuk orang-orang yang menjalankan validator node (technical & semi-technical users).

**Technology Stack:**
- Framework: React.js atau Vue.js (TypeScript recommended)
- HTTP Client: Axios atau Fetch API
- State Management: Redux atau Pinia
- Styling: Tailwind CSS atau Material Design
- Build Tool: Vite atau Next.js
- Backend Connection: REST API calls ke localhost:3030+ atau gRPC

**Core Features:**
1. **Dashboard Overview**
   - Node status (running/offline)
   - Current block height & finality
   - Network statistics (total validators, total stake, APR)
   - Uptime percentage & slashing history

2. **Stake Management**
   - Display current stake (1,000 UAT minimum)
   - Option to increase/decrease stake
   - Delegation management
   - Reward claiming interface

3. **Rewards Tracking**
   - Historical reward collection
   - Gas fees earned per block
   - Real-time earning rate
   - Reward distribution chart

4. **Validator Configuration**
   - Display current config (ports, sentry address)
   - P2P peer monitoring (connected nodes)
   - IP/port settings UI
   - PSK key management

5. **Network Monitoring**
   - Active peer list with latency
   - Block propagation time
   - Transaction mempool size
   - Network health indicators

6. **Security & Alerts**
   - Double-signing detection
   - Downtime warnings
   - Slashing alerts
   - Backup reminders for private keys

**API Endpoints Used:**
- `GET /balance` - Validator stake balance
- `GET /peers` - Connected nodes
- `GET /block` - Current block info
- `GET /validators` - Active validator list
- `GET /node-info` - Node metadata
- `POST /send` - Stake delegation (if needed)

---

### 9.2 PUBLIC WALLET & BURN INTERFACE (For PoB Distribution)
**Tujuan:** UI untuk publik yang ingin membuat wallet dan burn BTC/ETH untuk mendapatkan UAT.

**Technology Stack:**
- Framework: React.js atau Vue.js (TypeScript)
- Web3 Integration: Ethers.js atau Web3.js (untuk memantau BTC/ETH)
- HD Wallet: BIP39/BIP44 library (@scure/bip39, @scure/bip32)
- QR Code: qrcode.react atau qr-code
- Styling: Tailwind CSS atau Material Design
- State Management: Context API atau Zustand
- Build Tool: Vite atau Next.js

**Core Features:**

1. **Wallet Management**
   - Create new wallet (HD wallet with seed phrase)
   - Import existing wallet (from private key/seed phrase)
   - Display wallet address (UAT format: "UAT...")
   - Show UAT balance in real-time
   - Multi-wallet support (import multiple addresses)

2. **Proof-of-Burn Interface**
   - Display QR code for BTC deposit address
   - Display QR code for ETH deposit address
   - Bonding curve calculator (show how much UAT for X BTC/ETH)
   - Instructions for burning BTC/ETH
   - Accepted assets: BTC, ETH (only decentralized)
   - Show current burn rate (updated from oracle)

3. **Transaction Tracking**
   - Monitor incoming BTC/ETH transactions
   - Real-time confirmation counting
   - Calculate UAT received per burn
   - Display when UAT will be credited
   - Historical burn records

4. **Balance & History**
   - Display total UAT balance
   - Transaction history (sent, received, burned)
   - Filter by transaction type
   - Export history to CSV

5. **Send & Receive**
   - Send UAT to another address
   - Generate receive address QR code
   - Copy address to clipboard
   - Transaction fee estimation

6. **Security Features**
   - Private key never leaves device (client-side only)
   - Optional password encryption for stored wallets
   - Seed phrase backup & verification
   - Warning for mainnet vs testnet
   - Hardware wallet support (future: Ledger/Trezor)

**API Endpoints Used:**
- `GET /balance/:address` - Get UAT balance
- `POST /send` - Send transaction
- `GET /block` - Verify burn confirmations
- `GET /account/:address` - Account details
- `GET /node-info` - Bonding curve & burn rates (from oracle)

---

## 10. DEPLOYMENT ARCHITECTURE (PRIVACY-FIRST)

### Production Deployment (Zero Server/Hosting Needed):

```
┌──────────────────────────────────────────────────────────────────┐
│                  UNAUTHORITY NETWORK (PERMISSIONLESS)            │
│                                                                  │
│  ┌──────────────┐      ┌──────────────────┐                     │
│  │  Validator   │      │  Full Node (RPC) │                     │
│  │   Nodes      │◄────►│                  │                     │
│  │ (3 Bootstrap)│      │ REST API:8080-82 │                     │
│  │              │      │ gRPC:50051+      │                     │
│  └──────────────┘      └────────┬─────────┘                     │
│                                 │ Public HTTP                   │
│                    ┌────────────┴────────────┬──────────────┐   │
│                    ▼                         ▼              ▼   │
│          ┌──────────────────┐      ┌────────────────┐  ┌──────┐ │
│          │ VALIDATOR        │      │ PUBLIC WALLET  │  │ IPFS │ │
│          │ DASHBOARD        │      │ BURN INTERFACE │  │ Web3 │ │
│          │                  │      │                │  │      │ │
│          │ Electron App     │      │ Electron App   │  │ CDN  │ │
│          │ (Downloads from  │      │ (Downloads     │  │      │ │
│          │  GitHub Release) │      │  from GitHub)  │  │      │ │
│          └──────────────────┘      └────────────────┘  └──────┘ │
│          For: Node Operators      For: General Public           │
│          100% Local Execution     100% Local Execution          │
│                                                                  │
│  ✅ NO SERVER NEEDED - ALL DATA LOCAL                           │
│  ✅ NO VPS/HOSTING - ZERO PRIVACY RISK                          │
│  ✅ NO DEV DATA EXPOSED - DECENTRALIZED ONLY                    │
└──────────────────────────────────────────────────────────────────┘
```

### Deployment Options (Choose One or Multiple):

**Option 1: Electron Desktop App (RECOMMENDED)**
- Users download `.exe` / `.dmg` / `.AppImage` from GitHub Releases
- App runs 100% locally on user's computer
- Connects only to public Full Nodes (REST API)
- Zero hosting needed
- Zero privacy risk

**Option 2: IPFS/Web3 Hosting (DECENTRALIZED)**
- Upload static build to IPFS (via Pinata/Nft.storage)
- Files stored immutable across global network
- Users access via `gateway.ipfs.io/ipfs/QmXxx...`
- No centralized server
- Free tier available

**Option 3: Self-Hosted by User**
- Users clone GitHub repo locally
- Run `npm run build` → open `dist/index.html`
- OR run simple HTTP server: `python3 -m http.server`
- 100% user control
- Best for technical users

---

## 11. INTEGRATION REQUIREMENTS

**Authentication & Security:**
- REST API calls authenticated via JWT tokens (if private endpoints)
- Public endpoints (balance, blocks) remain public
- Frontend runs locally, no authentication needed for localhost:3030

**Error Handling:**
- Handle node connection failures gracefully
- Show appropriate error messages to users
- Retry logic for API calls

**Real-Time Updates:**
- WebSocket support for live balance updates (optional)
- Polling fallback: update every 5-10 seconds
- Show "last updated" timestamp

---

## 12. DEVELOPMENT PRIORITIES

**Phase 1: Validator Dashboard (MUST HAVE)**
- Priority: HIGH (enables node operators to manage stakes)
- Timeline: 2-3 weeks
- Dependencies: REST API (already complete)

**Phase 2: Public Wallet Interface (MUST HAVE)**
- Priority: HIGH (enables public participation in PoB)
- Timeline: 3-4 weeks
- Dependencies: REST API, bonding curve oracle

**Phase 3: Network Explorer (NICE TO HAVE)**
- Block explorer UI
- Transaction history
- Validator list & stats
- Timeline: 4+ weeks