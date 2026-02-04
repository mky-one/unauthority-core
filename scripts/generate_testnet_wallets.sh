#!/bin/bash
# TESTNET Genesis Generator
# Generate 11 test wallets dengan seed phrase yang bisa di-share
# WARNING: ONLY FOR TESTNET - NEVER USE IN PRODUCTION

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTNET_DIR="$PROJECT_ROOT/testnet-genesis"
OUTPUT_FILE="$TESTNET_DIR/testnet_wallets.json"
README_FILE="$TESTNET_DIR/README_TESTNET.md"

echo "🔧 TESTNET Genesis Generator"
echo "============================="
echo ""

# Create testnet directory
mkdir -p "$TESTNET_DIR"

# Pre-defined seed phrases for deterministic testnet wallets
# These are PUBLICLY KNOWN - NEVER USE IN PRODUCTION
SEED_PHRASES=(
  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"
  "test test test test test test test test test test test junk"
  "legal legal legal legal legal legal legal legal legal legal legal legal"
  "art art art art art art art art art art art art"
  "work work work work work work work work work work work work"
  "hello hello hello hello hello hello hello hello hello hello hello hello"
  "world world world world world world world world world world world world"
  "node node node node node node node node node node node alpha"
  "node node node node node node node node node node node bravo"
  "node node node node node node node node node node node charlie"
)

WALLET_LABELS=(
  "TESTNET_TREASURY_1"
  "TESTNET_TREASURY_2"
  "TESTNET_TREASURY_3"
  "TESTNET_TREASURY_4"
  "TESTNET_TREASURY_5"
  "TESTNET_TREASURY_6"
  "TESTNET_TREASURY_7"
  "TESTNET_TREASURY_8"
  "TESTNET_VALIDATOR_NODE_A"
  "TESTNET_VALIDATOR_NODE_B"
  "TESTNET_VALIDATOR_NODE_C"
)

# Generate wallets using Python script
echo "⚙️  Generating testnet wallets from deterministic seeds..."
python3 - <<'PYTHON_SCRIPT' "$OUTPUT_FILE" "${SEED_PHRASES[@]}"
import sys
import json
import hashlib
from mnemonic import Mnemonic
from nacl.signing import SigningKey
from nacl.encoding import HexEncoder

output_file = sys.argv[1]
seed_phrases = sys.argv[2:]

# BIP39 Mnemonic
mnemo = Mnemonic("english")

def bytes_to_hex(data):
    return data.hex()

def generate_wallet_from_seed(seed_phrase):
    # Derive seed from mnemonic
    seed = mnemo.to_seed(seed_phrase)
    
    # Use first 32 bytes as private key for Ed25519
    private_key_bytes = seed[:32]
    
    # Generate keypair
    signing_key = SigningKey(private_key_bytes)
    verify_key = signing_key.verify_key
    
    # Format keys
    private_key_hex = bytes_to_hex(private_key_bytes)
    public_key_hex = bytes_to_hex(verify_key.encode())
    
    # Generate UAT address (UAT + Base58(PublicKey))
    import base58
    address = "UAT" + base58.b58encode(verify_key.encode()).decode('utf-8')
    
    return {
        "seed_phrase": seed_phrase,
        "private_key": private_key_hex,
        "public_key": public_key_hex,
        "address": address
    }

wallets = []
for i, seed in enumerate(seed_phrases):
    print(f"  Generating wallet {i+1}/11...", file=sys.stderr)
    wallet = generate_wallet_from_seed(seed)
    wallet["index"] = i
    wallets.append(wallet)

# Save to JSON
with open(output_file, 'w') as f:
    json.dump(wallets, f, indent=2)

print(f"✅ Saved {len(wallets)} wallets to {output_file}", file=sys.stderr)
PYTHON_SCRIPT

# Check if Python script succeeded
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "❌ Failed to generate wallets. Installing required Python packages..."
    pip3 install mnemonic pynacl base58
    python3 - <<'PYTHON_RETRY' "$OUTPUT_FILE" "${SEED_PHRASES[@]}"
import sys
import json
import hashlib
from mnemonic import Mnemonic
from nacl.signing import SigningKey
from nacl.encoding import HexEncoder

output_file = sys.argv[1]
seed_phrases = sys.argv[2:]

mnemo = Mnemonic("english")

def bytes_to_hex(data):
    return data.hex()

def generate_wallet_from_seed(seed_phrase):
    seed = mnemo.to_seed(seed_phrase)
    private_key_bytes = seed[:32]
    signing_key = SigningKey(private_key_bytes)
    verify_key = signing_key.verify_key
    private_key_hex = bytes_to_hex(private_key_bytes)
    public_key_hex = bytes_to_hex(verify_key.encode())
    
    import base58
    address = "UAT" + base58.b58encode(verify_key.encode()).decode('utf-8')
    
    return {
        "seed_phrase": seed_phrase,
        "private_key": private_key_hex,
        "public_key": public_key_hex,
        "address": address
    }

wallets = []
for i, seed in enumerate(seed_phrases):
    print(f"  Generating wallet {i+1}/11...", file=sys.stderr)
    wallet = generate_wallet_from_seed(seed)
    wallet["index"] = i
    wallets.append(wallet)

with open(output_file, 'w') as f:
    json.dump(wallets, f, indent=2)

print(f"✅ Saved {len(wallets)} wallets to {output_file}", file=sys.stderr)
PYTHON_RETRY
fi

# Create README with wallet info
cat > "$README_FILE" <<'EOF'
# TESTNET WALLETS (PUBLIC - DO NOT USE IN PRODUCTION)

**⚠️ WARNING: These wallets are PUBLICLY KNOWN and should ONLY be used for testnet testing.**

## Why Testnet Wallets?

These pre-generated wallets allow developers to:
- Test wallet import functionality (private key + seed phrase)
- Test validator setup without risking real funds
- Share test funds across development team
- Debug blockchain features in safe environment

## Wallet List

### Treasury Wallets (for testing token distribution)

**TESTNET_TREASURY_1:**
- Seed Phrase: `abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about`
- Use: General testing wallet #1

**TESTNET_TREASURY_2:**
- Seed Phrase: `zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong`
- Use: General testing wallet #2

**TESTNET_TREASURY_3:**
- Seed Phrase: `test test test test test test test test test test test junk`
- Use: General testing wallet #3

**TESTNET_TREASURY_4:**
- Seed Phrase: `legal legal legal legal legal legal legal legal legal legal legal legal`
- Use: Smart contract testing

**TESTNET_TREASURY_5:**
- Seed Phrase: `art art art art art art art art art art art art`
- Use: NFT/token testing

**TESTNET_TREASURY_6:**
- Seed Phrase: `work work work work work work work work work work work work`
- Use: Transaction spam testing

**TESTNET_TREASURY_7:**
- Seed Phrase: `hello hello hello hello hello hello hello hello hello hello hello hello`
- Use: API integration testing

**TESTNET_TREASURY_8:**
- Seed Phrase: `world world world world world world world world world world world world`
- Use: Frontend wallet testing

### Validator Node Wallets (1,000 UAT stake each)

**TESTNET_VALIDATOR_NODE_A:**
- Seed Phrase: `node node node node node node node node node node node alpha`
- Stake: 1,000 UAT
- Use: Bootstrap validator #1

**TESTNET_VALIDATOR_NODE_B:**
- Seed Phrase: `node node node node node node node node node node node bravo`
- Stake: 1,000 UAT
- Use: Bootstrap validator #2

**TESTNET_VALIDATOR_NODE_C:**
- Seed Phrase: `node node node node node node node node node node node charlie`
- Stake: 1,000 UAT
- Use: Bootstrap validator #3

## How to Use

### Import in Unauthority Wallet (Frontend Wallet)
1. Open Unauthority Wallet app
2. Click "Import Existing Wallet"
3. Select "Seed Phrase (12 words)"
4. Paste one of the seed phrases above
5. Click "Import"

### Import in Validator Dashboard
1. Open Unauthority Validator app
2. Choose "Import Existing Keys"
3. Select "Seed Phrase (12 or 24 words)"
4. Paste validator seed phrase (e.g., `node node node node node node node node node node node alpha`)
5. Click "Import & Start Node"

### Get Private Key (for testing import private key feature)
All private keys are stored in `testnet_wallets.json`. You can copy private key directly from there.

Example usage in code:
```javascript
import wallets from './testnet-genesis/testnet_wallets.json';
const treasury1 = wallets[0]; // TESTNET_TREASURY_1
console.log('Address:', treasury1.address);
console.log('Private Key:', treasury1.private_key);
```

## Security Notice

🔒 **NEVER USE THESE WALLETS IN PRODUCTION/MAINNET**

These wallets are:
- ❌ Publicly documented in this repository
- ❌ Derived from well-known seed phrases
- ❌ Shared across all testnet users
- ✅ ONLY safe for testnet testing

For mainnet, ALWAYS:
- ✅ Generate fresh random wallet
- ✅ Store seed phrase securely offline
- ✅ Never share private keys
- ✅ Use hardware wallet for large amounts

## Testnet Genesis Configuration

These wallets are hardcoded into testnet genesis block:

| Wallet | Address | Initial Balance |
|--------|---------|-----------------|
| TREASURY_1 | UAT... | 2,000,000 UAT |
| TREASURY_2 | UAT... | 2,000,000 UAT |
| TREASURY_3 | UAT... | 2,000,000 UAT |
| TREASURY_4 | UAT... | 2,000,000 UAT |
| TREASURY_5 | UAT... | 2,000,000 UAT |
| TREASURY_6 | UAT... | 2,000,000 UAT |
| TREASURY_7 | UAT... | 2,000,000 UAT |
| TREASURY_8 | UAT... | 1,397,000 UAT |
| NODE_A | UAT... | 1,000 UAT (staked) |
| NODE_B | UAT... | 1,000 UAT (staked) |
| NODE_C | UAT... | 1,000 UAT (staked) |
| **TOTAL** | | **21,936,236 UAT** |

## Development Commands

```bash
# Generate testnet wallets
./scripts/generate_testnet_wallets.sh

# View all wallet details
cat testnet-genesis/testnet_wallets.json | jq

# Get specific wallet
cat testnet-genesis/testnet_wallets.json | jq '.[0]'  # Treasury 1

# Extract seed phrases only
cat testnet-genesis/testnet_wallets.json | jq -r '.[].seed_phrase'

# Deploy testnet with these wallets
./scripts/deploy_testnet.sh
```

## FAQ

**Q: Can I use these wallets for mainnet?**
A: NO! These are publicly known and will be compromised immediately.

**Q: What if someone drains testnet funds from these wallets?**
A: That's expected! Testnet can be reset anytime. Just re-deploy testnet.

**Q: How do I get more testnet UAT?**
A: Use the faucet in Unauthority Wallet (testnet mode) or send from treasury wallets.

**Q: Can I generate my own testnet wallet?**
A: Yes! Use "Generate New Wallet" in the app. But these pre-made ones are convenient for testing import features.

---

**Generated:** $(date)
**Network:** Testnet Only
**Security Level:** PUBLIC (Zero - For Testing Only)
EOF

echo ""
echo "✅ Testnet wallets generated successfully!"
echo ""
echo "📁 Files created:"
echo "   - $OUTPUT_FILE"
echo "   - $README_FILE"
echo ""
echo "📖 To view wallet details:"
echo "   cat $OUTPUT_FILE | jq"
echo ""
echo "⚠️  REMINDER: These are PUBLIC testnet wallets"
echo "   NEVER use in production!"
echo ""
