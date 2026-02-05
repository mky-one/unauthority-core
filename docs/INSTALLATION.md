# 📦 Unauthority Installation Guide

Complete guide for installing and running Unauthority Core on all platforms.

---

## 🎯 Choose Your Installation Method

### For End Users (Wallet Only)
- ✅ [Pre-built Desktop Apps](#desktop-wallet-installation) (Recommended)
- ✅ [Web Browser Version](#web-wallet-installation)

### For Validators & Developers
- ✅ [Full Node Installation](#full-node-installation)
- ✅ [Build from Source](#build-from-source)

---

## 📱 Desktop Wallet Installation

### macOS (DMG)

1. **Download:**
   - Visit: https://github.com/unauthoritymky-6236/unauthority-core/releases/latest
   - Download: `Unauthority-Wallet-macOS.dmg`

2. **Install:**
   ```bash
   # Open DMG
   open Unauthority-Wallet-macOS.dmg
   
   # Drag to Applications folder
   # Or double-click installer
   ```

3. **Run:**
   - Open from Applications folder
   - If "Unidentified Developer" warning appears:
     ```bash
     # Remove quarantine attribute
     xattr -d com.apple.quarantine /Applications/Unauthority-Wallet.app
     ```

4. **Connect to Testnet:**
   - Open Settings → Network Endpoint
   - Enter: `http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion`
   - **Important:** Requires Tor Browser running
   - Download Tor: https://www.torproject.org/download/

### Windows (EXE)

1. **Download:**
   - Visit: https://github.com/unauthoritymky-6236/unauthority-core/releases/latest
   - Download: `Unauthority-Wallet-Setup.exe`

2. **Install:**
   ```cmd
   # Double-click installer
   # Follow setup wizard
   # Choose installation directory
   ```

3. **Run:**
   - Launch from Start Menu or Desktop shortcut
   - Windows Defender may show warning (click "More Info" → "Run Anyway")

4. **Connect to Testnet:**
   - Settings → Network Endpoint
   - Enter onion address (requires Tor Browser)
   - Or use local node: `http://localhost:3030`

### Linux (AppImage)

1. **Download:**
   ```bash
   cd ~/Downloads
   wget https://github.com/unauthoritymky-6236/unauthority-core/releases/latest/download/Unauthority-Wallet-Linux.AppImage
   ```

2. **Make Executable:**
   ```bash
   chmod +x Unauthority-Wallet-Linux.AppImage
   ```

3. **Run:**
   ```bash
   ./Unauthority-Wallet-Linux.AppImage
   ```

4. **Optional - Desktop Integration:**
   ```bash
   # Move to /opt
   sudo mv Unauthority-Wallet-Linux.AppImage /opt/
   
   # Create desktop entry
   cat > ~/.local/share/applications/unauthority-wallet.desktop << EOF
   [Desktop Entry]
   Name=Unauthority Wallet
   Exec=/opt/Unauthority-Wallet-Linux.AppImage
   Icon=unauthority
   Type=Application
   Categories=Finance;
   EOF
   ```

---

## 🌐 Web Wallet Installation

### Quick Start (No Install)

1. **Visit:** https://unauthoritymky-6236.github.io/unauthority-wallet/
2. **Or run locally:**
   ```bash
   git clone https://github.com/unauthoritymky-6236/unauthority-core.git
   cd unauthority-core/frontend-wallet
   npm install
   npm run dev
   ```
3. **Open:** http://localhost:5173

---

## 🔧 Full Node Installation

### Prerequisites

- **Rust:** 1.75+
- **Node.js:** 18+
- **Git**
- **4GB RAM minimum**
- **10GB disk space**

### Quick Install

```bash
# 1. Clone repository
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core

# 2. Build backend (takes 5-10 minutes)
cargo build --release --bin uat-node

# 3. Generate wallet (or use existing)
# Option A: Generate new wallet
cd genesis && cargo run --release
# Saves to: genesis/genesis_config.json

# Option B: Use testnet wallet
cp testnet-genesis/testnet_wallets.json node_data/validator-1/wallet.json

# 4. Start node
./target/release/uat-node \
  --port 3030 \
  --api-port 3030 \
  --ws-port 9030 \
  --wallet node_data/validator-1/wallet.json

# Node running at: http://localhost:3030
```

### Verify Installation

```bash
# Test API
curl http://localhost:3030/node-info | jq .

# Expected output:
# {
#   "chain_id": "uat-mainnet",
#   "version": "1.0.0",
#   "block_height": 0,
#   "validator_count": 3,
#   ...
# }
```

---

## 🧅 Tor Integration (For Privacy)

### macOS/Linux

```bash
# Install Tor
brew install tor  # macOS
sudo apt install tor  # Ubuntu/Debian

# Start Tor service
brew services start tor  # macOS
sudo systemctl start tor  # Linux

# Or run Tor manually
tor

# Use torsocks for terminal access
torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/node-info
```

### Windows

1. **Download Tor Expert Bundle:**
   - Visit: https://www.torproject.org/download/tor/
   - Download: Windows Expert Bundle

2. **Extract and Run:**
   ```cmd
   cd tor-win64
   tor.exe
   ```

3. **Configure Wallet:**
   - Set SOCKS5 proxy: `127.0.0.1:9050`
   - Or use Tor Browser

---

## 🚀 Deploy Your Own Testnet

### One-Command Tor Deployment

```bash
cd unauthority-core
./scripts/setup_tor_mainnet.sh

# Output:
# ✅ TOR HIDDEN SERVICE AKTIF!
# 🧅 MAINNET .ONION ADDRESS:
#    http://your-unique-address.onion
# 
# Keep running:
# - Node: localhost:3030
# - Tor: PID shown
```

### Manual Deployment Steps

1. **Start Local Node:**
   ```bash
   ./target/release/uat-node \
     --port 3030 \
     --api-port 3030 \
     --ws-port 9030 \
     --wallet node_data/validator-1/wallet.json
   ```

2. **Configure Tor:**
   ```bash
   # Create torrc config
   mkdir -p ~/.tor-unauthority
   cat > ~/.tor-unauthority/torrc << EOF
   HiddenServiceDir ~/.tor-unauthority/hidden_service
   HiddenServicePort 80 127.0.0.1:3030
   SocksPort 0
   DataDirectory ~/.tor-unauthority/data
   EOF
   ```

3. **Start Tor:**
   ```bash
   tor -f ~/.tor-unauthority/torrc &
   
   # Wait 60 seconds for .onion address
   sleep 60
   cat ~/.tor-unauthority/hidden_service/hostname
   ```

4. **Share .onion Address:**
   - Give to users
   - They need Tor Browser to access

---

## 🎮 First-Time Setup

### Create New Wallet

1. Open wallet application
2. Click **"Create New Wallet"**
3. **CRITICAL:** Write down your 12-word seed phrase
4. Confirm seed phrase
5. Wallet created! 🎉

### Import Testnet Wallet

For testing with pre-funded accounts:

```bash
# Use Treasury 1 (2,000,000 UAT)
# Seed: abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

1. Click **"Import Wallet"**
2. Paste seed phrase above
3. Click **"Import"**
4. Balance: 2,000,000 UAT ✅

### Request Testnet Tokens

1. Go to **Faucet** tab (💧)
2. Click **"Request 100 UAT"**
3. Wait 1 hour between requests
4. Check balance in Dashboard

---

## 🔍 Troubleshooting

### Node Won't Start

```bash
# Check if port is already in use
lsof -i :3030

# Kill existing process
pkill -9 uat-node

# Remove database lock (if exists)
rm -f node_data/validator-1/uat_database/LOCK

# Restart
./target/release/uat-node --port 3030 --api-port 3030 \
  --ws-port 9030 --wallet node_data/validator-1/wallet.json
```

### Wallet Shows "Node Offline"

```bash
# Test connection
curl http://localhost:3030/node-info

# If fails, check node is running:
ps aux | grep uat-node

# Check API endpoint in Settings:
# Should be: http://localhost:3030
# Or: http://your-onion-address.onion (for Tor)
```

### Tor Connection Issues

```bash
# Test Tor is running
curl --socks5-hostname 127.0.0.1:9050 \
  http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/node-info

# If fails, restart Tor:
killall tor
brew services restart tor  # macOS
sudo systemctl restart tor  # Linux
```

### Build Errors

```bash
# Update Rust
rustup update

# Clean build cache
cargo clean

# Rebuild
cargo build --release --bin uat-node

# If still fails, check Rust version:
rustc --version  # Should be 1.75+
```

---

## 📊 System Requirements

### Minimum (User Wallet)
- **OS:** Windows 10, macOS 11, Ubuntu 20.04
- **RAM:** 2GB
- **Disk:** 500MB
- **Internet:** 1 Mbps

### Recommended (Validator Node)
- **OS:** Linux (Ubuntu 22.04 LTS recommended)
- **CPU:** 4 cores
- **RAM:** 8GB
- **Disk:** 50GB SSD
- **Internet:** 10 Mbps upload
- **Uptime:** 99.9%

---

## 🔗 Useful Links

- **Releases:** https://github.com/unauthoritymky-6236/unauthority-core/releases
- **Documentation:** https://github.com/unauthoritymky-6236/unauthority-core/tree/main/docs
- **API Reference:** https://github.com/unauthoritymky-6236/unauthority-core/tree/main/api_docs
- **Test Report:** [TEST_REPORT.md](../TEST_REPORT.md)
- **Tor Browser:** https://www.torproject.org/download/

---

## 📞 Support

- **Issues:** https://github.com/unauthoritymky-6236/unauthority-core/issues
- **Discussions:** https://github.com/unauthoritymky-6236/unauthority-core/discussions

---

**Installation Status Check:**

```bash
# Verify everything is working:
curl http://localhost:3030/health | jq .

# Expected:
# {
#   "status": "healthy",
#   "chain": {
#     "accounts": 14,
#     "blocks": 1
#   },
#   "version": "1.0.0"
# }
```

**✅ Ready to use!**
