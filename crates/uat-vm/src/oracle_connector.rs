// Oracle Connector for External Price Feeds (Exchange Integration)
// Allows smart contracts to fetch real-time UAT price from exchanges

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExchangePrice {
    pub exchange: String,       // "binance", "coinbase", "kraken"
    pub pair: String,           // "UAT/USDT", "UAT/BTC"
    pub price: f64,             // Current price
    pub volume_24h: f64,        // 24h volume
    pub timestamp: u64,         // Last update timestamp
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OracleConsensusPrice {
    pub median_price: f64,      // Byzantine-resistant median
    pub sources: Vec<ExchangePrice>,
    pub confidence: f64,        // 0.0-1.0 (based on source agreement)
}

/// Smart Contract Oracle Interface
/// This is what payment smart contracts will call
pub trait PriceOracle {
    /// Get current UAT price in USD (median from multiple exchanges)
    fn get_uat_price_usd(&self) -> Result<f64, String>;
    
    /// Get UAT price from specific exchange
    fn get_uat_price_from_exchange(&self, exchange: &str) -> Result<f64, String>;
    
    /// Get full consensus data (all sources + median)
    fn get_oracle_consensus(&self) -> Result<OracleConsensusPrice, String>;
    
    /// Verify if price is within acceptable deviation (anti-manipulation)
    fn verify_price_sanity(&self, price: f64) -> Result<bool, String>;
}

/// Implementation (used by UVM when contract calls oracle)
pub struct ExchangeOracle {
    price_feeds: HashMap<String, ExchangePrice>,
    last_update: u64,
    update_interval_secs: u64,
}

impl ExchangeOracle {
    pub fn new() -> Self {
        Self {
            price_feeds: HashMap::new(),
            last_update: 0,
            update_interval_secs: 60, // Update every 60 seconds
        }
    }
    
    /// Fetch prices from multiple exchanges (called by background worker)
    pub async fn fetch_exchange_prices(&mut self) -> Result<(), String> {
        // Example: Fetch from Binance API
        let binance_price = self.fetch_from_binance().await?;
        self.price_feeds.insert("binance".to_string(), binance_price);
        
        // Example: Fetch from Coinbase API
        let coinbase_price = self.fetch_from_coinbase().await?;
        self.price_feeds.insert("coinbase".to_string(), coinbase_price);
        
        // Example: Fetch from Kraken API
        let kraken_price = self.fetch_from_kraken().await?;
        self.price_feeds.insert("kraken".to_string(), kraken_price);
        
        self.last_update = chrono::Utc::now().timestamp() as u64;
        Ok(())
    }
    
    async fn fetch_from_binance(&self) -> Result<ExchangePrice, String> {
        // TODO: Implement actual API call
        // Example: https://api.binance.com/api/v3/ticker/24hr?symbol=UATUSDT
        Ok(ExchangePrice {
            exchange: "binance".to_string(),
            pair: "UAT/USDT".to_string(),
            price: 0.01, // Placeholder
            volume_24h: 1_000_000.0,
            timestamp: chrono::Utc::now().timestamp() as u64,
        })
    }
    
    async fn fetch_from_coinbase(&self) -> Result<ExchangePrice, String> {
        // TODO: Implement actual API call
        // Example: https://api.coinbase.com/v2/prices/UAT-USD/spot
        Ok(ExchangePrice {
            exchange: "coinbase".to_string(),
            pair: "UAT-USD".to_string(),
            price: 0.0099, // Placeholder
            volume_24h: 500_000.0,
            timestamp: chrono::Utc::now().timestamp() as u64,
        })
    }
    
    async fn fetch_from_kraken(&self) -> Result<ExchangePrice, String> {
        // TODO: Implement actual API call
        // Example: https://api.kraken.com/0/public/Ticker?pair=UATUSD
        Ok(ExchangePrice {
            exchange: "kraken".to_string(),
            pair: "UATUSD".to_string(),
            price: 0.0101, // Placeholder
            volume_24h: 750_000.0,
            timestamp: chrono::Utc::now().timestamp() as u64,
        })
    }
}

impl PriceOracle for ExchangeOracle {
    fn get_uat_price_usd(&self) -> Result<f64, String> {
        if self.price_feeds.is_empty() {
            return Err("No price feeds available".to_string());
        }
        
        // Calculate median price (Byzantine-resistant)
        let mut prices: Vec<f64> = self.price_feeds
            .values()
            .map(|p| p.price)
            .collect();
        
        prices.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let median = prices[prices.len() / 2];
        
        Ok(median)
    }
    
    fn get_uat_price_from_exchange(&self, exchange: &str) -> Result<f64, String> {
        self.price_feeds
            .get(exchange)
            .map(|p| p.price)
            .ok_or_else(|| format!("Exchange {} not found", exchange))
    }
    
    fn get_oracle_consensus(&self) -> Result<OracleConsensusPrice, String> {
        let median = self.get_uat_price_usd()?;
        
        // Calculate confidence (how close are prices to each other?)
        let prices: Vec<f64> = self.price_feeds.values().map(|p| p.price).collect();
        let max_price = prices.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let min_price = prices.iter().cloned().fold(f64::INFINITY, f64::min);
        
        let deviation = (max_price - min_price) / median;
        let confidence = 1.0 - deviation.min(1.0); // High confidence if prices agree
        
        Ok(OracleConsensusPrice {
            median_price: median,
            sources: self.price_feeds.values().cloned().collect(),
            confidence,
        })
    }
    
    fn verify_price_sanity(&self, price: f64) -> Result<bool, String> {
        let median = self.get_uat_price_usd()?;
        let deviation = ((price - median).abs() / median) * 100.0;
        
        // Reject if price deviates more than 10% from oracle consensus
        if deviation > 10.0 {
            return Ok(false);
        }
        
        Ok(true)
    }
}

impl Default for ExchangeOracle {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_median_price_calculation() {
        let mut oracle = ExchangeOracle::new();
        
        oracle.price_feeds.insert("binance".to_string(), ExchangePrice {
            exchange: "binance".to_string(),
            pair: "UAT/USDT".to_string(),
            price: 0.010,
            volume_24h: 1_000_000.0,
            timestamp: 0,
        });
        
        oracle.price_feeds.insert("coinbase".to_string(), ExchangePrice {
            exchange: "coinbase".to_string(),
            pair: "UAT-USD".to_string(),
            price: 0.011,
            volume_24h: 500_000.0,
            timestamp: 0,
        });
        
        oracle.price_feeds.insert("kraken".to_string(), ExchangePrice {
            exchange: "kraken".to_string(),
            pair: "UATUSD".to_string(),
            price: 0.0105,
            volume_24h: 750_000.0,
            timestamp: 0,
        });
        
        let median = oracle.get_uat_price_usd().unwrap();
        assert_eq!(median, 0.0105); // Median of [0.010, 0.0105, 0.011]
    }
    
    #[test]
    fn test_price_sanity_check() {
        let mut oracle = ExchangeOracle::new();
        
        oracle.price_feeds.insert("binance".to_string(), ExchangePrice {
            exchange: "binance".to_string(),
            pair: "UAT/USDT".to_string(),
            price: 0.01,
            volume_24h: 1_000_000.0,
            timestamp: 0,
        });
        
        // Test within range (should pass)
        assert!(oracle.verify_price_sanity(0.0105).unwrap());
        
        // Test outside range (should fail)
        assert!(!oracle.verify_price_sanity(0.02).unwrap()); // 100% deviation
    }
    
    #[test]
    fn test_oracle_consensus() {
        let mut oracle = ExchangeOracle::new();
        
        // Add similar prices (high confidence expected)
        oracle.price_feeds.insert("binance".to_string(), ExchangePrice {
            exchange: "binance".to_string(),
            pair: "UAT/USDT".to_string(),
            price: 0.0100,
            volume_24h: 1_000_000.0,
            timestamp: 0,
        });
        
        oracle.price_feeds.insert("coinbase".to_string(), ExchangePrice {
            exchange: "coinbase".to_string(),
            pair: "UAT-USD".to_string(),
            price: 0.0101,
            volume_24h: 500_000.0,
            timestamp: 0,
        });
        
        let consensus = oracle.get_oracle_consensus().unwrap();
        assert!(consensus.confidence > 0.9); // High confidence
        assert_eq!(consensus.sources.len(), 2);
    }
}
