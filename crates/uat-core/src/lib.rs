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
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Keccak256::new();
        let data = format!(
            "{}{}{:?}{}{}",
            self.account, self.previous, self.block_type, self.amount, self.link
        );
        hasher.update(data.as_bytes());
        hex::encode(hasher.finalize())
    }

    pub fn verify_signature(&self) -> bool {
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
    pub distribution: DistributionState,
}

impl Ledger {
    pub fn new() -> Self {
        Self {
            accounts: HashMap::new(),
            distribution: DistributionState::new(),
        }
    }

    pub fn process_block(&mut self, block: &Block) -> Result<String, String> {
        if !block.verify_signature() {
            return Err("Invalid Signature!".to_string());
        }

        let block_hash = block.calculate_hash();
        let mut state = self.accounts.get(&block.account).cloned().unwrap_or(AccountState {
            head: "0".to_string(),
            balance: 0,
            block_count: 0,
        });

        if block.previous != state.head {
            return Err(format!("Chain Error: Expected {}", state.head));
        }

        match block.block_type {
            BlockType::Mint => {
                state.balance += block.amount;
                if self.distribution.remaining_supply >= block.amount {
                    self.distribution.remaining_supply -= block.amount;
                }
            }
            BlockType::Send => {
                if state.balance < block.amount { return Err("Insufficient Funds".to_string()); }
                state.balance -= block.amount;
            }
            BlockType::Receive => {
                state.balance += block.amount;
            }
            _ => {}
        }

        state.head = block_hash.clone();
        state.block_count += 1;
        self.accounts.insert(block.account.clone(), state);
        Ok(block_hash)
    }
}