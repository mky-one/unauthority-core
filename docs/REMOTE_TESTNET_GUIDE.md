# 🌍 Remote Testnet Setup Guide

Panduan lengkap untuk setup testnet Unauthority yang bisa diakses teman-teman dari lokasi berbeda.

---

## 📋 Overview

**Tujuan:** Membuat testnet node yang bisa diakses dari internet oleh teman-teman untuk testing.

**Solusi:**
1. **Ngrok** - Tunnel localhost ke internet (mudah, gratis)
2. **Cloudflare Tunnel** - Alternatif production-grade (gratis, lebih aman)
3. **VPS Public** - Deploy ke VPS dengan IP publik (advanced)

---

## 🚀 Metode 1: Ngrok (PALING MUDAH)

### Step 1: Install Ngrok

**macOS:**
```bash
brew install ngrok/ngrok/ngrok
```

**Windows:**
```powershell
# Download dari https://ngrok.com/download
# Extract dan jalankan ngrok.exe
```

**Linux:**
```bash
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok
```

### Step 2: Sign Up & Get Auth Token

1. Buat akun gratis di https://dashboard.ngrok.com/signup
2. Copy auth token dari dashboard
3. Configure ngrok:

```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN_HERE
```

### Step 3: Start Local Node

```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core

# Start validator node
./target/release/uat-node \
  --port 3030 \
  --api-port 3030 \
  --ws-port 9030 \
  --wallet node_data/validator-1/wallet.json
```

### Step 4: Expose Node dengan Ngrok

**Terminal baru:**
```bash
# Expose port 3030 ke internet
ngrok http 3030
```

**Output:**
```
ngrok

Session Status                online
Account                       your-email@gmail.com (Plan: Free)
Version                       3.5.0
Region                        Asia Pacific (ap)
Latency                       -
Web Interface                 http://127.0.0.1:4040
Forwarding                    https://abc123xyz.ngrok-free.app -> http://localhost:3030

Connections                   ttl     opn     rt1     rt5     p50     p90
                              0       0       0.00    0.00    0.00    0.00
```

**✅ PUBLIC URL:** `https://abc123xyz.ngrok-free.app`

### Step 5: Kirim ke Teman

Kirim URL ini ke teman-teman:
```
🌐 Testnet Node: https://abc123xyz.ngrok-free.app

Test endpoints:
- Balance: https://abc123xyz.ngrok-free.app/balance/UAT...
- Node Info: https://abc123xyz.ngrok-free.app/node-info
- Faucet: https://abc123xyz.ngrok-free.app/faucet
```

### Step 6: Teman Connect dari Wallet

**Di wallet frontend teman:**

1. Open `src/utils/api.ts` atau `api-improved.ts`
2. Change API_BASE:
```typescript
const API_BASE = 'https://abc123xyz.ngrok-free.app';
```

3. Atau tambahkan UI untuk ganti endpoint:
```typescript
// In App.tsx or Settings.tsx
import { setApiBase } from './utils/api-improved';

function Settings() {
  const [endpoint, setEndpoint] = useState('http://localhost:3030');
  
  const handleSave = () => {
    setApiBase(endpoint);
    window.location.reload();
  };
  
  return (
    <div>
      <input 
        value={endpoint} 
        onChange={(e) => setEndpoint(e.target.value)}
        placeholder="API Endpoint"
      />
      <button onClick={handleSave}>Save</button>
    </div>
  );
}
```

---

## 🔒 Metode 2: Cloudflare Tunnel (LEBIH AMAN)

### Step 1: Install Cloudflared

**macOS:**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**Windows:**
```powershell
# Download dari https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation
```

**Linux:**
```bash
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### Step 2: Login ke Cloudflare

```bash
cloudflared tunnel login
```

Browser akan terbuka, login dengan akun Cloudflare (gratis).

### Step 3: Create Tunnel

```bash
# Create tunnel
cloudflared tunnel create uat-testnet

# Output:
# Tunnel credentials written to: /Users/.../.cloudflared/UUID.json
# Created tunnel uat-testnet with id: abc-123-xyz
```

### Step 4: Configure Tunnel

Create config file:

```bash
nano ~/.cloudflared/config.yml
```

**Content:**
```yaml
tunnel: abc-123-xyz
credentials-file: /Users/USERNAME/.cloudflared/UUID.json

ingress:
  - hostname: uat-testnet.yourdomain.com
    service: http://localhost:3030
  - service: http_status:404
```

### Step 5: Route DNS

```bash
cloudflared tunnel route dns uat-testnet uat-testnet.yourdomain.com
```

### Step 6: Run Tunnel

```bash
cloudflared tunnel run uat-testnet
```

**✅ PUBLIC URL:** `https://uat-testnet.yourdomain.com`

---

## 🖥️ Metode 3: VPS Public (PRODUCTION-GRADE)

### Step 1: Rent VPS

**Provider Recommendations:**
- **DigitalOcean** - $6/month (1 vCPU, 1GB RAM)
- **Vultr** - $5/month (1 vCPU, 1GB RAM)
- **Hetzner** - €4/month (2 vCPU, 2GB RAM) - **CHEAPEST**

### Step 2: Setup VPS

```bash
# SSH to VPS
ssh root@YOUR_VPS_IP

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y build-essential pkg-config libssl-dev curl git

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Step 3: Deploy Node

```bash
# Clone repo
git clone https://github.com/YOUR_USERNAME/unauthority-core.git
cd unauthority-core

# Build
cargo build --release

# Create systemd service
cat > /etc/systemd/system/uat-node.service <<EOF
[Unit]
Description=Unauthority Testnet Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/unauthority-core
ExecStart=/root/unauthority-core/target/release/uat-node --port 3030 --api-port 3030 --ws-port 9030 --wallet /root/unauthority-core/node_data/validator-1/wallet.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl enable uat-node
systemctl start uat-node
systemctl status uat-node
```

### Step 4: Configure Firewall

```bash
# Allow API port
ufw allow 3030/tcp
ufw allow 8080/tcp  # P2P port
ufw allow 22/tcp    # SSH
ufw enable
```

### Step 5: Setup Domain (Optional)

**Di DNS provider (Cloudflare/GoDaddy):**
```
Type: A
Name: testnet
Value: YOUR_VPS_IP
TTL: Auto
```

**Access:** `http://testnet.yourdomain.com:3030`

### Step 6: Setup HTTPS dengan Nginx + Let's Encrypt

```bash
# Install nginx
apt install -y nginx certbot python3-certbot-nginx

# Configure nginx
cat > /etc/nginx/sites-available/uat-testnet <<EOF
server {
    listen 80;
    server_name testnet.yourdomain.com;

    location / {
        proxy_pass http://localhost:3030;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site
ln -s /etc/nginx/sites-available/uat-testnet /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# Get SSL certificate
certbot --nginx -d testnet.yourdomain.com
```

**✅ PUBLIC URL:** `https://testnet.yourdomain.com`

---

## 📱 Client Configuration (Wallet Frontend)

### Option 1: Hardcode Endpoint

**frontend-wallet/src/utils/api.ts:**
```typescript
// Change from localhost to public URL
const API_BASE = 'https://abc123xyz.ngrok-free.app'; // or your VPS
```

### Option 2: Environment Variable

**frontend-wallet/.env:**
```bash
VITE_API_BASE=https://abc123xyz.ngrok-free.app
```

**frontend-wallet/src/utils/api.ts:**
```typescript
const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3030';
```

### Option 3: Runtime Configuration (BEST)

**frontend-wallet/src/components/Settings.tsx:**
```typescript
import { useState } from 'react';
import { setApiBase, getApiBaseUrl } from '../utils/api-improved';

export default function Settings() {
  const [endpoint, setEndpoint] = useState(getApiBaseUrl());
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setApiBase(endpoint);
    setSaved(true);
    setTimeout(() => {
      window.location.reload();
    }, 1000);
  };

  const presets = [
    { name: 'Local', url: 'http://localhost:3030' },
    { name: 'Ngrok Testnet', url: 'https://abc123xyz.ngrok-free.app' },
    { name: 'VPS Testnet', url: 'https://testnet.unauthority.network' },
  ];

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">⚙️ Network Settings</h2>

      <div className="bg-uat-gray border border-gray-700 rounded-lg p-6">
        <label className="block text-sm font-medium mb-2">API Endpoint</label>
        <input
          type="text"
          value={endpoint}
          onChange={(e) => setEndpoint(e.target.value)}
          placeholder="https://testnet.unauthority.network"
          className="w-full px-4 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white"
        />

        <div className="mt-4 space-y-2">
          <p className="text-sm text-gray-400">Quick Presets:</p>
          {presets.map((preset) => (
            <button
              key={preset.name}
              onClick={() => setEndpoint(preset.url)}
              className="block w-full text-left px-4 py-2 bg-gray-800 hover:bg-gray-700 rounded-lg text-sm"
            >
              <span className="font-medium">{preset.name}</span>
              <span className="text-gray-400 ml-2">{preset.url}</span>
            </button>
          ))}
        </div>

        <button
          onClick={handleSave}
          className="mt-6 w-full bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-medium"
        >
          {saved ? '✓ Saved! Reloading...' : 'Save & Reconnect'}
        </button>
      </div>

      <div className="mt-4 p-4 bg-yellow-900/20 border border-yellow-700 rounded-lg">
        <p className="text-sm text-yellow-200">
          ⚠️ Make sure the endpoint is accessible and running before connecting.
        </p>
      </div>
    </div>
  );
}
```

---

## 🧪 Testing dari Teman

### Checklist untuk Teman:

1. **Get Endpoint URL** dari kamu (Ngrok/VPS URL)
2. **Configure Wallet:**
   ```
   Settings → Network → Paste URL → Save
   ```
3. **Test Connection:**
   - Dashboard should show "Node Online"
   - Balance tab loads without errors
4. **Create Wallet:**
   - Generate new wallet
   - Copy address
5. **Request Faucet:**
   - Faucet tab → Request 100 UAT
   - Wait 10 seconds
   - Balance should update
6. **Send Transaction:**
   - Send tab → Enter your address
   - Send 10 UAT
   - Check transaction in history

---

## 🔍 Monitoring & Debugging

### Check if Node is Accessible

```bash
# From teman's computer
curl https://abc123xyz.ngrok-free.app/node-info

# Expected response:
# {"node_address":"UAT...","network_id":1,"chain_name":"Unauthority",...}
```

### Check Logs

```bash
# Local
tail -f node_data/validator-1/node.log

# VPS
journalctl -u uat-node -f
```

### Common Issues

**Problem:** Teman tidak bisa connect
**Solution:**
- Check firewall: `ufw status`
- Check ngrok still running: `curl http://localhost:4040/api/tunnels`
- Check node running: `curl http://localhost:3030/node-info`

**Problem:** CORS errors di browser
**Solution:** Add CORS headers di backend:
```rust
// In main.rs
let cors = warp::cors()
    .allow_any_origin()
    .allow_methods(vec!["GET", "POST", "OPTIONS"])
    .allow_headers(vec!["Content-Type"]);

let routes = api_routes.with(cors);
```

**Problem:** Ngrok URL berubah setiap restart
**Solution:** Upgrade ke Ngrok paid ($8/month) untuk static domain

---

## 💰 Cost Comparison

| Method | Cost | Uptime | Speed | Setup Time |
|--------|------|--------|-------|------------|
| **Ngrok Free** | $0 | Session-based | Fast | 5 min |
| **Ngrok Paid** | $8/mo | 24/7 | Fast | 5 min |
| **Cloudflare** | $0 | 24/7 | Fast | 15 min |
| **VPS (Hetzner)** | €4/mo | 24/7 | Very Fast | 30 min |

**Recommendation:**
- **Testing (< 1 week):** Ngrok Free
- **Long-term Testnet:** VPS or Cloudflare Tunnel
- **Production:** Multiple VPS with load balancer

---

## 📞 Support

Jika teman mengalami masalah:

1. **Check Status:**
   ```bash
   curl YOUR_PUBLIC_URL/node-info
   ```

2. **Share Logs:**
   ```bash
   # Send last 50 lines
   tail -50 node_data/validator-1/node.log
   ```

3. **Discord Support:** #testnet-help

---

## 🎯 Next Steps

- [ ] Setup monitoring (Prometheus/Grafana)
- [ ] Add multiple bootstrap nodes
- [ ] Create block explorer for testnet
- [ ] Setup automatic restarts
- [ ] Add rate limiting for faucet
- [ ] Backup database regularly

**Happy Testing! 🚀**
