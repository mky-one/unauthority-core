#!/bin/bash
set -e

cd "$(dirname "$0")"
BIN=./target/release/uat-node

echo "Killing existing nodes..."
pkill -f uat-node 2>/dev/null || true
sleep 2

echo "Starting V1..."
UAT_BIND_ALL=1 UAT_P2P_PORT=4001 \
  UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004" \
  RUST_BACKTRACE=1 \
  $BIN --port 3030 --data-dir node_data/v1 --dev </dev/null > /tmp/uat-v1.log 2>&1 &
echo "  PID: $!"

sleep 2

echo "Starting V2..."
UAT_BIND_ALL=1 UAT_P2P_PORT=4002 \
  UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004" \
  RUST_BACKTRACE=1 \
  $BIN --port 3031 --data-dir node_data/v2 --dev </dev/null > /tmp/uat-v2.log 2>&1 &
echo "  PID: $!"

sleep 2

echo "Starting V3..."
UAT_BIND_ALL=1 UAT_P2P_PORT=4003 \
  UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4004" \
  RUST_BACKTRACE=1 \
  $BIN --port 3032 --data-dir node_data/v3 --dev </dev/null > /tmp/uat-v3.log 2>&1 &
echo "  PID: $!"

sleep 2

echo "Starting V4..."
UAT_BIND_ALL=1 UAT_P2P_PORT=4004 \
  UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003" \
  RUST_BACKTRACE=1 \
  $BIN --port 3033 --data-dir node_data/v4 --dev </dev/null > /tmp/uat-v4.log 2>&1 &
echo "  PID: $!"

sleep 3

echo ""
echo "=== Checking peer status ==="
for i in 1 2 3 4; do
  PORT=$((3029 + i))
  PEERS=$(curl -s http://127.0.0.1:$PORT/api/v1/status 2>/dev/null | grep -o '"connected_peers":[0-9]*' | grep -o '[0-9]*$' || echo "DOWN")
  echo "V$i (port $PORT): peers=$PEERS"
done

echo ""
echo "=== P2P listening check ==="
for i in 1 2 3 4; do
  P2P=$(grep "P2P listening on port" /tmp/uat-v$i.log 2>/dev/null || echo "NOT FOUND")
  echo "V$i: $P2P"
done
