# 🔐 Unauthority (LOS) - Genesis Generator

## Overview

The Genesis Generator adalah tool untuk inisialisasi blockchain Unauthority dengan 8 Dev Wallets yang immutable. Sistem ini mengimplementasikan Zero Remainder Protocol untuk memastikan distribusi supply yang sempurna tanpa desimal error.

## Architecture

```
UNAUTHORITY GENESIS WALLETS (8 Total)
├── BOOTSTRAP NODES (3)
│   ├── Node #1 - Validator 1 (191,942 LOS)
│   ├── Node #2 - Validator 2 (191,942 LOS)
│   └── Node #3 - Validator 3 (191,942 LOS)
└── TREASURY (5)
    ├── Treasury #1 - Reserve (191,942 LOS)
    ├── Treasury #2 - Reserve (191,942 LOS)
    ├── Treasury #3 - Reserve (191,942 LOS)
    ├── Treasury #4 - Reserve (191,942 LOS)
    └── Treasury #5 - Reserve (191,942 LOS)

TOTAL: 1,535,536 LOS (Fixed Supply, No Minting)
```

## Supply Constants

| Parameter | Value | Void (CIL) |
|-----------|-------|-----------|
| **1 LOS** | = | 100,000,000 CIL |
| **Total Supply** | 21,936,236 LOS | 2,193,623,600,000,000 CIL |
| **Dev Allocation** | 1,535,536 LOS | 153,553,600,000,000 CIL |
| **Public Allocation** | 20,400,700 LOS | 2,040,070,000,000,000 CIL |
| **Per Wallet** | 191,942 LOS | 19,194,200,000,000 CIL |

## Running the Genesis Generator

```bash
# Build and run
cd /path/to/unauthority-core
cargo run -p genesis

# Output akan menampilkan:
# - 3 Bootstrap Node Addresses & Private Keys
# - 5 Treasury Addresses & Private Keys
# - Supply verification (Zero Remainder Check)
```

### Example Output

```
╔════════════════════════════════════════════════════════════╗
║   UNAUTHORITY (LOS) - GENESIS WALLET GENERATOR v5.0      ║
║   Generating 6 Wallets (2 Dev Treasury + 4 Bootstrap)    ║
╚════════════════════════════════════════════════════════════╝

📊 CONFIGURATION:
   • Total Supply: 21,936,236 LOS
   • Dev Treasury 1: 428,113 LOS
   • Dev Treasury 2: 245,710 LOS
   • Bootstrap Nodes: 4 × 1,000 LOS = 4,000 LOS
   • Total Dev: 677,823 LOS (~3%)
   • Public: 21,258,413 LOS (~97%)

┌─────────────────────────────────────────────────────────┐
│ 🔐 NODE BOOTSTRAP WALLETS (Initial Validators)          │
└─────────────────────────────────────────────────────────┘

   Type            : BOOTSTRAP NODE #1
   Address         : LOS3ea85825b3e13862274365118cafed2939fa8947
   Balance         : 19194200000000 CIL (191942 LOS)
   Private Key     : 40ad3e2f9a787e771da8112fa2af1448eb542175f5906adbd0b...
```

## Setup Instructions

### 1. Genesis Configuration

Use the generated addresses in `genesis/genesis_config.json`:

```json
{
  "bootstrap_nodes": [
    {
      "address": "LOS3ea85825b3e13862274365118cafed2939fa8947",
      "initial_stake_cil": 1000000000000,
      "role": "validator"
    },
    // ... 2 more
  ],
  "treasury_wallets": [
    {
      "address": "LOS25a18ce74482bb544847cc95aa3f4b42f02d8663",
      "balance_cil": 19194200000000
    },
    // ... 4 more
  ]
}
```

### 2. Validator Configuration

Use template `validator.toml` untuk setup validator node:

```toml
[validator]
address = "LOS3ea85825b3e13862274365118cafed2939fa8947"
private_key_path = "${LOS_VALIDATOR_PRIVKEY_PATH}"
stake_cil = 100000000000  # 1000 LOS minimum

[sentry_public]
listen_addr = "0.0.0.0"
listen_port = 30333
external_addr = "validator-node-1.ua1.network"

[signer_private]
listen_addr = "127.0.0.1"
listen_port = 30334
signer_endpoint = "127.0.0.1:30334"
```

### 3. Security Setup

**Step 1:** Generate Pre-Shared Key (PSK) untuk signer:
```bash
openssl rand -hex 32 > /etc/los-validator/signer.psk
chmod 600 /etc/los-validator/signer.psk
```

**Step 2:** Store Private Key securely:
```bash
# Option 1: Cold Storage (Recommended)
cp /tmp/los_privkey.txt /offline/storage/validator-1.key
chmod 600 /offline/storage/validator-1.key

# Option 2: HSM (Hardware Security Module)
# Load private key into HSM and reference via PKCS#11

# Option 3: Environment Variable
export LOS_VALIDATOR_PRIVKEY_PATH="/secure/location/validator-1.key"
chmod 600 "$LOS_VALIDATOR_PRIVKEY_PATH"
```

**Step 3:** Firewall Configuration
```bash
# Allow public sentry port (with rate limiting)
sudo ufw allow from any to any port 30333 proto tcp
sudo ufw allow from any to any port 30333 proto udp

# Allow private signer port (from sentry node only)
sudo ufw allow from 192.168.1.100 to any port 30334 proto tcp

# Block everything else
sudo ufw default deny incoming
```

## Key Features

### ✅ Zero Remainder Protocol
- 1,535,536 LOS ÷ 8 wallets = **191,942 LOS per wallet (exactly)**
- No floating-point errors
- Cryptographic verification of total supply

### ✅ Sentry Node Architecture
```
┌──────────────────────────────────────────────┐
│         INTERNET (Public P2P Network)        │
└────────────────────┬─────────────────────────┘
                     │
            ┌────────▼─────────┐
            │  SENTRY NODE     │
            │  (Public Shield) │
            │  Port 30333      │
            └────────┬─────────┘
                     │ VPN/Wireguard
                     │ Encrypted Tunnel
            ┌────────▼──────────────┐
            │  SIGNER NODE (Private)│
            │  (Validator Logic)    │
            │  Port 30334           │
            │  - Never Exposed      │
            └───────────────────────┘
```

### ✅ Dynamic Fee Scaling (Anti-Spam)
- Base gas: 1,000 CIL per transaction
- If address sends >10 tx/sec: gas × 2
- Multiple violations: gas × 4, × 8, etc.
- Burn limit per block: 1,000,000,000 CIL

### ✅ Validator Rewards
- 100% transaction fees go to block producer
- No new minting (Fixed Supply)
- Quadratic voting power: √(Total Stake)
- Minimum stake: 1,000 LOS

## Files Generated

| File | Purpose |
|------|---------|
| `genesis/genesis_config.json` | Immutable genesis state with all 8 addresses |
| `validator.toml` | Example validator configuration |
| Output Log | 8 wallet addresses & private keys (terminal only) |

## Security Considerations

### 🔴 CRITICAL

1. **Never commit private keys to Git**
   - Always use environment variables: `$LOS_VALIDATOR_PRIVKEY_PATH`
   - Store in cold storage or HSM only

2. **Sentry Node Architecture**
   - Public node should run in DMZ or separate VPC
   - Private signer should NOT be internet-facing
   - Use Noise Protocol Framework for encryption

3. **Double Signing Protection**
   - Validator cannot sign conflicting blocks
   - Violation = 100% stake slash + permanent ban
   - Automated by consensus layer

4. **Uptime Monitoring**
   - >95% uptime required to avoid slashing
   - 1% penalty per epoch of downtime
   - Monitor validator health continuously

## Keypair Generation

Genesis generator uses **Post-Quantum Ready** keypair derivation:

```rust
// Seed = SHA3(timestamp + label + random_data)
let seed = Keccak256(timestamp || label || random)

// Private Key = SHA3(seed || "private")
let priv_key = Keccak256(seed || "private")

// Public Key = SHA3(seed || "public")
let pub_key = Keccak256(seed || "public")

// Address = "LOS" + first_40_chars(Keccak256(pub_key))
let address = "LOS" + Keccak256(pub_key)[0:40]
```

**Quantum Safety:** Ready to migrate to CRYSTALS-Dilithium or FALCON at hardfork.

## Integration with Node

### Bootstrap Node Startup

```bash
# 1. Load genesis config
export LOS_GENESIS_CONFIG="./genesis/genesis_config.json"

# 2. Set validator private key
export LOS_VALIDATOR_PRIVKEY_PATH="/secure/validator-1.key"

# 3. Start node with sentry architecture
./los-node \
  --config validator.toml \
  --genesis "$LOS_GENESIS_CONFIG" \
  --role validator
```

### Signer Node Setup

```bash
# Run on secure/isolated machine
./uat-signer \
  --config validator.toml \
  --psk /etc/los-validator/signer.psk \
  --privkey "$LOS_VALIDATOR_PRIVKEY_PATH"
```

## Troubleshooting

### Issue: "Private Key not found"
```bash
# Solution: Set environment variable
export LOS_VALIDATOR_PRIVKEY_PATH="/path/to/key"
chmod 600 "$LOS_VALIDATOR_PRIVKEY_PATH"
```

### Issue: "Signer connection failed"
```bash
# Check PSK file exists and readable
ls -la /etc/los-validator/signer.psk

# Verify firewall allows port 30334
sudo ufw status | grep 30334

# Check Wireguard/VPN tunnel is active
sudo wg show  # if using WireGuard
```

### Issue: "Double signing detected"
```bash
# Your validator was slashed 100% stake
# You've been automatically banned from network
# Stake recovery: NOT POSSIBLE (immutable penalty)
# Action: Submit governance proposal for reinstatement (if consensus agrees)
```

## Next Steps

1. **Validator Reward Distribution Logic** - See `crates/los-node/src/validator_rewards.rs`
2. **Dynamic Fee Scaling Implementation** - See `crates/los-network/src/fee_scaling.rs`
3. **Quadratic Voting Mechanism** - See `crates/los-consensus/src/voting.rs`
4. **Slashing Implementation** - See `crates/los-consensus/src/slashing.rs`

---

**Genesis Generated:** 2026-02-03  
**Network:** Unauthority (LOS)  
**Consensus:** Asynchronous Byzantine Fault Tolerance (aBFT)  
**Supply Model:** Fixed (No Minting)
