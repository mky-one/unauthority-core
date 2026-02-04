#!/bin/bash

###############################################################################
#  UNAUTHORITY - DAEMON MODE LAUNCHER
#  
#  Starts backend nodes in pure daemon mode (no interactive wait)
#  Nodes persist in background until explicitly stopped
###############################################################################

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        UNAUTHORITY BACKEND - DAEMON MODE                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check binary
if [ ! -f "$PROJECT_ROOT/target/release/uat-node" ]; then
    echo -e "${RED}❌ Binary not found. Build first:${NC} cargo build --release"
    exit 1
fi

# Kill existing
echo -e "${YELLOW}🧹 Cleaning existing processes...${NC}"
pkill -9 uat-node 2>/dev/null || true
sleep 1
echo -e "${GREEN}   ✓ Clean${NC}"
echo ""

# Create dirs
mkdir -p node_data/{validator-1,validator-2,validator-3}

# Start Node 1
echo -e "${BLUE}[1/3] Starting Node 1 (port 3030)...${NC}"
cd "$PROJECT_ROOT"
nohup env UAT_NODE_ID="validator-1" ./target/release/uat-node 3030 > node_data/validator-1/node.log 2>&1 & disown
PID1=$!
echo "   PID: $PID1"
echo ""

sleep 2

# Start Node 2
echo -e "${BLUE}[2/3] Starting Node 2 (port 3031)...${NC}"
nohup env UAT_NODE_ID="validator-2" ./target/release/uat-node 3031 > node_data/validator-2/node.log 2>&1 & disown
PID2=$!
echo "   PID: $PID2"
echo ""

sleep 2

# Start Node 3
echo -e "${BLUE}[3/3] Starting Node 3 (port 3032)...${NC}"
nohup env UAT_NODE_ID="validator-3" ./target/release/uat-node 3032 > node_data/validator-3/node.log 2>&1 & disown
PID3=$!
echo "   PID: $PID3"
echo ""

# Save PIDs
echo "$PID1" > node_data/pids.txt
echo "$PID2" >> node_data/pids.txt
echo "$PID3" >> node_data/pids.txt

# Wait for initialization
echo -e "${YELLOW}⏳ Waiting 5 seconds for initialization...${NC}"
sleep 5

# Verify
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BACKEND STARTED IN DAEMON MODE                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

RUNNING=$(ps aux | grep uat-node | grep -v grep | wc -l | tr -d ' ')
echo -e "${CYAN}📊 Status:${NC} $RUNNING nodes running"
echo ""
echo -e "${BLUE}🔗 API Endpoints:${NC}"
echo "   • Node 1: http://localhost:3030/node-info"
echo "   • Node 2: http://localhost:3031/node-info"
echo "   • Node 3: http://localhost:3032/node-info"
echo ""
echo -e "${BLUE}📝 View Logs:${NC}"
echo "   tail -f node_data/validator-1/node.log"
echo ""
echo -e "${RED}🛑 Stop:${NC}"
echo "   ./stop_all.sh"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test connection
echo -e "${YELLOW}Testing API...${NC}"
sleep 2
curl -s http://localhost:3030/node-info > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ API responding!${NC}"
else
    echo -e "${YELLOW}⚠️  API not responding yet (may need more time)${NC}"
fi
echo ""
