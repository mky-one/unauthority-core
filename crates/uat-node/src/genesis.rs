// Genesis module for initializing the blockchain
#![allow(dead_code)]

use crate::{AccountState, VOID_PER_UAT};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Wallet entry in the genesis JSON produced by the `genesis` crate.
/// Supports both old-form (balance_uat) and generator-form (balance_void).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenesisWallet {
    pub address: String,
    /// Balance in UAT as a decimal string — used by legacy / testnet configs
    #[serde(default)]
    pub balance_uat: Option<String>,
    /// Balance in VOID as an integer — used by the generator output
    #[serde(default)]
    pub balance_void: Option<u128>,
    /// Stake in VOID — used by bootstrap_nodes
    #[serde(default)]
    pub stake_void: Option<u128>,
    #[serde(default)]
    pub wallet_type: Option<String>,
    #[serde(default)]
    pub seed_phrase: Option<String>,
    #[serde(default)]
    pub public_key: Option<String>,
    #[serde(default)]
    pub private_key: Option<String>,
}

/// Top-level genesis config.
/// Supports BOTH the generator output schema (network_id, total_supply_void, bootstrap_nodes, dev_accounts)
/// and the legacy schema (network, total_supply, wallets).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenesisConfig {
    // === Generator output format ===
    #[serde(default)]
    pub network_id: Option<u64>,
    #[serde(default)]
    pub chain_name: Option<String>,
    #[serde(default)]
    pub total_supply_void: Option<u128>,
    #[serde(default)]
    pub dev_supply_void: Option<u128>,
    #[serde(default)]
    pub bootstrap_nodes: Option<Vec<GenesisWallet>>,
    #[serde(default)]
    pub dev_accounts: Option<Vec<GenesisWallet>>,
    // === Legacy format ===
    #[serde(default)]
    pub network: Option<String>,
    #[serde(default)]
    pub genesis_timestamp: Option<u64>,
    #[serde(default)]
    pub total_supply: Option<String>,
    #[serde(default)]
    pub dev_allocation: Option<String>,
    #[serde(default)]
    pub wallets: Option<Vec<GenesisWallet>>,
}

/// Initialize ledger with genesis state from JSON file.
/// Supports both the generator output format AND the legacy format.
pub fn load_genesis_from_file(path: &str) -> Result<HashMap<String, AccountState>, String> {
    let json_data = std::fs::read_to_string(path)
        .map_err(|e| format!("Failed to read genesis file {}: {}", path, e))?;

    let genesis_config: GenesisConfig = serde_json::from_str(&json_data)
        .map_err(|e| format!("Failed to parse genesis JSON: {}", e))?;

    load_genesis_from_config(&genesis_config)
}

/// Resolve the VOID balance from a GenesisWallet.
/// Prefers balance_void (integer), falls back to stake_void, then balance_uat (parsed).
fn resolve_wallet_balance(wallet: &GenesisWallet) -> Result<u128, String> {
    if let Some(bv) = wallet.balance_void {
        return Ok(bv);
    }
    if let Some(sv) = wallet.stake_void {
        return Ok(sv);
    }
    if let Some(ref uat_str) = wallet.balance_uat {
        return parse_uat_to_void(uat_str);
    }
    Err(format!("No balance field found for {}", wallet.address))
}

/// Initialize ledger with genesis state from config struct.
/// Supports both generator output (bootstrap_nodes + dev_accounts) and legacy (wallets).
pub fn load_genesis_from_config(
    config: &GenesisConfig,
) -> Result<HashMap<String, AccountState>, String> {
    let mut accounts = HashMap::new();

    // Collect all wallets from whichever fields are present, tracking validator status
    let mut all_wallets: Vec<(&GenesisWallet, bool)> = Vec::new(); // (wallet, is_validator)
    if let Some(ref nodes) = config.bootstrap_nodes {
        all_wallets.extend(nodes.iter().map(|w| (w, true))); // bootstrap = validator
    }
    if let Some(ref devs) = config.dev_accounts {
        all_wallets.extend(devs.iter().map(|w| (w, false))); // dev = NOT validator
    }
    if let Some(ref ws) = config.wallets {
        all_wallets.extend(ws.iter().map(|w| (w, false))); // legacy = NOT validator
    }

    for (wallet, is_validator) in all_wallets {
        let balance_voi = resolve_wallet_balance(wallet)
            .map_err(|e| format!("Invalid balance for {}: {}", wallet.address, e))?;

        accounts.insert(
            wallet.address.clone(),
            AccountState {
                head: "0".to_string(),
                balance: balance_voi,
                block_count: 0,
                is_validator,
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

/// Validate genesis configuration.
/// Supports both generator format (network_id, total_supply_void) and legacy (network, total_supply).
///
/// SECURITY FIX: Now enforces network_id matches runtime environment to prevent
/// a mainnet genesis being loaded on testnet or vice versa (chain contamination).
pub fn validate_genesis(config: &GenesisConfig) -> Result<(), String> {
    // Check network — accept either format
    let network_ok = match (&config.network, config.network_id) {
        (Some(n), _) if n == "mainnet" || n == "testnet" => true,
        (_, Some(1)) | (_, Some(2)) => true, // 1=mainnet, 2=testnet
        _ => false,
    };
    if !network_ok {
        return Err(format!(
            "Invalid network: network={:?}, network_id={:?}",
            config.network, config.network_id
        ));
    }

    // SECURITY FIX: Validate network_id matches runtime build target
    // Prevents mainnet genesis loading on testnet or vice versa
    let is_mainnet_genesis = matches!(
        (&config.network, config.network_id),
        (Some(n), _) if n == "mainnet"
    ) || config.network_id == Some(1);

    let is_testnet_genesis = matches!(
        (&config.network, config.network_id),
        (Some(n), _) if n == "testnet"
    ) || config.network_id == Some(2);

    if uat_core::is_mainnet_build() && is_testnet_genesis {
        return Err("Cannot load testnet genesis on mainnet build".to_string());
    }
    if !uat_core::is_mainnet_build() && is_mainnet_genesis {
        return Err("Cannot load mainnet genesis on testnet build".to_string());
    }

    // Check timestamp is reasonable (after 2020, before 2100)
    if let Some(ts) = config.genesis_timestamp {
        if !(1577836800..=4102444800).contains(&ts) {
            return Err("Invalid genesis timestamp".to_string());
        }
    }

    // Check total supply — supports both formats
    let supply_valid = if let Some(tsv) = config.total_supply_void {
        // Generator format: VOID integer (21,936,236 × 10^11 = 2,193,623,600,000,000,000)
        tsv == 21_936_236u128 * VOID_PER_UAT
    } else if let Some(ref ts) = config.total_supply {
        // Legacy format: UAT string
        let trimmed = ts.trim_end_matches('0').trim_end_matches('.');
        trimmed == "21936236"
    } else {
        false
    };
    if !supply_valid {
        return Err(format!(
            "Invalid total supply: total_supply_void={:?}, total_supply={:?} (expected 21936236 UAT)",
            config.total_supply_void, config.total_supply
        ));
    }

    // Validate all addresses: must start with "UAT" and have minimum length
    // SECURITY FIX: Added minimum length check to prevent malformed addresses
    let all_wallets = config
        .bootstrap_nodes
        .iter()
        .flatten()
        .chain(config.dev_accounts.iter().flatten())
        .chain(config.wallets.iter().flatten());
    for wallet in all_wallets {
        if !wallet.address.starts_with("UAT") {
            return Err(format!("Invalid address format: {}", wallet.address));
        }
        // Address should be at least "UAT" + some hash chars (minimum ~10 chars)
        if wallet.address.len() < 10 {
            return Err(format!(
                "Address too short (min 10 chars): {}",
                wallet.address
            ));
        }
    }

    // FIX C11-04: Validate dev_supply_void if present
    if let Some(dsv) = config.dev_supply_void {
        let expected_dev = 1_535_536u128 * VOID_PER_UAT;
        if dsv != expected_dev {
            return Err(format!(
                "Invalid dev_supply_void: {} (expected {})",
                dsv, expected_dev
            ));
        }
    }

    // FIX C11-04: Validate bootstrap_nodes count matches expected (4)
    if let Some(ref nodes) = config.bootstrap_nodes {
        if nodes.len() != 4 {
            return Err(format!(
                "Invalid bootstrap_nodes count: {} (expected 4)",
                nodes.len()
            ));
        }
        // Validate each bootstrap node has sufficient stake
        let min_stake = uat_core::MIN_VALIDATOR_STAKE_VOID;
        for node in nodes {
            if let Some(sv) = node.stake_void {
                if sv < min_stake {
                    return Err(format!(
                        "Bootstrap node {} stake {} < minimum {}",
                        node.address, sv, min_stake
                    ));
                }
            }
        }
    }

    // FIX C11-14: Validate aggregate balance doesn't exceed total supply
    if let Some(tsv) = config.total_supply_void {
        let mut total_balance: u128 = 0;
        let all_wallets_for_sum = config
            .bootstrap_nodes
            .iter()
            .flatten()
            .chain(config.dev_accounts.iter().flatten())
            .chain(config.wallets.iter().flatten());
        for wallet in all_wallets_for_sum {
            if let Ok(balance) = resolve_wallet_balance(wallet) {
                total_balance = total_balance.saturating_add(balance);
            }
        }
        if total_balance > tsv {
            return Err(format!(
                "Aggregate wallet balance {} exceeds total_supply_void {}",
                total_balance, tsv
            ));
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_legacy_config(network: &str, total_supply: &str) -> GenesisConfig {
        GenesisConfig {
            network: Some(network.to_string()),
            genesis_timestamp: Some(1770341710),
            total_supply: Some(total_supply.to_string()),
            dev_allocation: Some("1535536.52000000".to_string()),
            wallets: Some(vec![]),
            network_id: None,
            chain_name: None,
            total_supply_void: None,
            dev_supply_void: None,
            bootstrap_nodes: None,
            dev_accounts: None,
        }
    }

    fn make_generator_config(network_id: u64, total_supply_void: u128) -> GenesisConfig {
        let make_node = |suffix: &str| GenesisWallet {
            address: format!("UATtest{}", suffix),
            stake_void: Some(100_000_000_000_000), // 1000 UAT
            balance_void: None,
            balance_uat: None,
            wallet_type: None,
            seed_phrase: None,
            public_key: None,
            private_key: None,
        };
        GenesisConfig {
            network_id: Some(network_id),
            genesis_timestamp: Some(1770580908),
            total_supply_void: Some(total_supply_void),
            chain_name: Some("Unauthority".to_string()),
            dev_supply_void: Some(153_553_600_000_000_000),
            bootstrap_nodes: Some(vec![
                make_node("1234567890"),
                make_node("2345678901"),
                make_node("3456789012"),
                make_node("4567890123"),
            ]),
            dev_accounts: Some(vec![]),
            network: None,
            total_supply: None,
            dev_allocation: None,
            wallets: None,
        }
    }

    /// Helper: return the network_id matching the current build target
    fn current_network_id() -> u64 {
        if uat_core::is_mainnet_build() {
            1
        } else {
            2
        }
    }

    /// Helper: return the network string matching the current build target
    fn current_network_str() -> &'static str {
        if uat_core::is_mainnet_build() {
            "mainnet"
        } else {
            "testnet"
        }
    }

    /// Helper: return the opposite network_id (for mismatch tests)
    fn opposite_network_id() -> u64 {
        if uat_core::is_mainnet_build() {
            2
        } else {
            1
        }
    }

    #[test]
    fn test_genesis_validation_legacy() {
        assert!(validate_genesis(&make_legacy_config(
            current_network_str(),
            "21936236.00000000"
        ))
        .is_ok());
    }

    #[test]
    fn test_genesis_validation_generator_format() {
        let config = make_generator_config(current_network_id(), 2_193_623_600_000_000_000);
        assert!(validate_genesis(&config).is_ok());
    }

    #[test]
    fn test_invalid_network() {
        assert!(validate_genesis(&make_legacy_config("invalid", "21936236.00000000")).is_err());
    }

    #[test]
    fn test_invalid_supply_generator() {
        let config = make_generator_config(current_network_id(), 999);
        assert!(validate_genesis(&config).is_err());
    }

    #[test]
    fn test_network_mismatch_rejected() {
        // Opposite network genesis should be rejected
        let config = make_generator_config(opposite_network_id(), 2_193_623_600_000_000_000);
        assert!(validate_genesis(&config).is_err());
    }

    #[test]
    fn test_load_generator_format() {
        let config = make_generator_config(2, 2_193_623_600_000_000_000);
        let accounts = load_genesis_from_config(&config).unwrap();
        assert_eq!(accounts.len(), 4);
        let acc = accounts.get("UATtest1234567890").unwrap();
        assert_eq!(acc.balance, 100_000_000_000_000);
    }

    #[test]
    fn test_load_legacy_format() {
        let config = GenesisConfig {
            wallets: Some(vec![GenesisWallet {
                address: "UATlegacy1".to_string(),
                balance_uat: Some("1000".to_string()),
                balance_void: None,
                stake_void: None,
                wallet_type: None,
                seed_phrase: None,
                public_key: None,
                private_key: None,
            }]),
            network: Some("testnet".to_string()),
            genesis_timestamp: Some(1770341710),
            total_supply: Some("21936236".to_string()),
            dev_allocation: Some("0".to_string()),
            network_id: None,
            chain_name: None,
            total_supply_void: None,
            dev_supply_void: None,
            bootstrap_nodes: None,
            dev_accounts: None,
        };
        let accounts = load_genesis_from_config(&config).unwrap();
        assert_eq!(accounts.len(), 1);
        assert_eq!(
            accounts.get("UATlegacy1").unwrap().balance,
            1000 * VOID_PER_UAT
        );
    }
}
