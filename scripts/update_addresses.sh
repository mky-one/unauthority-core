#!/bin/bash
# Replace all old testnet wallet addresses with new ones (new domain separator)
# Mapping: same BIP39 seeds → new Dilithium5 keypairs → new addresses

set -e
cd "$(dirname "$0")/.."

echo "=== Updating old wallet addresses ==="

# Testnet wallet address mapping (old → new)
# Dev Treasury #1
OLD_DEV1="LOSWuWYfSNrUWxWL5sqCP5Sgj7bVtUdZQZdh8"
NEW_DEV1="LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8"

# Dev Treasury #2
OLD_DEV2="LOSWsEVHKVTuVU3puQRa7UeA6pS4qe7GtAfpg"
NEW_DEV2="LOSWoGEJEHwYA8am7sjspaPCDEQeyPFdzUu7e"

# Bootstrap Validator #1 (V1)
OLD_BOOT1="LOSWsy7qVzbxzRmmU3rHuefAZAycyiPtxBt6H"
NEW_BOOT1="LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"

# Bootstrap Validator #2 (V2)
OLD_BOOT2="LOSWqvrydB9rNNMJZQjk62ae9ZGAPXzgThExR"
NEW_BOOT2="LOSWxv2FpWd4eBTdap6Kt2sPrG8bcgyCyMP7L"

# Bootstrap Validator #3 (V3)
OLD_BOOT3="LOSX9BRWkb7BDESU66w16nD7vgUWg9CKeqivA"
NEW_BOOT3="LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7"

# Bootstrap Validator #4 (V4)
OLD_BOOT4="LOSWuvgYXFhHbDwqVQrySGZ3KSbkrWJmANBJJ"
NEW_BOOT4="LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf"

# Test-only addresses (from scripts)
OLD_TEST1="LOSX2QRrJ8f4hiu4LqknJcJB6zEsd31XJ4snn"
NEW_TEST1="$NEW_BOOT1"

# Invalid address test (contains EXTRA suffix)
OLD_INVALID="LOSWs5d47nNq1ZKHehwG7R59JTambEYFNvy2TEXTRA"
NEW_INVALID="${NEW_BOOT1}EXTRA"

# Doc example truncated addresses
OLD_DOC1="LOSWs5d47"
NEW_DOC1="LOSX48Jo"

# Old mainnet addresses (in case any remain outside genesis_config.json)
OLD_MN_B1="LOSX8sBoXqggW9xFA8w2nYJS6XQ15XuvFThEb"
OLD_MN_B2="LOSWsxE6mzVKaMFriEmPJ4VEoFKYtaAppz1GU"
OLD_MN_B3="LOSWoWPeNNa2TZCMAxaC5EMTKg4Ws2htiv3Gk"
OLD_MN_B4="LOSXAJaUyAzaY5FE2xQqm2iNT72Q4NXKzMGc4"
OLD_MN_D1="LOSWyovKUDm8cJNbK6C8fXZT9sPA3yH18sAsz"
OLD_MN_D2="LOSX3aJTBF2xfWQx2xXBrPBjDEeFtCKrCnjH6"
OLD_MN_D3="LOSWyYAer65mMmceEffswbFBdfXDRpbtHYTau"
OLD_MN_D4="LOSXA4x5x3D45XZ1LxkMj3GKbuHsZetdTq7vH"
OLD_MN_D5="LOSWrHseJSUYNYnXNgd2faWf5X1n9kytv9eMy"
OLD_MN_D6="LOSWwUf5QRJsP2japspzRxdBAWrnDwiai9JFv"
OLD_MN_D7="LOSX3Gex3UWepLuy5JzDKeY6GgsVevKc6k5Za"
OLD_MN_D8="LOSWwgy3kbh2KuVNSMqWx7f2x38wJQ4Jys7yU"

# Find all source files (exclude generated dirs)
FILES=$(find . \( -name "*.py" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" \
    -o -name "*.dart" -o -name "*.rs" -o -name "*.md" -o -name "*.html" \
    -o -name "*.json" -o -name "*.txt" -o -name "*.toml" \) \
    -not -path "*/node_data/*" \
    -not -path "*/target/*" \
    -not -path "*/build/*" \
    -not -path "*/.git/*" \
    -not -path "*/scripts/update_addresses.sh")

echo "Processing files..."

# Replace in order: longest/most specific first to avoid partial matches
echo "$FILES" | xargs sed -i '' \
    -e "s|$OLD_INVALID|$NEW_INVALID|g" \
    -e "s|$OLD_DEV1|$NEW_DEV1|g" \
    -e "s|$OLD_DEV2|$NEW_DEV2|g" \
    -e "s|$OLD_BOOT1|$NEW_BOOT1|g" \
    -e "s|$OLD_BOOT2|$NEW_BOOT2|g" \
    -e "s|$OLD_BOOT3|$NEW_BOOT3|g" \
    -e "s|$OLD_BOOT4|$NEW_BOOT4|g" \
    -e "s|$OLD_TEST1|$NEW_TEST1|g" \
    -e "s|$OLD_DOC1|$NEW_DOC1|g" \
    -e "s|$OLD_MN_B1|$NEW_BOOT1|g" \
    -e "s|$OLD_MN_B2|$NEW_BOOT2|g" \
    -e "s|$OLD_MN_B3|$NEW_BOOT3|g" \
    -e "s|$OLD_MN_B4|$NEW_BOOT4|g" \
    -e "s|$OLD_MN_D1|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D2|$NEW_DEV2|g" \
    -e "s|$OLD_MN_D3|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D4|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D5|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D6|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D7|$NEW_DEV1|g" \
    -e "s|$OLD_MN_D8|$NEW_DEV1|g" \
    2>/dev/null || true

echo "Done replacing addresses."

# Verify
echo ""
echo "=== Verification ==="
REMAINING=$(grep -rn "LOSWuWYf\|LOSWsEVH\|LOSWsy7q\|LOSWqvry\|LOSX9BRW\|LOSWuvgY\|LOSX2QRr\|LOSWs5d4\|LOSX8sBo\|LOSWsxE6\|LOSWoWPe\|LOSXAJaU\|LOSWyovK\|LOSX3aJT\|LOSWyYAe\|LOSXA4x5\|LOSWrHse\|LOSWwUf5\|LOSX3Gex\|LOSWwgy3" \
    --include="*.py" --include="*.sh" --include="*.ts" --include="*.tsx" \
    --include="*.dart" --include="*.rs" --include="*.md" --include="*.html" \
    --include="*.json" --include="*.txt" --include="*.toml" \
    . 2>/dev/null | grep -v "node_data/" | grep -v "target/" | grep -v "build/" | grep -v "update_addresses.sh" | wc -l | tr -d ' ')

echo "Remaining old addresses: $REMAINING"

if [ "$REMAINING" -gt 0 ]; then
    echo "Files with remaining old addresses:"
    grep -rn "LOSWuWYf\|LOSWsEVH\|LOSWsy7q\|LOSWqvry\|LOSX9BRW\|LOSWuvgY\|LOSX2QRr\|LOSWs5d4\|LOSX8sBo\|LOSWsxE6\|LOSWoWPe\|LOSXAJaU\|LOSWyovK\|LOSX3aJT\|LOSWyYAe\|LOSXA4x5\|LOSWrHse\|LOSWwUf5\|LOSX3Gex\|LOSWwgy3" \
        --include="*.py" --include="*.sh" --include="*.ts" --include="*.tsx" \
        --include="*.dart" --include="*.rs" --include="*.md" --include="*.html" \
        --include="*.json" --include="*.txt" --include="*.toml" \
        . 2>/dev/null | grep -v "node_data/" | grep -v "target/" | grep -v "build/" | grep -v "update_addresses.sh"
fi
