# 🧅 Tor Browser Installation Guide (macOS)

**Complete guide untuk download dan install Tor Browser di macOS dengan signature verification.**

---

## 📥 Download Tor Browser

### Official Download Link:
**🔗 https://www.torproject.org/download/**

### Direct macOS Download:
**🍎 https://www.torproject.org/dist/torbrowser/13.0.9/TorBrowser-13.0.9-macos_ALL.dmg**

---

## 🔐 Verify Signature (RECOMMENDED)

Sebelum install, **WAJIB** verify signature untuk keamanan!

### Step 1: Download Signature File
```bash
cd ~/Downloads

# Download DMG (if not yet)
curl -O https://www.torproject.org/dist/torbrowser/13.0.9/TorBrowser-13.0.9-macos_ALL.dmg

# Download signature
curl -O https://www.torproject.org/dist/torbrowser/13.0.9/TorBrowser-13.0.9-macos_ALL.dmg.asc
```

### Step 2: Import Tor Developer Keys
```bash
# Import Tor Project signing keys
gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org

# Output should show:
# pub   rsa4096 2014-12-15 [C] [expires: 2025-07-21]
#       EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
# uid   Tor Browser Developers (signing key) <torbrowser@torproject.org>
```

### Step 3: Verify Signature
```bash
gpg --verify TorBrowser-13.0.9-macos_ALL.dmg.asc TorBrowser-13.0.9-macos_ALL.dmg

# Expected output:
# gpg: Signature made [DATE]
# gpg:                using RSA key EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
# gpg: Good signature from "Tor Browser Developers (signing key) <torbrowser@torproject.org>"
```

✅ **"Good signature"** = Safe to install!  
❌ **"BAD signature"** = DO NOT INSTALL! Re-download!

---

## 📦 Installation Steps

### Method 1: GUI Installation (Easiest)

1. **Double-click** `TorBrowser-13.0.9-macos_ALL.dmg`
2. **Drag Tor Browser** to Applications folder
3. **Eject** the DMG
4. **Open Tor Browser** from Applications
5. **First Launch:**
   - Click **"Connect"** (automatic Tor connection)
   - Wait 10-30 seconds for connection
   - Browser akan open otomatis

### Method 2: Terminal Installation

```bash
# Mount DMG
hdiutil attach ~/Downloads/TorBrowser-13.0.9-macos_ALL.dmg

# Copy to Applications
cp -R "/Volumes/Tor Browser/Tor Browser.app" /Applications/

# Eject DMG
hdiutil detach "/Volumes/Tor Browser"

# Remove quarantine attribute (jika macOS block)
xattr -d com.apple.quarantine "/Applications/Tor Browser.app"

# Launch Tor Browser
open "/Applications/Tor Browser.app"
```

---

## 🔓 Fix macOS Gatekeeper Issues

Jika macOS bilang **"Tor Browser cannot be opened because the developer cannot be verified"**:

### Option 1: System Preferences
1. Go to **System Preferences** → **Security & Privacy**
2. Click **"Open Anyway"** button (muncul setelah first attempt)
3. Confirm **"Open"**

### Option 2: Terminal Command
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine "/Applications/Tor Browser.app"

# Verify removal
xattr -l "/Applications/Tor Browser.app"
# Should show: (empty) or no com.apple.quarantine
```

### Option 3: Allow from Unidentified Developers (Not Recommended)
```bash
# Temporarily allow
sudo spctl --master-disable

# Re-enable after install
sudo spctl --master-enable
```

---

## ✅ Verify Tor Browser Installation

### Check Tor Connection
1. **Open Tor Browser**
2. **Automatic Connection Test:** Browser akan test connection otomatis
3. **Manual Test:** Visit https://check.torproject.org
   - ✅ **"Congratulations. This browser is configured to use Tor."**

### Check Tor Circuit
1. Click **onion icon** di address bar (top-left)
2. See **"Circuit for this site"**
3. Should show: `Your IP → Guard → Middle → Exit → Website`

### Check .onion Site Access
```
Visit: http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```
✅ If loads = Tor working correctly!

---

## 🔧 Connect Unauthority Wallet to Tor Testnet

### Step 1: Start Tor Browser
```bash
open "/Applications/Tor Browser.app"
# Wait for "Connected to the Tor network"
```

### Step 2: Configure Wallet
1. **Open Wallet** (desktop app or web: http://localhost:5173)
2. Go to **Settings** → **Network**
3. **Node Endpoint:** Enter:
   ```
   http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
   ```
4. Click **"Test Connection"**
   - ✅ Should show: "Connected to node"
5. Click **"Save & Reconnect"**

### Step 3: Test Testnet Access
```bash
# In wallet, go to Dashboard
# Should show:
# - Balance: 0 UAT (or your balance)
# - Status: 🟢 Connected
# - Network: Tor Hidden Service
```

---

## 🧪 Test Tor Connection (Advanced)

### Test via torsocks (CLI)
```bash
# Install torsocks (if Tor Browser doesn't include it)
brew install tor torsocks

# Configure socks proxy (Tor Browser uses 9150, standalone Tor uses 9050)
export TORSOCKS_CONF_FILE=/etc/tor/torsocks.conf

# Test .onion access
torsocks curl http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/health

# Expected response:
# {"status":"healthy","version":"1.0.0","chain":{"id":"uat-mainnet",...}}
```

### Alternative: Use Tor Browser's SOCKS Proxy
```bash
# Tor Browser SOCKS5 proxy: localhost:9150
curl --socks5-hostname localhost:9150 \
  http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/node-info

# Note: Tor Browser must be running!
```

---

## 🔒 Security Best Practices

### ✅ DO:
- **Always verify GPG signature** before installing
- **Download only from official site:** https://www.torproject.org
- **Keep Tor Browser updated** (check for updates monthly)
- **Use Tor Browser for .onion sites** (not regular browser + VPN)
- **Never install browser extensions** in Tor Browser

### ❌ DON'T:
- Don't download from third-party sites (mirrors, forums, etc.)
- Don't maximize Tor Browser window (fingerprinting risk)
- Don't login to personal accounts in Tor Browser
- Don't torrent over Tor (slow + bad for network)
- Don't use Tor Browser + VPN simultaneously (overkill, slower)

---

## 🐛 Troubleshooting

### Problem: "Failed to connect to Tor network"
**Solution:**
1. Check internet connection
2. Restart Tor Browser
3. Try **"Configure"** → Use bridges (if ISP blocks Tor)
4. Check firewall settings (allow Tor Browser)

### Problem: ".onion site won't load"
**Solution:**
1. Verify Tor connected: https://check.torproject.org
2. Check .onion address correct (case-sensitive!)
3. Try **New Circuit** (onion icon → New Circuit)
4. Restart Tor Browser

### Problem: "Your connection is not secure" warning
**Solution:**
- .onion sites use Tor's encryption (no HTTPS needed)
- Click **"Advanced"** → **"Accept Risk"** (safe for .onion)
- Or use HTTP (not HTTPS) for .onion sites

### Problem: macOS blocks app launch
**Solution:**
```bash
# Remove quarantine
xattr -d com.apple.quarantine "/Applications/Tor Browser.app"

# Or System Preferences → Security → "Open Anyway"
```

---

## 📊 Tor Browser Performance

| Metric | Value |
|--------|-------|
| **Connection Time** | 10-30 seconds (first launch) |
| **Page Load Speed** | 2-5x slower than clearnet |
| **Latency** | 200-500ms (vs 20-50ms clearnet) |
| **.onion Load Time** | Faster than clearnet (no exit node!) |
| **Bandwidth** | ~1-5 Mbps (depends on circuit) |

**Note:** .onion sites are FASTER than clearnet because no exit node needed!

---

## 🔗 Official Resources

- **Tor Project:** https://www.torproject.org
- **Download Page:** https://www.torproject.org/download/
- **Signature Verification:** https://support.torproject.org/tbb/how-to-verify-signature/
- **Tor Support:** https://support.torproject.org
- **Check Tor:** https://check.torproject.org

---

## 📝 Quick Reference Card

```bash
# Download Tor Browser
curl -O https://www.torproject.org/dist/torbrowser/13.0.9/TorBrowser-13.0.9-macos_ALL.dmg

# Verify signature
gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
gpg --verify TorBrowser-*.dmg.asc TorBrowser-*.dmg

# Install
open TorBrowser-*.dmg
# Drag to Applications

# Remove quarantine
xattr -d com.apple.quarantine "/Applications/Tor Browser.app"

# Launch
open "/Applications/Tor Browser.app"

# Test connection
# Visit: https://check.torproject.org
# Visit: http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion

# Configure wallet
# Settings → Network → http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
```

---

**🎉 You're now ready to access Unauthority Testnet via Tor!**

**Next:** [TESTNET_OPERATION.md](TESTNET_OPERATION.md) - Learn how to use the testnet
