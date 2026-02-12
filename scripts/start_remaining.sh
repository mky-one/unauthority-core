#!/bin/bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core

V2_ONION=$(cat ~/.los-testnet-tor/hs-validator-2/hostname)
V3_ONION=$(cat ~/.los-testnet-tor/hs-validator-3/hostname)
V4_ONION=$(cat ~/.los-testnet-tor/hs-validator-4/hostname)

NODE=./target/release/los-node

# Start V2
LOS_NODE_ID=validator-2 \
LOS_TOR_SOCKS5=127.0.0.1:9052 \
LOS_ONION_ADDRESS=$V2_ONION \
LOS_P2P_PORT=4002 \
LOS_BOOTSTRAP_NODES=/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4003,/ip4/127.0.0.1/tcp/4004 \
LOS_TESTNET_LEVEL=consensus \
RUST_BACKTRACE=1 \
nohup $NODE --port 3031 --data-dir node_data/validator-2 > node_data/validator-2/logs/node.log 2>&1 &
echo "V2 PID=$!"
sleep 2

# Start V3
LOS_NODE_ID=validator-3 \
LOS_TOR_SOCKS5=127.0.0.1:9052 \
LOS_ONION_ADDRESS=$V3_ONION \
LOS_P2P_PORT=4003 \
LOS_BOOTSTRAP_NODES=/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4004 \
LOS_TESTNET_LEVEL=consensus \
RUST_BACKTRACE=1 \
nohup $NODE --port 3032 --data-dir node_data/validator-3 > node_data/validator-3/logs/node.log 2>&1 &
echo "V3 PID=$!"
sleep 2

# Start V4
LOS_NODE_ID=validator-4 \
LOS_TOR_SOCKS5=127.0.0.1:9052 \
LOS_ONION_ADDRESS=$V4_ONION \
LOS_P2P_PORT=4004 \
LOS_BOOTSTRAP_NODES=/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002,/ip4/127.0.0.1/tcp/4003 \
LOS_TESTNET_LEVEL=consensus \
RUST_BACKTRACE=1 \
nohup $NODE --port 3033 --data-dir node_data/validator-4 > node_data/validator-4/logs/node.log 2>&1 &
echo "V4 PID=$!"

echo "Waiting 8s..."
sleep 8

echo "=== HEALTH CHECK ==="
for p in 3030 3031 3032 3033; do
    N=$((p - 3029))
    if curl -sf -m 3 "http://localhost:$p/health" > /dev/null 2>&1; then
        ADDR=$(curl -s -m 3 "http://localhost:$p/whoami" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('address','?'))" 2>/dev/null)
        echo "  V$N (:$p) ONLINE - $ADDR"
    else
        echo "  V$N (:$p) OFFLINE"
    fi
done
