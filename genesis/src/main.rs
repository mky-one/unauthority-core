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

// Perhitungan Otomatis: 153,553,600,000,000 / 8 = 19,194,200,000,000 VOI
const ALLOCATION_PER_WALLET_VOID: u128 = DEV_SUPPLY_TOTAL_VOID / (DEV_WALLET_COUNT as u128);

// Struktur data Wallet
struct DevWallet {
    index: usize,
    address: String,
    private_key: String, 
    balance_void: u128, // Menyimpan dalam satuan terkecil (Integer)
}

fn main() {
    println!("============================================================");
    println!("   UNAUTHORITY (UAT) - GENESIS GENERATOR (PRECISION MODE)   ");
    println!("   Status: CRITICAL - ZERO REMAINDER PROTOCOL ACTIVE        ");
    println!("============================================================");
    println!("Generating {} Dev Wallets...", DEV_WALLET_COUNT);
    println!("Allocation per Wallet: {} VOI (Exactly 191,942 UAT)", ALLOCATION_PER_WALLET_VOID);
    println!("------------------------------------------------------------\n");

    let mut wallets: Vec<DevWallet> = Vec::new();
    let mut total_allocated_void: u128 = 0;

    for i in 1..=DEV_WALLET_COUNT {
        // 1. Generate Keypair Post-Quantum (Mock/Placeholder for now)
        let (priv_key, pub_key) = generate_post_quantum_keys();
        
        // 2. Derive Address
        let address = derive_address(&pub_key);

        let wallet = DevWallet {
            index: i,
            address,
            private_key: priv_key,
            balance_void: ALLOCATION_PER_WALLET_VOID,
        };

        total_allocated_void += ALLOCATION_PER_WALLET_VOID;
        wallets.push(wallet);
    }

    // OUTPUT KE LAYAR
    for wallet in &wallets {
        print_wallet_info(wallet);
    }

    println!("------------------------------------------------------------");
    println!("VERIFIKASI SUPLAI (INTEGER CHECK):");
    println!("Target Supply : {} VOI", DEV_SUPPLY_TOTAL_VOID);
    println!("Total Allocated: {} VOI", total_allocated_void);
    
    // Verifikasi Absolut (Tanpa toleransi desimal)
    if total_allocated_void == DEV_SUPPLY_TOTAL_VOID {
        println!("STATUS: [MATCH] - Distribusi Sempurna (Zero Remainder).");
    } else {
        let diff = if total_allocated_void > DEV_SUPPLY_TOTAL_VOID {
            total_allocated_void - DEV_SUPPLY_TOTAL_VOID
        } else {
            DEV_SUPPLY_TOTAL_VOID - total_allocated_void
        };
        println!("STATUS: [ERROR] - Terjadi selisih {} VOI!", diff);
    }
    println!("============================================================");
    println!("INSTRUKSI:");
    println!("1. Simpan 8 Private Key ini di lokasi terpisah (Cold Storage).");
    println!("2. Address akan digunakan untuk 'genesis block' di user chain masing-masing.");
    println!("============================================================");
}

// --- Helper Functions ---

fn generate_post_quantum_keys() -> (String, String) {
    let mut rng = rand::thread_rng();
    
    // Menggunakan fill untuk keamanan array 64-byte
    let mut priv_bytes = [0u8; 64]; 
    rng.fill(&mut priv_bytes);

    let mut pub_bytes = [0u8; 32];
    rng.fill(&mut pub_bytes);
    
    (hex::encode(priv_bytes), hex::encode(pub_bytes))
}

fn derive_address(pub_key_hex: &str) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(pub_key_hex.as_bytes());
    let result = hasher.finalize();
    let hash_hex = hex::encode(result);
    format!("UAT{}", &hash_hex[0..40])
}

fn print_wallet_info(w: &DevWallet) {
    // Konversi VOI ke UAT hanya untuk tampilan layar agar mudah dibaca
    let balance_uat = w.balance_void as f64 / VOID_PER_UAT as f64;
    
    println!("DOMPET DEV #{}", w.index);
    println!("> Address     : {}", w.address);
    println!("> Balance     : {} VOI ({:.8} UAT)", w.balance_void, balance_uat);
    println!("> PRIVATE KEY : {}", w.private_key); 
    println!("------------------------------------------------------------");
}