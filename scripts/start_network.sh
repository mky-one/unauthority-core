#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════════════
#  UNAUTHORITY 3-NODE NETWORK LAUNCHER (Production-Grade)
# ═══════════════════════════════════════════════════════════════════════════

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        UNAUTHORITY 3-NODE TESTNET LAUNCHER               ║"
echo "║        Multi-Node Blockchain with aBFT Consensus         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if binary exists
if [ ! -f "target/release/los-node" ]; then
    echo -e "${RED}❌ Binary not found!${NC}"
    echo "   Building release binary..."
    cargo build --release --bin los-node || exit 1
    echo -e "${GREEN}✅ Build complete${NC}"
    echo ""
fi

# Clean old processes
echo -e "${YELLOW}🧹 Cleaning old processes...${NC}"
pkill -9 los-node 2>/dev/null && echo "   Killed existing nodes" || echo "   No existing processes"

# Clean old PID file
rm -f node_data/pids.txt

# Create node directories
echo ""
echo -e "${BLUE}📁 Creating node directories...${NC}"
mkdir -p node_data/validator-{1,2,3}
echo "   ✓ node_data/validator-1/"
echo "   ✓ node_data/validator-2/"
echo "   ✓ node_data/validator-3/"

# Optional: Clean databases for fresh start (comment out for persistence)
# echo ""
# echo -e "${YELLOW}⚠️  Cleaning databases (fresh start)...${NC}"
# rm -rf node_data/validator-*/los_database
# echo "   Databases cleared"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# NODE 1 (REST: 3030, gRPC: 23030)
# ───────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}▶️  Starting Node 1 (Validator 1)${NC}"
echo "   Node ID: validator-1"
echo "   REST API: http://localhost:3030"
echo "   gRPC API: localhost:23030"
echo "   Database: node_data/validator-1/los_database"
echo "   Log file: node_data/validator-1/node.log"

export LOS_NODE_ID="validator-1"
./target/release/los-node 3030 > node_data/validator-1/node.log 2>&1 &
PID1=$!

echo -e "   ${GREEN}✓ Started (PID: $PID1)${NC}"
echo ""

sleep 3

# ───────────────────────────────────────────────────────────────────────────
# NODE 2 (REST: 3031, gRPC: 23031)
# ───────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}▶️  Starting Node 2 (Validator 2)${NC}"
echo "   Node ID: validator-2"
echo "   REST API: http://localhost:3031"
echo "   gRPC API: localhost:23031"
echo "   Database: node_data/validator-2/los_database"
echo "   Log file: node_data/validator-2/node.log"

export LOS_NODE_ID="validator-2"
./target/release/los-node 3031 > node_data/validator-2/node.log 2>&1 &
PID2=$!

echo -e "   ${GREEN}✓ Started (PID: $PID2)${NC}"
echo ""

sleep 3

# ───────────────────────────────────────────────────────────────────────────
# NODE 3 (REST: 3032, gRPC: 23032)
# ───────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}▶️  Starting Node 3 (Validator 3)${NC}"
echo "   Node ID: validator-3"
echo "   REST API: http://localhost:3032"
echo "   gRPC API: localhost:23032"
echo "   Database: node_data/validator-3/los_database"
echo "   Log file: node_data/validator-3/node.log"

export LOS_NODE_ID="validator-3"
./target/release/los-node 3032 > node_data/validator-3/node.log 2>&1 &
PID3=$!

echo -e "   ${GREEN}✓ Started (PID: $PID3)${NC}"
echo ""

# Save PIDs for easy cleanup
echo "$PID1" > node_data/pids.txt
echo "$PID2" >> node_data/pids.txt
echo "$PID3" >> node_data/pids.txt

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ All 3 nodes started successfully!${NC}"
echo ""

# Wait for nodes to initialize
echo -e "${YELLOW}⏳ Waiting for nodes to initialize (10 seconds)...${NC}"
for i in {10..1}; do
    echo -ne "   $i seconds remaining...\r"
    sleep 1
done
echo -e "   ${GREEN}✓ Initialization complete${NC}              "
echo ""

# ───────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ───────────────────────────────────────────────────────────────────────────

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📊 Quick Health Check${NC}"
echo ""

# Check Node 1
echo -n "   Node 1 (3030): "
if curl -s http://localhost:3030/supply > /dev/null 2>&1; then
    SUPPLY_1=$(curl -s http://localhost:3030/supply | grep -o '"remaining_supply_cil":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}ONLINE${NC} (Supply: $SUPPLY_1 CIL)"
else
    echo -e "${RED}OFFLINE${NC}"
fi

# Check Node 2
echo -n "   Node 2 (3031): "
if curl -s http://localhost:3031/supply > /dev/null 2>&1; then
    SUPPLY_2=$(curl -s http://localhost:3031/supply | grep -o '"remaining_supply_cil":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}ONLINE${NC} (Supply: $SUPPLY_2 CIL)"
else
    echo -e "${RED}OFFLINE${NC}"
fi

# Check Node 3
echo -n "   Node 3 (3032): "
if curl -s http://localhost:3032/supply > /dev/null 2>&1; then
    SUPPLY_3=$(curl -s http://localhost:3032/supply | grep -o '"remaining_supply_cil":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}ONLINE${NC} (Supply: $SUPPLY_3 CIL)"
else
    echo -e "${RED}OFFLINE${NC}"
fi

echo ""

# ───────────────────────────────────────────────────────────────────────────
# USAGE INSTRUCTIONS
# ───────────────────────────────────────────────────────────────────────────

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📝 COMMANDS & MONITORING${NC}"
echo ""
echo -e "${BLUE}Monitor Logs:${NC}"
echo "   tail -f node_data/validator-1/node.log"
echo "   tail -f node_data/validator-2/node.log"
echo "   tail -f node_data/validator-3/node.log"
echo ""
echo -e "${BLUE}API Endpoints:${NC}"
echo "   Node 1: curl http://localhost:3030/node-info"
echo "   Node 2: curl http://localhost:3031/node-info"
echo "   Node 3: curl http://localhost:3032/node-info"
echo ""
echo -e "${BLUE}Test Transaction:${NC}"
echo "   curl -X POST http://localhost:3030/send \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"target\":\"los_test\",\"amount\":1000000}'"
echo ""
echo -e "${BLUE}Test Burn (PoB):${NC}"
echo "   curl -X POST http://localhost:3030/burn \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"coin_type\":\"btc\",\"txid\":\"abc123...\",\"recipient_address\":\"LOS...\"}'"
echo ""
echo -e "${RED}Stop All Nodes:${NC}"
echo "   ./stop_network.sh"
echo "   OR: kill \$(cat node_data/pids.txt)"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🚀 Network is running! Press Ctrl+C to stop (or run stop_network.sh)${NC}"
echo ""

# Keep script running and handle graceful shutdown
trap "echo ''; echo -e '${YELLOW}🛑 Shutting down network...${NC}'; kill $PID1 $PID2 $PID3 2>/dev/null; echo -e '${GREEN}✅ All nodes stopped${NC}'; exit" INT TERM

wait
