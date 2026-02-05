use uat_core::{Block, BlockType, Ledger, AccountState, VOID_PER_UAT};
use uat_core::mempool::Mempool;
use uat_core::oracle_consensus::OracleConsensus;
use uat_crypto;
use std::time::{SystemTime, UNIX_EPOCH};

#[cfg(test)]
mod consensus_tests {
    use super::*;

    #[test]
    fn test_oracle_consensus_median() {
        let mut oracle = OracleConsensus::new();

        // Submit prices from 3 oracles
        oracle.submit_price("oracle1".to_string(), 50000.0, 3000.0).unwrap();
        oracle.submit_price("oracle2".to_string(), 51000.0, 3100.0).unwrap();
        oracle.submit_price("oracle3".to_string(), 49000.0, 2900.0).unwrap();

        let (btc_price, eth_price) = oracle.get_consensus_price().unwrap();

        // Median should be 50000 for BTC, 3000 for ETH
        assert_eq!(btc_price, 50000.0);
        assert_eq!(eth_price, 3000.0);
    }

    #[test]
    fn test_oracle_outlier_detection() {
        let mut oracle = OracleConsensus::new();

        // Submit normal prices
        oracle.submit_price("oracle1".to_string(), 50000.0, 3000.0).unwrap();
        oracle.submit_price("oracle2".to_string(), 51000.0, 3100.0).unwrap();
        oracle.submit_price("oracle3".to_string(), 49000.0, 2900.0).unwrap();

        // Submit outlier price (100x normal)
        oracle.submit_price("oracle4".to_string(), 5000000.0, 300000.0).unwrap();

        let outliers = oracle.detect_outliers();
        assert!(outliers.contains(&"oracle4".to_string()));
    }

    #[test]
    fn test_oracle_minimum_submissions() {
        let oracle = OracleConsensus::new();

        // No submissions yet
        assert!(oracle.get_consensus_price().is_none());
    }
}

#[cfg(test)]
mod mempool_tests {
    use super::*;

    fn create_test_block(account: &str, amount: u128, nonce: u64) -> Block {
        Block {
            account: account.to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount,
            link: "UAT_DEST".to_string(),
            signature: "test_sig".to_string(),
            work: 12345,
            nonce,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        }
    }

    #[test]
    fn test_mempool_add_transaction() {
        let mut mempool = Mempool::new(100);
        let block = create_test_block("UAT_TEST", 1000 * VOID_PER_UAT, 1);

        let hash = mempool.add_transaction(block, 100).unwrap();
        assert!(mempool.get_transaction(&hash).is_some());
    }

    #[test]
    fn test_mempool_duplicate_transaction() {
        let mut mempool = Mempool::new(100);
        let block = create_test_block("UAT_TEST", 1000 * VOID_PER_UAT, 1);

        mempool.add_transaction(block.clone(), 100).unwrap();
        let result = mempool.add_transaction(block, 100);

        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Transaction already in mempool");
    }

    #[test]
    fn test_mempool_nonce_tracking() {
        let mut mempool = Mempool::new(100);

        let block1 = create_test_block("UAT_TEST", 1000 * VOID_PER_UAT, 1);
        let block2 = create_test_block("UAT_TEST", 2000 * VOID_PER_UAT, 2);

        mempool.add_transaction(block1, 100).unwrap();
        mempool.add_transaction(block2, 100).unwrap();

        assert_eq!(mempool.get_nonce("UAT_TEST"), 2);
    }

    #[test]
    fn test_mempool_max_size_eviction() {
        let mut mempool = Mempool::new(3);

        for i in 0..5 {
            let block = create_test_block(&format!("UAT_TEST_{}", i), 1000 * VOID_PER_UAT, 1);
            let fee = (i + 1) as u128 * 100; // Increasing fees
            mempool.add_transaction(block, fee).unwrap();
        }

        // Should only have 3 transactions (max size)
        // Lowest fee transactions should be evicted
        assert_eq!(mempool.stats().pending_count, 3);
    }

    #[test]
    fn test_mempool_get_next_transactions() {
        let mut mempool = Mempool::new(100);

        for i in 0..5 {
            let block = create_test_block(&format!("UAT_TEST_{}", i), 1000 * VOID_PER_UAT, 1);
            mempool.add_transaction(block, 100).unwrap();
        }

        let next_txs = mempool.get_next_transactions(3);
        assert_eq!(next_txs.len(), 3);
    }
}

#[cfg(test)]
mod block_tests {
    use super::*;

    #[test]
    fn test_block_hash_calculation() {
        let block = Block {
            account: "UAT_TEST".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 1000 * VOID_PER_UAT,
            link: "UAT_DEST".to_string(),
            signature: "sig".to_string(),
            work: 12345,
            nonce: 1,
            timestamp: 1234567890,
        };

        let hash1 = block.calculate_hash();
        let hash2 = block.calculate_hash();

        // Hashing should be deterministic
        assert_eq!(hash1, hash2);
    }

    #[test]
    fn test_block_nonce_affects_hash() {
        let mut block1 = Block {
            account: "UAT_TEST".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 1000 * VOID_PER_UAT,
            link: "UAT_DEST".to_string(),
            signature: "sig".to_string(),
            work: 12345,
            nonce: 1,
            timestamp: 1234567890,
        };

        let hash1 = block1.calculate_hash();

        block1.nonce = 2;
        let hash2 = block1.calculate_hash();

        // Different nonce should produce different hash
        assert_ne!(hash1, hash2);
    }

    #[test]
    fn test_block_timestamp_affects_hash() {
        let mut block1 = Block {
            account: "UAT_TEST".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 1000 * VOID_PER_UAT,
            link: "UAT_DEST".to_string(),
            signature: "sig".to_string(),
            work: 12345,
            nonce: 1,
            timestamp: 1234567890,
        };

        let hash1 = block1.calculate_hash();

        block1.timestamp = 1234567891;
        let hash2 = block1.calculate_hash();

        // Different timestamp should produce different hash (replay protection)
        assert_ne!(hash1, hash2);
    }
}

#[cfg(test)]
mod ledger_tests {
    use super::*;

    #[test]
    fn test_ledger_initialization() {
        let ledger = Ledger::new();
        assert_eq!(ledger.accounts.len(), 0);
        assert_eq!(ledger.blocks.len(), 0);
    }

    #[test]
    fn test_account_nonce_initialization() {
        let mut ledger = Ledger::new();

        // Create account
        ledger.accounts.insert(
            "UAT_TEST".to_string(),
            AccountState {
                head: "0".to_string(),
                balance: 1000 * VOID_PER_UAT,
                block_count: 0,
                nonce: 0,
            },
        );

        let account = ledger.accounts.get("UAT_TEST").unwrap();
        assert_eq!(account.nonce, 0);
    }
}

#[cfg(test)]
mod crypto_tests {
    use super::*;
    use uat_crypto::hd_wallet::HdWallet;

    #[test]
    fn test_hd_wallet_generation() {
        let wallet = HdWallet::generate(12).unwrap();
        assert!(!wallet.mnemonic().is_empty());

        let words: Vec<&str> = wallet.mnemonic().split_whitespace().collect();
        assert_eq!(words.len(), 12);
    }

    #[test]
    fn test_hd_wallet_deterministic_derivation() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let wallet1 = HdWallet::from_mnemonic(mnemonic).unwrap();
        let wallet2 = HdWallet::from_mnemonic(mnemonic).unwrap();

        let (_, _, addr1) = wallet1.derive_key(0, 0, 0).unwrap();
        let (_, _, addr2) = wallet2.derive_key(0, 0, 0).unwrap();

        assert_eq!(addr1, addr2);
    }

    #[test]
    fn test_hd_wallet_multiple_addresses() {
        let wallet = HdWallet::generate(12).unwrap();

        let mut addresses = Vec::new();
        for i in 0..5 {
            let (_, _, address) = wallet.derive_key(0, 0, i).unwrap();
            addresses.push(address);
        }

        // All addresses should be unique
        let unique: std::collections::HashSet<_> = addresses.iter().collect();
        assert_eq!(unique.len(), 5);
    }

    #[test]
    fn test_hd_wallet_address_format() {
        let wallet = HdWallet::generate(12).unwrap();
        let (_, _, address) = wallet.derive_key(0, 0, 0).unwrap();

        // UAT addresses should start with "UAT"
        assert!(address.starts_with("UAT"));
        // Should be hex address after prefix
        assert!(address.len() > 3);
    }
}

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_full_transaction_flow() {
        let mut ledger = Ledger::new();
        let mut mempool = Mempool::new(100);

        // Create sender account
        ledger.accounts.insert(
            "UAT_SENDER".to_string(),
            AccountState {
                head: "0".to_string(),
                balance: 10000 * VOID_PER_UAT,
                block_count: 0,
                nonce: 0,
            },
        );

        // Create transaction
        let block = Block {
            account: "UAT_SENDER".to_string(),
            previous: "0".to_string(),
            block_type: BlockType::Send,
            amount: 1000 * VOID_PER_UAT,
            link: "UAT_RECEIVER".to_string(),
            signature: "test_sig".to_string(),
            work: 12345,
            nonce: 1,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };

        // Add to mempool
        let hash = mempool.add_transaction(block.clone(), 100).unwrap();
        assert!(mempool.get_transaction(&hash).is_some());

        // Simulate processing
        let next_txs = mempool.get_next_transactions(1);
        assert_eq!(next_txs.len(), 1);

        // Remove from mempool after processing
        mempool.remove_transaction(&hash);
        assert!(mempool.get_transaction(&hash).is_none());
    }
}
