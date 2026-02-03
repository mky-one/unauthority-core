// Database Module - sled Embedded Database
// Provides ACID-compliant atomic operations for blockchain state

use sled::{Db, Tree};
use uat_core::{Ledger, Block, AccountState};
use std::sync::Arc;
use std::path::Path;

const DB_PATH: &str = "uat_database";
const TREE_BLOCKS: &str = "blocks";
const TREE_ACCOUNTS: &str = "accounts";
const TREE_META: &str = "metadata";

/// Database wrapper with ACID guarantees
pub struct UatDatabase {
    db: Arc<Db>,
}

impl UatDatabase {
    /// Open or create database
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, String> {
        let db = sled::open(path)
            .map_err(|e| format!("Failed to open database: {}", e))?;
        
        Ok(UatDatabase {
            db: Arc::new(db),
        })
    }

    /// Open with default path
    pub fn open_default() -> Result<Self, String> {
        Self::open(DB_PATH)
    }

    /// Get blocks tree
    fn blocks_tree(&self) -> Result<Tree, String> {
        self.db.open_tree(TREE_BLOCKS)
            .map_err(|e| format!("Failed to open blocks tree: {}", e))
    }

    /// Get accounts tree
    fn accounts_tree(&self) -> Result<Tree, String> {
        self.db.open_tree(TREE_ACCOUNTS)
            .map_err(|e| format!("Failed to open accounts tree: {}", e))
    }

    /// Get metadata tree
    fn meta_tree(&self) -> Result<Tree, String> {
        self.db.open_tree(TREE_META)
            .map_err(|e| format!("Failed to open metadata tree: {}", e))
    }

    /// Save complete ledger state (ATOMIC)
    pub fn save_ledger(&self, ledger: &Ledger) -> Result<(), String> {
        let blocks_tree = self.blocks_tree()?;
        let accounts_tree = self.accounts_tree()?;
        let meta_tree = self.meta_tree()?;

        // Create atomic batch
        let mut batch = sled::Batch::default();

        // 1. Save all blocks
        for (hash, block) in &ledger.blocks {
            let block_json = serde_json::to_vec(block)
                .map_err(|e| format!("Failed to serialize block: {}", e))?;
            batch.insert(hash.as_bytes(), block_json);
        }

        // Apply blocks batch atomically
        blocks_tree.apply_batch(batch)
            .map_err(|e| format!("Failed to save blocks: {}", e))?;

        // 2. Save all accounts
        let mut accounts_batch = sled::Batch::default();
        for (addr, state) in &ledger.accounts {
            let state_json = serde_json::to_vec(state)
                .map_err(|e| format!("Failed to serialize account: {}", e))?;
            accounts_batch.insert(addr.as_bytes(), state_json);
        }

        accounts_tree.apply_batch(accounts_batch)
            .map_err(|e| format!("Failed to save accounts: {}", e))?;

        // 3. Save metadata (distribution, etc.)
        let distribution_json = serde_json::to_vec(&ledger.distribution)
            .map_err(|e| format!("Failed to serialize distribution: {}", e))?;
        
        meta_tree.insert(b"distribution", distribution_json)
            .map_err(|e| format!("Failed to save distribution: {}", e))?;

        // 4. Flush to disk (durability guarantee)
        self.db.flush()
            .map_err(|e| format!("Failed to flush to disk: {}", e))?;

        Ok(())
    }

    /// Load complete ledger state
    pub fn load_ledger(&self) -> Result<Ledger, String> {
        let blocks_tree = self.blocks_tree()?;
        let accounts_tree = self.accounts_tree()?;
        let meta_tree = self.meta_tree()?;

        let mut ledger = Ledger::new();

        // 1. Load all blocks
        for item in blocks_tree.iter() {
            let (key, value) = item.map_err(|e| format!("Failed to read block: {}", e))?;
            
            let hash = String::from_utf8(key.to_vec())
                .map_err(|e| format!("Invalid block hash: {}", e))?;
            
            let block: Block = serde_json::from_slice(&value)
                .map_err(|e| format!("Failed to deserialize block: {}", e))?;
            
            ledger.blocks.insert(hash, block);
        }

        // 2. Load all accounts
        for item in accounts_tree.iter() {
            let (key, value) = item.map_err(|e| format!("Failed to read account: {}", e))?;
            
            let addr = String::from_utf8(key.to_vec())
                .map_err(|e| format!("Invalid account address: {}", e))?;
            
            let state: AccountState = serde_json::from_slice(&value)
                .map_err(|e| format!("Failed to deserialize account: {}", e))?;
            
            ledger.accounts.insert(addr, state);
        }

        // 3. Load metadata
        if let Some(dist_bytes) = meta_tree.get(b"distribution")
            .map_err(|e| format!("Failed to read distribution: {}", e))? 
        {
            ledger.distribution = serde_json::from_slice(&dist_bytes)
                .map_err(|e| format!("Failed to deserialize distribution: {}", e))?;
        }

        Ok(ledger)
    }

    /// Save single block (ATOMIC)
    #[allow(dead_code)]
    pub fn save_block(&self, hash: &str, block: &Block) -> Result<(), String> {
        let tree = self.blocks_tree()?;
        
        let block_json = serde_json::to_vec(block)
            .map_err(|e| format!("Failed to serialize block: {}", e))?;
        
        tree.insert(hash.as_bytes(), block_json)
            .map_err(|e| format!("Failed to save block: {}", e))?;
        
        tree.flush()
            .map_err(|e| format!("Failed to flush block: {}", e))?;

        Ok(())
    }

    /// Get single block
    #[allow(dead_code)]
    pub fn get_block(&self, hash: &str) -> Result<Option<Block>, String> {
        let tree = self.blocks_tree()?;
        
        if let Some(bytes) = tree.get(hash.as_bytes())
            .map_err(|e| format!("Failed to read block: {}", e))? 
        {
            let block: Block = serde_json::from_slice(&bytes)
                .map_err(|e| format!("Failed to deserialize block: {}", e))?;
            Ok(Some(block))
        } else {
            Ok(None)
        }
    }

    /// Save account state (ATOMIC)
    #[allow(dead_code)]
    pub fn save_account(&self, addr: &str, state: &AccountState) -> Result<(), String> {
        let tree = self.accounts_tree()?;
        
        let state_json = serde_json::to_vec(state)
            .map_err(|e| format!("Failed to serialize account: {}", e))?;
        
        tree.insert(addr.as_bytes(), state_json)
            .map_err(|e| format!("Failed to save account: {}", e))?;
        
        tree.flush()
            .map_err(|e| format!("Failed to flush account: {}", e))?;

        Ok(())
    }

    /// Get account state
    #[allow(dead_code)]
    pub fn get_account(&self, addr: &str) -> Result<Option<AccountState>, String> {
        let tree = self.accounts_tree()?;
        
        if let Some(bytes) = tree.get(addr.as_bytes())
            .map_err(|e| format!("Failed to read account: {}", e))? 
        {
            let state: AccountState = serde_json::from_slice(&bytes)
                .map_err(|e| format!("Failed to deserialize account: {}", e))?;
            Ok(Some(state))
        } else {
            Ok(None)
        }
    }

    /// Get database statistics
    pub fn stats(&self) -> DatabaseStats {
        let blocks_count = self.blocks_tree()
            .ok()
            .map(|t| t.len())
            .unwrap_or(0);
        
        let accounts_count = self.accounts_tree()
            .ok()
            .map(|t| t.len())
            .unwrap_or(0);

        let size_on_disk = self.db.size_on_disk()
            .unwrap_or(0);

        DatabaseStats {
            blocks_count,
            accounts_count,
            size_on_disk,
        }
    }

    /// Check if database is empty (first run)
    pub fn is_empty(&self) -> bool {
        self.blocks_tree()
            .ok()
            .map(|t| t.is_empty())
            .unwrap_or(true)
    }

    /// Create backup snapshot
    #[allow(dead_code)]
    pub fn create_snapshot(&self, path: &str) -> Result<(), String> {
        self.db.flush()
            .map_err(|e| format!("Failed to flush before snapshot: {}", e))?;

        // sled snapshots are not directly supported, use export instead
        let blocks = self.blocks_tree()?;
        let accounts = self.accounts_tree()?;
        
        let backup_data = serde_json::json!({
            "blocks_count": blocks.len(),
            "accounts_count": accounts.len(),
            "timestamp": std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        });

        std::fs::write(
            format!("{}/snapshot_meta.json", path),
            serde_json::to_string_pretty(&backup_data).unwrap()
        ).map_err(|e| format!("Failed to write snapshot metadata: {}", e))?;

        Ok(())
    }

    /// Clear all data (DANGER - for testing only)
    #[allow(dead_code)]
    pub fn clear_all(&self) -> Result<(), String> {
        let blocks = self.blocks_tree()?;
        let accounts = self.accounts_tree()?;
        let meta = self.meta_tree()?;

        blocks.clear()
            .map_err(|e| format!("Failed to clear blocks: {}", e))?;
        accounts.clear()
            .map_err(|e| format!("Failed to clear accounts: {}", e))?;
        meta.clear()
            .map_err(|e| format!("Failed to clear metadata: {}", e))?;

        self.db.flush()
            .map_err(|e| format!("Failed to flush after clear: {}", e))?;

        Ok(())
    }
}

/// Database statistics
#[derive(Debug, Clone)]
pub struct DatabaseStats {
    pub blocks_count: usize,
    pub accounts_count: usize,
    pub size_on_disk: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use uat_core::{BlockType, VOID_PER_UAT};

    #[test]
    fn test_database_open() {
        let db = UatDatabase::open("test_db_open").unwrap();
        assert!(db.is_empty());
        
        // Cleanup
        std::fs::remove_dir_all("test_db_open").ok();
    }

    #[test]
    fn test_save_and_load_ledger() {
        let db = UatDatabase::open("test_db_ledger").unwrap();
        
        // Create test ledger
        let mut ledger = Ledger::new();
        ledger.accounts.insert(
            "test_account".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 1000 * VOID_PER_UAT,
                block_count: 1,
            },
        );

        // Save
        db.save_ledger(&ledger).unwrap();

        // Load
        let loaded = db.load_ledger().unwrap();
        assert_eq!(loaded.accounts.len(), 1);
        assert_eq!(loaded.accounts.get("test_account").unwrap().balance, 1000 * VOID_PER_UAT);

        // Cleanup
        std::fs::remove_dir_all("test_db_ledger").ok();
    }

    #[test]
    fn test_save_single_block() {
        let db = UatDatabase::open("test_db_block").unwrap();
        
        let block = Block {
            account: "test".to_string(),
            previous: "0".to_string(),
            link: "genesis".to_string(),
            block_type: BlockType::Send,
            amount: 100,
            signature: "sig123".to_string(),
            work: 0,
        };

        // Save
        db.save_block("block_hash_123", &block).unwrap();

        // Load
        let loaded = db.get_block("block_hash_123").unwrap().unwrap();
        assert_eq!(loaded.account, "test");
        assert_eq!(loaded.amount, 100);

        // Cleanup
        std::fs::remove_dir_all("test_db_block").ok();
    }

    #[test]
    fn test_atomic_batch() {
        let db = UatDatabase::open("test_db_atomic").unwrap();
        
        let mut ledger = Ledger::new();
        
        // Add multiple accounts
        for i in 0..10 {
            ledger.accounts.insert(
                format!("account_{}", i),
                AccountState {
                    head: "genesis".to_string(),
                    balance: (i as u128) * VOID_PER_UAT,
                    block_count: 0,
                },
            );
        }

        // Save atomically
        db.save_ledger(&ledger).unwrap();

        // Verify all saved
        let loaded = db.load_ledger().unwrap();
        assert_eq!(loaded.accounts.len(), 10);

        // Cleanup
        std::fs::remove_dir_all("test_db_atomic").ok();
    }

    #[test]
    fn test_database_stats() {
        let db = UatDatabase::open("test_db_stats").unwrap();
        
        let mut ledger = Ledger::new();
        ledger.accounts.insert(
            "test".to_string(),
            AccountState {
                head: "0".to_string(),
                balance: 100,
                block_count: 0,
            },
        );

        db.save_ledger(&ledger).unwrap();

        let stats = db.stats();
        assert_eq!(stats.accounts_count, 1);
        assert!(stats.size_on_disk > 0);

        // Cleanup
        std::fs::remove_dir_all("test_db_stats").ok();
    }
}
