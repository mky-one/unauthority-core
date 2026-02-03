#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY TESTNET - Network Monitoring Script
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# This script monitors the health of all 3 testnet nodes
# Queries REST API endpoints and displays live status
#
# Usage: ./scripts/monitor_testnet.sh [--watch]
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Node endpoints
NODE_A="http://localhost:3030"
NODE_B="http://localhost:3031"
NODE_C="http://localhost:3032"

# Function to query node info
query_node() {
    local name=$1
    local url=$2
    
    # Try to fetch node info
    response=$(curl -s "$url/node-info" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$response" ]; then
        # Parse JSON (requires jq, fallback to grep if not available)
        if command -v jq &> /dev/null; then
            block_height=$(echo "$response" | jq -r '.block_height // "N/A"')
            validator_count=$(echo "$response" | jq -r '.validator_count // "N/A"')
            peer_count=$(echo "$response" | jq -r '.peer_count // "N/A"')
            chain_id=$(echo "$response" | jq -r '.chain_id // "N/A"')
            version=$(echo "$response" | jq -r '.version // "N/A"')
        else
            block_height=$(echo "$response" | grep -o '"block_height":[0-9]*' | cut -d':' -f2)
            validator_count=$(echo "$response" | grep -o '"validator_count":[0-9]*' | cut -d':' -f2)
            peer_count=$(echo "$response" | grep -o '"peer_count":[0-9]*' | cut -d':' -f2)
            chain_id=$(echo "$response" | grep -o '"chain_id":"[^"]*"' | cut -d'"' -f4)
            version=$(echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        fi
        
        echo -e "${GREEN}✅ $name ONLINE${NC}"
        echo "   Chain ID:    $chain_id"
        echo "   Version:     $version"
        echo "   Block:       #$block_height"
        echo "   Validators:  $validator_count"
        echo "   Peers:       $peer_count"
    else
        echo -e "${RED}❌ $name OFFLINE${NC}"
        echo "   URL: $url"
        echo "   Error: Cannot connect"
    fi
    echo ""
}

# Function to check validator status
check_validators() {
    echo -e "${BLUE}━━━ VALIDATOR STATUS ━━━${NC}"
    
    # Query validators from Node A
    validators=$(curl -s "$NODE_A/validators" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$validators" ]; then
        if command -v jq &> /dev/null; then
            echo "$validators" | jq -r '.validators[] | "  • \(.address[0:20])... | Stake: \(.stake) UAT | Active: \(.active)"'
        else
            echo "$validators" | grep -o '"address":"[^"]*"' | cut -d'"' -f4 | head -3
        fi
    else
        echo -e "${RED}  Error: Cannot fetch validator list${NC}"
    fi
    echo ""
}

# Function to check consensus
check_consensus() {
    echo -e "${BLUE}━━━ CONSENSUS HEALTH ━━━${NC}"
    
    # Get block heights from all nodes
    height_a=$(curl -s "$NODE_A/node-info" 2>/dev/null | grep -o '"block_height":[0-9]*' | cut -d':' -f2)
    height_b=$(curl -s "$NODE_B/node-info" 2>/dev/null | grep -o '"block_height":[0-9]*' | cut -d':' -f2)
    height_c=$(curl -s "$NODE_C/node-info" 2>/dev/null | grep -o '"block_height":[0-9]*' | cut -d':' -f2)
    
    # Check if heights are similar (within 5 blocks)
    max_height=$height_a
    [ "$height_b" -gt "$max_height" ] && max_height=$height_b
    [ "$height_c" -gt "$max_height" ] && max_height=$height_c
    
    diff_a=$((max_height - height_a))
    diff_b=$((max_height - height_b))
    diff_c=$((max_height - height_c))
    
    if [ "$diff_a" -le 5 ] && [ "$diff_b" -le 5 ] && [ "$diff_c" -le 5 ]; then
        echo -e "  ${GREEN}✅ Consensus: SYNCED${NC}"
        echo "  Node A: #$height_a"
        echo "  Node B: #$height_b"
        echo "  Node C: #$height_c"
    else
        echo -e "  ${YELLOW}⚠️  Consensus: OUT OF SYNC${NC}"
        echo "  Node A: #$height_a (Δ $diff_a)"
        echo "  Node B: #$height_b (Δ $diff_b)"
        echo "  Node C: #$height_c (Δ $diff_c)"
    fi
    echo ""
}

# Function to check Prometheus metrics
check_metrics() {
    echo -e "${BLUE}━━━ PERFORMANCE METRICS ━━━${NC}"
    
    # Try to fetch Prometheus metrics
    metrics=$(curl -s "http://localhost:9090/metrics" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$metrics" ]; then
        # Extract key metrics
        tps=$(echo "$metrics" | grep "^uat_transactions_per_second" | awk '{print $2}')
        finality=$(echo "$metrics" | grep "^uat_finality_time_ms" | awk '{print $2}')
        mempool=$(echo "$metrics" | grep "^uat_mempool_size" | awk '{print $2}')
        
        echo "  TPS:          ${tps:-N/A}"
        echo "  Finality:     ${finality:-N/A} ms"
        echo "  Mempool:      ${mempool:-N/A} txs"
    else
        echo -e "  ${YELLOW}⚠️  Prometheus metrics not available${NC}"
        echo "  (This is optional, node still functional)"
    fi
    echo ""
}

# Main monitoring function
monitor() {
    clear
    
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   UNAUTHORITY TESTNET - Network Monitor       ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo -e "${BLUE}━━━ NODE STATUS ━━━${NC}"
    query_node "Node A" "$NODE_A"
    query_node "Node B" "$NODE_B"
    query_node "Node C" "$NODE_C"
    
    check_validators
    check_consensus
    check_metrics
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Press Ctrl+C to exit"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  'jq' not found. Install for better output: brew install jq${NC}"
    echo ""
fi

# Run once or in watch mode
if [ "$1" == "--watch" ]; then
    while true; do
        monitor
        sleep 5
    done
else
    monitor
fi
