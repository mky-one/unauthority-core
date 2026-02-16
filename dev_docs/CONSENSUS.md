# Consensus Deep Dive — Unauthority (LOS)

Detailed technical documentation of the aBFT consensus engine, quadratic voting, and finality guarantees.

---

## Table of Contents

1. [Overview](#overview)
2. [aBFT Protocol](#abft-protocol)
3. [Message Types](#message-types)
4. [Leader Selection](#leader-selection)
5. [View Change](#view-change)
6. [Quorum Calculation](#quorum-calculation)
7. [Quadratic Voting](#quadratic-voting)
8. [Block Finality](#block-finality)
9. [Checkpoints](#checkpoints)
10. [Send Consensus](#send-consensus)
11. [Burn Consensus](#burn-consensus)
12. [Configuration Constants](#configuration-constants)
13. [Determinism Guarantees](#determinism-guarantees)

---

## Overview

Unauthority uses an asynchronous Byzantine Fault Tolerant (aBFT) consensus protocol based on the PBFT (Practical Byzantine Fault Tolerance) model. The protocol tolerates up to `f = (n-1)/3` faulty or malicious validators while guaranteeing safety (no conflicting finalizations) and liveness (progress continues when leader fails).

Key properties:
- **Safety** — Two honest validators never finalize conflicting blocks
- **Liveness** — View change ensures progress even when the leader fails
- **Determinism** — All math is `u128` integer; identical results on all platforms
- **Anti-centralization** — Quadratic voting (√stake) prevents whale domination

---

## aBFT Protocol

### Three-Phase Commit

```
Phase 1: Pre-Prepare    (Leader → All)
Phase 2: Prepare        (All → All)
Phase 3: Commit         (All → All)
```

#### Phase 1: Pre-Prepare

The leader for the current view proposes a block:

```rust
ConsensusMessage {
    view: current_view,
    message_type: PrePrepare,
    block: Some(proposed_block),
    sender: leader_address,
    mac: keccak256_keyed_mac(message_bytes),
}
```

All validators receive the Pre-Prepare, validate the block, and if accepted, move to Phase 2.

#### Phase 2: Prepare

Each validator broadcasts a Prepare message acknowledging the proposed block:

```rust
ConsensusMessage {
    view: current_view,
    message_type: Prepare,
    block: Some(block_reference),
    sender: validator_address,
    mac: ...,
}
```

The consensus engine collects Prepare votes. Once **2f + 1** Prepare messages are received (including the leader's implicit prepare), the validator advances to Phase 3.

#### Phase 3: Commit

Each validator broadcasts a Commit message:

```rust
ConsensusMessage {
    view: current_view,
    message_type: Commit,
    block: Some(block_reference),
    sender: validator_address,
    mac: ...,
}
```

Once **2f + 1** Commit messages are received, the block is **finalized** — added to the finalized block list and no longer subject to reversion.

### Flow Diagram

```
    Leader          Validator A        Validator B        Validator C
      │                 │                  │                  │
      │── PrePrepare ──▶│──────────────────│──────────────────│
      │                 │── Prepare ──────▶│──────────────────│
      │                 │                  │── Prepare ──────▶│
      │                 │                  │                  │── Prepare ──▶
      │                 │                  │                  │
      │  (2f+1 Prepare received by all)    │                  │
      │                 │                  │                  │
      │                 │── Commit ───────▶│──────────────────│
      │                 │                  │── Commit ───────▶│
      │                 │                  │                  │── Commit ──▶
      │                 │                  │                  │
      │  (2f+1 Commit received → FINALIZED)│                  │
```

---

## Message Types

```rust
enum ConsensusMessageType {
    PrePrepare,    // Leader proposes block
    Prepare,       // Validator acknowledges proposal
    Commit,        // Validator finalizes block
    ViewChange,    // Request leader rotation
}
```

### Message Structure

```rust
struct ConsensusMessage {
    view: u64,                          // Current view number
    message_type: ConsensusMessageType, // Phase
    block: Option<Block>,               // Block data (or reference)
    sender: String,                     // Validator address
    mac: Vec<u8>,                       // Keccak256 keyed MAC
}
```

### MAC Authentication

Messages are authenticated using Keccak256 keyed MAC:

```
mac = Keccak256(shared_key ‖ message_bytes)
```

SHA-3 (Keccak) is safe against length-extension attacks, making it suitable for MAC without HMAC construction.

---

## Leader Selection

Round-robin based on the current view:

```rust
fn get_leader(view: u64, validator_set: &[String]) -> String {
    let index = (view as usize) % validator_set.len();
    validator_set[index].clone()
}
```

The `validator_set` is sorted deterministically by address string, ensuring all nodes agree on the leader for any given view.

### Properties

- **Deterministic** — All nodes calculate the same leader
- **Fair** — Each validator leads equally over time
- **Simple** — No randomness needed (view changes handle failures)

---

## View Change

When the leader fails (timeout or Byzantine behavior), a **view change** is triggered:

### Trigger Conditions

1. **Timeout** — No Pre-Prepare received within `view_change_timeout_ms` (5,000ms)
2. **Invalid block** — Leader proposes an invalid block (signature failure, invalid PoW, etc.)
3. **No progress** — Stuck in Prepare/Commit phase beyond timeout

### Process

```
1. Validator broadcasts ViewChange message with view = current_view + 1
2. Once 2f+1 ViewChange messages received → advance to new view
3. New leader = validator_set[(new_view) % n]
4. Prepare and Commit votes from old view are cleared
5. New leader proposes a block for the new view
6. Normal 3-phase consensus resumes
```

### Liveness Guarantee

As long as fewer than `f+1` validators are faulty, the view change protocol ensures:
- A non-faulty leader will eventually be selected
- The honest majority (2f+1) can always make the view change
- Progress is guaranteed within `O(f)` view changes

---

## Quorum Calculation

### Byzantine Threshold

```rust
fn max_faulty(n: usize) -> usize {
    (n - 1) / 3  // Integer division, rounds down
}

fn quorum_size(n: usize) -> usize {
    let f = max_faulty(n);
    2 * f + 1
}
```

### Safety Proof

For safety, we need `3f < n`:
- With `f = (n-1)/3`, we have `3 × (n-1)/3 = n-1 < n` ✓
- Two conflicting blocks cannot both reach 2f+1 votes because that would require `2(2f+1) = 4f+2 > n` total identities, but only `n` exist, so at least `f+1` would have to vote both ways — but only `f` are faulty.

### Examples

| Validators (n) | Max Faulty (f) | Quorum (2f+1) | Safety margin |
|---|---|---|---|
| 3 | 0 | 1 | Tolerates 0 faults |
| 4 | 1 | 3 | Tolerates 1 fault |
| 7 | 2 | 5 | Tolerates 2 faults |
| 10 | 3 | 7 | Tolerates 3 faults |
| 13 | 4 | 9 | Tolerates 4 faults |
| 100 | 33 | 67 | Tolerates 33 faults |

---

## Quadratic Voting

### Purpose

Standard proof-of-stake gives voting power proportional to stake, enabling whale domination. Quadratic voting uses √stake, making the relationship sub-linear and incentivizing decentralization.

### Formula

```rust
pub fn calculate_voting_power(staked_amount_cil: u128) -> u128 {
    if staked_amount_cil < MIN_STAKE_CIL {
        return 0;
    }
    let clamped = staked_amount_cil.min(MAX_STAKE_FOR_VOTING_CIL);
    isqrt(clamped)
}
```

Where `isqrt` is the deterministic integer square root (Newton's method):

```rust
pub fn isqrt(n: u128) -> u128 {
    if n == 0 { return 0; }
    let mut x = n;
    let mut y = x.div_ceil(2);
    while y < x {
        x = y;
        y = (x + n / x) / 2;
    }
    x
}
```

### Anti-Whale Effectiveness

| Scenario | Total Stake | Voting Power |
|---|---|---|
| 1 whale × 10,000 LOS | 10,000 LOS | ~31,623 |
| 10 validators × 1,000 LOS | 10,000 LOS | 10 × ~10,000 = ~100,000 |

**The distributed validators have 3× more power** with the same total stake. This is the core anti-centralization mechanism.

### Constants

| Constant | Value | Description |
|---|---|---|
| `MIN_STAKE_CIL` | 1,000 LOS in CIL | Below this → 0 voting power |
| `MAX_STAKE_FOR_VOTING_CIL` | Total supply in CIL | Cap to prevent overflow |
| `VOTING_POWER_PRECISION` | 6 decimals | Internal precision |

### Consensus Decision

```rust
// Aggregate votes
votes_for_bps = (Σ voting_power_for × 10_000) / total_voting_power
consensus_reached = votes_for_bps > 5_000  // Strictly > 50%
```

All math in u128 basis points (10,000 = 100%).

---

## Block Finality

A block is considered **final** when:

1. 2f+1 Commit votes received from distinct validators
2. The block passes all validation (PoW, signature, chain sequence, etc.)
3. The view number matches the current consensus view

Once finalized:
- Block is added to `finalized_blocks` (capped at 10,000 in memory)
- Block can never be reverted
- State changes (balance updates, etc.) are permanent

### Finality Time

| Component | Time |
|---|---|
| Pre-Prepare | ~0.5s (consensus + Tor propagation) |
| Prepare collection | ~1s (2f+1 messages over Tor) |
| Commit collection | ~1s (2f+1 messages over Tor) |
| **Total** | **~2-3 seconds** |

---

## Checkpoints

### Purpose

Periodic state checkpoints prevent long-range attacks and enable fast sync for new nodes.

### Interval

```rust
pub const CHECKPOINT_INTERVAL: u64 = 1_000; // Every 1,000 blocks
```

### Checkpoint Structure

```rust
struct FinalityCheckpoint {
    height: u64,           // Block height
    block_hash: String,    // Hash of the checkpoint block
    timestamp: u64,        // Creation time
    validator_count: u32,  // Validators at this height
    state_root: String,    // Merkle root of ledger state
    signature_count: u32,  // Validator signatures collected
}
```

### Quorum Verification

```rust
fn verify_quorum(signature_count: u32, validator_count: u32) -> bool {
    let required = (validator_count as u64 * 67 + 99) / 100; // Ceiling div for 67%
    signature_count as u64 >= required
}
```

Integer ceiling division — no f64.

### Storage

Checkpoints are stored in the sled database, enabling:
- Fast sync (new nodes download latest checkpoint + blocks since)
- Long-range attack prevention (RISK-003 mitigation)
- State verification without replaying entire history

---

## Send Consensus

Standard send transactions go through a lightweight consensus:

### Flow

```
1. Sender creates Send block (signed with Dilithium5)
2. POST /send → validator REST API
3. Validator validates: signature, balance, PoW, fee, chain sequence
4. Block added to sender's account chain
5. Gossip CONFIRM_REQ to all peers
6. Peers validate and return weighted votes
7. Accumulated votes checked against threshold
8. Once threshold met and ≥2 distinct voters → confirmed
9. Receive block auto-created on recipient's chain
10. BLOCK message broadcast to all peers for sync
```

### Threshold

```rust
const SEND_CONSENSUS_THRESHOLD: u128 = 20_000;
const MIN_DISTINCT_VOTERS: usize = 2;
```

The threshold is quadratic voting weight (not count). With 4 validators of 1,000 LOS each, each has `isqrt(1000) ≈ 31` voting power, so 2 validators provide ~62, well below 20,000. The threshold is designed for larger validator sets.

For testnet with small validator counts:
```rust
const TESTNET_FUNCTIONAL_THRESHOLD: u128 = 1;
```

---

## Burn Consensus

Proof-of-Burn requires stronger consensus since it creates new tokens:

### Flow

```
1. User submits burn TX hash via POST /burn
2. Validator gossips VOTE_REQ to all peers
3. Each validator independently:
   a. Fetches burn TX from blockchain explorer
   b. Fetches ETH/BTC price (ORACLE_SUBMIT exchange)
   c. Verifies burn amount and destination
   d. Returns signed VOTE_RES with validation result
4. BFT median aggregation of oracle prices
5. Yield calculation: (burn_usd × remaining) / PUBLIC_SUPPLY_CAP
6. Once ≥ BURN_CONSENSUS_THRESHOLD and ≥2 distinct voters → approved
7. Mint block created on recipient's account chain
8. Distribution state updated (remaining_supply decremented)
```

### Anti-Fraud

- Each validator independently verifies the burn TX on the source chain
- Oracle prices use BFT median (immune to single outlier)
- 20% outlier threshold for price submissions
- Fake burn triggers slashing (100% stake + permanent ban)

---

## Configuration Constants

### Consensus Timing

| Constant | Value | Description |
|---|---|---|
| `block_timeout_ms` | 3,000 | Max time for a consensus round |
| `view_change_timeout_ms` | 5,000 | View change trigger timeout |
| `MAX_FINALIZED_BLOCKS` | 10,000 | In-memory finalized block cap |
| `CHECKPOINT_INTERVAL` | 1,000 | Blocks between checkpoints |

### Voting

| Constant | Value | Description |
|---|---|---|
| `MIN_STAKE_CIL` | 1,000 LOS | Minimum for voting power |
| `SEND_CONSENSUS_THRESHOLD` | 20,000 | Send confirmation threshold |
| `BURN_CONSENSUS_THRESHOLD` | 20,000 | Burn confirmation threshold |
| `MIN_DISTINCT_VOTERS` | 2 | Minimum unique voters |

### Epochs

| Constant | Value | Description |
|---|---|---|
| `REWARD_EPOCH_SECS` | 2,592,000 (30 days) | Mainnet epoch |
| `TESTNET_REWARD_EPOCH_SECS` | 120 (2 min) | Testnet epoch |
| `REWARD_HALVING_INTERVAL_EPOCHS` | 48 | ~4 years between halvings |

---

## Determinism Guarantees

All consensus-critical code enforces strict determinism:

### No Floating Point

- Uses `u128` for all amounts, prices, votes
- `isqrt()` via Newton's method (integer only)
- Basis points (10,000 = 100%) instead of percentages
- `checked_mul`/`checked_add` for overflow protection
- Integer ceiling division: `(a * b + c - 1) / c`

### Verified Values

The following `isqrt` values are verified by unit tests:

```
isqrt(0) = 0
isqrt(1) = 1
isqrt(4) = 2
isqrt(1000) = 31
isqrt(10000) = 100
isqrt(1_000_000) = 1000
```

### Why This Matters

Floating-point arithmetic (`f32`/`f64`) is **not deterministic** across:
- Different CPU architectures (x86 vs ARM)
- Different compiler versions
- Different optimization levels (`-O0` vs `-O3`)
- Different rounding modes

If validators compute slightly different results due to floating-point non-determinism, consensus would fail — validators would disagree on block validity, voting weight, or reward amounts. This is why Unauthority uses exclusively integer math.
