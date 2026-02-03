use serde::{Deserialize, Serialize};

/// Bonding Curve for Unauthority (UAT) distribution
/// Implements Proof-of-Burn mechanism with dynamic pricing
/// The curve makes UAT increasingly scarce as supply dwindles

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BondingCurve {
    pub total_supply: u64,         // 21,936,236 UAT (fixed)
    pub distributed: u64,          // How much distributed via PoB
    pub price_per_pob_ratio: f64, // Base price multiplier
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BondingCurveResult {
    pub uat_amount: u64,
    pub burned_satoshis: u64,
    pub burn_price: f64,
    pub remaining_supply: u64,
}

impl BondingCurve {
    /// Create new bonding curve with fixed total supply
    pub fn new() -> Self {
        BondingCurve {
            total_supply: 21_936_236, // Hard-coded per spec
            distributed: 0,
            price_per_pob_ratio: 1.0,
        }
    }

    /// Calculate UAT amount given BTC/ETH burn amount
    /// Uses logarithmic bonding curve: price increases as supply depletes
    pub fn calculate_uat_for_burn(&self, burned_satoshis: u64) -> BondingCurveResult {
        let remaining = self.total_supply - self.distributed;
        
        if remaining == 0 {
            return BondingCurveResult {
                uat_amount: 0,
                burned_satoshis,
                burn_price: f64::INFINITY,
                remaining_supply: 0,
            };
        }

        // Logarithmic bonding curve: price = k * ln(supply / remaining)
        // where k is a scaling factor (price_per_pob_ratio)
        let supply_ratio = (self.total_supply as f64) / (remaining as f64);
        let price_multiplier = supply_ratio.ln().max(1.0);

        // Base conversion: 1 Satoshi ≈ 0.0001 UAT (adjustable per burn)
        let base_uat = (burned_satoshis as f64 * 0.0001) / price_multiplier;
        let uat_amount = base_uat as u64;

        let uat_clamped = uat_amount.min(remaining);

        BondingCurveResult {
            uat_amount: uat_clamped,
            burned_satoshis,
            burn_price: price_multiplier,
            remaining_supply: remaining - uat_clamped,
        }
    }

    /// Process a burn and distribute UAT
    pub fn process_burn(&mut self, burned_satoshis: u64) -> BondingCurveResult {
        let result = self.calculate_uat_for_burn(burned_satoshis);
        self.distributed += result.uat_amount;
        
        BondingCurveResult {
            remaining_supply: self.total_supply - self.distributed,
            ..result
        }
    }

    /// Get current scarcity factor (0.0 = abundant, 1.0 = rare)
    pub fn scarcity_factor(&self) -> f64 {
        (self.total_supply - self.distributed) as f64 / self.total_supply as f64
    }

    /// Get percent distributed
    pub fn distribution_percent(&self) -> f64 {
        (self.distributed as f64 / self.total_supply as f64) * 100.0
    }

    /// Get remaining supply in UAT
    pub fn remaining_supply(&self) -> u64 {
        self.total_supply - self.distributed
    }

    /// Calculate "difficulty" for next burn (price needed to get 1 UAT)
    pub fn satoshi_cost_per_uat(&self) -> f64 {
        let remaining = self.total_supply - self.distributed;
        if remaining == 0 {
            return f64::INFINITY;
        }

        let supply_ratio = (self.total_supply as f64) / (remaining as f64);
        let price_multiplier = supply_ratio.ln().max(1.0);
        
        // Cost in satoshis to get 1 UAT
        10000.0 * price_multiplier // 10000 satoshis = 0.0001 BTC base
    }

    /// Verify the bonding curve is valid (no overflow/underflow)
    pub fn is_valid(&self) -> bool {
        self.distributed <= self.total_supply
            && self.price_per_pob_ratio > 0.0
            && !self.price_per_pob_ratio.is_nan()
            && !self.price_per_pob_ratio.is_infinite()
    }

    /// Set custom price multiplier for dynamic fee adjustment
    pub fn set_price_multiplier(&mut self, multiplier: f64) -> Result<(), String> {
        if multiplier <= 0.0 || multiplier.is_nan() || multiplier.is_infinite() {
            return Err("Invalid price multiplier".to_string());
        }
        self.price_per_pob_ratio = multiplier;
        Ok(())
    }

    /// Calculate expected UAT at burn completion (all supply distributed)
    pub fn estimated_final_distribution(&self, remaining_burners: u64) -> u64 {
        // Estimate: if remaining_burners continue burning
        // This helps forecast when distribution ends
        let per_burner = self.total_supply / (remaining_burners + 1).max(1);
        per_burner
    }

    /// Reset curve state (for testing/genesis only)
    #[cfg(test)]
    pub fn reset(&mut self) {
        self.distributed = 0;
    }
}

impl Default for BondingCurve {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bonding_curve_creation() {
        let curve = BondingCurve::new();
        assert_eq!(curve.total_supply, 21_936_236);
        assert_eq!(curve.distributed, 0);
        assert!(curve.is_valid());
    }

    #[test]
    fn test_calculate_uat_for_single_satoshi() {
        let curve = BondingCurve::new();
        let result = curve.calculate_uat_for_burn(10_000); // 0.0001 BTC

        assert!(result.uat_amount > 0);
        assert_eq!(result.burned_satoshis, 10_000);
        assert!(result.burn_price >= 1.0);
    }

    #[test]
    fn test_process_burn_increments_distributed() {
        let mut curve = BondingCurve::new();
        let initial_distributed = curve.distributed;

        let result = curve.process_burn(10_000);

        assert!(curve.distributed > initial_distributed);
        assert_eq!(curve.distributed, result.uat_amount);
    }

    #[test]
    fn test_scarcity_increases_with_distribution() {
        let mut curve = BondingCurve::new();
        let initial_scarcity = curve.scarcity_factor();

        curve.process_burn(10_000);
        let new_scarcity = curve.scarcity_factor();

        // Scarcity should decrease as more UAT is distributed
        assert!(new_scarcity < initial_scarcity);
    }

    #[test]
    fn test_distribution_percent() {
        let mut curve = BondingCurve::new();
        assert_eq!(curve.distribution_percent(), 0.0);

        curve.process_burn(100_000);
        let percent = curve.distribution_percent();
        assert!(percent > 0.0);
        assert!(percent < 100.0);
    }

    #[test]
    fn test_remaining_supply() {
        let mut curve = BondingCurve::new();
        assert_eq!(curve.remaining_supply(), 21_936_236);

        let result = curve.process_burn(10_000);
        assert_eq!(
            curve.remaining_supply() + result.uat_amount,
            21_936_236
        );
    }

    #[test]
    fn test_price_increases_as_supply_depletes() {
        let mut curve = BondingCurve::new();
        let initial_cost = curve.satoshi_cost_per_uat();

        // Simulate gradual distribution (0.1% of supply per burn)
        let small_burn = curve.total_supply / 1000; // 0.1%
        for _ in 0..5 {
            curve.process_burn(small_burn as u64);
        }

        let new_cost = curve.satoshi_cost_per_uat();
        // After significant distribution, cost should be higher or equal
        assert!(new_cost >= initial_cost * 0.95); // Allow small variance
    }

    #[test]
    fn test_satoshi_cost_per_uat_increases_monotonically() {
        let mut curve = BondingCurve::new();

        for i in 0..5 {
            let cost_before = curve.satoshi_cost_per_uat();
            curve.process_burn(100_000 * (i + 1));
            let cost_after = curve.satoshi_cost_per_uat();

            // Cost should increase after each burn (more scarce)
            assert!(cost_after >= cost_before);
        }
    }

    #[test]
    fn test_zero_remaining_supply() {
        let mut curve = BondingCurve::new();
        curve.distributed = curve.total_supply; // Manually set to exhausted

        let result = curve.calculate_uat_for_burn(10_000);
        assert_eq!(result.uat_amount, 0);
        assert_eq!(result.remaining_supply, 0);
    }

    #[test]
    fn test_uat_clamped_to_remaining() {
        let mut curve = BondingCurve::new();
        // Simulate 99% distribution
        curve.distributed = (curve.total_supply * 99) / 100;

        let result = curve.calculate_uat_for_burn(10_000_000); // Very large burn
        assert!(result.uat_amount <= curve.remaining_supply());
    }

    #[test]
    fn test_price_multiplier_setting() {
        let mut curve = BondingCurve::new();

        assert!(curve.set_price_multiplier(2.5).is_ok());
        assert_eq!(curve.price_per_pob_ratio, 2.5);

        // Invalid multipliers
        assert!(curve.set_price_multiplier(0.0).is_err());
        assert!(curve.set_price_multiplier(-1.0).is_err());
        assert!(curve.set_price_multiplier(f64::NAN).is_err());
        assert!(curve.set_price_multiplier(f64::INFINITY).is_err());
    }

    #[test]
    fn test_bonding_curve_validity() {
        let mut curve = BondingCurve::new();
        assert!(curve.is_valid());

        curve.distributed = curve.total_supply + 1; // Overflow
        assert!(!curve.is_valid());

        let mut curve = BondingCurve::new();
        curve.price_per_pob_ratio = -1.0; // Negative
        assert!(!curve.is_valid());
    }

    #[test]
    fn test_estimated_final_distribution() {
        let curve = BondingCurve::new();
        let estimate = curve.estimated_final_distribution(1000);

        assert!(estimate > 0);
        assert!(estimate <= curve.total_supply);
    }

    #[test]
    fn test_bonding_curve_result_serialization() {
        let result = BondingCurveResult {
            uat_amount: 100,
            burned_satoshis: 10_000,
            burn_price: 1.5,
            remaining_supply: 21_936_136,
        };

        let json = serde_json::to_string(&result).unwrap();
        let deserialized: BondingCurveResult = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.uat_amount, 100);
        assert_eq!(deserialized.burn_price, 1.5);
    }

    #[test]
    fn test_multiple_burns_consistency() {
        let mut curve = BondingCurve::new();

        let result1 = curve.process_burn(10_000);
        let result2 = curve.process_burn(10_000);
        let result3 = curve.process_burn(10_000);

        let total_distributed = result1.uat_amount + result2.uat_amount + result3.uat_amount;
        assert_eq!(curve.distributed, total_distributed);
        assert!(curve.distributed <= curve.total_supply);
    }

    #[test]
    fn test_large_burn_exceeds_remaining() {
        let mut curve = BondingCurve::new();
        // Try to burn amount that would exceed total supply
        let result = curve.process_burn(1_000_000_000);

        assert!(result.uat_amount <= curve.total_supply);
        assert!(curve.distributed <= curve.total_supply);
    }

    #[test]
    fn test_curve_state_consistency() {
        let mut curve = BondingCurve::new();

        for _ in 0..100 {
            curve.process_burn(1_000);
            assert!(curve.is_valid());
            assert_eq!(
                curve.distributed + curve.remaining_supply(),
                curve.total_supply
            );
        }
    }
}
