use bip39::Mnemonic;
use rand::Rng;
use std::fs::File;
use std::io::Write;

const VOID_PER_UAT: u128 = 100_000_000_000; // 10^11 VOID per UAT
const DEV_SUPPLY_TOTAL_VOID: u128 = 1_535_536 * VOID_PER_UAT;
// SECURITY FIX #7: Separate total supply constant (was using DEV_SUPPLY for both)
const TOTAL_SUPPLY_VOID: u128 = 21_936_236 * VOID_PER_UAT;
const DEV_WALLET_COUNT: usize = 8;
const ALLOCATION_PER_DEV_WALLET_VOID: u128 = 191_942 * VOID_PER_UAT;
const BOOTSTRAP_NODE_COUNT: usize = 4;
const ALLOCATION_PER_BOOTSTRAP_NODE_VOID: u128 = 1_000 * VOID_PER_UAT;
const TOTAL_BOOTSTRAP_ALLOCATION_VOID: u128 =
    ALLOCATION_PER_BOOTSTRAP_NODE_VOID * (BOOTSTRAP_NODE_COUNT as u128);
const DEV_WALLET_8_FINAL_VOID: u128 =
    ALLOCATION_PER_DEV_WALLET_VOID - TOTAL_BOOTSTRAP_ALLOCATION_VOID;

#[derive(Clone)]
struct DevWallet {
    wallet_type: WalletType,
    address: String,
    seed_phrase: String,
    private_key: String,
    public_key: String,
    balance_void: u128,
}

#[derive(Clone, Debug)]
enum WalletType {
    DevWallet(u8),
    BootstrapNode(u8),
}

fn main() {
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║   UNAUTHORITY GENESIS GENERATOR v4.0 (PRODUCTION)         ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!("\n12 Wallets: 8 Dev + 4 Bootstrap Validators\n");

    let mut wallets: Vec<DevWallet> = Vec::new();
    let mut total_allocated_void: u128 = 0;

    for i in 1..=DEV_WALLET_COUNT {
        let (seed_phrase, priv_key, pub_key) = generate_keys(&format!("dev-wallet-{}", i));
        let address = derive_address(&pub_key);
        let balance = if i == DEV_WALLET_COUNT {
            DEV_WALLET_8_FINAL_VOID
        } else {
            ALLOCATION_PER_DEV_WALLET_VOID
        };

        wallets.push(DevWallet {
            wallet_type: WalletType::DevWallet(i as u8),
            address,
            seed_phrase,
            private_key: priv_key,
            public_key: pub_key,
            balance_void: balance,
        });
        total_allocated_void += balance;
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
            balance_void: ALLOCATION_PER_BOOTSTRAP_NODE_VOID,
        });
        total_allocated_void += ALLOCATION_PER_BOOTSTRAP_NODE_VOID;
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("DEV WALLETS (Treasury/Operations)");
    println!("═══════════════════════════════════════════════════════════\n");
    for wallet in wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_)))
    {
        print_wallet(wallet);
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("BOOTSTRAP VALIDATOR NODES (Initial Validators)");
    println!("═══════════════════════════════════════════════════════════\n");
    for wallet in wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_)))
    {
        print_wallet(wallet);
    }

    println!("═══════════════════════════════════════════════════════════");
    println!("SUPPLY VERIFICATION");
    println!("═══════════════════════════════════════════════════════════");
    println!(
        "Target:    {} VOI ({} UAT)",
        DEV_SUPPLY_TOTAL_VOID,
        DEV_SUPPLY_TOTAL_VOID / VOID_PER_UAT
    );
    println!(
        "Allocated: {} VOI ({} UAT)",
        total_allocated_void,
        total_allocated_void / VOID_PER_UAT
    );

    if total_allocated_void == DEV_SUPPLY_TOTAL_VOID {
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
    println!("   - Node will activate if balance >= 1000 UAT\n");

    generate_config(&wallets);

    println!("✅ Genesis config saved: genesis/genesis_config.json");
    println!("⚠️  WARNING: This file contains private keys! Keep secure!\n");
}

fn generate_keys(label: &str) -> (String, String, String) {
    let mut rng = rand::thread_rng();

    // Generate 24-word BIP39 seed phrase (256-bit entropy)
    let entropy: [u8; 32] = rng.gen();
    let mnemonic = Mnemonic::from_entropy(&entropy).expect("Failed to generate mnemonic");

    let seed_phrase = mnemonic.to_string();

    // DETERMINISTIC: Derive Dilithium5 keypair from BIP39 seed
    // Uses domain-separated SHA-256 → ChaCha20 DRBG → pqcrypto_dilithium::keypair()
    // This ensures: same seed phrase → same keypair → same address (importable!)
    let bip39_seed = mnemonic.to_seed("");
    let keypair = uat_crypto::generate_keypair_from_seed(&bip39_seed);

    let private_key = hex::encode(&keypair.secret_key);
    let public_key = hex::encode(&keypair.public_key);

    println!("✓ Generated deterministic Dilithium5 keypair for: {}", label);

    (seed_phrase, private_key, public_key)
}

fn derive_address(pub_key_hex: &str) -> String {
    // Decode hex public key
    let public_key = hex::decode(pub_key_hex).expect("Failed to decode public key hex");

    // Use uat-crypto's Base58Check address derivation
    // Format: UAT + Base58(0x4A + BLAKE2b160(pubkey) + checksum)
    uat_crypto::public_key_to_address(&public_key)
}

fn print_wallet(w: &DevWallet) {
    let label = match &w.wallet_type {
        WalletType::DevWallet(n) => format!("DEV WALLET #{}", n),
        WalletType::BootstrapNode(n) => format!("BOOTSTRAP NODE #{}", n),
    };
    let balance_uat = w.balance_void / VOID_PER_UAT;

    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ Type: {:<50} │", label);
    println!("├─────────────────────────────────────────────────────────┤");
    println!("│ Address:  {:<46} │", w.address);
    println!("│ Balance:  {:<46} │", format!("{} UAT", balance_uat));
    println!("├─────────────────────────────────────────────────────────┤");
    println!("│ SEED PHRASE (24 words):                                 │");

    // Word-wrap seed phrase for readability
    let words: Vec<&str> = w.seed_phrase.split_whitespace().collect();
    for chunk in words.chunks(6) {
        println!("│ {:<56} │", chunk.join(" "));
    }

    println!("├─────────────────────────────────────────────────────────┤");
    println!(
        "│ Private Key: {}...{} │",
        &w.private_key[0..24],
        &w.private_key[w.private_key.len() - 24..]
    );
    println!(
        "│ Public Key:  {}...{} │",
        &w.public_key[0..24],
        &w.public_key[w.public_key.len() - 24..]
    );
    println!("└─────────────────────────────────────────────────────────┘");
    println!();
}

fn generate_config(wallets: &[DevWallet]) {
    // Bootstrap nodes with PRIVATE KEYS included
    let bootstrap: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::BootstrapNode(_)))
        .map(|w| {
            format!(
                r#"    {{
      "address": "{}",
      "stake_void": {},
      "seed_phrase": "{}",
      "private_key": "{}",
      "public_key": "{}"
    }}"#,
                w.address, w.balance_void, w.seed_phrase, w.private_key, w.public_key
            )
        })
        .collect();

    // Dev accounts with PRIVATE KEYS included
    let dev: Vec<_> = wallets
        .iter()
        .filter(|w| matches!(w.wallet_type, WalletType::DevWallet(_)))
        .map(|w| {
            format!(
                r#"    {{
      "address": "{}",
      "balance_void": {},
      "seed_phrase": "{}",
      "private_key": "{}",
      "public_key": "{}"
    }}"#,
                w.address, w.balance_void, w.seed_phrase, w.private_key, w.public_key
            )
        })
        .collect();

    let config = format!(
        r#"{{
  "network_id": 1,
  "chain_name": "Unauthority",
  "ticker": "UAT",
  "genesis_timestamp": {},
  "total_supply_void": {},
  "dev_supply_void": {},
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
        TOTAL_SUPPLY_VOID,
        DEV_SUPPLY_TOTAL_VOID,
        bootstrap.join(",\n"),
        dev.join(",\n")
    );

    let mut file = File::create("genesis_config.json").expect("Failed to create config");
    file.write_all(config.as_bytes())
        .expect("Failed to write config");
}
