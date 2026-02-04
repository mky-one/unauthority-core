#!/bin/bash

echo "🎨 Starting Unauthority Wallet Development Server..."
cd "$(dirname "$0")/frontend-wallet"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "⚠️  node_modules not found. Running npm install..."
    npm install
fi

# Start Vite dev server
echo ""
echo "✅ Starting wallet on http://localhost:5173/"
echo "📝 Press Ctrl+C to stop"
echo ""
npm run dev
