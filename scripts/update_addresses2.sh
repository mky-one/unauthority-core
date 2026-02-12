#!/bin/bash
# Direct replacement of old addresses in specific files
set -e
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core

# Address mapping
declare -A MAP
MAP["LOSWuWYfSNrUWxWL5sqCP5Sgj7bVtUdZQZdh8"]="LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8"
MAP["LOSWsEVHKVTuVU3puQRa7UeA6pS4qe7GtAfpg"]="LOSWoGEJEHwYA8am7sjspaPCDEQeyPFdzUu7e"
MAP["LOSWsy7qVzbxzRmmU3rHuefAZAycyiPtxBt6H"]="LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"
MAP["LOSWqvrydB9rNNMJZQjk62ae9ZGAPXzgThExR"]="LOSWxv2FpWd4eBTdap6Kt2sPrG8bcgyCyMP7L"
MAP["LOSX9BRWkb7BDESU66w16nD7vgUWg9CKeqivA"]="LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7"
MAP["LOSWuvgYXFhHbDwqVQrySGZ3KSbkrWJmANBJJ"]="LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf"
MAP["LOSX2QRrJ8f4hiu4LqknJcJB6zEsd31XJ4snn"]="LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"
MAP["LOSWs5d47nNq1ZKHehwG7R59JTambEYFNvy2TEXTRA"]="LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9EXTRA"
MAP["LOSWs5d47"]="LOSX48Jo"

# Old mainnet addresses
MAP["LOSX8sBoXqggW9xFA8w2nYJS6XQ15XuvFThEb"]="LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"
MAP["LOSWsxE6mzVKaMFriEmPJ4VEoFKYtaAppz1GU"]="LOSWxv2FpWd4eBTdap6Kt2sPrG8bcgyCyMP7L"
MAP["LOSWoWPeNNa2TZCMAxaC5EMTKg4Ws2htiv3Gk"]="LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7"
MAP["LOSXAJaUyAzaY5FE2xQqm2iNT72Q4NXKzMGc4"]="LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf"

# Files with old addresses (found by grep)
TARGET_FILES=(
    "check_fees.py"
    "debug_balances.py"
    "test_e2e_tor.py"
    "scripts/e2e_test_onion.sh"
    ".vscode/tasks.json"
    "docs/E2E_TEST_REPORT.md"
    "docs/E2E_TESTNET_BUG_REPORT.md"
    "docs/API_REFERENCE.md"
    "docs/WALLET_GUIDE.md"
    "docs/VALIDATOR_GUIDE.md"
    "docs/JOIN_TESTNET.md"
    "docs/WHITEPAPER.md"
    "testnet-genesis/SUMMARY_TABLE.txt"
    "setup_node_wallets.py"
)

for file in "${TARGET_FILES[@]}"; do
    if [ -f "$file" ]; then
        for old in "${!MAP[@]}"; do
            new="${MAP[$old]}"
            sed -i '' "s|$old|$new|g" "$file"
        done
        echo "✓ $file"
    fi
done

echo ""
echo "=== Final check ==="
REMAINING=$(grep -rn "LOSWuWYf\|LOSWsEVH\|LOSWsy7q\|LOSWqvry\|LOSX9BRW\|LOSWuvgY\|LOSX2QRr\|LOSWs5d4\|LOSX8sBo\|LOSWsxE6\|LOSWoWPe\|LOSXAJaU\|LOSWyovK\|LOSX3aJT\|LOSWyYAe\|LOSXA4x5\|LOSWrHse\|LOSWwUf5\|LOSX3Gex\|LOSWwgy3" \
    --include="*.py" --include="*.sh" --include="*.ts" --include="*.tsx" \
    --include="*.dart" --include="*.rs" --include="*.md" --include="*.html" \
    --include="*.json" --include="*.txt" --include="*.toml" \
    . 2>/dev/null | grep -v "node_data/" | grep -v "target/" | grep -v "build/" | grep -v "update_addresses" | wc -l | tr -d ' ')
echo "Remaining old addresses: $REMAINING"
if [ "$REMAINING" -gt 0 ]; then
    grep -rn "LOSWuWYf\|LOSWsEVH\|LOSWsy7q\|LOSWqvry\|LOSX9BRW\|LOSWuvgY\|LOSX2QRr\|LOSWs5d4\|LOSX8sBo\|LOSWsxE6\|LOSWoWPe\|LOSXAJaU\|LOSWyovK\|LOSX3aJT\|LOSWyYAe\|LOSXA4x5\|LOSWrHse\|LOSWwUf5\|LOSX3Gex\|LOSWwgy3" \
        --include="*.py" --include="*.sh" --include="*.ts" --include="*.tsx" \
        --include="*.dart" --include="*.rs" --include="*.md" --include="*.html" \
        --include="*.json" --include="*.txt" --include="*.toml" \
        . 2>/dev/null | grep -v "node_data/" | grep -v "target/" | grep -v "build/" | grep -v "update_addresses"
fi
