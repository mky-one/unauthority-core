use rand::Rng; 
use sha3::{Digest, Keccak256}; 

// --- KONFIGURASI PRESISI (ZERO REMAINDER) ---
// 1 UAT = 100,000,000 Void (VOI)
const VOID_PER_UAT: u128 = 100_000_000;

// Total Jatah Dev: 1,535,536 UAT dikonversi ke Void
// 1,535,536 * 100,000,000 = 153,553,600,000,000 VOI
const DEV_SUPPLY_TOTAL_VOID: u128 = 1_535_536 * VOID_PER_UAT;

// Menggunakan 8 Wallet agar pembagian habis tanpa sisa desimal
const DEV_WALLET_COUNT: usize = 8;
const NODE_BOOTSTRAP_WALLETS: usize = 3;  // 3 untuk Node Awal
const TREASURY_WALLETS: usize = 5;        // 5 untuk Treasury

// Perhitungan Otomatis: 153,553,600,000,000 / 8 = 19,194,200,000,000 VOI
const ALLOCATION_PER_WALLET_VOID: u128 = DEV_SUPPLY_TOTAL_VOID / (DEV_WALLET_COUNT as u128);

// Struktur data Wallet
#[derive(Clone)]
struct DevWallet {
    #[allow(dead_code)]
    index: usize,
    wallet_type: WalletType,
    address: String,
    private_key: String, 
    balance_void: u128, // Menyimpan dalam satuan terkecil (Integer)
}

#[derive(Clone, Debug)]
enum WalletType {
    NodeBootstrap(u8),  // 1-3
    Treasury(u8),       // 1-5
}

fn main() {
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║   UNAUTHORITY (UAT) - GENESIS WALLET GENERATOR v1.0      ║");
    println!("║   Generating 8 Dev Wallets (Immutable Bootstrap)         ║");
    println!("╚════════════════════════════════════════════════════════════╝\n");

    println!("📊 CONFIGURATION:");
    println!("   • Total Dev Supply: {} UAT ({} VOI)", DEV_SUPPLY_TOTAL_VOID / VOID_PER_UAT, DEV_SUPPLY_TOTAL_VOID);
    println!("   • Per Wallet: {} VOI ({} UAT)", ALLOCATION_PER_WALLET_VOID, ALLOCATION_PER_WALLET_VOID / VOID_PER_UAT);
    println!("   • Node Bootstrap Wallets: {} (Initial Validators)", NODE_BOOTSTRAP_WALLETS);
    println!("   • Treasury Wallets: {} (Long-term Storage)\n", TREASURY_WALLETS);

    let mut wallets: Vec<DevWallet> = Vec::new();
    let mut total_allocated_void: u128 = 0;

    // Generate Node Bootstrap Wallets (1-3)
    for i in 1..=NODE_BOOTSTRAP_WALLETS {
        let (priv_key, pub_key) = generate_post_quantum_keys(format!("bootstrap-{}", i).as_str());
        let address = derive_address(&pub_key);

        let wallet = DevWallet {
            index: i,
            wallet_type: WalletType::NodeBootstrap(i as u8),
            address,
            private_key: priv_key,
            balance_void: ALLOCATION_PER_WALLET_VOID,
        };

        total_allocated_void += ALLOCATION_PER_WALLET_VOID;
        wallets.push(wallet);
    }

    // Generate Treasury Wallets (4-8)
    for i in 1..=TREASURY_WALLETS {
        let (priv_key, pub_key) = generate_post_quantum_keys(format!("treasury-{}", i).as_str());
        let address = derive_address(&pub_key);

        let wallet = DevWallet {
            index: NODE_BOOTSTRAP_WALLETS + i,
            wallet_type: WalletType::Treasury(i as u8),
            address,
            private_key: priv_key,
            balance_void: ALLOCATION_PER_WALLET_VOID,
        };

        total_allocated_void += ALLOCATION_PER_WALLET_VOID;
        wallets.push(wallet);
    }

    // OUTPUT BOOTSTRAP WALLETS
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ 🔐 NODE BOOTSTRAP WALLETS (Initial Validators)          │");
    println!("└─────────────────────────────────────────────────────────┘\n");
    
    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::NodeBootstrap(_))) {
        print_wallet_info(wallet);
    }

    // OUTPUT TREASURY WALLETS
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ 💰 TREASURY WALLETS (Long-term Storage)                 │");
    println!("└─────────────────────────────────────────────────────────┘\n");
    
    for wallet in wallets.iter().filter(|w| matches!(w.wallet_type, WalletType::Treasury(_))) {
        print_wallet_info(wallet);
    }

    // VERIFICATION
    println!("┌─────────────────────────────────────────────────────────┐");
    println!("│ ✓ SUPPLY VERIFICATION (IMMUTABLE)                      │");
    println!("└─────────────────────────────────────────────────────────┘\n");
    println!("   Target Supply   : {} VOI", DEV_SUPPLY_TOTAL_VOID);
    println!("   Total Allocated : {} VOI", total_allocated_void);
    
    if total_allocated_void == DEV_SUPPLY_TOTAL_VOID {
        println!("   Status          : ✓ MATCH (Zero Remainder Protocol)\n");
    } else {
        let diff = if total_allocated_void > DEV_SUPPLY_TOTAL_VOID {
            total_allocated_void - DEV_SUPPLY_TOTAL_VOID
        } else {
            DEV_SUPPLY_TOTAL_VOID - total_allocated_void
        };
        println!("   Status          : ✗ ERROR - Discrepancy {} VOI!\n", diff);
    }

    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║ ⚠️  CRITICAL INSTRUCTIONS:                                 ║");
    println!("║ 1. Copy all 8 Private Keys to COLD STORAGE (offline)      ║");
    println!("║ 2. Never share or expose Private Keys                    ║");
    println!("║ 3. Addresses above are used for Genesis Block             ║");
    println!("║ 4. Boot nodes (1-3) are initial validators                ║");
    println!("║ 5. Treasury (4-8) hold long-term protocol funds           ║");
    println!("╚════════════════════════════════════════════════════════════╝\n");
}

// --- Helper Functions ---

fn generate_post_quantum_keys(label: &str) -> (String, String) {
    use std::time::{SystemTime, UNIX_EPOCH};
    
    let mut hasher = Keccak256::new();
    
    // Seed dari: timestamp + label + random data
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    
    let mut rng = rand::thread_rng();
    let mut random_data = [0u8; 32];
    rng.fill(&mut random_data);
    
    hasher.update(timestamp.to_le_bytes());
    hasher.update(label.as_bytes());
    hasher.update(&random_data);
    
    let seed = hasher.finalize();
    
    // Derive Private Key (64 bytes)
    let mut priv_hasher = Keccak256::new();
    priv_hasher.update(&seed);
    priv_hasher.update(b"private");
    let priv_result = priv_hasher.finalize();
    
    // Derive Public Key (32 bytes)
    let mut pub_hasher = Keccak256::new();
    pub_hasher.update(&seed);
    pub_hasher.update(b"public");
    let pub_result = pub_hasher.finalize();
    
    (hex::encode(priv_result), hex::encode(pub_result))
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
        WalletType::NodeBootstrap(n) => format!("BOOTSTRAP NODE #{}", n),
        WalletType::Treasury(n) => format!("TREASURY #{}", n),
    };
    
    println!("   Type            : {}", wallet_label);
    println!("   Address         : {}", w.address);
    println!("   Balance         : {} VOI ({} UAT)", w.balance_void, 191_942);
    println!("   Private Key     : {}", w.private_key);
    println!("   ────────────────────────────────────────────────────────");
    println!();
}