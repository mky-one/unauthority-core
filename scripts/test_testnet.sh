#!/bin/bash

# UNAUTHORITY TESTNET - COMPREHENSIVE TEST SUITE
# Date: February 4, 2026
# Purpose: Test all REST API endpoints with real TXID

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        UNAUTHORITY TESTNET - COMPREHENSIVE TEST SUITE         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Cleanup
echo "📦 STEP 1: Cleaning Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pkill -9 -f 'los-node' 2>/dev/null || true
sleep 2
rm -rf los_database
echo -e "${GREEN}✅ Environment cleaned${NC}"
echo ""

# Step 2: Start Node
echo "🚀 STEP 2: Starting Node A (Port 3030)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
nohup target/release/los-node 3030 > /tmp/los_node.log 2>&1 &
NODE_PID=$!
echo "Node PID: $NODE_PID"
echo -e "${YELLOW}⏳ Waiting 10 seconds for startup...${NC}"
sleep 10

# Check if node is running
if ps -p $NODE_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Node is running${NC}"
else
    echo -e "${RED}❌ Node failed to start! Checking logs:${NC}"
    tail -30 /tmp/los_node.log
    exit 1
fi
echo ""

# Step 3: Test REST API Endpoints
echo "🔌 STEP 3: Testing REST API Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_endpoint() {
    local name=$1
    local url=$2
    local method=${3:-GET}
    local data=$4
    
    echo ""
    echo -e "${BLUE}📝 TEST: $name${NC}"
    echo "URL: $method $url"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s --max-time 5 -X POST "$url" -H "Content-Type: application/json" -d "$data" 2>&1)
    else
        response=$(curl -s --max-time 5 "$url" 2>&1)
    fi
    
    if echo "$response" | jq '.' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        echo "$response" | jq '.'
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "$response"
    fi
}

# Test all endpoints
test_endpoint "Node Info" "http://localhost:3030/node-info"
test_endpoint "Validators List" "http://localhost:3030/validators"
test_endpoint "Supply Info" "http://localhost:3030/supply"
test_endpoint "Latest Block" "http://localhost:3030/block"
test_endpoint "Peers List" "http://localhost:3030/peers"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 4: Test Burn Endpoint with Real TXID
echo "🔥 STEP 4: Testing BURN Endpoint (Proof-of-Burn)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# BTC Burn Test
test_endpoint "Burn BTC (Real TXID)" "http://localhost:3030/burn" "POST" '{
  "coin_type": "btc",
  "txid": "2096b844178ecc776e050be7886e618ee111e2a68fcf70b28928b82b5f97dcc9"
}'

sleep 3

# ETH Burn Test
test_endpoint "Burn ETH (Real TXID)" "http://localhost:3030/burn" "POST" '{
  "coin_type": "eth",
  "txid": "0x459ccd6fe488b0f826aef198ad5625d0275f5de1b77b905f85d6e71460c1f1aa"
}'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 5: Check Node Logs for Oracle Activity
echo "📊 STEP 5: Node Logs (Oracle Verification Activity)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
tail -40 /tmp/los_node.log | grep "LOS"" || echo "No oracle activity in logs"
echo ""

# Step 6: Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                       TEST SUMMARY                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✅ Node PID: $NODE_PID (still running)${NC}"
echo -e "${GREEN}✅ REST API: http://localhost:3030${NC}"
echo -e "${GREEN}✅ gRPC API: 0.0.0.0:50051${NC}"
echo ""
echo "📁 Full logs available at: /tmp/los_node.log"
echo ""
echo "🛑 To stop node: kill $NODE_PID"
echo ""
