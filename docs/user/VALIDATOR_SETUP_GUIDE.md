# 🚀 UNAUTHORITY VALIDATOR - QUICK START GUIDE

## GUI-FIRST VALIDATOR SETUP (NEW ARCHITECTURE)

**No CLI commands needed!** Setup your validator through the web dashboard.

---

## 📋 PREREQUISITES

- ✅ **Node.js** v18+ (https://nodejs.org)
- ✅ **Rust** 1.70+ (https://rustup.rs)
- ✅ **10 GB** free disk space
- ✅ **1000 UAT** minimum stake (testnet provides automatically)

---

## ⚡ INSTALLATION (One Command)

```bash
git clone https://github.com/unauthority/core.git
cd unauthority-core
./install_and_launch.sh
```

**What it does:**
1. ✅ Builds backend (Rust binary)
2. ✅ Installs frontend dependencies
3. ✅ Starts validator dashboard at `http://localhost:5173`

---

## 🎯 STEP-BY-STEP SETUP

### **STEP 1: Open Dashboard**

After running `install_and_launch.sh`, open:
```
http://localhost:5173
```

You'll see the **Setup Wizard**.

---

### **STEP 2: Choose Setup Method**

#### **Option A: Import Existing Keys** (If you already have a validator)

1. Click **"Import Existing Keys"**
2. Choose one:
   - **Paste Private Key** (64-character hex string)
   - **OR: Paste Seed Phrase** (12 or 24 words)
3. Click **"Import & Start Node"**

#### **Option B: Generate New Keys** (First-time validator)

1. Click **"Generate New Keys"**
2. **CRITICAL**: Write down your 24-word seed phrase
3. **DOWNLOAD** the backup file
4. ✅ Confirm: _"I have backed up my seed phrase"_
5. Click **"Confirm & Start Validator"**

---

### **STEP 3: Node Auto-Starts**

After confirming keys:

1. ⏳ **Starting node...** (3-5 seconds)
2. 🔍 **Discovering peers...** (P2P DHT)
3. 📥 **Syncing blockchain...** (downloads latest blocks)
4. ✅ **Validator active!**

**Dashboard will show:**
- ✅ Connected peers
- ✅ Your validator address
- ✅ Current stake (1000 UAT in testnet)
- ✅ Uptime & rewards

---

## 🔐 SECURITY FEATURES

### **Where Are Keys Stored?**

- 🚫 **NOT on backend servers**
- ✅ **Only in your browser** (localStorage, encrypted)
- 🔒 **AES-256-GCM encryption** with your password

### **Session Management**

- ⏱️ **Auto-lock** after 15 minutes inactivity
- 🔐 Password required to unlock
- 🚪 Manual logout available in settings

### **Backup Your Keys**

**You MUST backup your seed phrase!**

Methods:
1. ✍️ Write on paper (store in safe place)
2. 💾 Download encrypted JSON backup
3. 📸 (NOT RECOMMENDED) Screenshot (can be stolen)

⚠️ **WARNING**: If you lose your seed phrase, you **CANNOT RECOVER** your validator!

---

## 📊 MONITORING YOUR VALIDATOR

### **Dashboard Tabs**

1. **Dashboard** - Overview stats
   - Total stake
   - Uptime percentage
   - Earned rewards
   - Connected peers

2. **Validators** - Network validators
   - Active validator list
   - Stake amounts
   - Online status

3. **Blocks** - Recent blocks
   - Block height
   - Finality time
   - Transactions per block

4. **Settings** - Configuration
   - REST API port
   - gRPC port
   - P2P settings
   - Export logs

---

## 🛠️ ADVANCED CONFIGURATION

### **Manual Port Configuration**

Edit `node_data/validator-1/config.toml`:

```toml
[api]
rest_port = 3030

[grpc]
port = 23030

[p2p]
listen_port = 9030
bootstrap_nodes = [
  "/ip4/node1.unauthority.network/tcp/9030/p2p/12D3KooW...",
  "/ip4/node2.unauthority.network/tcp/9030/p2p/12D3KooW..."
]
```

Restart node: `./stop_3_validators.sh && ./launch_3_validators.sh`

---

## 🐛 TROUBLESHOOTING

### **"Node not responding"**

**Check if node is running:**
```bash
curl http://localhost:3030/node-info
```

**Restart node:**
```bash
./stop_3_validators.sh
./launch_3_validators.sh
```

### **"Cannot connect to peers"**

**Check firewall:**
```bash
# Open P2P port (default 9030)
sudo ufw allow 9030/tcp
```

**Test connectivity:**
```bash
curl https://api.unauthority.network/peers
```

### **"Session expired"**

- You were inactive for 15+ minutes
- Click **"Unlock"** and enter your password
- Keys are still safe in localStorage

### **"Invalid seed phrase"**

- Must be exactly 12 or 24 words
- Check for typos
- No extra spaces
- All lowercase

---

## 📱 MOBILE ACCESS

### **Remote Dashboard Access**

To access dashboard from other devices:

1. Edit `frontend-validator/vite.config.ts`:
```typescript
export default defineConfig({
  server: {
    host: '0.0.0.0', // Listen on all interfaces
    port: 5173,
  },
});
```

2. Restart frontend:
```bash
cd frontend-validator && npm run dev
```

3. Access from phone/tablet:
```
http://YOUR_LOCAL_IP:5173
```

**⚠️ Security Warning**: Only do this on trusted networks (home WiFi). Never expose to public internet without HTTPS + authentication.

---

## 🆘 SUPPORT

- 📚 **Documentation**: https://docs.unauthority.network
- 💬 **Discord**: https://discord.gg/unauthority
- 🐦 **Twitter**: @unauthority_uat
- 📧 **Email**: support@unauthority.network

---

## 🎉 CONGRATULATIONS!

Your validator is now part of the Unauthority network!

**Next steps:**
1. ✅ Monitor dashboard daily
2. ✅ Keep node online (99%+ uptime)
3. ✅ Stake more UAT to increase rewards
4. ✅ Join Discord community

**Welcome to decentralization!** 🚀
