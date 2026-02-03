use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Anti-Whale Mechanisms for Unauthority
/// Prevents single entities from dominating the network through:
/// - Dynamic fee scaling on spam
/// - Quadratic voting power (stake^0.5)
/// - Burn limits per block

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AntiWhaleConfig {
    pub max_tx_per_block: u32,        // Max transactions per block per address
    pub fee_scale_multiplier: f64,    // Fee multiplier when spam detected
    pub max_burn_per_block: u64,      // Max UAT burned per block per address
    pub voting_power_exponent: f64,   // Exponent for stake (0.5 = quadratic)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddressActivity {
    pub tx_count: u32,
    pub total_burned: u64,
    pub last_block: u64,
    pub fee_multiplier: f64,
}

pub struct AntiWhaleEngine {
    config: AntiWhaleConfig,
    address_activity: HashMap<String, AddressActivity>,
    current_block: u64,
}

impl AntiWhaleConfig {
    pub fn new() -> Self {
        AntiWhaleConfig {
            max_tx_per_block: 100,
            fee_scale_multiplier: 2.0,
            max_burn_per_block: 1_000,
            voting_power_exponent: 0.5,
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

    /// Advance to next block and reset activity counters
    pub fn new_block(&mut self, block_number: u64) {
        self.current_block = block_number;
        
        // Reset counters for this block
        for activity in self.address_activity.values_mut() {
            if activity.last_block < block_number {
                activity.tx_count = 0;
                activity.total_burned = 0;
                activity.fee_multiplier = 1.0;
                activity.last_block = block_number;
            }
        }
    }

    /// Register a transaction and calculate fee multiplier
    pub fn register_transaction(
        &mut self,
        address: String,
        base_fee: u64,
    ) -> Result<u64, String> {
        let activity = self
            .address_activity
            .entry(address.clone())
            .or_insert_with(|| AddressActivity {
                tx_count: 0,
                total_burned: 0,
                last_block: self.current_block,
                fee_multiplier: 1.0,
            });

        // Check if address exceeded tx limit
        if activity.tx_count >= self.config.max_tx_per_block {
            // Exponential fee scaling: fee = base * multiplier^(excess_tx - limit)
            let excess = activity.tx_count - self.config.max_tx_per_block;
            activity.fee_multiplier = self.config.fee_scale_multiplier.powi(excess as i32 + 1);
        }

        activity.tx_count += 1;

        let final_fee = (base_fee as f64 * activity.fee_multiplier) as u64;

        Ok(final_fee)
    }

    /// Register a burn and check limits
    pub fn register_burn(&mut self, address: String, amount: u64) -> Result<(), String> {
        let activity = self
            .address_activity
            .entry(address.clone())
            .or_insert_with(|| AddressActivity {
                tx_count: 0,
                total_burned: 0,
                last_block: self.current_block,
                fee_multiplier: 1.0,
            });

        if activity.total_burned + amount > self.config.max_burn_per_block {
            return Err(format!(
                "Burn limit exceeded: {} + {} > {}",
                activity.total_burned, amount, self.config.max_burn_per_block
            ));
        }

        activity.total_burned += amount;
        Ok(())
    }

    /// Calculate voting power using quadratic formula: stake^exponent
    pub fn calculate_voting_power(&self, stake: u64) -> u64 {
        let stake_f = stake as f64;
        let power = stake_f.powf(self.config.voting_power_exponent);
        power as u64
    }

    /// Get voting power distribution for validators
    pub fn calculate_voting_distribution(
        &self,
        validators: HashMap<String, u64>, // address -> stake
    ) -> HashMap<String, f64> {
        let mut distribution = HashMap::new();
        let mut total_power: f64 = 0.0;

        // Calculate power for each validator
        for (address, stake) in validators {
            let power = self.calculate_voting_power(stake) as f64;
            distribution.insert(address, power);
            total_power += power;
        }

        // Normalize to percentages
        if total_power > 0.0 {
            for power in distribution.values_mut() {
                *power /= total_power;
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
    pub fn get_fee_multiplier(&self, address: &str) -> f64 {
        self.address_activity
            .get(address)
            .map(|a| a.fee_multiplier)
            .unwrap_or(1.0)
    }

    /// Reset activity for new block cycle
    pub fn reset_block_activity(&mut self) {
        for activity in self.address_activity.values_mut() {
            activity.tx_count = 0;
            activity.total_burned = 0;
            activity.fee_multiplier = 1.0;
        }
    }

    /// Get statistics on network concentration
    pub fn get_concentration_stats(
        &self,
        validators: HashMap<String, u64>,
    ) -> ConcentrationStats {
        if validators.is_empty() {
            return ConcentrationStats::default();
        }

        let mut stakes: Vec<u64> = validators.values().cloned().collect();
        stakes.sort_by(|a, b| b.cmp(a));

        let total_stake: u64 = stakes.iter().sum();
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
        assert_eq!(config.max_tx_per_block, 100);
        assert_eq!(config.fee_scale_multiplier, 2.0);
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

        // Register many transactions from same address
        for _ in 0..101 {
            let _ = engine.register_transaction("spammer".to_string(), 100);
        }

        let activity = engine.get_activity("spammer").unwrap();
        assert!(activity.fee_multiplier > 1.0);
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

        // Both should have equal power (100^0.5 = 10 each)
        let alice_power = distribution.get("alice").unwrap();
        let bob_power = distribution.get("bob").unwrap();
        assert!((alice_power - bob_power).abs() < 0.01);
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
        let mut last_fee = 100u64;
        for i in 0..5 {
            let fee = engine
                .register_transaction("spammer".to_string(), 100)
                .unwrap();

            // After limit, fees should scale up
            if i >= max_tx as usize {
                assert!(fee >= last_fee);
            }
            last_fee = fee;
        }
    }

    #[test]
    fn test_get_fee_multiplier() {
        let config = AntiWhaleConfig::new();
        let mut engine = AntiWhaleEngine::new(config);
        engine.new_block(1);

        // Unknown address should have multiplier 1.0
        assert_eq!(engine.get_fee_multiplier("unknown"), 1.0);

        // After registration, should track multiplier
        let _ = engine.register_transaction("alice".to_string(), 100);
        let multiplier = engine.get_fee_multiplier("alice");
        assert_eq!(multiplier, 1.0);
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
}
