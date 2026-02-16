# Crate Reference — Unauthority (LOS)

Exhaustive module-level documentation for every crate in the workspace.

---

## Table of Contents

1. [los-core](#los-core)
2. [los-consensus](#los-consensus)
3. [los-network](#los-network)
4. [los-crypto](#los-crypto)
5. [los-node](#los-node)
6. [los-vm](#los-vm)
7. [los-sdk](#los-sdk)
8. [los-cli](#los-cli)
9. [genesis](#genesis)

---

## los-core

**Path:** `crates/los-core/`
**Purpose:** Blockchain primitives, state management, economics. Pure logic — no I/O.

### Constants (lib.rs)

| Constant | Value | Description |
|---|---|---|
| `CIL_PER_LOS` | `100_000_000_000` (10^11) | Atomic units per 1 LOS |
| `MIN_VALIDATOR_STAKE_CIL` | `1_000 × CIL_PER_LOS` | Minimum stake to be a validator |
| `BASE_FEE_CIL` | `100_000` | Base transaction fee (~0.000001 LOS) |
| `MIN_POW_DIFFICULTY_BITS` | `16` | Anti-spam PoW (65,536 avg hash attempts) |
| `CHAIN_ID` | `1` (mainnet) / `2` (testnet) | Replay protection between networks |
| `VALIDATOR_REWARD_POOL_CIL` | `500_000 × CIL_PER_LOS` | Total non-inflationary reward pool |
| `REWARD_EPOCH_SECS` | `2_592_000` (30 days) | Mainnet epoch duration |
| `TESTNET_REWARD_EPOCH_SECS` | `120` (2 min) | Testnet epoch duration |
| `REWARD_RATE_INITIAL_CIL` | `5_000 × CIL_PER_LOS` | Per-epoch reward before halving |
| `REWARD_HALVING_INTERVAL_EPOCHS` | `48` | Halving interval (~4 years) |
| `REWARD_MIN_UPTIME_PCT` | `95` | Minimum uptime % for rewards |
| `REWARD_PROBATION_EPOCHS` | `1` | New validator probation period |
| `GAS_PRICE_CIL` | `1` | 1 gas unit = 1 CIL |
| `MIN_DEPLOY_FEE_CIL` | `1_000_000_000` | Minimum contract deploy fee (0.01 LOS) |
| `DEFAULT_GAS_LIMIT` | `1_000_000` | Default gas limit |

### Enums

**BlockType:**
```rust
enum BlockType {
    Send,           // Debit from account
    Receive,        // Credit to account
    Change,         // Change representative
    Mint,           // Token creation (genesis, burn reward)
    Slash,          // Slashing penalty
    ContractDeploy, // Deploy WASM contract
    ContractCall,   // Call WASM contract
}
```

**ProcessResult:**
```rust
enum ProcessResult {
    Applied(String),    // Block hash — newly applied
    Duplicate(String),  // Block hash — already exists (safe for re-broadcast)
}
```

### Structs

**Block:**
| Field | Type | Description |
|---|---|---|
| `account` | `String` | Owner address (LOS...) |
| `previous` | `String` | Hash of previous block in this chain |
| `block_type` | `BlockType` | Transaction type |
| `amount` | `u128` | Amount in CIL |
| `link` | `String` | Context-dependent (recipient, send hash, contract) |
| `signature` | `String` | Dilithium5 hex signature |
| `public_key` | `String` | Dilithium5 hex public key |
| `work` | `u64` | Anti-spam PoW nonce |
| `timestamp` | `u64` | Unix timestamp |
| `fee` | `u128` | Dynamic fee in CIL |

**Block methods:**
- `signing_hash() → String` — Keccak256 of all fields except signature, includes `CHAIN_ID`
- `calculate_hash() → String` — `Keccak256(signing_hash ‖ signature)`
- `verify_signature() → bool` — Dilithium5 signature verification
- `verify_pow() → bool` — Check 16 leading zero bits

**AccountState:**
| Field | Type | Description |
|---|---|---|
| `head` | `String` | Hash of latest block in account's chain |
| `balance` | `u128` | Current balance in CIL |
| `block_count` | `u64` | Number of blocks in this chain |
| `is_validator` | `bool` | Validator status |

**Ledger:**
| Field | Type | Description |
|---|---|---|
| `accounts` | `BTreeMap<String, AccountState>` | All account states |
| `blocks` | `BTreeMap<String, Block>` | All blocks by hash |
| `distribution` | `DistributionState` | Public supply tracking |
| `claimed_sends` | `BTreeSet<String>` | Prevents double-receive |
| `accumulated_fees_cil` | `u128` | Fees pending epoch redistribution |

**Ledger::process_block() validation pipeline:**
1. PoW verification (16 zero bits)
2. Dilithium5 signature verification
3. Account ↔ public key binding (Send/Change/Deploy/Call must match account owner)
4. Block hash deduplication
5. Account existence (only Mint/Receive can create new accounts)
6. Chain sequence (`previous == state.head`)
7. Timestamp validation (±5 min drift, monotonic)
8. Per-type validation: fee, balance, supply limits, double-receive prevention, anti-whale

### Submodules

**anti_whale.rs:**
| Type | Description |
|---|---|
| `AntiWhaleConfig` | `max_tx_per_block` (5), `fee_scale_multiplier` (2), `max_burn_per_block` (1000 LOS) |
| `AntiWhaleEngine` | Activity tracking per address, fee scaling, whale detection |
| `AddressActivity` | Per-address transaction history (60s windows) |
| `calculate_voting_power(stake)` | `isqrt_u64(stake)` — quadratic voting |
| `whale_threshold` | `total_supply / 100` (>1% = whale) |

**distribution.rs:**
| Type | Description |
|---|---|
| `DistributionState` | Tracks `remaining_supply` (CIL) and `total_burned_usd` |
| `calculate_yield_cil()` | `(burn_usd × remaining) / PUBLIC_SUPPLY_CAP` — integer only |

**oracle_consensus.rs:**
| Type | Description |
|---|---|
| `OracleConsensus` | Price feed aggregation engine |
| `MICRO_USD_PER_USD` | `1_000_000` — all prices in micro-USD |
| `calculate_median()` | Integer median of sorted price array |
| `outlier_threshold_bp` | `2_000` (20% deviation) |
| `min_submissions` | `2` validators minimum |

**validator_rewards.rs:**
| Type | Description |
|---|---|
| `ValidatorRewardPool` | Epoch management, reward distribution |
| `ValidatorRewardState` | Per-validator: join_epoch, heartbeats, last_reward |
| `isqrt(n: u128)` | Newton's method integer sqrt — deterministic |
| `distribute_rewards()` | `budget × isqrt(stake) / Σisqrt(all)` |

---

## los-consensus

**Path:** `crates/los-consensus/`
**Purpose:** aBFT consensus, quadratic voting, slashing, checkpoints.

### abft.rs — aBFT Consensus Engine (839 lines)

| Type | Description |
|---|---|
| `ABFTConsensus` | Main consensus state: view, phase, votes, finalized blocks |
| `ConsensusMessage` | view, message_type, block, sender, mac |
| `ConsensusMessageType` | PrePrepare, Prepare, Commit, ViewChange |
| `Block` | height, timestamp, data, proposer, parent_hash |

**Key methods:**
- `propose_block()` — Leader creates Pre-Prepare
- `handle_message()` — Process incoming consensus messages
- `check_prepare_quorum()` — 2f+1 prepare votes → advance to Commit
- `check_commit_quorum()` — 2f+1 commit votes → finalize block
- `trigger_view_change()` — Leader failure recovery

**Parameters:**
| Parameter | Value |
|---|---|
| `block_timeout_ms` | 3,000 |
| `view_change_timeout_ms` | 5,000 |
| `MAX_FINALIZED_BLOCKS` | 10,000 |
| Quorum | `2f + 1` where `f = (n-1)/3` |

**MAC authentication:** Keccak256 keyed MAC for message integrity.

### voting.rs — Quadratic Voting (574 lines)

| Type | Description |
|---|---|
| `ValidatorVote` | validator_address, staked_amount_cil, voting_power, vote_preference, is_active |
| `VotePreference` | For, Against, Abstain |
| `ConsensusResult` | proposal_id, votes_for/against_bps, passed, total_voting_power |

**Key functions:**
- `calculate_voting_power(stake_cil) → u128` — `isqrt(clamped_stake)`, no f64
- `calculate_consensus() → ConsensusResult` — Aggregates votes, checks >50% quorum
- `calculate_concentration_ratio()` — Max single validator power / total power (basis points)

**Constants:**
- `MIN_STAKE_CIL`: 1,000 LOS in CIL
- `MAX_STAKE_FOR_VOTING_CIL`: total supply in CIL (cap)

### slashing.rs — Slashing Manager (892 lines)

| Type | Description |
|---|---|
| `SlashingManager` | Manages proposals, signatures, validator profiles |
| `SlashProposal` | proposer, target, violation, evidence_hash, confirmations |
| `SlashEvent` | block_height, validator, violation, amount |
| `ValidatorSafetyProfile` | status, slashed_cil, recent_signatures, blocks_participated |
| `ViolationType` | DoubleSigning, ExtendedDowntime, FraudulentTransaction |
| `ValidatorStatus` | Active, Slashed, Banned, Unstaking |

**Penalties:**
| Violation | Slash (bps) | Result |
|---|---|---|
| DoubleSigning | 10,000 (100%) | Banned |
| FraudulentTransaction | 10,000 (100%) | Banned |
| ExtendedDowntime | 100 (1%) | Slashed |

**Confirmation threshold:** `(validators × 2 / 3) + 1`

### checkpoint.rs — Finality Checkpoints (674 lines)

| Type | Description |
|---|---|
| `CheckpointManager` | Checkpoint creation and verification |
| `FinalityCheckpoint` | height, block_hash, timestamp, validator_count, state_root, signature_count |
| `CHECKPOINT_INTERVAL` | 1,000 blocks |

**Quorum verification:** `required = (n × 67 + 99) / 100` — integer ceiling for 67%.

---

## los-network

**Path:** `crates/los-network/`
**Purpose:** P2P networking, Tor transport, fee scaling.

### tor_transport.rs (299 lines)

| Type | Description |
|---|---|
| `TorConfig` | socks5_proxy, onion_address, listen_port, enabled |
| `TorDialer` | Creates local TCP proxies tunneling through SOCKS5 to `.onion` |
| `BootstrapNode` | `Multiaddr(String)` or `Onion { host, port }` |

**TorConfig::from_env()** reads:
- `LOS_SOCKS5_PROXY` / `LOS_TOR_SOCKS5`
- `LOS_ONION_ADDRESS`
- `LOS_P2P_PORT`
- Falls back to auto-detect at `127.0.0.1:9050` (500ms timeout)

**TorDialer::create_onion_proxy(host, port)** returns a local multiaddr `/ip4/127.0.0.1/tcp/{local}` that tunnels through Tor.

### p2p_integration.rs (516 lines)

| Type | Description |
|---|---|
| `P2PNetworkManager` | Session management, message queues, stats |
| `PeerSession` | peer_id, session_id, established_at, messages_sent/received |
| `MessagePriority` | Low, Normal, High, Critical |
| `QueuedMessage` | destination, payload, priority, timestamp |
| `NetworkStats` | total_peers, connected_peers, bytes_sent/received, security_events |
| `NodeRole` | Validator, Sentry, Full |

### p2p_encryption.rs

Noise Protocol (XX handshake) for end-to-end encryption on P2P channels.

### fee_scaling.rs

Dynamic fee calculation based on network congestion. Feeds into `AntiWhaleEngine`.

### lib.rs — LosNode (277 lines)

| Type | Description |
|---|---|
| `NetworkEvent` | `NewBlock(String)`, `PeerDiscovered(String)` |
| `LosBehaviour` | Gossipsub + Toggle<mDNS> |
| `LosNode::start()` | Main P2P event loop |

**Gossipsub config:**
- Topic: `"los-blocks"`
- Max message size: 10 MB
- mDNS disabled when Tor active
- Reconnection: 60s (testnet), 180s (mainnet)
- Binds `127.0.0.1` when Tor is active (IP leak prevention)

---

## los-crypto

**Path:** `crates/los-crypto/`
**Purpose:** Post-quantum cryptography (Dilithium5), key management, encryption.

### Functions

| Function | Input | Output | Description |
|---|---|---|---|
| `generate_keypair()` | — | `KeyPair` | Random Dilithium5 keypair |
| `generate_keypair_from_seed(seed)` | BIP39 seed bytes | `KeyPair` | Deterministic: SHA-256 domain separation → ChaCha20 DRBG → Dilithium5 |
| `keypair_from_secret(bytes)` | SK bytes | `KeyPair` | Reconstruct from 4864/4896 byte SK or 32-byte seed |
| `sign_message(msg, sk)` | message, secret key | hex signature | Dilithium5 detached signature |
| `verify_signature(msg, sig, pk)` | message, signature, pubkey | `bool` | Dual-mode: Dilithium5 primary + Ed25519 fallback (testnet only) |
| `public_key_to_address(pk)` | public key bytes | `String` | `"LOS" + Base58(0x4A ‖ BLAKE2b-160(pk) ‖ SHA256d-checksum)` |
| `validate_address(addr)` | address string | `Result<()>` | Format + checksum verification |
| `encrypt_private_key(sk, pw)` | secret key, password | `EncryptedKey` | age scrypt (N=2^20) |
| `decrypt_private_key(enc, pw)` | encrypted, password | `Vec<u8>` | age decryption |
| `generate_encrypted_keypair(pw)` | password | `(KeyPair, EncryptedKey)` | Generate + immediately encrypt |

### Address Format

```
"LOS" + Base58Check(version_byte ‖ hash ‖ checksum)

version_byte = 0x4A
hash = BLAKE2b-160(public_key)
checksum = SHA256(SHA256(version ‖ hash))[0..4]
```

Total decoded: 25 bytes. Bitcoin-style Base58Check encoding.

### Key Sizes

| Component | Size |
|---|---|
| Public key | ~2,592 bytes |
| Secret key | 4,864 bytes |
| Signature | ~4,627 bytes |
| Domain separator | `"los-dilithium5-keygen-v1"` |

---

## los-node

**Path:** `crates/los-node/`
**Purpose:** Main validator binary. REST API, gRPC, P2P gossip, consensus orchestration.

**Binary name:** `uat-node`

### Internal Modules

| Module | Lines | Purpose |
|---|---|---|
| `main.rs` | ~9,000 | REST API (Warp), P2P gossip, burn pipeline, epoch processing, CLI REPL |
| `grpc_server.rs` | — | gRPC service (Tonic) |
| `genesis.rs` | — | Genesis config parsing, validation, account initialization |
| `db.rs` | — | sled database: persistent ledger, checkpoints |
| `mempool.rs` | — | Transaction mempool management |
| `metrics.rs` | — | 45+ Prometheus gauges/counters/histograms |
| `rate_limiter.rs` | — | Per-IP and per-address API rate limiting |
| `testnet_config.rs` | — | Graduated testnet levels: Functional → Consensus → Production |
| `validator_api.rs` | — | Key generation, import, validator registration |
| `validator_rewards.rs` | — | Epoch processing, reward distribution |

### Key Constants (main.rs)

| Constant | Value | Description |
|---|---|---|
| `BURN_CONSENSUS_THRESHOLD` | `20_000` | Quadratic voting threshold for burns |
| `SEND_CONSENSUS_THRESHOLD` | `20_000` | Quadratic voting threshold for sends |
| `MIN_DISTINCT_VOTERS` | `2` | Prevents single-validator self-consensus |
| `TOTAL_SUPPLY_LOS` | `21_936_236` | Display constant |
| `BURN_ADDRESS_ETH` | `"0x0000...dead"` | Dead address for ETH burns |
| `BURN_ADDRESS_BTC` | `"1111...11111"` | Dead address for BTC burns |
| `LEDGER_FILE` | `"ledger_state.json"` | Ledger persistence file |

### Shared State

All state is wrapped in `Arc<RwLock<>>` for concurrent access:

```rust
Arc<RwLock<Ledger>>            // Blockchain state
Arc<RwLock<Vec<OraclePrice>>>  // Oracle submissions
Arc<RwLock<ABFTConsensus>>     // Consensus engine
Arc<RwLock<SlashingManager>>   // Slashing state
Arc<RwLock<ValidatorRewardPool>> // Reward tracking
Arc<RwLock<WasmEngine>>        // Smart contract engine
```

Thread safety enforced via `safe_lock<T>()` which recovers from poisoned mutexes.

---

## los-vm

**Path:** `crates/los-vm/`
**Purpose:** WASM smart contract execution engine (UVM).

### Constants

| Constant | Value | Description |
|---|---|---|
| `MAX_BYTECODE_SIZE` | 1,048,576 (1 MB) | Max contract size |
| `MAX_EXECUTION_SECS` | 5 | Wall-clock timeout |
| `GAS_PER_KB_BYTECODE` | 100 | Compilation cost |
| `MAX_LEAKED_THREADS` | 16 | Safety cap for stuck WASM threads |

### Key Types

**Contract:**
| Field | Type | Description |
|---|---|---|
| `address` | `String` | `LOSCon{blake3_hash}` |
| `code_hash` | `String` | blake3 of bytecode |
| `bytecode` | `Vec<u8>` | Compiled WASM |
| `state` | `BTreeMap<String,String>` | Contract storage |
| `balance` | `u128` | Contract balance in CIL |
| `created_at_block` | `u64` | Deployment block |
| `owner` | `String` | Deployer address |

**ContractCall:**
| Field | Type | Description |
|---|---|---|
| `contract` | `String` | Contract address |
| `function` | `String` | Function name |
| `args` | `Vec<String>` | Arguments |
| `gas_limit` | `u64` | Max gas |
| `caller` | `String` | Caller address |
| `block_timestamp` | `u64` | Current timestamp |

**ContractResult:**
| Field | Type | Description |
|---|---|---|
| `success` | `bool` | Execution succeeded |
| `output` | `String` | Return value |
| `gas_used` | `u64` | Gas consumed |
| `state_changes` | `HashMap` | Modified key-value pairs |
| `events` | `Vec<ContractEvent>` | Emitted events |

### Execution Pipeline

```
call_contract()
  ├── 1. Hosted WASM (SDK host functions available)
  ├── 2. Legacy WASM (raw execution, no host functions)
  └── 3. Mock dispatch (testnet only, disabled on mainnet)
```

**Gas metering:** wasmer-middlewares Metering at 1 WASM instruction = 1 gas unit. Deterministic across all validators.

### Submodules

- `oracle_connector.rs` — Oracle price feed interface for contracts
- `host.rs` — Host function implementations
- `usp01.rs` — USP-01 token standard implementation

---

## los-sdk

**Path:** `crates/los-sdk/`
**Purpose:** Smart contract development SDK. `#![no_std]` for `wasm32-unknown-unknown`.

### Host Functions (16 extern "C" imports)

| Category | Function | Description |
|---|---|---|
| **State** | `state::set(key, value)` | Write to contract storage |
| **State** | `state::get(key) → Option<String>` | Read from contract storage |
| **State** | `state::set_str/u128/u64()` | Typed setters |
| **State** | `state::get_str/u128/u64() → Option<T>` | Typed getters |
| **State** | `state::del(key)` | Delete key |
| **State** | `state::exists(key) → bool` | Check existence |
| **Events** | `event::emit(type, data_json)` | Emit contract event |
| **Crypto** | `crypto::blake3(data) → [u8;32]` | Hash data |
| **Context** | `caller() → String` | Transaction sender |
| **Context** | `self_address() → String` | Contract address |
| **Context** | `balance() → u128` | Contract balance |
| **Context** | `timestamp() → u64` | Block timestamp |
| **Args** | `arg_count() → u32` | Argument count |
| **Args** | `arg(idx) → Option<String>` | Get argument by index |
| **Transfer** | `transfer(recipient, amount)` | Send CIL from contract |
| **Return** | `set_return(data)` | Set return value |
| **Logging** | `log(msg)` | Debug logging |
| **Abort** | `abort(msg) → !` | Abort execution |

### Memory Allocator

Custom `WasmBumpAllocator` — grows WASM linear memory via `memory.grow`. No individual deallocation (bump allocator).

### Panic Handler

Writes up to 128 bytes of panic message into a buffer, calls `host_abort`, then `unreachable`.

---

## los-cli

**Path:** `crates/los-cli/`
**Binary name:** `los-cli`
**Purpose:** Command-line wallet, validator, and query tool.

### Commands

```
los-cli [--rpc <URL>] [--config-dir <PATH>] <COMMAND>

wallet new --name <NAME>             Create new wallet
wallet list                          List all wallets
wallet balance <ADDRESS>             Show balance
wallet export <NAME> --output <PATH> Export encrypted
wallet import <INPUT> --name <NAME>  Import wallet

validator stake --amount <LOS> --wallet <NAME>   Stake to become validator
validator unstake --wallet <NAME>                 Unstake tokens
validator status <ADDRESS>                        Validator status
validator list                                    List active validators

query block <HEIGHT>      Get block by height
query account <ADDRESS>   Get account state
query info                Network info
query validators          Validator set

tx send --to <ADDR> --amount <LOS> --from <NAME>   Send LOS
tx status <HASH>                                     Query transaction
```

**Config:** `--rpc` defaults to `http://localhost:3030` (env: `LOS_RPC_URL`). Config directory: `~/.los`.

---

## genesis

**Path:** `genesis/`
**Version:** 2.1.0
**Purpose:** Genesis configuration generation and parsing.

### Binaries

| Binary | Purpose |
|---|---|
| `testnet_generator` | Deterministic keypairs from hardcoded BIP39 seeds (safe to commit) |
| `mainnet_generator` | Air-gapped generation with OsRng (NEVER commit output) |

### Allocation

| Wallet | LOS | Notes |
|---|---|---|
| Dev Treasury #1 | 428,113 | Core development |
| Dev Treasury #2 | 245,710 | Operations |
| Dev Treasury #3 | 50,000 | Community |
| Dev Treasury #4 | 50,000 | Emergency |
| Bootstrap V1-V4 | 4,000 | 4 × 1,000 LOS |
| **Dev Total** | **777,823** | ~3.5% |
| **Public** | **21,158,413** | ~96.5% |
| **Total** | **21,936,236** | Fixed supply |

### Genesis Config Format

See [dev_docs/GENESIS.md](GENESIS.md) for the full format specification.
