/// Decentralized Oracle Consensus System
/// 
/// Implements Byzantine Fault Tolerant oracle price consensus using median aggregation.
/// Prevents single validator from manipulating BTC/ETH prices for PoB distribution.
/// 
/// **Security Model:**
/// - Minimum 2f+1 submissions required (f = faulty nodes)
/// - Median price resists outliers (cannot be manipulated by minority)
/// - Submission window: 60 seconds (configurable)
/// - Outlier detection: >20% deviation from median = flagged
/// 
/// **Workflow:**
/// 1. Each validator fetches ETH/BTC prices from external APIs
/// 2. Broadcasts price submission via P2P: "ORACLE_SUBMIT:addr:eth_price:btc_price"
/// 3. All validators collect submissions within time window
/// 4. Calculate median (Byzantine-resistant)
/// 5. Use consensus price for PoB burn calculations

use std::collections::HashMap;
use serde::{Serialize, Deserialize};

/// Price submission from a validator
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PriceSubmission {
    pub validator_address: String,
    pub eth_price_usd: f64,
    pub btc_price_usd: f64,
    pub timestamp: u64,
}

/// Oracle consensus state
pub struct OracleConsensus {
    /// Validator submissions: address -> PriceSubmission
    submissions: HashMap<String, PriceSubmission>,
    
    /// Submission window in seconds (default: 60s)
    submission_window_secs: u64,
    
    /// Minimum submissions required (2f+1 for BFT)
    min_submissions: usize,
    
    /// Outlier threshold percentage (default: 20%)
    outlier_threshold_percent: f64,
}

impl OracleConsensus {
    /// Create new oracle consensus with default settings
    pub fn new() -> Self {
        Self {
            submissions: HashMap::new(),
            submission_window_secs: 60,
            min_submissions: 2, // For 3 validators: 2f+1 = 2 (f=0.5, rounded up to 1, so 2*1+1=2)
            outlier_threshold_percent: 20.0,
        }
    }

    /// Create with custom configuration
    pub fn with_config(
        submission_window_secs: u64,
        min_submissions: usize,
        outlier_threshold_percent: f64,
    ) -> Self {
        Self {
            submissions: HashMap::new(),
            submission_window_secs,
            min_submissions,
            outlier_threshold_percent,
        }
    }

    /// Submit price from a validator (broadcast via P2P)
    pub fn submit_price(
        &mut self,
        validator_address: String,
        eth_price_usd: f64,
        btc_price_usd: f64,
    ) {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        let submission = PriceSubmission {
            validator_address: validator_address.clone(),
            eth_price_usd,
            btc_price_usd,
            timestamp,
        };
        
        self.submissions.insert(validator_address.clone(), submission);
        
        println!("📊 Oracle submission from {}: ETH=${:.2}, BTC=${:.2}",
            &validator_address[..std::cmp::min(12, validator_address.len())],
            eth_price_usd,
            btc_price_usd
        );
    }

    /// Get consensus price (median of recent submissions)
    /// Returns None if insufficient submissions
    pub fn get_consensus_price(&self) -> Option<(f64, f64)> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        // Filter recent submissions (within window)
        let recent: Vec<&PriceSubmission> = self.submissions
            .values()
            .filter(|s| now - s.timestamp < self.submission_window_secs)
            .collect();
        
        // Check if we have enough submissions (BFT requirement)
        if recent.len() < self.min_submissions {
            println!("⚠️  Insufficient oracle submissions: {} (need ≥{})",
                recent.len(), self.min_submissions);
            return None;
        }
        
        // Extract prices
        let mut eth_prices: Vec<f64> = recent.iter().map(|s| s.eth_price_usd).collect();
        let mut btc_prices: Vec<f64> = recent.iter().map(|s| s.btc_price_usd).collect();
        
        // Sort for median calculation
        eth_prices.sort_by(|a, b| a.partial_cmp(b).unwrap());
        btc_prices.sort_by(|a, b| a.partial_cmp(b).unwrap());
        
        // Calculate median (Byzantine-resistant)
        let eth_median = self.calculate_median(&eth_prices);
        let btc_median = self.calculate_median(&btc_prices);
        
        println!("✅ Oracle consensus reached: ETH=${:.2}, BTC=${:.2} (from {} validators)",
            eth_median, btc_median, recent.len());
        
        Some((eth_median, btc_median))
    }

    /// Calculate median of sorted array
    fn calculate_median(&self, sorted_values: &[f64]) -> f64 {
        let len = sorted_values.len();
        if len == 0 {
            return 0.0;
        }
        
        if len % 2 == 1 {
            // Odd number: return middle value
            sorted_values[len / 2]
        } else {
            // Even number: return average of two middle values
            (sorted_values[len / 2 - 1] + sorted_values[len / 2]) / 2.0
        }
    }

    /// Detect outlier validators (possible price manipulation)
    /// Returns list of validator addresses with suspicious prices
    pub fn detect_outliers(&self) -> Vec<String> {
        let consensus = match self.get_consensus_price() {
            Some(p) => p,
            None => return vec![],
        };
        
        let (median_eth, median_btc) = consensus;
        let mut outliers = Vec::new();
        
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        for (validator, submission) in &self.submissions {
            // Only check recent submissions
            if now - submission.timestamp >= self.submission_window_secs {
                continue;
            }
            
            let eth_deviation = ((submission.eth_price_usd - median_eth).abs() / median_eth) * 100.0;
            let btc_deviation = ((submission.btc_price_usd - median_btc).abs() / median_btc) * 100.0;
            
            // If deviation > threshold%, flag as outlier
            if eth_deviation > self.outlier_threshold_percent || btc_deviation > self.outlier_threshold_percent {
                println!("🚨 Oracle outlier detected: {} (ETH: {:.1}%, BTC: {:.1}%)",
                    &validator[..std::cmp::min(12, validator.len())],
                    eth_deviation,
                    btc_deviation
                );
                outliers.push(validator.clone());
            }
        }
        
        outliers
    }

    /// Cleanup old submissions (garbage collection)
    pub fn cleanup_old(&mut self) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        let cutoff = now - (self.submission_window_secs * 2);
        
        let before_count = self.submissions.len();
        self.submissions.retain(|_, s| s.timestamp > cutoff);
        let removed = before_count - self.submissions.len();
        
        if removed > 0 {
            println!("🧹 Oracle cleanup: removed {} old submissions", removed);
        }
    }

    /// Get current submission count
    pub fn submission_count(&self) -> usize {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        self.submissions
            .values()
            .filter(|s| now - s.timestamp < self.submission_window_secs)
            .count()
    }

    /// Get all recent submissions (for debugging)
    pub fn get_recent_submissions(&self) -> Vec<PriceSubmission> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        self.submissions
            .values()
            .filter(|s| now - s.timestamp < self.submission_window_secs)
            .cloned()
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_median_calculation() {
        let oracle = OracleConsensus::new();
        
        // Odd number of values
        let odd = vec![10.0, 20.0, 30.0, 40.0, 50.0];
        assert_eq!(oracle.calculate_median(&odd), 30.0);
        
        // Even number of values
        let even = vec![10.0, 20.0, 30.0, 40.0];
        assert_eq!(oracle.calculate_median(&even), 25.0);
        
        // Single value
        let single = vec![42.0];
        assert_eq!(oracle.calculate_median(&single), 42.0);
    }

    #[test]
    fn test_byzantine_resistance() {
        let mut oracle = OracleConsensus::new();
        
        // 2 honest validators
        oracle.submit_price("VAL1".to_string(), 50_000_000.0, 1_000_000_000.0);
        oracle.submit_price("VAL2".to_string(), 51_000_000.0, 1_010_000_000.0);
        
        // 1 malicious validator (trying to manipulate 2x price)
        oracle.submit_price("VAL_EVIL".to_string(), 100_000_000.0, 2_000_000_000.0);
        
        let (eth, btc) = oracle.get_consensus_price().unwrap();
        
        // Median resists the outlier (should be ~50-51M, not 100M)
        assert!((eth - 51_000_000.0).abs() < 2_000_000.0);
        assert!((btc - 1_010_000_000.0).abs() < 20_000_000.0);
        
        // Detect the outlier
        let outliers = oracle.detect_outliers();
        assert_eq!(outliers.len(), 1);
        assert!(outliers[0].contains("EVIL"));
    }

    #[test]
    fn test_insufficient_submissions() {
        let mut oracle = OracleConsensus::with_config(60, 3, 20.0); // Require 3 submissions
        
        // Only 1 submission (insufficient)
        oracle.submit_price("VAL1".to_string(), 50_000_000.0, 1_000_000_000.0);
        
        let result = oracle.get_consensus_price();
        assert!(result.is_none());
    }

    #[test]
    fn test_submission_window_expiry() {
        let mut oracle = OracleConsensus::with_config(1, 2, 20.0); // 1 second window
        
        oracle.submit_price("VAL1".to_string(), 50_000_000.0, 1_000_000_000.0);
        oracle.submit_price("VAL2".to_string(), 51_000_000.0, 1_010_000_000.0);
        
        // Should work immediately
        assert!(oracle.get_consensus_price().is_some());
        
        // Wait for expiry (simulation - in real code this would sleep)
        // Since we can't sleep in tests, we manually set old timestamp
        for submission in oracle.submissions.values_mut() {
            submission.timestamp -= 2; // Make it 2 seconds old
        }
        
        // Should fail now (expired)
        assert!(oracle.get_consensus_price().is_none());
    }

    #[test]
    fn test_cleanup_old_submissions() {
        let mut oracle = OracleConsensus::with_config(60, 2, 20.0);
        
        oracle.submit_price("VAL1".to_string(), 50_000_000.0, 1_000_000_000.0);
        oracle.submit_price("VAL2".to_string(), 51_000_000.0, 1_010_000_000.0);
        
        assert_eq!(oracle.submissions.len(), 2);
        
        // Make submissions very old
        for submission in oracle.submissions.values_mut() {
            submission.timestamp -= 200; // 200 seconds old
        }
        
        oracle.cleanup_old();
        assert_eq!(oracle.submissions.len(), 0);
    }

    #[test]
    fn test_outlier_detection() {
        let mut oracle = OracleConsensus::with_config(60, 2, 10.0); // 10% threshold
        
        // Normal submissions
        oracle.submit_price("VAL1".to_string(), 50_000_000.0, 1_000_000_000.0);
        oracle.submit_price("VAL2".to_string(), 52_000_000.0, 1_020_000_000.0);
        
        // Outlier (15% higher)
        oracle.submit_price("VAL3".to_string(), 57_500_000.0, 1_150_000_000.0);
        
        let outliers = oracle.detect_outliers();
        assert_eq!(outliers.len(), 1);
        assert_eq!(outliers[0], "VAL3");
    }
}
