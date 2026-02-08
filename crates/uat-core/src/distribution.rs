use serde::{Serialize, Deserialize};
use crate::VOID_PER_UAT;

pub const PUBLIC_SUPPLY_CAP: u128 = 20_400_700 * VOID_PER_UAT;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DistributionState {
    pub remaining_supply: u128,
    pub total_burned_usd: u128,
}

impl DistributionState {
    pub fn new() -> Self {
        Self {
            remaining_supply: PUBLIC_SUPPLY_CAP,
            total_burned_usd: 0,
        }
    }

    pub fn calculate_yield(&self, burn_amount_usd: u128) -> u128 {
        if self.remaining_supply == 0 { return 0; }
        
        // SECURITY FIX V4#5: Integer math to avoid f64 precision drift
        // Formula: yield = burn_usd * remaining_supply / PUBLIC_SUPPLY_CAP
        // Use checked arithmetic to prevent overflow
        // Scale: burn_amount_usd is in $0.01 units, result is in VOID
        let public_cap_uat: u128 = 20_400_700;
        
        // yield_void = burn_amount_usd * remaining_supply / (public_cap_uat * VOID_PER_UAT)
        // To avoid overflow with large numbers, divide before multiply where possible
        // remaining_supply / PUBLIC_SUPPLY_CAP gives the scarcity multiplier
        // burn_amount_usd * VOID_PER_UAT gives value in VOID
        
        // Safe path: (burn_usd * remaining) / public_cap
        // With intermediate u128: max burn_usd ~10^12, remaining ~10^22 → ~10^34, fits u128 (max ~10^38)
        let numerator = burn_amount_usd
            .checked_mul(self.remaining_supply)
            .unwrap_or(0);
        
        numerator / (public_cap_uat * VOID_PER_UAT)
    }
}