use serde::{Serialize, Deserialize};

pub const PUBLIC_SUPPLY_CAP: u128 = 20_400_700 * 100_000_000;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DistributionState {
    pub remaining_supply: u128,
    pub total_burned_idr: u128,
}

impl DistributionState {
    pub fn new() -> Self {
        Self {
            remaining_supply: PUBLIC_SUPPLY_CAP,
            total_burned_idr: 0,
        }
    }

    pub fn calculate_yield(&self, burn_amount_idr: u128) -> u128 {
        if self.remaining_supply == 0 { return 0; }
        
        // Rumus: M = Burn_IDR / (20.400.700 / Sisa_Supply)
        let public_cap_float = 20_400_700.0;
        let remaining_float = (self.remaining_supply as f64) / 100_000_000.0;
        
        let multiplier = public_cap_float / remaining_float;
        let yield_uat = (burn_amount_idr as f64) / multiplier;

        (yield_uat * 100_000_000.0) as u128
    }
}