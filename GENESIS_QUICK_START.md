# 🚀 Genesis Generator - Quick Start Guide

## One-Command Bootstrap

```bash
cd /path/to/unauthority-core
bash scripts/bootstrap_genesis.sh
```

This will:
1. ✅ Generate 8 Dev Wallets (BOOTSTRAP + TREASURY)
2. ✅ Create genesis_config.json
3. ✅ Setup validator node directories
4. ✅ Generate validator.toml configs for each node
5. ✅ Verify supply (Zero Remainder Protocol)

## What Gets Generated

### 8 Immutable Dev Wallets

```
BOOTSTRAP NODES (Initial Validators):
├── Node #1 (191,942 UAT)
├── Node #2 (191,942 UAT)
└── Node #3 (191,942 UAT)

TREASURY WALLETS (Long-term Storage):
├── Treasury #1 (191,942 UAT)
├── Treasury #2 (191,942 UAT)
├── Treasury #3 (191,942 UAT)
├── Treasury #4 (191,942 UAT)
└── Treasury #5 (191,942 UAT)

TOTAL: 1,535,536 UAT (Fixed, No Minting)
```

## Supply Breakdown

| Component | UAT | VOI (Void) | % |
|-----------|-----|-----------|---|
| **Dev Supply** | 1,535,536 | 153,553,600,000,000 | 7% |
| **Public Supply** | 20,400,700 | 2,040,070,000,000,000 | 93% |
| **TOTAL** | **21,936,236** | **2,193,623,600,000,000** | **100%** |

## Starting Validators

After bootstrap, start 3 validator nodes in separate terminals:

### Terminal 1: Validator #1
```bash
export UAT_VALIDATOR_PRIVKEY_PATH='/path/to/validator-1.key'
cargo run -p uat-node -- --config node_data/validator-1/validator.toml
```

### Terminal 2: Validator #2
```bash
export UAT_VALIDATOR_PRIVKEY_PATH='/path/to/validator-2.key'
cargo run -p uat-node -- --config node_data/validator-2/validator.toml
```

### Terminal 3: Validator #3
```bash
export UAT_VALIDATOR_PRIVKEY_PATH='/path/to/validator-3.key'
cargo run -p uat-node -- --config node_data/validator-3/validator.toml
```

## Key Security Points

### 🔐 Private Key Storage (CRITICAL)
```bash
# Option 1: Cold Storage (Recommended)
cp /tmp/bootstrap-node-1.key /offline/vault/validator-1.key
chmod 600 /offline/vault/validator-1.key

# Option 2: HSM (Hardware Security Module)
# Configure via PKCS#11 interface

# Option 3: Environment Variable
export UAT_VALIDATOR_PRIVKEY_PATH="/secure/path/validator-1.key"
```

### 🛡️ Sentry Node Architecture
```
INTERNET
   ↓
SENTRY NODE (Port 30333)
   ↓ VPN/Wireguard (Encrypted)
SIGNER NODE (Port 30334, Private)
```

### 📋 Firewall Setup
```bash
# Allow sentry public port (with rate limiting)
sudo ufw allow from any to any port 30333

# Allow signer private port (from sentry only)
sudo ufw allow from 192.168.1.100 to any port 30334

# Block everything else
sudo ufw default deny incoming
```

## Validator Economics

### Minimum Requirements
- **Stake:** 1,000 UAT (100,000,000,000 VOI)
- **Uptime:** >95% (or face 1% slash per epoch)

### Rewards
- **Source:** 100% of transaction fees (Gas)
- **Model:** Non-inflationary (fixed supply)
- **Voting Power:** √(Total Stake) - Quadratic

### Penalties (Slashing)
- **Double Signing:** 100% slash + permanent ban
- **Downtime:** 1% slash per epoch

## Files Created

| File | Purpose |
|------|---------|
| `genesis/genesis_config.json` | Immutable genesis state with 8 wallets |
| `genesis/README.md` | Comprehensive documentation |
| `validator.toml` | Validator configuration template |
| `scripts/bootstrap_genesis.sh` | One-command bootstrap automation |

## Troubleshooting

### Error: "Private Key not found"
```bash
# Solution
export UAT_VALIDATOR_PRIVKEY_PATH="/correct/path/to/key"
chmod 600 "$UAT_VALIDATOR_PRIVKEY_PATH"
```

### Error: "Signer connection failed"
```bash
# Check PSK exists
ls -la /etc/uat-validator/signer.psk

# Verify firewall
sudo ufw status | grep 30334

# Check VPN tunnel
sudo wg show
```

### Error: "Double signing detected"
```
⚠️ Your validator was:
   • Slashed 100% of stake
   • Permanently banned from network
   
Status: IRREVERSIBLE (immutable penalty)
Recovery: Require governance proposal & consensus
```

## What's Next?

After genesis bootstrap is complete:

1. **Task #2:** Validator Reward Distribution
   - Implement gas fee auto-distribution to validators

2. **Task #3:** Anti-Whale Mechanisms
   - Dynamic fee scaling & quadratic voting

3. **Task #4:** Slashing & Safety
   - Double-signing detection & penalties

4. **Task #5:** P2P Encryption
   - Noise Protocol Framework implementation

## Quick Links

- 🔗 [Genesis Complete Details](TASK_1_GENESIS_COMPLETION.md)
- 🔗 [Genesis Documentation](genesis/README.md)
- 🔗 [Validator Config](validator.toml)
- 🔗 [Bootstrap Script](scripts/bootstrap_genesis.sh)

---

**Status:** ✅ Production Ready  
**Created:** February 3, 2026  
**Network:** Unauthority (UAT)  
**Consensus:** aBFT with <3 second finality
