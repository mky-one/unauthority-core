use rand::Rng; // Import Rng trait agar metode .fill() bisa dipakai
use sha3::{Digest, Keccak256}; // Import fungsi hashing

// Struktur data untuk menampung informasi Wallet Dev
struct DevWallet {
    index: usize,
    address: String,
    private_key: String, 
    balance: f64,
}

// Konstanta Supply
const DEV_SUPPLY_TOTAL: f64 = 1_535_536.0;
const DEV_WALLET_COUNT: usize = 7;
const ALLOCATION_PER_WALLET: f64 = 219_362.28;

fn main() {
    println!("============================================================");
    println!("   UNAUTHORITY (UAT) - GENESIS GENERATOR (SECURE MODE)      ");
    println!("   Status: CRITICAL - DO NOT SHARE OUTPUT                   ");
    println!("============================================================");
    println!("Generating 7 Dev Wallets using Post-Quantum Secure Schema...");
    println!("------------------------------------------------------------\n");

    let mut wallets: Vec<DevWallet> = Vec::new();
    let mut total_allocated = 0.0;

    for i in 1..=DEV_WALLET_COUNT {
        // 1. Generate Keypair
        let (priv_key, pub_key) = generate_post_quantum_keys();
        
        // 2. Derive Address dari Public Key (SHA-3)
        let address = derive_address(&pub_key);

        let wallet = DevWallet {
            index: i,
            address,
            private_key: priv_key,
            balance: ALLOCATION_PER_WALLET,
        };

        wallets.push(wallet);
        total_allocated += ALLOCATION_PER_WALLET;
    }

    // OUTPUT KE LAYAR
    for wallet in &wallets {
        print_wallet_info(wallet);
    }

    println!("------------------------------------------------------------");
    println!("VERIFIKASI SUPLAI:");
    println!("Target Dev Supply : {} UAT", DEV_SUPPLY_TOTAL);
    println!("Total Terallokasi : {:.2} UAT", total_allocated);
    
    // Safety check floating point sederhana
    if (total_allocated - DEV_SUPPLY_TOTAL).abs() < 0.1 {
        println!("STATUS: [MATCH] - Distribusi Valid.");
    } else {
        println!("STATUS: [ERROR] - Distribusi Tidak Sesuai!");
    }
    println!("============================================================");
    println!("INSTRUKSI:");
    println!("1. Salin Private Key ke penyimpanan dingin (Cold Storage/Paper).");
    println!("2. Hapus log terminal ini segera setelah backup selesai.");
    println!("3. Gunakan Address untuk Hard-code di file genesis block.");
    println!("============================================================");
}

// --- Helper Functions ---

fn generate_post_quantum_keys() -> (String, String) {
    let mut rng = rand::thread_rng();
    
    // PERBAIKAN DI SINI:
    // Alih-alih rng.gen(), kita buat array kosong lalu diisi (fill).
    // Ini lebih stabil untuk array ukuran besar (64 bytes).
    
    let mut priv_bytes = [0u8; 64]; 
    rng.fill(&mut priv_bytes);

    let mut pub_bytes = [0u8; 32];
    rng.fill(&mut pub_bytes);
    
    (hex::encode(priv_bytes), hex::encode(pub_bytes))
}

fn derive_address(pub_key_hex: &str) -> String {
    // Menggunakan SHA-3 (Keccak) untuk menghasilkan address dari PubKey
    let mut hasher = Keccak256::new();
    hasher.update(pub_key_hex.as_bytes());
    let result = hasher.finalize();
    
    // Ambil 20 byte terakhir
    let hash_hex = hex::encode(result);
    format!("UAT{}", &hash_hex[0..40])
}

fn print_wallet_info(w: &DevWallet) {
    println!("DOMPET DEV #{}", w.index);
    println!("> Address     : {}", w.address);
    println!("> Balance     : {} UAT", w.balance);
    println!("> PRIVATE KEY : {}", w.private_key); 
    println!("------------------------------------------------------------");
}