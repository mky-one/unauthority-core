use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Anti-Whale Mechanisms for Unauthority
/// Prevents single entities from dominating the network through:
/// - Dynamic fee scaling on spam
/// - Quadratic voting power (stake^0.5)
/// - Burn limits per block

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AntiWhaleConfig {
    pub max_tx_per_block: u32,     // Max transactions per block per address
    pub fee_scale_multiplier: u64, // Fee multiplier base when spam detected (integer)
    pub max_burn_per_block: u64,   // Max UAT burned per block per address
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddressActivity {
    pub tx_count: u32,
    pub total_burned: u64,
    pub last_block: u64,
    pub fee_multiplier: u64,
    /// Timestamp of the start of the current activity window (Unix seconds)
    pub window_start: u64,
}

pub struct AntiWhaleEngine {
    pub config: AntiWhaleConfig,
    address_activity: HashMap<String, AddressActivity>,
    current_block: u64,
}

impl AntiWhaleConfig {
    pub fn new() -> Self {
        AntiWhaleConfig {
            max_tx_per_block: 5,
            fee_scale_multiplier: 2,
            max_burn_per_block: 1_000,
        }
    }
}

impl Default for AntiWhaleConfig {
    fn default() -> Self {
        Self::new()
    }
}

impl AntiWhaleEngine {
    /// Create new anti-whale engine
    pub fn new(config: AntiWhaleConfig) -> Self {
        AntiWhaleEngine {
            config,
            address_activity: HashMap::new(),
            current_block: 0,
        }
    }

    /// Activity window duration in seconds (counters reset after this period)
    pub const ACTIVITY_WINDOW_SECS: u64 = 60;

    /// Read-only access to the anti-whale config
    pub fn config(&self) -> &AntiWhaleConfig {
        &self.config
    }

    /// Get current Unix timestamp
    fn now_secs() -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }

    /// Reset activity if the time window has elapsed
    fn maybe_reset_activity(activity: &mut AddressActivity) {
        let now = Self::now_secs();
        if now.saturating_sub(activity.window_start) >= Self::ACTIVITY_WINDOW_SECS {
            activity.tx_count = 0;
            activity.total_burned = 0;
            activity.fee_multiplier = 1;
            activity.window_start = now;
        }
    }

    /// Advance to next block and reset activity counters
    pub fn new_block(&mut self, block_number: u64) {
        self.current_block = block_number;

        // Reset counters for this block
        for activity in self.address_activity.values_mut() {
            if activity.last_block < block_number {
                activity.tx_count = 0;
                activity.total_burned = 0;
                activity.fee_multiplier = 1;
                activity.last_block = block_number;
                activity.window_start = Self::now_secs();
            }
        }
    }

    /// Estimate the fee for the NEXT transaction from this address.
    /// Read-only — does NOT register the transaction or modify state.
    /// Used by /fee-estimate endpoint so wallets can pre-fetch dynamic fee.
    pub fn estimate_fee(&self, address: &str, base_fee: u64) -> u64 {
        let multiplier = match self.address_activity.get(address) {
            Some(activity) => {
                let now = Self::now_secs();
                // Check if window has expired (would reset)
                if now.saturating_sub(activity.window_start) >= Self::ACTIVITY_WINDOW_SECS {
                    1 // Window expired, fee resets to 1×
                } else if activity.tx_count >= self.config.max_tx_per_block {
                    // Would trigger scaling on next tx
                    let excess = activity.tx_count - self.config.max_tx_per_block;
                    self.config.fee_scale_multiplier.saturating_pow(excess + 1)
                } else {
                    1 // Still under threshold
                }
            }
            None => 1, // New address, no activity
        };
        base_fee.saturating_mul(multiplier)
    }

    /// Register a transaction and calculate fee multiplier
    pub fn register_transaction(&mut self, address: String, base_fee: u64) -> Result<u64, String> {
        let now = Self::now_secs();
        let current_block = self.current_block;
        let activity = self
            .address_activity
            .entry(address.clone())
            .or_insert_with(|| AddressActivity {
                tx_count: 0,
                total_burned: 0,
                last_block: current_block,
                fee_multiplier: 1,
                window_start: now,
            });

        // Time-window based reset: counters reset every ACTIVITY_WINDOW_SECS
        Self::maybe_reset_activity(activity);

        // Check if address exceeded tx limit
        if activity.tx_count >= self.config.max_tx_per_block {
            // Exponential fee scaling: fee = base * multiplier^(excess+1)
            // SECURITY FIX: Uses integer exponentiation instead of f64 powi
            let excess = activity.tx_count - self.config.max_tx_per_block;
            activity.fee_multiplier = self.config.fee_scale_multiplier.saturating_pow(excess + 1);
        }

        activity.tx_count += 1;

        // SECURITY FIX: Integer multiplication instead of f64
        let final_fee = base_fee.saturating_mul(activity.fee_multiplier);

        Ok(final_fee)
    }

    /// Register a burn and check limits
    pub fn register_burn(&mut self, address: String, amount: u64) -> Result<(), String> {
        let now = Self::now_secs();
        let current_block = self.current_block;
        let activity = self
            .address_activity
            .entry(address.clone())
            .or_insert_with(|| AddressActivity {
                tx_count: 0,
                total_burned: 0,
                last_block: current_block,
                fee_multiplier: 1,
                window_start: now,
            });

        // Time-window based reset: counters reset every ACTIVITY_WINDOW_SECS
        Self::maybe_reset_activity(activity);

        if activity.total_burned + amount > self.config.max_burn_per_block {
            return Err(format!(
                "Burn limit exceeded: {} + {} > {}",
                activity.total_burned, amount, self.config.max_burn_per_block
            ));
        }

        activity.total_burned += amount;
        Ok(())
    }

    /// Calculate voting power using quadratic formula: √(stake)
    /// SECURITY FIX: Uses deterministic integer sqrt (Newton's method)
    /// instead of f64 powf() which varies across platforms.
    pub fn calculate_voting_power(&self, stake: u64) -> u64 {
        isqrt_u64(stake)
    }

    /// Get voting power distribution for validators (basis points, 10000 = 100%)
    pub fn calculate_voting_distribution(
        &self,
        validators: HashMap<String, u64>, // address -> stake
    ) -> HashMap<String, u64> {
        let mut distribution = HashMap::new();
        let mut total_power: u64 = 0;

        // Calculate power for each validator
        for (address, stake) in &validators {
            let power = self.calculate_voting_power(*stake);
            distribution.insert(address.clone(), power);
            total_power += power;
        }

        // Normalize to basis points (10000 = 100%)
        if total_power > 0 {
            for power in distribution.values_mut() {
                *power = (*power as u128 * 10_000 / total_power as u128) as u64;
            }
        }

        distribution
    }

    /// Check if an address is a whale (above threshold)
    pub fn is_whale(&self, stake: u64, total_supply: u64) -> bool {
        // Whale = holds > 1% of total supply
        stake > total_supply / 100
    }

    /// Get current activity for an address
    pub fn get_activity(&self, address: &str) -> Option<&AddressActivity> {
        self.address_activity.get(address)
    }

    /// Get fee multiplier for an address
    pub fn get_fee_multiplier(&self, address: &str) -> u64 {
        self.address_activity
            .get(address)
            .map(|a| a.fee_multiplier)
            .unwrap_or(1)
    }

    /// Reset activity for new block cycle
    pub fn reset_block_activity(&mut self) {
        let now = Self::now_secs();
        for activity in self.address_activity.values_mut() {
            activity.tx_count = 0;
            activity.total_burned = 0;
            activity.fee_multiplier = 1;
            activity.window_start = now;
        }
    }

    /// Get statistics on network concentration
    pub fn get_concentration_stats(&self, validators: HashMap<String, u64>) -> ConcentrationStats {
        if validators.is_empty() {
            return ConcentrationStats::default();
        }

        let mut stakes: Vec<u64> = validators.values().cloned().collect();
        stakes.sort_by(|a, b| b.cmp(a));

        let total_stake: u64 = stakes.iter().sum();
        if total_stake == 0 {
            return ConcentrationStats::default();
        }
        let top_3_stake: u64 = stakes.iter().take(3).sum();
        let top_10_stake: u64 = stakes.iter().take(10).sum();

        ConcentrationStats {
            total_validators: stakes.len(),
            total_stake,
            top_3_percent: (top_3_stake as f64 / total_stake as f64) * 100.0,
            top_10_percent: (top_10_stake as f64 / total_stake as f64) * 100.0,
            largest_stake: stakes[0],
            smallest_stake: stakes[stakes.len() - 1],
        }
    }
}

/// Deterministic integer square root using Newton's method.
/// Returns floor(√n) for any u64 value.
/// Used for quadratic voting power: voting_power = √stake
fn isqrt_u64(n: u64) -> u64 {
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

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ConcentrationStats {
    pub total_validators: usize,
    pub total_stake: u64,
    pub top_3_percent: f64,
    pub top_10_percent: f64,
    pub largest_stake: u64,
    pub smallest_stake: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_anti_whale_config_creation() {
        let config = AntiWhaleConfig::new();
        assert_eq!(config.max_tx_per_block, 5);
        assert_eq!(config.fee_scale_multiplier, 2);
        assert_eq!(config.max_burn_per_block, 1_000);
    }

    #[test]
    fn test_anti_whale_engine_creation() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);
        assert_eq!(engine.current_block, 0);
    }

    #[test]
    fn test_register_transaction_within_limit() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        let fee = engine
            .register_transaction("alice".to_string(), 100)
            .unwrap();
        assert_eq!(fee, 100);
    }

    #[test]
    fn test_fee_scaling_on_spam() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        // First 5 transactions should be at base fee
        for i in 0..5 {
            let fee = engine.register_transaction("spammer".to_string(), 100).unwrap();
            assert_eq!(fee, 100, "tx {} should be base fee", i + 1);
        }

        // 6th transaction: 2× base fee
        let fee6 = engine.register_transaction("spammer".to_string(), 100).unwrap();
        assert_eq!(fee6, 200, "tx 6 should be 2× base fee");

        // 7th transaction: 4× base fee
        let fee7 = engine.register_transaction("spammer".to_string(), 100).unwrap();
        assert_eq!(fee7, 400, "tx 7 should be 4× base fee");

        // 8th transaction: 8× base fee
        let fee8 = engine.register_transaction("spammer".to_string(), 100).unwrap();
        assert_eq!(fee8, 800, "tx 8 should be 8× base fee");

        let activity = engine.get_activity("spammer").unwrap();
        assert!(activity.fee_multiplier > 1);
    }

    #[test]
    fn test_register_burn_within_limit() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        let result = engine.register_burn("alice".to_string(), 500);
        assert!(result.is_ok());
    }

    #[test]
    fn test_register_burn_exceeds_limit() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        let _ = engine.register_burn("whale".to_string(), 900);
        let result = engine.register_burn("whale".to_string(), 200);
        assert!(result.is_err());
    }

    #[test]
    fn test_voting_power_quadratic() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        let power_100 = engine.calculate_voting_power(100);
        let power_10 = engine.calculate_voting_power(10);

        // 100^0.5 = 10, 10^0.5 ≈ 3.16
        assert!(power_100 > power_10);
        assert_eq!(power_100, 10);
    }

    #[test]
    fn test_voting_distribution() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        let mut validators = HashMap::new();
        validators.insert("alice".to_string(), 100);
        validators.insert("bob".to_string(), 100);

        let distribution = engine.calculate_voting_distribution(validators);
        assert!(distribution.len() == 2);

        // Both should have equal power (isqrt(100) = 10 each → 5000 bps each)
        let alice_power = *distribution.get("alice").unwrap();
        let bob_power = *distribution.get("bob").unwrap();
        assert_eq!(alice_power, bob_power);
        assert_eq!(alice_power, 5000); // 50% in basis points
    }

    #[test]
    fn test_whale_detection() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        let total_supply = 21_936_236;
        let whale_stake = total_supply / 50; // 2%
        let normal_stake = total_supply / 1000; // 0.1%

        assert!(engine.is_whale(whale_stake, total_supply));
        assert!(!engine.is_whale(normal_stake, total_supply));
    }

    #[test]
    fn test_concentration_stats() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        let mut validators = HashMap::new();
        validators.insert("alice".to_string(), 10_000);
        validators.insert("bob".to_string(), 5_000);
        validators.insert("charlie".to_string(), 3_000);
        validators.insert("dave".to_string(), 2_000);

        let stats = engine.get_concentration_stats(validators);
        assert_eq!(stats.total_validators, 4);
        assert_eq!(stats.total_stake, 20_000);
        assert!(stats.top_3_percent > 0.0);
    }

    #[test]
    fn test_new_block_resets_counters() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);

        engine.new_block(1);
        let _ = engine.register_transaction("alice".to_string(), 100);

        let activity_before = engine.get_activity("alice").unwrap().tx_count;
        assert_eq!(activity_before, 1);

        engine.new_block(2);
        let activity_after = engine.get_activity("alice").unwrap().tx_count;
        assert_eq!(activity_after, 0);
    }

    #[test]
    fn test_fee_multiplier_progression() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config.clone());
        engine.new_block(1);

        let max_tx = config.max_tx_per_block;
        let base = 100u64;
        let mut fees = Vec::new();

        // Register 10 transactions and track fees
        for _ in 0..10 {
            let fee = engine
                .register_transaction("spammer".to_string(), base)
                .unwrap();
            fees.push(fee);
        }

        // First max_tx should be base fee
        for i in 0..max_tx as usize {
            assert_eq!(fees[i], base, "tx {} should be base fee", i + 1);
        }

        // After threshold: exponential scaling
        // tx 6: 2×, tx 7: 4×, tx 8: 8×, tx 9: 16×, tx 10: 32×
        assert_eq!(fees[5], 200);  // 2^1 × 100
        assert_eq!(fees[6], 400);  // 2^2 × 100
        assert_eq!(fees[7], 800);  // 2^3 × 100
        assert_eq!(fees[8], 1600); // 2^4 × 100
        assert_eq!(fees[9], 3200); // 2^5 × 100
    }

    #[test]
    fn test_get_fee_multiplier() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        // Unknown address should have multiplier 1
        assert_eq!(engine.get_fee_multiplier("unknown"), 1);

        // After registration, should track multiplier
        let _ = engine.register_transaction("alice".to_string(), 100);
        let multiplier = engine.get_fee_multiplier("alice");
        assert_eq!(multiplier, 1);
    }

    #[test]
    fn test_concentration_stats_empty() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        let stats = engine.get_concentration_stats(HashMap::new());
        assert_eq!(stats.total_validators, 0);
        assert_eq!(stats.total_stake, 0);
    }

    #[test]
    fn test_anti_whale_serialization() {
        let config = AntiWhaleConfig::new();
        let json = serde_json::to_string(&config).unwrap();
        let deserialized: AntiWhaleConfig = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.max_tx_per_block, config.max_tx_per_block);
        assert_eq!(deserialized.max_burn_per_block, config.max_burn_per_block);
    }

    #[test]
    fn test_estimate_fee_read_only() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        let base = 100u64;

        // New address: estimate should be base fee
        assert_eq!(engine.estimate_fee("alice", base), 100);

        // Register 5 tx (at threshold)
        for _ in 0..5 {
            let _ = engine.register_transaction("alice".to_string(), base);
        }

        // Estimate for the 6th tx should be 2× (without registering)
        assert_eq!(engine.estimate_fee("alice", base), 200);

        // Calling estimate_fee again should give same result (read-only)
        assert_eq!(engine.estimate_fee("alice", base), 200);

        // Actually register the 6th tx
        let fee6 = engine.register_transaction("alice".to_string(), base).unwrap();
        assert_eq!(fee6, 200);

        // Now estimate for 7th should be 4×
        assert_eq!(engine.estimate_fee("alice", base), 400);
    }

    #[test]
    fn test_estimate_fee_unknown_address() {
        let config = AntiWhaleConfig::new();
        let engine = AntiWhaleEngine::new(config);

        // Unknown address should always return base fee
        assert_eq!(engine.estimate_fee("unknown", 100000), 100000);
    }
}
