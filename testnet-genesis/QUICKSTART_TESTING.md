# QUICK START: Testing Testnet Wallets

## ✅ JAWABAN PERTANYAAN KAMU

### 1. Apakah validator ada switch testnet/mainnet?
**Ya!** NetworkSwitcher sudah ditambahkan ke header validator dashboard (sebelah kiri tombol Send).

### 2. Apakah bisa testnet dengan genesis khusus?
**Ya!** Sudah dibuat 11 testnet wallets dengan seed phrase yang **PUBLICLY KNOWN** (hanya untuk testing).

---

## 🔧 CARA TEST IMPORT PRIVATE KEY/SEED PHRASE

### Testnet Wallets yang Tersedia

**File:** `testnet-genesis/testnet_wallets.json`  
**Dokumentasi:** `testnet-genesis/README_TESTNET.md`

### Seed Phrases untuk Testing (PUBLIK - TESTNET ONLY)

#### 1. Treasury Wallet #1 (paling mudah untuk test)
```
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

#### 2. Validator Node A (untuk test validator)
```
node node node node node node node node node node node alpha
```

#### 3. Simple Test Wallet
```
test test test test test test test test test test test junk
```

---

## 📱 CARA TEST DI FRONTEND WALLET

1. **Buka Unauthority Wallet app**
2. **Pastikan Network: "UAT Testnet"** (dropdown di header)
3. **Klik "Import Existing Wallet"**
4. **Pilih "Seed Phrase (12 or 24 words)"**
5. **Paste salah satu seed phrase di atas**, contoh:
   ```
   abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
   ```
6. **Klik "Import"**
7. **✅ Seharusnya berhasil import!**

### Test Import Private Key
1. **Buka file testnet wallets:**
   ```bash
   cat testnet-genesis/testnet_wallets.json | jq '.[0]'
   ```
2. **Copy private key** (contoh: `5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1`)
3. **Di app, pilih "Import with Private Key"**
4. **Paste private key**
5. **✅ Import berhasil!**

---

## 🖥️ CARA TEST DI VALIDATOR DASHBOARD

1. **Buka Unauthority Validator app**
2. **Setup Wizard muncul → Pilih "Import Existing Keys"**
3. **Paste validator seed phrase:**
   ```
   node node node node node node node node node node node alpha
   ```
4. **ATAU paste private key dari:**
   ```bash
   cat testnet-genesis/testnet_wallets.json | jq '.[8].private_key'
   ```
5. **Klik "Import & Start Node"**
6. **✅ Validator wallet imported!**

---

## 🔍 VERIFIKASI

### Cek Address yang Di-Generate

Seed phrase `abandon abandon...` harus menghasilkan:
- **Address:** `UATEHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o`
- **Public Key:** `c5785e1865b708938aff8161d573006496663b1aa10834e396dc566869a2c66a`

Jika address sama = **wallet import bekerja dengan benar!**

---

## 🌐 NETWORK SWITCHING

### Di Frontend Wallet:
- **Testnet:** localhost:3030 (default untuk testing)
- **Mainnet:** rpc.unauthority.io (production - belum deploy)

### Di Validator Dashboard:
- **Testnet:** localhost:3030-3032 (3 validators local)
- **Mainnet:** validator.unauthority.io (production - future)

**Cara Switch:**
1. Lihat dropdown di header (sebelah kiri status indicator)
2. Klik dropdown
3. Pilih "UAT Testnet" atau "UAT Mainnet"

---

## ⚠️ SECURITY REMINDER

**Testnet Wallets = PUBLIC (zero security)**
- ✅ Boleh di-share untuk testing
- ✅ Seed phrase boleh di-commit ke git
- ✅ Private key boleh di-screenshot
- ❌ **JANGAN pakai untuk mainnet!**
- ❌ **JANGAN simpan UAT production di sini!**

**Mainnet Wallets = PRIVATE (full security)**
- ✅ Generate fresh random wallet
- ✅ Simpan seed phrase offline (paper/hardware wallet)
- ✅ Jangan screenshot private key
- ✅ Jangan share seed phrase

---

## 🚀 TESTING SCENARIOS

### Scenario 1: Import Seed Phrase di Wallet
```bash
# Open wallet app
# Switch to testnet
# Import with seed: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
# Expected: Success, address = UATEHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o
```

### Scenario 2: Import Private Key di Validator
```bash
# Open validator app
# Choose "Import Existing Keys" → "Private Key (Hex)"
# Paste: 5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1
# Expected: Success, no "Buffer is not defined" error
```

### Scenario 3: Network Switching
```bash
# Open wallet
# Current: "UAT Testnet" (green indicator = online if testnet running)
# Click dropdown → Select "UAT Mainnet"
# Expected: Red indicator = offline (mainnet belum deploy)
```

### Scenario 4: Send Transaction (Testnet)
```bash
# Import testnet wallet with balance
# Switch to testnet
# Send 100 UAT to another address
# Expected: Transaction broadcast ke localhost:3030
```

---

## 📊 ALL TESTNET WALLETS

| Index | Label | Seed Phrase (First 3 Words) | Balance (Genesis) |
|-------|-------|----------------------------|-------------------|
| 0 | TREASURY_1 | abandon abandon abandon | 2,000,000 UAT |
| 1 | TREASURY_2 | zoo zoo zoo | 2,000,000 UAT |
| 2 | TREASURY_3 | test test test | 2,000,000 UAT |
| 3 | TREASURY_4 | legal legal legal | 2,000,000 UAT |
| 4 | TREASURY_5 | art art art | 2,000,000 UAT |
| 5 | TREASURY_6 | work work work | 2,000,000 UAT |
| 6 | TREASURY_7 | hello hello hello | 2,000,000 UAT |
| 7 | TREASURY_8 | world world world | 1,397,000 UAT |
| 8 | NODE_A | node node node (alpha) | 1,000 UAT |
| 9 | NODE_B | node node node (bravo) | 1,000 UAT |
| 10 | NODE_C | node node node (charlie) | 1,000 UAT |

**Full seed phrases:** Lihat `testnet-genesis/README_TESTNET.md`

---

## 🛠️ COMMANDS

```bash
# Generate testnet wallets (sudah di-run, tapi bisa run lagi)
./scripts/generate_testnet_wallets.sh

# View all wallets
cat testnet-genesis/testnet_wallets.json | jq

# Get specific wallet
cat testnet-genesis/testnet_wallets.json | jq '.[0]'  # Treasury 1
cat testnet-genesis/testnet_wallets.json | jq '.[8]'  # Validator Node A

# Extract seed phrases only
cat testnet-genesis/testnet_wallets.json | jq -r '.[].seed_phrase'

# Extract private keys only
cat testnet-genesis/testnet_wallets.json | jq -r '.[].private_key'

# Deploy testnet (future - akan pakai wallets ini di genesis)
./scripts/deploy_testnet.sh
```

---

## ✅ TEST CHECKLIST

- [ ] Import seed phrase "abandon abandon..." di wallet → Success
- [ ] Import private key di validator → Success (no Buffer error)
- [ ] Network switcher visible di wallet header → Yes
- [ ] Network switcher visible di validator header → Yes
- [ ] Switch testnet → mainnet di wallet → Red indicator (offline)
- [ ] Switch testnet → mainnet di validator → Connection failed (expected)
- [ ] Address match: UATEHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o → Yes

---

**Last Updated:** $(date)
**Status:** Ready for Testing
**Security:** TESTNET ONLY - Public Wallets
