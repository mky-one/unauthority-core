#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      UNAUTHORITY 3-VALIDATOR TESTNET LAUNCHER             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Create directories
mkdir -p node_data/validator-{1,2,3}/logs

# Ensure binary is built
if [ ! -f "target/release/uat-node" ]; then
    echo "📦 Building release binary..."
    cargo build --release -p uat-node
    echo ""
fi

# Node 1
echo "▶️  Starting Validator-1 (REST:3030, gRPC:23030)..."
export UAT_NODE_ID="validator-1"
nohup ./target/release/uat-node 3030 > node_data/validator-1/logs/node.log 2>&1 &
echo $! > node_data/validator-1/pid.txt
echo "   ✓ PID: $(cat node_data/validator-1/pid.txt)"
sleep 2

# Node 2
echo "▶️  Starting Validator-2 (REST:3031, gRPC:23031)..."
export UAT_NODE_ID="validator-2"
nohup ./target/release/uat-node 3031 > node_data/validator-2/logs/node.log 2>&1 &
echo $! > node_data/validator-2/pid.txt
echo "   ✓ PID: $(cat node_data/validator-2/pid.txt)"
sleep 2

# Node 3
echo "▶️  Starting Validator-3 (REST:3032, gRPC:23032)..."
export UAT_NODE_ID="validator-3"
nohup ./target/release/uat-node 3032 > node_data/validator-3/logs/node.log 2>&1 &
echo $! > node_data/validator-3/pid.txt
echo "   ✓ PID: $(cat node_data/validator-3/pid.txt)"

echo ""
echo "⏳ Waiting 5 seconds for node initialization..."
sleep 5

echo ""
echo "✅ All validators started!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 QUICK HEALTH CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check each node
for port in 3030 3031 3032; do
    if curl -sf http://localhost:$port/node-info > /dev/null 2>&1; then
        echo "✅ Node on port $port: ONLINE"
        ADDR=$(curl -s http://localhost:$port/whoami | jq -r '.short' 2>/dev/null || echo "unknown")
        echo "   Address: $ADDR"
    else
        echo "❌ Node on port $port: OFFLINE"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 MONITORING COMMANDS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Logs:       tail -f node_data/validator-1/logs/node.log"
echo "   Validators: curl http://localhost:3030/validators | jq"
echo "   Supply:     curl http://localhost:3030/supply | jq"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛑 STOP ALL NODES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   ./stop_3_validators.sh"
echo ""
