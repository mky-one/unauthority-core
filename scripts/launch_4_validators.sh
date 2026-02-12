#!/bin/bash

# =============================================================================
# LAUNCH 4 LOS VALIDATORS (GRADUATED TESTNET SUPPORT)
# Supports graduated testnet levels: functional, consensus, production
# =============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Detect testnet level
TESTNET_LEVEL=${LOS_TESTNET_LEVEL:-functional}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   LAUNCHING 4 LOS VALIDATORS (LEVEL: $TESTNET_LEVEL)      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

case $TESTNET_LEVEL in
    functional)
        echo "🧪 FUNCTIONAL LEVEL: UI/API testing (immediate finalization)"
        ;;
    consensus)
        echo "⚡ CONSENSUS LEVEL: Real aBFT + oracle consensus (production blockchain logic)"
        ;;
    production)
        echo "🚀 PRODUCTION LEVEL: Full mainnet simulation (validator economics enabled)"
        ;;
    *)
        echo "⚠️  Unknown testnet level: $TESTNET_LEVEL"
        echo "   Valid levels: functional, consensus, production"
        echo "   Using functional as default..."
        TESTNET_LEVEL="functional"
        ;;
esac

echo ""

# Export testnet level for all validator processes
export LOS_TESTNET_LEVEL=$TESTNET_LEVEL

# Kill existing nodes
echo "🔄 Stopping existing nodes..."
pkill -f "los-node" 2>/dev/null || true
sleep 2

# Clean old data
echo "🧹 Cleaning old data..."
rm -rf node_data/validator-*
rm -rf los_database/
mkdir -p node_data logs

# Check if built
if [ ! -f "./target/release/los-node" ]; then
    echo "⚠️  los-node not found. Building..."
    cargo build --release
fi

# Generate testnet wallets if needed
if [ ! -f "testnet-genesis/testnet_wallets.json" ]; then
    echo "📝 Generating testnet wallets..."
    ./scripts/generate_testnet_wallets.sh
fi

echo ""
echo "🚀 Starting 4 validators..."
echo ""

# Validator 1 (Port 3030, gRPC 23030)
echo "  ├─ Validator 1: http://localhost:3030 (gRPC: 23030)"
./target/release/los-node \
    --port 23030 \
    --api-port 3030 \
    --db node_data/validator-1 \
    --genesis testnet-genesis/testnet_wallets.json \
    > logs/validator-1.log 2>&1 &

sleep 1

# Validator 2 (Port 3031, gRPC 23031)
echo "  ├─ Validator 2: http://localhost:3031 (gRPC: 23031)"
./target/release/los-node \
    --port 23031 \
    --api-port 3031 \
    --db node_data/validator-2 \
    --genesis testnet-genesis/testnet_wallets.json \
    --peer "127.0.0.1:23030" \
    > logs/validator-2.log 2>&1 &

sleep 1

# Validator 3 (Port 3032, gRPC 23032)
echo "  ├─ Validator 3: http://localhost:3032 (gRPC: 23032)"
./target/release/los-node \
    --port 23032 \
    --api-port 3032 \
    --db node_data/validator-3 \
    --genesis testnet-genesis/testnet_wallets.json \
    --peer "127.0.0.1:23030" \
    --peer "127.0.0.1:23031" \
    > logs/validator-3.log 2>&1 &

sleep 1

# Validator 4 (Port 3033, gRPC 23033)
echo "  └─ Validator 4: http://localhost:3033 (gRPC: 23033)"
./target/release/los-node \
    --port 23033 \
    --api-port 3033 \
    --db node_data/validator-4 \
    --genesis testnet-genesis/testnet_wallets.json \
    --peer "127.0.0.1:23030" \
    --peer "127.0.0.1:23031" \
    --peer "127.0.0.1:23032" \
    > logs/validator-4.log 2>&1 &

echo ""
echo "⏳ Waiting for nodes to initialize (5 seconds)..."
sleep 5

echo ""
echo "🔍 Health Check:"
echo ""

for PORT in 3030 3031 3032 3033; do
    echo -n "  Validator (port $PORT): "
    if curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo "✅ Healthy"
    else
        echo "❌ Not responding"
    fi
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   4 VALIDATORS RUNNING                                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 API Endpoints:"
echo "   http://localhost:3030 (Validator 1)"
echo "   http://localhost:3031 (Validator 2)"
echo "   http://localhost:3032 (Validator 3)"
echo "   http://localhost:3033 (Validator 4)"
echo ""
echo "🔗 gRPC Ports (Consensus):"
echo "   127.0.0.1:23030 (Validator 1)"
echo "   127.0.0.1:23031 (Validator 2)"
echo "   127.0.0.1:23032 (Validator 3)"
echo "   127.0.0.1:23033 (Validator 4)"
echo ""
echo "📋 View Logs:"
echo "   tail -f logs/validator-1.log"
echo "   tail -f logs/validator-2.log"
echo "   tail -f logs/validator-3.log"
echo "   tail -f logs/validator-4.log"
echo ""
echo "🛑 Stop All Validators:"
echo "   pkill -f los-node"
echo ""
