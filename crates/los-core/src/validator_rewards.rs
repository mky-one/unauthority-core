// ─────────────────────────────────────────────────────────────────
// Validator Reward System — Epoch-Based Proportional Distribution
// ─────────────────────────────────────────────────────────────────
// Pool:        500,000 LOS (from public allocation)
// Rate:        5,000 LOS/epoch (30 days), halving every 48 epochs (4 yrs)
// Weight:      √stake — consistent with anti-whale system
// Eligibility: 1000 LOS min stake, 95% uptime, 30-day probation passed
// Exclusion:   Genesis bootstrap validators do NOT earn rewards
// Lifespan:    Pool lasts ~16-20 years (asymptotic halving)
// ─────────────────────────────────────────────────────────────────

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::{
    effective_reward_epoch_secs, CIL_PER_LOS, MIN_VALIDATOR_STAKE_CIL,
    REWARD_HALVING_INTERVAL_EPOCHS, REWARD_MIN_UPTIME_PCT, REWARD_PROBATION_EPOCHS,
    REWARD_RATE_INITIAL_CIL, VALIDATOR_REWARD_POOL_CIL,
};

/// Per-validator reward tracking state.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ValidatorRewardState {
    /// Epoch when this validator first registered (0-indexed)
    pub join_epoch: u64,
    /// Total heartbeats sent during the current epoch
    pub heartbeats_current_epoch: u64,
    /// Expected heartbeats for the current epoch (based on epoch duration / heartbeat interval)
    pub expected_heartbeats: u64,
    /// Cumulative rewards received (CIL units)
    pub cumulative_rewards_cil: u128,
    /// Whether this is a genesis bootstrap validator (excluded from rewards)
    pub is_genesis: bool,
    /// Current stake snapshot ( CIL) — updated each epoch from ledger
    pub stake_cil: u128,
}

impl ValidatorRewardState {
    pub fn new(join_epoch: u64, is_genesis: bool, stake_cil: u128) -> Self {
        Self {
            join_epoch,
            heartbeats_current_epoch: 0,
            expected_heartbeats: 0,
            cumulative_rewards_cil: 0,
            is_genesis,
            stake_cil,
        }
    }

    /// Uptime percentage for the current epoch (0–100)
    /// Uses pure integer math — no floating point.
    pub fn uptime_pct(&self) -> u64 {
        if self.expected_heartbeats == 0 {
            return 0;
        }
        // Integer: (heartbeats * 100) / expected, capped at 100
        let pct = (self.heartbeats_current_epoch * 100) / self.expected_heartbeats;
        pct.min(100)
    }

    /// Returns true if this validator is eligible for rewards this epoch.
    /// Requirements:
    /// 1. NOT a genesis bootstrap validator (mainnet only — testnet allows genesis)
    /// 2. Past probation period (at least 1 epoch since join)
    /// 3. Meets minimum uptime (95%)
    /// 4. Meets minimum stake (1000 LOS)
    pub fn is_eligible(&self, current_epoch: u64) -> bool {
        // Mainnet: genesis bootstrap validators never earn rewards
        // Testnet: genesis validators ARE eligible (otherwise no one can test rewards)
        if self.is_genesis && !crate::is_testnet_build() {
            return false;
        }
        if current_epoch < self.join_epoch + REWARD_PROBATION_EPOCHS {
            return false;
        }
        if self.uptime_pct() < REWARD_MIN_UPTIME_PCT {
            return false;
        }
        if self.stake_cil < MIN_VALIDATOR_STAKE_CIL {
            return false;
        }
        true
    }

    /// Quadratic voting weight: √(stake in LOS units)
    /// Uses integer square root to avoid floating-point determinism issues.
    pub fn sqrt_stake_weight(&self) -> u128 {
        let stake_los = self.stake_cil / CIL_PER_LOS;
        isqrt(stake_los)
    }
}

/// Global reward pool and epoch tracking state.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ValidatorRewardPool {
    /// Remaining CIL in the reward pool
    pub remaining_cil: u128,
    /// Current epoch number (starts at 0)
    pub current_epoch: u64,
    /// Timestamp when the current epoch started (Unix seconds)
    pub epoch_start_timestamp: u64,
    /// Number of halvings that have occurred
    pub halvings_occurred: u64,
    /// Total CIL distributed across all epochs
    pub total_distributed_cil: u128,
    /// Per-validator reward state (keyed by address)
    pub validators: HashMap<String, ValidatorRewardState>,
    /// Epoch duration in seconds (testnet=120, mainnet=2592000)
    /// Defaults to effective_reward_epoch_secs() if not present (backwards-compatible).
    #[serde(default = "default_epoch_duration")]
    pub epoch_duration_secs: u64,
}

fn default_epoch_duration() -> u64 {
    effective_reward_epoch_secs()
}

impl ValidatorRewardPool {
    /// Create a new reward pool with full funding.
    /// `genesis_timestamp` = network genesis time (Unix seconds).
    pub fn new(genesis_timestamp: u64) -> Self {
        Self {
            remaining_cil: VALIDATOR_REWARD_POOL_CIL,
            current_epoch: 0,
            epoch_start_timestamp: genesis_timestamp,
            halvings_occurred: 0,
            total_distributed_cil: 0,
            validators: HashMap::new(),
            epoch_duration_secs: effective_reward_epoch_secs(),
        }
    }

    /// Create from a custom initial balance (for testing or partial funding).
    pub fn with_balance(genesis_timestamp: u64, balance_cil: u128) -> Self {
        Self {
            remaining_cil: balance_cil,
            current_epoch: 0,
            epoch_start_timestamp: genesis_timestamp,
            halvings_occurred: 0,
            total_distributed_cil: 0,
            validators: HashMap::new(),
            epoch_duration_secs: effective_reward_epoch_secs(),
        }
    }

    /// Register a validator for reward tracking.
    /// If already registered, updates stake and genesis status.
    pub fn register_validator(&mut self, address: &str, is_genesis: bool, stake_cil: u128) {
        self.validators
            .entry(address.to_string())
            .and_modify(|v| {
                v.stake_cil = stake_cil;
                v.is_genesis = is_genesis;
            })
            .or_insert_with(|| {
                ValidatorRewardState::new(self.current_epoch, is_genesis, stake_cil)
            });
    }

    /// Record a heartbeat from a validator (proving liveness).
    pub fn record_heartbeat(&mut self, address: &str) {
        if let Some(state) = self.validators.get_mut(address) {
            state.heartbeats_current_epoch += 1;
        }
    }

    /// Calculate the reward rate for the current epoch (with halving).
    /// Rate halves every `REWARD_HALVING_INTERVAL_EPOCHS` epochs.
    /// After n halvings: rate = initial_rate >> n
    pub fn epoch_reward_rate(&self) -> u128 {
        let halvings = self.current_epoch / REWARD_HALVING_INTERVAL_EPOCHS;
        if halvings >= 128 {
            return 0; // Effectively zero after 128 halvings
        }
        REWARD_RATE_INITIAL_CIL >> halvings
    }

    /// Check if the current epoch has ended (based on timestamp).
    pub fn is_epoch_complete(&self, now_secs: u64) -> bool {
        now_secs >= self.epoch_start_timestamp + self.epoch_duration_secs
    }

    /// How many seconds remain in the current epoch.
    pub fn epoch_remaining_secs(&self, now_secs: u64) -> u64 {
        let end = self.epoch_start_timestamp + self.epoch_duration_secs;
        end.saturating_sub(now_secs)
    }

    /// Fast-forward through missed epochs (e.g., after node restart).
    /// Skips all fully-elapsed epochs without distributing rewards for them,
    /// since nobody was online to earn them. Returns number of epochs skipped.
    pub fn catch_up_epochs(&mut self, now_secs: u64) -> u64 {
        if self.epoch_duration_secs == 0 {
            return 0;
        }
        let elapsed = now_secs.saturating_sub(self.epoch_start_timestamp);
        let epochs_behind = elapsed / self.epoch_duration_secs;
        if epochs_behind <= 1 {
            return 0; // Current epoch or just one behind — normal processing
        }
        // Skip all but the current epoch (no rewards for missed epochs)
        let skip = epochs_behind - 1;
        self.current_epoch += skip;
        self.epoch_start_timestamp += skip * self.epoch_duration_secs;
        self.halvings_occurred = self.current_epoch / REWARD_HALVING_INTERVAL_EPOCHS;
        // Reset heartbeats since nobody was online
        for state in self.validators.values_mut() {
            state.heartbeats_current_epoch = 0;
            state.expected_heartbeats = 0;
        }
        skip
    }

    /// Set expected heartbeats for all validators at the start of an epoch.
    /// `heartbeat_interval_secs` = time between heartbeats (e.g., 60s).
    pub fn set_expected_heartbeats(&mut self, heartbeat_interval_secs: u64) {
        let expected = if heartbeat_interval_secs > 0 {
            self.epoch_duration_secs / heartbeat_interval_secs
        } else {
            0
        };
        for state in self.validators.values_mut() {
            state.expected_heartbeats = expected;
        }
    }

    /// Distribute rewards for the completed epoch.
    ///
    /// Returns a Vec of (address, reward_cil) for each validator that received rewards.
    /// The caller is responsible for crediting these amounts to the ledger.
    ///
    /// After distribution, advances to the next epoch and resets heartbeat counters.
    pub fn distribute_epoch_rewards(&mut self) -> Vec<(String, u128)> {
        let epoch_rate = self.epoch_reward_rate();
        if epoch_rate == 0 || self.remaining_cil == 0 {
            self.advance_epoch();
            return vec![];
        }

        // Cap at remaining pool balance
        let budget = epoch_rate.min(self.remaining_cil);

        // Collect eligible validators and their √stake weights
        let eligible: Vec<(String, u128)> = self
            .validators
            .iter()
            .filter(|(_, v)| v.is_eligible(self.current_epoch))
            .map(|(addr, v)| (addr.clone(), v.sqrt_stake_weight()))
            .filter(|(_, w)| *w > 0)
            .collect();

        if eligible.is_empty() {
            // No eligible validators this epoch — budget stays in pool
            self.advance_epoch();
            return vec![];
        }

        let total_weight: u128 = eligible.iter().map(|(_, w)| w).sum();
        if total_weight == 0 {
            self.advance_epoch();
            return vec![];
        }

        // Proportional distribution: reward_i = budget × (weight_i / total_weight)
        let mut rewards: Vec<(String, u128)> = Vec::new();
        let mut actually_distributed: u128 = 0;

        for (addr, weight) in &eligible {
            // Use u128 multiplication then divide to avoid overflow:
            // reward = (budget * weight) / total_weight
            // We use checked arithmetic to prevent any overflow
            let reward = budget
                .checked_mul(*weight)
                .map(|prod| prod / total_weight)
                .unwrap_or(0);

            if reward > 0 {
                rewards.push((addr.clone(), reward));
                actually_distributed += reward;
            }
        }

        // Deduct from pool
        self.remaining_cil = self.remaining_cil.saturating_sub(actually_distributed);
        self.total_distributed_cil += actually_distributed;

        // Update per-validator cumulative totals
        for (addr, reward) in &rewards {
            if let Some(state) = self.validators.get_mut(addr) {
                state.cumulative_rewards_cil += reward;
            }
        }

        self.advance_epoch();
        rewards
    }

    /// Advance to the next epoch: increment counter, reset heartbeats, update halvings.
    fn advance_epoch(&mut self) {
        self.current_epoch += 1;
        self.epoch_start_timestamp += self.epoch_duration_secs;
        self.halvings_occurred = self.current_epoch / REWARD_HALVING_INTERVAL_EPOCHS;

        // Reset heartbeat counters for the new epoch
        for state in self.validators.values_mut() {
            state.heartbeats_current_epoch = 0;
            state.expected_heartbeats = 0;
        }
    }

    /// Get reward info for a specific validator.
    pub fn validator_info(&self, address: &str) -> Option<&ValidatorRewardState> {
        self.validators.get(address)
    }

    /// Summary stats for the reward pool.
    pub fn pool_summary(&self) -> RewardPoolSummary {
        let eligible_count = self
            .validators
            .values()
            .filter(|v| v.is_eligible(self.current_epoch))
            .count() as u64;
        let total_validators = self.validators.len() as u64;

        RewardPoolSummary {
            remaining_cil: self.remaining_cil,
            total_distributed_cil: self.total_distributed_cil,
            current_epoch: self.current_epoch,
            epoch_reward_rate_cil: self.epoch_reward_rate(),
            halvings_occurred: self.halvings_occurred,
            total_validators,
            eligible_validators: eligible_count,
            pool_exhaustion_bps: if VALIDATOR_REWARD_POOL_CIL > 0 {
                // Basis points (10000 = 100%) — pure integer math
                ((VALIDATOR_REWARD_POOL_CIL - self.remaining_cil) * 10_000
                    / VALIDATOR_REWARD_POOL_CIL) as u64
            } else {
                0
            },
        }
    }
}

/// Serializable summary of reward pool state (for /reward-info endpoint).
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RewardPoolSummary {
    pub remaining_cil: u128,
    pub total_distributed_cil: u128,
    pub current_epoch: u64,
    pub epoch_reward_rate_cil: u128,
    pub halvings_occurred: u64,
    pub total_validators: u64,
    pub eligible_validators: u64,
    /// Pool exhaustion in basis points (10000 = 100%), pure integer
    pub pool_exhaustion_bps: u64,
}

// ─────────────────────────────────────────────────────────────────
// Integer square root (Newton's method) — deterministic across platforms
// ─────────────────────────────────────────────────────────────────
pub fn isqrt(n: u128) -> u128 {
    if n == 0 {
        return 0;
    }
    let mut x = n;
    let mut y = x.div_ceil(2);
    while y < x {
        x = y;
        y = (x + n / x) / 2;
    }
    x
}

// ─────────────────────────────────────────────────────────────────
// Unit Tests
// ─────────────────────────────────────────────────────────────────
#[cfg(test)]
mod tests {
    use super::*;

    const GENESIS_TS: u64 = 1_770_580_908; // Same as genesis_config.json

    #[test]
    fn test_isqrt() {
        assert_eq!(isqrt(0), 0);
        assert_eq!(isqrt(1), 1);
        assert_eq!(isqrt(4), 2);
        assert_eq!(isqrt(9), 3);
        assert_eq!(isqrt(100), 10);
        assert_eq!(isqrt(1000), 31); // √1000 ≈ 31.6
        assert_eq!(isqrt(10000), 100);
        assert_eq!(isqrt(1_000_000), 1000);
    }

    #[test]
    fn test_pool_creation() {
        let pool = ValidatorRewardPool::new(GENESIS_TS);
        assert_eq!(pool.remaining_cil, 500_000 * CIL_PER_LOS);
        assert_eq!(pool.current_epoch, 0);
        assert_eq!(pool.total_distributed_cil, 0);
    }

    #[test]
    fn test_epoch_reward_rate_halving() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        // Epoch 0: full rate
        assert_eq!(pool.epoch_reward_rate(), 5_000 * CIL_PER_LOS);

        // Advance to epoch 48 (first halving)
        pool.current_epoch = 48;
        assert_eq!(pool.epoch_reward_rate(), 2_500 * CIL_PER_LOS);

        // Epoch 96 (second halving)
        pool.current_epoch = 96;
        assert_eq!(pool.epoch_reward_rate(), 1_250 * CIL_PER_LOS);

        // Epoch 144 (third halving)
        pool.current_epoch = 144;
        assert_eq!(pool.epoch_reward_rate(), 625 * CIL_PER_LOS);
    }

    #[test]
    fn test_genesis_validators_excluded() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        let genesis_addr = "LOSgenesis1";
        let normal_addr = "LOSnormal1";

        pool.register_validator(genesis_addr, true, 1000 * CIL_PER_LOS);
        pool.register_validator(normal_addr, false, 1000 * CIL_PER_LOS);

        // Advance past probation
        pool.current_epoch = 2;

        // Set heartbeats to 100% uptime
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }

        let genesis_state = pool.validators.get(genesis_addr).unwrap();
        // Testnet: genesis validators ARE eligible (for testing rewards)
        // Mainnet: genesis validators are excluded from rewards
        if crate::is_testnet_build() {
            assert!(genesis_state.is_eligible(pool.current_epoch));
        } else {
            assert!(!genesis_state.is_eligible(pool.current_epoch));
        }

        let normal_state = pool.validators.get(normal_addr).unwrap();
        assert!(normal_state.is_eligible(pool.current_epoch));
    }

    #[test]
    fn test_probation_period() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        let addr = "LOSvalidator1";

        pool.register_validator(addr, false, 2000 * CIL_PER_LOS);
        pool.set_expected_heartbeats(60);

        // During epoch 0 (join epoch) — still in probation
        {
            let v = pool.validators.get_mut(addr).unwrap();
            v.heartbeats_current_epoch = v.expected_heartbeats; // 100% uptime
        }
        assert!(!pool.validators.get(addr).unwrap().is_eligible(0));

        // Epoch 1 — past probation → eligible
        pool.current_epoch = 1;
        {
            let v = pool.validators.get_mut(addr).unwrap();
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }
        assert!(pool.validators.get(addr).unwrap().is_eligible(1));
    }

    #[test]
    fn test_uptime_requirement() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        let addr = "LOSvalidator2";

        pool.register_validator(addr, false, 1000 * CIL_PER_LOS);
        pool.current_epoch = 2;
        // Use heartbeat interval of 1s so we get enough heartbeats
        // for meaningful uptime calculation (epoch_duration / 1 = epoch_duration)
        pool.set_expected_heartbeats(1);

        // 90% uptime — below 95% threshold
        {
            let v = pool.validators.get_mut(addr).unwrap();
            let expected = v.expected_heartbeats;
            v.heartbeats_current_epoch = expected * 90 / 100;
        }
        assert!(!pool.validators.get(addr).unwrap().is_eligible(2));

        // 95% uptime — meets threshold
        {
            let v = pool.validators.get_mut(addr).unwrap();
            let expected = v.expected_heartbeats;
            v.heartbeats_current_epoch = expected * 95 / 100;
        }
        assert!(pool.validators.get(addr).unwrap().is_eligible(2));
    }

    #[test]
    fn test_sqrt_stake_weight() {
        let v1 = ValidatorRewardState::new(0, false, 1_000 * CIL_PER_LOS);
        let v2 = ValidatorRewardState::new(0, false, 10_000 * CIL_PER_LOS);

        // √1000 ≈ 31, √10000 = 100
        // So 10× the stake gives only ~3.2× the weight
        assert_eq!(v1.sqrt_stake_weight(), 31);
        assert_eq!(v2.sqrt_stake_weight(), 100);
    }

    #[test]
    fn test_distribute_epoch_rewards() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);

        // Register 3 validators: 1 genesis (excluded), 2 normal
        pool.register_validator("LOSgenesis_v1", true, 1000 * CIL_PER_LOS);
        pool.register_validator("LOSnormal_v1", false, 1000 * CIL_PER_LOS);
        pool.register_validator("LOSnormal_v2", false, 4000 * CIL_PER_LOS);

        // Advance past probation (epoch 2)
        pool.current_epoch = 2;
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats; // 100% uptime
        }

        let initial_remaining = pool.remaining_cil;
        let rewards = pool.distribute_epoch_rewards();

        // Testnet: all 3 validators eligible (genesis included)
        // Mainnet: only 2 non-genesis validators
        if crate::is_testnet_build() {
            assert_eq!(rewards.len(), 3);
        } else {
            assert_eq!(rewards.len(), 2);
            assert!(!rewards.iter().any(|(addr, _)| addr == "LOSgenesis_v1"));
        }

        // √1000 ≈ 31, √4000 ≈ 63 → total = 94
        // v1 gets ~31/94 of 5000 LOS ≈ 1648 LOS
        // v2 gets ~63/94 of 5000 LOS ≈ 3351 LOS
        let total_rewarded: u128 = rewards.iter().map(|(_, r)| r).sum();
        assert!(total_rewarded > 0);
        assert!(total_rewarded <= 5_000 * CIL_PER_LOS);

        // Pool should be reduced
        assert_eq!(pool.remaining_cil, initial_remaining - total_rewarded);
        assert_eq!(pool.total_distributed_cil, total_rewarded);

        // Epoch should have advanced
        assert_eq!(pool.current_epoch, 3);
    }

    #[test]
    fn test_no_eligible_validators_preserves_pool() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);

        // Only genesis validators
        pool.register_validator("LOSgenesis_v1", true, 1000 * CIL_PER_LOS);
        pool.current_epoch = 5;
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }

        let initial_remaining = pool.remaining_cil;
        let rewards = pool.distribute_epoch_rewards();

        if crate::is_testnet_build() {
            // Testnet: genesis validators CAN earn rewards
            assert_eq!(rewards.len(), 1);
        } else {
            // Mainnet: genesis validators excluded → no eligible → no rewards
            assert!(rewards.is_empty());
            assert_eq!(pool.remaining_cil, initial_remaining); // Nothing deducted
        }
        assert_eq!(pool.current_epoch, 6); // Epoch still advances
    }

    #[test]
    fn test_pool_exhaustion_cap() {
        // Create a pool with only 1000 LOS remaining
        let mut pool = ValidatorRewardPool::with_balance(GENESIS_TS, 1_000 * CIL_PER_LOS);

        pool.register_validator("LOSval1", false, 2000 * CIL_PER_LOS);
        pool.current_epoch = 2;
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }

        // Rate is 5000 LOS but only 1000 available — should cap at 1000
        let rewards = pool.distribute_epoch_rewards();
        let total: u128 = rewards.iter().map(|(_, r)| r).sum();
        assert!(total <= 1_000 * CIL_PER_LOS);
    }

    #[test]
    fn test_epoch_timing() {
        let pool = ValidatorRewardPool::new(GENESIS_TS);
        let epoch_dur = pool.epoch_duration_secs;

        // Not complete at start
        assert!(!pool.is_epoch_complete(GENESIS_TS));
        assert!(!pool.is_epoch_complete(GENESIS_TS + epoch_dur - 1));

        // Complete at exactly epoch boundary
        assert!(pool.is_epoch_complete(GENESIS_TS + epoch_dur));

        // Remaining seconds
        assert_eq!(pool.epoch_remaining_secs(GENESIS_TS), epoch_dur);
        assert_eq!(pool.epoch_remaining_secs(GENESIS_TS + 10), epoch_dur - 10);
        assert_eq!(pool.epoch_remaining_secs(GENESIS_TS + epoch_dur), 0);
    }

    #[test]
    fn test_heartbeat_recording() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        pool.register_validator("LOSval1", false, 1000 * CIL_PER_LOS);

        pool.record_heartbeat("LOSval1");
        pool.record_heartbeat("LOSval1");
        pool.record_heartbeat("LOSval1");

        assert_eq!(
            pool.validators
                .get("LOSval1")
                .unwrap()
                .heartbeats_current_epoch,
            3
        );

        // Recording heartbeat for unknown validator is a no-op
        pool.record_heartbeat("LOSunknown");
    }

    #[test]
    fn test_pool_summary() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);
        pool.register_validator("LOSgenesis", true, 1000 * CIL_PER_LOS);
        pool.register_validator("LOSval1", false, 2000 * CIL_PER_LOS);
        pool.current_epoch = 2;
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }

        let summary = pool.pool_summary();
        assert_eq!(summary.total_validators, 2);
        if crate::is_testnet_build() {
            // On testnet, genesis validators ARE eligible
            assert_eq!(summary.eligible_validators, 2);
        } else {
            // On mainnet, genesis validators are excluded
            assert_eq!(summary.eligible_validators, 1);
        }
        assert_eq!(summary.current_epoch, 2);
        assert_eq!(summary.epoch_reward_rate_cil, 5_000 * CIL_PER_LOS);
    }

    #[test]
    fn test_minimum_stake_requirement() {
        let mut pool = ValidatorRewardPool::new(GENESIS_TS);

        // Register with less than 1000 LOS stake
        pool.register_validator("LOSpoor", false, 500 * CIL_PER_LOS);
        pool.current_epoch = 2;
        pool.set_expected_heartbeats(60);
        for v in pool.validators.values_mut() {
            v.heartbeats_current_epoch = v.expected_heartbeats;
        }

        assert!(!pool.validators.get("LOSpoor").unwrap().is_eligible(2));
    }
}
