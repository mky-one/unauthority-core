#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     UNAUTHORITY - START ALL SERVICES                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if already running
if pgrep -f "uat-node" > /dev/null; then
    echo "⚠️  Backend nodes already running. Stop them first with ./stop_network.sh"
    exit 1
fi

# Start backend
echo "🔧 Starting backend (3-node network)..."
./start_network.sh &
BACKEND_PID=$!
echo "   Backend PID: $BACKEND_PID"
sleep 10

# Start wallet
echo ""
echo "🎨 Starting Public Wallet..."
cd frontend-wallet
npm run dev > ../logs/wallet.log 2>&1 &
WALLET_PID=$!
echo "   Wallet PID: $WALLET_PID"
echo "   URL: http://localhost:5173"
cd ..

# Start validator
echo ""
echo "📊 Starting Validator Dashboard..."
cd frontend-validator
npm run dev > ../logs/validator.log 2>&1 &
VALIDATOR_PID=$!
echo "   Validator PID: $VALIDATOR_PID"
echo "   URL: http://localhost:5174"
cd ..

# Save PIDs
mkdir -p logs
echo $BACKEND_PID > logs/backend.pid
echo $WALLET_PID > logs/wallet.pid
echo $VALIDATOR_PID > logs/validator.pid

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     ALL SERVICES RUNNING!                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Access Points:"
echo "   Backend Node 1:       http://localhost:3030"
echo "   Backend Node 2:       http://localhost:3031"
echo "   Backend Node 3:       http://localhost:3032"
echo "   Public Wallet:        http://localhost:5173"
echo "   Validator Dashboard:  http://localhost:5174"
echo ""
echo "📝 Logs:"
echo "   Backend: node_data/validator-{1,2,3}/node.log"
echo "   Wallet:  logs/wallet.log"
echo "   Validator: logs/validator.log"
echo ""
echo "🛑 To stop all services:"
echo "   ./stop_all.sh"
echo ""
