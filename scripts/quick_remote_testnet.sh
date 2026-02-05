#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                    UNAUTHORITY - QUICK REMOTE TESTNET                        ║
# ║              Share your testnet with friends in 1 command!                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🌐 UNAUTHORITY REMOTE TESTNET                             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Check/Install ngrok
echo -e "${BLUE}[1/5] Checking ngrok...${NC}"
if ! command -v ngrok &> /dev/null; then
    echo -e "${YELLOW}    Installing ngrok...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ngrok/ngrok/ngrok 2>/dev/null || {
            echo -e "${RED}    Failed. Please install manually: https://ngrok.com/download${NC}"
            exit 1
        }
    else
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok -y
    fi
fi
echo -e "${GREEN}    ✓ ngrok ready${NC}"

# Check ngrok auth
if ! ngrok config check &> /dev/null 2>&1; then
    echo -e "${YELLOW}    ⚠️  ngrok needs authentication${NC}"
    echo "    1. Go to: https://dashboard.ngrok.com/signup"
    echo "    2. Get your auth token"
    echo ""
    read -p "    Enter auth token: " TOKEN
    ngrok config add-authtoken "$TOKEN"
fi

# 2. Stop old processes
echo -e "${BLUE}[2/5] Cleaning up old processes...${NC}"
pkill -f "uat-node" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
sleep 2
echo -e "${GREEN}    ✓ Clean${NC}"

# 3. Build if needed
echo -e "${BLUE}[3/5] Checking backend build...${NC}"
if [ ! -f "target/release/uat-node" ]; then
    echo -e "${YELLOW}    Building (this may take a minute)...${NC}"
    cargo build --release 2>&1 | tail -3
fi
echo -e "${GREEN}    ✓ Backend ready${NC}"

# 4. Start node
echo -e "${BLUE}[4/5] Starting UAT node...${NC}"
mkdir -p node_data/validator-1
mkdir -p logs

nohup ./target/release/uat-node \
    --port 3030 \
    --api-port 3030 \
    --ws-port 9030 \
    > logs/node.log 2>&1 &

NODE_PID=$!
echo $NODE_PID > logs/node.pid

# Wait for node
for i in {1..15}; do
    if curl -s http://localhost:3030/health > /dev/null 2>&1; then
        echo -e "${GREEN}    ✓ Node running (PID: $NODE_PID)${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 15 ]; then
        echo -e "${RED}    ✗ Node failed to start. Check logs/node.log${NC}"
        exit 1
    fi
done

# 5. Start ngrok
echo -e "${BLUE}[5/5] Creating public tunnel...${NC}"
nohup ngrok http 3030 --log=stdout > logs/ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > logs/ngrok.pid

sleep 5

# Get public URL
PUBLIC_URL=""
for i in {1..10}; do
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    if [ ! -z "$PUBLIC_URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$PUBLIC_URL" ]; then
    echo -e "${RED}    ✗ Failed to get public URL${NC}"
    echo "    Check http://localhost:4040 for details"
    exit 1
fi

echo -e "${GREEN}    ✓ Tunnel created${NC}"

# Success!
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         ✅ TESTNET READY!                                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🌐 PUBLIC URL:${NC} ${YELLOW}$PUBLIC_URL${NC}"
echo ""
echo -e "${CYAN}📋 SHARE THIS WITH YOUR FRIENDS:${NC}"
echo ""
echo "   ┌──────────────────────────────────────────────────────────────────┐"
echo "   │  🎮 JOIN MY UAT TESTNET!                                         │"
echo "   │                                                                  │"
echo "   │  Endpoint: $PUBLIC_URL"
echo "   │                                                                  │"
echo "   │  1. Download wallet from GitHub releases                         │"
echo "   │  2. Settings → API Endpoint → paste URL above                    │"
echo "   │  3. Create wallet → Request faucet (100 UAT)                     │"
echo "   │  4. Send transactions to each other!                             │"
echo "   └──────────────────────────────────────────────────────────────────┘"
echo ""
echo -e "${CYAN}📊 MONITORING:${NC}"
echo "   Node logs:  tail -f logs/node.log"
echo "   Ngrok:      http://localhost:4040"
echo ""
echo -e "${CYAN}🧪 QUICK TEST:${NC}"
echo "   curl $PUBLIC_URL/node-info"
echo ""
echo -e "${YELLOW}⚠️  Keep this terminal open. Press Ctrl+C to stop.${NC}"
echo ""

# Save info
cat > TESTNET_INFO.txt << EOF
══════════════════════════════════════════════════════════
         UNAUTHORITY TESTNET - CONNECTION INFO
══════════════════════════════════════════════════════════

🌐 PUBLIC ENDPOINT: $PUBLIC_URL

📱 FOR YOUR FRIENDS:
1. Download Unauthority Wallet
2. Settings → API Endpoint
3. Enter: $PUBLIC_URL
4. Save & Connect
5. Create wallet
6. Request faucet (100 UAT)
7. Start testing!

🧪 TEST COMMANDS:
curl $PUBLIC_URL/node-info
curl $PUBLIC_URL/health
curl $PUBLIC_URL/validators

Generated: $(date)
══════════════════════════════════════════════════════════
EOF

echo -e "${GREEN}📄 Saved to: TESTNET_INFO.txt${NC}"
echo ""

# Trap cleanup
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down...${NC}"
    [ -f logs/node.pid ] && kill $(cat logs/node.pid) 2>/dev/null
    [ -f logs/ngrok.pid ] && kill $(cat logs/ngrok.pid) 2>/dev/null
    rm -f logs/*.pid
    echo -e "${GREEN}✓ Stopped${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Keep alive
while true; do
    sleep 30
    if ! curl -s http://localhost:3030/health > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Node health check failed${NC}"
    fi
done
