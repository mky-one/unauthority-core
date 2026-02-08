# 🏛️ Validator Guide - Become a UAT Validator

**How to participate in Unauthority network consensus and earn gas fees**

---

## 🎯 Overview

Unauthority is a **permissionless blockchain** - anyone can become a validator without registration, KYC, or whitelist approval. Simply stake 1,000 UAT and run a validator node.

### **What is a Validator?**

Validators are network participants who:
- ✅ Propose and vote on new blocks
- ✅ Participate in aBFT consensus
- ✅ Earn 100% of gas fees (proportional to voting power)
- ✅ Secure the network through economic stake

### **Requirements**

| Requirement | Details |
|-------------|---------|
| **Minimum Stake** | 1,000 UAT (auto-detected by network) |
| **Hardware** | Standard laptop/desktop (2GB RAM, 50GB disk) |
| **Network** | Stable internet connection (Tor-compatible) |
| **Uptime** | 24/7 recommended (maximize earnings) |
| **Registration** | None required (permissionless!) |

---

## 🚀 Quick Start: Become a Validator

### **Step 1: Acquire UAT via Proof-of-Burn**

Burn ETH or BTC to receive UAT at dynamic market rate:

```bash
# Option A: Via Flutter Wallet (GUI)
1. Open flutter_wallet
2. Go to "Burn" tab
3. Select ETH or BTC
4. Enter amount to burn
5. Confirm transaction
6. Receive UAT (usually within 10 minutes)

# Option B: Via API (Advanced)
curl -X POST https://testnet.unauthority.network/burn \
  -H "Content-Type: application/json" \
  -d '{
    "coin_type": "eth",
    "burn_tx_hash": "0xYOUR_ETH_BURN_TX",
    "uat_address": "UATYOUR_ADDRESS_HERE",
    "signature": "YOUR_DILITHIUM_SIGNATURE"
  }'
```

**Burn Addresses** (verifiable on-chain):
- **ETH**: `0x000000000000000000000000000000000000dEaD` (standard burn address)
- **BTC**: `1BitcoinEaterAddressDontSendf59kuE` (provably unspendable)

**Bonding Curve Pricing**:
- Initial: 1 UAT ≈ 0.0001 ETH (dynamic based on supply)
- Updates every block based on remaining public allocation
- Check current rate: `GET /burn/rate`

**Minimum Burn**: Acquire at least **1,000 UAT** to qualify as validator

---

### **Step 2: Setup Validator Node**

#### **Option A: Flutter Validator Dashboard** (Easiest)

```bash
# Download pre-built release
# macOS: Download DMG from GitHub releases
# Windows: Download ZIP from GitHub releases
# Linux: Download tar.gz from GitHub releases

# Or build from source:
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core/flutter_validator

flutter pub get
flutter build macos --release  # or windows/linux
```

**First Run Setup**:
1. Launch flutter_validator app
2. Import wallet seed phrase (24 words)
3. App will automatically:
   - Detect balance ≥ 1,000 UAT
   - Start validator node (uat-node binary)
   - Connect to network (Tor or clearnet)
   - Begin consensus participation

#### **Option B: Command Line** (Advanced)

```bash
# Build validator node
cargo build --release -p uat-node

# Create validator wallet (or import existing)
./target/release/uat-node generate-wallet \
  --output node_data/my-validator/wallet.json

# IMPORTANT: Save seed phrase securely!

# Start validator node
./target/release/uat-node \
  --port 3030 \
  --api-port 3030 \
  --ws-port 9030 \
  --wallet node_data/my-validator/wallet.json \
  --validator-mode

# Check validator status
curl http://localhost:3030/node-info
# {"node_id":"UAT...","validator":true,"stake":1000000000000000,...}
```

---

### **Step 3: Verify Validator Status**

Your validator is active when all checks pass:

```bash
# 1. Check balance ≥ 1,000 UAT
curl https://testnet.unauthority.network/balance/YOUR_UAT_ADDRESS
# {"balance_uat":1500,"balance_void":150000000000000}

# 2. Check validator list
curl https://testnet.unauthority.network/validators
# [{"address":"YOUR_UAT_ADDRESS","stake":1500,"voting_power":38.73,...}]

# 3. Check node health
curl http://localhost:3030/health
# {"status":"healthy","validator_mode":true,"participating":true}

# 4. Monitor consensus participation
curl http://localhost:3030/node-info | jq '.consensus'
# {"blocks_proposed":12,"votes_cast":3456,"uptime_pct":99.8}
```

**Troubleshooting**:
- ❌ Not in validator list → Check balance ≥ 1,000 UAT
- ❌ Not proposing blocks → Check network connectivity (peers > 0)
- ❌ Not earning fees → Check uptime and consensus participation

---

## 💰 Validator Economics

### **Revenue Model**

**Gas Fee Distribution**: 100% to validators (no burn, no treasury)

**Voting Power**: Quadratic function to prevent whale dominance
```
voting_power = √(total_stake)

Examples:
- Stake 1,000 UAT → Voting power = 31.62
- Stake 10,000 UAT → Voting power = 100.00 (not 10x, just 3.16x!)
- Stake 100,000 UAT → Voting power = 316.23 (not 100x, just 10x!)
```

**Revenue Share**: Proportional to voting power
```
your_share = your_voting_power / total_voting_power_of_all_validators

Example network:
- 100 validators, average stake 5,000 UAT each
- Total voting power: 100 * √5000 = 7,071 votes
- Your stake: 10,000 UAT → Your voting power: 100 votes
- Your share: 100 / 7,071 = 1.41% of all gas fees
```

**Typical Earnings** (estimates, actual varies by network activity):
```
Assumption:
- Network: 100 validators
- Your stake: 10,000 UAT (voting power: 100, ~1.4% share)
- Average gas fee: 0.01 UAT per transaction
- Network throughput: 1,000 tx/day

Daily earnings:
- Total fees: 1000 tx × 0.01 UAT = 10 UAT/day
- Your share: 10 × 1.41% = 0.141 UAT/day

Annual earnings:
- 0.141 UAT/day × 365 days = 51.47 UAT/year
- ROI: 51.47 / 10,000 = 0.51% APY

⚠️ Note: APY decreases as more validators join (more competition)
Early validators earn higher % until network saturates
```

---

## 🌐 Network Lifecycle: Bootstrap → Decentralized

### **Phase 1: Genesis (Day 1)**

**Network Status**: 4 bootstrap validators (dev-operated)

| Validator | Stake | Operator |
|-----------|-------|----------|
| Bootstrap #1 | 1,000 UAT | Core dev |
| Bootstrap #2 | 1,000 UAT | Core dev |
| Bootstrap #3 | 1,000 UAT | Core dev |
| Bootstrap #4 | 1,000 UAT | Core dev |
| **Total** | **4,000 UAT** | **Centralized (temporary!)** |

**Status**: 🔴 **CENTRALIZED** (bootstrap nodes must be online 24/7)  
**Risk**: Network freezes if <3 bootstrap nodes online (67% aBFT threshold)

---

### **Phase 2: Early Growth (Month 1-3)**

**Network Status**: Bootstrap + Early public validators

| Validator Type | Count | Total Stake |
|----------------|-------|-------------|
| Bootstrap | 4 | 4,000 UAT |
| Public | 10-20 | 15,000-30,000 UAT |
| **Total** | **14-24** | **19,000-34,000 UAT** |

**Status**: 🟡 **SEMI-DECENTRALIZED** (bootstrap still critical but network more resilient)  
**Recommendation**: Bootstrap nodes should maintain 24/7 uptime  
**Public Impact**: Early validators earn higher gas fee %, attract more participants

---

### **Phase 3: Mature Network (Month 6+)**

**Network Status**: Highly decentralized with diverse validators

| Validator Type | Count | Total Stake |
|----------------|-------|-------------|
| Bootstrap | 4 | 4,000 UAT |
| Public | 50-100+ | 100,000-500,000+ UAT |
| **Total** | **54-104+** | **104,000-504,000+ UAT** |

**Status**: 🟢 **FULLY DECENTRALIZED** (bootstrap nodes are optional!)  
**Bootstrap Mode**: Can go offline for maintenance without network disruption  
**Consensus**: 67% of 54 validators = 37 validators needed (bootstrap = 4, public = 50+)

**Example Calculation**:
```
Total validators: 54 (4 bootstrap + 50 public)
Consensus threshold: 54 × 67% = 37 validators needed

Scenario: All 4 bootstrap nodes go offline
- Remaining validators: 50 public validators
- 50 > 37 → ✅ Network continues operating normally!

Conclusion: Bootstrap nodes NO LONGER CRITICAL after 50+ public validators
```

---

### **Phase 4: Long-term (Year 1+)**

**Network Status**: Thousands of validators worldwide

| Metric | Value |
|--------|-------|
| Total Validators | 500-5,000+ |
| Bootstrap Nodes | Optional (can be deprecated) |
| Geographic Distribution | Global (Tor anonymity) |
| Decentralization Index | 99%+ (measured by voting power distribution) |

**Bootstrap Evolution**:
- Option A: Bootstrap nodes continue as regular validators (no special privilege)
- Option B: Bootstrap nodes shut down (network fully independent)
- Option C: Bootstrap nodes become "archive nodes" (historical data only)

**Permissionless Reality**: Anyone can join/leave at any time, network self-sustains

---

## 📊 Validator Dashboard (Flutter App)

### **Key Metrics Displayed**

**1. Validator Status**
- ✅ Active / ❌ Inactive
- Stake amount (UAT)
- Voting power (calculated)
- Network share (%)

**2. Earnings**
- Total earned (lifetime)
- Last 24 hours
- Average per block
- Projected APY

**3. Network Participation**
- Blocks proposed (count)
- Votes cast (count)
- Uptime percentage
- Missed blocks (if any)

**4. Network Health**
- Connected peers (count)
- Total validators
- Your ranking (by voting power)
- Network throughput (TPS)

---

## 🛡️ Validator Security

### **1. Wallet Security** (CRITICAL)

**DO**:
- ✅ Store seed phrase offline (paper backup)
- ✅ Encrypt wallet.json file
- ✅ Use strong passwords
- ✅ Regular backups

**DON'T**:
- ❌ Share seed phrase with anyone
- ❌ Store seed in cloud/email
- ❌ Reuse seed across multiple chains
- ❌ Screenshot seed phrase

**Consequence**: Lost seed = lost validator stake (1,000+ UAT!)

---

### **2. Node Security**

**Recommended Setup**:
```
Public Internet
     ↓
[Firewall] 
     ↓
[Sentry Node] ← Public-facing (takes DDoS hits)
     ↓ VPN/Private Network
[Validator Node] ← Private IP, hidden from public
```

**Simple Setup** (current, single-node):
```
Public Internet (Tor)
     ↓
[Validator Node] ← Exposed to DDoS risk
```

**⚠️ TODO Feature**: Sentry node architecture (coming in Level 2 testnet)

---

### **3. Slashing Risks** (Coming Soon)

**Penalties** (NOT YET IMPLEMENTED):

| Offense | Penalty | Status |
|---------|---------|--------|
| **Double Signing** | 100% stake slashed + permanent ban | ⚠️ TODO |
| **Extended Downtime** | 1% per day (after 6h grace period) | ⚠️ TODO |
| **Invalid Blocks** | Warning (3 strikes = temp ban) | ⚠️ TODO |

**Current Status**: 🟢 No slashing in testnet (safe to test)  
**Mainnet Plan**: Full slashing enforcement (validator accountability)

**Protection**:
- Run reliable hardware (no crashes)
- Monitor uptime (set alerts)
- Never run same validator on multiple machines (double signing risk!)
- Regular backups (but never duplicate live validators)

---

## 🔧 Advanced Configuration

### **Validator Settings** (`validator.toml`)

```toml
[validator]
# Validator mode (required)
enabled = true

# Minimum stake to participate (auto-detected)
min_stake_uat = 1000

# Block proposal settings
max_block_size_kb = 1024
block_time_target_sec = 3

# Consensus
voting_timeout_sec = 5
consensus_threshold_pct = 67  # aBFT threshold

[network]
# P2P settings
listen_addr = "0.0.0.0:3030"
max_peers = 50
peer_discovery_interval_sec = 60

# Tor configuration (optional, for privacy)
tor_enabled = true
tor_socks_proxy = "127.0.0.1:9050"

[security]
# Firewall rules
allow_rpc_hosts = ["127.0.0.1", "::1"]  # Localhost only
rate_limit_requests_per_min = 1000

# Encryption
require_tls = false  # Tor already encrypted
```

---

## 📈 Monitoring & Maintenance

### **Health Checks**

```bash
# Quick health check
curl http://localhost:3030/health
# Expected: {"status":"healthy","validator":true}

# Detailed metrics
curl http://localhost:3030/node-info | jq '.'
# Returns: full validator stats

# Check if earning fees
curl http://localhost:3030/balance/YOUR_UAT_ADDRESS
# Monitor balance increasing over time
```

### **Log Monitoring**

```bash
# View validator logs
tail -f ~/.uat/validator.log

# Key patterns to monitor:
# ✅ "Block proposed" → You're actively proposing
# ✅ "Vote cast" → You're voting in consensus
# ⚠️ "Missed block" → Check network connection
# 🔴 "Consensus timeout" → Check peers
```

### **Automated Monitoring** (Recommended)

```bash
# Uptime monitoring script
#!/bin/bash
while true; do
    STATUS=$(curl -s http://localhost:3030/health | jq -r '.status')
    if [ "$STATUS" != "healthy" ]; then
        echo "⚠️ ALERT: Validator unhealthy!" | mail -s "UAT Validator Down" admin@example.com
        # Or send Telegram/Discord notification
    fi
    sleep 300  # Check every 5 minutes
done
```

---

## ❓ FAQ

### **Q: Do I need technical knowledge to run a validator?**
**A**: Basic level. If you can:
- Download and install desktop apps (flutter_validator)
- Import a seed phrase
- Keep your computer running 24/7

You're good! Advanced CLI setup is optional.

---

### **Q: Can I run multiple validators with the same wallet?**
**A**: ❌ **NO!** This causes double signing (will be slashed in mainnet).  
Each validator needs unique wallet. To run multiple validators:
1. Create separate wallets (different seed phrases)
2. Stake 1,000+ UAT in each wallet
3. Run separate validator nodes

---

### **Q: What if my validator goes offline?**
**A**: 
- **Testnet**: No penalty (safe to test)
- **Mainnet** (future): 1% slash after 6 hours downtime
- **Revenue**: Miss gas fees during downtime

**Solution**: Set up monitoring alerts + backup nodes (hot standby)

---

### **Q: Can I unstake my 1,000 UAT anytime?**
**A**: ✅ **YES!** No lock period.  
To exit:
1. Stop validator node
2. Transfer UAT to another wallet (entire balance)
3. Node auto-removed from validator set next epoch

**Note**: Gas fee earnings stay in validator wallet

---

### **Q: How do bootstrap validators differ from public validators?**
**A**: **Zero technical difference!** Same code, same rules, same economics.  

Only difference: Bootstrap validators funded at genesis (day 1).  
Public validators must acquire UAT via Proof-of-Burn.

After 50+ public validators → bootstrap nodes have NO special privilege

---

### **Q: What's the maximum number of validators?**
**A**: **Unlimited**. Permissionless design = no cap.

**Practical limit**: Economics (gas fee dilution as more validators join)  
Example:
- 10 validators → 10% share each (high earnings)
- 1,000 validators → 0.1% share each (low earnings)

Market naturally limits validator count via profitability threshold.

---

### **Q: Can I run a validator from home? Or need VPS?**
**A**: ✅ **YES, run from home!** No VPS needed.

**Tor Integration**: Validator connects via .onion (Tor Hidden Service)
- No public IP exposure
- No DNS records
- No port forwarding required
- Works behind NAT/firewall

**Example Home Setup**:
- Raspberry Pi 4 (8GB RAM) ← Perfectly fine!
- Home internet (even mobile hotspot works via Tor)
- Desktop computer running 24/7

**No need for**: VPS, cloud servers, static IP, domain names

---

### **Q: What happens if ALL bootstrap nodes go offline?**
**A**: Depends on network maturity:

**Early Network** (<10 public validators):
- 🔴 Network likely freezes (can't reach 67% threshold)
- Solution: Bootstrap nodes must maintain 24/7

**Mature Network** (50+ public validators):
- 🟢 Network continues normally (enough validators remain)
- Bootstrap nodes become optional

---

### **Q: Can validators vote to change consensus rules?**
**A**: ❌ **NO!** Unauthority is **immutable by design**.

**No governance** = No voting on:
- Supply cap changes
- Consensus rule changes
- Fee structure changes
- Protocol upgrades

**Hard forks**: Only via community consensus (like Bitcoin), not validator voting.

---

## 🚀 Next Steps

### **For New Validators**:
1. ✅ [Acquire UAT via Proof-of-Burn](#step-1-acquire-uat-via-proof-of-burn)
2. ✅ [Download flutter_validator](https://github.com/unauthoritymky-6236/unauthority-core/releases)
3. ✅ [Import wallet & start validating](#step-2-setup-validator-node)
4. ✅ [Monitor earnings in dashboard](#validator-dashboard-flutter-app)

### **For Developers**:
- 🔨 [Build from source](../README.md#installation)
- 📖 [Read Whitepaper](WHITEPAPER.md)
- 🛠️ [API Documentation](../api_docs/API_REFERENCE.md)
- 🐛 [Report issues](https://github.com/unauthoritymky-6236/unauthority-core/issues)

### **Join Community**:
- 💬 Telegram: TBD
- 🐦 Twitter: TBD
- 📧 Email: TBD

---

**Happy Validating! 🏛️**

---

*Last Updated: February 8, 2026*  
*Testnet Version: Level 1 (Functional)*  
*Mainnet Launch: Q2 2026*
