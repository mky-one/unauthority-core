use serde::{Serialize, Deserialize};
use sha3::{Digest, Keccak256};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum BlockType {
    Send,
    Receive,
    Change, // Untuk ganti representative/validator
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Block {
    pub account: String,      // Address pemilik rantai
    pub previous: String,     // Hash blok sebelumnya di rantai yang sama
    pub block_type: BlockType,
    pub amount: u128,         // Jumlah dalam satuan VOI (1 UAT = 10^8 VOI)
    pub link: String,         // Hash sumber (jika Receive) atau tujuan (jika Send)
    pub signature: String,    // Tanda tangan Post-Quantum
    pub work: u64,            // Anti-spam (Proof of Work kecil)
}

impl Block {
    /// Fungsi untuk menghitung Hash dari sebuah blok
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Keccak256::new();
        // Gabungkan data penting untuk di-hash
        let data = format!("{}{}{:?}{}{}", 
            self.account, self.previous, self.block_type, self.amount, self.link);
        hasher.update(data.as_bytes());
        hex::encode(hasher.finalize())
    }
}