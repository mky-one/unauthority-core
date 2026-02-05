#!/bin/bash
# Start 4-Validator Testnet with Genesis Wallets
# Byzantine Fault Tolerance: 3f + 1 = 4 nodes (f=1)

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_WALLETS="$PROJECT_ROOT/testnet-genesis/testnet_wallets.json"
NODE_BINARY="$PROJECT_ROOT/target/release/uat-node"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          UAT TESTNET - 4 Validators (BFT Ready)               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if node binary exists
if [ ! -f "$NODE_BINARY" ]; then
    echo -e "${RED}❌ Node binary not found!${NC}"
    echo -e "${YELLOW}Building uat-node...${NC}"
    cd "$PROJECT_ROOT"
    cargo build --release -p uat-node
    echo -e "${GREEN}✅ Build complete${NC}"
fi

# Check if genesis wallets exist
if [ ! -f "$GENESIS_WALLETS" ]; then
    echo -e "${RED}❌ Genesis wallets not found!${NC}"
    echo -e "${YELLOW}Run: ./scripts/generate_testnet_wallets.sh${NC}"
    exit 1
fi

# Extract validator private keys from genesis JSON
echo -e "${YELLOW}📋 Loading validator keys from genesis...${NC}"

KEY_A=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_A") | .private_key' "$GENESIS_WALLETS")
KEY_B=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_B") | .private_key' "$GENESIS_WALLETS")
KEY_C=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_C") | .private_key' "$GENESIS_WALLETS")
KEY_D=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_D") | .private_key' "$GENESIS_WALLETS")

ADDR_A=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_A") | .address' "$GENESIS_WALLETS")
ADDR_B=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_B") | .address' "$GENESIS_WALLETS")
ADDR_C=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_C") | .address' "$GENESIS_WALLETS")
ADDR_D=$(jq -r '.wallets[] | select(.label == "TESTNET_VALIDATOR_NODE_D") | .address' "$GENESIS_WALLETS")

echo -e "${GREEN}✅ Loaded 4 validator keys${NC}"
echo ""

# Create node data directories
mkdir -p "$PROJECT_ROOT/node_data/validator-1"
mkdir -p "$PROJECT_ROOT/node_data/validator-2"
mkdir -p "$PROJECT_ROOT/node_data/validator-3"
mkdir -p "$PROJECT_ROOT/node_data/validator-4"

# Function to start validator
start_validator() {
    local NODE_NUM=$1
    local PORT=$2
    local KEY=$3
    local ADDR=$4
    local LABEL=$5
    local DATA_DIR="$PROJECT_ROOT/node_data/validator-$NODE_NUM"
    
    echo -e "${BLUE}🚀 Starting Validator $NODE_NUM ($LABEL)${NC}"
    echo -e "   Port: ${GREEN}$PORT${NC}"
    echo -e "   Address: ${YELLOW}$ADDR${NC}"
    
    # Start node in background
    cd "$PROJECT_ROOT"
    "$NODE_BINARY" \
        --validator \
        --private-key "$KEY" \
        --port "$PORT" \
        --data-dir "$DATA_DIR" \
        > "$DATA_DIR/node.log" 2>&1 &
    
    local PID=$!
    echo $PID > "$DATA_DIR/node.pid"
    echo -e "   PID: ${GREEN}$PID${NC}"
    echo ""
    
    # Wait a bit for node to initialize
    sleep 2
}

echo -e "${YELLOW}Starting 4 Validators (Byzantine Fault Tolerance)...${NC}"
echo ""

# Start all 4 validators
start_validator 1 3030 "$KEY_A" "$ADDR_A" "NODE_A"
start_validator 2 3031 "$KEY_B" "$ADDR_B" "NODE_B"
start_validator 3 3032 "$KEY_C" "$ADDR_C" "NODE_C"
start_validator 4 3033 "$KEY_D" "$ADDR_D" "NODE_D"

echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 4-Validator Testnet Started Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📊 Validator Endpoints:${NC}"
echo -e "   Validator 1 (NODE_A): ${GREEN}http://localhost:3030${NC}"
echo -e "   Validator 2 (NODE_B): ${GREEN}http://localhost:3031${NC}"
echo -e "   Validator 3 (NODE_C): ${GREEN}http://localhost:3032${NC}"
echo -e "   Validator 4 (NODE_D): ${GREEN}http://localhost:3033${NC}"
echo ""
echo -e "${BLUE}🛡️  Byzantine Fault Tolerance:${NC}"
echo -e "   Formula: 3f + 1 (f = max faulty nodes)"
echo -e "   Current: 4 nodes can tolerate ${GREEN}1 Byzantine node${NC}"
echo -e "   Network survives if ${GREEN}≥3 nodes${NC} are honest"
echo ""
echo -e "${BLUE}📝 Logs:${NC}"
echo -e "   tail -f $PROJECT_ROOT/node_data/validator-1/node.log"
echo -e "   tail -f $PROJECT_ROOT/node_data/validator-2/node.log"
echo -e "   tail -f $PROJECT_ROOT/node_data/validator-3/node.log"
echo -e "   tail -f $PROJECT_ROOT/node_data/validator-4/node.log"
echo ""
echo -e "${BLUE}🖥️  Validator Dashboard:${NC}"
echo -e "   Connect to: ${GREEN}http://localhost:3030${NC}"
echo -e "   Import seed: ${YELLOW}node node node node node node node node node node node alpha${NC}"
echo ""
echo -e "${BLUE}⏹️  To stop:${NC}"
echo -e "   ./scripts/stop_testnet.sh"
echo ""
