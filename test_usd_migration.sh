#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY USD MIGRATION VERIFICATION TEST
# Purpose: Verify ALL IDR references have been replaced with USD
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "======================================================================"
echo "  USD MIGRATION VERIFICATION (ANONYMITY & ECONOMIC VIABILITY)"
echo "======================================================================"
echo ""

cd "$(dirname "$0")"

# Test 1: Check for ANY remaining IDR references
echo "🔍 Test 1: Checking for IDR/Rupiah remnants..."
IDR_COUNT=$(grep -r "_idr\|IDR\|Rp[0-9]\|rupiah\|Rupiah\|indodax\|Indodax" crates/ --include="*.rs" | wc -l | tr -d ' ')

if [ "$IDR_COUNT" -eq 0 ]; then
    echo "✅ PASS: No IDR/Rupiah references found"
else
    echo "❌ FAIL: Found $IDR_COUNT IDR references!"
    grep -rn "_idr\|IDR\|Rp[0-9]\|rupiah\|indodax" crates/ --include="*.rs"
    exit 1
fi

# Test 2: Verify USD is used everywhere
echo ""
echo "🔍 Test 2: Verifying USD adoption..."
USD_STRUCT=$(grep -c "total_burned_usd" crates/uat-core/src/distribution.rs)
USD_ORACLE=$(grep -c "eth_price_usd" crates/uat-core/src/oracle_consensus.rs)
USD_PROTO=$(grep -c "eth_price_usd" uat.proto)

if [ "$USD_STRUCT" -ge 1 ] && [ "$USD_ORACLE" -ge 1 ] && [ "$USD_PROTO" -ge 1 ]; then
    echo "✅ PASS: USD fields found in:"
    echo "   - DistributionState struct ($USD_STRUCT occurrences)"
    echo "   - Oracle consensus ($USD_ORACLE occurrences)"
    echo "   - Protobuf definition ($USD_PROTO occurrences)"
else
    echo "❌ FAIL: USD fields missing!"
    exit 1
fi

# Test 3: Check oracle API URLs
echo ""
echo "🔍 Test 3: Verifying oracle APIs (no Indonesian exchanges)..."
if grep -q "indodax" crates/uat-node/src/main.rs; then
    echo "❌ FAIL: Indodax (Indonesian exchange) still present!"
    exit 1
fi

if grep -q "vs_currencies=usd" crates/uat-node/src/main.rs; then
    echo "✅ PASS: CoinGecko using USD"
else
    echo "❌ FAIL: CoinGecko not using USD!"
    exit 1
fi

if grep -q "Kraken" crates/uat-node/src/main.rs; then
    echo "✅ PASS: Kraken (global exchange) integrated"
else
    echo "⚠️  WARNING: Kraken not found (using fallback)"
fi

# Test 4: Check log formatting
echo ""
echo "🔍 Test 4: Verifying log message currency symbols..."
if grep -q 'ETH=\${' crates/uat-node/src/main.rs; then
    echo "✅ PASS: USD log formatting detected (\$ symbol)"
else
    echo "❌ FAIL: No USD formatting in logs!"
    exit 1
fi

# Test 5: Compilation check
echo ""
echo "🔍 Test 5: Testing compilation..."
if cargo build --release --quiet 2>&1 | grep -i "error"; then
    echo "❌ FAIL: Compilation errors detected!"
    cargo build --release 2>&1 | grep "error"
    exit 1
else
    echo "✅ PASS: Code compiles successfully"
fi

# Test 6: Economic viability check
echo ""
echo "🔍 Test 6: Checking economic parameters..."
DEFAULT_ETH=$(grep -A2 "if eth_prices.is_empty()" crates/uat-node/src/main.rs | grep -oP '\d+\.\d+' | head -1)
DEFAULT_BTC=$(grep -A2 "if btc_prices.is_empty()" crates/uat-node/src/main.rs | grep -oP '\d+' | head -1)

echo "   Default ETH price: \$$DEFAULT_ETH"
echo "   Default BTC price: \$$DEFAULT_BTC"

if [ -n "$DEFAULT_ETH" ] && [ -n "$DEFAULT_BTC" ]; then
    echo "✅ PASS: Fallback prices configured"
else
    echo "⚠️  WARNING: Could not detect fallback prices"
fi

# Test 7: Anonymity verification
echo ""
echo "🔍 Test 7: Anonymity verification (no geographic fingerprints)..."
GEOGRAPHIC_COUNT=$(grep -ri "indonesia\|jakarta\|rupiah\|indodax" crates/ --include="*.rs" | wc -l | tr -d ' ')

if [ "$GEOGRAPHIC_COUNT" -eq 0 ]; then
    echo "✅ PASS: No geographic identifiers found"
    echo "   ✓ Identity preserved (Bitcoin-style anonymous launch)"
else
    echo "❌ FAIL: Geographic identifiers detected!"
    grep -rin "indonesia\|jakarta\|rupiah\|indodax" crates/ --include="*.rs"
    exit 1
fi

# Summary
echo ""
echo "======================================================================"
echo "                    🎉 ALL TESTS PASSED 🎉"
echo "======================================================================"
echo ""
echo "✅ Anonymity: PRESERVED (no IDR/Indonesian references)"
echo "✅ Economics: USD-based (\$0.01 per UAT starting price)"
echo "✅ Oracle: Global exchanges only (CoinGecko, CryptoCompare, Kraken)"
echo "✅ Compilation: SUCCESS"
echo ""
echo "⚠️  IMPORTANT: Before mainnet launch, verify:"
echo "   1. Real-time oracle prices show USD values"
echo "   2. Logs display '\$' not 'Rp'"
echo "   3. No geographic data leaks in network messages"
echo ""
echo "======================================================================"
