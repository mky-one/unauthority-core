#!/bin/bash

###############################################################################
#  UNAUTHORITY - FULL STACK STOPPER
#  
#  Gracefully stops all services (Backend + UIs)
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           STOPPING ALL UNAUTHORITY SERVICES                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}[1/2] Stopping backend nodes...${NC}"
pkill -9 uat-node 2>/dev/null && echo "   ✅ Backend nodes stopped" || echo "   • No backend nodes running"
sleep 1

echo ""
echo -e "${YELLOW}[2/2] Stopping UI services...${NC}"
pkill -f "vite.*5173" 2>/dev/null && echo "   • Stopped Wallet (5173)"
pkill -f "vite.*5174" 2>/dev/null && echo "   • Stopped Validator (5174)"
pkill -f "vite.*5175" 2>/dev/null && echo "   • Stopped service (5175)"
pkill -f "vite.*5176" 2>/dev/null && echo "   • Stopped service (5176)"
pkill -f "npm.*dev" 2>/dev/null

sleep 1

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ ALL SERVICES STOPPED                                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

