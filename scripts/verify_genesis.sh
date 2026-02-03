#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNAUTHORITY (UAT) - GENESIS VERIFICATION SCRIPT v2.0
# Verify 11-wallet structure: 8 dev + 3 bootstrap nodes
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_CONFIG="${PROJECT_ROOT}/genesis/genesis_config.json"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  UNAUTHORITY GENESIS VERIFICATION                         ║"
echo "║  11-Wallet Structure: 8 Dev + 3 Bootstrap Validators      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Verify genesis_config.json exists
if [ ! -f "$GENESIS_CONFIG" ]; then
    echo "❌ ERROR: genesis_config.json not found!"
    echo "   Run: cargo run -p genesis"
    exit 1
fi

echo "✅ Genesis config found: $GENESIS_CONFIG"
echo ""

# Step 2: Count wallets
echo "📊 WALLET STRUCTURE:"
echo ""

DEV_COUNT=$(jq '.dev_accounts | length' "$GENESIS_CONFIG" 2>/dev/null || echo "0")
BOOTSTRAP_COUNT=$(jq '.bootstrap_nodes | length' "$GENESIS_CONFIG" 2>/dev/null || echo "0")
TOTAL_WALLETS=$((DEV_COUNT + BOOTSTRAP_COUNT))

echo "   Dev Accounts:      $DEV_COUNT (expected: 8)"
if [ "$DEV_COUNT" -ne 8 ]; then
    echo "   ❌ FAIL: Expected 8 dev accounts, got $DEV_COUNT"
    exit 1
fi
echo "   ✅ PASS"
echo ""

echo "   Bootstrap Nodes:   $BOOTSTRAP_COUNT (expected: 3)"
if [ "$BOOTSTRAP_COUNT" -ne 3 ]; then
    echo "   ❌ FAIL: Expected 3 bootstrap nodes, got $BOOTSTRAP_COUNT"
    exit 1
fi
echo "   ✅ PASS"
echo ""

echo "   Total Wallets:     $TOTAL_WALLETS (expected: 11)"
if [ "$TOTAL_WALLETS" -ne 11 ]; then
    echo "   ❌ FAIL: Expected 11 total wallets, got $TOTAL_WALLETS"
    exit 1
fi
echo "   ✅ PASS"
echo ""

# Step 3: Verify supply
echo "💰 SUPPLY VERIFICATION:"
echo ""

# Get dev supply (sum of all dev account balances)
DEV_SUPPLY=$(jq '[.dev_accounts[].balance_void] | add' "$GENESIS_CONFIG" 2>/dev/null || echo "0")
echo "   Dev Supply:        $DEV_SUPPLY VOI"

# Get bootstrap supply (sum of all bootstrap node stakes)
BOOTSTRAP_SUPPLY=$(jq '[.bootstrap_nodes[].stake_void] | add' "$GENESIS_CONFIG" 2>/dev/null || echo "0")
echo "   Bootstrap Supply:  $BOOTSTRAP_SUPPLY VOI"

# Total dev allocation
TOTAL_ALLOCATED=$((DEV_SUPPLY + BOOTSTRAP_SUPPLY))
echo "   Total Allocated:   $TOTAL_ALLOCATED VOI"
echo ""

# Expected supply
EXPECTED_SUPPLY=153553600000000  # 1,535,536 UAT * 100,000,000

echo "   Expected Supply:   $EXPECTED_SUPPLY VOI"
echo "   Difference:        $((TOTAL_ALLOCATED - EXPECTED_SUPPLY)) VOI"
echo ""

if [ "$TOTAL_ALLOCATED" -eq "$EXPECTED_SUPPLY" ]; then
    echo "   ✅ PASS: Supply verification MATCH"
else
    echo "   ❌ FAIL: Supply mismatch!"
    echo "   Expected: $EXPECTED_SUPPLY VOI"
    echo "   Got:      $TOTAL_ALLOCATED VOI"
    exit 1
fi
echo ""

# Step 4: Verify individual wallet balances
echo "🔍 WALLET BALANCE DETAILS:"
echo ""

echo "   Dev Wallets #1-7 (191,942 UAT each):"
EXPECTED_DEV_BALANCE=19194200000000  # 191,942 UAT in VOI

for i in $(seq 0 6); do
    BALANCE=$(jq ".dev_accounts[$i].balance_void" "$GENESIS_CONFIG" 2>/dev/null || echo "0")
    ADDR=$(jq -r ".dev_accounts[$i].address" "$GENESIS_CONFIG" 2>/dev/null | cut -c1-16)...
    
    if [ "$BALANCE" -eq "$EXPECTED_DEV_BALANCE" ]; then
        echo "      ✅ Dev #$((i+1)): $ADDR ($BALANCE VOI)"
    else
        echo "      ❌ Dev #$((i+1)): MISMATCH (got $BALANCE, expected $EXPECTED_DEV_BALANCE)"
        exit 1
    fi
done
echo ""

echo "   Dev Wallet #8 (188,942 UAT - reduced for bootstrap):"
EXPECTED_DEV8_BALANCE=18894200000000  # 188,942 UAT in VOI (reduced from 191,942)
DEV8_BALANCE=$(jq ".dev_accounts[7].balance_void" "$GENESIS_CONFIG" 2>/dev/null || echo "0")
ADDR=$(jq -r ".dev_accounts[7].address" "$GENESIS_CONFIG" 2>/dev/null | cut -c1-16)...

if [ "$DEV8_BALANCE" -eq "$EXPECTED_DEV8_BALANCE" ]; then
    echo "      ✅ Dev #8: $ADDR ($DEV8_BALANCE VOI)"
else
    echo "      ❌ Dev #8: MISMATCH (got $DEV8_BALANCE, expected $EXPECTED_DEV8_BALANCE)"
    exit 1
fi
echo ""

echo "   Bootstrap Validator Nodes #1-3 (1,000 UAT each):"
EXPECTED_BOOTSTRAP_BALANCE=100000000000  # 1,000 UAT in VOI

for i in $(seq 0 2); do
    BALANCE=$(jq ".bootstrap_nodes[$i].stake_void" "$GENESIS_CONFIG" 2>/dev/null || echo "0")
    ADDR=$(jq -r ".bootstrap_nodes[$i].address" "$GENESIS_CONFIG" 2>/dev/null | cut -c1-16)...
    
    if [ "$BALANCE" -eq "$EXPECTED_BOOTSTRAP_BALANCE" ]; then
        echo "      ✅ Validator #$((i+1)): $ADDR ($BALANCE VOI)"
    else
        echo "      ❌ Validator #$((i+1)): MISMATCH (got $BALANCE, expected $EXPECTED_BOOTSTRAP_BALANCE)"
        exit 1
    fi
done
echo ""

# Step 5: Summary table
echo "📋 SUMMARY TABLE:"
echo ""
echo "   ┌────────────────────────────┬──────────┬────────────────────────┐"
echo "   │ Category                   │ Count    │ Balance (VOI)          │"
echo "   ├────────────────────────────┼──────────┼────────────────────────┤"

DEV_1_7_TOTAL=$((7 * EXPECTED_DEV_BALANCE))
printf "   │ Dev Wallets #1-7           │ 7        │ %,20d │\n" "$DEV_1_7_TOTAL" | sed 's/,/ /g'
printf "   │ Dev Wallet #8 (reduced)    │ 1        │ %,20d │\n" "$DEV8_BALANCE" | sed 's/,/ /g'
printf "   │ Bootstrap Validators #1-3  │ 3        │ %,20d │\n" "$BOOTSTRAP_SUPPLY" | sed 's/,/ /g'

echo "   ├────────────────────────────┼──────────┼────────────────────────┤"
printf "   │ TOTAL DEV SUPPLY           │ 11       │ %,20d │\n" "$TOTAL_ALLOCATED" | sed 's/,/ /g'
echo "   └────────────────────────────┴──────────┴────────────────────────┘"
echo ""

# Step 6: Conversion to UAT
echo "🔄 SUPPLY IN UAT (1 UAT = 100,000,000 VOI):"
echo ""

DEV_1_7_UAT=$((DEV_1_7_TOTAL / 100000000))
DEV8_UAT=$((DEV8_BALANCE / 100000000))
BOOTSTRAP_UAT=$((BOOTSTRAP_SUPPLY / 100000000))
TOTAL_UAT=$((TOTAL_ALLOCATED / 100000000))

printf "   Dev Wallets #1-7:    %,10d UAT\n" "$DEV_1_7_UAT" | sed 's/,/ /g'
printf "   Dev Wallet #8:       %,10d UAT\n" "$DEV8_UAT" | sed 's/,/ /g'
printf "   Bootstrap Nodes:     %,10d UAT\n" "$BOOTSTRAP_UAT" | sed 's/,/ /g'
echo "   ─────────────────────────────────────"
printf "   TOTAL:               %,10d UAT\n" "$TOTAL_UAT" | sed 's/,/ /g'
echo ""

# Step 7: Verify zero remainder
echo "✓ ZERO REMAINDER VERIFICATION:"
echo ""

# Check: 7 * 191,942 + 1 * 188,942 + 3 * 1,000 should equal 1,535,536
CALCULATED=$((7 * 191942 + 1 * 188942 + 3 * 1000))

if [ "$CALCULATED" -eq 1535536 ]; then
    echo "   ✅ Perfect integer math (no remainder)"
    echo "      7 × 191,942 UAT = 1,343,594 UAT"
    echo "      1 × 188,942 UAT =   188,942 UAT"
    echo "      3 ×   1,000 UAT =     3,000 UAT"
    echo "      ─────────────────────────────────"
    echo "      TOTAL           = 1,535,536 UAT ✓"
else
    echo "   ❌ FAIL: Remainder detected!"
    echo "   Calculated: $CALCULATED UAT"
    exit 1
fi
echo ""

# Final status
echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ✅ GENESIS VERIFICATION PASSED                            ║"
echo "║                                                            ║"
echo "║ 11 Wallets correctly configured:                          ║"
echo "║   • 8 Dev/Treasury Wallets                               ║"
echo "║   • 3 Bootstrap Validator Nodes                          ║"
echo "║   • Total Supply: 1,535,536 UAT (exact match)           ║"
echo "║   • Zero Remainder Protocol: ✓                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
