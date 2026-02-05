# 🚀 DEPLOYMENT GUIDE - REMOTE TESTNET

## ✅ SEMUA PERBAIKAN SELESAI!

### 📦 Yang Sudah Diimplementasikan:

1. **✅ Mempool System** - Pending transactions dengan fee prioritization
2. **✅ Transaction Nonce** - Replay attack protection
3. **✅ HD Wallet (BIP44)** - Hierarchical Deterministic wallet support
4. **✅ WebSocket Server** - Real-time updates (port = REST+1000)
5. **✅ Automated Backups** - Hourly backups dengan compression
6. **✅ Rate Limiting** - 100 req/sec per IP
7. **✅ CORS Support** - Allow remote frontend access
8. **✅ Comprehensive Tests** - Unit & integration tests
9. **✅ Prometheus Metrics** - Production-ready monitoring
10. **✅ GitHub Actions** - Auto-build installers untuk semua platform

---

## 🌐 CARA DEPLOY REMOTE TESTNET

### 1. Build Backend

```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
cargo build --release
```

### 2. Start Node dengan Tor (Untuk Remote Access)

```bash
# Install Tor (macOS)
brew install tor

# Start Tor service
tor &

# Edit torrc config untuk hidden service
cat >> /usr/local/etc/tor/torrc << 'EOF'
HiddenServiceDir /usr/local/var/lib/tor/uat_testnet/
HiddenServicePort 80 127.0.0.1:3030
EOF

# Restart Tor
killall tor
tor &

# Get your .onion address
cat /usr/local/var/lib/tor/uat_testnet/hostname
# Output: xxxxxxxxxxxxxxxxxxxxx.onion
```

### 3. Start Validator Node

```bash
# Start node
./target/release/uat-node \
  --port 3030 \
  --api-port 3030 \
  --ws-port 4030 \
  --wallet node_data/validator-1/wallet.json

# Atau gunakan script
./scripts/launch_3_validators.sh
```

### 4. Verify Node Running

```bash
# Health check
curl http://localhost:3030/health | jq '.'

# Node info
curl http://localhost:3030/node-info | jq '.'

# WebSocket (gunakan wscat)
npm install -g wscat
wscat -c ws://localhost:4030
```

### 5. Share dengan Teman

Kirim ke teman:
- **Testnet RPC**: `http://your-onion-address.onion`
- **Download Wallet**: GitHub Releases (setelah push tag)

---

## 📱 CARA TEMAN INSTALL & CONNECT

### 1. Download & Install Wallet

```bash
# macOS
wget https://github.com/unauthoritymky-6236/unauthority-core/releases/download/v1.0.0/Unauthority-Wallet-1.0.0.dmg
open Unauthority-Wallet-1.0.0.dmg

# Windows
# Download Unauthority-Wallet-Setup-1.0.0.exe dari GitHub Releases
# Double click untuk install

# Linux
wget https://github.com/unauthoritymky-6236/unauthority-core/releases/download/v1.0.0/Unauthority-Wallet-1.0.0.AppImage
chmod +x Unauthority-Wallet-1.0.0.AppImage
./Unauthority-Wallet-1.0.0.AppImage
```

### 2. Setup Tor Browser

```bash
# Download Tor Browser
https://www.torproject.org/download/

# Open Tor Browser, wait untuk connect
```

### 3. Connect Wallet ke Testnet

1. Open Wallet app
2. Go to **Settings → Network**
3. Select **Custom RPC**
4. Enter: `http://your-onion-address.onion`
5. Click **Test Connection** → Should show "✅ Connected"
6. Click **Save & Reconnect**

### 4. Create Wallet & Request Faucet

1. Click **Create New Wallet**
2. Save seed phrase (24 words)
3. Go to **Faucet** tab
4. Click **Request 100 UAT** (available setiap 1 jam)
5. Wait ~3 seconds untuk confirmation

---

## 🚀 RELEASE GITHUB INSTALLERS

### 1. Push Code ke GitHub

```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core

# Add all changes
git add .
git commit -m "feat: Production-ready testnet with mempool, nonce, HD wallet, websocket, backups"

# Push ke main branch
git push origin main
```

### 2. Create Release Tag

```bash
# Tag version
git tag v1.0.0

# Push tag (ini akan trigger GitHub Actions)
git push origin v1.0.0
```

### 3. Monitor GitHub Actions

```bash
# Go to GitHub repo
https://github.com/unauthoritymky-6236/unauthority-core/actions

# Wait 20-30 minutes untuk build semua platform:
# - macOS wallet & validator (.dmg)
# - Windows wallet & validator (.exe)
# - Linux wallet & validator (.AppImage)
```

### 4. Download Installers

```bash
# Setelah build selesai, download dari:
https://github.com/unauthoritymky-6236/unauthority-core/releases/tag/v1.0.0

# Share link ini ke teman!
```

---

## 🧪 TESTING DENGAN TEMAN

### Scenario 1: Send Transaction

**You (Validator):**
```bash
# Check your address
curl http://localhost:3030/whoami | jq '.address'
```

**Friend (Wallet User):**
```
1. Request faucet (100 UAT)
2. Send 10 UAT to your address
3. Check transaction in History tab
```

**You (Verify):**
```bash
# Check balance
curl http://localhost:3030/balance/YOUR_ADDRESS | jq '.'

# Check mempool
curl http://localhost:3030/mempool | jq '.'

# Check latest block
curl http://localhost:3030/block | jq '.'
```

### Scenario 2: WebSocket Real-time

**Friend (Wallet App):**
```javascript
// Wallet otomatis connect ke WebSocket
// Akan receive real-time updates:
// - New blocks
// - Balance updates
// - Transaction notifications
```

**You (Monitor):**
```bash
# Connect via wscat
wscat -c ws://localhost:4030

# Will receive JSON events:
# {"type":"NewBlock","data":{"hash":"...","height":100,"transactions":5}}
# {"type":"BalanceUpdate","data":{"address":"UAT...","balance":1000}}
```

---

## 📊 MONITORING

### Prometheus Metrics

```bash
# Access metrics
curl http://localhost:3030/metrics

# Metrics include:
# - uat_blocks_total
# - uat_transactions_total
# - uat_mempool_size
# - uat_balance_total
# - uat_validators_count
# - uat_network_peers
```

### Health Check

```bash
# Automated health monitoring
while true; do
  curl -s http://localhost:3030/health | jq '.status'
  sleep 30
done
```

### Backup Status

```bash
# List backups
ls -lh backups/validator-1/

# Backup files:
# backup_20260205_120000.tar.gz
# backup_20260205_130000.tar.gz
# ... (24 hourly backups)
```

---

## 🐛 TROUBLESHOOTING

### Port Already in Use

```bash
# Check ports
lsof -i :3030 -i :4030

# Kill process
lsof -ti :3030 | xargs kill -9
```

### Tor Not Working

```bash
# Check Tor status
curl --socks5-hostname localhost:9050 https://check.torproject.org/api/ip

# Restart Tor
killall tor
tor &
```

### WebSocket Connection Failed

```bash
# Check WebSocket port
nc -zv localhost 4030

# Check firewall
sudo ufw allow 4030/tcp
```

### Backup Failed

```bash
# Check disk space
df -h

# Check backup directory permissions
ls -ld backups/validator-1/
chmod 755 backups/validator-1/
```

---

## 📝 PRODUCTION CHECKLIST

- [x] Mempool implemented
- [x] Transaction nonce (replay protection)
- [x] HD wallet (BIP44)
- [x] WebSocket server
- [x] Automated backups (hourly)
- [x] Rate limiting (100 req/sec)
- [x] CORS configured
- [x] Comprehensive tests
- [x] Prometheus metrics
- [x] GitHub Actions (auto-release)
- [x] Dev docs removed
- [x] Production logging
- [x] Error handling
- [x] Security hardening

---

## 🎉 STATUS: 100% READY FOR TESTNET

**Next Steps:**
1. Push code → GitHub
2. Tag release → v1.0.0
3. Wait GitHub Actions → Build installers
4. Share .onion address + installer links → Teman
5. Test transactions → Verify network works
6. Monitor metrics → Ensure stability
7. Collect feedback → Iterate

**Selamat! Blockchain kamu siap untuk remote testing! 🚀**
