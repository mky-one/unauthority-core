#!/bin/bash
# Stop All Testnet Validators

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Stopping UAT Testnet Validators                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to stop validator
stop_validator() {
    local NODE_NUM=$1
    local PID_FILE="$PROJECT_ROOT/node_data/validator-$NODE_NUM/node.pid"
    
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "${YELLOW}⏹️  Stopping Validator $NODE_NUM (PID: $PID)${NC}"
            kill $PID
            sleep 1
            
            # Force kill if still running
            if ps -p $PID > /dev/null 2>&1; then
                echo -e "${RED}   Force killing...${NC}"
                kill -9 $PID
            fi
            
            rm -f "$PID_FILE"
            echo -e "${GREEN}   ✅ Stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  Validator $NODE_NUM not running (stale PID)${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️  Validator $NODE_NUM PID file not found${NC}"
    fi
}

# Stop all validators
stop_validator 1
stop_validator 2
stop_validator 3
stop_validator 4

echo ""
echo -e "${GREEN}✅ All validators stopped${NC}"
echo ""
