use reqwest;
use serde_json::Value;

pub struct Oracle;

impl Oracle {
    /// Mengambil harga ETH dalam IDR saat ini
    pub async fn get_eth_price_idr() -> Result<f64, Box<dyn std::error::Error>> {
        let url = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=idr";
        let resp: Value = reqwest::get(url).await?.json().await?;
        let price = resp["ethereum"]["idr"].as_f64().unwrap_or(0.0);
        Ok(price)
    }

    /// Verifikasi apakah TXID Ethereum benar-benar sebuah "Burn"
    /// Catatan: Ini draf sederhana, di produksi butuh pengecekan address tujuan
    pub async fn verify_eth_burn(txid: &str) -> Result<f64, Box<dyn std::error::Error>> {
        let url = format!("https://api.blockcypher.com/v1/eth/main/txs/{}", txid);
        let resp: Value = reqwest::get(url).await?.json().await?;
        
        // Ambil nilai dalam WEI dan konversi ke ETH
        let value_wei = resp["total"].as_f64().unwrap_or(0.0);
        let value_eth = value_wei / 1_000_000_000_000_000_000.0;
        
        Ok(value_eth)
    }
}