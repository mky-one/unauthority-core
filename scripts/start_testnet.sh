#!/bin/bash
# Start all 4 testnet validators with Tor environment
set -e

cd "$(dirname "$0")/.."
BINARY="./target/release/los-node"

# Onion addresses
V1_ONION="u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion"
V2_ONION="5yvqf4sdbif4pegxgrgfq5ksv3gqqpt27x2xzx5nvrmdqmsrk4mnkgad.onion"
V3_ONION="3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion"
V4_ONION="yapub6hgjr3eyxnxzvgd4yejt7rkhwlmaivdpy6757o3tr5iicckgjyd.onion"

# Bootstrap nodes list — use localhost P2P ports for libp2p inter-node mesh.
# Tor is used for external API access (.onion), but libp2p needs direct TCP.
# Each node's bootstrap list EXCLUDES itself and includes the others.
BOOT_ALL="127.0.0.1:4001,127.0.0.1:4002,127.0.0.1:4003,127.0.0.1:4004"

start_validator() {
  local id=$1 port=$2 onion=$3 p2p_port=$4
  local data_dir="node_data/validator-${id}"

  echo "Starting validator-${id} on port ${port}..."

  LOS_NODE_ID="validator-${id}" \
  LOS_TOR_SOCKS5="127.0.0.1:9052" \
  LOS_ONION_ADDRESS="${onion}" \
  LOS_P2P_PORT="${p2p_port}" \
  LOS_BOOTSTRAP_NODES="${BOOT_ALL}" \
  LOS_TESTNET_LEVEL="consensus" \
  nohup "${BINARY}" --port "${port}" --data-dir "${data_dir}" \
    > "${data_dir}/node.log" 2>&1 &

  echo "  PID: $! → ${data_dir}/node.log"
}

# Start all 4
start_validator 1 3030 "$V1_ONION" 4001
start_validator 2 3031 "$V2_ONION" 4002
start_validator 3 3032 "$V3_ONION" 4003
start_validator 4 3033 "$V4_ONION" 4004

echo ""
echo "All 4 validators starting. Waiting 3s for boot..."
sleep 3

# Quick health check
for port in 3030 3031 3032 3033; do
  resp=$(curl -s -m 2 http://localhost:${port}/health 2>/dev/null || echo "FAIL")
  echo "  Port ${port}: ${resp}"
done

echo ""
echo "Done."
