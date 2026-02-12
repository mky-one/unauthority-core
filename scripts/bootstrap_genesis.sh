#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Unauthority (LOS) - Genesis Bootstrap Script
# Integration test showing how to use generated genesis wallets in node startup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_DIR="${PROJECT_ROOT}/genesis"
NODE_DATA_DIR="${PROJECT_ROOT}/node_data"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  UNAUTHORITY (LOS) - GENESIS BOOTSTRAP INTEGRATION TEST    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: Generate Genesis Wallets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 1: Generating Genesis Wallets..."
if [ ! -f "${GENESIS_DIR}/genesis_config.json" ]; then
    echo "   ⚠️  Genesis config not found. Generating..."
    cargo run -p genesis --quiet 2>/dev/null | head -n 30
else
    echo "   ✓ Genesis config already exists"
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: Parse Genesis Config
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 2: Parsing Genesis Configuration..."

# Extract bootstrap node 1 address
BOOTSTRAP_1=$(jq -r '.bootstrap_nodes[0].address' "${GENESIS_DIR}/genesis_config.json")
BOOTSTRAP_2=$(jq -r '.bootstrap_nodes[1].address' "${GENESIS_DIR}/genesis_config.json")
BOOTSTRAP_3=$(jq -r '.bootstrap_nodes[2].address' "${GENESIS_DIR}/genesis_config.json")

# Extract treasury addresses
TREASURY_1=$(jq -r '.treasury_wallets[0].address' "${GENESIS_DIR}/genesis_config.json")

echo "   ✓ Bootstrap Node 1: ${BOOTSTRAP_1:0:20}..."
echo "   ✓ Bootstrap Node 2: ${BOOTSTRAP_2:0:20}..."
echo "   ✓ Bootstrap Node 3: ${BOOTSTRAP_3:0:20}..."
echo "   ✓ Treasury 1: ${TREASURY_1:0:20}..."
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: Verify Supply
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 3: Verifying Supply..."

DEV_SUPPLY=$(jq -r '.constants.dev_supply_cil' "${GENESIS_DIR}/genesis_config.json")
PUBLIC_SUPPLY=$(jq -r '.constants.public_supply_cil' "${GENESIS_DIR}/genesis_config.json")
TOTAL_SUPPLY=$(jq -r '.constants.total_supply_cil' "${GENESIS_DIR}/genesis_config.json")

echo "   • Dev Supply:    ${DEV_SUPPLY} VOI"
echo "   • Public Supply: ${PUBLIC_SUPPLY} VOI"
echo "   • Total Supply:  ${TOTAL_SUPPLY} VOI"

# Verify sum
CALCULATED_TOTAL=$((DEV_SUPPLY + PUBLIC_SUPPLY))
if [ "$CALCULATED_TOTAL" -eq "$TOTAL_SUPPLY" ]; then
    echo "   ✓ Supply verification: PASSED (Zero Remainder Protocol)"
else
    echo "   ✗ Supply verification: FAILED"
    exit 1
fi
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: Setup Node Directories
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 4: Setting up Node Directories..."

mkdir -p "${NODE_DATA_DIR}/validator-1/"{blockchain,logs}
mkdir -p "${NODE_DATA_DIR}/validator-2/"{blockchain,logs}
mkdir -p "${NODE_DATA_DIR}/validator-3/"{blockchain,logs}
mkdir -p "${NODE_DATA_DIR}/treasury-1/"{blockchain,logs}

echo "   ✓ Created node directories"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: Create Bootstrap Node Configurations
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 5: Creating Bootstrap Node Configurations..."

# Extract validator addresses from genesis config
VALIDATOR_ADDR_1=$(jq -r '.bootstrap_nodes[0].address' "${GENESIS_DIR}/genesis_config.json")
VALIDATOR_ADDR_2=$(jq -r '.bootstrap_nodes[1].address' "${GENESIS_DIR}/genesis_config.json")
VALIDATOR_ADDR_3=$(jq -r '.bootstrap_nodes[2].address' "${GENESIS_DIR}/genesis_config.json")

VALIDATOR_ADDRS=("$VALIDATOR_ADDR_1" "$VALIDATOR_ADDR_2" "$VALIDATOR_ADDR_3")
SENTRY_PORTS=(30333 30334 30335)     # Public sentry ports
SIGNER_PORTS=(30331 30332 30333)     # Private signer ports

for i in 1 2 3; do
    CONFIG_FILE="${NODE_DATA_DIR}/validator-${i}/validator.toml"
    ENV_FILE="${NODE_DATA_DIR}/validator-${i}/.env"
    VALIDATOR_ADDR="${VALIDATOR_ADDRS[$((i-1))]}"
    SENTRY_PORT="${SENTRY_PORTS[$((i-1))]}"
    SIGNER_PORT="${SIGNER_PORTS[$((i-1))]}"
    
    # Copy template and customize
    cp "${PROJECT_ROOT}/validator.toml" "${CONFIG_FILE}"
    
    # Customize for this node with UNIQUE ADDRESS, PORTS, and NODE_ID
    sed -i "" "s|node_id = \"validator-1\"|node_id = \"validator-${i}\"|g" "${CONFIG_FILE}"
    sed -i "" "s|listen_port = \${LOS_SENTRY_PORT:-30333}|listen_port = ${SENTRY_PORT}|g" "${CONFIG_FILE}"
    sed -i "" "s|external_port = \${LOS_SENTRY_PORT:-30333}|external_port = ${SENTRY_PORT}|g" "${CONFIG_FILE}"
    sed -i "" "s|listen_port = \${LOS_SIGNER_PORT:-30331}|listen_port = ${SIGNER_PORT}|g" "${CONFIG_FILE}"
    sed -i "" "s|signer_endpoint = \"127.0.0.1:\${LOS_SIGNER_PORT:-30331}\"|signer_endpoint = \"127.0.0.1:${SIGNER_PORT}\"|g" "${CONFIG_FILE}"
    sed -i "" "s|./node_data/validator-1|./node_data/validator-${i}|g" "${CONFIG_FILE}"
    
    # Create environment file for this validator
    cat > "${ENV_FILE}" << EOF
# Auto-generated environment variables for validator-${i}
export LOS_VALIDATOR_ADDRESS="${VALIDATOR_ADDR}"
export LOS_SENTRY_PORT="${SENTRY_PORT}"
export LOS_SIGNER_PORT="${SIGNER_PORT}"
export LOS_VALIDATOR_PRIVKEY_PATH="/path/to/bootstrap-node-${i}.key"
export LOS_NODE_ID="validator-${i}"
export LOS_STAKE_CIL=100000000000
EOF
    chmod 600 "${ENV_FILE}"
    
    echo "   ✓ Created ${CONFIG_FILE}"
    echo "     • Node ID: validator-${i}"
    echo "     • Address: ${VALIDATOR_ADDR:0:30}..."
    echo "     • Sentry Port: ${SENTRY_PORT}"
    echo "     • Signer Port: ${SIGNER_PORT}"
    echo "     • Env File: ${ENV_FILE}"
    echo ""
done
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: Copy Genesis Config to Node Directories
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 6: Copying Genesis Config to Node Directories..."

for i in 1 2 3; do
    cp "${GENESIS_DIR}/genesis_config.json" "${NODE_DATA_DIR}/validator-${i}/"
    echo "   ✓ Copied genesis_config.json to validator-${i}"
done
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 7: Display Bootstrap Instructions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📌 Step 7: Bootstrap Instructions"
echo ""
echo "🚀 TO START VALIDATOR NODES:"
echo ""
echo "   Terminal 1 (Validator Node 1):"
echo "   $ cd ${PROJECT_ROOT}"
echo "   $ source node_data/validator-1/.env"
echo "   $ export LOS_VALIDATOR_PRIVKEY_PATH='/path/to/bootstrap-node-1.key'"
echo "   $ cargo run -p los-node -- --config node_data/validator-1/validator.toml"
echo ""
echo "   Terminal 2 (Validator Node 2):"
echo "   $ source node_data/validator-2/.env"
echo "   $ export LOS_VALIDATOR_PRIVKEY_PATH='/path/to/bootstrap-node-2.key'"
echo "   $ cargo run -p los-node -- --config node_data/validator-2/validator.toml"
echo ""
echo "   Terminal 3 (Validator Node 3):"
echo "   $ source node_data/validator-3/.env"
echo "   $ export LOS_VALIDATOR_PRIVKEY_PATH='/path/to/bootstrap-node-3.key'"
echo "   $ cargo run -p los-node -- --config node_data/validator-3/validator.toml"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 8: Display Genesis State Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ✓ GENESIS BOOTSTRAP PREPARATION COMPLETE                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 GENESIS STATE SUMMARY:"
echo "   • Total Supply: 21,936,236 LOS"
echo "   • Dev Allocation: 1,535,536 LOS (8 wallets)"
echo "   • Bootstrap Nodes: 3 (Initial Validators)"
echo "   • Treasury Wallets: 5 (Long-term Storage)"
echo "   • Consensus: aBFT (<3 sec finality)"
echo "   • Network ID: 1"
echo ""
echo "📁 NODE DIRECTORIES:"
echo "   • ${NODE_DATA_DIR}/validator-1"
echo "   • ${NODE_DATA_DIR}/validator-2"
echo "   • ${NODE_DATA_DIR}/validator-3"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "   1. Store private keys in COLD STORAGE (offline)"
echo "   2. Use environment variables: LOS_VALIDATOR_PRIVKEY_PATH"
echo "   3. Never commit private keys to Git"
echo "   4. Use Sentry Node architecture for production"
echo "   5. Enable firewall rules before going live"
echo ""
echo "🔗 DOCUMENTATION:"
echo "   • Genesis Guide: ${GENESIS_DIR}/README.md"
echo "   • Task Completion: ${PROJECT_ROOT}/TASK_1_GENESIS_COMPLETION.md"
echo "   • Validator Config: ${PROJECT_ROOT}/validator.toml"
echo ""
