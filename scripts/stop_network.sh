#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
#  UNAUTHORITY NETWORK STOPPER
# ═══════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}🛑 Stopping Unauthority Network...${NC}"
echo ""

if [ -f node_data/pids.txt ]; then
    echo "   Reading PIDs from file..."
    while read pid; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo -e "   ${GREEN}✓${NC} Stopped process $pid"
        else
            echo -e "   ${YELLOW}⚠${NC}  Process $pid already stopped"
        fi
    done < node_data/pids.txt
    
    # Clean up PID file
    rm node_data/pids.txt
    echo ""
    echo -e "${GREEN}✅ All nodes stopped successfully${NC}"
else
    echo "   No PIDs file found. Attempting to kill by name..."
    pkill -f "uat-node" && echo -e "   ${GREEN}✓${NC} Killed uat-node processes" || echo -e "   ${YELLOW}⚠${NC}  No processes found"
    echo ""
    echo -e "${GREEN}✅ Cleanup complete${NC}"
fi

echo ""
