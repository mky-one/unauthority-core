#!/bin/bash
cd "$(dirname "$0")"

echo "=== Killing existing nodes ==="
pkill -9 -f "uat-node" 2>/dev/null
sleep 2

echo "=== Starting 4 bootstrap validators ==="
mkdir -p node_data/validator-{1,2,3,4}/logs

UAT_NODE_ID=validator-1 \
UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004" \
nohup ./target/release/uat-node 3030 > node_data/validator-1/logs/node.log 2>&1 &
echo "V1 PID=$!"
sleep 2

UAT_NODE_ID=validator-2 \
UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004" \
nohup ./target/release/uat-node 3031 > node_data/validator-2/logs/node.log 2>&1 &
echo "V2 PID=$!"
sleep 2

UAT_NODE_ID=validator-3 \
UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4004" \
nohup ./target/release/uat-node 3032 > node_data/validator-3/logs/node.log 2>&1 &
echo "V3 PID=$!"
sleep 1

UAT_NODE_ID=validator-4 \
UAT_BOOTSTRAP_NODES="/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003" \
nohup ./target/release/uat-node 3033 > node_data/validator-4/logs/node.log 2>&1 &
echo "V4 PID=$!"

echo "Waiting 8s for startup..."
sleep 8

echo ""
echo "=== HEALTH CHECK ==="
for p in 3030 3031 3032 3033; do
  result=$(curl -sf --max-time 3 "http://localhost:$p/health" 2>&1)
  if [ $? -eq 0 ]; then
    echo "  Port $p: ONLINE - $result"
  else
    echo "  Port $p: OFFLINE"
  fi
done

echo ""
echo "=== PROCESS CHECK ==="
pgrep -af "uat-node" || echo "No uat-node processes found!"
