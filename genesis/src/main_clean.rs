use bip39::{Language, Mnemonic, MnemonicType};
use ed25519_dalek::{PublicKey, SecretKey};
use serde::{Deserialize, Serialize};
use std::fs;

// Constants (matching los-core/src/lib.rs)
const CIL_PER_LOS: u128 = 100_000_000_000; // 100 billion CIL per LOS
const TOTAL_SUPPLY_LOS: u128 = 21_936_236;
const DEV_ALLOCATION_PERCENT: f64 = 0.07; // 7%
const DEV_TREASURY_COUNT: usize = 8;
const BOOTSTRAP_NODE_COUNT: usize = 4;
const BOOTSTRAP_NODE_STAKE_LOS: u128 = 1_000; // 1000 LOS per validator

#[derive(Debug, Clone, Serialize, Deserialize)]
struct GenesisWallet {
    wallet_type: String,
    address: String,
    balance_los: String,
    balance_cil: String,
    seed_phrase: String,
    private_key: String,
    public_key: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct GenesisConfig {
    network: String,
    genesis_timestamp: u64,
    total_supply: String,
    dev_allocation: String,
    wallets: Vec<GenesisWallet>,
}

fn main() {
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║   UNAUTHORITY MAINNET GENESIS GENERATOR v6.0              ║");
    println!("║   ⚠️  PRIVATE - NEVER COMMIT TO GIT                       ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!("\n12 Wallets: 8 Dev Treasury + 4 Bootstrap Validators\n");

    // Calculate allocations
    let dev_allocation_cil = (TOTAL_SUPPLY_LOS as f64 * DEV_ALLOCATION_PERCENT) as u128 * CIL_PER_LOS;
    let total_bootstrap_allocation_cil = BOOTSTRAP_NODE_STAKE_LOS * (BOOTSTRAP_NODE_COUNT as u128) * CIL_PER_LOS;
    let allocation_per_treasury_cil = dev_allocation_cil / (DEV_TREASURY_COUNT as u128);
    let treasury_8_balance_cil = allocation_per_treasury_cil - total_bootstrap_allocation_cil;

    let mut wallets: Vec<GenesisWallet> = Vec::new();
    let mut total_allocated_cil: u128 = 0;

    println!("═══════════════════════════════════════════════════════════");
    println!("MAINNET TREASURY WALLETS (Private - Do Not Share!)");
    println!("═══════════════════════════════════════════════════════════\n");

    // Generate 8 dev treasury wallets
    for i in 1..=DEV_TREASURY_COUNT {
        let wallet_label = format!("mainnet-treasury-{}", i);
        let (seed_phrase, private_key, public_key, address) = generate_wallet(&wallet_label);
        
        let balance = if i == DEV_TREASURY_COUNT {
            treasury_8_balance_cil
        } else {
            allocation_per_treasury_cil
        };

        let balance_los = balance as f64 / CIL_PER_LOS as f64;
        
        println!("Treasury Wallet #{}:", i);
        println!("  Address:      {}", address);
        println!("  Balance:      {:.8} LOS ({} CIL)", balance_los, balance);
        println!("  Seed Phrase:  {}", seed_phrase);
        println!("  Private Key:  {}", private_key);
        println!("  Public Key:   {}\n", public_key);

        wallets.push(GenesisWallet {
            wallet_type: format!("DevWallet({})", i),
            address,
            balance_los: format!("{:.8}", balance_los),
            balance_cil: balance.to_string(),
            seed_phrase,
            private_key,
            public_key,
        });

        total_allocated_cil += balance;
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("MAINNET BOOTSTRAP VALIDATORS (Private - Do Not Share!)");
    println!("═══════════════════════════════════════════════════════════\n");

    // Generate 4 bootstrap node wallets
    for i in 1..=BOOTSTRAP_NODE_COUNT {
        let validator_label = format!("mainnet-validator-{}", i);
        let (seed_phrase, private_key, public_key, address) = generate_wallet(&validator_label);
        
        let balance = BOOTSTRAP_NODE_STAKE_LOS * CIL_PER_LOS;
        let balance_los = balance as f64 / CIL_PER_LOS as f64;
        
        println!("Bootstrap Validator #{}:", i);
        println!("  Address:      {}", address);
        println!("  Balance:      {:.8} LOS ({} CIL)", balance_los, balance);
        println!("  Seed Phrase:  {}", seed_phrase);
        println!("  Private Key:  {}", private_key);
        println!("  Public Key:   {}\n", public_key);

        wallets.push(GenesisWallet {
            wallet_type: format!("BootstrapNode({})", i),
            address,
            balance_los: format!("{:.8}", balance_los),
            balance_cil: balance.to_string(),
            seed_phrase,
            private_key,
            public_key,
        });

        total_allocated_cil += balance;
    }

    let total_los = total_allocated_cil as f64 / CIL_PER_LOS as f64;
    let expected_los = dev_allocation_cil as f64 / CIL_PER_LOS as f64;

    println!("═══════════════════════════════════════════════════════════");
    println!("ALLOCATION SUMMARY (MAINNET)");
    println!("═══════════════════════════════════════════════════════════");
    println!("Total Supply:     {:.8} LOS", TOTAL_SUPPLY_LOS as f64);
    println!("Dev Allocation:   {:.8} LOS (7%)", expected_los);
    println!("Treasury Wallets: 8 × {:.8} LOS", allocation_per_treasury_cil as f64 / CIL_PER_LOS as f64);
    println!("Treasury 8:       {:.8} LOS (after funding 4 nodes)", treasury_8_balance_cil as f64 / CIL_PER_LOS as f64);
    println!("Validators:       4 × {:.8} LOS", BOOTSTRAP_NODE_STAKE_LOS as f64);
    println!("Total Allocated:  {:.8} LOS", total_los);
    println!("Difference:       {:.8} LOS", (total_los - expected_los).abs());
    println!("═══════════════════════════════════════════════════════════\n");

    // Generate genesis config JSON
    let genesis = GenesisConfig {
        network: "mainnet".to_string(),
        genesis_timestamp: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs(),
        total_supply: format!("{:.8}", TOTAL_SUPPLY_LOS as f64),
        dev_allocation: format!("{:.8}", expected_los),
        wallets,
    };

    let json = serde_json::to_string_pretty(&genesis)
        .expect("Failed to serialize genesis config");

    fs::write("genesis_config.json", json)
        .expect("Failed to write genesis_config.json");

    println!("✅ Mainnet genesis saved to: genesis_config.json");
    println!("⚠️  CRITICAL: Keep this file secure and NEVER commit to git!");
    println!("\n🔒 Add to .gitignore:");
    println!("   genesis_config.json");
    println!("   genesis/genesis_config.json");
    println!("\n");
}

/// Generate a wallet with 24-word BIP39 seed phrase
fn generate_wallet(label: &str) -> (String, String, String, String) {
    println!("  Generating: {}", label);
    
    // Generate 24-word BIP39 seed phrase (256-bit entropy)
    let mnemonic = Mnemonic::new(MnemonicType::Words24, Language::English);
    let seed_phrase = mnemonic.to_string();
    
    // Derive seed from mnemonic (BIP39 standard)
    let seed = mnemonic.to_seed("");
    
    // Use first 32 bytes as Ed25519 private key
    let secret_key = SecretKey::from_bytes(&seed[0..32])
        .expect("Failed to create secret key");
    let public_key: PublicKey = (&secret_key).into();
    
    // Generate LOS address (LOS + Base58 of public key)
    let address = format!("LOS{}", bs58::encode(public_key.as_bytes()).into_string());
    
    let private_key_hex = hex::encode(secret_key.as_bytes());
    let public_key_hex = hex::encode(public_key.as_bytes());
    
    (seed_phrase, private_key_hex, public_key_hex, address)
}
