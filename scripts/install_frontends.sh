#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     UNAUTHORITY FRONTEND - DEPENDENCY INSTALLER           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check Public Wallet
echo "📦 Checking Public Wallet dependencies..."
if [ -d "frontend-wallet/node_modules" ]; then
    echo "   ✅ Public Wallet dependencies already installed"
else
    echo "   ⏳ Installing Public Wallet dependencies..."
    cd frontend-wallet
    npm install
    cd ..
    echo "   ✅ Public Wallet dependencies installed"
fi
echo ""

# Check Validator Dashboard
echo "📦 Checking Validator Dashboard dependencies..."
if [ -d "frontend-validator/node_modules" ]; then
    echo "   ✅ Validator Dashboard dependencies already installed"
else
    echo "   ⏳ Installing Validator Dashboard dependencies..."
    cd frontend-validator
    npm install
    cd ..
    echo "   ✅ Validator Dashboard dependencies installed"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     READY TO RUN!                                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🚀 To start development servers:"
echo ""
echo "Terminal 1 (Backend):"
echo "  ./start_network.sh"
echo ""
echo "Terminal 2 (Public Wallet):"
echo "  cd frontend-wallet && npm run dev"
echo "  Open: http://localhost:5173"
echo ""
echo "Terminal 3 (Validator Dashboard):"
echo "  cd frontend-validator && npm run dev"
echo "  Open: http://localhost:5174"
echo ""
