#!/usr/bin/env bash
# start.sh — Start a 4-validator local testnet for Unauthority (LOS)
# Usage: ./start.sh [testnet_level]
#   testnet_level: functional | consensus (default) | production

set -euo pipefail

LEVEL="${1:-consensus}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$BASE_DIR/target/release/los-node"

if [[ ! -f "$BINARY" ]]; then
    echo "❌ Binary not found. Build first: cargo build --release"
    exit 1
fi

echo "🚀 Starting 4-validator local testnet (level: $LEVEL)"
echo "──────────────────────────────────────────────────"

# Bootstrap node addresses (comma-separated host:port for libp2p)
BOOTSTRAP="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004"

for i in 1 2 3 4; do
    PORT=$((3029 + i))
    NODE_DIR="node_data/v${i}"
    NODE_ID="validator-${i}"
    PID_FILE="$NODE_DIR/pid.txt"

    # Check if already running
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⏭️  Validator $i already running (PID $(cat "$PID_FILE"))"
        continue
    fi

    mkdir -p "$NODE_DIR"

    LOS_NODE_ID="$NODE_ID" \
    LOS_TESTNET_LEVEL="$LEVEL" \
    LOS_BOOTSTRAP_NODES="$BOOTSTRAP" \
    nohup "$BINARY" --port "$PORT" --data-dir "$NODE_DIR" --node-id "$NODE_ID" \
        > "$NODE_DIR/node.log" 2>&1 &

    echo $! > "$PID_FILE"
    echo "✅ Validator $i started — port $PORT, PID $!, data: $NODE_DIR"
done

echo "──────────────────────────────────────────────────"
echo "📊 API endpoints:"
echo "   V1: http://localhost:3030"
echo "   V2: http://localhost:3031"
echo "   V3: http://localhost:3032"
echo "   V4: http://localhost:3033"
echo ""
echo "🛑 Stop with: ./stop.sh"
