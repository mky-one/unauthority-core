use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use uat_core::{Block, BlockType, Ledger, VOID_PER_UAT, AccountState};
use uat_crypto;
use uat_network::{UatNode, NetworkEvent};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::time::Duration;
use std::fs;
use serde_json::Value;

const LEDGER_FILE: &str = "ledger_state.json";
const WALLET_FILE: &str = "wallet.json";
const BURN_ADDRESS_ETH: &str = "0x000000000000000000000000000000000000dead";
const BURN_ADDRESS_BTC: &str = "1111111111111111111114oLvT2";

const BOOTSTRAP_NODES: &[&str] = &[
    "/ip4/127.0.0.1/tcp/63351", // Sesuaikan dengan Node 1 lo
];

// --- ORACLE FUNCTIONS ---

async fn get_crypto_prices() -> (f64, f64) {
    let url = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=idr";
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .timeout(Duration::from_secs(10))
        .build()
        .unwrap_or_default();

    if let Ok(resp) = client.get(url).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            let eth_price = json["ethereum"]["idr"].as_f64().unwrap_or(35_000_000.0);
            let btc_price = json["bitcoin"]["idr"].as_f64().unwrap_or(1_000_000_000.0);
            return (eth_price, btc_price);
        }
    }
    (35_000_000.0, 1_000_000_000.0) 
}

async fn verify_eth_burn_tx(txid: &str) -> Option<f64> {
    let clean_txid = txid.trim().trim_start_matches("0x").to_lowercase();
    let url = format!("https://api.blockcypher.com/v1/eth/main/txs/{}", clean_txid);
    let client = reqwest::Client::builder().timeout(Duration::from_secs(10)).build().ok()?;
    
    println!("🌐 Oracle ETH: Verifikasi TXID {}...", clean_txid);
    
    if let Ok(resp) = client.get(url).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(outputs) = json["outputs"].as_array() {
                let target = BURN_ADDRESS_ETH.to_lowercase().replace("0x", "");
                for out in outputs {
                    if let Some(addrs) = out["addresses"].as_array() {
                        for a in addrs {
                            if a.as_str().unwrap_or("").to_lowercase() == target {
                                let wei = out["value"].as_f64().unwrap_or(0.0);
                                return Some(wei / 1_000_000_000_000_000_000.0);
                            }
                        }
                    }
                }
            }
        }
    }
    None
}

async fn verify_btc_burn_tx(txid: &str) -> Option<f64> {
    let url = format!("https://mempool.space/api/tx/{}", txid.trim());
    let client = reqwest::Client::builder().user_agent("Mozilla/5.0").timeout(Duration::from_secs(10)).build().ok()?;

    println!("🌐 Oracle BTC: Membedah TXID {}...", txid);
    
    if let Ok(resp) = client.get(url).send().await {
        if let Ok(body_text) = resp.text().await {
            if let Ok(json) = serde_json::from_str::<Value>(&body_text) {
                if let Some(vout) = json["vout"].as_array() {
                    for out in vout.iter() {
                        if out.to_string().contains(BURN_ADDRESS_BTC) {
                            let satoshis = out["value"].as_f64().unwrap_or(0.0);
                            return Some(satoshis / 100_000_000.0);
                        }
                    }
                }
            }
        }
    }
    None
}

// --- UTILS ---

fn get_short_addr(full_addr: &str) -> String {
    if full_addr.len() < 12 { return full_addr.to_string(); }
    format!("uat_{}", &full_addr[..12])
}

fn save_to_disk(ledger: &Ledger) {
    if let Ok(data) = serde_json::to_string_pretty(ledger) { let _ = fs::write(LEDGER_FILE, data); }
}

fn load_from_disk() -> Ledger {
    if let Ok(data) = fs::read_to_string(LEDGER_FILE) {
        if let Ok(l) = serde_json::from_str(&data) { return l; }
    }
    Ledger::new()
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let keys: uat_crypto::KeyPair = if let Ok(data) = fs::read_to_string(WALLET_FILE) {
        serde_json::from_str(&data)?
    } else {
        let new_k = uat_crypto::generate_keypair();
        fs::write(WALLET_FILE, serde_json::to_string(&new_k)?)?;
        new_k
    };

    let my_address = hex::encode(&keys.public_key);
    let my_short = get_short_addr(&my_address);
    let secret_key = keys.secret_key.clone();
    
    let ledger = Arc::new(Mutex::new(load_from_disk()));
    let address_book = Arc::new(Mutex::new(HashMap::<String, String>::new()));

    {
        let mut l = ledger.lock().unwrap();
        if !l.accounts.contains_key(&my_address) {
            l.accounts.insert(my_address.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0 });
            save_to_disk(&l);
        }
    }

    let (tx_out, rx_out) = mpsc::channel(32);
    let (tx_in, mut rx_in) = mpsc::channel(32);

    tokio::spawn(async move { let _ = UatNode::start(tx_in, rx_out).await; });

    let tx_boot = tx_out.clone();
    let my_addr_boot = my_address.clone();
    let ledger_boot = Arc::clone(&ledger);
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(5)).await;
        for addr in BOOTSTRAP_NODES {
            let _ = tx_boot.send(format!("DIAL:{}", addr)).await;
            tokio::time::sleep(Duration::from_secs(2)).await;
            let (s, b) = { let l = ledger_boot.lock().unwrap(); (l.distribution.remaining_supply, l.distribution.total_burned_idr) };
            let _ = tx_boot.send(format!("ID:{}:{}:{}", my_addr_boot, s, b)).await;
        }
    });

    println!("\n==================================================================");
    println!("                 UNAUTHORITY (UAT) ORACLE NODE                   ");
    println!("==================================================================");
    println!("🆔 MY ID        : {}", my_short);
    println!("💾 DATABASE     : {}", LEDGER_FILE);
    println!("------------------------------------------------------------------");
    println!("📖 PERINTAH:");
    println!("   bal                   - Cek saldo");
    println!("   burn <eth|btc> <TXID> - Mint UAT dari Burn ETH/BTC");
    println!("   supply                - Cek total supply & burn");
    println!("   peers                 - List node aktif");
    println!("   dial <addr>           - Koneksi manual");
    println!("   send <ID> <AMT>       - Kirim koin");
    println!("   addr                  - Alamat lengkap");
    println!("   exit                  - Keluar aplikasi");
    println!("------------------------------------------------------------------");

    let mut stdin = BufReader::new(io::stdin()).lines();

    loop {
        tokio::select! {
            Ok(Some(line)) = stdin.next_line() => {
                let p: Vec<&str> = line.split_whitespace().collect();
                if p.is_empty() { continue; }
                match p[0] {
                    "addr" => println!("🆔 Alamat: {}", my_address),
                    "bal" => {
                        let l = ledger.lock().unwrap();
                        let b = l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0);
                        println!("📊 Saldo: {} UAT", b / VOID_PER_UAT);
                    },
                    "supply" => {
                        let l = ledger.lock().unwrap();
                        println!("📉 Supply: {} UAT | 🔥 Burn: Rp{}", l.distribution.remaining_supply / VOID_PER_UAT, l.distribution.total_burned_idr);
                    },
                    "peers" => {
                        let ab = address_book.lock().unwrap();
                        println!("👥 Peers: {}", ab.len());
                        for (s, f) in ab.iter() { println!("  - {}: {}", s, f); }
                    },
                    "dial" => {
                        if p.len() == 2 {
                            let tx = tx_out.clone();
                            let ma = my_address.clone();
                            let (s, b) = { let l = ledger.lock().unwrap(); (l.distribution.remaining_supply, l.distribution.total_burned_idr) };
                            let target = p[1].to_string();
                            tokio::spawn(async move {
                                let _ = tx.send(format!("DIAL:{}", target)).await;
                                tokio::time::sleep(Duration::from_secs(2)).await;
                                let _ = tx.send(format!("ID:{}:{}:{}", ma, s, b)).await;
                            });
                        }
                    },
                    "burn" => {
                        if p.len() == 3 {
                            let (ep, bp) = get_crypto_prices().await;
                            let res = if p[1] == "eth" { verify_eth_burn_tx(p[2]).await.map(|a| (a, ep, "ETH")) } 
                                      else { verify_btc_burn_tx(p[2]).await.map(|a| (a, bp, "BTC")) };

                            if let Some((amt, prc, sym)) = res {
                                let idr = (amt * prc) as u128;
                                let mut l = ledger.lock().unwrap();
                                let yld = l.distribution.calculate_yield(idr);
                                let state = l.accounts.get(&my_address).unwrap().clone();
                                let mut blk = Block {
                                    account: my_address.clone(), previous: state.head, block_type: BlockType::Mint,
                                    amount: yld, link: format!("{}:{}", sym, p[2]), signature: "".to_string(), work: 0,
                                };
                                blk.signature = hex::encode(uat_crypto::sign_message(blk.calculate_hash().as_bytes(), &secret_key).unwrap());
                                if l.process_block(&blk).is_ok() {
                                    l.distribution.total_burned_idr += idr;
                                    save_to_disk(&l);
                                    let _ = tx_out.send(serde_json::to_string(&blk).unwrap()).await;
                                    println!("🔥 Terdeteksi: {} {} (Nilai: Rp{})", amt, sym, idr);
                                    println!("✅ MINT BERHASIL: +{} UAT", yld / VOID_PER_UAT);
                                }
                            } else { println!("❌ Verifikasi gagal. TXID salah atau belum masuk Burn Address."); }
                        }
                    },
                    "send" => {
                        if p.len() == 3 {
                            let amt = p[2].parse::<u128>().unwrap_or(0) * VOID_PER_UAT;
                            if let Some(d) = address_book.lock().unwrap().get(p[1]).cloned() {
                                let mut l = ledger.lock().unwrap();
                                let state = l.accounts.get(&my_address).unwrap().clone();
                                let mut blk = Block {
                                    account: my_address.clone(), previous: state.head, block_type: BlockType::Send,
                                    amount: amt, link: d, signature: "".to_string(), work: 0,
                                };
                                blk.signature = hex::encode(uat_crypto::sign_message(blk.calculate_hash().as_bytes(), &secret_key).unwrap());
                                if l.process_block(&blk).is_ok() {
                                    save_to_disk(&l);
                                    let _ = tx_out.send(serde_json::to_string(&blk).unwrap()).await;
                                    println!("🚀 Sent!");
                                }
                            }
                        }
                    },
                    "exit" => break,
                    _ => {}
                }
            },
            Some(event) = rx_in.recv() => {
                match event {
                    NetworkEvent::NewBlock(data) => {
                        if data.starts_with("ID:") {
                            // Logic handshake (tetap sama)
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() >= 4 {
                                let full = parts[1].to_string();
                                let rem_s = parts[2].parse::<u128>().unwrap_or(0);
                                let tot_b = parts[3].parse::<u128>().unwrap_or(0);
                                if full != my_address {
                                    let short = get_short_addr(&full);
                                    address_book.lock().unwrap().insert(short.clone(), full.clone());
                                    let mut l = ledger.lock().unwrap();
                                    
                                    // SYNC TOTAL BURN JUGA DI SINI
                                    if rem_s < l.distribution.remaining_supply && rem_s != 0 {
                                        l.distribution.remaining_supply = rem_s;
                                        l.distribution.total_burned_idr = tot_b; // SYNC NILAI RUPIAH
                                        save_to_disk(&l);
                                        println!("🔄 Ledger Synced (Supply & Burn) with Peer: {}", short);
                                    }
                                    
                                    println!("🤝 Handshake Berhasil! Peer: {}", short);
                                    let (s, b) = (l.distribution.remaining_supply, l.distribution.total_burned_idr);
                                    let _ = tx_out.send(format!("ID:{}:{}:{}", my_address, s, b)).await;
                                }
                            }
                        } else if let Ok(inc) = serde_json::from_str::<Block>(&data) {
                            let mut l = ledger.lock().unwrap();
                            
                            if !l.accounts.contains_key(&inc.account) {
                                l.accounts.insert(inc.account.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0 });
                            }

                            // Biarkan process_block yang menangani validasi dan pengurangan supply internal
                            if let Ok(_hash) = l.process_block(&inc) {
                                if inc.block_type == BlockType::Mint {
                                    // JANGAN kurangi remaining_supply di sini! (Sudah dilakukan di process_block)
                                    
                                    // Kita cuma perlu update angka Rupiah-nya untuk tampilan display 'supply'
                                    let burn_val = inc.amount / VOID_PER_UAT;
                                    l.distribution.total_burned_idr += burn_val;
                                    
                                    println!("🔥 Network Mint Verified: +{} UAT", burn_val);
                                }

                                save_to_disk(&l);
                                
                                // Logic auto-receive (tetap sama)
                                if inc.block_type == BlockType::Send && inc.link == my_address {
                                    let state = l.accounts.get(&my_address).unwrap().clone();
                                    let mut rb = Block {
                                        account: my_address.clone(), previous: state.head, block_type: BlockType::Receive,
                                        amount: inc.amount, link: _hash, signature: "".to_string(), work: 0,
                                    };
                                    rb.signature = hex::encode(uat_crypto::sign_message(rb.calculate_hash().as_bytes(), &secret_key).unwrap());
                                    if l.process_block(&rb).is_ok() {
                                        save_to_disk(&l);
                                        let _ = tx_out.send(serde_json::to_string(&rb).unwrap()).await;
                                        println!("📥 Received!");
                                    }
                                }
                            }
                        }
                    },
                    _ => {}
                }
            }
        }
    }
    Ok(())
}