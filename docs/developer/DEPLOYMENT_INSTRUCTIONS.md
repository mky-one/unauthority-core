# 🚀 Deployment Instructions - Unauthority v1.0.0

## Pre-Deployment Checklist

### ✅ Code Ready
- [x] All tests passing (cargo test)
- [x] Zero critical warnings (cargo clippy)
- [x] Frontend builds (npm run build)
- [x] Genesis generated with seed phrases
- [x] .gitignore blocks sensitive files

### ✅ Documentation
- [x] README.md updated
- [x] API documentation complete
- [x] User guides written
- [x] Security disclosures prepared

---

## 📦 Step 1: Build Release Binaries

### 1.1 Backend (Rust)

```bash
# Clean previous builds
cargo clean

# Build release (optimized)
cargo build --release --bin uat-node

# Verify binary
./target/release/uat-node --version
# Output: uat-node 1.0.0
```

### 1.2 Cross-Compile for Multiple Platforms

**Install cross-compilation tools:**
```bash
# macOS → Linux
rustup target add x86_64-unknown-linux-gnu

# macOS → Windows
rustup target add x86_64-pc-windows-gnu
brew install mingw-w64

# Linux → macOS
rustup target add x86_64-apple-darwin
```

**Build for each platform:**
```bash
# Linux x86_64
cargo build --release --target x86_64-unknown-linux-gnu

# macOS ARM64 (M1/M2)
cargo build --release --target aarch64-apple-darwin

# macOS Intel
cargo build --release --target x86_64-apple-darwin

# Windows
cargo build --release --target x86_64-pc-windows-gnu
```

**Rename binaries:**
```bash
cp target/release/uat-node target/release/uat-node-linux-x86_64
cp target/aarch64-apple-darwin/release/uat-node target/release/uat-node-macos-arm64
cp target/x86_64-apple-darwin/release/uat-node target/release/uat-node-macos-x86_64
cp target/x86_64-pc-windows-gnu/release/uat-node.exe target/release/uat-node-windows.exe
```

### 1.3 Frontend (Electron Apps)

**Validator Dashboard:**
```bash
cd frontend-validator

# Install dependencies
npm install

# Build web assets
npm run build

# Package desktop apps (all platforms)
npm run electron:build

# Output:
# - release/Unauthority-Validator-Dashboard.dmg (macOS)
# - release/Unauthority-Validator-Dashboard-Setup.exe (Windows)
# - release/Unauthority-Validator-Dashboard.AppImage (Linux)
```

**Public Wallet:**
```bash
cd frontend-wallet

npm install
npm run build
npm run electron:build

# Output:
# - release/Unauthority-Wallet.dmg
# - release/Unauthority-Wallet-Setup.exe
# - release/Unauthority-Wallet.AppImage
```

---

## 🔐 Step 2: Generate Genesis & Secure Keys

### 2.1 Generate Production Genesis

```bash
cd genesis
cargo run --release > genesis_output.txt 2>&1

# IMPORTANT: Save this output!
# Contains 24-word seed phrases for all 11 wallets
```

### 2.2 Backup Seed Phrases

**For Bootstrap Nodes (3 wallets):**
```bash
# Extract bootstrap seed phrases
grep -A 4 "BOOTSTRAP NODE" genesis_output.txt > bootstrap_seeds.txt

# CRITICAL SECURITY:
# 1. Print bootstrap_seeds.txt
# 2. Store printed copy in bank safe deposit box
# 3. Delete bootstrap_seeds.txt from computer
# 4. NEVER store seed phrases in cloud/email/Git
```

**For Dev Wallets (8 wallets):**
```bash
# Extract dev wallet seed phrases
grep -A 4 "DEV WALLET" genesis_output.txt > dev_seeds.txt

# Security:
# 1. Encrypt with GPG
gpg --symmetric --cipher-algo AES256 dev_seeds.txt
# 2. Store encrypted file in multiple secure locations
# 3. Delete original dev_seeds.txt
```

### 2.3 Prepare Genesis Config for Distribution

```bash
# genesis_config.json contains private keys!
# For bootstrap nodes ONLY (not public)

# Create sanitized version (without private keys)
jq 'del(.bootstrap_nodes[].private_key, .dev_accounts[].private_key, .bootstrap_nodes[].seed_phrase, .dev_accounts[].seed_phrase)' \
  genesis/genesis_config.json > genesis_config_public.json

# genesis_config_public.json = safe for public GitHub
# genesis_config.json = NEVER commit to Git
```

---

## 📤 Step 3: GitHub Release

### 3.1 Create Git Tag

```bash
# Commit all changes
git add .
git commit -m "v1.0.0 - Genesis Release"

# Create annotated tag
git tag -a v1.0.0 -m "Unauthority v1.0.0 - Production Release

- Mainnet launch
- Desktop wallets (Electron)
- Validator dashboard
- Proof-of-Burn distribution
- Smart contract engine (UVM)
- Zero admin keys
- <3 second finality
"

# Push to GitHub
git push origin main
git push origin v1.0.0
```

### 3.2 Create GitHub Release (Web UI)

1. **Go to:** https://github.com/YOUR_ORG/unauthority-core/releases/new

2. **Fill Release Form:**
   - **Tag:** v1.0.0
   - **Title:** Unauthority (UAT) v1.0.0 - Genesis Release 🚀
   - **Description:** Copy from `GITHUB_RELEASE_v1.0.0.md`

3. **Upload Binaries:**

**Backend:**
```
uat-node-linux-x86_64
uat-node-macos-arm64
uat-node-macos-x86_64
uat-node-windows.exe
```

**Validator Dashboard:**
```
Unauthority-Validator-Dashboard.dmg
Unauthority-Validator-Dashboard-Setup.exe
Unauthority-Validator-Dashboard.AppImage
```

**Public Wallet:**
```
Unauthority-Wallet.dmg
Unauthority-Wallet-Setup.exe
Unauthority-Wallet.AppImage
```

**Genesis (Optional - For Bootstrap Nodes):**
```
genesis_config.json (⚠️ Contains private keys!)
```

4. **Generate Checksums:**

```bash
# Create checksums file
cd target/release
sha256sum uat-node-* > SHA256SUMS.txt

cd ../../frontend-validator/release
sha256sum Unauthority-Validator-Dashboard.* >> ../../target/release/SHA256SUMS.txt

cd ../../frontend-wallet/release
sha256sum Unauthority-Wallet.* >> ../../target/release/SHA256SUMS.txt

# Upload SHA256SUMS.txt to GitHub release
```

5. **Publish Release:**
   - Check "This is a pre-release" if testnet
   - Uncheck if mainnet production
   - Click "Publish release"

---

## 🌐 Step 4: Deploy Bootstrap Nodes

### 4.1 Rent VPS Servers (3 nodes)

**Requirements per node:**
- 2 CPU cores
- 4 GB RAM
- 100 GB SSD
- 1 Gbps network
- Ubuntu 22.04 LTS

**Regions (for geographic distribution):**
1. USA West (Oregon/California)
2. Europe (Frankfurt/London)
3. Asia (Singapore/Tokyo)

**Recommended providers:**
- DigitalOcean
- Linode
- Vultr
- Hetzner

### 4.2 Setup Bootstrap Node 1 (USA)

```bash
# SSH into VPS
ssh root@bootstrap-node-1-ip

# Install dependencies
apt update && apt upgrade -y
apt install -y curl wget

# Download binary
wget https://github.com/YOUR_ORG/unauthority-core/releases/download/v1.0.0/uat-node-linux-x86_64
chmod +x uat-node-linux-x86_64
mv uat-node-linux-x86_64 /usr/local/bin/uat-node

# Verify
uat-node --version

# Create data directory
mkdir -p /var/lib/uat-node

# Create systemd service
cat > /etc/systemd/system/uat-node.service << 'EOF'
[Unit]
Description=Unauthority Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/uat-node
ExecStart=/usr/local/bin/uat-node 3030
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable uat-node
systemctl start uat-node

# Check status
systemctl status uat-node
journalctl -u uat-node -f

# Verify node is running
curl http://localhost:3030/node-info
```

### 4.3 Import Bootstrap Seed Phrase

**On your local computer:**

1. Open Validator Dashboard (downloaded from GitHub release)
2. Click "Import Existing Keys"
3. Paste 24-word seed phrase from `bootstrap_seeds.txt` (Bootstrap Node #1)
4. Set password (only for local app encryption)
5. Click "Start Validator"

**Result:**
- Node activates with 1,000 UAT genesis balance
- Starts participating in consensus
- Dashboard shows: "Active Validator"

### 4.4 Repeat for Nodes 2 & 3

Deploy to:
- **Node 2:** Europe VPS (Frankfurt)
- **Node 3:** Asia VPS (Singapore)

Import respective seed phrases:
- Node 2: Bootstrap seed phrase #2
- Node 3: Bootstrap seed phrase #3

### 4.5 Verify Network Consensus

**Check all 3 nodes agree:**
```bash
# Node 1 (USA)
curl http://bootstrap-node-1-ip:3030/supply

# Node 2 (Europe)
curl http://bootstrap-node-2-ip:3030/supply

# Node 3 (Asia)
curl http://bootstrap-node-3-ip:3030/supply

# All should return same remaining_supply_void
```

**Check peer connectivity:**
```bash
curl http://bootstrap-node-1-ip:3030/peers

# Should show 2+ peers (other bootstrap nodes)
```

---

## 📱 Step 5: Mobile & Web Deployment (Optional)

### 5.1 IPFS Hosting (Decentralized)

```bash
# Build frontend for IPFS
cd frontend-wallet
npm run build

# Upload to IPFS (via Pinata)
curl -X POST \
  https://api.pinata.cloud/pinning/pinFileToIPFS \
  -H "pinata_api_key: YOUR_API_KEY" \
  -H "pinata_secret_api_key: YOUR_SECRET" \
  -F file=@dist.zip

# Result: QmXXXXXXX...
# Access: https://gateway.ipfs.io/ipfs/QmXXXXXXX
```

### 5.2 Cloudflare Pages (Fast CDN)

```bash
# Install Wrangler CLI
npm install -g wrangler

# Login
wrangler login

# Deploy
cd frontend-wallet
npm run build
wrangler pages deploy dist --project-name=unauthority-wallet

# Custom domain: wallet.unauthority.network
```

---

## 🔍 Step 6: Monitoring & Maintenance

### 6.1 Setup Monitoring (Prometheus + Grafana)

**Install on monitoring server:**
```bash
# Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvf prometheus-*.tar.gz
cd prometheus-*

# Configure scraping
cat > prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'uat-nodes'
    static_configs:
      - targets:
        - 'bootstrap-node-1-ip:3030'
        - 'bootstrap-node-2-ip:3030'
        - 'bootstrap-node-3-ip:3030'
EOF

./prometheus --config.file=prometheus.yml
```

### 6.2 Alerts

**Critical alerts:**
- Node offline > 5 minutes
- Supply mismatch between nodes
- No new blocks > 1 minute
- Disk usage > 80%

### 6.3 Backup Strategy

**Daily backups:**
```bash
# Backup blockchain data
tar -czf uat-backup-$(date +%Y%m%d).tar.gz /var/lib/uat-node

# Upload to S3/Backblaze
aws s3 cp uat-backup-*.tar.gz s3://backups/uat-node/
```

---

## 📣 Step 7: Announcements

### 7.1 Social Media

**Twitter:**
```
🚀 Unauthority (UAT) v1.0.0 is LIVE!

✅ Mainnet launched
✅ Desktop wallets available
✅ Proof-of-Burn active (BTC/ETH → UAT)
✅ Zero admin keys
✅ <3 second finality

Download: https://github.com/unauthority/unauthority-core/releases/tag/v1.0.0

#Crypto #Blockchain #DeFi #UAT
```

**Discord/Telegram:**
```
@everyone Unauthority Mainnet Launch! 🎉

What's live:
- Backend nodes (Linux/macOS/Windows)
- Validator dashboard (Electron)
- Public wallet (Electron)
- Proof-of-Burn distribution

Get started: https://github.com/unauthority/unauthority-core/releases/tag/v1.0.0

First 100 validators get bonus rewards!
```

### 7.2 Community Platforms

**Reddit:**
- r/cryptocurrency
- r/CryptoTechnology
- r/altcoin

**Forums:**
- BitcoinTalk (ANN thread)
- CryptoTalk

**Crypto News:**
- CoinDesk
- Cointelegraph
- Decrypt
- The Block

---

## 🏦 Step 8: Exchange Listings

### 8.1 Prepare Listing Materials

**Required documents:**
```
1. Project Overview (1-page)
2. Technical Whitepaper
3. Tokenomics breakdown
4. Smart contract audit report
5. Team information
6. Legal opinion (if available)
7. Marketing materials (logo, banners)
```

### 8.2 Apply to Exchanges

**Tier 1 (CEX):**
- Binance (application fee: varies)
- Coinbase (institutional process)
- Kraken (direct contact)

**Tier 2 (CEX):**
- KuCoin (https://www.kucoin.com/support/list)
- Gate.io (listing@gate.io)
- MEXC (listing@mexc.com)

**DEX (Decentralized):**
- Uniswap (self-list, no approval)
- PancakeSwap (self-list)
- SushiSwap (governance vote)

### 8.3 CoinMarketCap / CoinGecko

**CoinMarketCap:**
```
https://coinmarketcap.com/request/

Required info:
- Project name: Unauthority
- Ticker: UAT
- Total supply: 21,936,236 UAT
- Circulating supply: Check blockchain API
- Contract address: N/A (native coin)
- Explorer: https://explorer.unauthority.network
```

**CoinGecko:**
```
https://www.coingecko.com/en/coins/new

Fill form with same info
Add API endpoint: https://rpc1.unauthority.network:3030/supply
```

---

## 🎯 Step 9: Post-Launch Checklist

### Week 1
- [ ] Monitor all 3 bootstrap nodes (uptime)
- [ ] Verify supply consensus
- [ ] Check first user transactions
- [ ] Respond to community questions
- [ ] Fix any critical bugs

### Month 1
- [ ] Onboard 10+ validators
- [ ] Process exchange listing applications
- [ ] External security audit
- [ ] Community AMA

### Month 3
- [ ] 100+ active validators
- [ ] 1+ exchange listings
- [ ] Mobile wallet beta
- [ ] DeFi protocol partnerships

---

## 📞 Emergency Contacts

**Critical Issues:**
- security@unauthority.network (security bugs)
- support@unauthority.network (user issues)
- ops@unauthority.network (infrastructure)

**On-Call Rotation:**
- Developer 1: +1-XXX-XXX-XXXX
- Developer 2: +1-XXX-XXX-XXXX
- DevOps: +1-XXX-XXX-XXXX

---

## ✅ Deployment Complete

**Verification checklist:**
- [ ] GitHub release published
- [ ] All binaries uploaded
- [ ] Checksums verified
- [ ] Bootstrap nodes running
- [ ] Supply consensus verified
- [ ] Wallets downloadable
- [ ] Announcements posted
- [ ] Monitoring active
- [ ] Backups configured

**🎉 MAINNET IS LIVE! 🎉**

---

_Last updated: February 5, 2026_  
_Deployment version: v1.0.0_  
_Status: PRODUCTION READY_
