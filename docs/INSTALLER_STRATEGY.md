# Frontend Installer Strategy - Universal App (1 Version)

## ❌ TIDAK Perlu 2 Versi (Testnet vs Mainnet)

### Rekomendasi: **1 Installer Universal**

Seperti MetaMask, Phantom, atau wallet crypto lainnya, **UAT Wallet cukup 1 app** yang bisa switch network.

---

## ✅ Implementasi Network Switcher

### 1. Network Configuration
File: `frontend-wallet/src/config/networks.ts`

```typescript
export const NETWORKS = {
  testnet: {
    id: 'testnet',
    name: 'UAT Testnet',
    chainId: 'uat-testnet',
    rpcUrl: 'http://localhost:3030',
    faucetEnabled: true,
    description: 'Local testnet for development'
  },
  mainnet: {
    id: 'mainnet',
    name: 'UAT Mainnet',
    chainId: 'uat-mainnet',
    rpcUrl: 'https://rpc.unauthority.io',
    faucetEnabled: false,
    description: 'Production network with real UAT'
  }
};
```

### 2. Network Switcher Component
File: `frontend-wallet/src/components/NetworkSwitcher.tsx`

**Features:**
- 🔄 Switch between Testnet/Mainnet
- 🟢 Real-time connection status (Online/Offline/Checking)
- 💾 Save preference to localStorage
- 🧪 Test connection button
- 💧 Faucet badge for testnet

**UI Preview:**
```
┌─────────────────────────────────────────┐
│ Network              🟢 Connected       │
├─────────────────────────────────────────┤
│ ▼ UAT Testnet (Testnet)                │
│   UAT Mainnet (Mainnet)                 │
├─────────────────────────────────────────┤
│ RPC: http://localhost:3030              │
│ Local testnet for development           │
│                                         │
│ 💧 Faucet: 100,000 UAT per request     │
│                                         │
│ [Test Connection]                       │
└─────────────────────────────────────────┘
```

---

## 📦 Build Process (1 Installer)

### Build Commands
```bash
cd frontend-wallet

# macOS (.dmg)
npm run electron:build  # Output: dist/Unauthority-Wallet-1.0.0.dmg

# Windows (.exe) - requires Windows or Wine
npm run build:win      # Output: dist/Unauthority-Wallet-Setup-1.0.0.exe

# Linux (.AppImage)
npm run build:linux    # Output: dist/Unauthority-Wallet-1.0.0.AppImage
```

### Installer Details
- **Name:** Unauthority Wallet
- **Version:** 1.0.0
- **Default Network:** Testnet (safe for first-time users)
- **App ID:** `io.unauthority.wallet`
- **Size:** 
  - macOS: ~120 MB
  - Windows: ~100 MB
  - Linux: ~130 MB

---

## 🎯 User Experience Flow

### First Launch
1. User downloads **1 installer** (e.g., `Unauthority-Wallet-1.0.0.dmg`)
2. Opens app → sees **Network Switcher** at top
3. Default: **UAT Testnet** (safe)
4. Can request 100k UAT from faucet
5. Test transactions

### Switch to Mainnet
1. Click dropdown: "UAT Testnet (Testnet)" → "UAT Mainnet (Mainnet)"
2. App automatically:
   - Saves preference to localStorage
   - Connects to `https://rpc.unauthority.io`
   - Disables faucet button
   - Shows warning: "⚠️ You are on MAINNET - transactions use real UAT"

### Network Verification
- On app start: `GET /node-info` to verify RPC
- Check `chain_id` field:
  - `"uat-testnet"` → Testnet
  - `"uat-mainnet"` → Mainnet
- If mismatch: Show warning modal

---

## ✅ Benefits of 1 Universal Installer

| Benefit | Description |
|---------|-------------|
| **Simpler** | Users don't need to choose which installer to download |
| **Consistent** | Same UI/UX for testnet and mainnet |
| **Flexible** | Developers can add custom RPC endpoints |
| **Standard** | Follows industry practice (MetaMask, Phantom, etc.) |
| **Maintainable** | 1 codebase to update, not 2 |

---

## 🚫 Why NOT 2 Separate Installers?

| Problem | Impact |
|---------|--------|
| **User Confusion** | "Which one should I download?" |
| **Duplication** | 2x maintenance effort |
| **Disk Space** | Users testing both = 2 apps installed |
| **Updates** | Need to update 2 apps separately |
| **Non-Standard** | No major crypto wallet does this |

---

## 🔐 Security Considerations

### Network Validation
```typescript
// Before every transaction, verify network
const nodeInfo = await fetch(`${rpcUrl}/node-info`);
const { chain_id } = await nodeInfo.json();

if (chain_id !== expectedChainId) {
  throw new Error('Network mismatch! Expected ${expectedChainId}, got ${chain_id}');
}
```

### Warning Modals
- **Switching to Mainnet:** "⚠️ Transactions will use real UAT tokens. Are you sure?"
- **Sending on Mainnet:** "🔴 MAINNET: This transaction is irreversible"
- **Network Mismatch:** "❌ Connected to wrong network. Expected Testnet but RPC returned Mainnet"

---

## 📊 Current Build Status

### ✅ Completed
- [x] Network configuration file
- [x] NetworkSwitcher component
- [x] localStorage persistence
- [x] Connection verification
- [x] Build scripts (package.json)

### 🔄 In Progress
- [ ] macOS .dmg build (downloading Electron 28.3.3 - 95 MB)

### ⏳ Pending
- [ ] Windows .exe build (requires Windows machine)
- [ ] Linux .AppImage build (requires Linux machine)
- [ ] Code signing (macOS: Developer ID, Windows: Authenticode)

---

## 📝 Final Recommendation

**Build 1 universal installer** with:
- ✅ Network switcher UI
- ✅ Testnet default (safe)
- ✅ Easy mainnet toggle
- ✅ Network verification
- ✅ Warning modals

**Do NOT build:**
- ❌ Unauthority-Wallet-Testnet-1.0.0.dmg
- ❌ Unauthority-Wallet-Mainnet-1.0.0.dmg

This follows industry standard and provides better UX.
