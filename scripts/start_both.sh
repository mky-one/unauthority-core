#!/bin/bash

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Unauthority Node + Wallet${NC}"
echo "================================================"

cd "$(dirname "$0")"

# Clean old database
echo -e "${YELLOW}🧹 Cleaning old database...${NC}"
rm -rf los_database

# Start node in background with stdin redirect
echo -e "${BLUE}📡 Starting Unauthority Node...${NC}"
(cat /dev/null | ./target/release/los-node 3030 > /tmp/los_node.log 2>&1 &)
NODE_PID=$!

echo -e "${GREEN}✅ Node started (PID: $NODE_PID)${NC}"
echo -e "${YELLOW}⏳ Waiting 5 seconds for initialization...${NC}"
sleep 5

# Check if node API is responding
if curl -s http://localhost:3030/supply > /dev/null 2>&1; then
    SUPPLY=$(curl -s http://localhost:3030/supply)
    echo -e "${GREEN}✅ Node API responding (Supply: $SUPPLY VOI)${NC}"
else
    echo -e "${YELLOW}⚠️  Node API not responding yet (check /tmp/los_node.log)${NC}"
    echo "   You can still use the wallet, but node connection will be offline."
fi

echo ""
echo -e "${BLUE}🎨 Starting Wallet...${NC}"
cd frontend-wallet

# Start wallet (this will block)
npm run dev

# Cleanup on exit
trap "kill $NODE_PID 2>/dev/null; echo 'Stopped node'" EXIT
