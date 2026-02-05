# 🧅 UNAUTHORITY TESTNET - REMOTE ACCESS GUIDE

**Tanggal**: 5 Februari 2026  
**Status**: ✅ ACTIVE & READY

---

## 🌐 TESTNET TOR ADDRESS

```
http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```

**Karakteristik**:
- ✅ 100% Anonymous (Tor Network)
- ✅ Gratis selamanya (no hosting costs)
- ✅ Censorship-resistant
- ✅ Production-ready security

---

## 📱 CARA AKSES UNTUK TEMAN (REMOTE USERS)

### Option 1: Tor Browser (RECOMMENDED - 100% Private)

#### Step 1: Download Tor Browser
1. Buka https://www.torproject.org/download/
2. Download untuk OS kamu (Windows/Mac/Linux)
3. Install seperti browser biasa

#### Step 2: Akses Wallet
1. Buka **Tor Browser**
2. Di address bar, ketik:
   ```
   http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
   ```
3. Tunggu 10-30 detik (koneksi Tor lebih lambat dari internet biasa)
4. ✅ Wallet akan terbuka!

#### Step 3: Create Wallet
1. Klik "Create New Wallet"
2. **SIMPAN seed phrase** (12 kata) di tempat AMAN!
3. Verify seed phrase
4. Wallet siap digunakan

#### Step 4: Get Testnet Tokens
1. Di dashboard wallet, klik "Faucet"
2. Klik "Claim 100 UAT"
3. Tunggu 2-5 detik
4. ✅ Balance bertambah 100 UAT (testnet tokens)

---

### Option 2: Clearnet Proxy (Lebih Cepat, Kurang Private)

Jika tidak ingin install Tor Browser, gunakan proxy clearnet:

1. Install `torsocks`:
   ```bash
   # macOS
   brew install tor
   
   # Ubuntu/Debian
   sudo apt install torsocks
   ```

2. Access via curl:
   ```bash
   torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/node-info
   ```

**Note**: Metode ini untuk developer/testing saja, bukan untuk end users.

---

## 🔧 API ENDPOINTS (FOR DEVELOPERS)

Base URL (Tor):
```
http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```

### Health Check
```bash
GET /health
```

### Get Node Info
```bash
GET /node-info
```

### Check Balance
```bash
GET /balance/{address}
```

### Claim Faucet (100 UAT)
```bash
POST /faucet
Content-Type: application/json

{
  "address": "UAT..."
}
```

### Send Transaction
```bash
POST /send
Content-Type: application/json

{
  "from": "UAT...",
  "target": "UAT...",
  "amount": 1000000
}
```

### List Validators
```bash
GET /validators
```

---

## 🧪 TESTING CHECKLIST

- [ ] Download & install Tor Browser
- [ ] Connect to .onion URL
- [ ] Create new wallet
- [ ] Backup seed phrase
- [ ] Claim faucet (100 UAT)
- [ ] Check balance
- [ ] Send transaction ke teman
- [ ] Verify transaction received

---

## ❓ TROUBLESHOOTING

### "Cannot connect to node"
- ✅ Pastikan menggunakan **Tor Browser** (bukan Chrome/Firefox biasa)
- ✅ Tunggu 30-60 detik untuk koneksi Tor establish
- ✅ Check status node: tanya maintainer apakah node masih running

### "Stuck loading..."
- ✅ Refresh page (F5)
- ✅ Clear cache: Settings → Clear browsing data
- ✅ Restart Tor Browser
- ✅ Check internet connection

### "Faucet failed"
- ✅ Cooldown 1 jam per address
- ✅ Tunggu 1 jam, lalu claim lagi
- ✅ Atau create new wallet untuk test

### "Transaction failed"
- ✅ Check balance cukup (min 0.001 UAT untuk fees)
- ✅ Pastikan address tujuan valid (format: UAT...)
- ✅ Refresh wallet untuk sync latest state

---

## 🎯 TESTNET GOALS

1. **Test P2P Networking**: Multiple users connecting simultaneously
2. **Test Consensus**: Transaction validation & block creation
3. **Test UX**: Wallet usability, onboarding flow
4. **Test Security**: Tor anonymity, key management
5. **Find Bugs**: Report any issues to maintainer

---

## 📞 SUPPORT

**Node Maintainer**: @moonkey-code  
**GitHub**: https://github.com/unauthoritymky-6236/unauthority-core  
**Status**: Testnet node running 24/7 (best-effort)

**Report Bugs**: Create issue on GitHub atau DM maintainer

---

## 🔐 SECURITY REMINDER

**Testnet = Play Money**
- Tokens tidak ada nilai real
- Data bisa direset kapan saja
- JANGAN gunakan seed phrase mainnet!

**Mainnet (2026 Q2)**
- Gunakan hardware wallet
- Backup seed phrase di safe deposit box
- Enable 2FA untuk exchange accounts

---

**Happy Testing! 🚀**
