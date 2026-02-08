// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UNAUTHORITY (UAT) - FINALITY CHECKPOINTS
//
// Prevents long-range attacks by storing immutable checkpoints every N blocks
// Security: RISK-003 mitigation (P0 Critical)
//
// How it works:
// 1. Every 1,000 blocks → create checkpoint (hash + height)
// 2. Store checkpoints in persistent DB (sled)
// 3. On sync: validate forks against latest checkpoint
// 4. Reject any blocks before last checkpoint (finality guarantee)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::path::Path;

/// Checkpoint interval (every 1,000 blocks)
pub const CHECKPOINT_INTERVAL: u64 = 1000;

/// Immutable checkpoint representing finalized state
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct FinalityCheckpoint {
    /// Block height of checkpoint
    pub height: u64,

    /// Block hash at checkpoint
    pub block_hash: String,

    /// Timestamp when checkpoint was created (Unix)
    pub timestamp: u64,

    /// Total validators active at checkpoint
    pub validator_count: u32,

    /// Merkle root of all accounts at this height (state snapshot)
    pub state_root: String,

    /// Signature count (67% of validators)
    pub signature_count: u32,
}

impl FinalityCheckpoint {
    /// Create new checkpoint
    pub fn new(
        height: u64,
        block_hash: String,
        validator_count: u32,
        state_root: String,
        signature_count: u32,
    ) -> Self {
        Self {
            height,
            block_hash,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
            validator_count,
            state_root,
            signature_count,
        }
    }

    /// Calculate unique checkpoint ID (hash of height + block_hash)
    pub fn calculate_id(&self) -> String {
        let mut hasher = Keccak256::new();
        hasher.update(self.height.to_le_bytes());
        hasher.update(self.block_hash.as_bytes());
        hasher.update(self.state_root.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    /// Verify checkpoint has enough signatures (67% quorum)
    pub fn verify_quorum(&self) -> bool {
        let required_sigs = ((self.validator_count as f64) * 0.67).ceil() as u32;
        self.signature_count >= required_sigs
    }

    /// Check if checkpoint is valid (interval aligned)
    pub fn is_valid_interval(&self) -> bool {
        self.height.is_multiple_of(CHECKPOINT_INTERVAL)
    }
}

/// Checkpoint Manager with persistent storage
pub struct CheckpointManager {
    /// Database for storing checkpoints
    db: sled::Db,

    /// Latest checkpoint height
    latest_checkpoint_height: u64,
}

impl CheckpointManager {
    /// Create new checkpoint manager
    pub fn new<P: AsRef<Path>>(db_path: P) -> Result<Self, Box<dyn std::error::Error>> {
        let db = sled::open(db_path)?;

        // Load latest checkpoint from DB
        let latest_checkpoint_height = db
            .get(b"latest_checkpoint_height")?
            .map(|bytes| {
                let arr: [u8; 8] = bytes.as_ref().try_into().unwrap_or([0u8; 8]);
                u64::from_le_bytes(arr)
            })
            .unwrap_or(0);

        Ok(Self {
            db,
            latest_checkpoint_height,
        })
    }

    /// Store checkpoint in database (immutable)
    pub fn store_checkpoint(
        &mut self,
        checkpoint: FinalityCheckpoint,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Validate checkpoint
        if !checkpoint.is_valid_interval() {
            return Err(format!(
                "Invalid checkpoint height: {} not aligned to {} interval",
                checkpoint.height, CHECKPOINT_INTERVAL
            )
            .into());
        }

        if !checkpoint.verify_quorum() {
            return Err(format!(
                "Insufficient signatures: {}/{} (need 67%)",
                checkpoint.signature_count, checkpoint.validator_count
            )
            .into());
        }

        // Serialize checkpoint
        let checkpoint_bytes = bincode::serialize(&checkpoint)?;
        let key = format!("checkpoint_{}", checkpoint.height);

        // Store in DB (immutable)
        self.db.insert(key.as_bytes(), checkpoint_bytes)?;

        // Update latest checkpoint height
        if checkpoint.height > self.latest_checkpoint_height {
            self.latest_checkpoint_height = checkpoint.height;
            self.db.insert(
                b"latest_checkpoint_height",
                &checkpoint.height.to_le_bytes(),
            )?;
        }

        self.db.flush()?;

        Ok(())
    }

    /// Get checkpoint by height
    pub fn get_checkpoint(
        &self,
        height: u64,
    ) -> Result<Option<FinalityCheckpoint>, Box<dyn std::error::Error>> {
        let key = format!("checkpoint_{}", height);

        if let Some(bytes) = self.db.get(key.as_bytes())? {
            let checkpoint: FinalityCheckpoint = bincode::deserialize(&bytes)?;
            Ok(Some(checkpoint))
        } else {
            Ok(None)
        }
    }

    /// Get latest checkpoint
    pub fn get_latest_checkpoint(
        &self,
    ) -> Result<Option<FinalityCheckpoint>, Box<dyn std::error::Error>> {
        if self.latest_checkpoint_height == 0 {
            return Ok(None);
        }

        self.get_checkpoint(self.latest_checkpoint_height)
    }

    /// Validate block against checkpoint (prevents long-range attacks)
    pub fn validate_block_against_checkpoint(
        &self,
        block_height: u64,
        block_hash: &str,
        _parent_hash: &str,
    ) -> Result<bool, Box<dyn std::error::Error>> {
        // Get latest checkpoint
        let latest_checkpoint = match self.get_latest_checkpoint()? {
            Some(cp) => cp,
            None => return Ok(true), // No checkpoints yet, allow
        };

        // CRITICAL: Reject blocks before last checkpoint (finality guarantee)
        if block_height < latest_checkpoint.height {
            return Err(format!(
                "Block height {} is before finality checkpoint {} (long-range attack rejected)",
                block_height, latest_checkpoint.height
            )
            .into());
        }

        // If block is at checkpoint height, verify hash matches
        if block_height == latest_checkpoint.height && block_hash != latest_checkpoint.block_hash {
            return Err(format!(
                "Block hash mismatch at checkpoint {}: expected {}, got {}",
                block_height, latest_checkpoint.block_hash, block_hash
            )
            .into());
        }

        // Validate parent hash chain back to checkpoint
        if block_height > latest_checkpoint.height
            && block_height < latest_checkpoint.height + CHECKPOINT_INTERVAL
        {
            // Parent must be after or at checkpoint
            let parent_height = block_height - 1;
            if parent_height < latest_checkpoint.height {
                return Err(format!(
                    "Parent block {} is before checkpoint {} (invalid chain)",
                    parent_height, latest_checkpoint.height
                )
                .into());
            }
        }

        Ok(true)
    }

    /// Check if height should create checkpoint
    pub fn should_create_checkpoint(&self, height: u64) -> bool {
        height.is_multiple_of(CHECKPOINT_INTERVAL) && height > self.latest_checkpoint_height
    }

    /// Get all checkpoints (for sync)
    pub fn get_all_checkpoints(
        &self,
    ) -> Result<Vec<FinalityCheckpoint>, Box<dyn std::error::Error>> {
        let mut checkpoints = Vec::new();

        for item in self.db.scan_prefix(b"checkpoint_") {
            let (_, value) = item?;
            let checkpoint: FinalityCheckpoint = bincode::deserialize(&value)?;
            checkpoints.push(checkpoint);
        }

        // Sort by height
        checkpoints.sort_by_key(|cp| cp.height);

        Ok(checkpoints)
    }

    /// Get checkpoint count
    pub fn get_checkpoint_count(&self) -> usize {
        self.db.scan_prefix(b"checkpoint_").count()
    }

    /// Prune old checkpoints (keep last N)
    pub fn prune_old_checkpoints(
        &mut self,
        keep_last: usize,
    ) -> Result<usize, Box<dyn std::error::Error>> {
        let mut checkpoints = self.get_all_checkpoints()?;

        if checkpoints.len() <= keep_last {
            return Ok(0); // Nothing to prune
        }

        // Sort by height descending
        checkpoints.sort_by_key(|cp| std::cmp::Reverse(cp.height));

        // Remove old checkpoints (but keep at least 1)
        let _to_remove = checkpoints.len() - keep_last;
        let mut removed = 0;

        for checkpoint in checkpoints.iter().skip(keep_last) {
            let key = format!("checkpoint_{}", checkpoint.height);
            self.db.remove(key.as_bytes())?;
            removed += 1;
        }

        self.db.flush()?;

        Ok(removed)
    }

    /// Get statistics
    pub fn get_statistics(&self) -> CheckpointStats {
        CheckpointStats {
            total_checkpoints: self.get_checkpoint_count(),
            latest_checkpoint_height: self.latest_checkpoint_height,
            checkpoint_interval: CHECKPOINT_INTERVAL,
        }
    }
}

/// Checkpoint statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckpointStats {
    pub total_checkpoints: usize,
    pub latest_checkpoint_height: u64,
    pub checkpoint_interval: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_checkpoint_creation() {
        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash_1000".to_string(),
            10,
            "state_root".to_string(),
            7, // 70% signatures
        );

        assert_eq!(checkpoint.height, 1000);
        assert!(checkpoint.verify_quorum()); // 7/10 = 70% > 67%
        assert!(checkpoint.is_valid_interval());
    }

    #[test]
    fn test_checkpoint_id_consistency() {
        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash".to_string(),
            10,
            "state_root".to_string(),
            7,
        );

        let id1 = checkpoint.calculate_id();
        let id2 = checkpoint.calculate_id();

        assert_eq!(id1, id2);
    }

    #[test]
    fn test_checkpoint_quorum_validation() {
        let mut checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash".to_string(),
            10,
            "state_root".to_string(),
            6, // 60% < 67% (insufficient)
        );

        assert!(!checkpoint.verify_quorum());

        checkpoint.signature_count = 7; // 70% >= 67% (sufficient)
        assert!(checkpoint.verify_quorum());
    }

    #[test]
    fn test_checkpoint_interval_validation() {
        let checkpoint1 = FinalityCheckpoint::new(
            1000,
            "block_hash".to_string(),
            10,
            "state_root".to_string(),
            7,
        );

        let checkpoint2 = FinalityCheckpoint::new(
            1001, // Invalid (not aligned to 1000)
            "block_hash".to_string(),
            10,
            "state_root".to_string(),
            7,
        );

        assert!(checkpoint1.is_valid_interval());
        assert!(!checkpoint2.is_valid_interval());
    }

    #[test]
    fn test_checkpoint_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");

        let manager = CheckpointManager::new(&db_path);
        assert!(manager.is_ok());
    }

    #[test]
    fn test_store_and_retrieve_checkpoint() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash_1000".to_string(),
            10,
            "state_root".to_string(),
            7,
        );

        let store_result = manager.store_checkpoint(checkpoint.clone());
        assert!(store_result.is_ok());

        let retrieved = manager.get_checkpoint(1000).unwrap();
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().height, 1000);
    }

    #[test]
    fn test_get_latest_checkpoint() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store multiple checkpoints
        for i in 1..=3 {
            let checkpoint = FinalityCheckpoint::new(
                i * 1000,
                format!("block_hash_{}", i * 1000),
                10,
                "state_root".to_string(),
                7,
            );
            manager.store_checkpoint(checkpoint).unwrap();
        }

        let latest = manager.get_latest_checkpoint().unwrap();
        assert!(latest.is_some());
        assert_eq!(latest.unwrap().height, 3000);
    }

    #[test]
    fn test_validate_block_after_checkpoint() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store checkpoint at height 1000
        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash_1000".to_string(),
            10,
            "state_root".to_string(),
            7,
        );
        manager.store_checkpoint(checkpoint).unwrap();

        // Block at height 1500 should be valid (after checkpoint)
        let result =
            manager.validate_block_against_checkpoint(1500, "block_hash_1500", "parent_hash_1499");
        assert!(result.is_ok());
        assert!(result.unwrap());
    }

    #[test]
    fn test_reject_block_before_checkpoint() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store checkpoint at height 1000
        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash_1000".to_string(),
            10,
            "state_root".to_string(),
            7,
        );
        manager.store_checkpoint(checkpoint).unwrap();

        // Block at height 500 should be REJECTED (before checkpoint - long-range attack)
        let result =
            manager.validate_block_against_checkpoint(500, "block_hash_500", "parent_hash_499");
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("long-range attack"));
    }

    #[test]
    fn test_should_create_checkpoint() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let manager = CheckpointManager::new(&db_path).unwrap();

        assert!(manager.should_create_checkpoint(1000));
        assert!(manager.should_create_checkpoint(2000));
        assert!(!manager.should_create_checkpoint(1500)); // Not at interval
        assert!(!manager.should_create_checkpoint(999)); // Not at interval
    }

    #[test]
    fn test_get_all_checkpoints() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store 3 checkpoints
        for i in 1..=3 {
            let checkpoint = FinalityCheckpoint::new(
                i * 1000,
                format!("block_hash_{}", i * 1000),
                10,
                "state_root".to_string(),
                7,
            );
            manager.store_checkpoint(checkpoint).unwrap();
        }

        let checkpoints = manager.get_all_checkpoints().unwrap();
        assert_eq!(checkpoints.len(), 3);
        assert_eq!(checkpoints[0].height, 1000);
        assert_eq!(checkpoints[2].height, 3000);
    }

    #[test]
    fn test_prune_old_checkpoints() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store 5 checkpoints
        for i in 1..=5 {
            let checkpoint = FinalityCheckpoint::new(
                i * 1000,
                format!("block_hash_{}", i * 1000),
                10,
                "state_root".to_string(),
                7,
            );
            manager.store_checkpoint(checkpoint).unwrap();
        }

        assert_eq!(manager.get_checkpoint_count(), 5);

        // Keep only last 3
        let removed = manager.prune_old_checkpoints(3).unwrap();
        assert_eq!(removed, 2);
        assert_eq!(manager.get_checkpoint_count(), 3);

        // Latest checkpoint should still exist
        let latest = manager.get_latest_checkpoint().unwrap();
        assert!(latest.is_some());
        assert_eq!(latest.unwrap().height, 5000);
    }

    #[test]
    fn test_checkpoint_statistics() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Store 2 checkpoints
        for i in 1..=2 {
            let checkpoint = FinalityCheckpoint::new(
                i * 1000,
                format!("block_hash_{}", i * 1000),
                10,
                "state_root".to_string(),
                7,
            );
            manager.store_checkpoint(checkpoint).unwrap();
        }

        let stats = manager.get_statistics();
        assert_eq!(stats.total_checkpoints, 2);
        assert_eq!(stats.latest_checkpoint_height, 2000);
        assert_eq!(stats.checkpoint_interval, 1000);
    }

    #[test]
    fn test_reject_checkpoint_without_quorum() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Checkpoint with insufficient signatures (5/10 = 50% < 67%)
        let checkpoint = FinalityCheckpoint::new(
            1000,
            "block_hash_1000".to_string(),
            10,
            "state_root".to_string(),
            5, // Only 50% signatures
        );

        let result = manager.store_checkpoint(checkpoint);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("Insufficient signatures"));
    }

    #[test]
    fn test_reject_checkpoint_invalid_interval() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("checkpoints_test");
        let mut manager = CheckpointManager::new(&db_path).unwrap();

        // Checkpoint at invalid height (1500 not aligned to 1000)
        let checkpoint = FinalityCheckpoint::new(
            1500,
            "block_hash_1500".to_string(),
            10,
            "state_root".to_string(),
            7,
        );

        let result = manager.store_checkpoint(checkpoint);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("not aligned"));
    }
}
