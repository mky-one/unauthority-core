# 🚀 QUICK START - REMOTE TESTNET

## Untuk Kamu (Host)

### 1. Start Remote Testnet (1 Command)
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
./scripts/start_remote_testnet.sh
```

### Output yang Akan Muncul:
```
╔══════════════════════════════════════════════════════════╗
║                  ✅ TESTNET READY!                      ║
╚══════════════════════════════════════════════════════════╝

📡 PUBLIC ENDPOINT:
   https://abc123xyz.ngrok-free.app

🆔 NODE INFO:
   Address: UAT...
   Chain: Unauthority

🧪 TEST ENDPOINTS:
   Node Info:  https://abc123xyz.ngrok-free.app/node-info
   Balance:    https://abc123xyz.ngrok-free.app/balance/UAT...
   Faucet:     https://abc123xyz.ngrok-free.app/faucet
   Send:       https://abc123xyz.ngrok-free.app/send

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SHARE THIS WITH YOUR FRIENDS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌐 Unauthority Testnet Node
   Endpoint: https://abc123xyz.ngrok-free.app

📝 Instructions:
   1. Download wallet from GitHub releases
   2. In wallet Settings, change API endpoint to:
      https://abc123xyz.ngrok-free.app
   3. Create/import wallet
   4. Request faucet (100 UAT)
   5. Start testing!
```

### 2. Monitor Status
```bash
# Check node log
tail -f node_data/validator-1/node.log

# Check ngrok dashboard
open http://localhost:4040

# Test endpoint
curl https://YOUR_NGROK_URL/node-info
```

### 3. Stop Testnet
```
Press Ctrl+C in the terminal running start_remote_testnet.sh
```

---

## Untuk Teman (Tester)

### 1. Download Wallet
**macOS:**
```bash
# Download dari GitHub Releases
# File: Unauthority-Wallet-0.1.0-arm64.dmg
```

**Windows:**
```powershell
# File: Unauthority-Wallet-Setup-0.1.0.exe
```

**Linux:**
```bash
# File: Unauthority-Wallet-0.1.0.AppImage
chmod +x Unauthority-Wallet-0.1.0.AppImage
./Unauthority-Wallet-0.1.0.AppImage
```

### 2. Configure Wallet
1. Open wallet app
2. Click **"Settings"** tab (gear icon)
3. In "API Endpoint" field, paste:
   ```
   https://abc123xyz.ngrok-free.app
   ```
   (Ganti dengan URL yang diberikan host)
4. Click **"Test Connection"** → Should show "Connected! Chain: UAT"
5. Click **"Save & Reconnect"** → App will reload

### 3. Create Wallet
1. Click **"Create New Wallet"**
2. **WRITE DOWN** your 12-word seed phrase (IMPORTANT!)
3. Confirm seed phrase
4. Wallet created!

### 4. Get Testnet Tokens
1. Click **"Faucet"** tab (💧 droplet icon)
2. Click **"Request 100 UAT"** button
3. Wait 10 seconds
4. Balance akan update otomatis → 100 UAT

### 5. Test Sending
1. Click **"Send"** tab
2. **Recipient Address:** Paste address teman atau host
3. **Amount:** 10 (UAT)
4. Click **"Send Transaction"**
5. Success! Check History tab

---

## 🧪 Testing Scenarios

### Scenario 1: Basic Transfer
```
1. Teman A request faucet → 100 UAT
2. Teman A send 10 UAT ke Teman B
3. Teman B check balance → +10 UAT
4. Check history → transaction muncul
```

### Scenario 2: Multi-User Testing
```
1. 3+ teman connect ke same node
2. Each request faucet → 100 UAT
3. Send transactions ke each other
4. Monitor transactions di History
```

### Scenario 3: Network Switching
```
1. Settings → Change to localhost
2. Should show "Node Offline"
3. Settings → Change back to Ngrok URL
4. Should reconnect → "Node Online"
```

---

## 🐛 Troubleshooting

### Problem: "Cannot connect to node"
**Solution:**
```bash
# Check from your terminal:
curl https://YOUR_NGROK_URL/node-info

# If fails, check:
1. Ngrok still running?
2. Node still running? (ps aux | grep uat-node)
3. Firewall blocking?
```

### Problem: "Faucet cooldown active"
**Solution:**
- Wait 1 hour
- OR create new wallet
- OR host can restart node to reset cooldown

### Problem: "Transaction failed"
**Solution:**
- Check balance sufficient (need > amount + fee)
- Check recipient address valid (starts with "UAT")
- Check connection status (Node Online?)

### Problem: Balance not updating
**Solution:**
- Wait 10 seconds (auto-refresh)
- Click refresh button in header
- Check browser console (F12) for errors

---

## 📊 Quick Commands

### Host Commands
```bash
# Start remote testnet
./scripts/start_remote_testnet.sh

# Check node status
ps aux | grep uat-node

# View logs
tail -f node_data/validator-1/node.log

# Stop node
pkill uat-node

# Restart everything
./scripts/start_remote_testnet.sh
```

### Tester Commands
```bash
# Test connection
curl https://YOUR_NGROK_URL/node-info

# Get balance
curl https://YOUR_NGROK_URL/balance/UAT...

# Request faucet
curl -X POST https://YOUR_NGROK_URL/faucet \
  -H "Content-Type: application/json" \
  -d '{"address": "UAT..."}'
```

---

## 💡 Tips

### For Host:
- Keep terminal open while testing
- Ngrok free tier: URL changes on restart
- Monitor ngrok dashboard: http://localhost:4040
- Share connection-info.txt file with testers

### For Testers:
- Save your seed phrase securely
- Testnet tokens have NO real value
- Can create multiple wallets for testing
- Join Discord for support

---

## 📞 Support

**Discord:** https://discord.gg/unauthority  
**GitHub Issues:** https://github.com/unauthority/core/issues  
**Docs:** `docs/REMOTE_TESTNET_GUIDE.md` (detailed guide)

---

## ✅ Testing Checklist

### Host:
- [ ] Script ran successfully
- [ ] Got public Ngrok URL
- [ ] Node log shows "REST API: http://0.0.0.0:3030"
- [ ] Can curl node-info from terminal
- [ ] Shared URL with testers

### Tester:
- [ ] Downloaded wallet
- [ ] Configured endpoint in Settings
- [ ] Connection test successful
- [ ] Created wallet
- [ ] Received faucet tokens (100 UAT)
- [ ] Sent transaction successfully
- [ ] Saw transaction in History

---

**READY TO TEST! 🚀**

Jalankan `./scripts/start_remote_testnet.sh` dan share URL-nya!
