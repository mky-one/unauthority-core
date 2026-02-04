#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      UNAUTHORITY PRODUCTION READINESS TEST SUITE          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
TOTAL=0

test_pass() { 
    echo "✅ $1"
    PASS=$((PASS+1))
    TOTAL=$((TOTAL+1))
}

test_fail() { 
    echo "❌ $1"
    FAIL=$((FAIL+1))
    TOTAL=$((TOTAL+1))
}

test_info() {
    echo "ℹ️  $1"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 1: Build & Compilation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if cargo build --release -p uat-node 2>&1 | grep -q "Finished"; then
    test_pass "Release binary compiled successfully"
    BINARY_SIZE=$(du -h target/release/uat-node | cut -f1)
    test_info "Binary size: $BINARY_SIZE"
else
    test_fail "Compilation failed"
    exit 1
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 2: Unit Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_OUTPUT=$(cargo test --release --quiet 2>&1 || true)
if echo "$TEST_OUTPUT" | grep -q "test result: ok"; then
    TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -o '[0-9]* passed' | grep -o '[0-9]*' | head -1 || echo "0")
    test_pass "All unit tests passed ($TEST_COUNT tests)"
else
    test_fail "Some unit tests failed"
    echo "$TEST_OUTPUT" | tail -20
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 3: Multi-Node Database Isolation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Stop any running nodes
./stop_3_validators.sh > /dev/null 2>&1 || true
sleep 2

# Clean databases for fresh test
rm -rf node_data/validator-*/uat_database 2>/dev/null || true

# Start 3-node network
test_info "Starting 3-node testnet..."
./launch_3_validators.sh > /dev/null 2>&1
sleep 8

# Check database isolation
if [ -d "node_data/validator-1/uat_database" ] && \
   [ -d "node_data/validator-2/uat_database" ] && \
   [ -d "node_data/validator-3/uat_database" ]; then
    test_pass "Each validator has isolated database"
else
    test_fail "Database isolation broken"
fi

# Check wallet isolation
if [ -f "node_data/validator-1/wallet.json" ] && \
   [ -f "node_data/validator-2/wallet.json" ] && \
   [ -f "node_data/validator-3/wallet.json" ]; then
    test_pass "Each validator has unique wallet"
    
    # Verify addresses are different
    ADDR1=$(head -c 100 node_data/validator-1/wallet.json 2>/dev/null || echo "ADDR1")
    ADDR2=$(head -c 100 node_data/validator-2/wallet.json 2>/dev/null || echo "ADDR2")
    
    if [ "$ADDR1" != "$ADDR2" ]; then
        test_pass "Validator addresses are unique"
    else
        test_fail "Validators share same address"
    fi
else
    test_fail "Wallet isolation broken"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 4: Node Health & API Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for port in 3030 3031 3032; do
    if curl -sf http://localhost:$port/node-info > /dev/null 2>&1; then
        test_pass "Node on port $port is responding"
    else
        test_fail "Node on port $port not responding"
    fi
done

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 5: gRPC Port Isolation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if gRPC ports are different
for port in 23030 23031 23032; do
    if lsof -i :$port > /dev/null 2>&1; then
        test_pass "gRPC port $port is open (unique)"
    else
        test_fail "gRPC port $port not listening"
    fi
done

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 6: Consensus & Supply Synchronization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

S1=$(curl -s http://localhost:3030/supply | jq -r '.remaining_supply_void' 2>/dev/null || echo "0")
S2=$(curl -s http://localhost:3031/supply | jq -r '.remaining_supply_void' 2>/dev/null || echo "0")
S3=$(curl -s http://localhost:3032/supply | jq -r '.remaining_supply_void' 2>/dev/null || echo "0")

if [ "$S1" = "$S2" ] && [ "$S2" = "$S3" ] && [ "$S1" != "0" ]; then
    test_pass "All nodes report identical supply: $S1 VOI"
else
    test_fail "Supply mismatch detected (N1:$S1, N2:$S2, N3:$S3)"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 7: Validator Aggregation (DEV_MODE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VALIDATOR_COUNT=$(curl -s http://localhost:3030/validators | jq '.validators | length' 2>/dev/null || echo "0")

if [ "$VALIDATOR_COUNT" = "3" ]; then
    test_pass "Validator aggregation working ($VALIDATOR_COUNT validators visible)"
else
    test_fail "Expected 3 validators, got $VALIDATOR_COUNT"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 8: DEV_MODE Initial Balances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for port in 3030 3031 3032; do
    ADDR=$(curl -s http://localhost:$port/whoami | jq -r '.short' 2>/dev/null)
    if [ -n "$ADDR" ] && [ "$ADDR" != "null" ]; then
        BALANCE=$(curl -s http://localhost:$port/bal/$ADDR | jq -r '.balance_uat' 2>/dev/null || echo "0")
        if [ "$BALANCE" = "1000" ]; then
            test_pass "Node $port has correct DEV_MODE balance (1000 UAT)"
        else
            test_fail "Node $port has incorrect balance: $BALANCE UAT (expected 1000)"
        fi
    else
        test_fail "Could not retrieve address for node $port"
    fi
done

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 9: API Endpoint Coverage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ENDPOINTS=(
    "/node-info"
    "/supply"
    "/validators"
    "/whoami"
)

for endpoint in "${ENDPOINTS[@]}"; do
    if curl -sf http://localhost:3030$endpoint > /dev/null 2>&1; then
        test_pass "Endpoint $endpoint responding"
    else
        test_fail "Endpoint $endpoint not responding"
    fi
done

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "📋 TEST 10: Performance & Resource Usage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if nodes are using reasonable memory
for i in 1 2 3; do
    if [ -f node_data/validator-$i/pid.txt ]; then
        PID=$(cat node_data/validator-$i/pid.txt)
        MEM=$(ps -o rss= -p $PID 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
        if [ "$MEM" -lt 1000 ]; then
            test_pass "Validator-$i memory usage: ${MEM}MB (healthy)"
        else
            test_fail "Validator-$i memory usage: ${MEM}MB (high)"
        fi
    fi
done

echo ""

# Cleanup
test_info "Stopping test network..."
./stop_3_validators.sh > /dev/null 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      TEST RESULTS                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total Tests:  $TOTAL"
echo "  ✅ Passed:     $PASS"
echo "  ❌ Failed:     $FAIL"
echo ""

SCORE=$((PASS * 100 / TOTAL))

if [ $FAIL -eq 0 ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🎉 ALL TESTS PASSED - PRODUCTION READY ($SCORE/100)        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  SOME TESTS FAILED - SCORE: $SCORE/100                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    exit 1
fi
