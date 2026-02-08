// Genesis module for initializing the blockchain
#![allow(dead_code)]

use crate::{AccountState, VOID_PER_UAT};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenesisWallet {
    pub wallet_type: String,
    pub address: String,
    pub balance_uat: String,
    pub balance_void: String,
    pub seed_phrase: String,
    pub public_key: String,
    pub private_key: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenesisConfig {
    pub network: String,
    pub genesis_timestamp: u64,
    pub total_supply: String,
    pub dev_allocation: String,
    pub wallets: Vec<GenesisWallet>,
}

/// Initialize ledger with genesis state from JSON file
pub fn load_genesis_from_file(path: &str) -> Result<HashMap<String, AccountState>, String> {
    let json_data = std::fs::read_to_string(path)
        .map_err(|e| format!("Failed to read genesis file {}: {}", path, e))?;

    let genesis_config: GenesisConfig = serde_json::from_str(&json_data)
        .map_err(|e| format!("Failed to parse genesis JSON: {}", e))?;

    load_genesis_from_config(&genesis_config)
}

/// Initialize ledger with genesis state from config struct
pub fn load_genesis_from_config(
    config: &GenesisConfig,
) -> Result<HashMap<String, AccountState>, String> {
    let mut accounts = HashMap::new();

    for wallet in &config.wallets {
        // SECURITY FIX #9: Use integer math to avoid f64 precision loss
        // Parse as decimal string and multiply properly
        let balance_voi = parse_uat_to_void(&wallet.balance_uat)
            .map_err(|e| format!("Invalid balance_uat for {}: {}", wallet.address, e))?;

        accounts.insert(
            wallet.address.clone(),
            AccountState {
                head: "0".to_string(),
                balance: balance_voi,
                block_count: 0,
            },
        );
    }

    Ok(accounts)
}

/// Parse UAT amount string to VOID (integer) without f64 precision loss
/// Handles both integer ("191942") and decimal ("191942.50000000000") formats
pub fn parse_uat_to_void(uat_str: &str) -> Result<u128, String> {
    let trimmed = uat_str.trim();
    if let Some(dot_pos) = trimmed.find('.') {
        // Has decimal part: "123.456" → 123 UAT + fractional
        let integer_part: u128 = trimmed[..dot_pos]
            .parse()
            .map_err(|e| format!("Invalid integer part: {}", e))?;
        let decimal_str = &trimmed[dot_pos + 1..];

        // Pad or truncate to 11 decimal places (VOID_PER_UAT = 10^11)
        let padded = format!("{:0<11}", decimal_str);
        let decimal_void: u128 = padded[..11]
            .parse()
            .map_err(|e| format!("Invalid decimal part: {}", e))?;

        Ok(integer_part * VOID_PER_UAT + decimal_void)
    } else {
        // Integer only: "191942" → 191942 * VOID_PER_UAT
        let integer_part: u128 = trimmed
            .parse()
            .map_err(|e| format!("Invalid amount: {}", e))?;
        Ok(integer_part * VOID_PER_UAT)
    }
}

/// Validate genesis configuration
pub fn validate_genesis(config: &GenesisConfig) -> Result<(), String> {
    // Check network
    if config.network != "mainnet" && config.network != "testnet" {
        return Err(format!("Invalid network: {}", config.network));
    }

    // Check timestamp is reasonable (after 2020, before 2100)
    if config.genesis_timestamp < 1577836800 || config.genesis_timestamp > 4102444800 {
        return Err("Invalid genesis timestamp".to_string());
    }

    // Check total supply — SECURITY FIX V4#6: String comparison, not f64 equality
    let trimmed = config
        .total_supply
        .trim_end_matches('0')
        .trim_end_matches('.');
    if trimmed != "21936236" {
        return Err(format!(
            "Invalid total supply: {} (expected 21936236)",
            config.total_supply
        ));
    }

    // Validate addresses
    for wallet in &config.wallets {
        if !wallet.address.starts_with("UAT") {
            return Err(format!("Invalid address format: {}", wallet.address));
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_genesis_validation() {
        let config = GenesisConfig {
            network: "testnet".to_string(),
            genesis_timestamp: 1770341710,
            total_supply: "21936236.00000000".to_string(),
            dev_allocation: "1535536.52000000".to_string(),
            wallets: vec![],
        };

        assert!(validate_genesis(&config).is_ok());
    }

    #[test]
    fn test_invalid_network() {
        let config = GenesisConfig {
            network: "invalid".to_string(),
            genesis_timestamp: 1770341710,
            total_supply: "21936236.00000000".to_string(),
            dev_allocation: "1535536.52000000".to_string(),
            wallets: vec![],
        };

        assert!(validate_genesis(&config).is_err());
    }
}
