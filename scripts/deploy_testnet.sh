#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY TESTNET - Node Deployment Script (Bootstrap)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# This script deploys 3 bootstrap validator nodes for testnet launch (Feb 18)
# Each node runs independently with its own data directory and ports
#
# Usage: ./scripts/deploy_testnet.sh
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "╔═══════════════════════════════════════════════╗"
echo "║   UNAUTHORITY TESTNET - Bootstrap Deployment  ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# Configuration
TESTNET_DIR="$HOME/.los/testnet"
BINARY="./target/release/los-node"

# Build project first
echo "🔨 Building project in release mode..."
cargo build --release

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "❌ Error: los-node binary not found at $BINARY"
    exit 1
fi

echo "✅ Build complete"
echo ""

# Create testnet directory structure
echo "📁 Creating testnet directory structure..."
mkdir -p "$TESTNET_DIR"
mkdir -p "$TESTNET_DIR/node_a"
mkdir -p "$TESTNET_DIR/node_b"
mkdir -p "$TESTNET_DIR/node_c"
mkdir -p "$TESTNET_DIR/logs"

echo "✅ Directories created"
echo ""

# Deploy Node A (Bootstrap Leader)
echo "🚀 Deploying Node A (Bootstrap Leader)..."
cat > "$TESTNET_DIR/node_a/config.toml" <<EOF
[node]
name = "bootstrap-node-a"
data_dir = "$TESTNET_DIR/node_a/data"
log_level = "info"

[network]
listen_addr = "0.0.0.0:4001"
external_addr = "127.0.0.1:4001"
bootstrap_peers = []

[api]
rest_port = 3030
grpc_port = 50051

[validator]
enabled = true
stake_amount = 1000

[consensus]
timeout_ms = 3000
max_block_size = 1048576

[monitoring]
prometheus_port = 9090
EOF

echo "✅ Node A config created"

# Deploy Node B
echo "🚀 Deploying Node B..."
cat > "$TESTNET_DIR/node_b/config.toml" <<EOF
[node]
name = "bootstrap-node-b"
data_dir = "$TESTNET_DIR/node_b/data"
log_level = "info"

[network]
listen_addr = "0.0.0.0:4002"
external_addr = "127.0.0.1:4002"
bootstrap_peers = ["/ip4/127.0.0.1/tcp/4001"]

[api]
rest_port = 3031
grpc_port = 50052

[validator]
enabled = true
stake_amount = 1000

[consensus]
timeout_ms = 3000
max_block_size = 1048576

[monitoring]
prometheus_port = 9091
EOF

echo "✅ Node B config created"

# Deploy Node C
echo "🚀 Deploying Node C..."
cat > "$TESTNET_DIR/node_c/config.toml" <<EOF
[node]
name = "bootstrap-node-c"
data_dir = "$TESTNET_DIR/node_c/data"
log_level = "info"

[network]
listen_addr = "0.0.0.0:4003"
external_addr = "127.0.0.1:4003"
bootstrap_peers = ["/ip4/127.0.0.1/tcp/4001"]

[api]
rest_port = 3032
grpc_port = 50053

[validator]
enabled = true
stake_amount = 1000

[consensus]
timeout_ms = 3000
max_block_size = 1048576

[monitoring]
prometheus_port = 9092
EOF

echo "✅ Node C config created"
echo ""

# Create systemd service files (optional, for production)
echo "📝 Creating start scripts..."

cat > "$TESTNET_DIR/start_node_a.sh" <<EOF
#!/bin/bash
cd "$PWD"
$BINARY --config "$TESTNET_DIR/node_a/config.toml" > "$TESTNET_DIR/logs/node_a.log" 2>&1 &
echo \$! > "$TESTNET_DIR/node_a/pid"
echo "Node A started (PID: \$(cat $TESTNET_DIR/node_a/pid))"
EOF

cat > "$TESTNET_DIR/start_node_b.sh" <<EOF
#!/bin/bash
cd "$PWD"
$BINARY --config "$TESTNET_DIR/node_b/config.toml" > "$TESTNET_DIR/logs/node_b.log" 2>&1 &
echo \$! > "$TESTNET_DIR/node_b/pid"
echo "Node B started (PID: \$(cat $TESTNET_DIR/node_b/pid))"
EOF

cat > "$TESTNET_DIR/start_node_c.sh" <<EOF
#!/bin/bash
cd "$PWD"
$BINARY --config "$TESTNET_DIR/node_c/config.toml" > "$TESTNET_DIR/logs/node_c.log" 2>&1 &
echo \$! > "$TESTNET_DIR/node_c/pid"
echo "Node C started (PID: \$(cat $TESTNET_DIR/node_c/pid))"
EOF

# Make scripts executable
chmod +x "$TESTNET_DIR/start_node_a.sh"
chmod +x "$TESTNET_DIR/start_node_b.sh"
chmod +x "$TESTNET_DIR/start_node_c.sh"

echo "✅ Start scripts created"
echo ""

# Create stop script
cat > "$TESTNET_DIR/stop_all.sh" <<EOF
#!/bin/bash
echo "Stopping all testnet nodes..."
for node in node_a node_b node_c; do
    if [ -f "$TESTNET_DIR/\$node/pid" ]; then
        pid=\$(cat "$TESTNET_DIR/\$node/pid")
        kill \$pid 2>/dev/null && echo "✅ \$node stopped (PID: \$pid)" || echo "⚠️  \$node not running"
        rm "$TESTNET_DIR/\$node/pid"
    fi
done
echo "Done."
EOF

chmod +x "$TESTNET_DIR/stop_all.sh"

echo "✅ Stop script created"
echo ""

# Print summary
echo "╔═══════════════════════════════════════════════╗"
echo "║        TESTNET DEPLOYMENT COMPLETE!           ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "📊 DEPLOYMENT SUMMARY:"
echo "  • Location: $TESTNET_DIR"
echo "  • Nodes: 3 (node_a, node_b, node_c)"
echo ""
echo "🌐 NODE ENDPOINTS:"
echo "  Node A (Leader):"
echo "    REST API:    http://localhost:3030"
echo "    gRPC:        localhost:50051"
echo "    P2P:         localhost:4001"
echo "    Prometheus:  http://localhost:9090/metrics"
echo ""
echo "  Node B:"
echo "    REST API:    http://localhost:3031"
echo "    gRPC:        localhost:50052"
echo "    P2P:         localhost:4002"
echo "    Prometheus:  http://localhost:9091/metrics"
echo ""
echo "  Node C:"
echo "    REST API:    http://localhost:3032"
echo "    gRPC:        localhost:50053"
echo "    P2P:         localhost:4003"
echo "    Prometheus:  http://localhost:9092/metrics"
echo ""
echo "🚀 TO START TESTNET:"
echo "  $TESTNET_DIR/start_node_a.sh"
echo "  $TESTNET_DIR/start_node_b.sh"
echo "  $TESTNET_DIR/start_node_c.sh"
echo ""
echo "🛑 TO STOP TESTNET:"
echo "  $TESTNET_DIR/stop_all.sh"
echo ""
echo "📋 VIEW LOGS:"
echo "  tail -f $TESTNET_DIR/logs/node_a.log"
echo "  tail -f $TESTNET_DIR/logs/node_b.log"
echo "  tail -f $TESTNET_DIR/logs/node_c.log"
echo ""
echo "🔍 TEST CONNECTION:"
echo "  curl http://localhost:3030/node-info"
echo "  cargo run --bin los-cli -- query info --rpc http://localhost:3030"
echo ""
echo "✅ Ready for testnet launch (Feb 18, 2026)!"
