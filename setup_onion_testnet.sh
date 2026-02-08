#!/bin/bash
# Setup Unauthority Testnet sebagai Tor Hidden Service
# 100% FREE, NO VPS, ANONYMOUS

set -e

echo "🧅 UNAUTHORITY .ONION TESTNET SETUP"
echo "===================================="
echo ""

# 1. Check Tor Browser Bundle installed
if [ ! -d "/Applications/Tor Browser.app" ]; then
    echo "❌ Tor Browser not found!"
    echo "📥 Download from: https://www.torproject.org/download/"
    exit 1
fi

echo "✅ Tor Browser found"

# 2. Get Tor data directory
TOR_DATA_DIR="$HOME/Library/Application Support/TorBrowser-Data/Tor"
TORRC_FILE="$TOR_DATA_DIR/torrc"

echo "📁 Tor config: $TORRC_FILE"

# 3. Backup existing torrc
if [ -f "$TORRC_FILE" ]; then
    cp "$TORRC_FILE" "$TORRC_FILE.backup.$(date +%s)"
    echo "✅ Backed up existing torrc"
fi

# 4. Create hidden service directory
HIDDEN_SERVICE_DIR="$HOME/uat-testnet-onion"
mkdir -p "$HIDDEN_SERVICE_DIR"

echo "📁 Hidden service dir: $HIDDEN_SERVICE_DIR"

# 5. Add hidden service config to torrc
echo "" >> "$TORRC_FILE"
echo "# UAT Testnet Hidden Service" >> "$TORRC_FILE"
echo "HiddenServiceDir $HIDDEN_SERVICE_DIR" >> "$TORRC_FILE"
echo "HiddenServicePort 80 127.0.0.1:3030" >> "$TORRC_FILE"

echo "✅ Tor config updated"

# 6. Instructions
cat << 'EOF'

📋 NEXT STEPS:
==============

1. RESTART TOR BROWSER
   - Close Tor Browser completely
   - Start Tor Browser again
   
2. GET YOUR .ONION ADDRESS:
   cat ~/uat-testnet-onion/hostname
   
3. START VALIDATORS:
   cd unauthority-core
   ./scripts/launch_3_validators.sh
   
4. TEST CONNECTION:
   # Di terminal baru:
   curl -x socks5h://localhost:9150 http://$(cat ~/uat-testnet-onion/hostname)/health
   
5. SHARE .ONION URL KE TEMAN:
   http://[YOUR_ONION_ADDRESS]
   
⚠️  PENTING:
- Keep Tor Browser RUNNING (jangan di-quit)
- Keep validators RUNNING (jangan di-stop)
- MacBook harus online agar teman bisa akses

🔒 ANONYMOUS & FREE:
- Tidak ada VPS = tidak ada billing info
- .onion address random = tidak traceable
- Tor encryption = anonymous hosting

EOF

echo ""
echo "✅ Setup complete! Follow steps above."
