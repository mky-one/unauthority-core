# 🌐 Public User Deployment Guide

## 🎯 2 Cara Untuk User Public Akses UAT

### 📦 Cara 1: Desktop App (Mac/Windows/Linux) - RECOMMENDED

**Untuk User Public:**
```
1. Download installer:
   - Mac: Unauthority-Wallet-1.0.0.dmg
   - Windows: Unauthority-Wallet-Setup-1.0.0.exe
   - Linux: Unauthority-Wallet-1.0.0.AppImage

2. Install dan buka aplikasi

3. App sudah built-in SOCKS proxy untuk akses Tor

4. Automatic connect ke testnet .onion ✅
```

**Keuntungan:**
- ✅ One-click install
- ✅ Built-in Tor proxy (tidak perlu Tor Browser)
- ✅ Langsung bisa akses .onion
- ✅ Better UX, native feel

**Cara Build Installer:**
```bash
# Build Mac DMG
cd frontend-wallet
npm run dist

# Build Windows EXE
npm run dist:win

# Build Linux AppImage
npm run dist:linux
```

---

### 🌐 Cara 2: Web Version (Browser) - UNTUK DEVELOPMENT/TESTING

**Untuk User Public:**

#### Option A: Localhost Testing (Local Node)
```
1. User install UAT node locally:
   curl -sSL https://get.unauthority.xyz/install.sh | bash

2. Node running di localhost:3030

3. User buka browser:
   https://wallet.unauthority.xyz

4. Web app connect ke localhost:3030 ✅
```

**Setup:**
- Deploy frontend ke hosting (Vercel/Netlify)
- User set network = "Local Node" di settings
- API endpoint = http://localhost:3030

#### Option B: Remote Testnet via Tor Browser
```
1. User install Tor Browser:
   https://www.torproject.org/download/

2. User buka Tor Browser

3. Akses web app:
   - Via clearnet: https://wallet.unauthority.xyz
   - Via .onion: http://[your-onion-address].onion

4. Web app auto-connect ke remote testnet .onion ✅
```

**Setup:**
- Deploy frontend ke hosting dengan .onion support
- Or host .onion hidden service untuk frontend
- Default network = "Remote Testnet (.onion)"

---

## 🔧 Current Setup Status

### ✅ Yang Sudah Jalan

**Local Dev Environment:**
```
✅ Backend: 3 validators (localhost:3030-3032)
✅ Frontend Vite: localhost:5173, 5176
✅ Desktop Apps: Built-in Tor SOCKS proxy
✅ API: .onion address configured
```

**Testing:**
```
✅ Mac Desktop App → .onion testnet (working)
✅ Tor Browser → localhost:5173 → .onion API (working)
❌ Chrome/Safari → localhost:5173 → .onion API (tidak bisa - normal!)
```

---

## 📊 Deployment Strategy Untuk Public

### Phase 1: Testnet Launch (Current)
```
Target User: Early testers, developers

Distribution:
├─ Desktop Apps (DMG/EXE/AppImage)
│  └─ Built-in Tor proxy
│  └─ Default: Remote Testnet (.onion)
│
└─ Web Version (Optional)
   └─ Hosted at: wallet.unauthority.xyz
   └─ User needs: Tor Browser OR Local node
```

### Phase 2: Mainnet Launch (Q2 2026)
```
Target User: General public

Distribution:
├─ Desktop Apps (Primary)
│  └─ Mac App Store / Windows Store
│  └─ Direct download
│  └─ Built-in Tor for privacy
│
├─ Web Version (Secondary)
│  └─ Hosted clearnet + .onion
│  └─ Connect to local node
│  └─ Or public RPC nodes
│
└─ Mobile Apps (Future)
   └─ iOS / Android
   └─ Orbot integration for Tor
```

---

## 🚀 Untuk Public Launch: Step by Step

### Step 1: Build Desktop Installers
```bash
# Mac
cd frontend-wallet
npm run dist
# Output: dist/Unauthority-Wallet-1.0.0.dmg

cd ../frontend-validator
npm run dist
# Output: dist/Unauthority-Validator-1.0.0.dmg
```

### Step 2: Upload ke GitHub Releases
```bash
# Tag release
git tag v1.0.0-testnet
git push origin v1.0.0-testnet

# Upload installers ke GitHub Releases
# User download dari: https://github.com/yourorg/unauthority-core/releases
```

### Step 3: Setup Web Hosting (Optional)
```bash
# Deploy frontend ke Vercel/Netlify
cd frontend-wallet
vercel deploy --prod

# Or setup .onion hidden service
# For fully anonymous web access
```

### Step 4: Documentation untuk User
```
Create user guides:
├─ INSTALLATION.md (Mac/Windows/Linux)
├─ GETTING_STARTED.md (First time setup)
├─ TESTNET_GUIDE.md (How to get test UAT)
└─ FAQ.md (Common issues)
```

---

## 🔐 Security Considerations

### Desktop Apps (Electron)
```
✅ Built-in Tor SOCKS proxy
✅ No external dependencies
✅ Private key stays local
✅ Encrypted storage
✅ Auto-update mechanism
```

### Web Version
```
⚠️  Depends on Tor Browser (user must install)
⚠️  OR requires local node (localhost:3030)
⚠️  Cannot access .onion in normal browser
✅ Same encryption as desktop
✅ Private keys in localStorage (encrypted)
```

### Recommendation
**For public launch: Desktop apps as PRIMARY distribution method.**

Web version = optional for advanced users with:
- Local node running, OR
- Tor Browser installed

---

## 📝 Current Testing Scenario

**Yang Kamu Test Sekarang:**
```
Setup:
├─ Backend validators: localhost:3030-3032 ✅
├─ Frontend Vite: localhost:5173 ✅
├─ Desktop App: Built-in SOCKS → .onion ✅
└─ Tor Browser: localhost:5173 → .onion ✅

Testing:
1. Desktop App (Mac) → Direct ke .onion ✅
2. Tor Browser → localhost:5173 (Vite) → .onion ✅
3. Chrome biasa → localhost:5173 → .onion ❌ (expected)
```

**Kesimpulan:**
- Desktop app = production-ready untuk .onion ✅
- Web version = butuh Tor Browser untuk .onion ✅
- Chrome biasa = hanya untuk localhost testing

---

## 🎯 Answer: "User Public Mau Jalankan Versi Web Gimana?"

### Jawaban Singkat:
**User public ada 3 pilihan:**

1. **Desktop App (BEST)**
   - Download DMG/EXE
   - Install
   - Langsung jalan dengan .onion ✅
   - Tidak perlu Tor Browser

2. **Web + Tor Browser**
   - Install Tor Browser
   - Buka https://wallet.unauthority.xyz di Tor Browser
   - Bisa akses .onion testnet ✅

3. **Web + Local Node**
   - Install UAT node locally
   - Node jalan di localhost:3030
   - Buka https://wallet.unauthority.xyz di browser biasa
   - Set network = "Local Node" ✅
   - Connect ke localhost, bukan .onion

---

## 🔧 What's Running Now

```bash
# Check processes
ps aux | grep -E "uat-node|vite|electron"

# Should see:
✅ uat-node 3030 (Backend validator)
✅ uat-node 3031 (Backend validator)
✅ uat-node 3032 (Backend validator)
✅ vite --port 5173 (Wallet web dev)
✅ vite --port 5176 (Validator web dev)
✅ Electron (Desktop apps - if launched)
```

**Access Points:**
- Tor Browser → http://localhost:5173 ✅ (sekarang sudah jalan!)
- Desktop App → Direct launch ✅ (built-in Tor)
- Chrome biasa → http://localhost:5173 ❌ (tidak bisa ke .onion - normal)

---

**Summary**: Untuk public users, desktop app adalah cara terbaik. Web version butuh Tor Browser atau local node. Testing sekarang: gunakan Tor Browser untuk akses localhost:5173!
