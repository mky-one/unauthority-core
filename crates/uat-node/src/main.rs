use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use uat_core::{Block, BlockType, Ledger, VOID_PER_UAT, AccountState};
use uat_core::oracle_consensus::OracleConsensus;  // NEW: Oracle consensus
use uat_crypto;
use uat_network::{UatNode, NetworkEvent};
use uat_vm::{WasmEngine, ContractCall};
use rate_limiter::{RateLimiter, filters::rate_limit};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;

// Oracle module with multi-source consensus
mod oracle;
use std::time::Duration;
use std::fs;
use serde_json::Value;

mod validator_rewards;
mod genesis;
mod grpc_server;  // NEW: gRPC server module
mod rate_limiter; // NEW: Rate limiter module
mod db;           // NEW: Database module (sled)
mod metrics;      // NEW: Prometheus metrics module
mod faucet;       // NEW: Testnet faucet module
// --- TAMBAHAN: HTTP API MODULE ---
use warp::Filter;
use db::UatDatabase;
use metrics::UatMetrics;
use faucet::{Faucet, FaucetConfig, FaucetRequest};

const LEDGER_FILE: &str = "ledger_state.json";
const WALLET_FILE: &str = "wallet.json";
const BURN_ADDRESS_ETH: &str = "0x000000000000000000000000000000000000dead";
const BURN_ADDRESS_BTC: &str = "1111111111111111111114oLvT2";

const BOOTSTRAP_NODES: &[&str] = &[];

// DEV MODE: Set to true for testing without blockchain verification
const DEV_MODE: bool = true;


// Request body structure for sending UAT
#[derive(serde::Deserialize, serde::Serialize)]
struct SendRequest {
    from: Option<String>,  // Sender address (if empty, use node's address)
    target: String,
    amount: u128,
}

#[derive(serde::Deserialize, serde::Serialize)]
struct BurnRequest {
    coin_type: String, // "eth" or "btc"
    txid: String,
    recipient_address: Option<String>, // Address to receive minted UAT (optional, defaults to sender)
}

#[derive(serde::Deserialize, serde::Serialize)]
struct DeployContractRequest {
    owner: String,
    bytecode: String, // base64 encoded WASM
    initial_state: Option<HashMap<String, String>>,
}

#[derive(serde::Deserialize, serde::Serialize)]
struct CallContractRequest {
    contract_address: String,
    function: String,
    args: Vec<String>,
    gas_limit: Option<u64>,
}

// Helper to inject state into route handlers
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
    oracle_consensus: Arc<Mutex<OracleConsensus>>,
    metrics: Arc<UatMetrics>,
    database: Arc<UatDatabase>,
) {
    // Rate Limiter: 100 req/sec per IP, burst 200
    let limiter = RateLimiter::new(100, Some(200));
    let rate_limit_filter = rate_limit(limiter.clone());
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
                "total_burned_usd": l_guard.distribution.total_burned_usd 
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
                                "from": if blk.block_type == BlockType::Send { blk.account.clone() } else { "SYSTEM".to_string() },
                                "to": if blk.block_type == BlockType::Receive { blk.account.clone() } else { blk.link.clone() },
                                "amount": (blk.amount as f64 / VOID_PER_UAT as f64),
                                "timestamp": 0, // TODO: Add real timestamp
                                "type": format!("{:?}", blk.block_type).to_lowercase()
                            }));
                            curr = blk.previous.clone();
                        } else { break; }
                    }
                }
            }
            warp::reply::json(&serde_json::json!({"transactions": history}))
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
            // Determine sender: use req.from if provided, otherwise node's address
            let sender_addr = req.from.clone().unwrap_or(my_addr.clone());
            
            // For now, only allow sending from node's own address (security)
            // TODO: Implement frontend signing for user wallets
            if sender_addr != my_addr {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Sending from external addresses not yet supported. Please use node's address."
                }));
            }
            
            let target_addr = {
                let l_guard = l.lock().unwrap();
                l_guard.accounts.keys().find(|k| get_short_addr(k) == req.target || **k == req.target).cloned()
            };
            if let Some(target) = target_addr {
                let amt = req.amount * VOID_PER_UAT;
                let mut blk = Block { account: sender_addr.clone(), previous: "0".to_string(), block_type: BlockType::Send, amount: amt, link: target, signature: "".to_string(), work: 0 };
                
                let mut initial_power: u32 = 0;
                {
                    let l_guard = l.lock().unwrap();
                    if let Some(st) = l_guard.accounts.get(&sender_addr) { 
                        blk.previous = st.head.clone(); 
                        if st.balance < amt { return warp::reply::json(&serde_json::json!({"status":"error","msg":"Insufficient balance"})); }
                        // Get initial power (sender balance)
                        initial_power = (st.balance / VOID_PER_UAT) as u32;
                    } else {
                        return warp::reply::json(&serde_json::json!({"status":"error","msg":"Sender account not found"}));
                    }
                }
                
                solve_pow(&mut blk);
                let hash = blk.calculate_hash();
                blk.signature = hex::encode(uat_crypto::sign_message(hash.as_bytes(), &key).unwrap());
                
                // Insert with INITIAL POWER to queue
                p.lock().unwrap().insert(hash.clone(), (blk, initial_power));
                
                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                let _ = tx.send(format!("CONFIRM_REQ:{}:{}:{}:{}", hash, sender_addr, amt, ts)).await;
                warp::reply::json(&serde_json::json!({"status":"success","tx_hash":hash, "initial_power": initial_power}))
            } else {
                warp::reply::json(&serde_json::json!({"status":"error","msg":"Address not found"}))
            }
        });

    // 6. POST /burn (WEIGHTED INITIAL POWER + SANITASI + ANTI-DOUBLE-CLAIM)
    let p_burn = pending_burns.clone();
    let tx_burn = tx_out.clone();
    let l_burn = ledger.clone();
    let oc_burn = oracle_consensus.clone();
    let burn_route = warp::path("burn")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((p_burn, tx_burn, my_address.clone(), l_burn, oc_burn)))
        .then(|req: BurnRequest, (p, tx, my_addr, l, oc): (Arc<Mutex<HashMap<String, (f64, f64, String, u128)>>>, mpsc::Sender<String>, String, Arc<Mutex<Ledger>>, Arc<Mutex<OracleConsensus>>)| async move {
            
            // 1. Sanitize TXID
            let clean_txid = req.txid.trim().trim_start_matches("0x").to_lowercase();
            
            // 2. Double-Claim Protection (Ledger & Pending)
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
                    "msg": "This TXID has already been used or is currently being verified!"
                })); 
            }
            
            // 3. Process Oracle: Use Consensus if available, fallback to single-node
            let consensus_price_opt = {
                let oc_guard = oc.lock().unwrap();
                oc_guard.get_consensus_price()
            }; // Drop lock before await
            
            let (ep, bp) = match consensus_price_opt {
                Some((eth_median, btc_median)) => {
                    println!("✅ Using Oracle Consensus for burn calculation");
                    (eth_median, btc_median)
                },
                None => {
                    println!("⚠️ Consensus not yet available, using single-node oracle");
                    get_crypto_prices().await
                }
            };
            
            let res = if req.coin_type.to_lowercase() == "eth" { 
                verify_eth_burn_tx(&clean_txid).await.map(|a| (a, ep, "ETH")) 
            } else { 
                verify_btc_burn_tx(&clean_txid).await.map(|a| (a, bp, "BTC")) 
            };

            if let Some((amt, prc, sym)) = res {
                // DEV_MODE: Instant finalization without voting (for testing only)
                if DEV_MODE {
                    let usd_val = amt * prc;
                    let uat_to_mint = ((usd_val / 0.01) * VOID_PER_UAT as f64) as u128;
                    
                    // Get recipient address from request, fallback to sender if not provided
                    let recipient = req.recipient_address.as_ref().unwrap_or(&my_addr).clone();
                    
                    let mut l_guard = l.lock().unwrap();
                    let state = l_guard.accounts.get(&recipient).cloned().unwrap_or(AccountState { 
                        head: "0".to_string(), balance: 0, block_count: 0 
                    });

                    let mint_blk = Block {
                        account: recipient.clone(),
                        previous: state.head.clone(),
                        block_type: BlockType::Mint,
                        amount: uat_to_mint,
                        link: format!("{}:{}:{}", sym, clean_txid, prc as u128),
                        signature: "DEV_MODE_AUTO".to_string(),
                        work: 0,
                    };

                    let hash = mint_blk.calculate_hash();
                    l_guard.blocks.insert(hash.clone(), mint_blk);
                    
                    let acc = l_guard.accounts.entry(recipient.clone()).or_insert(AccountState {
                        head: "0".to_string(),
                        balance: 0,
                        block_count: 0,
                    });
                    acc.balance += uat_to_mint;
                    acc.block_count += 1;
                    acc.head = hash;
                    
                    println!("🧪 DEV MODE: Instant mint {} {} → {} UAT to {}", amt, sym, uat_to_mint / VOID_PER_UAT, recipient);
                    
                    return warp::reply::json(&serde_json::json!({
                        "status":"success",
                        "msg":"Burn finalized instantly (DEV MODE)",
                        "uat_minted": uat_to_mint / VOID_PER_UAT,
                        "usd_value": usd_val,
                        "recipient": recipient
                    }));
                }
                
                // Production: Add to pending with initial power = our own balance
                p.lock().unwrap().insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power));
                
                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                let vote_msg = format!("VOTE_REQ:{}:{}:{}:{}", req.coin_type.to_lowercase(), clean_txid, my_addr, ts);
                println!("📡 Broadcasting VOTE_REQ: {} (Initial Power: {})", &vote_msg[..50], my_power);
                let _ = tx.send(vote_msg).await;
                
                warp::reply::json(&serde_json::json!({
                    "status":"success",
                    "msg":"Verification started",
                    "initial_power": my_power
                }))
            } else {
                warp::reply::json(&serde_json::json!({"status":"error","msg":"Invalid TXID or Oracle data failed"}))
            }
        });

    // 7. POST /deploy-contract (PERMISSIONLESS)
    let wasm_engine = Arc::new(WasmEngine::new());
    let wasm_deploy = wasm_engine.clone();
    let deploy_route = warp::path("deploy-contract")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state(wasm_deploy))
        .then(|req: DeployContractRequest, engine: Arc<WasmEngine>| async move {
            // Decode base64 WASM bytecode
            let bytecode = match base64::decode(&req.bytecode) {
                Ok(bytes) => bytes,
                Err(_) => return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Invalid base64 bytecode"
                }))
            };

            // Deploy to UVM (permissionless)
            let block_number = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();

            match engine.deploy_contract(
                req.owner.clone(),
                bytecode,
                req.initial_state.unwrap_or_default(),
                block_number
            ) {
                Ok(contract_addr) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "success",
                        "contract_address": contract_addr,
                        "owner": req.owner,
                        "deployed_at_block": block_number
                    }))
                },
                Err(e) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "error",
                        "msg": e
                    }))
                }
            }
        });

    // 8. POST /call-contract
    let wasm_call = wasm_engine.clone();
    let call_route = warp::path("call-contract")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state(wasm_call))
        .then(|req: CallContractRequest, engine: Arc<WasmEngine>| async move {
            let call = ContractCall {
                contract: req.contract_address,
                function: req.function,
                args: req.args,
                gas_limit: req.gas_limit.unwrap_or(1000000),
            };

            match engine.call_contract(call) {
                Ok(result) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "success",
                        "result": result
                    }))
                },
                Err(e) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "error",
                        "msg": e
                    }))
                }
            }
        });

    // 9. GET /contract/:address
    let wasm_get = wasm_engine.clone();
    let get_contract_route = warp::path!("contract" / String)
        .and(with_state(wasm_get))
        .map(|addr: String, engine: Arc<WasmEngine>| {
            match engine.get_contract(&addr) {
                Ok(contract) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "success",
                        "contract": {
                            "address": contract.address,
                            "code_hash": contract.code_hash,
                            "balance": contract.balance,
                            "owner": contract.owner,
                            "created_at_block": contract.created_at_block,
                            "state": contract.state
                        }
                    }))
                },
                Err(e) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "error",
                        "msg": e
                    }))
                }
            }
        });

    // 10. GET /metrics (Prometheus endpoint)
    let metrics_clone = metrics.clone();
    let ledger_metrics = ledger.clone();
    let db_metrics = database.clone();
    let metrics_route = warp::path("metrics")
        .and(with_state((metrics_clone, ledger_metrics, db_metrics)))
        .map(|(m, l, db): (Arc<UatMetrics>, Arc<Mutex<Ledger>>, Arc<UatDatabase>)| {
            // Update blockchain metrics before export
            {
                let ledger_guard = l.lock().unwrap();
                m.update_blockchain_metrics(&ledger_guard);
            }
            
            // Update database metrics
            let stats = db.stats();
            m.update_db_metrics(&stats);
            
            // Export all metrics
            match m.export() {
                Ok(output) => {
                    warp::reply::with_header(output, "Content-Type", "text/plain; version=0.0.4")
                },
                Err(e) => {
                    warp::reply::with_header(
                        format!("# Error exporting metrics: {}", e),
                        "Content-Type",
                        "text/plain"
                    )
                }
            }
        });

    // 11. GET /node-info (Network metadata for CLI)
    let l_info = ledger.clone();
    let node_info_route = warp::path("node-info")
        .and(with_state(l_info))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            let total_supply = 21_936_236u128 * VOID_PER_UAT;
            let circulating = total_supply - l_guard.distribution.remaining_supply;
            warp::reply::json(&serde_json::json!({
                "chain_id": "uat-mainnet",
                "version": "1.0.0",
                "block_height": l_guard.blocks.len(),
                "validator_count": 3,
                "peer_count": 0,
                "total_supply": total_supply / VOID_PER_UAT,
                "circulating_supply": circulating / VOID_PER_UAT,
                "network_tps": 0
            }))
        });

    // 12. GET /validators (List active validators - DEV_MODE aggregates from all nodes)
    let l_validators = ledger.clone();
    let validators_route = warp::path("validators")
        .and(with_state(l_validators))
        .and_then(|l: Arc<Mutex<Ledger>>| async move {
            // Get local validators (collect quickly then drop lock)
            let local_validators: Vec<serde_json::Value> = {
                let l_guard = l.lock().unwrap();
                l_guard.accounts.iter()
                    .filter(|(_, acc)| acc.balance >= 1000 * VOID_PER_UAT)
                    .map(|(addr, acc)| serde_json::json!({
                        "address": addr,
                        "stake": acc.balance / VOID_PER_UAT,
                        "is_active": true,
                        "active": true,
                        "uptime_percentage": 99.9
                    }))
                    .collect()
            }; // Lock dropped here
            
            // DEV_MODE: Aggregate from all 3 bootstrap nodes
            let mut all_validators = local_validators.clone();
            
            if DEV_MODE {
                let client = reqwest::Client::new();
                let bootstrap_ports = vec![3031, 3032]; // Skip self to avoid circular call
                
                for port in bootstrap_ports {
                    match client.get(format!("http://localhost:{}/validators", port))
                        .timeout(std::time::Duration::from_millis(500))
                        .send()
                        .await {
                        Ok(resp) => {
                            match resp.json::<serde_json::Value>().await {
                                Ok(data) => {
                                    if let Some(vals) = data["validators"].as_array() {
                                        for v in vals {
                                            // Deduplicate by address
                                            if let Some(addr) = v["address"].as_str() {
                                                if !all_validators.iter().any(|existing| 
                                                    existing["address"].as_str() == Some(addr)) {
                                                    all_validators.push(v.clone());
                                                }
                                            }
                                        }
                                    }
                                }
                                Err(e) => eprintln!("Failed to parse response from port {}: {}", port, e),
                            }
                        }
                        Err(e) => eprintln!("Failed to connect to port {}: {}", port, e),
                    }
                }
            }
            
            Ok::<_, warp::Rejection>(warp::reply::json(&serde_json::json!({
                "validators": all_validators
            })))
        });

    // 13. GET /balance/:address (Check balance - alias for CLI compatibility)
    let l_balance_alias = ledger.clone();
    let balance_alias_route = warp::path!("balance" / String)
        .and(with_state(l_balance_alias))
        .map(|addr: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            let full_addr = l_guard.accounts.keys().find(|k| get_short_addr(k) == addr || **k == addr).cloned().unwrap_or(addr.clone());
            let bal = l_guard.accounts.get(&full_addr).map(|a| a.balance).unwrap_or(0);
            warp::reply::json(&serde_json::json!({ 
                "address": full_addr, 
                "balance": bal / VOID_PER_UAT,  // Changed from balance_uat
                "balance_uat": bal / VOID_PER_UAT,
                "balance_voi": bal 
            }))
        });

    // 14. GET /block (Latest block)
    let l_block = ledger.clone();
    let block_route = warp::path("block")
        .and(with_state(l_block))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            // Get last block (blocks is HashMap, iterate to find one)
            let latest = l_guard.blocks.values().next();
            if let Some(b) = latest {
                warp::reply::json(&serde_json::json!({
                    "height": l_guard.blocks.len(),
                    "hash": b.calculate_hash(),
                    "account": b.account,
                    "previous": b.previous,
                    "amount": b.amount / VOID_PER_UAT,
                    "block_type": format!("{:?}", b.block_type)
                }))
            } else {
                warp::reply::json(&serde_json::json!({"error": "No blocks yet"}))
            }
        });

    // 15. POST /faucet (DEV MODE ONLY - Free UAT for testing)
    let l_faucet = ledger.clone();
    let db_faucet = database.clone();
    let faucet_route = warp::path("faucet")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((l_faucet, db_faucet)))
        .map(|req: serde_json::Value, (l, db): (Arc<Mutex<Ledger>>, Arc<UatDatabase>)| {
            if !DEV_MODE {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Faucet only available in DEV_MODE"
                }));
            }
            
            let address = req["address"].as_str().unwrap_or("");
            if address.is_empty() {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Address required"
                }));
            }
            
            let faucet_amount = 100_000u128 * VOID_PER_UAT; // 100k UAT
            
            let mut l_guard = l.lock().unwrap();
            let state = l_guard.accounts.get(address).cloned().unwrap_or(AccountState {
                head: "0".to_string(),
                balance: 0,
                block_count: 0,
            });
            
            let faucet_block = Block {
                account: address.to_string(),
                previous: state.head.clone(),
                block_type: BlockType::Mint,
                amount: faucet_amount,
                link: "FAUCET:DEV_MODE".to_string(),
                signature: "FAUCET_AUTO".to_string(),
                work: 0,
            };
            
            let hash = faucet_block.calculate_hash();
            l_guard.blocks.insert(hash.clone(), faucet_block);
            
            let new_balance = {
                let acc = l_guard.accounts.entry(address.to_string()).or_insert(AccountState {
                    head: "0".to_string(),
                    balance: 0,
                    block_count: 0,
                });
                acc.balance += faucet_amount;
                acc.block_count += 1;
                acc.head = hash;
                acc.balance
            };
            
            save_to_disk(&l_guard, &db);
            
            warp::reply::json(&serde_json::json!({
                "status": "success",
                "msg": "Faucet claim successful",
                "amount": faucet_amount / VOID_PER_UAT,
                "new_balance": new_balance / VOID_PER_UAT
            }))
        });

    // 16. GET /blocks/recent (Recent blocks for validator dashboard)
    let l_blocks = ledger.clone();
    let blocks_recent_route = warp::path!("blocks" / "recent")
        .and(with_state(l_blocks))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = l.lock().unwrap();
            let blocks: Vec<serde_json::Value> = l_guard.blocks.iter()
                .take(10) // Last 10 blocks
                .map(|(hash, b)| serde_json::json!({
                    "hash": hash,
                    "height": l_guard.blocks.len(), // Simplified
                    "timestamp": 0, // TODO: Add timestamp to Block struct
                    "transactions_count": 1,
                    "account": b.account,
                    "amount": b.amount / VOID_PER_UAT
                }))
                .collect();
            warp::reply::json(&serde_json::json!({
                "blocks": blocks
            }))
        });
    
    // 17. GET /whoami (Get node's internal signing address)
    let whoami_route = warp::path("whoami")
        .and(with_state(my_address.clone()))
        .map(|addr: String| {
            warp::reply::json(&serde_json::json!({
                "address": addr,
                "short": get_short_addr(&addr),
                "format": "hex-encoded"
            }))
        });

    // CORS configuration - Allow all origins for local development
    let cors = warp::cors()
        .allow_any_origin()
        .allow_methods(vec!["GET", "POST", "PUT", "DELETE", "OPTIONS"])
        .allow_headers(vec!["Content-Type", "Authorization", "Accept"]);

    // Combine all routes with rate limiting
    let routes = balance_route
        .or(supply_route)
        .or(history_route)
        .or(peers_route)
        .or(send_route)
        .or(burn_route)
        .or(deploy_route)
        .or(call_route)
        .or(get_contract_route)
        .or(metrics_route)
        .or(node_info_route)      // NEW: Node info endpoint
        .or(validators_route)     // NEW: Validators endpoint
        .or(balance_alias_route)  // NEW: Balance alias for CLI
        .or(block_route)          // NEW: Latest block endpoint
        .or(faucet_route)         // NEW: Faucet endpoint (DEV_MODE only)
        .or(blocks_recent_route)  // NEW: Recent blocks endpoint
        .or(whoami_route)         // NEW: Node's signing address endpoint
        .with(cors)               // Apply CORS
        .with(warp::log("api"))
        .recover(handle_rejection);

    // Apply rate limiting globally
    let routes_with_limit = rate_limit_filter.and(routes);

    println!("🌍 API Server running at http://localhost:{} (Rate Limit: 100 req/sec per IP)", api_port);
    warp::serve(routes_with_limit).run(([0, 0, 0, 0], api_port)).await;
}

// Rate limit rejection handler
async fn handle_rejection(err: warp::Rejection) -> Result<impl warp::Reply, std::convert::Infallible> {
    if let Some(rate_limiter::filters::RateLimitExceeded { ip }) = err.find() {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 429,
            "msg": "Rate limit exceeded. Please slow down your requests.",
            "ip": ip.to_string()
        }));
        Ok(warp::reply::with_status(json, warp::http::StatusCode::TOO_MANY_REQUESTS))
    } else if err.is_not_found() {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 404,
            "msg": "Endpoint not found"
        }));
        Ok(warp::reply::with_status(json, warp::http::StatusCode::NOT_FOUND))
    } else {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 500,
            "msg": "Internal server error"
        }));
        Ok(warp::reply::with_status(json, warp::http::StatusCode::INTERNAL_SERVER_ERROR))
    }
}

async fn get_crypto_prices() -> (f64, f64) {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .timeout(Duration::from_secs(10))
        .build()
        .unwrap_or_default();

    let url_coingecko = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=usd";
    let url_cryptocompare = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=BTC,ETH&tsyms=USD";
    let url_kraken = "https://api.kraken.com/0/public/Ticker?pair=ETHUSD,XBTUSD"; // Kraken (global exchange)
    
    let mut eth_prices = Vec::new();
    let mut btc_prices = Vec::new();

    // 1. Fetch CoinGecko
    if let Ok(resp) = client.get(url_coingecko).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ethereum"]["usd"].as_f64() { eth_prices.push(p); }
            if let Some(p) = json["bitcoin"]["usd"].as_f64() { btc_prices.push(p); }
        }
    }

    // 2. Fetch CryptoCompare
    if let Ok(resp) = client.get(url_cryptocompare).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ETH"]["USD"].as_f64() { eth_prices.push(p); }
            if let Some(p) = json["BTC"]["USD"].as_f64() { btc_prices.push(p); }
        }
    }

    // 3. Fetch Kraken (Global exchange)
    if let Ok(resp) = client.get(url_kraken).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(result) = json["result"].as_object() {
                // Kraken returns prices in array format
                if let Some(eth) = result.get("XETHZUSD") {
                    if let Some(p_array) = eth["c"].as_array() {
                        if let Some(p_str) = p_array[0].as_str() {
                            if let Ok(p) = p_str.parse::<f64>() { eth_prices.push(p); }
                        }
                    }
                }
                if let Some(btc) = result.get("XXBTZUSD") {
                    if let Some(p_array) = btc["c"].as_array() {
                        if let Some(p_str) = p_array[0].as_str() {
                            if let Ok(p) = p_str.parse::<f64>() { btc_prices.push(p); }
                        }
                    }
                }
            }
        }
    }

    // Calculate Final Average
    let final_eth = if eth_prices.is_empty() { 2500.0 } else {
        eth_prices.iter().sum::<f64>() / eth_prices.len() as f64
    };

    let final_btc = if btc_prices.is_empty() { 83000.0 } else {
        btc_prices.iter().sum::<f64>() / btc_prices.len() as f64
    };

    // Show successful source count (for debugging)
    println!("📊 Oracle Consensus ({} APIs): ETH ${:.2}, BTC ${:.2}", 
        eth_prices.len(), 
        format_u128(final_eth as u128), 
        format_u128(final_btc as u128)
    );

    (final_eth, final_btc)
}

async fn verify_eth_burn_tx(txid: &str) -> Option<f64> {
    // DEV MODE: Accept any valid format TXID and mock burn amount
    if DEV_MODE {
        let clean_txid = txid.trim().trim_start_matches("0x").to_lowercase();
        if clean_txid.len() == 64 && clean_txid.chars().all(|c| c.is_ascii_hexdigit()) {
            println!("🧪 DEV MODE: Accepting ETH TXID {} with mock amount 0.1 ETH", &clean_txid[..16]);
            return Some(0.1); // Mock 0.1 ETH burn
        }
        return None;
    }
    
    let clean_txid = txid.trim().trim_start_matches("0x").to_lowercase();
    let url = format!("https://api.blockcypher.com/v1/eth/main/txs/{}", clean_txid);
    let client = reqwest::Client::builder().timeout(Duration::from_secs(10)).build().ok()?;
    println!("🌐 Oracle ETH: Verifying TXID {}...", clean_txid);
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
    // DEV MODE: Accept any valid format TXID and mock burn amount
    if DEV_MODE {
        let clean_txid = txid.trim().to_lowercase();
        if clean_txid.len() == 64 && clean_txid.chars().all(|c| c.is_ascii_hexdigit()) {
            println!("🧪 DEV MODE: Accepting BTC TXID {} with mock amount 0.01 BTC", &clean_txid[..16]);
            return Some(0.01); // Mock 0.01 BTC burn
        }
        return None;
    }
    
    let url = format!("https://mempool.space/api/tx/{}", txid.trim());
    let client = reqwest::Client::builder().user_agent("Mozilla/5.0").timeout(Duration::from_secs(10)).build().ok()?;
    println!("🌐 Oracle BTC: Verifying TXID {}...", txid);
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

// DEPRECATED: Old JSON-based save (kept for emergency backup)
#[allow(dead_code)]
fn save_to_disk_legacy(ledger: &Ledger) {
    if let Ok(data) = serde_json::to_string_pretty(ledger) {
        let _ = fs::write(LEDGER_FILE, &data);
        let _ = fs::create_dir_all("backups");
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let backup_path = format!("backups/ledger_{}.json", ts % 100); 
        let _ = fs::write(backup_path, data);
    }
}

// NEW: Database-based save (ACID-compliant)
fn save_to_disk(ledger: &Ledger, db: &UatDatabase) {
    if let Err(e) = db.save_ledger(ledger) {
        eprintln!("❌ Database save failed: {}", e);
        // Fallback to JSON backup
        save_to_disk_legacy(ledger);
    }
}

// NEW: Load from database with JSON migration
fn load_from_disk(db: &UatDatabase) -> Ledger {
    // Try loading from database first
    if !db.is_empty() {
        match db.load_ledger() {
            Ok(ledger) => {
                println!("✅ Loaded ledger from database");
                return ledger;
            },
            Err(e) => {
                eprintln!("⚠️  Database load failed: {}", e);
            }
        }
    }
    
    // Fallback: Try loading from JSON file (migration path)
    if let Ok(data) = fs::read_to_string(LEDGER_FILE) {
        if let Ok(ledger) = serde_json::from_str::<Ledger>(&data) {
            println!("📦 Migrating from JSON to database...");
            
            // Save to database
            if let Err(e) = db.save_ledger(&ledger) {
                eprintln!("❌ Migration failed: {}", e);
            } else {
                println!("✅ Migration successful! {} accounts, {} blocks",
                    ledger.accounts.len(), ledger.blocks.len());
                
                // Rename old JSON file to prevent confusion
                let _ = fs::rename(LEDGER_FILE, format!("{}.migrated", LEDGER_FILE));
            }
            
            return ledger;
        }
    }
    
    // No data found, return empty ledger
    println!("🆕 Creating new ledger");
    Ledger::new()
}

fn solve_pow(block: &mut uat_core::Block) {
    println!("⏳ Calculating PoW (Anti-Spam)...");
    let mut nonce: u64 = 0;
    loop {
        block.work = nonce;
        
        // ADD THIS LOG: To show CPU is working
        if nonce % 50000 == 0 && nonce > 0 {
            println!("   ... trying nonce #{}", nonce);
        }

        if block.calculate_hash().starts_with("000") {
            break;
        }
        nonce += 1;
    }
    println!("✅ PoW found in {} iterations!", nonce);
}

// --- VISUALIZATION ---

fn print_history_table(blocks: Vec<&Block>) {
    println!("\n📜 TRANSACTION HISTORY (Newest -> Oldest)");
    println!("+----------------+----------------+--------------------------+------------------------+");
    println!("| {:<14} | {:<14} | {:<24} | {:<22} |", "TYPE", "AMOUNT (UAT)", "DETAIL / LINK", "HASH");
    println!("+----------------+----------------+--------------------------+------------------------+");

    for b in blocks {
        let amount_uat = b.amount / VOID_PER_UAT;
        let amt_str = format_u128(amount_uat);
        
        let (type_str, amt_display, info) = match b.block_type {
            BlockType::Mint => ("🔥 MINT", format!("+{}", amt_str), format!("Src: {}", &b.link[..10])),
            BlockType::Send => ("📤 SEND", format!("-{}", amt_str), format!("To: {}", get_short_addr(&b.link))),
            BlockType::Receive => ("📥 RECEIVE", format!("+{}", amt_str), format!("From Hash: {}", &b.link[..8])),
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
    // Parse command line: --config validator.toml
    let args: Vec<String> = std::env::args().collect();
    
    // Try to load port from validator.toml if --config is provided
    let mut api_port: u16 = 3030; // Default
    if let Some(config_idx) = args.iter().position(|a| a == "--config") {
        if let Some(config_path) = args.get(config_idx + 1) {
            if let Ok(config_content) = fs::read_to_string(config_path) {
                // Parse TOML to get [api] rest_port
                if let Some(line) = config_content.lines().find(|l| l.trim().starts_with("rest_port")) {
                    if let Some(port_str) = line.split('=').nth(1) {
                        api_port = port_str.trim().parse().unwrap_or(3030);
                    }
                }
            }
        }
    }
    
    // Fallback: accept direct port argument
    if let Some(port_arg) = args.get(1).and_then(|s| s.parse().ok()) {
        api_port = port_arg;
    }

    // --- NEW: INITIALIZE DATABASE ---
    println!("🗄️  Initializing database...");
    // AUTO-DETECT NODE ID from port or environment variable
    let node_id = std::env::var("UAT_NODE_ID").unwrap_or_else(|_| {
        match api_port {
            3030 => "validator-1".to_string(),
            3031 => "validator-2".to_string(),
            3032 => "validator-3".to_string(),
            _ => format!("node-{}", api_port),
        }
    });
    
    println!("🆔 Node ID: {}", node_id);
    println!("📂 Data directory: node_data/{}/", node_id);
    
    // Create node-specific database path (CRITICAL: Multi-node isolation)
    let db_path = format!("node_data/{}/uat_database", node_id);
    std::fs::create_dir_all(&format!("node_data/{}", node_id))?;
    
    let database = match UatDatabase::open(&db_path) {
        Ok(db) => {
            let stats = db.stats();
            println!("✅ Database opened: {}", db_path);
            println!("   {} blocks, {} accounts, {:.2} MB on disk",
                stats.blocks_count,
                stats.accounts_count,
                stats.size_on_disk as f64 / 1_048_576.0
            );
            Arc::new(db)
        },
        Err(e) => {
            eprintln!("❌ Failed to open database at {}: {}", db_path, e);
            eprintln!("⚠️  Falling back to JSON mode (not recommended for production)");
            return Err(e.into());
        }
    };

    // --- NEW: INITIALIZE METRICS ---
    println!("📊 Initializing Prometheus metrics...");
    let metrics = match UatMetrics::new() {
        Ok(m) => {
            println!("✅ Metrics ready: 45+ endpoints registered");
            m
        },
        Err(e) => {
            eprintln!("❌ Failed to initialize metrics: {}", e);
            return Err(e);
        }
    };

    // Use node-specific wallet file path
    let wallet_path = format!("node_data/{}/wallet.json", &node_id);
    let keys: uat_crypto::KeyPair = if let Ok(data) = fs::read_to_string(&wallet_path) {
        serde_json::from_str(&data)?
    } else {
        let new_k = uat_crypto::generate_keypair();
        fs::create_dir_all(format!("node_data/{}", &node_id))?;
        fs::write(&wallet_path, serde_json::to_string(&new_k)?)?;
        println!("🔑 Generated new keypair for {}", node_id);
        new_k
    };

    let my_address = hex::encode(&keys.public_key);
    let my_short = get_short_addr(&my_address);
    let secret_key = keys.secret_key.clone();
    
    let ledger = Arc::new(Mutex::new(load_from_disk(&database)));
    let address_book = Arc::new(Mutex::new(HashMap::<String, String>::new()));

    let pending_burns = Arc::new(Mutex::new(HashMap::<String, (f64, f64, String, u128)>::new()));

    let pending_sends = Arc::new(Mutex::new(HashMap::<String, (Block, u32)>::new()));
    
    // NEW: Oracle Consensus (decentralized median pricing)
    let oracle_consensus = Arc::new(Mutex::new(OracleConsensus::new()));
    
    // Init own account in ledger if not exists
    {
        let mut l = ledger.lock().unwrap();
        if !l.accounts.contains_key(&my_address) {
            // DEV_MODE: Give each new node 1000 UAT initial balance for testing
            let initial_balance = if DEV_MODE { 1000 * VOID_PER_UAT } else { 0 };
            l.accounts.insert(my_address.clone(), AccountState { 
                head: "0".to_string(), 
                balance: initial_balance, 
                block_count: 0 
            });
            save_to_disk(&l, &database);
            if DEV_MODE && initial_balance > 0 {
                println!("🎁 DEV_MODE: Node initialized with 1000 UAT balance");
            }
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
    let api_oracle = Arc::clone(&oracle_consensus);
    let api_metrics = Arc::clone(&metrics);
    let api_database = Arc::clone(&database);

    tokio::spawn(async move {
        start_api_server(
            api_ledger, 
            api_tx, 
            api_pending_sends, 
            api_pending_burns, 
            api_address_book, 
            api_addr, 
            api_key, 
            api_port,
            api_oracle,
            api_metrics,
            api_database
        ).await;
    });

    // --- NEW: JALANKAN gRPC SERVER (PRODUCTION READY) ---
    let grpc_ledger = Arc::clone(&ledger);
    let grpc_tx = tx_out.clone();
    let grpc_addr = my_address.clone();
    let grpc_port = api_port + 20000; // Dynamic gRPC port (REST+20000)

    tokio::spawn(async move {
        println!("🔧 Starting gRPC server on port {}...", grpc_port);
        if let Err(e) = grpc_server::start_grpc_server(
            grpc_ledger,
            grpc_addr,
            grpc_tx,
            grpc_port,
        ).await {
            eprintln!("❌ gRPC Server error: {}", e);
        }
    });

    // --- NEW: ORACLE PRICE BROADCASTER (Every 30 seconds) ---
    let oracle_tx = tx_out.clone();
    let oracle_addr = my_address.clone();
    let oracle_ledger = Arc::clone(&ledger);
    
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(30));
        loop {
            interval.tick().await;
            
            // Cek apakah node adalah validator (min 1,000 UAT)
            let is_validator = {
                let l = oracle_ledger.lock().unwrap();
                l.accounts.get(&oracle_addr)
                    .map(|acc| acc.balance >= 1_000_0000_0000)
                    .unwrap_or(false)
            };
            
            if is_validator {
                // Fetch price from external oracle
                let (eth_price, btc_price) = get_crypto_prices().await;
                
                // Broadcast to network
                let oracle_msg = format!("ORACLE_SUBMIT:{}:{}:{}", 
                    oracle_addr, eth_price, btc_price);
                let _ = oracle_tx.send(oracle_msg).await;
                
                println!("📊 Broadcasting oracle prices: ETH=${:.2}, BTC=${:.2}", 
                    eth_price, btc_price);
            }
        }
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
            let (s, b) = { let l = ledger_boot.lock().unwrap(); (l.distribution.remaining_supply, l.distribution.total_burned_usd) };
            let _ = tx_boot.send(format!("ID:{}:{}:{}", my_addr_boot, s, b)).await;
        }
    });

    println!("\n==================================================================");
    println!("                 UNAUTHORITY (UAT) ORACLE NODE                   ");
    println!("==================================================================");
    println!("🆔 MY ID        : {}", my_short);
    println!("📡 REST API     : http://0.0.0.0:{}", api_port);
    println!("🔌 gRPC API     : 0.0.0.0:50051 (8 services)");
    println!("------------------------------------------------------------------");
    println!("📖 COMMANDS:");
    println!("   bal                   - Check balance");
    println!("   whoami                - Check full address");
    println!("   history               - View transaction history (NEW!)");
    println!("   burn <eth|btc> <TXID> - Mint UAT from Burn ETH/BTC");
    println!("   send <ID> <AMT>       - Send coins");
    println!("   supply                - Check total supply & burn");
    println!("   peers                 - List active nodes");
    println!("   dial <addr>           - Manual connection");
    println!("   exit                  - Exit application");
    println!("------------------------------------------------------------------");

    let mut stdin = BufReader::new(io::stdin()).lines();

    // Clone database and metrics for event loop
    let db_clone = Arc::clone(&database);
    let _metrics_clone = Arc::clone(&metrics);

    loop {
        tokio::select! {
            Ok(Some(line)) = stdin.next_line() => {
                let p: Vec<&str> = line.split_whitespace().collect();
                if p.is_empty() { continue; }
                match p[0] {
                    "bal" => {
                        let l = ledger.lock().unwrap();
                        let b = l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0);
                        println!("📊 Balance: {} UAT", format_u128(b / VOID_PER_UAT));
                    },
                    "whoami" => {
                        println!("🆔 My Short ID: {}", my_short);
                        println!("🔑 Full Address: {}", my_address);
                    },
                    "supply" => {
                        let l = ledger.lock().unwrap();
                        println!("📉 Supply: {} UAT | 🔥 Burn: ${:.2}", format_u128(l.distribution.remaining_supply / VOID_PER_UAT), (l.distribution.total_burned_usd as f64) / 100.0);
                    },
                    "history" => {
                        let l = ledger.lock().unwrap();
                        // 1. Determine target: user input or self if empty
                        let input_addr = if p.len() == 2 { p[1] } else { &my_address };

                        // 2. Find Full Address
                        let target_full = if input_addr.starts_with("uat_") {
                            // If user input short ID, search in address book
                            address_book.lock().unwrap().get(input_addr).cloned()
                        } else {
                            // If user input full address or this is our own address
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
                                    println!("📭 No transaction history for {}", get_short_addr(&full_addr));
                                } else {
                                    print_history_table(history_blocks);
                                }
                            } else {
                                println!("❌ Account {} has no record in Ledger.", input_addr);
                            }
                        } else {
                            println!("❌ ID {} not found in Address Book.", input_addr);
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
                            let (s, b) = { let l = ledger.lock().unwrap(); (l.distribution.remaining_supply, l.distribution.total_burned_usd) };
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

                            // 1. SANITIZE TXID (Important: 0xABC == abc)
                            let clean_txid = raw_txid.trim().trim_start_matches("0x").to_lowercase();
                            let link_to_search = format!("{}:{}", coin_type.to_uppercase(), clean_txid);

                            // 2. LEDGER PROTECTION (Main Database - Check if already minted)
                            let is_already_minted = {
                                let l = ledger.lock().unwrap();
                                l.blocks.values().any(|b| {
                                    b.block_type == uat_core::BlockType::Mint && 
                                    (b.link == link_to_search || b.link.contains(&clean_txid))
                                })
                            };

                            if is_already_minted {
                                println!("❌ Failed: This TXID is already registered in Ledger (Double Claim prevented)!");
                                continue;
                            }

                            // 3. MEMORY PROTECTION (Check if verification in progress)
                            let is_pending = pending_burns.lock().unwrap().contains_key(&clean_txid);
                            if is_pending {
                                println!("⏳ Please wait: This TXID is currently in network verification queue!");
                                continue;
                            }

                            // 4. PROCESS ORACLE (Use Consensus if available)
                            println!("📊 Contacting Oracle for {}...", coin_type.to_uppercase());
                            
                            let consensus_price_opt = {
                                let oc_guard = oracle_consensus.lock().unwrap();
                                oc_guard.get_consensus_price()
                            }; // Drop lock before await
                            
                            let (ep, bp) = match consensus_price_opt {
                                Some((eth_median, btc_median)) => {
                                    println!("✅ Using Oracle Consensus: ETH=${:.2}, BTC=${:.2}", eth_median, btc_median);
                                    (eth_median, btc_median)
                                },
                                None => {
                                    println!("⚠️ Consensus not yet available, using single-node oracle");
                                    get_crypto_prices().await
                                }
                            };
                            
                            let res = if coin_type == "eth" { 
                                verify_eth_burn_tx(&clean_txid).await.map(|a| (a, ep, "ETH")) 
                            } else if coin_type == "btc" {
                                verify_btc_burn_tx(&clean_txid).await.map(|a| (a, bp, "BTC")) 
                            } else {
                                println!("❌ Error: Coin '{}' not supported.", coin_type);
                                None
                            };

                            if let Some((amt, prc, sym)) = res {
                                println!("✅ Valid TXID: {:.6} {} detected.", amt, sym);
                                
                                // --- SELF-VOTING FEATURE (INITIAL POWER) ---
                                // Get our own balance to use as initial Power
                                let my_power = {
                                    let l = ledger.lock().unwrap();
                                    l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0) / VOID_PER_UAT
                                };

                                // Insert to pending with initial Power = our balance
                                pending_burns.lock().unwrap().insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power));
                                
                                // 5. BROADCAST TO NETWORK
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                let msg = format!("VOTE_REQ:{}:{}:{}:{}", coin_type, clean_txid, my_address, ts);
                                let _ = tx_out.send(msg).await;
                                
                                println!("📡 VOTE_REQ broadcast sent (Initial Power: {} UAT)", my_power);

                                // INFO: If my_power >= 20, minting process will be auto-triggered in network loop
                            } else {
                                println!("❌ Failed: Oracle could not find burn proof for this TXID.");
                            }
                        } else {
                            println!("💡 Use format: burn <eth/btc> <txid>");
                        }
                    },
                    "send" => {
                        if p.len() == 3 {
                            let target_short = p[1];
                            let amt_raw = p[2].parse::<u128>().unwrap_or(0);
                            let amt = amt_raw * VOID_PER_UAT;

                            if amt == 0 {
                                println!("❌ Send amount must be greater than 0!");
                                continue;
                            }

                            let target_full = address_book.lock().unwrap().get(target_short).cloned();
                            
                            if let Some(d) = target_full {
                                let l = ledger.lock().unwrap();
                                let state = l.accounts.get(&my_address).cloned().unwrap_or(AccountState { 
                                    head: "0".to_string(), balance: 0, block_count: 0 
                                });

                                // Calculate available balance (minus pending transactions)
                                let pending_total: u128 = pending_sends.lock().unwrap().values().map(|(b, _)| b.amount).sum();
                                
                                if state.balance < (amt + pending_total) {
                                    println!("❌ Insufficient balance! (Balance: {} UAT, In process: {} UAT)", 
                                        format_u128(state.balance / VOID_PER_UAT), 
                                        format_u128(pending_total / VOID_PER_UAT));
                                    continue;
                                }

                                // Create Send block draft
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

                                // Save to confirmation queue
                                pending_sends.lock().unwrap().insert(hash.clone(), (blk.clone(), 0));
                                
                                // Broadcast confirmation request (REQ) to network
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                let req_msg = format!("CONFIRM_REQ:{}:{}:{}:{}", hash, my_address, amt, ts);
                                let _ = tx_out.send(req_msg).await;
                                
                                println!("⏳ Transaction created. Requesting network confirmation (Anti Double-Spend)...");
                            } else {
                                println!("❌ ID {} not found. Peer must connect first.", target_short);
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
                                    
                                    // SUPPLY SYNCHRONIZATION
                                    if rem_s < l.distribution.remaining_supply && rem_s != 0 {
                                        l.distribution.remaining_supply = rem_s;
                                        l.distribution.total_burned_usd = tot_b;
                                        save_to_disk(&l, &db_clone);
                                        println!("🔄 Supply Synced with Peer: {}", short);
                                    }
                                    
                                    println!("🤝 Handshake: {}", short);

                                    // --- PENDING TRANSACTION RESEND LOGIC ---
                                    // When new peer handshakes, we resend confirmation request
                                    let pending_map = pending_sends.lock().unwrap();
                                    for (hash, (blk, _)) in pending_map.iter() {
                                        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
                                        let retry_msg = format!("CONFIRM_REQ:{}:{}:{}:{}", hash, blk.account, blk.amount, ts);
                                        let _ = tx_out.send(retry_msg).await;
                                        println!("📡 Resending confirmation request to new peer for TX: {}", &hash[..8]);
                                    }
                                    drop(pending_map);

                                    // IF NEW PEER: Send our ID + Full Ledger (With Compression)
                                    if is_new {
                                        let (s, b) = (l.distribution.remaining_supply, l.distribution.total_burned_usd);
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

                                        // 1. LIMITATION: Maximum 1000 blocks per synchronization
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

                                        // 2. AUTOMATIC BLACKLIST: If garbage blocks > 50, remove from address book
                                        if invalid_count > 50 {
                                            println!("🚫 BLACKLIST: Peer sent {} garbage blocks. Disconnecting...", invalid_count);
                                            // Remove from local address book to stop interaction
                                            let mut ab = address_book.lock().unwrap();
                                            ab.retain(|_, v| !data.contains(v.as_str())); 
                                        }

                                        if added_count > 0 {
                                            save_to_disk(&l, &db_clone);
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
                                    // 1. Check Ledger: Ensure this TXID has never been minted before
                                    let link_to_check = format!("{}:{}", coin_type.to_uppercase(), txid);
                                    let already_exists = {
                                        let l = ledger_ref.lock().unwrap();
                                        l.blocks.values().any(|b| b.block_type == uat_core::BlockType::Mint && (b.link == link_to_check || b.link.contains(&txid)))
                                    };

                                    if already_exists { 
                                        // IF DOUBLE CLAIM DETECTED FROM OTHER PEER
                                        if requester != my_addr_clone {
                                            println!("🚨 DOUBLE CLAIM DETECTED: {} trying to claim existing TXID!", get_short_addr(&requester));
                                            let slash_msg = format!("SLASH_REQ:{}:{}", requester, txid);
                                            let _ = tx_vote.send(slash_msg).await;
                                        }
                                        return; 
                                    }

                                    // 2. Oracle Verification: Verify TXID to Blockchain Explorer
                                    let amount_opt = if coin_type == "eth" {
                                        verify_eth_burn_tx(&txid).await
                                    } else {
                                        verify_btc_burn_tx(&txid).await
                                    };

                                    let ts_res = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();

                                    // 3. Decision Logic: YES (Valid) or SLASH (Fake)
                                    if amount_opt.is_some() {
                                        // VALID TXID: Send VOTE_RES YES
                                        let response = format!("VOTE_RES:{}:{}:YES:{}:{}", txid, requester, my_addr_clone, ts_res); 
                                        let _ = tx_vote.send(response).await;
                                        
                                        println!("🗳️ Casting YES vote for TXID: {} from {}", 
                                            &txid[..8], 
                                            get_short_addr(&requester)
                                        );
                                    } else {
                                        // FAKE TXID/NOT FOUND: Send SLASH_REQ
                                        if requester != my_addr_clone {
                                            println!("🚨 FRAUD DETECTED: TXID {} from {} is invalid! Sending Slash Request.", 
                                                &txid[..8], get_short_addr(&requester));
                                            
                                            let slash_msg = format!("SLASH_REQ:{}:{}", requester, txid);
                                            let _ = tx_vote.send(slash_msg).await;
                                        }
                                    }
                                });
                            } 
                        } else if data.starts_with("ORACLE_SUBMIT:") {
                            // FORMAT: ORACLE_SUBMIT:validator_address:eth_price_usd:btc_price_usd
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 4 {
                                let validator_addr = parts[1].to_string();
                                let eth_price: f64 = parts[2].parse().unwrap_or(0.0);
                                let btc_price: f64 = parts[3].parse().unwrap_or(0.0);

                                // Submit to oracle consensus
                                let mut oc = oracle_consensus.lock().unwrap();
                                oc.submit_price(validator_addr.clone(), eth_price, btc_price);

                                // Check if consensus achieved
                                if let Some((eth_median, btc_median)) = oc.get_consensus_price() {
                                    println!("✅ Oracle Consensus: ETH=${:.2}, BTC=${:.2} (from {} validators)", 
                                        eth_median, btc_median, oc.submission_count());
                                } else {
                                    println!("📊 Oracle submission dari {} (butuh {} validator lagi)", 
                                        get_short_addr(&validator_addr), 
                                        2_usize.saturating_sub(oc.submission_count())
                                    );
                                }
                            }
                        } else if data.starts_with("SLASH_REQ:") {
                            // FORMAT: SLASH_REQ:cheater_address:fake_txid
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 3 {
                                let cheater_addr = parts[1].to_string();
                                let fake_txid = parts[2].to_string();

                                println!("⚖️  Network Penalty Processing for: {}", get_short_addr(&cheater_addr));

                                let mut l = ledger.lock().unwrap();
                                // Synchronize latest balance from disk to prevent amnesia
                                if let Ok(raw) = std::fs::read_to_string(LEDGER_FILE) {
                                    if let Ok(upd) = serde_json::from_str::<Ledger>(&raw) { *l = upd; }
                                }

                                if let Some(state) = l.accounts.get(&cheater_addr).cloned() {
                                    if state.balance > 0 {
                                        // Penalty: Deduct 10% of total balance
                                        let penalty_amount = state.balance / 10;
                                        
                                        // CREATE PENALTY BLOCK
                                        let mut slash_blk = Block {
                                            account: cheater_addr.clone(),
                                            previous: state.head.clone(),
                                            block_type: BlockType::Send,
                                            amount: penalty_amount,
                                            link: format!("PENALTY:FAKE_TXID:{}", fake_txid),
                                            // USE SPECIAL SYSTEM SIGNATURE
                                            signature: "SYSTEM_VALIDATED_SLASH".to_string(), 
                                            work: 0,
                                        };

                                        // 1. MUST COMPLETE POW (To avoid Invalid PoW error)
                                        solve_pow(&mut slash_blk);

                                        // 2. EXECUTE PENALTY TO STATE MANUALLY
                                        // Karena process_block pasti gagal validasi signature kunci publik,
                                        // kita langsung potong di state-nya agar konsisten di seluruh network.
                                        
                                        if let Some(acc) = l.accounts.get_mut(&cheater_addr) {
                                            let blk_hash = slash_blk.calculate_hash();
                                            acc.balance -= penalty_amount;
                                            acc.head = blk_hash.clone();
                                            acc.block_count += 1;
                                            
                                            // Masukkan blok ke database
                                            l.blocks.insert(blk_hash, slash_blk);
                                            
                                            save_to_disk(&l, &db_clone);
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
                                        
                                        // --- FIX: Force reload ledger to get latest voter balance ---
                                        let mut l_guard = ledger.lock().unwrap();
                                        if let Ok(raw_data) = fs::read_to_string(LEDGER_FILE) {
                                            if let Ok(updated_l) = serde_json::from_str::<Ledger>(&raw_data) {
                                                *l_guard = updated_l;
                                            }
                                        }

                                        let voter_balance = l_guard.accounts.get(&voter_addr)
                                            .map(|a| a.balance)
                                            .unwrap_or(0);
                                        drop(l_guard); // Release lock immediately

                                        // --- WEIGHTED VOTING LOGIC ---
                                        let voter_power = voter_balance / VOID_PER_UAT;

                                        if voter_power >= 10 {
                                            // burn_info.3 (u128) accumulates Power
                                            burn_info.3 += voter_power; 
                                            
                                            println!("📩 Vote Received: {} (Power: {} UAT) | Progress: {}/20 Power", 
                                                get_short_addr(&voter_addr),
                                                voter_power,
                                                burn_info.3
                                            );
                                        } else {
                                            println!("⚠️ Vote ignored: {} (Power {} insufficient)", 
                                                get_short_addr(&voter_addr),
                                                voter_power
                                            );
                                            continue; 
                                        }

                                        // Consensus: Total Power >= 20 (or 1 in DEV_MODE)
                                        if burn_info.3 >= if DEV_MODE { 1 } else { 20 } {
                                            println!("✅ Stake Consensus Achieved (Total Power: {})!", burn_info.3);
                                            
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
                                                    save_to_disk(&l, &db_clone);
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

                                        if *total_power_votes >= if DEV_MODE { 1 } else { 20 } {
                                            let blk_to_finalize = blk.clone();
                                            
                                            let process_success = {
                                                let mut l = ledger.lock().unwrap();
                                                match l.process_block(&blk_to_finalize) {
                                                    Ok(_) => {
                                                        save_to_disk(&l, &db_clone);
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
                                    save_to_disk(&l, &db_clone);
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
                                                save_to_disk(&l, &db_clone);
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