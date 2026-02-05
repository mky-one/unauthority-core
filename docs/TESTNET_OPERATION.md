# 🌐 Testnet Operation Guide

## ✅ Testnet Status: **LIVE ON TOR**

**Official .onion Address:**  
```
http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```

---

## 🚀 Quick Start: Menjalankan Testnet

### **Opsi 1: Koneksi ke Testnet Public (Recommended)**

Testnet sudah running 24/7 di Tor. Kamu hanya perlu connect:

#### **A. Via Tor Browser (Paling Mudah)**
1. Download [Tor Browser](https://www.torproject.org)
2. Buka Wallet Desktop/Web
3. Go to **Settings** → **Network**
4. Masukkan: `http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion`
5. Klik **Test Connection** → **Save & Reconnect**

#### **B. Via CLI (Developer)**
```bash
# Install Tor
brew install tor  # macOS
sudo apt install tor  # Linux
# Windows: Download Tor Expert Bundle

# Test koneksi
torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/node-info

# Response:
# {"node_id":"UAT...","version":"1.0.0","chain":"Unauthority",...}
```

---

### **Opsi 2: Jalankan Node Lokal + Connect ke Testnet**

Jika kamu ingin run validator atau full node sendiri:

#### **Step 1: Clone & Build**
```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core
cargo build --release -p uat-node
```

#### **Step 2: Start Node**
```bash
# Start as validator
./target/release/uat-node \
  --port 3030 \
  --api-port 3030 \
  --ws-port 9030 \
  --wallet node_data/validator-1/wallet.json

# Or use quick script
./scripts/launch_3_validators.sh
```

#### **Step 3: Connect ke Testnet Tor**

Node akan otomatis detect testnet jika ada `~/.tor-unauthority/`:

```bash
# Check connection
curl http://localhost:3030/node-info
curl http://localhost:3030/peers

# Should show connection to .onion peers
```

---

### **Opsi 3: Deploy Testnet Sendiri (Advanced)**

Jika kamu ingin deploy testnet sendiri dengan Tor Hidden Service:

```bash
# One-command deployment
./scripts/setup_tor_mainnet.sh

# Manual steps:
# 1. Generate genesis
cd genesis && cargo run --release

# 2. Configure Tor
mkdir -p ~/.tor-unauthority/hidden_service
cat > ~/.tor-unauthority/torrc << EOF
DataDirectory ~/.tor-unauthority/data
HiddenServiceDir ~/.tor-unauthority/hidden_service
HiddenServicePort 80 127.0.0.1:3030
EOF

# 3. Start Tor daemon
tor -f ~/.tor-unauthority/torrc &

# 4. Get .onion address
cat ~/.tor-unauthority/hidden_service/hostname

# 5. Start node
./target/release/uat-node --port 3030 --api-port 3030
```

---

## 🔍 Verifikasi Testnet Running

### **Check Node Status**
```bash
# Local node
curl http://localhost:3030/health
# {"status":"healthy","version":"1.0.0"}

# Testnet via Tor
torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/health
```

### **Check Peers**
```bash
curl http://localhost:3030/peers
# [{"address":"...","type":"tor","latency_ms":250}]
```

### **Get Balance**
```bash
curl http://localhost:3030/balance/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd
# {"address":"UAT...","balance_uat":19194200}
```

---

## 🎮 Testnet Operations

### **1. Create Wallet**
Via Desktop App:
- Open Wallet → **Create New Wallet**
- Save seed phrase (12-24 words) **SECURELY**
- Wallet akan auto-generate UAT address

Via CLI:
```bash
node test_bip39.js
# Generate address: UAT...
# Save seed phrase!
```

### **2. Request Testnet Tokens (Faucet)**

**Via Wallet UI:**
1. Go to **Faucet** tab
2. Klik **Request 100 UAT**
3. Tunggu 1-2 detik
4. Check balance di **Dashboard**

**Via API:**
```bash
curl -X POST http://localhost:3030/faucet \
  -H "Content-Type: application/json" \
  -d '{"address":"UAT_YOUR_ADDRESS_HERE"}'

# Response:
# {"success":true,"amount_uat":100,"cooldown_seconds":3600}
```

**Limits:**
- 100 UAT per request
- Cooldown: 1 jam per address
- Max 10 requests per IP per hari

### **3. Send Transactions**

**Via Wallet UI:**
1. Go to **Send** tab
2. Enter recipient: `UAT...`
3. Enter amount: `10`
4. Klik **Send**
5. Confirm dengan seed phrase

**Via API:**
```bash
curl -X POST http://localhost:3030/send \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UAT_YOUR_ADDRESS",
    "target": "UAT_RECIPIENT_ADDRESS",
    "amount": 10000000,
    "signature": "..."
  }'

# Response:
# {"success":true,"tx_hash":"0x...","block_height":12345}
```

### **4. Check Transaction History**

```bash
curl http://localhost:3030/history/UAT_YOUR_ADDRESS

# Response:
# {
#   "address": "UAT...",
#   "transactions": [
#     {"type":"receive","from":"faucet","amount_uat":100,"timestamp":1738742400},
#     {"type":"send","to":"UAT...","amount_uat":10,"timestamp":1738742500}
#   ]
# }
```

---

## 🔧 Troubleshooting

### **Node Won't Start**

**Error:** `Address already in use (port 3030)`
```bash
# Find process using port
lsof -ti:3030 | xargs kill -9

# Or change port
./target/release/uat-node --port 3031 --api-port 3031
```

**Error:** `Cannot read genesis_config.json`
```bash
# Regenerate genesis
cd genesis
cargo run --release

# Verify
ls genesis/genesis_config.json
```

### **Tor Connection Issues**

**Check Tor daemon:**
```bash
ps aux | grep tor
# Should show: tor -f ~/.tor-unauthority/torrc

# Restart if needed
killall tor
tor -f ~/.tor-unauthority/torrc &
```

**Check .onion address:**
```bash
cat ~/.tor-unauthority/hidden_service/hostname
# fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```

**Test Tor connection:**
```bash
# Should work
torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/health

# If timeout, check Tor Browser running
```

### **Wallet Offline**

1. Check node running: `curl http://localhost:3030/health`
2. Check Settings → Network → Node URL correct
3. Check firewall tidak block port 3030
4. Try reconnect: Settings → **Test Connection**

### **Faucet "Cooldown Active"**

- Wait 1 jam dari last request
- Atau gunakan address berbeda
- Developer: Edit `main.rs` faucet cooldown

---

## 📊 Testnet Endpoints

Semua endpoint sudah **production-ready** dan accessible via:
- Local: `http://localhost:3030/`
- Tor: `http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/node-info` | GET | Node information & chain stats |
| `/health` | GET | Health check (status, version) |
| `/balance/:address` | GET | Get balance for address |
| `/account/:address` | GET | Get full account (balance + history) |
| `/history/:address` | GET | Transaction history |
| `/validators` | GET | List all active validators |
| `/peers` | GET | Connected peers (Tor/clearnet) |
| `/block` | GET | Latest block info |
| `/block/:height` | GET | Block at specific height |
| `/faucet` | POST | Request testnet tokens (100 UAT) |
| `/send` | POST | Send transaction |
| `/burn` | POST | Burn mechanism (ETH/BTC → UAT) |
| `/whoami` | GET | Current node address |

**Full API Docs:** [api_docs/API_REFERENCE.md](../api_docs/API_REFERENCE.md)

---

## 🔐 Genesis Configuration

**Testnet genesis sudah di-generate dengan:**
- **Network ID:** 1
- **Total Supply:** 153,553,600 UAT (153.55M)
- **Bootstrap Validators:** 3 nodes
- **Dev Accounts:** 8 accounts (pre-funded)

**Genesis Location:**  
`genesis/genesis_config.json` *(NEVER COMMIT - Contains private keys!)*

**Regenerate Genesis:**
```bash
cd genesis
cargo run --release
# New genesis_config.json created
# Copy ke root jika diperlukan
```

⚠️ **WARNING:** Genesis config di-ignore by git karena contains private keys! Jangan commit ke public repo.

---

## 📈 Monitoring

### **Check Node Logs**
```bash
# Tail node output
tail -f node.log

# Grep errors
grep ERROR node.log

# Watch block production
watch -n 1 'curl -s http://localhost:3030/block | jq .height'
```

### **Check Tor Logs**
```bash
tail -f ~/.tor-unauthority/tor.log

# Should see:
# [notice] Bootstrapped 100%: Done
# [notice] Opened 3 rendezvous circuits
```

### **Prometheus Metrics (Advanced)**
```bash
# Enable metrics (if compiled with feature flag)
curl http://localhost:9090/metrics

# See: docs/PROMETHEUS_MONITORING_REPORT.md
```

---

## 🚀 Production Deployment

Ready untuk deploy sendiri? See:
- [TESTNET_DEPLOYMENT.md](TESTNET_DEPLOYMENT.md) - Full deployment guide
- [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) - Docker setup
- [REMOTE_TESTNET_GUIDE.md](REMOTE_TESTNET_GUIDE.md) - Remote server setup

---

## 🆘 Need Help?

- **Documentation:** [docs/](.)
- **Issues:** [GitHub Issues](https://github.com/unauthoritymky-6236/unauthority-core/issues)
- **Test Report:** [TEST_REPORT.md](../TEST_REPORT.md)

---

**🎉 Testnet is LIVE! Start building your dApps!**
