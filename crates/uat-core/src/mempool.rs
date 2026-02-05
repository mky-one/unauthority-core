use crate::{Block, VOID_PER_UAT};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, VecDeque};
use std::time::{SystemTime, UNIX_EPOCH};

/// Transaction mempool for pending transactions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Mempool {
    /// Pending transactions by hash
    transactions: HashMap<String, MempoolEntry>,
    /// Transaction queue ordered by fee/priority
    queue: VecDeque<String>,
    /// Maximum transactions in mempool
    max_size: usize,
    /// Transaction nonces by account
    nonces: HashMap<String, u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MempoolEntry {
    pub block: Block,
    pub fee: u128,
    pub timestamp: u64,
    pub nonce: u64,
}

impl Mempool {
    pub fn new(max_size: usize) -> Self {
        Self {
            transactions: HashMap::new(),
            queue: VecDeque::new(),
            max_size,
            nonces: HashMap::new(),
        }
    }

    /// Add transaction to mempool
    pub fn add_transaction(&mut self, block: Block, fee: u128) -> Result<String, String> {
        let hash = block.calculate_hash();

        // Check if transaction already exists
        if self.transactions.contains_key(&hash) {
            return Err("Transaction already in mempool".to_string());
        }

        // Check mempool size
        if self.transactions.len() >= self.max_size {
            // Remove lowest fee transaction
            self.evict_lowest_fee()?;
        }

        // Get current nonce for account
        let current_nonce = self.nonces.get(&block.account).copied().unwrap_or(0);
        let tx_nonce = current_nonce + 1;

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|_| "System time error")?
            .as_secs();

        let entry = MempoolEntry {
            block,
            fee,
            timestamp,
            nonce: tx_nonce,
        };

        // Add to mempool
        self.transactions.insert(hash.clone(), entry);
        self.queue.push_back(hash.clone());
        self.nonces.insert(entry.block.account.clone(), tx_nonce);

        Ok(hash)
    }

    /// Remove transaction from mempool
    pub fn remove_transaction(&mut self, hash: &str) -> Option<MempoolEntry> {
        if let Some(entry) = self.transactions.remove(hash) {
            self.queue.retain(|h| h != hash);
            Some(entry)
        } else {
            None
        }
    }

    /// Get transaction by hash
    pub fn get_transaction(&self, hash: &str) -> Option<&MempoolEntry> {
        self.transactions.get(hash)
    }

    /// Get next transactions for block creation
    pub fn get_next_transactions(&self, count: usize) -> Vec<MempoolEntry> {
        self.queue
            .iter()
            .take(count)
            .filter_map(|hash| self.transactions.get(hash).cloned())
            .collect()
    }

    /// Check if transaction with nonce already exists
    pub fn has_nonce(&self, account: &str, nonce: u64) -> bool {
        self.transactions
            .values()
            .any(|entry| entry.block.account == account && entry.nonce == nonce)
    }

    /// Get current nonce for account
    pub fn get_nonce(&self, account: &str) -> u64 {
        self.nonces.get(account).copied().unwrap_or(0)
    }

    /// Evict lowest fee transaction
    fn evict_lowest_fee(&mut self) -> Result<(), String> {
        let lowest = self
            .transactions
            .iter()
            .min_by_key(|(_, entry)| entry.fee)
            .map(|(hash, _)| hash.clone());

        if let Some(hash) = lowest {
            self.remove_transaction(&hash);
            Ok(())
        } else {
            Err("Mempool is empty".to_string())
        }
    }

    /// Remove expired transactions (older than 1 hour)
    pub fn cleanup_expired(&mut self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let expired: Vec<String> = self
            .transactions
            .iter()
            .filter(|(_, entry)| now - entry.timestamp > 3600)
            .map(|(hash, _)| hash.clone())
            .collect();

        for hash in expired {
            self.remove_transaction(&hash);
        }
    }

    /// Get mempool statistics
    pub fn stats(&self) -> MempoolStats {
        let total_fees: u128 = self.transactions.values().map(|e| e.fee).sum();
        let avg_fee = if !self.transactions.is_empty() {
            total_fees / self.transactions.len() as u128
        } else {
            0
        };

        MempoolStats {
            pending_count: self.transactions.len(),
            total_fees,
            avg_fee,
        }
    }

    /// Clear all transactions
    pub fn clear(&mut self) {
        self.transactions.clear();
        self.queue.clear();
        self.nonces.clear();
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MempoolStats {
    pub pending_count: usize,
    pub total_fees: u128,
    pub avg_fee: u128,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::BlockType;

    #[test]
    fn test_mempool_add_remove() {
        let mut mempool = Mempool::new(100);

        let block = Block {
            account: "UAT123".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 100 * VOID_PER_UAT,
            link: "UAT456".to_string(),
            signature: "sig".to_string(),
            work: 12345,
        };

        let hash = mempool.add_transaction(block.clone(), 1000).unwrap();
        assert!(mempool.get_transaction(&hash).is_some());

        let removed = mempool.remove_transaction(&hash);
        assert!(removed.is_some());
        assert!(mempool.get_transaction(&hash).is_none());
    }

    #[test]
    fn test_mempool_nonce() {
        let mut mempool = Mempool::new(100);

        let block1 = Block {
            account: "UAT123".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 100 * VOID_PER_UAT,
            link: "UAT456".to_string(),
            signature: "sig1".to_string(),
            work: 12345,
        };

        mempool.add_transaction(block1, 1000).unwrap();
        assert_eq!(mempool.get_nonce("UAT123"), 1);
    }

    #[test]
    fn test_mempool_max_size() {
        let mut mempool = Mempool::new(2);

        for i in 0..3 {
            let block = Block {
                account: format!("UAT{}", i),
                previous: "0".to_string(),
                block_type: BlockType::Send,
                amount: 100 * VOID_PER_UAT,
                link: "UAT456".to_string(),
                signature: format!("sig{}", i),
                work: 12345 + i as u64,
            };
            mempool.add_transaction(block, 1000 + i as u128 * 100).unwrap();
        }

        // Should only have 2 transactions (evicted lowest fee)
        assert_eq!(mempool.transactions.len(), 2);
    }
}
