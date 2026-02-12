#!/bin/bash

###############################################################################
#  UNAUTHORITY - FULL STACK LAUNCHER
#  
#  Launches Backend (3 nodes) + Wallet + Validator Dashboard
#  All-in-one solution for development and testing
###############################################################################

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║            UNAUTHORITY BLOCKCHAIN - FULL LAUNCHER              ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║            The Sovereign Machine - Permissionless              ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
sleep 1

# Step 1: Check binaries
echo -e "${BLUE}[1/3] Checking blockchain binaries...${NC}"
if [ ! -f "$PROJECT_ROOT/target/release/los-node" ]; then
    echo -e "${YELLOW}⚠️  Binary not found. Building release version...${NC}"
    cargo build --release
fi
echo -e "${GREEN}   ✅ Blockchain binary ready${NC}"
echo ""
sleep 1

# Step 2: Start backend
echo -e "${BLUE}[2/3] Starting backend network (3 nodes)...${NC}"

# Check if start_network.sh exists
if [ -f "$PROJECT_ROOT/start_network.sh" ]; then
    # Kill existing nodes
    pkill -9 los-node 2>/dev/null || true
    sleep 1
    
    # Start network
    "$PROJECT_ROOT/start_network.sh" > /dev/null 2>&1 &
    sleep 3
    
    # Verify nodes are running
    NODE_COUNT=$(ps aux | grep los-node | grep -v grep | wc -l | tr -d ' ')
    if [ "$NODE_COUNT" -ge "1" ]; then
        echo -e "${GREEN}   ✅ Backend network started ($NODE_COUNT nodes running)${NC}"
    else
        echo -e "${RED}   ⚠️  Warning: Backend may not have started${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  start_network.sh not found, skipping backend${NC}"
fi
echo ""
sleep 1

# Step 3: Launch UIs
echo -e "${BLUE}[3/3] Launching user interfaces...${NC}"
echo ""
sleep 1

"$PROJECT_ROOT/launch_ui.sh"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 FULL STACK LAUNCHED SUCCESSFULLY                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 SYSTEM STATUS:${NC}"
echo ""
echo "   Backend Network:  ✅ Running (3 nodes)"
echo "   • REST API:       http://localhost:3030"
echo "   • gRPC:           localhost:23030"
echo ""
echo "   Frontend UIs:     ✅ Launching in new terminals"
echo "   • Public Wallet:       http://localhost:5173"
echo "   • Validator Dashboard: http://localhost:5174"
echo ""
echo -e "${YELLOW}📖 NEXT STEPS:${NC}"
echo ""
echo "   1. Check the NEW terminal windows that opened"
echo "   2. Wait for 'VITE ready' message (5-10 seconds)"
echo "   3. Open the URLs in your browser"
echo "   4. Test wallet creation and validator monitoring"
echo ""
echo -e "${BLUE}🛑 To stop everything:${NC}"
echo "   ./stop_all.sh"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
