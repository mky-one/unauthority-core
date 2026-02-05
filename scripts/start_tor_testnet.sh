#!/bin/bash
# UNAUTHORITY REMOTE TESTNET - TOR HIDDEN SERVICE
# Exposes local node via Tor .onion (100% anonymous, free forever)

set -e

echo "🧅 Starting Unauthority Remote Testnet (Tor)..."
echo ""

# Check if backend is running
if ! curl -s http://localhost:3030/health > /dev/null 2>&1; then
    echo "❌ Backend node not running on port 3030"
    echo "   Start it first: ./target/release/uat-node --port 3030 --grpc-port 50051"
    exit 1
fi

echo "✅ Backend node is running"

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

# Check if Tor is already running
if pgrep -f "tor.*unauthority" > /dev/null; then
    echo "✅ Tor daemon already running"
else
    echo "🚀 Starting Tor hidden service..."
    TOR_DIR="$HOME/.tor-unauthority"
    
    # Check if config exists
    if [ ! -f "$TOR_DIR/torrc" ]; then
        echo "❌ Tor config not found. Run: ./scripts/setup_tor_mainnet.sh"
        exit 1
    fi
    
    # Start Tor
    tor -f "$TOR_DIR/torrc" &> "$TOR_DIR/tor.log" &
    echo "   Waiting for Tor to initialize..."
    sleep 10
fi

# Get .onion address
TOR_DIR="$HOME/.tor-unauthority"
if [ -f "$TOR_DIR/hidden_service/hostname" ]; then
    ONION_ADDRESS=$(cat "$TOR_DIR/hidden_service/hostname")
    PUBLIC_URL="http://$ONION_ADDRESS"
else
    echo "❌ Tor hidden service not found. Run: ./scripts/setup_tor_mainnet.sh"
    exit 1
fi

# Test local connection
echo "🧪 Testing local node..."
HEALTH=$(curl -s http://localhost:3030/health | jq -r '.status')
if [ "$HEALTH" != "healthy" ]; then
    echo "❌ Node health check failed"
    exit 1
fi

echo "✅ Node is healthy"
echo ""

# Display connection info
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ TOR TESTNET READY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🧅 PUBLIC URL (Tor):  $PUBLIC_URL"
echo "📍 LOCAL URL:         http://localhost:3030"
echo "🔐 PRIVACY:           100% Anonymous"
echo "💰 COST:              $0 (Free Forever)"
echo ""
echo "📋 SHARE WITH FRIENDS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Download Tor Browser: https://www.torproject.org"
echo "2. Open Tor Browser"
echo "3. Access wallet at: http://localhost:5173"
echo "4. In wallet Settings, change API to: $PUBLIC_URL"
echo "5. Click 'Test Connection' → 'Save & Reconnect'"
echo ""
echo "📊 TEST WITH TORSOCKS (FOR DEVELOPERS):"
echo "   brew install tor  # or: sudo apt install torsocks"
echo "   torsocks curl $PUBLIC_URL/health"
echo "   torsocks curl $PUBLIC_URL/node-info"
echo ""
echo "📖 FULL GUIDE: See TESTNET_ACCESS_GUIDE.md"
echo ""
echo "⚠️  KEEP THESE RUNNING:"
echo "   ✅ UAT Node (PID: $(pgrep -f uat-node))"
echo "   ✅ Tor Daemon (PID: $(pgrep -f 'tor.*unauthority'))"
echo "   ✅ Wallet Frontend: http://localhost:5173"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Testnet is live! Share the .onion URL with your friends."
echo ""
