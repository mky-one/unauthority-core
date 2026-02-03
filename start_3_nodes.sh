#!/bin/bash

echo "🚀 Starting 3 Unauthority Nodes for Testing..."

# Kill existing nodes
pkill -9 uat-node 2>/dev/null

# Create separate data directories
mkdir -p node_a_data node_b_data node_c_data

# Start Node A (port 3030)
echo "📡 Starting Node A on port 3030..."
cd node_a_data
../target/release/uat-node 3030 > ../node_a.log 2>&1 &
NODE_A_PID=$!
cd ..

sleep 2

# Start Node B (port 3031)  
echo "📡 Starting Node B on port 3031..."
cd node_b_data
../target/release/uat-node 3031 > ../node_b.log 2>&1 &
NODE_B_PID=$!
cd ..

sleep 2

# Start Node C (port 3032)
echo "📡 Starting Node C on port 3032..."
cd node_c_data
../target/release/uat-node 3032 > ../node_c.log 2>&1 &
NODE_C_PID=$!
cd ..

sleep 2

echo ""
echo "✅ All nodes started!"
echo "   Node A (3030): PID $NODE_A_PID"
echo "   Node B (3031): PID $NODE_B_PID"
echo "   Node C (3032): PID $NODE_C_PID"
echo ""
echo "📊 View logs:"
echo "   tail -f node_a.log"
echo "   tail -f node_b.log"
echo "   tail -f node_c.log"
echo ""
echo "🔥 Test burn transaction:"
echo "   curl -X POST http://localhost:3030/burn -H 'Content-Type: application/json' -d '{\"coin_type\":\"btc\",\"txid\":\"a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd\"}'"
echo ""
echo "🛑 Stop all nodes:"
echo "   pkill -9 uat-node"
