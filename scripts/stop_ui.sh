#!/bin/bash

###############################################################################
#  UNAUTHORITY - UI STOPPER
#  
#  Gracefully stops all UI processes
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           STOPPING UNAUTHORITY UI SERVICES                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}🛑 Stopping Vite dev servers...${NC}"

# Kill Vite processes on specific ports
pkill -f "vite.*5173" 2>/dev/null && echo "   • Stopped service on port 5173"
pkill -f "vite.*5174" 2>/dev/null && echo "   • Stopped service on port 5174"
pkill -f "vite.*5175" 2>/dev/null && echo "   • Stopped service on port 5175"
pkill -f "vite.*5176" 2>/dev/null && echo "   • Stopped service on port 5176"

# Kill any remaining npm dev processes
pkill -f "npm.*dev" 2>/dev/null

sleep 1

echo ""
echo -e "${GREEN}✅ All UI services stopped${NC}"
echo ""
