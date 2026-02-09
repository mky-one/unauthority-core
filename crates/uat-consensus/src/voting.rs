// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UNAUTHORITY (UAT) - QUADRATIC VOTING
//
// Task #3b: Anti-Whale Voting Mechanism
// - Voting power = √(Total Stake)
// - Prevents wealth concentration in consensus
// - Enables fair network governance
// - Example: 1 whale(1000) < 10 nodes(100 each) → 31.6 < 100 voting power
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Voting power calculation precision (decimal places)
pub const VOTING_POWER_PRECISION: u32 = 6;

/// Minimum stake required to participate in consensus (1000 UAT minimum)
/// 1 UAT = 100_000_000_000 VOID (10^11 precision)
pub const MIN_STAKE_VOI: u128 = 100_000_000_000_000; // 1000 UAT × 10^11

/// Maximum stake for voting power calculation (prevents overflow)
pub const MAX_STAKE_FOR_VOTING_VOI: u128 = 2_193_623_600_000_000; // Total supply

/// Validator voting information
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ValidatorVote {
    /// Validator address
    pub validator_address: String,

    /// Current staked amount (in VOI)
    pub staked_amount_void: u128,

    /// Calculated voting power (√stake) — deterministic u128 via integer sqrt
    /// SECURITY FIX M-01: Changed from f64 to u128 for cross-platform determinism.
    pub voting_power: u128,

    /// Vote preference (proposition ID or "abstain")
    pub vote_preference: String,

    /// Is validator currently active
    pub is_active: bool,
}

impl ValidatorVote {
    pub fn new(
        validator_address: String,
        staked_amount_void: u128,
        vote_preference: String,
        is_active: bool,
    ) -> Self {
        // SECURITY FIX M-01: Use deterministic u128 integer sqrt, not f64
        let voting_power = calculate_voting_power(staked_amount_void);

        Self {
            validator_address,
            staked_amount_void,
            voting_power,
            vote_preference,
            is_active,
        }
    }
}

/// Calculate voting power using quadratic formula: √(stake in VOI)
///
/// SECURITY P1-4: Uses integer square root for cross-platform determinism.
/// f64::sqrt() can produce different results across CPU architectures.
/// We use Newton's method on u128 for exact deterministic results.
///
/// SECURITY FIX S4: Returns u128 instead of f64 to avoid floating-point
/// truncation when scaling by 1000 in consensus vote accumulation.
/// All callers must use integer arithmetic.
///
/// # Returns
/// Voting power as u128 (deterministic integer sqrt), or 0 if below minimum stake.
pub fn calculate_voting_power(staked_amount_void: u128) -> u128 {
    if staked_amount_void < MIN_STAKE_VOI {
        return 0;
    }

    let clamped_stake = staked_amount_void.min(MAX_STAKE_FOR_VOTING_VOI);
    isqrt(clamped_stake)
}

/// Legacy f64 wrapper — only used for display/logging purposes.
/// NOT for consensus-critical accumulation.
#[deprecated(note = "Use calculate_voting_power() which returns u128 for deterministic consensus")]
pub fn calculate_voting_power_f64(staked_amount_void: u128) -> f64 {
    calculate_voting_power(staked_amount_void) as f64
}

/// Deterministic integer square root using Newton's method.
/// Returns floor(√n) for any u128 value.
fn isqrt(n: u128) -> u128 {
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

/// Normalize voting power to [0, 1] range — DEPRECATED, use basis-point integer math.
///
/// # Arguments
/// * `validator_power` - Individual validator voting power
/// * `total_network_power` - Sum of all validator voting powers
///
/// # Returns
/// Normalized power as fraction (0.0 = no influence, 1.0 = network controls 100%)
#[deprecated(note = "Use integer basis-point normalization instead of f64 fractions")]
pub fn normalize_voting_power(validator_power: f64, total_network_power: f64) -> f64 {
    if total_network_power <= 0.0 {
        return 0.0;
    }
    (validator_power / total_network_power).min(1.0)
}

/// Voting power summary for a network
/// SECURITY FIX M-01: All fields use deterministic integer math.
/// Concentration ratio uses basis points (0-10000 = 0%-100%).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VotingPowerSummary {
    /// Total validators participating
    pub total_validators: u32,

    /// Total network stake (VOI)
    pub total_stake_void: u128,

    /// Total voting power (sum of √stake for all validators) — deterministic u128
    pub total_voting_power: u128,

    /// Validators with voting power
    pub votes: Vec<ValidatorVote>,

    /// Average voting power per validator (integer division, floor)
    pub average_voting_power: u128,

    /// Maximum voting power (richest validator)
    pub max_voting_power: u128,

    /// Minimum voting power (poorest active validator)
    pub min_voting_power: u128,

    /// Power concentration in basis points (max_power * 10000 / total_power)
    /// Lower = more decentralized. 10000 = one validator controls 100%.
    pub concentration_ratio_bps: u32,
}

/// Voting system to calculate and track voting power
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VotingSystem {
    validators: HashMap<String, ValidatorVote>,
}

impl Default for VotingSystem {
    fn default() -> Self {
        Self::new()
    }
}

impl VotingSystem {
    /// Create new voting system
    pub fn new() -> Self {
        Self {
            validators: HashMap::new(),
        }
    }

    /// Register or update a validator
    /// SECURITY FIX M-01: Returns u128 voting power (deterministic)
    pub fn register_validator(
        &mut self,
        validator_address: String,
        staked_amount_void: u128,
        vote_preference: String,
        is_active: bool,
    ) -> Result<u128, String> {
        if staked_amount_void > MAX_STAKE_FOR_VOTING_VOI {
            return Err(format!(
                "Stake {} exceeds maximum {}",
                staked_amount_void, MAX_STAKE_FOR_VOTING_VOI
            ));
        }

        let vote = ValidatorVote::new(
            validator_address.clone(),
            staked_amount_void,
            vote_preference,
            is_active,
        );

        let voting_power = vote.voting_power;
        self.validators.insert(validator_address, vote);

        Ok(voting_power)
    }

    /// Update validator stake (happens during epochs)
    /// SECURITY FIX M-01: Returns u128 voting power (deterministic)
    pub fn update_stake(
        &mut self,
        validator_address: &str,
        new_stake_void: u128,
    ) -> Result<u128, String> {
        let validator = self
            .validators
            .get_mut(validator_address)
            .ok_or_else(|| format!("Validator {} not found", validator_address))?;

        validator.staked_amount_void = new_stake_void;
        validator.voting_power = calculate_voting_power(new_stake_void);

        Ok(validator.voting_power)
    }

    /// Update validator vote preference
    pub fn update_vote_preference(
        &mut self,
        validator_address: &str,
        preference: String,
    ) -> Result<(), String> {
        let validator = self
            .validators
            .get_mut(validator_address)
            .ok_or_else(|| format!("Validator {} not found", validator_address))?;

        validator.vote_preference = preference;
        Ok(())
    }

    /// Get individual validator voting power (deterministic u128)
    pub fn get_validator_power(&self, validator_address: &str) -> Option<u128> {
        self.validators
            .get(validator_address)
            .map(|v| v.voting_power)
    }

    /// Get normalized voting power in basis points (0-10000)
    /// SECURITY FIX M-01: Uses integer math for determinism.
    pub fn get_normalized_power(&self, validator_address: &str) -> Option<u32> {
        let total_power: u128 = self.validators.values().map(|v| v.voting_power).sum();
        if total_power == 0 {
            return Some(0);
        }
        self.validators
            .get(validator_address)
            .map(|v| ((v.voting_power * 10_000) / total_power) as u32)
    }

    /// Calculate voting power summary — all deterministic integer math
    /// SECURITY FIX M-01: Eliminates f64 from governance summary.
    pub fn get_summary(&self) -> VotingPowerSummary {
        let votes: Vec<ValidatorVote> = self
            .validators
            .values()
            .filter(|v| v.is_active)
            .cloned()
            .collect();

        let total_validators = votes.len() as u32;
        let total_stake_void: u128 = votes.iter().map(|v| v.staked_amount_void).sum();
        let total_voting_power: u128 = votes.iter().map(|v| v.voting_power).sum();

        let (max_voting_power, min_voting_power) = if votes.is_empty() {
            (0u128, 0u128)
        } else {
            let max = votes.iter().map(|v| v.voting_power).max().unwrap_or(0);
            let min = votes.iter().map(|v| v.voting_power).min().unwrap_or(0);
            (max, min)
        };

        let average_voting_power = if total_validators > 0 {
            total_voting_power / total_validators as u128
        } else {
            0
        };

        let concentration_ratio_bps = if total_voting_power > 0 {
            ((max_voting_power * 10_000) / total_voting_power) as u32
        } else {
            0
        };

        VotingPowerSummary {
            total_validators,
            total_stake_void,
            total_voting_power,
            votes,
            average_voting_power,
            max_voting_power,
            min_voting_power,
            concentration_ratio_bps,
        }
    }

    /// Reach consensus on a proposal (>50% voting power needed)
    /// SECURITY FIX M-01: Returns (votes_for_u128, percentage_bps_u32, consensus_bool)
    /// percentage_bps: 0-10000 basis points (5000 = 50%, 10000 = 100%)
    /// Consensus requires >5000 bps (strictly greater than 50%)
    pub fn calculate_proposal_consensus(&self, proposal_id: &str) -> (u128, u32, bool) {
        let votes_for: u128 = self
            .validators
            .values()
            .filter(|v| v.is_active && v.vote_preference == proposal_id)
            .map(|v| v.voting_power)
            .sum();

        let total_voting_power: u128 = self
            .validators
            .values()
            .filter(|v| v.is_active)
            .map(|v| v.voting_power)
            .sum();

        let percentage_bps: u32 = if total_voting_power > 0 {
            ((votes_for * 10_000) / total_voting_power) as u32
        } else {
            0
        };

        let consensus_reached = percentage_bps > 5_000; // Strictly > 50%

        (votes_for, percentage_bps, consensus_reached)
    }

    /// Compare voting power distributions (for testing anti-whale effectiveness)
    /// SECURITY FIX M-01: Returns basis points (u32) instead of f64 ratios.
    /// Returns (whale_concentration_bps, distributed_concentration_bps, improvement_bps)
    pub fn compare_scenarios(
        whale_scenario: &[(String, u128)],
        distributed_scenario: &[(String, u128)],
    ) -> (u32, u32, u32) {
        // Whale scenario
        let whale_total_power: u128 = whale_scenario
            .iter()
            .map(|(_, stake)| calculate_voting_power(*stake))
            .sum();

        // Distributed scenario
        let distributed_total_power: u128 = distributed_scenario
            .iter()
            .map(|(_, stake)| calculate_voting_power(*stake))
            .sum();

        let max_whale: u128 = whale_scenario
            .iter()
            .map(|(_, stake)| calculate_voting_power(*stake))
            .max()
            .unwrap_or(0);

        let max_distributed: u128 = distributed_scenario
            .iter()
            .map(|(_, stake)| calculate_voting_power(*stake))
            .max()
            .unwrap_or(0);

        let whale_concentration_bps = if whale_total_power > 0 {
            ((max_whale * 10_000) / whale_total_power) as u32
        } else {
            0
        };

        let distributed_concentration_bps = if distributed_total_power > 0 {
            ((max_distributed * 10_000) / distributed_total_power) as u32
        } else {
            0
        };

        let improvement_bps = if whale_concentration_bps > 0 {
            ((whale_concentration_bps as u64).saturating_sub(distributed_concentration_bps as u64) * 10_000
                / whale_concentration_bps as u64) as u32
        } else {
            0
        };

        (
            whale_concentration_bps,
            distributed_concentration_bps,
            improvement_bps,
        )
    }

    /// Clear all validators
    pub fn clear(&mut self) {
        self.validators.clear();
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#[cfg(test)]
mod tests {
    use super::*;

    // 1 UAT = 100_000_000_000 VOID (10^11)
    // MIN_STAKE_VOI = 1000 UAT = 100_000_000_000_000 VOID (10^14)
    const UAT: u128 = 100_000_000_000; // 10^11 VOID per UAT

    #[test]
    fn test_voting_power_calculation() {
        // 1000 UAT = MIN_STAKE = 100_000_000_000_000 VOID
        let power = calculate_voting_power(1000 * UAT);
        // √(10^14) = 10^7 = 10,000,000
        assert_eq!(power, 10_000_000);

        // 10000 UAT = 1_000_000_000_000_000 VOID
        let power = calculate_voting_power(10_000 * UAT);
        // √(10^15) ≈ 31,622,776 (integer floor)
        assert!(power >= 31_622_776 && power <= 31_622_777);
    }

    #[test]
    fn test_voting_power_below_minimum() {
        // 999 UAT = below MIN_STAKE (1000 UAT)
        let power = calculate_voting_power(999 * UAT);
        assert_eq!(power, 0); // No voting power
    }

    #[test]
    fn test_anti_whale_effectiveness() {
        // Scenario 1: Single whale with 10000 UAT
        let whale_stake = 10_000 * UAT;
        let whale_power = calculate_voting_power(whale_stake);

        // Scenario 2: 10 nodes with 1000 UAT each (minimum stake)
        let node_stake = 1_000 * UAT;
        let nodes_power = calculate_voting_power(node_stake) * 10;

        // Nodes should have significantly more power
        // whale: √(10^15) ≈ 31.6M, nodes: √(10^14)*10 = 10M*10 = 100M
        assert!(nodes_power > whale_power);
        let ratio = nodes_power / whale_power;
        assert!(ratio >= 3); // At least 3x more power
    }

    #[test]
    #[allow(deprecated)]
    fn test_normalize_voting_power() {
        let validator_power = 100_000.0;
        let total_power = 500_000.0;

        let normalized = normalize_voting_power(validator_power, total_power);
        assert_eq!(normalized, 0.2); // 100_000 / 500_000 = 0.2
    }

    #[test]
    fn test_voting_system_registration() {
        let mut system = VotingSystem::new();

        let power = system
            .register_validator(
                "validator1".to_string(),
                1_000 * UAT, // 1000 UAT = minimum stake
                "proposal_1".to_string(),
                true,
            )
            .unwrap();

        assert!(power > 0);
        assert_eq!(system.get_validator_power("validator1"), Some(power));
    }

    #[test]
    fn test_voting_system_summary() {
        let mut system = VotingSystem::new();

        // Add 3 validators with valid stakes (>= 1000 UAT)
        system
            .register_validator("val1".to_string(), 1_000 * UAT, "prop_1".to_string(), true)
            .unwrap();
        system
            .register_validator("val2".to_string(), 1_000 * UAT, "prop_1".to_string(), true)
            .unwrap();
        system
            .register_validator("val3".to_string(), 10_000 * UAT, "prop_1".to_string(), true)
            .unwrap();

        let summary = system.get_summary();

        assert_eq!(summary.total_validators, 3);
        assert!(summary.total_voting_power > 0);
        assert!(summary.average_voting_power > 0);
        assert!(summary.max_voting_power > summary.average_voting_power);
    }

    #[test]
    fn test_consensus_calculation() {
        let mut system = VotingSystem::new();

        // Add validators voting for proposal (all >= 1000 UAT)
        system
            .register_validator(
                "val1".to_string(),
                1_000 * UAT,
                "proposal_1".to_string(),
                true,
            )
            .unwrap();
        system
            .register_validator(
                "val2".to_string(),
                1_000 * UAT,
                "proposal_1".to_string(),
                true,
            )
            .unwrap();
        system
            .register_validator(
                "val3".to_string(),
                1_000 * UAT,
                "proposal_2".to_string(),
                true,
            )
            .unwrap();

        let (votes_for, percentage_bps, consensus) =
            system.calculate_proposal_consensus("proposal_1");

        assert_eq!(votes_for, calculate_voting_power(1_000 * UAT) * 2);
        assert!(percentage_bps > 5_000); // 2/3 validators (≈6666 bps = 66.7%)
        assert!(consensus); // Passed
    }

    #[test]
    fn test_no_consensus_with_split_votes() {
        let mut system = VotingSystem::new();

        // Equal vote split (both >= 1000 UAT)
        system
            .register_validator(
                "val1".to_string(),
                1_000 * UAT,
                "proposal_1".to_string(),
                true,
            )
            .unwrap();
        system
            .register_validator(
                "val2".to_string(),
                1_000 * UAT,
                "proposal_2".to_string(),
                true,
            )
            .unwrap();

        let (_, percentage_bps, consensus) = system.calculate_proposal_consensus("proposal_1");

        assert_eq!(percentage_bps, 5_000); // 50% = 5000 bps
        assert!(!consensus); // Needs > 50%, not ≥ 50%
    }

    #[test]
    fn test_update_stake() {
        let mut system = VotingSystem::new();

        system
            .register_validator("val1".to_string(), 1_000 * UAT, "prop_1".to_string(), true)
            .unwrap();

        let old_power = system.get_validator_power("val1").unwrap();

        // Increase stake (10x)
        system.update_stake("val1", 10_000 * UAT).unwrap();

        let new_power = system.get_validator_power("val1").unwrap();
        assert!(new_power > old_power);
    }

    #[test]
    fn test_concentration_ratio() {
        let mut system = VotingSystem::new();

        // Highly concentrated: whale has 10x more stake
        system
            .register_validator(
                "whale".to_string(),
                10_000 * UAT,
                "prop_1".to_string(),
                true,
            )
            .unwrap();
        system
            .register_validator(
                "small1".to_string(),
                1_000 * UAT,
                "prop_1".to_string(),
                true,
            )
            .unwrap();

        let summary = system.get_summary();
        // Whale voting power: √(10^15) ≈ 31.6M, Small: √(10^14) = 10M
        // Concentration ≈ 31.6M / (31.6M + 10M) ≈ 7600 bps (76%)
        assert!(summary.concentration_ratio_bps > 5_000); // Whale has >50% voting power
    }
}
