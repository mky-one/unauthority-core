#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$BASE_DIR/target/release/los-node"
BN="/ip4/127.0.0.1/tcp/4030,/ip4/127.0.0.1/tcp/4031,/ip4/127.0.0.1/tcp/4032,/ip4/127.0.0.1/tcp/4033"

echo "Stopping existing validators..."
for i in 1 2 3 4; do
    pkill -f "los-node.*validator-${i}" 2>/dev/null || true
done
sleep 2

echo "Starting 4 validators with new binary..."
for i in 1 2 3 4; do
    PORT=$((3029 + i))
    DIR="$BASE_DIR/node_data/validator-${i}"
    NID="validator-${i}"
    mkdir -p "$DIR"

    # P2P port auto-derived: API port + 1000 (e.g. 3030→4030)
    LOS_NODE_ID="$NID" \
    LOS_TESTNET_LEVEL="consensus" \
    LOS_BOOTSTRAP_NODES="$BN" \
    nohup "$BINARY" --port "$PORT" --data-dir "$DIR" --node-id "$NID" \
        </dev/null >"$DIR/node.log" 2>&1 &

    echo "  V${i}: API=$PORT, P2P=$((PORT+1000)), PID=$!, dir=$DIR"
done

echo ""
echo "Waiting 5s for startup..."
sleep 5

echo ""
echo "=== Health Check ==="
for i in 1 2 3 4; do
    PORT=$((3029 + i))
    STATUS=$(curl -s -m 3 "http://127.0.0.1:${PORT}/health" 2>/dev/null || echo "TIMEOUT")
    if [ -z "$STATUS" ]; then
        STATUS="EMPTY"
    fi
    echo "  V${i} ($PORT): $STATUS"
done

echo ""
echo "=== Process Check ==="
ps aux | grep los-node | grep -v grep | grep -v flutter | awk '{print "  PID " $2 " STAT " $8}' || echo "  No processes found"
echo ""
echo "Done."
