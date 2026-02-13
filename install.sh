#!/usr/bin/env bash
# install.sh — Build Unauthority (LOS) from source
# Usage: ./install.sh [--mainnet]

set -euo pipefail

echo "🔧 Unauthority (LOS) — Build from Source"
echo "──────────────────────────────────────────"

# Check Rust
if ! command -v cargo &>/dev/null; then
    echo "❌ Rust not found. Install from https://rustup.rs"
    exit 1
fi

echo "✅ Rust: $(rustc --version)"

if [[ "${1:-}" == "--mainnet" ]]; then
    echo "🏗️  Building MAINNET binary..."
    cargo build --release -p los-node -p los-cli --features los-core/mainnet
    echo ""
    echo "✅ Mainnet build complete!"
    echo "   Binary: target/release/los-node"
    echo "   CLI:    target/release/los-cli"
    echo ""
    echo "⚠️  Mainnet requires:"
    echo "   export LOS_WALLET_PASSWORD='your-strong-password'"
    echo "   Tor hidden service configured"
else
    echo "🏗️  Building TESTNET binary..."
    cargo build --release
    echo ""
    echo "✅ Testnet build complete!"
    echo "   Binary: target/release/los-node"
    echo "   CLI:    target/release/los-cli"
    echo ""
    echo "🚀 Quick start: ./start.sh"
fi
