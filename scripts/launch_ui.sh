#!/bin/bash

###############################################################################
#  UNAUTHORITY - UI LAUNCHER (Production Ready)
#  
#  Launches both Wallet and Validator Dashboard in separate terminal windows
#  Professional process management for end users
###############################################################################

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLET_DIR="$PROJECT_ROOT/frontend-wallet"
VALIDATOR_DIR="$PROJECT_ROOT/frontend-validator"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           UNAUTHORITY - UI LAUNCHER v1.0                       ║"
echo "║           Professional Blockchain Interface                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if frontend directories exist
if [ ! -d "$WALLET_DIR" ]; then
    echo -e "${RED}❌ Error: Wallet directory not found${NC}"
    echo "   Expected: $WALLET_DIR"
    exit 1
fi

if [ ! -d "$VALIDATOR_DIR" ]; then
    echo -e "${RED}❌ Error: Validator directory not found${NC}"
    echo "   Expected: $VALIDATOR_DIR"
    exit 1
fi

# Check if dependencies are installed
echo -e "${BLUE}🔍 Checking dependencies...${NC}"
if [ ! -d "$WALLET_DIR/node_modules" ]; then
    echo -e "${YELLOW}⚠️  Wallet dependencies not installed${NC}"
    echo -e "${BLUE}   Installing wallet dependencies...${NC}"
    cd "$WALLET_DIR" && npm install
fi

if [ ! -d "$VALIDATOR_DIR/node_modules" ]; then
    echo -e "${YELLOW}⚠️  Validator dependencies not installed${NC}"
    echo -e "${BLUE}   Installing validator dependencies...${NC}"
    cd "$VALIDATOR_DIR" && npm install
fi

echo -e "${GREEN}✅ Dependencies ready${NC}"
echo ""

# Kill existing processes
echo -e "${BLUE}🧹 Cleaning existing processes...${NC}"
pkill -f "vite.*5173" 2>/dev/null || true
pkill -f "vite.*5174" 2>/dev/null || true
pkill -f "vite.*5175" 2>/dev/null || true
pkill -f "vite.*5176" 2>/dev/null || true
sleep 1
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# Detect OS for terminal launching
OS_TYPE="$(uname -s)"

launch_wallet() {
    echo -e "${BLUE}🚀 Launching Public Wallet...${NC}"
    
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS - use Terminal.app or iTerm2
        osascript <<EOF
tell application "Terminal"
    do script "cd '$WALLET_DIR' && clear && echo '═══════════════════════════════════════════════' && echo '  UNAUTHORITY PUBLIC WALLET' && echo '═══════════════════════════════════════════════' && echo '' && npm run dev"
    activate
end tell
EOF
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Linux - try common terminals
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "cd '$WALLET_DIR' && npm run dev; exec bash"
        elif command -v konsole &> /dev/null; then
            konsole -e bash -c "cd '$WALLET_DIR' && npm run dev; exec bash"
        elif command -v xterm &> /dev/null; then
            xterm -e "cd '$WALLET_DIR' && npm run dev; bash" &
        else
            echo -e "${RED}❌ No terminal emulator found${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS: $OS_TYPE${NC}"
        return 1
    fi
    
    sleep 2
}

launch_validator() {
    echo -e "${BLUE}🚀 Launching Validator Dashboard...${NC}"
    
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS
        osascript <<EOF
tell application "Terminal"
    do script "cd '$VALIDATOR_DIR' && clear && echo '═══════════════════════════════════════════════' && echo '  UNAUTHORITY VALIDATOR DASHBOARD' && echo '═══════════════════════════════════════════════' && echo '' && npm run dev"
    activate
end tell
EOF
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Linux
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "cd '$VALIDATOR_DIR' && npm run dev; exec bash"
        elif command -v konsole &> /dev/null; then
            konsole -e bash -c "cd '$VALIDATOR_DIR' && npm run dev; exec bash"
        elif command -v xterm &> /dev/null; then
            xterm -e "cd '$VALIDATOR_DIR' && npm run dev; bash" &
        else
            echo -e "${RED}❌ No terminal emulator found${NC}"
            return 1
        fi
    fi
    
    sleep 2
}

# Launch both UIs
launch_wallet
launch_validator

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ UI SERVICES LAUNCHED SUCCESSFULLY                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📡 Services starting...${NC}"
echo ""
echo "   Wait 5-10 seconds for Vite to compile, then check your new terminal windows."
echo ""
echo -e "${YELLOW}📝 Expected URLs:${NC}"
echo "   • Public Wallet:       http://localhost:5173"
echo "   • Validator Dashboard: http://localhost:5174"
echo ""
echo -e "${BLUE}🌐 Open the URLs shown in each terminal window in your browser${NC}"
echo ""
echo -e "${YELLOW}⚠️  Note:${NC} If backend is offline, UIs will show 'Offline' status (normal)."
echo "        Start backend: ./start_network.sh"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
