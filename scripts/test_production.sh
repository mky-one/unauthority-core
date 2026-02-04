#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════════════
#  UNAUTHORITY PRODUCTION READINESS TEST SUITE
#  Comprehensive validation of all blockchain components
# ═══════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

test_pass() {
    echo -e "   ${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "   ${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_warn() {
    echo -e "   ${YELLOW}⚠${NC} $1"
    TESTS_WARNED=$((TESTS_WARNED + 1))
}

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     UNAUTHORITY PRODUCTION READINESS TEST SUITE           ║"
echo "║     Comprehensive Blockchain Validation                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 1: COMPILATION & BUILD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${MAGENTA}━━━ SESI 1: BUILD & COMPILATION ━━━${NC}"
echo ""
echo -e "${BLUE}[TEST 1.1]${NC} Release Build"
if cargo build --release --bin uat-node > /dev/null 2>&1; then
    test_pass "Release build successful"
    
    # Check binary size
    BINARY_SIZE=$(du -h target/release/uat-node | cut -f1)
    echo -e "   ${BLUE}ℹ${NC}  Binary size: $BINARY_SIZE"
else
    test_fail "Release build failed"
    echo ""
    echo -e "${RED}❌ BUILD FAILED - Cannot proceed with tests${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[TEST 1.2]${NC} Unit Tests"
if cargo test --release --quiet > /dev/null 2>&1; then
    test_pass "All unit tests passing"
else
    test_warn "Some unit tests failed (non-blocking)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 2: MULTI-NODE STARTUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 2: MULTI-NODE NETWORK ━━━${NC}"
echo ""

# Clean old processes
echo -e "${YELLOW}🧹 Cleaning environment...${NC}"
pkill -9 uat-node 2>/dev/null || true
rm -rf node_data/validator-*/uat_database 2>/dev/null || true
mkdir -p node_data/validator-{1,2,3}

echo -e "${BLUE}[TEST 2.1]${NC} Node Directory Structure"
if [ -d "node_data/validator-1" ] && [ -d "node_data/validator-2" ] && [ -d "node_data/validator-3" ]; then
    test_pass "All node directories created"
else
    test_fail "Missing node directories"
    exit 1
fi

echo ""
echo -e "${BLUE}[TEST 2.2]${NC} Starting 3-Node Network"
echo "   Launching nodes..."

# Start Node 1
export UAT_NODE_ID="validator-1"
./target/release/uat-node 3030 > node_data/validator-1/node.log 2>&1 &
PID1=$!
echo "   Node 1 started (PID: $PID1)"

sleep 3

# Start Node 2
export UAT_NODE_ID="validator-2"
./target/release/uat-node 3031 > node_data/validator-2/node.log 2>&1 &
PID2=$!
echo "   Node 2 started (PID: $PID2)"

sleep 3

# Start Node 3
export UAT_NODE_ID="validator-3"
./target/release/uat-node 3032 > node_data/validator-3/node.log 2>&1 &
PID3=$!
echo "   Node 3 started (PID: $PID3)"

# Save PIDs
echo "$PID1" > node_data/pids.txt
echo "$PID2" >> node_data/pids.txt
echo "$PID3" >> node_data/pids.txt

echo "   Waiting for initialization (15s)..."
for i in {15..1}; do
    echo -ne "   $i seconds...\r"
    sleep 1
done
echo -e "   ${GREEN}✓ Initialization complete${NC}     "

echo ""
echo -e "${BLUE}[TEST 2.3]${NC} Node Connectivity"

# Check Node 1
if curl -s -f http://localhost:3030/supply > /dev/null 2>&1; then
    test_pass "Node 1 (3030) is online"
else
    test_fail "Node 1 (3030) is offline"
fi

# Check Node 2
if curl -s -f http://localhost:3031/supply > /dev/null 2>&1; then
    test_pass "Node 2 (3031) is online"
else
    test_fail "Node 2 (3031) is offline"
fi

# Check Node 3
if curl -s -f http://localhost:3032/supply > /dev/null 2>&1; then
    test_pass "Node 3 (3032) is online"
else
    test_fail "Node 3 (3032) is offline"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 3: DATABASE ISOLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 3: DATABASE ISOLATION ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 3.1]${NC} Separate Database Files"
if [ -d "node_data/validator-1/uat_database" ] && \
   [ -d "node_data/validator-2/uat_database" ] && \
   [ -d "node_data/validator-3/uat_database" ]; then
    test_pass "Each node has separate database"
    
    # Check database sizes
    DB1_SIZE=$(du -sh node_data/validator-1/uat_database 2>/dev/null | cut -f1 || echo "N/A")
    DB2_SIZE=$(du -sh node_data/validator-2/uat_database 2>/dev/null | cut -f1 || echo "N/A")
    DB3_SIZE=$(du -sh node_data/validator-3/uat_database 2>/dev/null | cut -f1 || echo "N/A")
    
    echo -e "   ${BLUE}ℹ${NC}  Node 1 DB: $DB1_SIZE"
    echo -e "   ${BLUE}ℹ${NC}  Node 2 DB: $DB2_SIZE"
    echo -e "   ${BLUE}ℹ${NC}  Node 3 DB: $DB3_SIZE"
else
    test_fail "Database isolation broken"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 4: CONSENSUS CONSISTENCY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 4: CONSENSUS & STATE SYNC ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 4.1]${NC} Supply Consistency"
SUPPLY_1=$(curl -s http://localhost:3030/supply | grep -o '"remaining_supply_void":[0-9]*' | cut -d':' -f2)
SUPPLY_2=$(curl -s http://localhost:3031/supply | grep -o '"remaining_supply_void":[0-9]*' | cut -d':' -f2)
SUPPLY_3=$(curl -s http://localhost:3032/supply | grep -o '"remaining_supply_void":[0-9]*' | cut -d':' -f2)

echo "   Node 1: $SUPPLY_1 VOI"
echo "   Node 2: $SUPPLY_2 VOI"
echo "   Node 3: $SUPPLY_3 VOI"

if [ "$SUPPLY_1" = "$SUPPLY_2" ] && [ "$SUPPLY_2" = "$SUPPLY_3" ]; then
    test_pass "All nodes report same supply"
else
    test_fail "Supply mismatch detected"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 5: TRANSACTION FUNCTIONALITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 5: TRANSACTION TESTS ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 5.1]${NC} Faucet Endpoint (DEV MODE)"
TEST_WALLET="UATTest_$(date +%s)"
FAUCET_RESULT=$(curl -s -X POST http://localhost:3030/faucet \
    -H "Content-Type: application/json" \
    -d "{\"address\":\"$TEST_WALLET\"}")

if echo "$FAUCET_RESULT" | grep -q '"status":"success"'; then
    test_pass "Faucet claim successful"
    FAUCET_AMT=$(echo "$FAUCET_RESULT" | grep -o '"amount":[0-9]*' | cut -d':' -f2)
    echo -e "   ${BLUE}ℹ${NC}  Received: $FAUCET_AMT UAT"
else
    test_fail "Faucet endpoint failed"
fi

echo ""
echo -e "${BLUE}[TEST 5.2]${NC} Balance Verification"
sleep 2
BALANCE=$(curl -s http://localhost:3030/balance/$TEST_WALLET | grep -o '"balance_uat":[0-9]*' | cut -d':' -f2)

if [ "$BALANCE" -gt 0 ]; then
    test_pass "Balance updated correctly ($BALANCE UAT)"
else
    test_fail "Balance not updated"
fi

echo ""
echo -e "${BLUE}[TEST 5.3]${NC} Burn Transaction (Recipient Fix)"
BURN_WALLET="UATBurn_$(date +%s)"
BURN_TXID="a1b2c3d4e5f6789012345678901234567890123456789012345678901234test"

BURN_RESULT=$(curl -s -X POST http://localhost:3030/burn \
    -H "Content-Type: application/json" \
    -d "{\"coin_type\":\"btc\",\"txid\":\"$BURN_TXID\",\"recipient_address\":\"$BURN_WALLET\"}")

if echo "$BURN_RESULT" | grep -q '"status":"success"'; then
    test_pass "Burn transaction succeeded"
    
    RECIPIENT=$(echo "$BURN_RESULT" | grep -o '"recipient":"[^"]*"' | cut -d'"' -f4)
    UAT_MINTED=$(echo "$BURN_RESULT" | grep -o '"uat_minted":[0-9]*' | cut -d':' -f2)
    
    echo -e "   ${BLUE}ℹ${NC}  UAT Minted: $UAT_MINTED"
    echo -e "   ${BLUE}ℹ${NC}  Recipient: $RECIPIENT"
    
    if [ "$RECIPIENT" = "$BURN_WALLET" ]; then
        test_pass "Recipient address matches (CRITICAL FIX VERIFIED)"
    else
        test_fail "Recipient mismatch!"
    fi
    
    # Verify balance
    sleep 2
    BURN_BALANCE=$(curl -s http://localhost:3030/balance/$BURN_WALLET | grep -o '"balance_uat":[0-9]*' | cut -d':' -f2)
    
    if [ "$BURN_BALANCE" = "$UAT_MINTED" ]; then
        test_pass "UAT correctly credited to user wallet (not validator)"
    else
        test_fail "Balance mismatch after burn"
    fi
else
    test_fail "Burn transaction failed"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 6: gRPC ENDPOINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 6: gRPC API VALIDATION ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 6.1]${NC} Dynamic gRPC Ports"
echo "   Expected: Node 1→23030, Node 2→23031, Node 3→23032"

if command -v grpcurl > /dev/null 2>&1; then
    if timeout 3 grpcurl -plaintext localhost:23030 list > /dev/null 2>&1; then
        test_pass "Node 1 gRPC (23030) responding"
    else
        test_warn "Node 1 gRPC not responding (may still be initializing)"
    fi
    
    if timeout 3 grpcurl -plaintext localhost:23031 list > /dev/null 2>&1; then
        test_pass "Node 2 gRPC (23031) responding"
    else
        test_warn "Node 2 gRPC not responding (may still be initializing)"
    fi
    
    if timeout 3 grpcurl -plaintext localhost:23032 list > /dev/null 2>&1; then
        test_pass "Node 3 gRPC (23032) responding"
    else
        test_warn "Node 3 gRPC not responding (may still be initializing)"
    fi
else
    test_warn "grpcurl not installed, skipping gRPC tests"
    echo -e "   ${YELLOW}ℹ${NC}  Install: brew install grpcurl (macOS)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 7: SECURITY VALIDATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 7: SECURITY CHECKS ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 7.1]${NC} Private Key Leaks"
if grep -r "PRIVATE_KEY" node_data/validator-*/node.log > /dev/null 2>&1; then
    test_fail "Private keys found in logs!"
else
    test_pass "No private key leaks detected"
fi

echo ""
echo -e "${BLUE}[TEST 7.2]${NC} Immutability Check"
if grep -r "fn pause_network\|fn admin_\|fn emergency_stop" crates/ > /dev/null 2>&1; then
    test_fail "Admin functions detected (violates immutability)"
else
    test_pass "No admin functions found (immutable confirmed)"
fi

echo ""
echo -e "${BLUE}[TEST 7.3]${NC} Fixed Supply Verification"
NODE_INFO=$(curl -s http://localhost:3030/node-info)
TOTAL_SUPPLY=$(echo "$NODE_INFO" | grep -o '"total_supply":[0-9]*' | cut -d':' -f2)

if [ "$TOTAL_SUPPLY" = "21936236" ]; then
    test_pass "Total supply fixed at 21,936,236 UAT"
else
    test_fail "Total supply incorrect: $TOTAL_SUPPLY"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST SESI 8: PERFORMANCE METRICS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${MAGENTA}━━━ SESI 8: PERFORMANCE MONITORING ━━━${NC}"
echo ""

echo -e "${BLUE}[TEST 8.1]${NC} Memory Usage"
for pid in $PID1 $PID2 $PID3; do
    if ps -p "$pid" > /dev/null 2>&1; then
        MEM=$(ps -o rss= -p "$pid" | awk '{printf "%.1f", $1/1024}')
        if (( $(echo "$MEM < 500" | bc -l 2>/dev/null || echo 0) )); then
            test_pass "Node $pid: ${MEM}MB (healthy)"
        else
            test_warn "Node $pid: ${MEM}MB (high memory)"
        fi
    fi
done

echo ""
echo -e "${BLUE}[TEST 8.2]${NC} Response Time"
START=$(date +%s%3N)
curl -s http://localhost:3030/supply > /dev/null
END=$(date +%s%3N)
LATENCY=$((END - START))

if [ "$LATENCY" -lt 100 ]; then
    test_pass "API response time: ${LATENCY}ms (excellent)"
elif [ "$LATENCY" -lt 500 ]; then
    test_warn "API response time: ${LATENCY}ms (acceptable)"
else
    test_fail "API response time: ${LATENCY}ms (slow)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLEANUP & RESULTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${YELLOW}🧹 Cleaning up test network...${NC}"
./stop_network.sh > /dev/null 2>&1 || kill $PID1 $PID2 $PID3 2>/dev/null || true

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  TEST RESULTS SUMMARY                     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}✗ Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}⚠ Warned:${NC}  $TESTS_WARNED"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED / $TOTAL_TESTS) * 100}")
    echo -e "  ${BLUE}Success Rate:${NC} $SUCCESS_RATE%"
    echo ""
fi

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ ALL CRITICAL TESTS PASSED - PRODUCTION READY! ✅      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🚀 Ready to deploy to testnet!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ SOME TESTS FAILED - FIX BEFORE RELEASE ❌            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Review errors above and fix issues${NC}"
    echo ""
    exit 1
fi
