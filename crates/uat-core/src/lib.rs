use serde::{Serialize, Deserialize};
use sha3::{Digest, Keccak256};
use std::collections::HashMap;

pub mod distribution;
use crate::distribution::DistributionState;

pub const VOID_PER_UAT: u128 = 100_000_000;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub enum BlockType {
    Send,
    Receive,
    Change,
    Mint,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Block {
    pub account: String,
    pub previous: String,
    pub block_type: BlockType,
    pub amount: u128,
    pub link: String,
    pub signature: String,
    pub work: u64,
}

impl Block {
    // OPTIMASI: Menghapus format! yang lambat, diganti dengan byte-feeding
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Keccak256::new();
        
        hasher.update(self.account.as_bytes());
        hasher.update(self.previous.as_bytes());
        
        // Mengubah enum ke byte untuk hashing cepat
        let type_byte = match self.block_type {
            BlockType::Send => 0,
            BlockType::Receive => 1,
            BlockType::Change => 2,
            BlockType::Mint => 3,
        };
        hasher.update(&[type_byte]);
        
        hasher.update(self.amount.to_le_bytes());
        hasher.update(self.link.as_bytes());
        
        // PENTING: Variabel work (nonce) HARUS ikut di-hash
        hasher.update(self.work.to_le_bytes());
        
        hex::encode(hasher.finalize())
    }

    pub fn verify_signature(&self) -> bool {
        if self.signature.is_empty() { return false; }
        
        let msg_hash = self.calculate_hash();
        let sig_bytes = hex::decode(&self.signature).unwrap_or_default();
        let pk_bytes = hex::decode(&self.account).unwrap_or_default();
        uat_crypto::verify_signature(msg_hash.as_bytes(), &sig_bytes, &pk_bytes)
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AccountState {
    pub head: String,
    pub balance: u128,
    pub block_count: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Ledger {
    pub accounts: HashMap<String, AccountState>,
    pub blocks: HashMap<String, Block>, 
    pub distribution: DistributionState,
}

impl Ledger {
    pub fn new() -> Self {
        Self {
            accounts: HashMap::new(),
            blocks: HashMap::new(),
            distribution: DistributionState::new(),
        }
    }

    pub fn process_block(&mut self, block: &Block) -> Result<String, String> {
        let block_hash = block.calculate_hash();

        // VALIDASI POW: 3 Nol untuk keseimbangan Keamanan & Kecepatan
        if !block_hash.starts_with("000") {
            return Err("Invalid PoW: Blok tidak memenuhi kriteria anti-spam".to_string());
        }

        if !block.verify_signature() {
            return Err("Invalid Signature: Verifikasi kunci publik gagal!".to_string());
        }

        if self.blocks.contains_key(&block_hash) {
            return Ok(block_hash);
        }

        let mut state = self.accounts.get(&block.account).cloned().unwrap_or(AccountState {
            head: "0".to_string(),
            balance: 0,
            block_count: 0,
        });

        if block.previous != state.head {
            return Err(format!(
                "Chain Error: Urutan blok tidak valid. Diharapkan {}, dapat {}", 
                state.head, block.previous
            ));
        }

        // 7. LOGIKA TRANSAKSI BERDASARKAN TIPE BLOK
        match block.block_type {
            BlockType::Mint => {
                // Tambahkan saldo ke akun peminta
                state.balance += block.amount;
                
                // Validasi dan update supply global
                if self.distribution.remaining_supply >= block.amount {
                    self.distribution.remaining_supply -= block.amount;

                    let parts: Vec<&str> = block.link.split(':').collect();
                    if parts.len() >= 4 { 
                        if let Ok(fiat_price) = parts[3].trim().parse::<u128>() {
                            self.distribution.total_burned_idr += fiat_price;
                        }
                    }
                    // --------------------------------------------
                } else {
                    return Err("Distribution Error: Supply sudah habis!".to_string());
                }
            }
            BlockType::Send => {
                if state.balance < block.amount {
                    return Err("Insufficient Funds: Saldo tidak cukup untuk mengirim".to_string());
                }
                state.balance -= block.amount;
            }
            BlockType::Receive => {
                // Penerima mendapatkan penambahan saldo
                state.balance += block.amount;
            }
            _ => {}
        }

        state.head = block_hash.clone();
        state.block_count += 1;
        
        self.accounts.insert(block.account.clone(), state);
        self.blocks.insert(block_hash.clone(), block.clone()); 

        Ok(block_hash)
    }
}