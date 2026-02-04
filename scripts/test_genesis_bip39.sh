#!/bin/bash
# Test Genesis BIP39 Generation & Validator Onboarding

set -e

echo "========================================="
echo "GENESIS BIP39 INTEGRATION TEST"
echo "========================================="
echo ""

# Step 1: Generate Genesis
echo "Step 1: Generating Genesis with BIP39 Seed Phrases..."
cd genesis
cargo run --release > genesis_output.txt 2>&1
echo "✅ Genesis generated"
echo ""

# Step 2: Verify seed phrases in console output
echo "Step 2: Verifying seed phrase output..."
SEED_COUNT=$(grep "SEED PHRASE (24 words):" genesis_output.txt | wc -l | xargs)
if [ "$SEED_COUNT" -eq "11" ]; then
    echo "✅ Found 11 seed phrases in output"
else
    echo "❌ Expected 11 seed phrases, found $SEED_COUNT"
    exit 1
fi
echo ""

# Step 3: Verify seed phrases in JSON config
echo "Step 3: Verifying genesis_config.json..."
if [ -f "genesis_config.json" ]; then
    JSON_SEED_COUNT=$(cat genesis_config.json | grep -o "seed_phrase" | wc -l | xargs)
    if [ "$JSON_SEED_COUNT" -eq "11" ]; then
        echo "✅ Found 11 seed phrases in JSON config"
    else
        echo "❌ Expected 11 seed phrases in JSON, found $JSON_SEED_COUNT"
        exit 1
    fi
else
    echo "❌ genesis_config.json not found"
    exit 1
fi
echo ""

# Step 4: Extract bootstrap node seed phrases
echo "Step 4: Extracting Bootstrap Node Seed Phrases..."
echo ""
echo "BOOTSTRAP NODE SEED PHRASES:"
echo "=============================="
cat genesis_output.txt | grep -A 20 "BOOTSTRAP VALIDATOR NODES" | grep -A 2 "SEED PHRASE" | grep -v "SEED PHRASE" | grep -v "^--$" | head -3
echo ""

# Step 5: Show sample wallet for testing
echo "Step 5: Sample Bootstrap Wallet for Testing..."
echo ""
FIRST_BOOTSTRAP=$(cat genesis_config.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(data['bootstrap_nodes'][0]['address'])")
FIRST_SEED=$(cat genesis_config.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(data['bootstrap_nodes'][0]['seed_phrase'])")
echo "Address: $FIRST_BOOTSTRAP"
echo "Balance: 1000 UAT"
echo "Seed Phrase: $FIRST_SEED"
echo ""

# Step 6: Verify supply allocation
echo "Step 6: Verifying Supply Allocation..."
if grep -q "Status: MATCH" genesis_output.txt; then
    echo "✅ Supply verification passed"
else
    echo "❌ Supply verification failed"
    exit 1
fi
echo ""

# Step 7: Show next steps
echo "========================================="
echo "✅ ALL TESTS PASSED"
echo "========================================="
echo ""
echo "NEXT STEPS:"
echo "1. Start Validator Dashboard:"
echo "   cd ../frontend-validator && npm run dev"
echo ""
echo "2. Open Browser:"
echo "   http://localhost:5173"
echo ""
echo "3. Import Bootstrap Node:"
echo "   - Click 'Import Existing Keys'"
echo "   - Paste seed phrase from above"
echo "   - Set password"
echo "   - Start validator"
echo ""
echo "4. Verify Node Activation:"
echo "   - Check dashboard shows 1000 UAT balance"
echo "   - Node should become active validator"
echo "   - P2P connections established"
echo ""

# Cleanup
echo "Cleaning up test artifacts..."
rm -f genesis_output.txt
echo "✅ Test complete"
