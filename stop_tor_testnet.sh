#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STOP UNAUTHORITY TOR TESTNET
# Stops all 4 validators and the Tor daemon
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOR_DATA="$HOME/.uat-testnet-tor"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     🛑 STOPPING UNAUTHORITY TOR TESTNET                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

STOPPED=0

# ── Stop Validators ──────────────────────────────────────────────────────
echo "▶ Stopping validators..."
for i in 1 2 3 4; do
    PID_FILE="$SCRIPT_DIR/node_data/validator-$i/pid.txt"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
            echo "   ✅ Validator-$i stopped (PID: $PID)"
            STOPPED=$((STOPPED + 1))
        else
            echo "   ⚠️  Validator-$i already stopped"
        fi
        rm -f "$PID_FILE"
    else
        echo "   ⚠️  Validator-$i — no PID file"
    fi
done

echo ""

# ── Stop Tor Daemon ──────────────────────────────────────────────────────
echo "▶ Stopping Tor daemon..."
if [ -f "$TOR_DATA/tor.pid" ]; then
    TOR_PID=$(cat "$TOR_DATA/tor.pid" 2>/dev/null || echo "")
    if [ -n "$TOR_PID" ] && kill -0 "$TOR_PID" 2>/dev/null; then
        kill "$TOR_PID" 2>/dev/null || true
        sleep 1
        # Force kill if still running
        if kill -0 "$TOR_PID" 2>/dev/null; then
            kill -9 "$TOR_PID" 2>/dev/null || true
        fi
        echo "   ✅ Tor daemon stopped (PID: $TOR_PID)"
        STOPPED=$((STOPPED + 1))
    else
        echo "   ⚠️  Tor daemon already stopped"
    fi
    rm -f "$TOR_DATA/tor.pid"
else
    echo "   ⚠️  No Tor PID file found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Stopped $STOPPED processes"
echo ""
echo "NOTE: .onion addresses are persistent — same addresses on restart."
echo "      Data lives in: $TOR_DATA"
echo "      To fully reset: rm -rf $TOR_DATA"
echo ""
echo "RESTART: ./setup_tor_testnet.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
