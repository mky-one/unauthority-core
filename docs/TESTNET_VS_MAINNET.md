# Testnet vs Mainnet - UAT Blockchain

Panduan lengkap perbedaan antara Testnet dan Mainnet untuk Unauthority (UAT).

---

## 🔍 Overview

| Aspect | Testnet | Mainnet |
|--------|---------|---------|
| **Purpose** | Testing & Development | Production use |
| **UAT Value** | $0 (no real value) | Real economic value |
| **Supply** | Same (21.936M UAT) | Same (21.936M UAT) |
| **Consensus** | Same aBFT | Same aBFT |
| **Blockchain Tech** | **100% IDENTICAL** | **100% IDENTICAL** |
| **Smart Contracts** | Same UVM (WASM) | Same UVM (WASM) |
| **Distribution** | **Faucet + PoB** | **PoB only** |
| **Reset** | Can be reset | **IMMUTABLE** |
| **Network ID** | `uat-testnet` | `uat-mainnet` |

---

## ⚙️ Technical Differences

### 1. **Blockchain Technology (SAME)**

**Testnet dan Mainnet menggunakan blockchain yang SAMA:**

✅ **aBFT Consensus** - <3 second finality  
✅ **Block-Lattice structure** - DAG architecture  
✅ **WASM smart contracts** - UVM execution  
✅ **Quadratic voting** - √Stake voting power  
✅ **Dynamic fee scaling** - Anti-spam mechanism  
✅ **Post-quantum crypto** - Dilithium-ready  
✅ **Fixed supply** - 21.936M UAT  

**Kode Rust yang sama, binary yang sama, algoritma yang sama.**

---

### 2. **Distribution Method (DIFFERENT)**

#### Testnet:
```rust
// Faucet enabled (DEV_MODE = true)
const DEV_MODE: bool = true;
const FAUCET_DRIP: u128 = 100_000 * VOID_PER_UAT; // 100k UAT per request

// Rate limits:
// - 1 request per hour (per IP)
// - 1 request per 24h (per address)
```

**Cara mendapat UAT testnet:**
1. **Faucet:** Request via REST API `/faucet`
2. **PoB:** Burn BTC/ETH (same as mainnet, but testnet BTC/ETH)

#### Mainnet:
```rust
// Faucet DISABLED (DEV_MODE = false)
const DEV_MODE: bool = false;

// Only PoB distribution
// - Burn real BTC/ETH → receive real UAT
// - Bonding curve pricing
```

**Cara mendapat UAT mainnet:**
- **HANYA PoB:** Burn **REAL** BTC/ETH untuk UAT

---

### 3. **Genesis Configuration (SAME STRUCTURE)**

**Testnet & Mainnet punya struktur genesis IDENTIK:**

```json
{
  "total_supply": 21936236,
  "dev_wallets": [
    { "address": "UAT...", "balance": 191942 },
    // ... 8 wallets total
  ],
  "bootstrap_validators": [
    { "address": "UAT...", "stake": 1000 },
    { "address": "UAT...", "stake": 1000 },
    { "address": "UAT...", "stake": 1000 }
  ]
}
```

**Perbedaan:** Private keys berbeda (testnet vs mainnet).

---

### 4. **Network ID & Chain ID**

#### Testnet:
```rust
const CHAIN_ID: &str = "uat-testnet";
const GENESIS_HASH: &str = "0x...testnet";
const NETWORK_MAGIC: u32 = 0x54455354; // "TEST"
```

#### Mainnet:
```rust
const CHAIN_ID: &str = "uat-mainnet";
const GENESIS_HASH: &str = "0x...mainnet";
const NETWORK_MAGIC: u32 = 0x4D41494E; // "MAIN"
```

**Transaksi testnet tidak valid di mainnet** (dan sebaliknya).

---

### 5. **Explorer & APIs**

#### Testnet:
- **Explorer:** testnet.unauthority.io
- **REST API:** https://api-testnet.unauthority.io
- **RPC:** https://rpc-testnet.unauthority.io

#### Mainnet:
- **Explorer:** explorer.unauthority.io
- **REST API:** https://api.unauthority.io
- **RPC:** https://rpc.unauthority.io

---

### 6. **Validator Requirements (SAME)**

**Testnet & Mainnet requirements IDENTIK:**

| Requirement | Testnet | Mainnet |
|-------------|---------|---------|
| Min Stake | 1,000 UAT | 1,000 UAT |
| Hardware | 4 CPU, 8GB RAM, 100GB SSD | Same |
| Uptime | 99%+ recommended | Same |
| Slashing | Double-sign: 100% | Same |
| Rewards | Gas fees | Same |

---

## 🚀 Use Cases

### Testnet (Testing)

**Untuk siapa:**
- Smart contract developers
- Wallet developers
- Validator operators (testing setup)
- Researchers/auditors

**Aktivitas:**
1. **Deploy & test smart contracts** (free gas via faucet)
2. **Test wallet integration** (create, send, receive)
3. **Simulate validator operations** (staking, rewards)
4. **Load testing** (spam transactions tanpa cost)
5. **Bug hunting** (find vulnerabilities)

**Example workflow:**
```bash
# 1. Get testnet UAT
curl -X POST http://testnet-api:8080/faucet \
  -d '{"address":"UAT123..."}'

# 2. Deploy contract
uat-cli deploy contract.wasm --network testnet

# 3. Test transactions
uat-cli send --to UAT456... --amount 100 --network testnet
```

---

### Mainnet (Production)

**Untuk siapa:**
- Real users holding UAT
- Production validators earning fees
- dApps with real users
- Traders/investors

**Aktivitas:**
1. **Burn BTC/ETH** untuk mendapat UAT (real value)
2. **Send/receive real UAT**
3. **Deploy production contracts** (pay real gas)
4. **Stake as validator** (earn real gas fees)
5. **Build dApps** (dengan real users)

**Example workflow:**
```bash
# 1. Get mainnet UAT via PoB
# Burn 0.1 BTC → receive ~4500 UAT

# 2. Send real transaction (costs real gas)
uat-cli send --to UAT456... --amount 1000 --network mainnet

# 3. Stake as validator
uat-cli stake --amount 1000 --network mainnet
```

---

## 🔄 Migration Path (Testnet → Mainnet)

**Data TIDAK bisa migrate** karena blockchain terpisah.

### Cara deploy ke mainnet:

1. **Test di testnet** hingga yakin code works
2. **Audit contract** di testnet
3. **Deploy ULANG di mainnet** (bukan migrate)
4. **Update frontend** untuk connect ke mainnet RPC

**Example:**
```typescript
// Development (testnet)
const API_URL = "https://api-testnet.unauthority.io";

// Production (mainnet)
const API_URL = "https://api.unauthority.io";
```

---

## 💰 Economic Model

### Testnet (No Value)

```
Testnet UAT = $0
- Free via faucet
- No trading value
- Can be reset anytime
- Unlimited supply via faucet
```

**Purpose:** Risk-free experimentation.

### Mainnet (Real Value)

```
Mainnet UAT = Market Price
- Acquired via PoB (burn BTC/ETH)
- Tradeable on DEX/CEX
- Immutable (no reset)
- Fixed supply (21.936M)
```

**Purpose:** Real economic activity.

---

## ⚠️ Important Warnings

### For Developers:

❌ **JANGAN deploy untested contracts ke mainnet**  
✅ **ALWAYS test di testnet dulu**

❌ **JANGAN hardcode testnet addresses di production**  
✅ **Use environment variables** for network config

❌ **JANGAN mix testnet & mainnet private keys**  
✅ **Separate wallets** for safety

### For Users:

❌ **JANGAN send mainnet UAT ke testnet address**  
❌ **JANGAN expect testnet UAT to have value**  
❌ **JANGAN trade testnet tokens** (scam)

---

## 🛠️ Configuration Examples

### Node Configuration

**Testnet validator.toml:**
```toml
[network]
chain_id = "uat-testnet"
bootstrap_peers = [
    "/ip4/testnet1.unauthority.io/tcp/30333",
    "/ip4/testnet2.unauthority.io/tcp/30333"
]

[api]
faucet_enabled = true
```

**Mainnet validator.toml:**
```toml
[network]
chain_id = "uat-mainnet"
bootstrap_peers = [
    "/ip4/mainnet1.unauthority.io/tcp/30333",
    "/ip4/mainnet2.unauthority.io/tcp/30333"
]

[api]
faucet_enabled = false  # NEVER enable on mainnet
```

---

### Frontend Configuration

**Wallet (.env):**
```bash
# Testnet
REACT_APP_NETWORK=testnet
REACT_APP_API_URL=https://api-testnet.unauthority.io
REACT_APP_FAUCET_ENABLED=true

# Mainnet
REACT_APP_NETWORK=mainnet
REACT_APP_API_URL=https://api.unauthority.io
REACT_APP_FAUCET_ENABLED=false
```

---

## 📊 Comparison Table (Complete)

| Feature | Testnet | Mainnet |
|---------|---------|---------|
| **Blockchain Code** | ✅ Same | ✅ Same |
| **Consensus (aBFT)** | ✅ Same | ✅ Same |
| **Smart Contracts** | ✅ Same UVM | ✅ Same UVM |
| **Fixed Supply** | ✅ 21.936M | ✅ 21.936M |
| **Genesis Structure** | ✅ Same (11 wallets) | ✅ Same (11 wallets) |
| **Cryptography** | ✅ Post-quantum ready | ✅ Post-quantum ready |
| **Finality Time** | ✅ <3 seconds | ✅ <3 seconds |
| **Gas Fees** | ✅ Same calculation | ✅ Same calculation |
| **Slashing** | ✅ Same rules | ✅ Same rules |
| **Quadratic Voting** | ✅ √Stake | ✅ √Stake |
| **Anti-Whale** | ✅ Same mechanisms | ✅ Same mechanisms |
| **Faucet** | ✅ Enabled (100k UAT/req) | ❌ Disabled |
| **PoB Distribution** | ⚠️ Testnet BTC/ETH | ✅ Real BTC/ETH |
| **Economic Value** | ❌ $0 | ✅ Market price |
| **Can Reset** | ✅ Yes | ❌ IMMUTABLE |
| **Network ID** | `uat-testnet` | `uat-mainnet` |
| **Chain ID** | `0x54455354` | `0x4D41494E` |
| **Explorer** | testnet.unauthority.io | explorer.unauthority.io |

---

## 🎯 Summary

**Key Takeaways:**

1. **Blockchain technology IDENTIK** - testnet = preview of mainnet
2. **Faucet HANYA di testnet** - mainnet purely PoB
3. **Testnet untuk testing** - zero risk, unlimited UAT
4. **Mainnet untuk production** - real value, fixed supply
5. **Data TIDAK migrate** - deploy ulang saat move to mainnet
6. **Always test di testnet** sebelum mainnet deploy

---

## 📚 Resources

- [Testnet Deployment Guide](./TESTNET_DEPLOYMENT.md)
- [Faucet Documentation](../crates/uat-node/FAUCET_README.md)
- [API Examples](../api_docs/API_EXAMPLES.md)
- [Docker Deployment](./DOCKER_DEPLOYMENT.md)
