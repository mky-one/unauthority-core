#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY TOR TESTNET LAUNCHER
# Creates 4 bootstrap validators, each behind a unique Tor hidden service
# 100% FREE • NO VPS • NO DOMAIN • NO KYC • PRIVACY-FIRST
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -e

# ── Configuration ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOR_DATA="$HOME/.los-testnet-tor"
TOR_SOCKS_PORT=9052
VALIDATOR_REST_PORTS=(3030 3031 3032 3033)
VALIDATOR_P2P_PORTS=(4001 4002 4003 4004)
NODE_BIN="$SCRIPT_DIR/target/release/los-node"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     🧅 UNAUTHORITY TOR TESTNET LAUNCHER                      ║"
echo "║     4 Bootstrap Validators via Tor Hidden Services            ║"
echo "║     100% Free • No VPS • No Domain • Privacy-First           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. FIND OR INSTALL TOR
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "🔍 Step 1: Checking for Tor binary..."

TOR_BIN=""
for candidate in /opt/homebrew/bin/tor /usr/local/bin/tor /usr/bin/tor /opt/local/bin/tor; do
    if [ -x "$candidate" ]; then
        TOR_BIN="$candidate"
        break
    fi
done

if [ -z "$TOR_BIN" ]; then
    TOR_BIN=$(which tor 2>/dev/null || true)
fi

if [ -z "$TOR_BIN" ]; then
    echo "   Tor not found. Attempting auto-install..."
    if command -v brew &>/dev/null; then
        echo "   📦 Installing via Homebrew (this may take a minute)..."
        brew install tor
        TOR_BIN=$(which tor 2>/dev/null || echo "/opt/homebrew/bin/tor")
    elif command -v apt-get &>/dev/null; then
        echo "   📦 Installing via apt..."
        sudo apt-get install -y tor
        TOR_BIN="/usr/bin/tor"
    else
        echo "   ❌ Cannot install Tor automatically."
        echo "   Install manually:"
        echo "     macOS:  brew install tor"
        echo "     Linux:  sudo apt install tor"
        exit 1
    fi
fi

if [ ! -x "$TOR_BIN" ]; then
    echo "   ❌ Tor binary not executable: $TOR_BIN"
    exit 1
fi

echo "   ✅ Tor: $TOR_BIN"
echo "      $($TOR_BIN --version | head -1)"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. KILL EXISTING TESTNET (if running)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "🧹 Step 2: Cleaning up previous testnet..."

if [ -f "$TOR_DATA/tor.pid" ]; then
    OLD_PID=$(cat "$TOR_DATA/tor.pid" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
        echo "   Stopped old Tor daemon (PID: $OLD_PID)"
    fi
fi

for i in 1 2 3 4; do
    if [ -f "$SCRIPT_DIR/node_data/validator-$i/pid.txt" ]; then
        OLD_PID=$(cat "$SCRIPT_DIR/node_data/validator-$i/pid.txt" 2>/dev/null || echo "")
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            kill "$OLD_PID" 2>/dev/null || true
            echo "   Stopped old Validator-$i (PID: $OLD_PID)"
        fi
    fi
done
echo "   ✅ Clean"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. CREATE TOR DATA DIRECTORIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📁 Step 3: Creating Tor hidden service directories..."

mkdir -p "$TOR_DATA/data"
for i in 1 2 3 4; do
    mkdir -p "$TOR_DATA/hs-validator-$i"
    chmod 700 "$TOR_DATA/hs-validator-$i"
done
echo "   ✅ $TOR_DATA"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. GENERATE TORRC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "⚙️  Step 4: Generating Tor configuration..."

TORRC="$TOR_DATA/torrc"
cat > "$TORRC" << TORRC_EOF
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY TESTNET — Tor Hidden Services Configuration
# Generated by setup_tor_testnet.sh at $(date -u +%Y-%m-%dT%H:%M:%SZ)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DataDirectory $TOR_DATA/data
SocksPort $TOR_SOCKS_PORT
Log notice file $TOR_DATA/tor.log

# Performance tuning
MaxCircuitDirtiness 600
MaxClientCircuitsPending 48

# Client-only mode (we're not a relay)
ClientOnly 1
ExitRelay 0
ExitPolicy reject *:*

# ── Hidden Service: Validator 1 ──────────────────────────────────────
HiddenServiceDir $TOR_DATA/hs-validator-1
HiddenServicePort 80 127.0.0.1:${VALIDATOR_REST_PORTS[0]}
HiddenServicePort 4001 127.0.0.1:${VALIDATOR_P2P_PORTS[0]}

# ── Hidden Service: Validator 2 ──────────────────────────────────────
HiddenServiceDir $TOR_DATA/hs-validator-2
HiddenServicePort 80 127.0.0.1:${VALIDATOR_REST_PORTS[1]}
HiddenServicePort 4001 127.0.0.1:${VALIDATOR_P2P_PORTS[1]}

# ── Hidden Service: Validator 3 ──────────────────────────────────────
HiddenServiceDir $TOR_DATA/hs-validator-3
HiddenServicePort 80 127.0.0.1:${VALIDATOR_REST_PORTS[2]}
HiddenServicePort 4001 127.0.0.1:${VALIDATOR_P2P_PORTS[2]}

# ── Hidden Service: Validator 4 ──────────────────────────────────────
HiddenServiceDir $TOR_DATA/hs-validator-4
HiddenServicePort 80 127.0.0.1:${VALIDATOR_REST_PORTS[3]}
HiddenServicePort 4001 127.0.0.1:${VALIDATOR_P2P_PORTS[3]}
TORRC_EOF

echo "   ✅ $TORRC"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. BUILD LOS-NODE (if needed)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "🔨 Step 5: Checking los-node binary..."

if [ ! -f "$NODE_BIN" ]; then
    echo "   Building release binary (this may take a few minutes)..."
    cd "$SCRIPT_DIR"
    cargo build --release -p los-node
    echo ""
fi

if [ ! -f "$NODE_BIN" ]; then
    echo "   ❌ Build failed. Binary not found: $NODE_BIN"
    exit 1
fi

echo "   ✅ $NODE_BIN"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. START TOR DAEMON
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "🧅 Step 6: Starting Tor daemon..."

# Verify config before starting
if ! $TOR_BIN --verify-config -f "$TORRC" > /dev/null 2>&1; then
    echo "   ❌ Tor configuration invalid!"
    $TOR_BIN --verify-config -f "$TORRC"
    exit 1
fi

# Start Tor in background
$TOR_BIN -f "$TORRC" &
TOR_PID=$!
echo "$TOR_PID" > "$TOR_DATA/tor.pid"

echo "   PID: $TOR_PID"
echo "   SOCKS5: 127.0.0.1:$TOR_SOCKS_PORT"
echo "   Log: $TOR_DATA/tor.log"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. WAIT FOR HIDDEN SERVICES (.onion addresses)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "⏳ Step 7: Waiting for Tor hidden services..."
echo "   First run takes 30-120 seconds (subsequent runs are instant)"
echo ""

MAX_WAIT=180
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    ALL_READY=true
    for i in 1 2 3 4; do
        if [ ! -f "$TOR_DATA/hs-validator-$i/hostname" ]; then
            ALL_READY=false
            break
        fi
    done

    if $ALL_READY; then
        break
    fi

    # Check if Tor is still alive
    if ! kill -0 "$TOR_PID" 2>/dev/null; then
        echo ""
        echo "   ❌ Tor daemon crashed. Check log: $TOR_DATA/tor.log"
        tail -20 "$TOR_DATA/tor.log" 2>/dev/null || true
        exit 1
    fi

    sleep 2
    WAITED=$((WAITED + 2))
    printf "\r   ⏳ %ds / %ds..." "$WAITED" "$MAX_WAIT"
done
echo ""

if ! $ALL_READY; then
    echo "   ❌ Tor hidden services failed to initialize within ${MAX_WAIT}s"
    echo "   Check log: tail -50 $TOR_DATA/tor.log"
    kill "$TOR_PID" 2>/dev/null || true
    exit 1
fi

# Read .onion addresses
ONION_ADDRS=()
echo "   ✅ Hidden services ready!"
echo ""
for i in 1 2 3 4; do
    ADDR=$(cat "$TOR_DATA/hs-validator-$i/hostname")
    ONION_ADDRS+=("$ADDR")
    echo "   🧅 Validator-$i: $ADDR"
done
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 8. START 4 VALIDATORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "▶️  Step 8: Starting 4 bootstrap validators..."
echo ""

cd "$SCRIPT_DIR"
mkdir -p node_data/validator-{1,2,3,4}/logs

for i in 0 1 2 3; do
    N=$((i + 1))
    REST_PORT=${VALIDATOR_REST_PORTS[$i]}
    P2P_PORT=${VALIDATOR_P2P_PORTS[$i]}
    MY_ONION=${ONION_ADDRS[$i]}

    # Build bootstrap list: LOCAL P2P ports (fast, same machine) + .onion addresses (external)
    # Local multiaddrs ensure instant peering; .onion addresses are for remote nodes.
    BOOTSTRAP=""
    for j in 0 1 2 3; do
        if [ $j -ne $i ]; then
            if [ -n "$BOOTSTRAP" ]; then
                BOOTSTRAP="$BOOTSTRAP,"
            fi
            # Local direct connection first (fast), then .onion (for external peers)
            BOOTSTRAP="${BOOTSTRAP}/ip4/127.0.0.1/tcp/${VALIDATOR_P2P_PORTS[$j]}"
        fi
    done

    echo "   ▶ Validator-$N"
    echo "     REST: localhost:$REST_PORT → http://$MY_ONION"
    echo "     P2P:  localhost:$P2P_PORT  → $MY_ONION:4001"

    # Export environment for this validator
    # Nodes bind to 127.0.0.1 ONLY — Tor hidden services handle external access
    LOS_NODE_ID="validator-$N" \
    LOS_TOR_SOCKS5="127.0.0.1:$TOR_SOCKS_PORT" \
    LOS_ONION_ADDRESS="$MY_ONION" \
    LOS_P2P_PORT="$P2P_PORT" \
    LOS_BOOTSTRAP_NODES="$BOOTSTRAP" \
    LOS_TESTNET_LEVEL="consensus" \
    RUST_BACKTRACE=1 \
    nohup "$NODE_BIN" --port "$REST_PORT" --data-dir "node_data/validator-$N" \
        > "node_data/validator-$N/logs/node.log" 2>&1 &

    echo $! > "node_data/validator-$N/pid.txt"
    echo "     PID: $(cat node_data/validator-$N/pid.txt)"
    echo ""
    sleep 2
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 9. SAVE TESTNET INFO FILE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INFO_FILE="$SCRIPT_DIR/testnet-tor-info.json"
cat > "$INFO_FILE" << JSON_EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tor_socks_port": $TOR_SOCKS_PORT,
  "validators": [
    {
      "id": 1,
      "onion": "${ONION_ADDRS[0]}",
      "rest_url": "http://${ONION_ADDRS[0]}",
      "p2p": "${ONION_ADDRS[0]}:4001",
      "local_rest": "http://127.0.0.1:${VALIDATOR_REST_PORTS[0]}",
      "local_p2p": "127.0.0.1:${VALIDATOR_P2P_PORTS[0]}"
    },
    {
      "id": 2,
      "onion": "${ONION_ADDRS[1]}",
      "rest_url": "http://${ONION_ADDRS[1]}",
      "p2p": "${ONION_ADDRS[1]}:4001",
      "local_rest": "http://127.0.0.1:${VALIDATOR_REST_PORTS[1]}",
      "local_p2p": "127.0.0.1:${VALIDATOR_P2P_PORTS[1]}"
    },
    {
      "id": 3,
      "onion": "${ONION_ADDRS[2]}",
      "rest_url": "http://${ONION_ADDRS[2]}",
      "p2p": "${ONION_ADDRS[2]}:4001",
      "local_rest": "http://127.0.0.1:${VALIDATOR_REST_PORTS[2]}",
      "local_p2p": "127.0.0.1:${VALIDATOR_P2P_PORTS[2]}"
    },
    {
      "id": 4,
      "onion": "${ONION_ADDRS[3]}",
      "rest_url": "http://${ONION_ADDRS[3]}",
      "p2p": "${ONION_ADDRS[3]}:4001",
      "local_rest": "http://127.0.0.1:${VALIDATOR_REST_PORTS[3]}",
      "local_p2p": "127.0.0.1:${VALIDATOR_P2P_PORTS[3]}"
    }
  ],
  "flutter_wallet_url": "http://${ONION_ADDRS[0]}",
  "flutter_validator_url": "http://${ONION_ADDRS[0]}",
  "connection_guide": {
    "tor_browser": "http://${ONION_ADDRS[0]}/node-info",
    "curl_via_tor": "curl --socks5-hostname 127.0.0.1:$TOR_SOCKS_PORT http://${ONION_ADDRS[0]}/health"
  }
}
JSON_EOF

echo "💾 Step 9: Testnet info saved to testnet-tor-info.json"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 10. HEALTH CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "⏳ Waiting 8 seconds for validators to initialize..."
sleep 8

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 HEALTH CHECK (via localhost)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ONLINE=0
for i in 0 1 2 3; do
    N=$((i + 1))
    PORT=${VALIDATOR_REST_PORTS[$i]}
    if curl -sf "http://localhost:$PORT/node-info" > /dev/null 2>&1; then
        SHORT=$(curl -s "http://localhost:$PORT/whoami" 2>/dev/null | grep -o '"short":"[^"]*"' | cut -d'"' -f4 || echo "?")
        echo "   ✅ Validator-$N (:$PORT) ONLINE — $SHORT"
        ONLINE=$((ONLINE + 1))
    else
        echo "   ❌ Validator-$N (:$PORT) OFFLINE — check node_data/validator-$N/logs/node.log"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧅 UNAUTHORITY TOR TESTNET — $ONLINE/4 VALIDATORS ONLINE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 CONNECT WITH FLUTTER WALLET:"
echo "   The wallet auto-detects Tor."
echo "   Set API URL: http://${ONION_ADDRS[0]}"
echo ""
echo "🌐 TEST FROM TOR BROWSER (on any device):"
echo "   http://${ONION_ADDRS[0]}/node-info"
echo "   http://${ONION_ADDRS[0]}/health"
echo "   http://${ONION_ADDRS[0]}/supply"
echo ""
echo "🔌 TEST VIA CURL + TOR:"
echo "   curl --socks5-hostname 127.0.0.1:$TOR_SOCKS_PORT http://${ONION_ADDRS[0]}/health"
echo ""
echo "📋 SHARE WITH FRIENDS:"
echo "   Give them the .onion address: ${ONION_ADDRS[0]}"
echo "   They just need Tor Browser — open http://${ONION_ADDRS[0]}/node-info"
echo ""
echo "📊 LOGS:"
echo "   tail -f node_data/validator-1/logs/node.log"
echo "   tail -f $TOR_DATA/tor.log"
echo ""
echo "🛑 STOP:"
echo "   ./stop_tor_testnet.sh"
echo ""
