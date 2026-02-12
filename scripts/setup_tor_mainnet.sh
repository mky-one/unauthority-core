#!/bin/bash
# UNAUTHORITY MAINNET - TOR HIDDEN SERVICE SETUP
# 100% Free, Anonymous, Production-Ready

set -e

echo "🧅 Setting up Tor Hidden Service for Unauthority Mainnet..."
echo ""

# Check if Tor is installed
if ! command -v tor &> /dev/null; then
    echo "📦 Installing Tor..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install tor
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y tor
    else
        echo "❌ Unsupported OS. Install Tor manually from https://www.torproject.org"
        exit 1
    fi
fi

echo "✅ Tor installed"
echo ""

# Create Tor config directory
TOR_DIR="$HOME/.tor-unauthority"
mkdir -p "$TOR_DIR"

# Generate Tor configuration
cat > "$TOR_DIR/torrc" << 'EOF'
# Unauthority Mainnet Hidden Service Configuration
# This exposes localhost:3030 to Tor network

HiddenServiceDir /Users/moonkey-code/.tor-unauthority/hidden_service
HiddenServicePort 80 127.0.0.1:3030

# Security settings
SocksPort 0
ControlPort 0
DataDirectory /Users/moonkey-code/.tor-unauthority/data

# Performance tuning
NumEntryGuards 8
UseEntryGuards 1
EOF

# Replace username in config
sed -i.bak "s|/Users/moonkey-code|$HOME|g" "$TOR_DIR/torrc"

echo "📝 Tor config created at: $TOR_DIR/torrc"
echo ""

# Start Tor daemon
echo "🚀 Starting Tor daemon..."
tor -f "$TOR_DIR/torrc" &> "$TOR_DIR/tor.log" &
TOR_PID=$!
echo "Tor PID: $TOR_PID"

# Wait for hidden service to be created (takes 30-60 seconds)
echo "⏳ Waiting for .onion address generation (30-60 seconds)..."
for i in {1..60}; do
    if [ -f "$TOR_DIR/hidden_service/hostname" ]; then
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

# Check if hostname was generated
if [ ! -f "$TOR_DIR/hidden_service/hostname" ]; then
    echo "❌ Failed to generate .onion address. Check logs:"
    echo "   tail -f $TOR_DIR/tor.log"
    exit 1
fi

# Read .onion address
ONION_ADDRESS=$(cat "$TOR_DIR/hidden_service/hostname")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ TOR HIDDEN SERVICE AKTIF!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🧅 MAINNET .ONION ADDRESS:"
echo "   http://$ONION_ADDRESS"
echo ""
echo "📍 LOCAL NODE: http://localhost:3030"
echo "🔐 PRIVACY: 100% Anonymous"
echo "💰 COST: $0 (Free Forever)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 SHARE THIS WITH USERS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Install Tor Browser: https://www.torproject.org"
echo "2. Open Tor Browser"
echo "3. Connect wallet to: http://$ONION_ADDRESS"
echo ""
echo "OR for developers (command line):"
echo "   torsocks curl http://$ONION_ADDRESS/node-info"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "• Keep Tor daemon running (PID $TOR_PID)"
echo "• Keep node running on localhost:3030"
echo "• .onion address is PERMANENT (unless you delete hidden_service/)"
echo "• To stop: kill $TOR_PID"
echo ""
echo "📂 Tor data stored at: $TOR_DIR"
echo "📄 Tor logs: $TOR_DIR/tor.log"
echo ""

# Save connection info
cat > "mainnet-tor-connection.txt" << EOF
UNAUTHORITY MAINNET - TOR HIDDEN SERVICE
═════════════════════════════════════════

MAINNET ADDRESS:
http://$ONION_ADDRESS

STATUS: Active
PRIVACY: 100% Anonymous
COST: Free Forever

USER INSTRUCTIONS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Download Tor Browser from https://www.torproject.org
2. Open Tor Browser
3. In Unauthority Wallet Settings:
   - Change API Endpoint to: http://$ONION_ADDRESS
   - Click "Test Connection"
   - Click "Save & Reconnect"

DEVELOPER ACCESS (CLI):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install torsocks (proxy for Tor)
brew install tor  # macOS
sudo apt install torsocks  # Linux

# Test connection
torsocks curl http://$ONION_ADDRESS/node-info

# Check balance
torsocks curl http://$ONION_ADDRESS/balance/LOS...

DAEMON INFO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tor PID: $TOR_PID
Tor Config: $TOR_DIR/torrc
Tor Logs: $TOR_DIR/tor.log
Hidden Service Dir: $TOR_DIR/hidden_service

MAINTAINER:
Keep both running in background:
1. Tor daemon (PID $TOR_PID)
2. LOS node (localhost:3030)

To stop:
kill $TOR_PID

Generated: $(date)
EOF

echo "💾 Connection info saved to: mainnet-tor-connection.txt"
echo ""
echo "🎯 MAINNET READY - Share .onion address with your users!"
