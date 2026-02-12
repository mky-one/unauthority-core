# LOS Testnet E2E Bug Report

**Date:** 2026-02-12  
**Binary Version:** v1.0.9  
**Environment:** 4 validators on Tor Hidden Services (.onion), macOS  
**Testnet Epoch:** 120 seconds  
**Unit Tests:** 241/241 passed, 0 failures, 0 warnings  

---

## Summary

Comprehensive end-to-end testnet simulation across all APIs, consensus, rewards, fees, slashing, node recovery, and validator registration. **3 critical bugs were found and fixed.** After fixes, the testnet achieved 100% cross-node consistency across all 4 validators.

---

## Bugs Found & Fixed This Session

### BUG #1: False Double-Sign Slashing (CRITICAL)

**Severity:** CRITICAL — caused validators to lose 100% of their balance  
**File:** [crates/los-node/src/main.rs](crates/los-node/src/main.rs#L6456)  

**Symptoms:**
- V2 and V4 balances dropped to 0 LOS after running for several epochs
- Slashing events showed `DOUBLE_SIGN` penalties of 17,250+ LOS
- V1 and V3 were unaffected

**Root Cause:**
When the epoch leader creates REWARD + FEE_REWARD Mint blocks for the same validator, both blocks target the same `block_count` (height). When gossipped to peers, the second block triggers the double-sign detection because `record_signature()` in [crates/los-consensus/src/slashing.rs](crates/los-consensus/src/slashing.rs#L180) sees two different blocks at the same height for the same validator.

These are **system-created** blocks (Mint type) — the validator never signed them. The double-sign check was incorrectly applied to blocks the validator didn't author.

**Fix:**
```rust
// Before double-sign check, skip system blocks
let is_system_block = matches!(
    inc.block_type,
    BlockType::Mint | BlockType::Slash
);
if !is_system_block {
    // ... existing double-sign detection ...
}
```

**Verification:** 0 slash events after 15+ epochs with send transactions.

---

### BUG #2: Metrics `active_validators` Always 0 (MEDIUM)

**Severity:** MEDIUM — monitoring showed 0 active validators despite 4 running  
**File:** [crates/los-node/src/metrics.rs](crates/los-node/src/metrics.rs#L429)  

**Root Cause:**
The `los_active_validators` IntGauge was defined but never set in `update_blockchain_metrics()`. The function updated blocks, accounts, supply, etc. but omitted the validator count.

**Fix:**
Added count of accounts where `is_validator == true && balance >= MIN_VALIDATOR_STAKE_CIL` in the metrics update function.

**Verification:** `los_active_validators 4` confirmed in metrics output.

---

### BUG #3: Gossip Propagation Lag / State Drift (MEDIUM)

**Severity:** MEDIUM — some nodes permanently behind by 2+ blocks  
**File:** [crates/los-node/src/main.rs](crates/los-node/src/main.rs#L4766)  

**Symptoms:**
- V4 persistently 2 blocks behind for V2 and V3's accounts
- All other nodes (V1, V2, V3) agreed perfectly
- The gap never closed

**Root Cause:**
State sync (SYNC_REQUEST) only ran **once** at startup. If GossipSub dropped a message (common in P2P networks), the node permanently missed that block. There was no mechanism to detect or recover from missed gossip messages.

**Fix:**
Added periodic `SYNC_REQUEST` every 2 minutes (every 4th tick of the 30-second peer re-announce interval). Each cycle sends a compressed sync request to random peers to fill any gaps.

```rust
// In the periodic re-announce loop (every 30s):
sync_counter += 1;
if sync_counter % 4 == 0 {
    // Every 2 minutes: send SYNC_REQUEST to catch dropped gossip
    // ... broadcast SYNC_REQUEST via GossipSub ...
}
```

**Verification:**
- After fix: All 4 nodes achieve 100% identical state (balances, blocks, head hashes)
- V3 killed for 130+ seconds → restarted → caught up from 22 to 62 blocks via periodic sync
- Cross-node consistency: PERFECT after recovery

---

## Test Results Summary

### Consensus & Transactions ✅
| Test | Result |
|------|--------|
| Send 50 LOS V1→Dev2 via Tor | ✅ Confirmed, fee=0.000001 LOS |
| Cross-node propagation | ✅ All 4 nodes see identical state |
| Consensus Level 2 voting | ✅ MIN_DISTINCT_VOTERS=2, THRESHOLD=20000 |

### Validator Rewards ✅
| Test | Result |
|------|--------|
| Epoch reward creation | ✅ 1,250 LOS/validator/epoch (5000÷4 √stake weighted) |
| Multiple epochs (15+) | ✅ Correct cumulative rewards, no drift |
| Reward pool tracking | ✅ Pool distributed=70,000 LOS, remaining=430,000 LOS |
| Cross-node reward consistency | ✅ All nodes agree on all balances |

### Fee Distribution ✅
| Test | Result |
|------|--------|
| Fee collection on send | ✅ 0.000001 LOS fee deducted from sender |
| FEE_REWARD distribution | ✅ ~0.00000025 LOS to each of 4 validators |
| Fee balance consistency | ✅ All nodes show identical fee rewards |

### Slashing ✅
| Test | Result |
|------|--------|
| False positive detection | ✅ FIXED — 0 events after 15+ epochs |
| Slashing status API | ✅ events=0, banned=0 |

### Node Kill & Recovery ✅
| Test | Result |
|------|--------|
| Kill V3 (1 of 4 validators) | ✅ Network continues with 3/4 nodes |
| Reward accrual while down | ✅ V3 still receives rewards (other nodes track V3's state) |
| V3 restart + sync | ✅ Caught up from 22→62 blocks via periodic sync |
| Post-recovery consistency | ✅ All 4 nodes 100% identical after recovery |

### Validator Registration ✅
| Test | Result |
|------|--------|
| Wrong signature | ✅ Rejected |
| Wrong public key | ✅ Rejected |
| Stale timestamp | ✅ Rejected (as "Signature verification failed") |
| Invalid address | ✅ Rejected |
| Already registered | ✅ Rejected |

### Metrics ✅
| Metric | Value |
|--------|-------|
| `los_active_validators` | 4 |
| `los_blocks_total` | 62 |
| `los_accounts_total` | 6 |
| `los_slashing_events_total` | 0 |
| `los_mint_blocks_total` | 60+ |

---

## Known Issues (Non-Critical)

### 1. `connected_peers` Always Shows `false` in `/network/peers`
**Severity:** LOW (cosmetic)  
The `connected` field in peer info always returns `false` even when peers are actively exchanging blocks via GossipSub. This is a reporting issue, not a connectivity issue.

### 2. `stake_los` Shows 0 in `/network/peers`
**Severity:** LOW (cosmetic)  
Peer stake information is not populated in the peer info response. The actual stake is tracked correctly internally.

### 3. Validator Registration Error Message for Stale Timestamp
**Severity:** LOW (UX)  
When a re-registration request has a stale timestamp, the error says "Signature verification failed" instead of "Timestamp too old". This is because signature verification (which includes timestamp in the signing hash) runs before the timestamp check.

### 4. V2 Always Epoch Leader
**Severity:** LOW (testnet-only)  
In this 4-validator testnet, V2 was selected as epoch leader for ALL epochs. The leader selection algorithm may need review for better distribution, though this could be an artifact of the small validator set + specific stake weights.

### 5. API Request Metrics Not Populated
**Severity:** LOW  
`los_api_requests_total`, `los_api_request_duration_seconds_*` always show 0. The warp request counter middleware may not be wired in.

---

## Final State After All Fixes

```
Epoch: 15
Validators: 4/4 active, 0 slashed, 0 banned

V1: 18,449.999999 LOS (16 blocks) — sender, has tx fee deductions
V2: 18,500.000000 LOS (15 blocks) — epoch leader
V3: 18,500.000000 LOS (15 blocks) — recovered from kill
V4: 18,500.000000 LOS (15 blocks) — previously lagging, now synced

Dev1: 428,113 LOS (genesis, untouched)
Dev2: 245,760 LOS (genesis 245,710 + 50 received)

Reward Pool: 430,000 LOS remaining / 500,000 LOS total
Cross-Node Consistency: 100% — ALL nodes agree on ALL balances
Unit Tests: 241/241 passed, 0 failures
```

---

## Changes Made

| File | Change | Lines |
|------|--------|-------|
| [crates/los-node/src/main.rs](crates/los-node/src/main.rs#L6456) | Skip double-sign check for system blocks | ~6456 |
| [crates/los-node/src/main.rs](crates/los-node/src/main.rs#L4766) | Periodic SYNC_REQUEST every 2 min | ~4766 |
| [crates/los-node/src/metrics.rs](crates/los-node/src/metrics.rs#L429) | Set `active_validators` gauge | ~429 |
