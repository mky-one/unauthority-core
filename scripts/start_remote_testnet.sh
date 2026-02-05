#!/bin/bash

# Remote Testnet Setup Script
# Automatically exposes local node to internet using Ngrok

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       UNAUTHORITY REMOTE TESTNET SETUP                  ║"
echo "║       Expose local node to internet for friends         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo -e "${YELLOW}⚠️  Ngrok not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ngrok/ngrok/ngrok
        else
            echo -e "${RED}❌ Homebrew not found. Please install from https://brew.sh${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok -y
    else
        echo -e "${RED}❌ Unsupported OS. Please install ngrok manually from https://ngrok.com/download${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Ngrok installed${NC}"
fi

# Check if ngrok is configured
if ! ngrok config check &> /dev/null; then
    echo -e "${YELLOW}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NGROK AUTHENTICATION REQUIRED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    echo "1. Visit: https://dashboard.ngrok.com/signup"
    echo "2. Sign up for FREE account"
    echo "3. Copy your auth token from dashboard"
    echo ""
    read -p "Enter your Ngrok auth token: " AUTH_TOKEN
    
    ngrok config add-authtoken "$AUTH_TOKEN"
    echo -e "${GREEN}✅ Ngrok configured${NC}"
fi

# Check if node is running
echo -e "${BLUE}🔍 Checking if node is running...${NC}"
if curl -s http://localhost:3030/node-info > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Node is running${NC}"
else
    echo -e "${YELLOW}⚠️  Node not running. Starting node...${NC}"
    
    # Build if needed
    if [ ! -f "target/release/uat-node" ]; then
        echo -e "${BLUE}🔨 Building node...${NC}"
        cargo build --release
    fi
    
    # Start node in background
    nohup ./target/release/uat-node \
        --port 3030 \
        --api-port 3030 \
        --ws-port 9030 \
        --wallet node_data/validator-1/wallet.json \
        > node_data/validator-1/node.log 2>&1 &
    
    echo "Waiting for node to start..."
    sleep 5
    
    if curl -s http://localhost:3030/node-info > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Node started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start node. Check logs: tail -f node_data/validator-1/node.log${NC}"
        exit 1
    fi
fi

# Get node info
NODE_INFO=$(curl -s http://localhost:3030/node-info)
NODE_ADDRESS=$(echo "$NODE_INFO" | grep -o '"node_address":"[^"]*"' | cut -d'"' -f4)
CHAIN_NAME=$(echo "$NODE_INFO" | grep -o '"chain_name":"[^"]*"' | cut -d'"' -f4)

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Starting Ngrok tunnel...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Kill any existing ngrok processes
pkill ngrok 2>/dev/null || true
sleep 2

# Start ngrok in background
nohup ngrok http 3030 > /dev/null 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
echo "Waiting for ngrok to initialize..."
sleep 5

# Get public URL
PUBLIC_URL=""
for i in {1..10}; do
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    if [ ! -z "$PUBLIC_URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$PUBLIC_URL" ]; then
    echo -e "${RED}❌ Failed to get ngrok public URL${NC}"
    echo "Check ngrok web interface: http://localhost:4040"
    exit 1
fi

# Success message
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  ✅ TESTNET READY!                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${BLUE}📡 PUBLIC ENDPOINT:${NC}"
echo -e "${GREEN}   $PUBLIC_URL${NC}"
echo ""
echo -e "${BLUE}🆔 NODE INFO:${NC}"
echo "   Address: $NODE_ADDRESS"
echo "   Chain: $CHAIN_NAME"
echo ""
echo -e "${BLUE}🧪 TEST ENDPOINTS:${NC}"
echo "   Node Info:  ${PUBLIC_URL}/node-info"
echo "   Balance:    ${PUBLIC_URL}/balance/UAT..."
echo "   Faucet:     ${PUBLIC_URL}/faucet"
echo "   Send:       ${PUBLIC_URL}/send"
echo ""
echo -e "${BLUE}📊 MONITORING:${NC}"
echo "   Ngrok Dashboard: http://localhost:4040"
echo "   Node Logs:       tail -f node_data/validator-1/node.log"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}SHARE THIS WITH YOUR FRIENDS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "🌐 Unauthority Testnet Node"
echo "   Endpoint: $PUBLIC_URL"
echo ""
echo "📝 Instructions:"
echo "   1. Download wallet from GitHub releases"
echo "   2. In wallet Settings, change API endpoint to:"
echo "      $PUBLIC_URL"
echo "   3. Create/import wallet"
echo "   4. Request faucet (100 UAT)"
echo "   5. Start testing!"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}ℹ️  TIPS:${NC}"
echo "   - Ngrok URL changes every restart (upgrade to paid for static URL)"
echo "   - Free tier has 40 connections/minute limit"
echo "   - Keep this terminal open to maintain connection"
echo "   - Press Ctrl+C to stop tunnel"
echo ""

# Create shareable connection info file
cat > testnet-connection-info.txt <<EOF
═══════════════════════════════════════════════════════
    UNAUTHORITY TESTNET - PUBLIC CONNECTION INFO
═══════════════════════════════════════════════════════

🌐 PUBLIC ENDPOINT:
   $PUBLIC_URL

🧪 TEST ENDPOINTS:
   Node Info:  ${PUBLIC_URL}/node-info
   Balance:    ${PUBLIC_URL}/balance/<your-address>
   Faucet:     ${PUBLIC_URL}/faucet
   Send TX:    ${PUBLIC_URL}/send

📱 WALLET SETUP:
   1. Download wallet app
   2. Settings → Network Settings
   3. Change API Endpoint to: $PUBLIC_URL
   4. Save & Reconnect

🎯 QUICK TEST:
   # Test connection
   curl ${PUBLIC_URL}/node-info

   # Get balance
   curl ${PUBLIC_URL}/balance/UAT...

   # Request faucet (100 UAT)
   curl -X POST ${PUBLIC_URL}/faucet \\
     -H "Content-Type: application/json" \\
     -d '{"address": "UAT..."}'

⚠️  NOTES:
   - This is testnet - tokens have NO real value
   - URL valid until I restart ngrok
   - Rate limit: 40 req/min (free tier)

📞 SUPPORT:
   Discord: https://discord.gg/unauthority
   GitHub: https://github.com/unauthority/core

═══════════════════════════════════════════════════════
Generated: $(date)
═══════════════════════════════════════════════════════
EOF

echo -e "${GREEN}✅ Connection info saved to: testnet-connection-info.txt${NC}"
echo ""

# Keep script running
echo -e "${BLUE}🔄 Tunnel is active. Press Ctrl+C to stop...${NC}"
echo ""

# Wait for ngrok process
wait $NGROK_PID
