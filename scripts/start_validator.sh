#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Unauthority (UAT) - Validator Startup Script
# Automatically loads environment-specific configuration for each validator
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <validator-number> [private_key_path]"
    echo ""
    echo "Examples:"
    echo "  $0 1"
    echo "  $0 2 /path/to/bootstrap-node-2.key"
    echo "  $0 3 ~/keys/validator-3.key"
    echo ""
    exit 1
fi

VALIDATOR_NUM="$1"
PRIVKEY_PATH="${2:-/path/to/bootstrap-node-${VALIDATOR_NUM}.key}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR_DIR="${PROJECT_ROOT}/node_data/validator-${VALIDATOR_NUM}"
ENV_FILE="${VALIDATOR_DIR}/.env"
CONFIG_FILE="${VALIDATOR_DIR}/validator.toml"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  UNAUTHORITY (UAT) - VALIDATOR STARTUP                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Validate validator number
if [ "$VALIDATOR_NUM" != "1" ] && [ "$VALIDATOR_NUM" != "2" ] && [ "$VALIDATOR_NUM" != "3" ]; then
    echo "❌ Error: Validator number must be 1, 2, or 3"
    exit 1
fi

# Check if validator directory exists
if [ ! -d "$VALIDATOR_DIR" ]; then
    echo "❌ Error: Validator directory not found: $VALIDATOR_DIR"
    echo ""
    echo "Please run bootstrap first:"
    echo "  $ bash scripts/bootstrap_genesis.sh"
    exit 1
fi

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: Environment file not found: $ENV_FILE"
    exit 1
fi

# Load environment variables
echo "📌 Loading configuration from: $ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"

# Display loaded configuration
echo ""
echo "🔧 Configuration:"
echo "   • Validator ID: $UAT_NODE_ID"
echo "   • Address: ${UAT_VALIDATOR_ADDRESS:0:30}..."
echo "   • Sentry Port: $UAT_SENTRY_PORT"
echo "   • Signer Port: $UAT_SIGNER_PORT"
echo "   • Stake: $UAT_STAKE_VOID VOI"
echo ""

# Check if private key exists
if [ ! -f "$PRIVKEY_PATH" ]; then
    echo "⚠️  Warning: Private key not found at: $PRIVKEY_PATH"
    echo ""
    echo "   You can:"
    echo "   1. Provide the actual private key path as second argument:"
    echo "      $ $0 $VALIDATOR_NUM /path/to/your/key.key"
    echo ""
    echo "   2. Or set it via environment before running:"
    echo "      $ export UAT_VALIDATOR_PRIVKEY_PATH=/path/to/key.key"
    echo "      $ $0 $VALIDATOR_NUM"
    echo ""
    echo "   3. For testing, you can generate a test key:"
    echo "      $ mkdir -p /tmp/uat-keys"
    echo "      $ openssl rand -hex 32 > /tmp/uat-keys/validator-${VALIDATOR_NUM}.key"
    echo "      $ $0 $VALIDATOR_NUM /tmp/uat-keys/validator-${VALIDATOR_NUM}.key"
    echo ""
    read -p "Continue without private key? (for testing only) [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✓ Private key found: ${PRIVKEY_PATH:0:50}..."
    export UAT_VALIDATOR_PRIVKEY_PATH="$PRIVKEY_PATH"
fi

echo ""
echo "📂 Config file: $CONFIG_FILE"
echo ""

# Final confirmation
echo "🚀 Starting validator-${VALIDATOR_NUM}..."
echo ""
echo "   Project Root: $PROJECT_ROOT"
echo "   Data Dir: $VALIDATOR_DIR"
echo ""

# Execute validator
cd "$PROJECT_ROOT"
cargo run -p uat-node -- --config "$CONFIG_FILE"
