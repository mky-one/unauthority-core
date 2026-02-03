use rand::Rng;
use sha3::{Digest, Keccak256};
use std::fs::File;
use std::io::Write;

// --- KONFIGURASI PRESISI (ZERO REMAINDER) ---
const VOID_PER_UAT: u128 = 100_000_000;

// Total Dev Supply: 1,535,536 UAT
const DEV_SUPPLY_TOTAL_VOID: u128 = 1_535_536 * VOID_PER_UAT; // 153,553,600,000,000 VOI

// 8 Dev Wallets (Treasury/Operations)
const DEV_WALLET_COUNT: usize = 8;
const ALLOCATION_PER_DEV_WALLET_VOID: u128 = 191_942 * VOID_PER_UAT; // 19,194,200,000,000 VOI

// 3 Bootstrap Validator Nodes (Initial Validators)
const BOOTSTRAP_NODE_COUNT: usize = 3;
const ALLOCATION_PER_BOOTSTRAP_NODE_VOID: u128 = 1_000 * VOID_PER_UAT; // 100,000,000,000 VOI (1000 UAT)
const TOTAL_BOOTSTRAP_ALLOCATION_VOID: u128 = ALLOCATION_PER_BOOTSTRAP_NODE_VOID * (BOOTSTRAP_NODE_COUNT as u128); // 3,000 UAT

// Wallet Dev #8 setelah dikurangi bootstrap nodes
const DEV_WALLET_8_FINAL_VOID: u128 = ALLOCATION_PER_DEV_WALLET_VOID - TOTAL_BOOTSTRAP_ALLOCATION_VOID;

#[derive(Clone)]
struct DevWallet {
    wallet_type: WalletType,
    address: String,
    private_key: String,
    balance_void: u128,
}

#[derive(Clone, Debug)]
enum WalletType {
    DevWallet(u8),
    BootstrapNode(u8),
}

fn main() {
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║   UNAUTHORITY (UAT) - GENESIS WALLET GENERATOR v2.0      ║");
    println!("║   11 Wallets: 8 Dev + 3 Bootstrap Validators             ║");
    println!("╚════════════════════════════════════════════════════════════╝\n");

    println!("📊 CONFIGURATION:");
    println!("   • Total Dev Supply: 1,535,536 UAT ({} VOI)", DEV_SUPPLY_TOTAL_VOID);
    println!("   • Dev Wallets: 8 (191,942 UAT each)");
    println!("   • Bootstrap Nodes: 3 (1,000 UAT each)");
    println!("   • Total: 11 Wallets\n");

    let mut wallets: Vec<DevWallet> = Vec::new();
    let mut total_allocated_void: u128 = 0;

    // Generate 8 Dev Wallets (Treasury/Operations)
    for i in 1..=DEV_WALLET_COUNT {
        let (priv_key, pub_key) = generate_post_quantum_keys(&format!("dev-wallet-{}", i));
        let address = derive_address(&pub_key);

        // Wallet Dev #8 reduced for bootstrap nodes
        let balance = if i == DEV_WALLET_COUNT {
            DEV_WALLET_8_FINAL_VOID
        } else {
            ALLOCATION_PER_DEV_WALLET_VOID
        };

        let wallet = DevWallet {
            wallet_type: WalletType::DevWallet(i as u8),
            address,
            private_key: priv_key,
            balance_void: balance,
        };

        total_allocated_void += balance;
        wallets.push(wallet);
    }

    // Generate 3 Bootstrap Validator Nodes (from Dev Wallet #8)
    for i in 1..=BOOTSTRAP_NODE_COUNT {
        let (priv_key, pub_key) = generate_post_quantum_keys(&format!("bootstrap-node-{}", i));
        let address = derive_address(&pub_key);

        let wallet = DevWallet {
            wallet_type: WalletType::BootstrapNode(i as u8),
            address,
            private_key: priv_key,
            balance_void: ALLOCATION_PER_BOOTSTRAP_NODE_VOID,
        };

        total_allocated_void += ALLOCATION_PER_BOOTSTRAP_NODE_VOID;
        wallets.push(wallet);
    }

    // OUTPUT: DEV WALLETS
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ 💰 DEV WALLETS (Treasury/Operations)                    │");
    println!("└─────────────────────────────────────────────────────────┘\n");

    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_))) {
        print_wallet_info(wallet);
    }

    // OUTPUT: BOOTSTRAP VALIDATOR NODES
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ 🔐 BOOTSTRAP VALIDATOR NODES (Initial Validators)       │");
    println!("└─────────────────────────────────────────────────────────┘\n");

    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_))) {
        print_wallet_info(wallet);
    }

    // SUPPLY VERIFICATION
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ ✓ SUPPLY VERIFICATION (IMMUTABLE)                      │");
    println!("└─────────────────────────────────────────────────────────┘\n");
    println!("   Target Supply   : {} VOI (1,535,536 UAT)", DEV_SUPPLY_TOTAL_VOID);
    println!("   Total Allocated : {} VOI", total_allocated_void);

    if total_allocated_void == DEV_SUPPLY_TOTAL_VOID {
        println!("   Status          : ✓ MATCH (Zero Remainder Protocol)\n");
    } else {
        println!("   Status          : ✗ MISMATCH! Check allocation logic!\n");
        std::process::exit(1);
    }

    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║ ✅ GENESIS GENERATION COMPLETE                           ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!("\n⚠️  SECURITY WARNING:");
    println!("   • Store private keys in cold storage immediately");
    println!("   • Never commit private keys to git");
    println!("   • Use hardware wallets for dev wallets");
    println!("   • Bootstrap node keys should be encrypted at rest\n");

    // Generate genesis_config.json
    generate_genesis_config(&wallets);
}

fn generate_post_quantum_keys(label: &str) -> (String, String) {
    let mut rng = rand::thread_rng();
    let private_key: Vec<u8> = (0..64).map(|_| rng.gen()).collect();
    let public_key: Vec<u8> = (0..32).map(|_| rng.gen()).collect();

    let priv_hex = hex::encode(private_key);
    let pub_hex = hex::encode(public_key);

    println!("   🔑 Generated keypair for: {}", label);
    (priv_hex, pub_hex)
}

fn derive_address(pub_key_hex: &str) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(pub_key_hex.as_bytes());
    let result = hasher.finalize();
    let hash_hex = hex::encode(result);
    format!("UAT{}", &hash_hex[0..40])
}

fn print_wallet_info(w: &DevWallet) {
    let wallet_label = match &w.wallet_type {
        WalletType::DevWallet(n) => format!("DEV WALLET #{}", n),
        WalletType::BootstrapNode(n) => format!("BOOTSTRAP NODE #{}", n),
    };

    let balance_uat = w.balance_void / VOID_PER_UAT;

    println!("   Type            : {}", wallet_label);
    println!("   Address         : {}", w.address);
    println!("   Balance         : {} VOI ({} UAT)", w.balance_void, balance_uat);
    println!("   Private Key     : {}...", &w.private_key[0..64]);
    println!("   ────────────────────────────────────────────────────────");
    println!();
}

fn generate_genesis_config(wallets: &[DevWallet]) {
    let bootstrap_nodes: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_)))
        .map(|w| {
            format!(
                r#"    {{
      "address": "{}",
      "stake_void": {},
      "private_key": "{}"
    }}"#,
                w.address, w.balance_void, w.private_key
            )
        })
        .collect();

    let dev_accounts: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_)))
        .map(|w| {
            format!(
                r#"    {{
      "address": "{}",
      "balance_void": {}
    }}"#,
                w.address, w.balance_void
            )
        })
        .collect();

    let config = format!(
        r#"{{
  "network_id": 1,
  "chain_name": "Unauthority",
  "ticker": "UAT",
  "genesis_timestamp": {},
  
  "constants": {{
    "total_supply_void": 2193623600000000,
    "dev_supply_void": 153553600000000,
    "public_supply_void": 2040070000000000,
    "void_per_uat": 100000000
  }},
  
  "bootstrap_nodes": [
{}
  ],
  
  "dev_accounts": [
{}
  ],
  
  "consensus": {{
    "type": "aBFT",
    "min_validators": 3,
    "block_time_ms": 3000,
    "finality_threshold": 0.67
  }}
}}
"#,
        chrono::Utc::now().timestamp(),
        bootstrap_nodes.join(",\n"),
        dev_accounts.join(",\n")
    );

    let mut file = File::create("genesis/genesis_config.json").expect("Unable to create file");
    file.write_all(config.as_bytes())
        .expect("Unable to write genesis config");

    println!("📄 genesis/genesis_config.json created successfully!\n");
}
