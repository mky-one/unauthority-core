# Genesis Configuration — Unauthority (LOS)

Genesis config format, generation tooling, validation rules, and allocation details.

---

## Table of Contents

1. [Overview](#overview)
2. [Genesis Config Format](#genesis-config-format)
3. [Wallet Entries](#wallet-entries)
4. [Allocation](#allocation)
5. [Genesis Generators](#genesis-generators)
6. [Testnet Genesis](#testnet-genesis)
7. [Mainnet Genesis](#mainnet-genesis)
8. [Validation Rules](#validation-rules)
9. [How Genesis is Loaded](#how-genesis-is-loaded)
10. [Modifying Genesis](#modifying-genesis)

---

## Overview

The genesis configuration defines the initial state of the Unauthority blockchain:
- Which accounts exist at launch
- How much LOS each account holds
- Which accounts are bootstrap validators
- Network identification (mainnet vs testnet)
- Bootstrap validator `.onion` addresses and ports

The genesis config is **embedded in the binary at compile-time** via `include_str!()`, ensuring every binary knows its genesis without external configuration files.

---

## Genesis Config Format

File: `genesis_config.json`

```json
{
  "network": "mainnet",
  "chain_id": 1,
  "timestamp": "2025-01-01T00:00:00Z",
  "total_supply": "21936236",
  "wallets": [
    {
      "name": "dev_treasury_1",
      "address": "LOS...",
      "public_key": "hex...",
      "balance_los": "428113",
      "is_validator": false
    },
    {
      "name": "bootstrap_validator_1",
      "address": "LOS...",
      "public_key": "hex...",
      "balance_los": "1000",
      "is_validator": true,
      "onion_address": "abc123...onion",
      "rest_port": 3030,
      "p2p_port": 4030
    }
  ]
}
```

### Top-Level Fields

| Field | Type | Description |
|---|---|---|
| `network` | `"mainnet"` or `"testnet"` | Network identification |
| `chain_id` | `u64` | 1 = mainnet, 2 = testnet (replay protection) |
| `timestamp` | RFC 3339 string | Genesis block timestamp |
| `total_supply` | String (LOS) | Total supply — must equal sum of all wallets |
| `wallets` | Array | All genesis accounts |

---

## Wallet Entries

### Standard Wallet (Non-Validator)

```json
{
  "name": "dev_treasury_1",
  "address": "LOSxxxxxxxxxx...",
  "public_key": "hex_dilithium5_public_key",
  "balance_los": "428113",
  "is_validator": false
}
```

### Bootstrap Validator

Validators have additional fields for network connectivity:

```json
{
  "name": "bootstrap_validator_1",
  "address": "LOSxxxxxxxxxx...",
  "public_key": "hex_dilithium5_public_key",
  "balance_los": "1000",
  "is_validator": true,
  "onion_address": "f3zfmhvverdljhddhxvdnkibrajd2cbolrfq4z6a5y2ifprf2xh34nid.onion",
  "rest_port": 3030,
  "p2p_port": 4030
}
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | String | Yes | Human-readable identifier |
| `address` | String | Yes | LOS address (Base58Check with `LOS` prefix) |
| `public_key` | String | Yes | Hex-encoded Dilithium5 public key (~5184 hex chars) |
| `balance_los` | String | Yes | Initial balance in LOS (as string for precision) |
| `is_validator` | bool | Yes | Whether this is a bootstrap validator |
| `onion_address` | String | Validators | Tor `.onion` address (V3, 56 chars + `.onion`) |
| `rest_port` | u16 | Validators | REST API port |
| `p2p_port` | u16 | P2P gossip port |

---

## Allocation

### Fixed Supply: 21,936,236 LOS

| Category | Wallet | Balance (LOS) | Validator |
|---|---|---|---|
| Dev Treasury | dev_treasury_1 | 428,113 | No |
| Dev Treasury | dev_treasury_2 | 245,710 | No |
| Dev Treasury | dev_treasury_3 | 50,000 | No |
| Dev Treasury | dev_treasury_4 | 50,000 | No |
| Bootstrap | bootstrap_validator_1 | 1,000 | Yes |
| Bootstrap | bootstrap_validator_2 | 1,000 | Yes |
| Bootstrap | bootstrap_validator_3 | 1,000 | Yes |
| Bootstrap | bootstrap_validator_4 | 1,000 | Yes |
| **Dev Total** | | **777,823** | |
| **Public** | *(via Proof-of-Burn)* | **21,158,413** | |
| **Total** | | **21,936,236** | |

### Public Supply

The public allocation (21,158,413 LOS) is **not in genesis**. It is distributed over time via the Proof-of-Burn mechanism. The genesis config only contains the dev treasury and bootstrap validator accounts.

### Bootstrap Stake

Each bootstrap validator receives exactly 1,000 LOS — the minimum validator stake. This ensures they can participate in consensus immediately at launch.

---

## Genesis Generators

Located in `genesis/`:

### Testnet Generator

```bash
cargo run -p genesis --bin testnet_generator
```

**Output:** `testnet-genesis/testnet_wallets.json`

**Properties:**
- **Deterministic** — uses hardcoded BIP39 seed phrases
- **Safe to commit** — test keys only, no real value
- Generates 8 wallets (4 treasuries + 4 bootstrap validators)
- Uses `los_crypto::generate_keypair_from_seed()` for deterministic key derivation

**Seed derivation:**
```
BIP39 seed phrase → SHA-256 domain separation ("los-dilithium5-keygen-v1") → ChaCha20 DRBG → Dilithium5 keypair
```

### Mainnet Generator

```bash
cargo run -p genesis --bin mainnet_generator
```

**Output:**
- `mainnet-genesis/mainnet_wallets.json` — FULL (includes private keys)
- `mainnet-genesis/mainnet_public.json` — PUBLIC only (safe to share)

**Properties:**
- **Non-deterministic** — uses `OsRng` (OS-level randomness)
- **Air-gapped** — should be run on an offline machine
- **NEVER commit** `mainnet_wallets.json` — contains secret keys
- Only commit `mainnet_public.json` (no secret keys)

### Legacy Generator

```bash
cargo run -p genesis
```

Generates random genesis wallets. Used for development/testing.

---

## Testnet Genesis

### File: `testnet-genesis/testnet_wallets.json`

Contains 8 pre-generated wallets with deterministic keys (hardcoded BIP39 seeds).

### Testnet-Specific Behavior

When `genesis_config.json` has `"network": "testnet"`:

1. **Testnet fallback** — if `genesis_config.json` is missing, the node falls back to `testnet-genesis/testnet_wallets.json`
2. **Fast epochs** — `TESTNET_REWARD_EPOCH_SECS = 120` (2 minutes instead of 30 days)
3. **Genesis validators earn rewards** — unlike mainnet, bootstrap validators participate in rewards
4. **Relaxed consensus** — `TESTNET_FUNCTIONAL_THRESHOLD = 1` (lower quorum for testing)
5. **Ed25519 fallback** — signature verification also accepts Ed25519 (for developer convenience)

### Testnet Config

File: `testnet-genesis/genesis_config.json`

```json
{
  "network": "testnet",
  "chain_id": 2,
  "timestamp": "2025-01-01T00:00:00Z",
  "total_supply": "21936236",
  "wallets": [ ... ]
}
```

---

## Mainnet Genesis

### Strict Mode

When `genesis_config.json` has `"network": "mainnet"`:

1. **No fallback** — the genesis config MUST be present. No testnet wallets fallback.
2. **Strict validation** — all supply, address, and key validation enforced
3. **30-day epochs** — `REWARD_EPOCH_SECS = 2_592_000`
4. **Genesis validators excluded from rewards** — bootstrap validators don't earn rewards
5. **Dilithium5 only** — no Ed25519 fallback
6. **Bonding curve disabled** — no `f64` bonding curve (testnet only)

### Embeding in Binary

The genesis config is embedded at compile time:

```rust
// In crates/los-node/src/genesis.rs
const GENESIS_CONFIG: &str = include_str!("../../../genesis_config.json");
```

This ensures:
- Every binary has the genesis config baked in
- No external file dependency at runtime
- Consistent genesis across all nodes

### Override

The embedded config can be overridden via environment variable:

```bash
export LOS_GENESIS_PATH="/path/to/custom/genesis_config.json"
```

---

## Validation Rules

When loading genesis, the node validates:

### Supply Validation

```
Σ(wallet.balance_los) == total_supply
```

All wallet balances must sum exactly to the declared total supply. This is also enforced at compile-time in the genesis generators via `assert_eq!`.

### Address Validation

- Each address must start with `LOS`
- Base58Check checksum must be valid
- No duplicate addresses allowed

### Key Validation

- Public keys must be valid hex-encoded Dilithium5 keys
- Each public key must derive to its declared address:
  ```
  public_key_to_address(decode_hex(public_key)) == address
  ```

### Validator Validation

- Validators must have `is_validator: true`
- Validators must have `balance_los >= 1000` (minimum stake)
- Validators must have `onion_address` (V3 format, 56+ chars)
- Validators must have `rest_port` and `p2p_port`

### Network Validation

- `chain_id` must match the `network` field (1 = mainnet, 2 = testnet)
- `timestamp` must be a valid RFC 3339 datetime

---

## How Genesis is Loaded

### Startup Sequence

```
1. Node starts
2. Read embedded GENESIS_CONFIG (compile-time)
3. Check LOS_GENESIS_PATH env var for override
4. Parse JSON → GenesisConfig struct
5. Validate: supply, addresses, keys, validators
6. For each wallet:
   a. Create AccountState with initial balance
   b. Create Mint block (genesis block for the account)
   c. Add to Ledger
7. Extract bootstrap validators → peer table
8. Connect to bootstrap peers via Tor
```

### GenesisConfig Struct (Rust)

```rust
struct GenesisConfig {
    network: String,           // "mainnet" or "testnet"
    chain_id: u64,             // 1 or 2
    timestamp: String,         // RFC 3339
    total_supply: String,      // "21936236"
    wallets: Vec<GenesisWallet>,
}

struct GenesisWallet {
    name: String,
    address: String,
    public_key: String,
    balance_los: String,
    is_validator: bool,
    onion_address: Option<String>,
    rest_port: Option<u16>,
    p2p_port: Option<u16>,
}
```

---

## Modifying Genesis

### For Testnet

1. Edit `testnet-genesis/testnet_wallets.json` directly, OR
2. Modify seeds in `genesis/src/bin/testnet_generator.rs` and regenerate:
   ```bash
   cargo run -p genesis --bin testnet_generator
   ```
3. Copy to root: `cp testnet-genesis/genesis_config.json ./genesis_config.json`
4. Rebuild the node: `cargo build --release`

### For Mainnet

1. Run on an air-gapped machine:
   ```bash
   cargo run -p genesis --bin mainnet_generator
   ```
2. Securely store `mainnet-genesis/mainnet_wallets.json` (secret keys!)
3. Copy public config: `cp mainnet-genesis/mainnet_public.json ./genesis_config.json`
4. Add `.onion` addresses and ports for bootstrap validators
5. Rebuild: `cargo build --release --features mainnet`
6. Distribute the binary — genesis is embedded

### Adding a Bootstrap Validator

Add to the `wallets` array in `genesis_config.json`:

```json
{
  "name": "bootstrap_validator_5",
  "address": "LOSnew_address...",
  "public_key": "hex_new_pubkey...",
  "balance_los": "1000",
  "is_validator": true,
  "onion_address": "new_onion_address.onion",
  "rest_port": 3034,
  "p2p_port": 4034
}
```

**Important:** Update `total_supply` to account for the additional 1,000 LOS, or reduce another allocation. The sum must always equal exactly 21,936,236.
