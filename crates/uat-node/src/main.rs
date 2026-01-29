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

const BOOTSTRAP_NODES: &[&str] = &[];

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
    if let Ok(data) = serde_json::to_string_pretty(ledger) { let _ = fs::write(LEDGER_FILE, data); }
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
                            let coin_type = p[1].to_string();
                            let txid = p[2].to_string();
                            
                            // 1. PROTEKSI LOKAL: Cek apakah TXID ini sudah ada di Ledger kita
                            let link_to_check = format!("{}:{}", coin_type.to_uppercase(), txid);
                            let is_already_minted = {
                                let l = ledger.lock().unwrap();
                                l.blocks.values().any(|b| b.block_type == uat_core::BlockType::Mint && b.link == link_to_check)
                            };

                            if is_already_minted {
                                println!("❌ Gagal: TXID ini sudah pernah di-mint sebelumnya!");
                                continue;
                            }

                            // 2. Jika belum ada di ledger, baru tarik harga dari Oracle
                            let (ep, bp) = get_crypto_prices().await;
                            let res = if coin_type == "eth" { verify_eth_burn_tx(&txid).await.map(|a| (a, ep, "ETH")) } 
                                    else { verify_btc_burn_tx(&txid).await.map(|a| (a, bp, "BTC")) };

                            if let Some((amt, prc, sym)) = res {
                                println!("⏳ TXID Valid. Meminta verifikasi dari peer...");
                                pending_burns.lock().unwrap().insert(txid.clone(), (amt, prc, sym.to_string(), 0));
                                
                                let msg = format!("VOTE_REQ:{}:{}:{}", coin_type, txid, my_address);
                                let _ = tx_out.send(msg).await;
                            } else {
                                println!("❌ Gagal verifikasi lokal. TXID tidak ditemukan atau salah.");
                            }
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

                            // 1. Dapatkan Full Address dari Address Book
                            let target_full = address_book.lock().unwrap().get(target_short).cloned();
                            
                            if let Some(d) = target_full {
                                let mut l = ledger.lock().unwrap();
                                
                                // 2. AMBIL STATE TERBARU (Pastikan saldo cukup saat ini juga)
                                let state = l.accounts.get(&my_address).cloned().unwrap_or(AccountState { 
                                    head: "0".to_string(), 
                                    balance: 0, 
                                    block_count: 0 
                                });

                                if state.balance < amt {
                                    println!("❌ Saldo tidak cukup! (Saldo: {} UAT, Kirim: {} UAT)", 
                                        format_u128(state.balance / VOID_PER_UAT), 
                                        format_u128(amt / VOID_PER_UAT));
                                    continue;
                                }

                                // 3. BUAT BLOK SEND
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

                                // 4. TANDATANGANI
                                let hash = blk.calculate_hash();
                                blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &secret_key).unwrap());

                                // 5. EKSEKUSI LOKAL (Kunci Ledger)
                                // Di dalam l.process_block, saldo akan langsung dipotong. 
                                // Karena kita memegang lock Mutex 'l', transaksi lain tidak bisa menyerobot.
                                match l.process_block(&blk) {
                                    Ok(_) => {
                                        save_to_disk(&l);
                                        let _ = tx_out.send(serde_json::to_string(&blk).unwrap()).await;
                                        println!("🚀 Transaksi Berhasil Dikirim ke {}!", target_short);
                                        println!("📊 Sisa Saldo: {} UAT", format_u128((state.balance - amt) / VOID_PER_UAT));
                                    },
                                    Err(e) => {
                                        println!("❌ Transaksi Ditolak Ledger: {:?}", e);
                                    }
                                }
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
                            // FORMAT: VOTE_REQ:coin_type:txid:requester_address
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 4 {
                                let coin_type = parts[1].to_string();
                                let txid = parts[2].to_string();
                                let requester = parts[3].to_string();

                                // Clone variabel yang diperlukan untuk task async
                                let tx_vote = tx_out.clone();
                                let ledger_ref = Arc::clone(&ledger);

                                let my_addr_clone = my_address.clone();

                                tokio::spawn(async move {
                                    // 1. Cek Ledger: Pastikan TXID ini belum pernah di-mint sebelumnya
                                    let link_to_check = format!("{}:{}", coin_type.to_uppercase(), txid);
                                    let already_exists = {
                                        let l = ledger_ref.lock().unwrap();
                                        l.blocks.values().any(|b| b.block_type == uat_core::BlockType::Mint && b.link == link_to_check)
                                    };

                                    if already_exists {
                                        // Abaikan jika sudah ada di ledger untuk mencegah double minting
                                        return;
                                    }

                                    // 2. Oracle Verification: Verifikasi TXID ke Blockchain Explorer
                                    let amount_opt = if coin_type == "eth" {
                                        verify_eth_burn_tx(&txid).await
                                    } else {
                                        verify_btc_burn_tx(&txid).await
                                    };

                                    // 3. Jika TXID Valid, kirim balasan VOTE_RES
                                    if amount_opt.is_some() {
                                        // FORMAT RESPONSE: VOTE_RES:txid:requester_address:vote_count
                                        let response = format!("VOTE_RES:{}:{}:YES:{}", txid, requester, my_addr_clone); 
                                        let _ = tx_vote.send(response).await;
                                        
                                        println!("🗳️ Memberikan suara YES untuk TXID: {} dari {}", 
                                            &txid[..8], 
                                            get_short_addr(&requester)
                                        );
                                    }
                                });
                            }
                         // Tambahkan ini di main.rs di dalam loop NetworkEvent
                        // --- BAGIAN PENANGANAN VOTE_RES DI MAIN.RS ---
                        } else if data.starts_with("VOTE_RES:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            
                            // Kita gunakan 5 kolom karena format baru adalah:
                            // VOTE_RES : TXID : REQUESTER : VOTE_TEXT : VOTER_ADDRESS
                            if parts.len() == 5 {
                                let txid = parts[1].to_string();
                                let requester = parts[2].to_string();
                                let voter_addr = parts[4].to_string(); // Mengambil alamat node yang memberi suara

                                // Hanya proses jika kita adalah pengusul (yang mengetik perintah 'burn')
                                if requester == my_address {
                                    let mut pending = pending_burns.lock().unwrap();
                                    
                                    if let Some(burn_info) = pending.get_mut(&txid) {
                                        // Tambah jumlah suara
                                        burn_info.3 += 1; 
                                        
                                        println!("📩 Terima suara dari: {} ({}/2)", 
                                            get_short_addr(&voter_addr), 
                                            burn_info.3
                                        );

                                        // Syarat Konsensus: Minimal dapat 2 suara dari node lain (Node 2 & Node 3)
                                        if burn_info.3 >= 2 {
                                            println!("✅ Konsensus Tercapai! Memulai proses Minting...");
                                            
                                            let (amt_coin, price, sym, _) = burn_info.clone();
                                            // Hitung berapa UAT yang harus dicetak (Nilai Koin * Harga Oracle)
                                            let uat_to_mint = (amt_coin * price) as u128 * VOID_PER_UAT;

                                            let mut l = ledger.lock().unwrap();
                                            let state = l.accounts.get(&my_address).cloned().unwrap_or(AccountState { 
                                                head: "0".to_string(), 
                                                balance: 0, 
                                                block_count: 0 
                                            });

                                            // Membuat blok bertipe Mint
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

                                            // Tanda tangani blok secara kriptografis
                                            let hash = mint_blk.calculate_hash();
                                            mint_blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &secret_key).unwrap());
                                            
                                            // Eksekusi ke Ledger Lokal
                                            match l.process_block(&mint_blk) {
                                                Ok(_) => {
                                                    save_to_disk(&l);
                                                    // Broadcast blok ke network agar node lain mencatat saldo baru kita
                                                    let _ = tx_out.send(serde_json::to_string(&mint_blk).unwrap()).await;
                                                    
                                                    println!("🔥 Minting Berhasil: +{} UAT ditambahkan ke saldo!", 
                                                        format_u128(uat_to_mint / VOID_PER_UAT)
                                                    );
                                                },
                                                Err(e) => {
                                                    println!("❌ Gagal memproses blok Mint: {}", e);
                                                }
                                            }
                                            
                                            // Hapus dari antrean pending agar tidak terjadi double minting
                                            pending.remove(&txid);
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