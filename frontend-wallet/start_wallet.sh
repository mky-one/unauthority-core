#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY PUBLIC WALLET - QUICK START SCRIPT
# Automated setup for macOS/Linux
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "======================================================================"
echo "  UNAUTHORITY PUBLIC WALLET - SETUP & LAUNCH"
echo "======================================================================"
echo ""

# Check if Node.js installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found!"
    echo ""
    echo "Please install Node.js 18+ first:"
    echo "  macOS: brew install node"
    echo "  Linux: sudo apt install nodejs npm"
    echo "  Or download: https://nodejs.org"
    echo ""
    exit 1
fi

NODE_VERSION=$(node -v)
echo "✅ Node.js detected: $NODE_VERSION"

# Check if npm installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found!"
    exit 1
fi

echo "✅ npm detected: $(npm -v)"
echo ""

# Navigate to frontend directory
cd "$(dirname "$0")"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies (this may take a few minutes)..."
    npm install
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install dependencies!"
        exit 1
    fi
    
    echo "✅ Dependencies installed"
else
    echo "✅ Dependencies already installed"
fi

echo ""
echo "======================================================================"
echo "  STARTING WALLET"
echo "======================================================================"
echo ""
echo "🚀 Launching Unauthority Wallet..."
echo ""
echo "⚠️  IMPORTANT: Make sure your Unauthority node is running!"
echo "   Command: ./target/release/los-node 3030"
echo ""
echo "📡 Wallet will connect to: http://localhost:3030"
echo ""

# Start development server
npm run dev
