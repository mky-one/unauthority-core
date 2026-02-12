use bip39::{Language, Mnemonic, MnemonicType};
use ed25519_dalek::{PublicKey, SecretKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
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
}MAINNET GENESIS GENERATOR v6.0              ║");
    println!("║   ⚠️  PRIVATE - NEVER COMMIT TO GIT                       ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!("\n12 Wallets: 8 Dev Treasury + 4 Bootstrap Validators\n");

    // Calculate allocations
    let total_supply_cil = TOTAL_SUPPLY_LOS * CIL_PER_LOS;
    let dev_allocation_cil = (TOTAL_SUPPLY_LOS as f64 * DEV_ALLOCATION_PERCENT) as u128 * CIL_PER_LOS;
    let total_bootstrap_allocation_cil = BOOTSTRAP_NODE_STAKE_LOS * (BOOTSTRAP_NODE_COUNT as u128) * CIL_PER_LOS;
    
    // Each treasury wallet gets equal share
    let allocation_per_treasury_cil = dev_allocation_cil / (DEV_TREASURY_COUNT as u128);
    
    // Treasury 8 will fund bootstrap nodes, so it gets less
    let treasury_8_balance_cil = allocation_per_treasury_cil - total_bootstrap_allocation_cil;

    let mut wallets: Vec<GenesisWallet> = Vec::new();
    let mut total_allocated_cil: u128 = 0;

    println!("═══════════════════════════════════════════════════════════");
    println!("MAINNETGenesisWallet {
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

        total_allocated_cil += balance
            ALLOCATION_PER_DEV_WALLET_CIL
        };

        wallets.push(DevWallet {
            wallet_type: WalletType::DevWallet(i as u8),
            address,
            seed_phrase,
            private_key: priv_key,
            public_key: pub_key,
            balance_cil: balance,
        });
        total_allocated_cil += balance;
    }

    for i in 1..=BOOTSTRAP_NODE_COUNT {
        let (seed_phrase, priv_key, pub_key) = generate_keys(&format!("bootstrap-node-{}", i));
        let address = derive_address(&pub_key);

        wallets.push(DevWallet {
            wallet_type: WalletType::BootstrapNode(i as u8),
            address,
            seed_phrase,
            private_key: priv_key,
            public_key: pub_key,
            balance_cil: ALLOCATION_PER_BOOTSTRAP_NODE_CIL,
        });
        total_allocated_cil += ALLOCATION_PER_BOOTSTRAP_NODE_CIL;
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("DEV WALLETS (Treasury/Operations)");
    println!("═══════════════════════════════════════════════════════════\n");
    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_))) {
        print_wallet(wallet);
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("BOOTSTRAP VALIDATOR NODES (Initial Validators)");
    println!("═══════════════════════════════════════════════════════════\n");
    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_))) {
        print_wallet(wallet);
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("SUPPLY VERIFICATION");
    println!("═══════════════════════════════════════════════════════════");
    println!("Target:    {} CIL ({} LOS)", DEV_SUPPLY_TOTAL_CIL, DEV_SUPPLY_TOTAL_CIL / CIL_PER_LOS);
    println!("Allocated: {} CIL ({} LOS)", total_allocated_cil, total_allocated_cil / CIL_PER_LOS);
    
    if total_allocated_cil == DEV_SUPPLY_TOTAL_CIL {
        println!("Status: ✅ MATCH\n");
    } else {
        println!("Status: ❌ MISMATCH!\n");
        std::process::exit(1);
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("🔒 SECURITY INSTRUCTIONS (CRITICAL)");
    println!("═══════════════════════════════════════════════════════════");
    println!("1. BACKUP ALL SEED PHRASES IMMEDIATELY (write on paper)");
    println!("2. Store genesis_config.json in ENCRYPTED cold storage");
    println!("3. NEVER commit genesis_config.json to public Git");
    println!("4. For Bootstrap Nodes:");
    println!("   - Open Validator Dashboard: http://localhost:5173");
    println!("   - Click 'Import Existing Keys'");
    println!("   - Paste seed phrase OR private key");
    println!("   - Node will activate if balance >= 1000 LOS\n");

    generate_config(&wallets);
    
    println!("✅ Genesis config saved: genesis/genesis_config.json");
    println!("⚠️  WARNING: This file contains private keys! Keep secure!\n");
}

fn generate_keys(label: &str) -> (String, String, String) {
    let mut rng = rand::thread_rng();
    
    // Generate 24-word BIP39 seed phrase (256-bit entropy)
    let entropy: [u8; 32] = rng.gen();
    let mnemonic = Mnemonic::from_entropy(&entropy)
        .expect("Failed to generate mnemonic");
    
    let seed_phrase = mnemonic.to_string();
    let seed = mnemonic.to_seed("");
    
    // Derive private key from seed (first 64 bytes)
    let private_key: Vec<u8> = seed[0..64].to_vec();
    
    // Generate public key (deterministic from private key)
    let mut pub_hasher = Keccak256::new();
    pub_hasher.update(&private_key);
    let public_key = hex::encode(pub_hasher.finalize());

    println!("✓ Generated keypair for: {}", label);
    
    (seed_phrase, hex::encode(private_key), public_key)
}

fn derive_address(pub_key_hex: &str) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(pub_key_hex.as_bytes());
    let hash_hex = hex::encode(hasher.finalize());
    format!("LOS{}", &hash_hex[0..40])
}

fn print_wallet(w: &DevWallet) {
    let label = match &w.wallet_type {
        WalletType::DevWallet(n) => format!("DEV WALLET #{}", n),
        WalletType::BootstrapNode(n) => format!("BOOTSTRAP NODE #{}", n),
    };
    let balance_los = w.balance_cil / CIL_PER_LOS;

    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ Type: {:<50} │", label);
    println!("├─────────────────────────────────────────────────────────┤");
    println!("│ Address:  {:<46} │", w.address);
    println!("│ Balance:  {:<46} │", format!("{} LOS", balance_los));
    println!("├─────────────────────────────────────────────────────────┤");
    println!("│ SEED PHRASE (24 words):                                 │");
    
    // Word-wrap seed phrase for readability
    let words: Vec<&str> = w.seed_phrase.split_whitespace().collect();
    for chunk in words.chunks(6) {
        println!("│ {:<56} │", chunk.join(" "));
    }
    
    println!("├─────────────────────────────────────────────────────────┤");
    println!("│ Private Key: {}...{} │", &w.private_key[0..24], &w.private_key[w.private_key.len()-24..]);
    println!("│ Public Key:  {}...{} │", &w.public_key[0..24], &w.public_key[w.public_key.len()-24..]);
    println!("└─────────────────────────────────────────────────────────┘");
    println!();
}

fn generate_config(wallets: &[DevWallet]) {
    // Bootstrap nodes with PRIVATE KEYS included
    let bootstrap: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_)))
        .map(|w| format!(
            r#"    {{
      "address": "{}",
      "stake_cil": {},
      "seed_phrase": "{}",
      "private_key": "{}",
      "public_key": "{}"
    }}"#,
            w.address, w.balance_cil, w.seed_phrase, w.private_key, w.public_key
        ))
        .collect();

    // Dev accounts with PRIVATE KEYS included
    let dev: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_)))
        .map(|w| format!(
            r#"    {{
      "address": "{}",
      "balance_cil": {},
      "seed_phrase": "{}",
      "private_key": "{}",
      "public_key": "{}"
    }}"#,
            w.address, w.balance_cil, w.seed_phrase, w.private_key, w.public_key
        ))
        .collect();

    let config = format!(
        r#"{{
  "network_id": 1,
  "chain_name": "Unauthority",
  "ticker": "LOS",
  "genesis_timestamp": {},
  "total_supply_cil": {},
  "dev_supply_cil": {},
  "bootstrap_nodes": [
{}
  ],
  "dev_accounts": [
{}
  ],
  "security_notice": "⚠️ CRITICAL: This file contains private keys! Store in encrypted cold storage. NEVER commit to public repository!"
}}
"#,
        chrono::Utc::now().timestamp(),
        DEV_SUPPLY_TOTAL_CIL,
        DEV_SUPPLY_TOTAL_CIL,
        bootstrap.join(",\n"),
        dev.join(",\n")
    );

    let mut file = File::create("genesis_config.json").expect("Failed to create config");
    file.write_all(config.as_bytes()).expect("Failed to write config");
}
