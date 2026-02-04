# FAQ: Installer Frontend UAT

## ❓ Pertanyaan 1: Apakah bisa generate .dmg/.exe/.AppImage?

### Jawaban:
**Sebagian bisa, sebagian tidak:**

| Platform | File | Status | Requirement |
|----------|------|--------|-------------|
| macOS | `.dmg` | ✅ **BISA** | Kamu di macOS, bisa build langsung |
| Windows | `.exe` | ❌ **TIDAK** | Butuh Windows machine atau Wine + osslsigncode |
| Linux | `.AppImage` | ❌ **TIDAK** | Butuh Linux machine (Ubuntu/Debian) |

### Yang Sudah Dikerjakan:
```bash
cd frontend-wallet
npm run electron:build  # Started, tapi di-cancel manual
```

**Proses:**
1. ✅ TypeScript compile berhasil
2. ✅ Vite build berhasil (1.85s)
3. ✅ electron-builder mulai packaging
4. 🔄 Download Electron 28.3.3 (95 MB) → **Interrupted**

**Untuk melanjutkan:**
```bash
cd frontend-wallet
npm run electron:build  # Akan menghasilkan .dmg di dist/
```

**Expected output:**
```
dist/
  ├── Unauthority-Wallet-1.0.0.dmg  (macOS installer)
  └── mac-arm64/                     (app bundle)
```

---

## ❓ Pertanyaan 2: Apakah installer harus 2 versi (Testnet & Mainnet)?

### Jawaban: ❌ **TIDAK PERLU 2 VERSI**

### Rekomendasi: **1 Installer Universal + Network Switcher**

---

## ✅ Implementasi yang Benar

### Arsitektur:
```
┌───────────────────────────────────────────────────┐
│  Unauthority-Wallet-1.0.0.dmg (1 file saja)      │
└───────────────────────────────────────────────────┘
                    │
                    ↓
        ┌───────────────────────┐
        │   UAT Wallet App      │
        │  ┌─────────────────┐  │
        │  │ Network Switcher│  │
        │  │  ▼ Testnet      │  │ ← User pilih
        │  │    Mainnet      │  │
        │  └─────────────────┘  │
        └───────────────────────┘
                    │
        ┌───────────┴────────────┐
        ↓                        ↓
┌──────────────┐        ┌──────────────┐
│   Testnet    │        │   Mainnet    │
│ localhost:   │        │ rpc.unauth   │
│ 3030         │        │ ority.io     │
│ Faucet: ✅   │        │ Faucet: ❌   │
└──────────────┘        └──────────────┘
```

### File yang Sudah Dibuat:

1. **Network Config** (`src/config/networks.ts`):
```typescript
export const NETWORKS = {
  testnet: {
    id: 'testnet',
    name: 'UAT Testnet',
    rpcUrl: 'http://localhost:3030',
    faucetEnabled: true
  },
  mainnet: {
    id: 'mainnet',
    name: 'UAT Mainnet',
    rpcUrl: 'https://rpc.unauthority.io',
    faucetEnabled: false
  }
};
```

2. **Network Switcher Component** (`src/components/NetworkSwitcher.tsx`):
- Dropdown untuk switch network
- Connection status indicator (🟢/🔴/🟡)
- Test connection button
- Faucet badge untuk testnet
- LocalStorage untuk save preference

---

## 📊 Perbandingan: 1 vs 2 Installer

### ✅ 1 Installer Universal (RECOMMENDED)

**Keuntungan:**
- User tidak bingung mau download yang mana
- Gampang switch testnet ↔ mainnet (1 click)
- Konsisten dengan industry standard (MetaMask, Phantom, Trust Wallet)
- Maintenance lebih mudah (1 codebase)
- Updates sekali untuk semua network

**Cara Kerja:**
```
User Download → 1 File (.dmg)
              ↓
         Install App
              ↓
    Launch → Default: Testnet (safe)
              ↓
    Want Mainnet? → Click dropdown → Select Mainnet
              ↓
         Done! (preference saved)
```

---

### ❌ 2 Installer Terpisah (NOT RECOMMENDED)

**Kalau dibuat 2 versi:**
- Unauthority-Wallet-Testnet-1.0.0.dmg
- Unauthority-Wallet-Mainnet-1.0.0.dmg

**Masalah:**
1. **User confusion:** "Eh yang mana ya yang harus didownload?"
2. **Duplicate effort:** Update fitur = build 2 kali
3. **Disk space:** User testing both = 2 apps installed (240 MB)
4. **Non-standard:** Tidak ada wallet crypto yang pakai cara ini
5. **Switching network:** User harus uninstall & reinstall app lain
6. **Risk:** User salah download (mau testnet, malah mainnet)

---

## 🌍 Industry Standard Reference

**Semua wallet crypto besar pakai 1 installer:**

| Wallet | Networks Supported | Installer Count |
|--------|-------------------|-----------------|
| MetaMask | Ethereum Mainnet, Sepolia, Goerli, Polygon, BSC, etc. | **1** |
| Phantom | Solana Mainnet, Devnet, Testnet | **1** |
| Trust Wallet | 70+ chains (mainnet + testnet) | **1** |
| Coinbase Wallet | Ethereum, Base, Polygon, etc. | **1** |

**Tidak ada yang buat:**
- ❌ MetaMask-Mainnet.exe
- ❌ MetaMask-Testnet.exe
- ❌ Phantom-Devnet.dmg

---

## 🔐 Security dengan Network Switcher

### Network Verification (Auto)
```typescript
// Sebelum setiap transaksi
const nodeInfo = await fetch(`${rpcUrl}/node-info`);
const { chain_id } = await nodeInfo.json();

if (chain_id !== expectedChainId) {
  alert('⚠️ Network mismatch detected!');
}
```

### Warning Modals
1. **Switch ke Mainnet:**
   ```
   ⚠️ You are switching to MAINNET
   
   Transactions will use REAL UAT tokens.
   Make sure you know what you're doing.
   
   [Cancel]  [I Understand, Proceed]
   ```

2. **Send di Mainnet:**
   ```
   🔴 MAINNET TRANSACTION
   
   You are about to send 100 UAT on MAINNET.
   This transaction is IRREVERSIBLE.
   
   [Cancel]  [Confirm Send]
   ```

3. **Network Mismatch:**
   ```
   ❌ Network Configuration Error
   
   Expected: UAT Testnet
   Detected: UAT Mainnet
   
   Please check your RPC endpoint.
   ```

---

## 📝 Final Recommendation

### ✅ DO THIS:
```bash
# Build 1 universal installer
cd frontend-wallet
npm run electron:build

# Output:
# dist/Unauthority-Wallet-1.0.0.dmg  (Universal)
```

**Features:**
- Network switcher UI (dropdown)
- Default: Testnet (safe for beginners)
- Easy mainnet toggle (1 click)
- LocalStorage persistence
- Connection verification
- Warning modals

### ❌ DON'T DO THIS:
```bash
# Jangan build 2 versi terpisah:
npm run build:testnet   # ❌ NO
npm run build:mainnet   # ❌ NO
```

---

## 🚀 Next Steps

1. **Continue .dmg Build:**
   ```bash
   cd frontend-wallet
   npm run electron:build
   ```
   Expected time: 2-5 minutes (download + packaging)

2. **Test Installer:**
   ```bash
   # Mount .dmg
   open dist/Unauthority-Wallet-1.0.0.dmg
   
   # Drag to Applications
   # Launch app
   # Test network switcher
   ```

3. **Windows/Linux:**
   - Requires separate machines OR
   - Use GitHub Actions CI/CD (build all platforms)

---

**Kesimpulan:**
- ✅ .dmg bisa dibangun di macOS (sedang dalam proses)
- ✅ 1 installer universal JAUH LEBIH BAIK daripada 2 versi
- ✅ Network Switcher sudah diimplementasi
- ✅ Mengikuti industry standard (MetaMask, Phantom, etc.)
