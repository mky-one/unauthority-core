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
// --- TAMBAHAN: HTTP API MODULE ---
use warp::Filter;

const LEDGER_FILE: &str = "ledger_state.json";
const WALLET_FILE: &str = "wallet.json";
const BURN_ADDRESS_ETH: &str = "0x000000000000000000000000000000000000dead";
const BURN_ADDRESS_BTC: &str = "1111111111111111111114oLvT2";

const BOOTSTRAP_NODES: &[&str] = &[];


// Struktur data untuk Request Body saat kirim uang
#[derive(serde::Deserialize, serde::Serialize)]
struct SendRequest {
    target: String,
    amount: u128,
}

#[derive(serde::Deserialize, serde::Serialize)]
struct BurnRequest {
    coin_type: String, // "eth" atau "btc"
    txid: String,
}

// Helper untuk menyuntikkan (inject) state ke dalam route handler
fn with_state<T: Clone + Send>(state: T) -> impl Filter<Extract = (T,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

pub async fn start_api_server(
    ledger: Arc<Mutex<Ledger>>,
    tx_out: mpsc::Sender<String>,
    pending_sends: Arc<Mutex<HashMap<String, (Block, u32)>>>,
    pending_burns: Arc<Mutex<HashMap<String, (f64, f64, String, u128)>>>,
    address_book: Arc<Mutex<HashMap<String, String>>>,
    my_address: String,
    secret_key: Vec<u8>,
    api_port: u16,
) {
    // 1. GET /bal/:address
    let l_bal = ledger.clone();
    let balance_route = warp::path!("bal" / String)
        .and(with_state(l_bal))
        .map(|addr: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            let full_addr = l_guard.accounts.keys().find(|k| get_short_addr(k) == addr || **k == addr).cloned().unwrap_or(addr);
            let bal = l_guard.accounts.get(&full_addr).map(|a| a.balance).unwrap_or(0);
            warp::reply::json(&serde_json::json!({ "address": full_addr, "balance_uat": bal / VOID_PER_UAT }))
        });

    // 2. GET /supply
    let l_sup = ledger.clone();
    let supply_route = warp::path("supply")
        .and(with_state(l_sup))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            warp::reply::json(&serde_json::json!({ 
                "remaining_supply": l_guard.distribution.remaining_supply / VOID_PER_UAT, 
                "total_burned_idr": l_guard.distribution.total_burned_idr 
            }))
        });

    // 3. GET /history/:address
    let l_his = ledger.clone();
    let ab_his = address_book.clone();
    let history_route = warp::path!("history" / String)
        .and(with_state((l_his, ab_his)))
        .map(|addr: String, (l, ab): (Arc<Mutex<Ledger>>, Arc<Mutex<HashMap<String, String>>>)| {
            let l_guard = l.lock().unwrap();
            let target_full = if l_guard.accounts.contains_key(&addr) {
                Some(addr)
            } else {
                let ab_guard = ab.lock().unwrap();
                if let Some(full) = ab_guard.get(&addr) {
                    Some(full.clone())
                } else {
                    l_guard.accounts.keys().find(|k| get_short_addr(k) == addr).cloned()
                }
            };

            let mut history = Vec::new();
            if let Some(full) = target_full {
                if let Some(acct) = l_guard.accounts.get(&full) {
                    let mut curr = acct.head.clone();
                    while curr != "0" {
                        if let Some(blk) = l_guard.blocks.get(&curr) {
                            history.push(serde_json::json!({
                                "hash": curr,
                                "type": format!("{:?}", blk.block_type),
                                "amount": (blk.amount as f64 / VOID_PER_UAT as f64),
                                "link": blk.link
                            }));
                            curr = blk.previous.clone();
                        } else { break; }
                    }
                }
            }
            warp::reply::json(&history)
        });

    // 4. GET /peers
    let ab_peer = address_book.clone();
    let peers_route = warp::path("peers")
        .and(with_state(ab_peer))
        .map(|ab: Arc<Mutex<HashMap<String, String>>>| {
            let peers = ab.lock().unwrap().clone();
            warp::reply::json(&peers)
        });

    // 5. POST /send (WEIGHTED INITIAL POWER)
    let l_send = ledger.clone();
    let p_send = pending_sends.clone();
    let tx_send = tx_out.clone();
    let send_route = warp::path("send")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((l_send, tx_send, p_send, my_address.clone(), secret_key.clone())))
        .then(|req: SendRequest, (l, tx, p, my_addr, key): (Arc<Mutex<Ledger>>, mpsc::Sender<String>, Arc<Mutex<HashMap<String, (Block, u32)>>>, String, Vec<u8>)| async move {
            let target_addr = {
                let l_guard = l.lock().unwrap();
                l_guard.accounts.keys().find(|k| get_short_addr(k) == req.target || **k == req.target).cloned()
            };
            if let Some(target) = target_addr {
                let amt = req.amount * VOID_PER_UAT;
                let mut blk = Block { account: my_addr.clone(), previous: "0".to_string(), block_type: BlockType::Send, amount: amt, link: target, signature: "".to_string(), work: 0 };
                
                let mut initial_power: u32 = 0;
                {
                    let l_guard = l.lock().unwrap();
                    if let Some(st) = l_guard.accounts.get(&my_addr) { 
                        blk.previous = st.head.clone(); 
                        if st.balance < amt { return warp::reply::json(&serde_json::json!({"status":"error","msg":"Saldo tidak cukup"})); }
                        // Ambil power awal (saldo pengirim)
                        initial_power = (st.balance / VOID_PER_UAT) as u32;
                    }
                }
                
                solve_pow(&mut blk);
                let hash = blk.calculate_hash();
                blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &key).unwrap());
                
                // Masukkan INITIAL POWER ke antrean
                p.lock().unwrap().insert(hash.clone(), (blk, initial_power));
                
                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                let _ = tx.send(format!("CONFIRM_REQ:{}:{}:{}:{}", hash, my_addr, amt, ts)).await;
                warp::reply::json(&serde_json::json!({"status":"success","tx_hash":hash, "initial_power": initial_power}))
            } else {
                warp::reply::json(&serde_json::json!({"status":"error","msg":"Alamat tidak ditemukan"}))
            }
        });

    // 6. POST /burn (WEIGHTED INITIAL POWER + SANITASI + ANTI-DOUBLE-CLAIM)
    let p_burn = pending_burns.clone();
    let tx_burn = tx_out.clone();
    let l_burn = ledger.clone();
    let burn_route = warp::path("burn")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((p_burn, tx_burn, my_address.clone(), l_burn)))
        .then(|req: BurnRequest, (p, tx, my_addr, l): (Arc<Mutex<HashMap<String, (f64, f64, String, u128)>>>, mpsc::Sender<String>, String, Arc<Mutex<Ledger>>)| async move {
            
            // 1. Sanitasi TXID
            let clean_txid = req.txid.trim().trim_start_matches("0x").to_lowercase();
            
            // 2. Proteksi Double-Claim (Ledger & Pending)
            let (in_ledger, my_power) = {
                let l_guard = l.lock().unwrap();
                let exists = l_guard.blocks.values().any(|b| b.block_type == BlockType::Mint && b.link.contains(&clean_txid));
                let pwr = l_guard.accounts.get(&my_addr).map(|a| a.balance).unwrap_or(0) / VOID_PER_UAT;
                (exists, pwr)
            };

            let is_pending = p.lock().unwrap().contains_key(&clean_txid);

            if in_ledger || is_pending { 
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "TXID ini sudah digunakan atau sedang dalam proses verifikasi!"
                })); 
            }
            
            // 3. Proses Oracle
            let (ep, bp) = get_crypto_prices().await;
            let res = if req.coin_type.to_lowercase() == "eth" { 
                verify_eth_burn_tx(&clean_txid).await.map(|a| (a, ep, "ETH")) 
            } else { 
                verify_btc_burn_tx(&clean_txid).await.map(|a| (a, bp, "BTC")) 
            };

            if let Some((amt, prc, sym)) = res {
                // Masukkan ke pending dengan Power awal = Saldo kita sendiri
                p.lock().unwrap().insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power));
                
                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                let _ = tx.send(format!("VOTE_REQ:{}:{}:{}:{}", req.coin_type.to_lowercase(), clean_txid, my_addr, ts)).await;
                
                warp::reply::json(&serde_json::json!({
                    "status":"success",
                    "msg":"Verifikasi dimulai",
                    "initial_power": my_power
                }))
            } else {
                warp::reply::json(&serde_json::json!({"status":"error","msg":"TXID tidak valid atau data Oracle gagal"}))
            }
        });

    // Gabungkan semua route
    let routes = balance_route
        .or(supply_route)
        .or(history_route)
        .or(peers_route)
        .or(send_route)
        .or(burn_route);

    println!("🌍 API Server berjalan di http://localhost:{}", api_port);
    warp::serve(routes).run(([0, 0, 0, 0], api_port)).await;
}

async fn get_crypto_prices() -> (f64, f64) {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .timeout(Duration::from_secs(10))
        .build()
        .unwrap_or_default();

    let url_coingecko = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=idr";
    let url_cryptocompare = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=BTC,ETH&tsyms=IDR";
    let url_indodax = "https://indodax.com/api/summaries"; 
    
    let mut eth_prices = Vec::new();
    let mut btc_prices = Vec::new();

    // 1. Fetch CoinGecko
    if let Ok(resp) = client.get(url_coingecko).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ethereum"]["idr"].as_f64() { eth_prices.push(p); }
            if let Some(p) = json["bitcoin"]["idr"].as_f64() { btc_prices.push(p); }
        }
    }

    // 2. Fetch CryptoCompare
    if let Ok(resp) = client.get(url_cryptocompare).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ETH"]["IDR"].as_f64() { eth_prices.push(p); }
            if let Some(p) = json["BTC"]["IDR"].as_f64() { btc_prices.push(p); }
        }
    }

    // 3. Fetch Indodax (Sangat akurat untuk pasar IDR)
    if let Ok(resp) = client.get(url_indodax).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(tickers) = json["tickers"].as_object() {
                // Indodax menyimpan harga dalam bentuk String, jadi kita perlu parse ke f64
                if let Some(eth) = tickers.get("eth_idr") {
                    if let Some(p_str) = eth["last"].as_str() {
                        if let Ok(p) = p_str.parse::<f64>() { eth_prices.push(p); }
                    }
                }
                if let Some(btc) = tickers.get("btc_idr") {
                    if let Some(p_str) = btc["last"].as_str() {
                        if let Ok(p) = p_str.parse::<f64>() { btc_prices.push(p); }
                    }
                }
            }
        }
    }

    // Hitung Rata-Rata Final
    let final_eth = if eth_prices.is_empty() { 35_000_000.0 } else {
        eth_prices.iter().sum::<f64>() / eth_prices.len() as f64
    };

    let final_btc = if btc_prices.is_empty() { 1_000_000_000.0 } else {
        btc_prices.iter().sum::<f64>() / btc_prices.len() as f64
    };

    // Tampilkan jumlah sumber yang berhasil (untuk debugging)
    println!("📊 Oracle Consensus ({} APIs): ETH Rp{}, BTC Rp{}", 
        eth_prices.len(), 
        format_u128(final_eth as u128), 
        format_u128(final_btc as u128)
    );

    (final_eth, final_btc)
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
                                return Some(out["value"].as_f64().unwrap_or(0.0) / 1e18);
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
        if let Ok(body) = resp.text().await {
            if let Ok(json) = serde_json::from_str::<Value>(&body) {
                if let Some(vout) = json["vout"].as_array() {
                    for out in vout.iter() {
                        if out.to_string().contains(BURN_ADDRESS_BTC) {
                            return Some(out["value"].as_f64().unwrap_or(0.0) / 1e8);
                        }
                    }
                }
            }
        }
    }
    None
}

// --- UTILS & FORMATTING ---

fn get_short_addr(full_addr: &str) -> String {
    if full_addr.len() < 12 { return full_addr.to_string(); }
    format!("uat_{}", &full_addr[..8])
}

fn format_u128(n: u128) -> String {
    let s = n.to_string();
    if s.len() > 3 {
        let mut result = String::new();
        let mut count = 0;
        for c in s.chars().rev() {
            if count > 0 && count % 3 == 0 { result.push('.'); }
            result.push(c);
            count += 1;
        }
        result.chars().rev().collect()
    } else { s }
}

fn save_to_disk(ledger: &Ledger) {
    if let Ok(data) = serde_json::to_string_pretty(ledger) {
        // 1. Simpan Ledger Utama
        let _ = fs::write(LEDGER_FILE, &data);

        // 2. Simpan Backup Berkala (Sistem Rotasi 1-100)
        let _ = fs::create_dir_all("backups");
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        // Menggunakan modulo 100 agar file backup tidak lebih dari 100 file
        let backup_path = format!("backups/ledger_{}.json", ts % 100); 
        let _ = fs::write(backup_path, data);
    }
}

fn load_from_disk() -> Ledger {
    if let Ok(data) = fs::read_to_string(LEDGER_FILE) {
        if let Ok(l) = serde_json::from_str(&data) { return l; }
    }
    Ledger::new()
}

fn solve_pow(block: &mut uat_core::Block) {
    println!("⏳ Menghitung PoW (Anti-Spam)...");
    let mut nonce: u64 = 0;
    loop {
        block.work = nonce;
        
        // TAMBAHKAN LOG INI: Biar kelihatan kalau CPU kerja
        if nonce % 50000 == 0 && nonce > 0 {
            println!("   ... mencoba nonce ke-{}", nonce);
        }

        if block.calculate_hash().starts_with("000") {
            break;
        }
        nonce += 1;
    }
    println!("✅ PoW Ditemukan dalam {} iterasi!", nonce);
}

// --- VISUALIZATION ---

fn print_history_table(blocks: Vec<&Block>) {
    println!("\n📜 RIWAYAT TRANSAKSI (Terbaru -> Terlama)");
    println!("+----------------+----------------+--------------------------+------------------------+");
    println!("| {:<14} | {:<14} | {:<24} | {:<22} |", "TIPE", "JUMLAH (UAT)", "DETAIL / LINK", "HASH");
    println!("+----------------+----------------+--------------------------+------------------------+");

    for b in blocks {
        let amount_uat = b.amount / VOID_PER_UAT;
        let amt_str = format_u128(amount_uat);
        
        let (type_str, amt_display, info) = match b.block_type {
            BlockType::Mint => ("🔥 MINT", format!("+{}", amt_str), format!("Src: {}", &b.link[..10])),
            BlockType::Send => ("📤 KIRIM", format!("-{}", amt_str), format!("To: {}", get_short_addr(&b.link))),
            BlockType::Receive => ("📥 TERIMA", format!("+{}", amt_str), format!("From Hash: {}", &b.link[..8])),
            _ => ("UNKNOWN", "0".to_string(), "-".to_string()),
        };

        let hash_short = if b.calculate_hash().len() > 8 { format!("...{}", &b.calculate_hash()[..8]) } else { "-".to_string() };

        println!("| {:<14} | {:<14} | {:<24} | {:<22} |", type_str, amt_display, info, hash_short);
    }
    println!("+----------------+----------------+--------------------------+------------------------+\n");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // --- 1. LOGIKA PORT DINAMIS ---
    // Membaca argumen terminal: cargo run -- 3031
    let args: Vec<String> = std::env::args().collect();
    let api_port: u16 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(3030);

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

    let pending_burns = Arc::new(Mutex::new(HashMap::<String, (f64, f64, String, u128)>::new()));

    let pending_sends = Arc::new(Mutex::new(HashMap::<String, (Block, u32)>::new()));
    // Init akun sendiri di ledger jika belum ada
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
    
    // --- TAMBAHAN: JALANKAN HTTP API ---
    let api_ledger = Arc::clone(&ledger);
    let api_tx = tx_out.clone();
    let api_pending_sends = Arc::clone(&pending_sends);
    let api_pending_burns = Arc::clone(&pending_burns); 
    let api_address_book = Arc::clone(&address_book);
    let api_addr = my_address.clone();
    let api_key = keys.secret_key.clone();

    tokio::spawn(async move {
        start_api_server(
            api_ledger, 
            api_tx, 
            api_pending_sends, 
            api_pending_burns, 
            api_address_book, 
            api_addr, 
            api_key, 
            api_port
        ).await;
    });
    // Bootstrapping
    let tx_boot = tx_out.clone();
    let my_addr_boot = my_address.clone();
    let ledger_boot = Arc::clone(&ledger);

    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(3)).await; // Delay sedikit biar node siap
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
    println!("------------------------------------------------------------------");
    println!("📖 PERINTAH:");
    println!("   bal                   - Cek saldo");
    println!("   whoami                - Cek alamat lengkap");
    println!("   history               - Lihat riwayat transaksi (NEW!)");
    println!("   burn <eth|btc> <TXID> - Mint UAT dari Burn ETH/BTC");
    println!("   send <ID> <AMT>       - Kirim koin");
    println!("   supply                - Cek total supply & burn");
    println!("   peers                 - List node aktif");
    println!("   dial <addr>           - Koneksi manual");
    println!("   exit                  - Keluar aplikasi");
    println!("------------------------------------------------------------------");

    let mut stdin = BufReader::new(io::stdin()).lines();

    loop {
        tokio::select! {
            Ok(Some(line)) = stdin.next_line() => {
                let p: Vec<&str> = line.split_whitespace().collect();
                if p.is_empty() { continue; }
                match p[0] {
                    "bal" => {
                        let l = ledger.lock().unwrap();
                        let b = l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0);
                        println!("📊 Saldo: {} UAT", format_u128(b / VOID_PER_UAT));
                    },
                    "whoami" => {
                        println!("🆔 My Short ID: {}", my_short);
                        println!("🔑 Full Address: {}", my_address);
                    },
                    "supply" => {
                        let l = ledger.lock().unwrap();
                        println!("📉 Supply: {} UAT | 🔥 Burn: Rp{}", format_u128(l.distribution.remaining_supply / VOID_PER_UAT), format_u128(l.distribution.total_burned_idr));
                    },
                    "history" => {
                        let l = ledger.lock().unwrap();
                        // 1. Tentukan target: input user, atau diri sendiri jika kosong
                        let input_addr = if p.len() == 2 { p[1] } else { &my_address };

                        // 2. Cari Full Address-nya
                        let target_full = if input_addr.starts_with("uat_") {
                            // Jika user input short ID, cari di address book
                            address_book.lock().unwrap().get(input_addr).cloned()
                        } else {
                            // Jika user input full address atau ini address kita sendiri
                            Some(input_addr.to_string())
                        };

                        if let Some(full_addr) = target_full {
                            if let Some(acct) = l.accounts.get(&full_addr) {
                                let mut history_blocks = Vec::new();
                                let mut curr = acct.head.clone();
                                
                                while curr != "0" {
                                    if let Some(blk) = l.blocks.get(&curr) {
                                        history_blocks.push(blk);
                                        curr = blk.previous.clone();
                                    } else { break; }
                                }
                                
                                if history_blocks.is_empty() {
                                    println!("📭 Belum ada riwayat untuk {}", get_short_addr(&full_addr));
                                } else {
                                    print_history_table(history_blocks);
                                }
                            } else {
                                println!("❌ Akun {} tidak memiliki catatan di Ledger.", input_addr);
                            }
                        } else {
                            println!("❌ ID {} tidak dikenal di Address Book.", input_addr);
                        }
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
                            let coin_type = p[1].to_lowercase();
                            let raw_txid = p[2].to_string();

                            // 1. SANITASI TXID (Penting agar 0xABC == abc)
                            let clean_txid = raw_txid.trim().trim_start_matches("0x").to_lowercase();
                            let link_to_search = format!("{}:{}", coin_type.to_uppercase(), clean_txid);

                            // 2. PROTEKSI LEDGER (Database Utama - Cek apakah sudah pernah diminting)
                            let is_already_minted = {
                                let l = ledger.lock().unwrap();
                                l.blocks.values().any(|b| {
                                    b.block_type == uat_core::BlockType::Mint && 
                                    (b.link == link_to_search || b.link.contains(&clean_txid))
                                })
                            };

                            if is_already_minted {
                                println!("❌ Gagal: TXID ini sudah terdaftar di Ledger (Double Claim dicegah)!");
                                continue;
                            }

                            // 3. PROTEKSI MEMORI (Cek apakah sedang dalam proses verifikasi)
                            let is_pending = pending_burns.lock().unwrap().contains_key(&clean_txid);
                            if is_pending {
                                println!("⏳ Mohon tunggu: TXID ini sedang dalam antrian verifikasi network!");
                                continue;
                            }

                            // 4. PROSES ORACLE (Cek ke Blockchain External)
                            println!("📊 Menghubungi Oracle untuk {}...", coin_type.to_uppercase());
                            let (ep, bp) = get_crypto_prices().await;
                            
                            let res = if coin_type == "eth" { 
                                verify_eth_burn_tx(&clean_txid).await.map(|a| (a, ep, "ETH")) 
                            } else if coin_type == "btc" {
                                verify_btc_burn_tx(&clean_txid).await.map(|a| (a, bp, "BTC")) 
                            } else {
                                println!("❌ Error: Koin '{}' tidak didukung.", coin_type);
                                None
                            };

                            if let Some((amt, prc, sym)) = res {
                                println!("✅ TXID Valid: {:.6} {} terdeteksi.", amt, sym);
                                
                                // --- FITUR SELF-VOTING (INITIAL POWER) ---
                                // Ambil saldo kita sendiri untuk dijadikan Power awal
                                let my_power = {
                                    let l = ledger.lock().unwrap();
                                    l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0) / VOID_PER_UAT
                                };

                                // Masukkan ke pending dengan Power awal = Saldo kita
                                pending_burns.lock().unwrap().insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power));
                                
                                // 5. BROADCAST KE NETWORK
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                let msg = format!("VOTE_REQ:{}:{}:{}:{}", coin_type, clean_txid, my_address, ts);
                                let _ = tx_out.send(msg).await;
                                
                                println!("📡 Broadcast VOTE_REQ dikirim (Initial Power: {} UAT)", my_power);

                                // INFO: Jika my_power >= 20, proses minting akan otomatis terpicu di loop network
                            } else {
                                println!("❌ Gagal: Oracle tidak menemukan bukti burn untuk TXID tersebut.");
                            }
                        } else {
                            println!("💡 Gunakan format: burn <eth/btc> <txid>");
                        }
                    },
                    "send" => {
                        if p.len() == 3 {
                            let target_short = p[1];
                            let amt_raw = p[2].parse::<u128>().unwrap_or(0);
                            let amt = amt_raw * VOID_PER_UAT;

                            if amt == 0 {
                                println!("❌ Jumlah kirim harus lebih dari 0!");
                                continue;
                            }

                            let target_full = address_book.lock().unwrap().get(target_short).cloned();
                            
                            if let Some(d) = target_full {
                                let l = ledger.lock().unwrap();
                                let state = l.accounts.get(&my_address).cloned().unwrap_or(AccountState { 
                                    head: "0".to_string(), balance: 0, block_count: 0 
                                });

                                // Kalkulasi saldo tersedia (dikurangi transaksi yang sedang menunggu konfirmasi)
                                let pending_total: u128 = pending_sends.lock().unwrap().values().map(|(b, _)| b.amount).sum();
                                
                                if state.balance < (amt + pending_total) {
                                    println!("❌ Saldo tidak cukup! (Saldo: {} UAT, Sedang dalam proses: {} UAT)", 
                                        format_u128(state.balance / VOID_PER_UAT), 
                                        format_u128(pending_total / VOID_PER_UAT));
                                    continue;
                                }

                                // Buat draft blok Send
                                let mut blk = Block {
                                    account: my_address.clone(),
                                    previous: state.head.clone(),
                                    block_type: BlockType::Send,
                                    amount: amt,
                                    link: d.clone(),
                                    signature: "".to_string(),
                                    work: 0,
                                };

                                solve_pow(&mut blk);
                                let hash = blk.calculate_hash();
                                blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &secret_key).unwrap());

                                // Simpan ke antrean konfirmasi
                                pending_sends.lock().unwrap().insert(hash.clone(), (blk.clone(), 0));
                                
                                // Siarkan permintaan konfirmasi (REQ) ke jaringan
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                let req_msg = format!("CONFIRM_REQ:{}:{}:{}:{}", hash, my_address, amt, ts);
                                let _ = tx_out.send(req_msg).await;
                                
                                println!("⏳ Transaksi dibuat. Meminta konfirmasi jaringan (Anti Double-Spend)...");
                            } else {
                                println!("❌ ID {} tidak ditemukan. Peer harus connect dulu.", target_short);
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
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() >= 4 {
                                let full = parts[1].to_string();
                                let rem_s = parts[2].parse::<u128>().unwrap_or(0);
                                let tot_b = parts[3].parse::<u128>().unwrap_or(0);
                                
                                if full != my_address {
                                    let short = get_short_addr(&full);
                                    let is_new = !address_book.lock().unwrap().contains_key(&short);
                                    address_book.lock().unwrap().insert(short.clone(), full.clone());
                                    
                                    let mut l = ledger.lock().unwrap();
                                    
                                    // SINKRONISASI SUPPLY
                                    if rem_s < l.distribution.remaining_supply && rem_s != 0 {
                                        l.distribution.remaining_supply = rem_s;
                                        l.distribution.total_burned_idr = tot_b;
                                        save_to_disk(&l);
                                        println!("🔄 Supply Synced with Peer: {}", short);
                                    }
                                    
                                    println!("🤝 Handshake: {}", short);

                                    // --- LOGIKA GEDOR PENDING TRANSAKSI ---
                                    // Begitu ada peer baru melakukan handshake, kita kirim ulang permintaan konfirmasi
                                    let pending_map = pending_sends.lock().unwrap();
                                    for (hash, (blk, _)) in pending_map.iter() {
                                        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                        let retry_msg = format!("CONFIRM_REQ:{}:{}:{}:{}", hash, blk.account, blk.amount, ts);
                                        let _ = tx_out.send(retry_msg).await;
                                        println!("📡 Mengirim ulang permintaan konfirmasi ke peer baru untuk TX: {}", &hash[..8]);
                                    }
                                    drop(pending_map);

                                    // JIKA PEER BARU: Kirim ID kita + Full Ledger (Dengan Kompresi)
                                    if is_new {
                                        let (s, b) = (l.distribution.remaining_supply, l.distribution.total_burned_idr);
                                        let _ = tx_out.send(format!("ID:{}:{}:{}", my_address, s, b)).await;
                                        
                                        if let Ok(full_state_json) = serde_json::to_string(&*l) {
                                            use flate2::write::GzEncoder;
                                            use flate2::Compression;
                                            use std::io::Write;

                                            let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
                                            let _ = encoder.write_all(full_state_json.as_bytes());
                                            if let Ok(compressed_bytes) = encoder.finish() {
                                                let encoded_data = base64::encode(compressed_bytes);
                                                let _ = tx_out.send(format!("SYNC_GZIP:{}", encoded_data)).await;
                                            }
                                        }
                                    }
                                }
                            }
                        } else if data.starts_with("SYNC_GZIP:") {
                            let encoded_data = &data[10..];
                            if let Ok(compressed_bytes) = base64::decode(encoded_data) {
                                use flate2::read::GzDecoder;
                                use std::io::Read;

                                let mut decoder = GzDecoder::new(&compressed_bytes[..]);
                                let mut decompressed_json = String::new();
                                
                                if decoder.read_to_string(&mut decompressed_json).is_ok() {
                                    if let Ok(incoming_ledger) = serde_json::from_str::<Ledger>(&decompressed_json) {
                                        let mut l = ledger.lock().unwrap();
                                        let mut added_count = 0;
                                        let mut invalid_count = 0;

                                        // 1. LIMITASI: Maksimal 1000 blok per sinkronisasi
                                        let incoming_blocks: Vec<Block> = incoming_ledger.blocks.values()
                                            .cloned()
                                            .take(1000) 
                                            .collect();
                                        
                                        let mut changed = true;
                                        while changed {
                                            changed = false;
                                            for blk in &incoming_blocks {
                                                let hash = blk.calculate_hash();
                                                if l.blocks.contains_key(&hash) { continue; }
                                                
                                                // Pre-check ringan
                                                if blk.block_type == BlockType::Mint && !blk.link.contains(':') {
                                                    invalid_count += 1;
                                                    continue;
                                                }

                                                if !l.accounts.contains_key(&blk.account) {
                                                    l.accounts.insert(blk.account.clone(), AccountState { 
                                                        head: "0".to_string(), balance: 0, block_count: 0 
                                                    });
                                                }

                                                match l.process_block(blk) {
                                                    Ok(_) => {
                                                        added_count += 1;
                                                        changed = true;
                                                    },
                                                    Err(_) => {
                                                        invalid_count += 1;
                                                    }
                                                }
                                            }
                                        }

                                        // 2. BLACKLIST OTOMATIS: Jika blok sampah > 50, hapus dari address book
                                        if invalid_count > 50 {
                                            println!("🚫 BLACKLIST: Peer mengirim {} blok sampah. Memutus jalur...", invalid_count);
                                            // Menghapus dari address book lokal agar tidak berinteraksi lagi
                                            let mut ab = address_book.lock().unwrap();
                                            ab.retain(|_, v| !data.contains(v.as_str())); 
                                        }

                                        if added_count > 0 {
                                            save_to_disk(&l);
                                            println!("📚 Sync Sukses: {} blok baru divalidasi!", added_count);
                                        }
                                    }
                                }
                            }
                        } else if data.starts_with("VOTE_REQ:") {
                            // FORMAT: VOTE_REQ:coin_type:txid:requester_address:timestamp
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 5 {
                                let coin_type = parts[1].to_string();
                                let txid = parts[2].to_string();
                                let requester = parts[3].to_string();

                                let tx_vote = tx_out.clone();
                                let ledger_ref = Arc::clone(&ledger);
                                let my_addr_clone = my_address.clone();

                                tokio::spawn(async move {
                                    // 1. Cek Ledger: Pastikan TXID ini belum pernah di-mint sebelumnya
                                    let link_to_check = format!("{}:{}", coin_type.to_uppercase(), txid);
                                    let already_exists = {
                                        let l = ledger_ref.lock().unwrap();
                                        l.blocks.values().any(|b| b.block_type == uat_core::BlockType::Mint && (b.link == link_to_check || b.link.contains(&txid)))
                                    };

                                    if already_exists { 
                                        // JIKA TERDETEKSI DOUBLE CLAIM DARI PEER LAIN
                                        if requester != my_addr_clone {
                                            println!("🚨 DETEKSI DOUBLE CLAIM: {} mencoba klaim TXID yang sudah ada!", get_short_addr(&requester));
                                            let slash_msg = format!("SLASH_REQ:{}:{}", requester, txid);
                                            let _ = tx_vote.send(slash_msg).await;
                                        }
                                        return; 
                                    }

                                    // 2. Oracle Verification: Verifikasi TXID ke Blockchain Explorer
                                    let amount_opt = if coin_type == "eth" {
                                        verify_eth_burn_tx(&txid).await
                                    } else {
                                        verify_btc_burn_tx(&txid).await
                                    };

                                    let ts_res = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();

                                    // 3. Logika Keputusan: YES (Valid) atau SLASH (Palsu)
                                    if amount_opt.is_some() {
                                        // TXID VALID: Kirim VOTE_RES YES
                                        let response = format!("VOTE_RES:{}:{}:YES:{}:{}", txid, requester, my_addr_clone, ts_res); 
                                        let _ = tx_vote.send(response).await;
                                        
                                        println!("🗳️ Memberikan suara YES untuk TXID: {} dari {}", 
                                            &txid[..8], 
                                            get_short_addr(&requester)
                                        );
                                    } else {
                                        // TXID PALSU/TIDAK DITEMUKAN: Kirim SLASH_REQ
                                        if requester != my_addr_clone {
                                            println!("🚨 DETEKSI FRAUD: TXID {} dari {} tidak valid! Mengirim Slash Request.", 
                                                &txid[..8], get_short_addr(&requester));
                                            
                                            let slash_msg = format!("SLASH_REQ:{}:{}", requester, txid);
                                            let _ = tx_vote.send(slash_msg).await;
                                        }
                                    }
                                });
                            } 
                        } else if data.starts_with("SLASH_REQ:") {
                            // FORMAT: SLASH_REQ:cheater_address:fake_txid
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 3 {
                                let cheater_addr = parts[1].to_string();
                                let fake_txid = parts[2].to_string();

                                println!("⚖️  Proses Penalti Network untuk: {}", get_short_addr(&cheater_addr));

                                let mut l = ledger.lock().unwrap();
                                // Sinkronisasi saldo terbaru dari disk agar tidak amnesia
                                if let Ok(raw) = std::fs::read_to_string(LEDGER_FILE) {
                                    if let Ok(upd) = serde_json::from_str::<Ledger>(&raw) { *l = upd; }
                                }

                                if let Some(state) = l.accounts.get(&cheater_addr).cloned() {
                                    if state.balance > 0 {
                                        // Hukuman: Potong 10% dari total saldo
                                        let penalty_amount = state.balance / 10;
                                        
                                        // BUAT BLOK HUKUMAN
                                        let mut slash_blk = Block {
                                            account: cheater_addr.clone(),
                                            previous: state.head.clone(),
                                            block_type: BlockType::Send,
                                            amount: penalty_amount,
                                            link: format!("PENALTY:FAKE_TXID:{}", fake_txid),
                                            // GUNAKAN SIGNATURE KHUSUS SISTEM
                                            signature: "SYSTEM_VALIDATED_SLASH".to_string(), 
                                            work: 0,
                                        };

                                        // 1. WAJIB SELESAIKAN POW (Agar tidak kena Invalid PoW)
                                        solve_pow(&mut slash_blk);

                                        // 2. EKSEKUSI PENALTI KE STATE SECARA MANUAL
                                        // Karena process_block pasti gagal validasi signature kunci publik,
                                        // kita langsung potong di state-nya agar konsisten di seluruh network.
                                        
                                        if let Some(acc) = l.accounts.get_mut(&cheater_addr) {
                                            let blk_hash = slash_blk.calculate_hash();
                                            acc.balance -= penalty_amount;
                                            acc.head = blk_hash.clone();
                                            acc.block_count += 1;
                                            
                                            // Masukkan blok ke database
                                            l.blocks.insert(blk_hash, slash_blk);
                                            
                                            save_to_disk(&l);
                                            println!("🔨 SLASHED! Saldo {} dipotong {} UAT karena mencoba menipu jaringan.", 
                                                get_short_addr(&cheater_addr), 
                                                penalty_amount / VOID_PER_UAT
                                            );
                                        }
                                    }
                                }
                            }
                        } else if data.starts_with("VOTE_RES:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            
                            // FORMAT: VOTE_RES:txid:requester:YES:voter_addr:timestamp (6 parts)
                            if parts.len() == 6 {
                                let txid = parts[1].to_string();
                                let requester = parts[2].to_string();
                                let voter_addr = parts[4].to_string(); 

                                if requester == my_address {
                                    let mut pending = pending_burns.lock().unwrap();
                                    
                                    if let Some(burn_info) = pending.get_mut(&txid) {
                                        
                                        // --- FIX: Force reload ledger agar saldo voter terbaru terbaca ---
                                        let mut l_guard = ledger.lock().unwrap();
                                        if let Ok(raw_data) = fs::read_to_string(LEDGER_FILE) {
                                            if let Ok(updated_l) = serde_json::from_str::<Ledger>(&raw_data) {
                                                *l_guard = updated_l;
                                            }
                                        }

                                        let voter_balance = l_guard.accounts.get(&voter_addr)
                                            .map(|a| a.balance)
                                            .unwrap_or(0);
                                        drop(l_guard); // Lepas lock segera

                                        // --- LOGIKA WEIGHTED VOTING ---
                                        let voter_power = voter_balance / VOID_PER_UAT;

                                        if voter_power >= 10 {
                                            // burn_info.3 (u128) menampung akumulasi Power
                                            burn_info.3 += voter_power; 
                                            
                                            println!("📩 Suara Masuk: {} (Power: {} UAT) | Progress: {}/20 Power", 
                                                get_short_addr(&voter_addr),
                                                voter_power,
                                                burn_info.3
                                            );
                                        } else {
                                            println!("⚠️ Suara diabaikan: {} (Power {} tidak cukup)", 
                                                get_short_addr(&voter_addr),
                                                voter_power
                                            );
                                            continue; 
                                        }

                                        // Konsensus: Total Power >= 20
                                        if burn_info.3 >= 20 {
                                            println!("✅ Konsensus Stake Tercapai (Total Power: {})!", burn_info.3);
                                            
                                            let (amt_coin, price, sym, _) = burn_info.clone();
                                            let uat_to_mint = (amt_coin * price) as u128 * VOID_PER_UAT;

                                            let mut l = ledger.lock().unwrap();
                                            let state = l.accounts.get(&my_address).cloned().unwrap_or(AccountState { 
                                                head: "0".to_string(), balance: 0, block_count: 0 
                                            });

                                            let mut mint_blk = Block {
                                                account: my_address.clone(),
                                                previous: state.head.clone(),
                                                block_type: BlockType::Mint,
                                                amount: uat_to_mint,
                                                link: format!("Src:{}:{}:{}", sym, txid, price as u128),
                                                signature: "".to_string(),
                                                work: 0,
                                            };

                                            solve_pow(&mut mint_blk);
                                            let hash = mint_blk.calculate_hash();
                                            mint_blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &secret_key).unwrap());
                                            
                                            match l.process_block(&mint_blk) {
                                                Ok(_) => {
                                                    save_to_disk(&l);
                                                    let _ = tx_out.send(serde_json::to_string(&mint_blk).unwrap()).await;
                                                    println!("🔥 Minting Berhasil: +{} UAT!", format_u128(uat_to_mint / VOID_PER_UAT));
                                                },
                                                Err(e) => println!("❌ Gagal memproses blok Mint: {}", e),
                                            }
                                            pending.remove(&txid);
                                        }
                                    }
                                }
                            } 
                        } else if data.starts_with("CONFIRM_REQ:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 5 {
                                let tx_hash = parts[1].to_string();
                                let sender_addr = parts[2].to_string();
                                let amount = parts[3].parse::<u128>().unwrap_or(0);
                                
                                let tx_confirm = tx_out.clone();
                                let ledger_ref = Arc::clone(&ledger);
                                let my_addr_clone = my_address.clone();

                                tokio::spawn(async move {
                                    let sender_balance = {
                                        let mut l_guard = ledger_ref.lock().unwrap();
                                        if let Ok(raw) = fs::read_to_string(LEDGER_FILE) {
                                            if let Ok(upd) = serde_json::from_str::<Ledger>(&raw) { 
                                                *l_guard = upd; 
                                            }
                                        }
                                        l_guard.accounts.get(&sender_addr).map(|a| a.balance).unwrap_or(0)
                                    };

                                    if sender_balance >= amount {
                                        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                        let res = format!("CONFIRM_RES:{}:{}:YES:{}:{}", tx_hash, sender_addr, my_addr_clone, ts);
                                        let _ = tx_confirm.send(res).await;
                                    }
                                });
                            }
                        } else if data.starts_with("CONFIRM_RES:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 6 {
                                let tx_hash = parts[1].to_string();
                                let requester = parts[2].to_string();
                                let voter_addr = parts[4].to_string();

                                if requester == my_address {
                                    let mut pending = pending_sends.lock().unwrap();
                                    if let Some((blk, total_power_votes)) = pending.get_mut(&tx_hash) {
                                        
                                        let voter_balance = {
                                            let mut l_guard = ledger.lock().unwrap();
                                            if let Ok(raw) = fs::read_to_string(LEDGER_FILE) {
                                                if let Ok(upd) = serde_json::from_str::<Ledger>(&raw) { *l_guard = upd; }
                                            }
                                            l_guard.accounts.get(&voter_addr).map(|a| a.balance).unwrap_or(0)
                                        };

                                        let voter_power = voter_balance / VOID_PER_UAT;

                                        if voter_power >= 10 {
                                            // --- FIX TYPE CASTING ---
                                            // Karena total_power_votes biasanya bertipe u32 di hashmap pending_sends
                                            *total_power_votes += voter_power as u32; 
                                            println!("📩 Konfirmasi Power: {} (Power: {}) | Total: {}/20", 
                                                get_short_addr(&voter_addr), voter_power, total_power_votes
                                            );
                                        }

                                        if *total_power_votes >= 20 {
                                            let blk_to_finalize = blk.clone();
                                            
                                            let process_success = {
                                                let mut l = ledger.lock().unwrap();
                                                match l.process_block(&blk_to_finalize) {
                                                    Ok(_) => {
                                                        save_to_disk(&l);
                                                        true
                                                    },
                                                    Err(e) => {
                                                        println!("❌ Gagal Finalisasi: {:?}", e);
                                                        false
                                                    }
                                                }
                                            };

                                            if process_success {
                                                let _ = tx_out.send(serde_json::to_string(&blk_to_finalize).unwrap()).await;
                                                println!("✅ Transaksi Terkonfirmasi (Power Verified) & Masuk Ledger!");
                                            }
                                            pending.remove(&tx_hash);
                                        }
                                    }
                                }
                            }
                        } else if let Ok(inc) = serde_json::from_str::<Block>(&data) {
                            let mut l = ledger.lock().unwrap();
                            if !l.accounts.contains_key(&inc.account) {
                                l.accounts.insert(inc.account.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0 });
                            }
                            match l.process_block(&inc) {
                                Ok(block_hash) => {
                                    if inc.block_type == BlockType::Mint {
                                        let burn_val = inc.amount / VOID_PER_UAT;
                                        println!("🔥 Network Mint Verified: +{} UAT", format_u128(burn_val));
                                    }
                                    save_to_disk(&l);
                                    println!("✅ Block Verified: {} dari {}", format!("{:?}", inc.block_type), get_short_addr(&inc.account));
                                    
                                    if inc.block_type == BlockType::Send && inc.link == my_address {
                                        if !l.accounts.contains_key(&my_address) {
                                            l.accounts.insert(my_address.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0 });
                                        }
                                        if let Some(state) = l.accounts.get(&my_address).cloned() {
                                            let mut rb = Block {
                                                account: my_address.clone(), previous: state.head, block_type: BlockType::Receive,
                                                amount: inc.amount, link: block_hash, signature: "".to_string(), work: 0,
                                            };
                                            solve_pow(&mut rb);
                                            rb.signature = hex::encode(uat_crypto::sign_message(rb.calculate_hash().as_bytes(), &secret_key).unwrap());
                                            if l.process_block(&rb).is_ok() {
                                                save_to_disk(&l);
                                                let _ = tx_out.send(serde_json::to_string(&rb).unwrap()).await;
                                                println!("📥 Incoming Transfer Received Automatically!");
                                            }
                                        }
                                    }
                                },
                                Err(e) => {
                                    println!("❌ Block Rejected: {:?} (Sender: {})", e, get_short_addr(&inc.account));
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