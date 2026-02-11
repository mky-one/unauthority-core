use rate_limiter::{filters::rate_limit, RateLimiter};
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};
use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use uat_consensus::abft::ABFTConsensus; // aBFT engine for consensus stats & safety validation
use uat_consensus::checkpoint::{CheckpointManager, FinalityCheckpoint, CHECKPOINT_INTERVAL}; // Finality checkpoints
use uat_consensus::slashing::SlashingManager; // Slashing enforcement
use uat_consensus::voting::calculate_voting_power; // Quadratic voting: Power = √Stake
use uat_core::anti_whale::{AntiWhaleConfig, AntiWhaleEngine}; // NEW: Anti-whale mechanisms
use uat_core::oracle_consensus::OracleConsensus; // NEW: Oracle consensus
use uat_core::validator_rewards::ValidatorRewardPool;
use uat_core::{AccountState, Block, BlockType, Ledger, MIN_VALIDATOR_STAKE_VOID, VOID_PER_UAT};
use uat_network::{NetworkEvent, UatNode};
#[cfg(feature = "vm")]
use uat_vm::{ContractCall, WasmEngine};
use zeroize::Zeroizing;

/// Safe mutex lock that recovers from poisoned state instead of panicking.
/// When a thread panics while holding a lock, the Mutex becomes "poisoned".
/// Instead of cascading panics, we recover the inner data.
fn safe_lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    match mutex.lock() {
        Ok(guard) => guard,
        Err(poisoned) => {
            eprintln!("⚠️ WARNING: Mutex was poisoned, recovering...");
            poisoned.into_inner()
        }
    }
}

use std::fs;
use std::time::{Duration, Instant};

// SECURITY FIX #11: Named constants for consensus thresholds (no more magic numbers)
/// Quadratic voting power threshold for burn consensus (production)
const BURN_CONSENSUS_THRESHOLD: u128 = 20_000;
/// Quadratic voting power threshold for send confirmation (production)
const SEND_CONSENSUS_THRESHOLD: u128 = 20_000;
/// Minimum threshold for testnet functional mode (bypasses real consensus)
/// MAINNET: This constant exists but is never reachable — testnet_config forces Production level.
const TESTNET_FUNCTIONAL_THRESHOLD: u128 = 1;
/// Initial testnet balance for functional testing (1000 UAT)
/// MAINNET: Never used — functional testnet path is unreachable on mainnet builds.
const TESTNET_INITIAL_BALANCE: u128 = 1000 * VOID_PER_UAT;
/// Total supply: 21,936,236 UAT (protocol constant, validated against genesis on mainnet)
const TOTAL_SUPPLY_UAT: u128 = 21_936_236;
const TOTAL_SUPPLY_VOID: u128 = TOTAL_SUPPLY_UAT * VOID_PER_UAT;
use serde_json::Value;

mod db; // NEW: Database module (sled)
mod genesis;
mod grpc_server; // NEW: gRPC server module
mod mempool; // NEW: Mempool for transaction management
mod metrics; // NEW: Prometheus metrics module
mod rate_limiter; // NEW: Rate limiter module
mod testnet_config;
mod validator_rewards; // Testnet configuration module (graduated levels)
                       // --- TAMBAHAN: HTTP API MODULE ---
use db::UatDatabase;
use metrics::UatMetrics;
use warp::Filter;

const LEDGER_FILE: &str = "ledger_state.json";
const BURN_ADDRESS_ETH: &str = "0x000000000000000000000000000000000000dead";
/// Provably unspendable Bitcoin burn address (BitcoinEater pattern)
/// No private key can generate this address — coins sent here are permanently destroyed
const BURN_ADDRESS_BTC: &str = "1BitcoinEaterAddressDontSendf59kuE";

// Race condition protection: Atomic flags for save state
static SAVE_IN_PROGRESS: AtomicBool = AtomicBool::new(false);
static SAVE_DIRTY: AtomicBool = AtomicBool::new(false);

/// Bootstrap nodes loaded from UAT_BOOTSTRAP_NODES environment variable
/// Format: comma-separated multiaddresses or .onion:port addresses
/// Example: UAT_BOOTSTRAP_NODES=abc123.onion:4001,def456.onion:4001
fn get_bootstrap_nodes() -> Vec<String> {
    match std::env::var("UAT_BOOTSTRAP_NODES") {
        Ok(val) if !val.trim().is_empty() => val
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect(),
        _ => Vec::new(),
    }
}

// Request body structure for sending UAT
#[derive(serde::Deserialize, serde::Serialize)]
struct SendRequest {
    from: Option<String>, // Sender address (if empty, use node's address)
    target: String,
    amount: u128,
    amount_void: Option<u128>, // Amount already in VOID (skips ×VOID_PER_UAT). Used by client-signed blocks.
    signature: Option<String>, // Client-provided signature (if present, validate instead of signing)
    public_key: Option<String>, // Sender's public key (hex-encoded, REQUIRED for signature verification)
    previous: Option<String>,   // Previous block hash (for client-side signing)
    work: Option<u64>,          // PoW nonce (if client pre-computed)
    timestamp: Option<u64>,     // Client timestamp (used when client_signed to match signing_hash)
    fee: Option<u128>,          // Client fee (used when client_signed to match signing_hash)
}

#[derive(serde::Deserialize, serde::Serialize)]
struct BurnRequest {
    coin_type: String, // "eth" or "btc"
    txid: String,
    recipient_address: Option<String>, // Address to receive minted UAT (optional, defaults to sender)
}

#[cfg(feature = "vm")]
#[derive(serde::Deserialize, serde::Serialize)]
struct DeployContractRequest {
    owner: String,
    bytecode: String, // base64 encoded WASM
    initial_state: Option<HashMap<String, String>>,
}

#[cfg(feature = "vm")]
#[derive(serde::Deserialize, serde::Serialize)]
struct CallContractRequest {
    contract_address: String,
    function: String,
    args: Vec<String>,
    gas_limit: Option<u64>,
}

/// Per-address endpoint rate limiter
/// Tracks request timestamps per address for each endpoint type
#[derive(Clone)]
pub struct EndpointRateLimiter {
    /// Map of address -> list of request timestamps
    requests: Arc<Mutex<HashMap<String, Vec<Instant>>>>,
    /// Maximum requests allowed in the time window
    max_requests: u32,
    /// Time window duration
    window: Duration,
    /// Last time we cleaned up old entries
    last_cleanup: Arc<Mutex<Instant>>,
}

impl EndpointRateLimiter {
    pub fn new(max_requests: u32, window_secs: u64) -> Self {
        Self {
            requests: Arc::new(Mutex::new(HashMap::new())),
            max_requests,
            window: Duration::from_secs(window_secs),
            last_cleanup: Arc::new(Mutex::new(Instant::now())),
        }
    }

    /// Check if the address is within rate limit. Returns Ok(()) or Err(seconds until next allowed request).
    pub fn check_and_record(&self, address: &str) -> Result<(), u64> {
        let now = Instant::now();
        let mut requests = match self.requests.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(), // Recover from poisoned mutex
        };

        // Periodic cleanup (every 60s): remove entries older than window
        {
            let mut last = match self.last_cleanup.lock() {
                Ok(guard) => guard,
                Err(poisoned) => poisoned.into_inner(),
            };
            if now.duration_since(*last) > Duration::from_secs(60) {
                requests.retain(|_, timestamps| {
                    timestamps.retain(|t| now.duration_since(*t) < self.window);
                    !timestamps.is_empty()
                });
                *last = now;
            }
        }

        let timestamps = requests.entry(address.to_string()).or_default();

        // Remove expired timestamps for this address
        timestamps.retain(|t| now.duration_since(*t) < self.window);

        if timestamps.len() >= self.max_requests as usize {
            // Calculate wait time from oldest relevant request
            let oldest = timestamps[0];
            let elapsed = now.duration_since(oldest);
            let wait = if self.window > elapsed {
                (self.window - elapsed).as_secs() + 1
            } else {
                1
            };
            return Err(wait);
        }

        timestamps.push(now);
        Ok(())
    }

    /// Check rate limit WITHOUT recording. Use with record_success() for
    /// endpoints where the cooldown should only apply on successful operations.
    pub fn check_only(&self, address: &str) -> Result<(), u64> {
        let now = Instant::now();
        let mut requests = match self.requests.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        };

        let timestamps = requests.entry(address.to_string()).or_default();
        timestamps.retain(|t| now.duration_since(*t) < self.window);

        if timestamps.len() >= self.max_requests as usize {
            let oldest = timestamps[0];
            let elapsed = now.duration_since(oldest);
            let wait = if self.window > elapsed {
                (self.window - elapsed).as_secs() + 1
            } else {
                1
            };
            return Err(wait);
        }
        Ok(())
    }

    /// Record a successful operation. Call AFTER the operation succeeds.
    pub fn record_success(&self, address: &str) {
        let now = Instant::now();
        let mut requests = match self.requests.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        };
        let timestamps = requests.entry(address.to_string()).or_default();
        timestamps.push(now);
    }
}

// Helper to inject state into route handlers
fn with_state<T: Clone + Send>(
    state: T,
) -> impl Filter<Extract = (T,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

/// Bundles all dependencies for the REST API server,
/// avoiding the `clippy::too_many_arguments` warning.
#[allow(clippy::type_complexity)]
pub struct ApiServerConfig {
    pub ledger: Arc<Mutex<Ledger>>,
    pub tx_out: mpsc::Sender<String>,
    pub pending_sends: Arc<Mutex<HashMap<String, (Block, u128)>>>,
    pub pending_burns: Arc<Mutex<HashMap<String, (f64, f64, String, u128, u64, String)>>>,
    pub address_book: Arc<Mutex<HashMap<String, String>>>,
    pub my_address: String,
    pub secret_key: Vec<u8>,
    pub api_port: u16,
    pub oracle_consensus: Arc<Mutex<OracleConsensus>>,
    pub metrics: Arc<UatMetrics>,
    pub database: Arc<UatDatabase>,
    pub slashing_manager: Arc<Mutex<SlashingManager>>,
    pub anti_whale: Arc<Mutex<AntiWhaleEngine>>,
    pub node_public_key: Vec<u8>,
    /// Bootstrap validator addresses loaded from genesis config (NOT hardcoded).
    /// On mainnet: from genesis_config.json bootstrap_nodes.
    /// On testnet: from testnet_wallets.json wallets with role="validator".
    pub bootstrap_validators: Vec<String>,
    /// Validator reward pool — epoch-based reward distribution engine
    pub reward_pool: Arc<Mutex<ValidatorRewardPool>>,
}

#[allow(clippy::type_complexity)]
pub async fn start_api_server(cfg: ApiServerConfig) {
    let ApiServerConfig {
        ledger,
        tx_out,
        pending_sends,
        pending_burns,
        address_book,
        my_address,
        secret_key,
        api_port,
        oracle_consensus,
        metrics,
        database,
        slashing_manager,
        anti_whale,
        node_public_key,
        bootstrap_validators,
        reward_pool,
    } = cfg;
    // Rate Limiter: 100 req/sec per IP, burst 200
    let limiter = RateLimiter::new(100, Some(200));
    let rate_limit_filter = rate_limit(limiter.clone());

    // Track node startup time for uptime calculation
    let start_time = std::time::Instant::now();

    // Per-address endpoint rate limiters
    let send_limiter = Arc::new(EndpointRateLimiter::new(10, 60)); // /send: 10 tx per 60 seconds
    let burn_limiter = Arc::new(EndpointRateLimiter::new(1, 60)); // /burn: 1 per 60 seconds (testnet)
    let faucet_limiter = Arc::new(EndpointRateLimiter::new(1, 120)); // /faucet: 1 per 2 minutes (testnet)

    // aBFT Consensus Engine — tracks consensus parameters and safety invariants
    let validator_count = {
        let l = safe_lock(&ledger);
        l.accounts
            .iter()
            .filter(|(_, a)| a.balance >= MIN_VALIDATOR_STAKE_VOID)
            .count()
            .max(4)
    };
    let abft_consensus = Arc::new(Mutex::new(ABFTConsensus::new(
        my_address.clone(),
        validator_count,
    )));
    {
        let abft = safe_lock(&abft_consensus);
        println!(
            "🔗 aBFT Consensus: n={}, f={}, quorum={}, safety={}",
            abft.total_validators,
            abft.f_max_faulty,
            abft.get_statistics().quorum_threshold,
            abft.is_byzantine_safe(0)
        );
    }

    // 1. GET /bal/:address
    let l_bal = ledger.clone();
    let balance_route = warp::path!("bal" / String)
        .and(with_state(l_bal))
        .map(|addr: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            let full_addr = l_guard.accounts.keys().find(|k| get_short_addr(k) == addr || **k == addr).cloned().unwrap_or(addr);
            let bal = l_guard.accounts.get(&full_addr).map(|a| a.balance).unwrap_or(0);
            warp::reply::json(&serde_json::json!({ "address": full_addr, "balance_uat": format_balance_precise(bal), "balance_void": bal }))
        });

    // 2. GET /supply
    let l_sup = ledger.clone();
    let supply_route = warp::path("supply")
        .and(with_state(l_sup))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            warp::reply::json(&serde_json::json!({
                "remaining_supply": format_balance_precise(l_guard.distribution.remaining_supply),
                "remaining_supply_void": l_guard.distribution.remaining_supply,
                "total_burned_usd": l_guard.distribution.total_burned_usd
            }))
        });

    // 3. GET /history/:address
    let l_his = ledger.clone();
    let ab_his = address_book.clone();
    let history_route = warp::path!("history" / String)
        .and(with_state((l_his, ab_his)))
        .map(#[allow(clippy::type_complexity)] |addr: String, (l, ab): (Arc<Mutex<Ledger>>, Arc<Mutex<HashMap<String, String>>>)| {
            let l_guard = safe_lock(&l);
            let target_full = if l_guard.accounts.contains_key(&addr) {
                Some(addr)
            } else {
                let ab_guard = safe_lock(&ab);
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
                            // FIX v1.0.7: Resolve actual sender for Receive blocks
                            let from_addr = match blk.block_type {
                                BlockType::Send => blk.account.clone(),
                                BlockType::Receive => {
                                    l_guard.blocks.get(&blk.link)
                                        .map(|send_blk| send_blk.account.clone())
                                        .unwrap_or_else(|| "SYSTEM".to_string())
                                },
                                _ => "SYSTEM".to_string(),
                            };
                            let to_addr = match blk.block_type {
                                BlockType::Receive => blk.account.clone(),
                                _ => blk.link.clone(),
                            };
                            history.push(serde_json::json!({
                                "hash": curr,
                                "from": from_addr,
                                "to": to_addr,
                                "amount": format!("{}.{:011}", blk.amount / VOID_PER_UAT, blk.amount % VOID_PER_UAT),
                                "timestamp": blk.timestamp,
                                "type": format!("{:?}", blk.block_type).to_lowercase(),
                                "fee": blk.fee
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
    let peers_route = warp::path("peers").and(with_state(ab_peer)).map(
        |ab: Arc<Mutex<HashMap<String, String>>>| {
            let peers = safe_lock(&ab).clone();
            warp::reply::json(&peers)
        },
    );

    // 5. POST /send (WEIGHTED INITIAL POWER + ANTI-WHALE DYNAMIC FEES)
    let l_send = ledger.clone();
    let p_send = pending_sends.clone();
    let tx_send = tx_out.clone();
    let sl_send = send_limiter.clone();
    let aw_send = anti_whale.clone();
    let pk_send = node_public_key.clone();
    let send_route = warp::path("send")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((l_send, tx_send, p_send, my_address.clone(), secret_key.clone(), sl_send, aw_send, pk_send)))
        .then(#[allow(clippy::type_complexity)] |req: SendRequest, (l, tx, p, my_addr, key, rate_lim, aw, node_pk): (Arc<Mutex<Ledger>>, mpsc::Sender<String>, Arc<Mutex<HashMap<String, (Block, u128)>>>, String, Vec<u8>, Arc<EndpointRateLimiter>, Arc<Mutex<AntiWhaleEngine>>, Vec<u8>)| async move {
            // Determine sender: use req.from if provided, otherwise node's address
            let sender_addr = req.from.clone().unwrap_or(my_addr.clone());

            // RATE LIMIT: 10 transactions per minute per sender address
            if let Err(wait_secs) = rate_lim.check_and_record(&sender_addr) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "code": 429,
                    "msg": format!("Rate limit exceeded: max 10 transactions per minute. Try again in {} seconds.", wait_secs)
                }));
            }

            // CRITICAL: Validate sender address format (Base58Check)
            if !uat_crypto::validate_address(&sender_addr) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Invalid sender address format. Must be Base58Check with UAT prefix."
                }));
            }

            // Validate target address format (Base58Check)
            if !uat_crypto::validate_address(&req.target) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Invalid target address format. Must be Base58Check with UAT prefix."
                }));
            }

            // Client-side signing: if signature provided, validate it instead of signing with node key
            let client_signed = req.signature.is_some();

            let target_addr = {
                let l_guard = safe_lock(&l);
                // First: check existing accounts (supports short address lookup)
                if let Some(found) = l_guard.accounts.keys()
                    .find(|k| get_short_addr(k) == req.target || **k == req.target).cloned() {
                    Some(found)
                // FIX C11-H3: Allow sending to new addresses not yet in ledger
                // In block-lattice, Send only records target in `link`; recipient
                // creates their own Receive block later.
                } else if uat_crypto::validate_address(&req.target) {
                    Some(req.target.clone())
                } else {
                    None
                }
            };
            if let Some(target) = target_addr {
                // FIX C11-C1: Checked multiplication to prevent u128 wrapping overflow
                // If amount_void is provided (client-signed with sub-UAT precision),
                // use it directly. Otherwise multiply UAT × VOID_PER_UAT.
                let amt = if let Some(void_amt) = req.amount_void {
                    void_amt
                } else {
                    match req.amount.checked_mul(VOID_PER_UAT) {
                        Some(v) => v,
                        None => {
                            return warp::reply::json(&serde_json::json!({
                                "status": "error",
                                "msg": "Amount overflow: value too large"
                            }));
                        }
                    }
                };

                // CRITICAL: For client-signed transactions, public_key is REQUIRED
                let pubkey = if client_signed {
                    if let Some(pk) = req.public_key.clone() {
                        pk
                    } else {
                        return warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": "public_key field is REQUIRED when providing signature"
                        }));
                    }
                } else {
                    hex::encode(&node_pk) // Node's own public key
                };

                let mut blk = Block {
                    account: sender_addr.clone(),
                    previous: req.previous.clone().unwrap_or("0".to_string()),
                    block_type: BlockType::Send,
                    amount: amt,
                    link: target.clone(),
                    signature: "".to_string(),
                    public_key: pubkey,
                    work: req.work.unwrap_or(0),
                    // When client-signed, use client's timestamp (part of signing_hash)
                    timestamp: if client_signed {
                        req.timestamp.unwrap_or_else(|| std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs())
                    } else {
                        std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs()
                    },
                    // When client-signed, use client's fee (part of signing_hash)
                    // Server still validates the fee is >= base_fee
                    fee: if client_signed { req.fee.unwrap_or(0) } else { 0 },
                };

                let initial_power: u128;
                let base_fee = uat_core::BASE_FEE_VOID; // Protocol constant from uat-core
                let final_fee: u128;

                // DEADLOCK FIX #4a: Never hold L and AW simultaneously.
                // Step 1: Read state from Ledger, drop lock
                let sender_state = {
                    let l_guard = safe_lock(&l);
                    l_guard.accounts.get(&sender_addr).cloned()
                }; // L dropped

                if let Some(st) = sender_state {
                    if req.previous.is_none() {
                        blk.previous = st.head.clone();
                    }

                    // Step 2: Anti-Whale fee calculation (separate lock scope)
                    {
                        let mut aw_guard = safe_lock(&aw);
                        match aw_guard.register_transaction(sender_addr.clone(), base_fee as u64) {
                            Ok(fee) => {
                                final_fee = fee as u128;
                                if final_fee > base_fee {
                                    println!("⚠️ Dynamic fee applied to {}: {} VOID ({}x multiplier)",
                                        get_short_addr(&sender_addr), final_fee, final_fee as f64 / base_fee as f64);
                                }
                            }
                            Err(e) => {
                                return warp::reply::json(&serde_json::json!({
                                    "status": "error",
                                    "msg": format!("Anti-whale fee calculation failed: {}", e)
                                }));
                            }
                        }
                    } // AW dropped

                    // Step 3: Check balance INCLUDING pending transactions (TOCTOU prevention)
                    let pending_total: u128 = {
                        let ps = safe_lock(&p);
                        ps.values()
                            .filter(|(b, _)| b.account == sender_addr)
                            .map(|(b, _)| b.amount)
                            .sum()
                    };
                    if st.balance < amt + final_fee + pending_total {
                        return warp::reply::json(&serde_json::json!({
                            "status":"error",
                            "msg": format!("Insufficient balance (need {} VOID for tx + {} VOID fee + {} VOID pending)", amt, final_fee, pending_total)
                        }));
                    }
                    initial_power = st.balance / VOID_PER_UAT;
                } else {
                    return warp::reply::json(&serde_json::json!({"status":"error","msg":"Sender account not found"}));
                }

                // Set fee on block BEFORE PoW/signing (fee is part of signing_hash)
                // When client-signed, validate that client fee >= server-calculated fee
                if client_signed {
                    let client_fee = blk.fee;
                    if client_fee < final_fee {
                        return warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": format!("Client fee {} VOID is below minimum required fee {} VOID", client_fee, final_fee)
                        }));
                    }
                    // Keep client's fee (already set on blk) — it's part of their signing_hash
                } else {
                    blk.fee = final_fee;
                }

                // Compute PoW if not provided by client
                if req.work.is_none() {
                    solve_pow(&mut blk);
                }

                // If client provided signature, validate it
                if client_signed {
                    blk.signature = req.signature.unwrap();

                    // CRITICAL: Verify signature with public key (not address!)
                    if !blk.verify_signature() {
                        let sh = blk.signing_hash();
                        return warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": format!("Invalid signature: Dilithium5 verification failed. signing_hash={}", sh)
                        }));
                    }
                    println!("✅ Client signature verified successfully");
                } else {
                    // Node signs with its own key (menggunakan signing_hash sebagai pesan)
                    // On functional testnet, allow node to sign on behalf of any address (no client-side crypto needed)
                    if sender_addr != my_addr && testnet_config::get_testnet_config().should_validate_signatures() {
                        return warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": "External address requires client-side signature. Please provide signature field."
                        }));
                    }
                    if sender_addr != my_addr {
                        println!("🧪 TESTNET functional: node signing on behalf of external address {}", sender_addr);
                    }
                    blk.signature = hex::encode(uat_crypto::sign_message(blk.signing_hash().as_bytes(), &key).expect("BUG: signing failed — key corrupted"));
                }

                // Block ID sekarang mencakup signature
                let hash = blk.calculate_hash();

                // FIX v1.0.7+: Finalize immediately when:
                //   (a) Functional testnet (no consensus needed), OR
                //   (b) Client-signed block with valid PoW + Dilithium5 signature
                //       (the block is cryptographically self-sufficient — consensus
                //       voting adds no security value for externally-signed blocks)
                //
                // MAINNET SAFETY: On mainnet build, should_enable_consensus() is ALWAYS true
                // (forced by testnet_config.rs), so this path is only reached when
                // client_signed=true. Mainnet client-signed blocks still skip consensus
                // because they carry a valid Dilithium5 signature + PoW — the cryptographic
                // proof IS the consensus for the sender's own account chain.
                //
                // In block-lattice, each account has its own chain. The sender proves
                // authorization via their private key signature. Consensus is only needed
                // for conflicting/double-spend resolution, not for validating a single
                // correctly-signed send from the account owner.
                let skip_consensus = !testnet_config::get_testnet_config().should_enable_consensus() || client_signed;
                if skip_consensus {
                    {
                        let mut l_guard = safe_lock(&l);
                        // Debit sender: amount + fee
                        // Use blk.fee (not final_fee) because for client-signed blocks,
                        // blk.fee is what's in the signed block (may be >= final_fee)
                        let actual_fee = blk.fee;
                        if let Some(sender_state) = l_guard.accounts.get_mut(&sender_addr) {
                            let total_debit = amt + actual_fee;
                            if sender_state.balance < total_debit {
                                return warp::reply::json(&serde_json::json!({
                                    "status": "error",
                                    "msg": "Insufficient balance for amount + fee"
                                }));
                            }
                            sender_state.balance -= total_debit;
                            sender_state.head = hash.clone();
                            sender_state.block_count += 1;
                        } else {
                            return warp::reply::json(&serde_json::json!({
                                "status":"error","msg":"Sender account not found"
                            }));
                        }
                        // Insert block
                        l_guard.blocks.insert(hash.clone(), blk.clone());
                        // Accumulate fees
                        l_guard.accumulated_fees_void += actual_fee;
                    }
                    SAVE_DIRTY.store(true, Ordering::Relaxed);
                    let reason = if client_signed { "client-signed" } else { "functional testnet" };
                    println!("✅ Send finalized immediately ({}): {} → {} ({} UAT, fee {} VOID)",
                        reason, get_short_addr(&sender_addr), get_short_addr(&target), amt / VOID_PER_UAT, blk.fee);

                    // Auto-receive for recipient on functional testnet
                    // In block-lattice, the recipient needs their own Receive block.
                    // On functional testnet (single-node), the node creates it for ALL recipients.
                    {
                        let mut l_guard = safe_lock(&l);
                        if !l_guard.accounts.contains_key(&target) {
                            l_guard.accounts.insert(target.clone(), AccountState {
                                head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                            });
                        }
                        if let Some(recv_state) = l_guard.accounts.get(&target).cloned() {
                            let mut recv_blk = Block {
                                account: target.clone(),
                                previous: recv_state.head,
                                block_type: BlockType::Receive,
                                amount: amt,
                                link: hash.clone(),
                                signature: "".to_string(),
                                public_key: hex::encode(&node_pk),
                                work: 0,
                                timestamp: std::time::SystemTime::now()
                                    .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                fee: 0,
                            };
                            solve_pow(&mut recv_blk);
                            recv_blk.signature = hex::encode(
                                uat_crypto::sign_message(recv_blk.signing_hash().as_bytes(), &key).expect("BUG: signing failed")
                            );
                            // Direct ledger manipulation for Receive block — bypass process_block()
                            // because the node's public_key doesn't match the target's account address.
                            // This is the same approach used for the Send block above.
                            let recv_hash = recv_blk.calculate_hash();
                            if let Some(recv_acct) = l_guard.accounts.get_mut(&target) {
                                recv_acct.balance += amt;
                                recv_acct.head = recv_hash.clone();
                                recv_acct.block_count += 1;
                            }
                            l_guard.blocks.insert(recv_hash.clone(), recv_blk);
                            SAVE_DIRTY.store(true, Ordering::Relaxed);
                            println!("✅ Auto-Receive created for {} ({} VOID)", get_short_addr(&target), amt);
                        }
                    }
                    return warp::reply::json(&serde_json::json!({
                        "status":"success",
                        "tx_hash":hash,
                        "initial_power": initial_power,
                        "fee_paid_void": blk.fee,
                        "fee_multiplier": blk.fee as f64 / base_fee as f64
                    }));
                }

                // Insert with INITIAL POWER to queue (consensus mode)
                safe_lock(&p).insert(hash.clone(), (blk, initial_power));

                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
                let _ = tx.send(format!("CONFIRM_REQ:{}:{}:{}:{}", hash, sender_addr, amt, ts)).await;
                warp::reply::json(&serde_json::json!({
                    "status":"success",
                    "tx_hash":hash,
                    "initial_power": initial_power,
                    "fee_paid_void": final_fee,
                    "fee_multiplier": final_fee as f64 / base_fee as f64
                }))
            } else {
                warp::reply::json(&serde_json::json!({"status":"error","msg":"Address not found"}))
            }
        });

    // 6. POST /burn (WEIGHTED INITIAL POWER + SANITASI + ANTI-DOUBLE-CLAIM + ANTI-WHALE BURN LIMITS)
    let p_burn = pending_burns.clone();
    let tx_burn = tx_out.clone();
    let l_burn = ledger.clone();
    let oc_burn = oracle_consensus.clone();
    let bl_burn = burn_limiter.clone();
    let aw_burn = anti_whale.clone();
    let pk_burn = node_public_key.clone();
    let sk_burn = secret_key.clone();
    let burn_route = warp::path("burn")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((p_burn, tx_burn, my_address.clone(), l_burn, oc_burn, bl_burn, aw_burn, (pk_burn, sk_burn))))
        .then(#[allow(clippy::type_complexity)] |req: BurnRequest, (p, tx, my_addr, l, oc, rate_lim, aw, (node_pk, node_sk)): (Arc<Mutex<HashMap<String, (f64, f64, String, u128, u64, String)>>>, mpsc::Sender<String>, String, Arc<Mutex<Ledger>>, Arc<Mutex<OracleConsensus>>, Arc<EndpointRateLimiter>, Arc<Mutex<AntiWhaleEngine>>, (Vec<u8>, Vec<u8>))| async move {

            // 1. Sanitize TXID
            let clean_txid = req.txid.trim().trim_start_matches("0x").to_lowercase();

            // Determine recipient address for rate limiting
            let recipient = req.recipient_address.as_ref().unwrap_or(&my_addr);

            // RATE LIMIT: 1 burn per 60 seconds per recipient address
            // Only CHECK here — record only after successful burn (not on failures like duplicate TXID)
            if let Err(wait_secs) = rate_lim.check_only(recipient) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "code": 429,
                    "msg": format!("Rate limit exceeded: max 1 burn per 60 seconds. Try again in {} seconds.", wait_secs)
                }));
            }

            // 2. Double-Claim Protection (Ledger & Pending)
            let (in_ledger, my_power) = {
                let l_guard = safe_lock(&l);
                let exists = l_guard.blocks.values().any(|b| b.block_type == BlockType::Mint && b.link.contains(&clean_txid));
                // SECURITY FIX C-03: Self-vote must use quadratic voting power
                // consistent with external VOTE_RES accumulation (× 1000 scale).
                // Previously: balance / VOID_PER_UAT (raw UAT, e.g. 1000)
                // Now: calculate_voting_power(balance) * 1000 (matches VOTE_RES path)
                let balance = l_guard.accounts.get(&my_addr).map(|a| a.balance).unwrap_or(0);
                let pwr = calculate_voting_power(balance) * 1000;
                (exists, pwr)
            };

            let is_pending = safe_lock(&p).contains_key(&clean_txid);

            if in_ledger || is_pending {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "This TXID has already been used or is currently being verified!"
                }));
            }

            // 3. Process Oracle: Use Consensus if available, fallback to single-node
            let consensus_price_opt = {
                let oc_guard = safe_lock(&oc);
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
                // SECURITY FIX NEW#3: Pure integer math via calculate_mint_void()
                let uat_to_mint = match calculate_mint_void(amt, prc, sym) {
                    Ok(v) => v,
                    Err(e) => {
                        return warp::reply::json(&serde_json::json!({"error": format!("Mint calculation overflow: {}", e)}));
                    }
                };
                let uat_to_mint_display = uat_to_mint / VOID_PER_UAT;

                if uat_to_mint == 0 {
                    return warp::reply::json(&serde_json::json!({"error": "Burn amount too small or overflow"}));
                }

                // Anti-Whale: Check burn limit per block
                // ATOMIC: Anti-whale check AND ledger modification in same scope for testnet instant path
                if !testnet_config::get_testnet_config().should_enable_consensus() {
                    // Get recipient address from request, fallback to sender if not provided
                    let recipient = req.recipient_address.as_ref().unwrap_or(&my_addr).clone();

                    // DEADLOCK FIX #4b: Never hold AW and L simultaneously.
                    // Step 1: Anti-whale check (separate lock scope)
                    // On functional testnet, skip anti-whale to allow testing with mock burn amounts
                    let mint_result = if testnet_config::get_testnet_config().level == testnet_config::TestnetLevel::Functional {
                        println!("🧪 TESTNET functional: bypassing anti-whale for {} UAT burn", uat_to_mint_display);
                        Ok(())
                    } else {
                        let mut aw_guard = safe_lock(&aw);
                        if let Err(e) = aw_guard.register_burn(recipient.clone(), uat_to_mint_display as u64) {
                            Err(format!("Anti-whale burn limit: {}", e))
                        } else {
                            Ok(()) // Burn limit check passed
                        }
                    }; // AW dropped

                    let mint_result = match mint_result {
                        Err(e) => Err(e),
                        Ok(()) => {
                            // Step 2: Lock ledger separately for minting
                            let mut l_guard = safe_lock(&l);

                            // Ensure account exists
                            if !l_guard.accounts.contains_key(&recipient) {
                                l_guard.accounts.insert(recipient.clone(), AccountState {
                                    head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                });
                            }

                            let state = l_guard.accounts.get(&recipient).cloned().unwrap_or(AccountState {
                                head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                            });

                            let mut mint_blk = Block {
                                account: recipient.clone(),
                                previous: state.head.clone(),
                                block_type: BlockType::Mint,
                                amount: uat_to_mint,
                                // Prefix with TESTNET: on functional testnet build ONLY to bypass anti-whale in ledger.
                                // MAINNET: is_testnet_build() is a const fn that returns false on mainnet builds,
                                // so the compiler eliminates the TESTNET: branch entirely — it cannot exist in mainnet binary.
                                link: if uat_core::is_testnet_build() && testnet_config::get_testnet_config().level == testnet_config::TestnetLevel::Functional {
                                    format!("TESTNET:{}:{}:{}", sym, clean_txid, prc as u128)
                                } else {
                                    format!("{}:{}:{}", sym, clean_txid, prc as u128)
                                },
                                signature: "".to_string(),
                                public_key: hex::encode(&node_pk), // Node's public key
                                work: 0,
                                timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                fee: 0,
                            };

                            solve_pow(&mut mint_blk);
                            mint_blk.signature = hex::encode(
                                uat_crypto::sign_message(mint_blk.signing_hash().as_bytes(), &node_sk).expect("BUG: signing failed — key corrupted")
                            );

                            match l_guard.process_block(&mint_blk) {
                                Ok(hash) => {
                                    SAVE_DIRTY.store(true, Ordering::Relaxed);
                                    println!("🧪 TESTNET (Functional): Instant mint {} {} → {} UAT to {}", amt, sym, uat_to_mint / VOID_PER_UAT, recipient);
                                    Ok(hash)
                                }
                                Err(e) => Err(format!("Mint failed: {}", e))
                            }
                        } // L dropped
                    };

                    match mint_result {
                        Err(msg) => {
                            return warp::reply::json(&serde_json::json!({
                                "status": "error",
                                "msg": msg
                            }));
                        }
                        Ok(hash) => {
                            // Record rate limit ONLY on successful burn
                            rate_lim.record_success(&recipient);
                            return warp::reply::json(&serde_json::json!({
                                "status":"success",
                                "msg":"Burn finalized instantly (Functional Testnet)",
                                "uat_minted": uat_to_mint / VOID_PER_UAT,
                                "usd_value": format!("{:.2}", amt * prc),
                                "recipient": recipient,
                                "block_hash": hash
                            }));
                        }
                    }
                }

                // Production path: Anti-whale check then add to pending
                {
                    let mut aw_guard = safe_lock(&aw);
                    if let Err(e) = aw_guard.register_burn(recipient.clone(), uat_to_mint_display as u64) {
                        return warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": format!("Anti-whale burn limit: {}", e)
                        }));
                    }
                    println!("🐋 Burn registered: {} UAT for {} (within limits)", uat_to_mint_display, get_short_addr(recipient));
                }

                // Production: Add to pending with initial power = our own balance + recipient address
                let created_at = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs();
                let burn_recipient = req.recipient_address.as_ref().unwrap_or(&my_addr).clone();
                safe_lock(&p).insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power, created_at, burn_recipient));

                // Record rate limit ONLY after successful pending insertion
                rate_lim.record_success(recipient);

                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
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
    #[cfg(feature = "vm")]
    let deploy_route = {
        let wasm_engine = Arc::new(WasmEngine::new());
        let wasm_deploy = wasm_engine.clone();
        let deploy = warp::path("deploy-contract")
            .and(warp::post())
            .and(warp::body::json())
            .and(with_state(wasm_deploy))
            .then(
                |req: DeployContractRequest, engine: Arc<WasmEngine>| async move {
                    // Decode base64 WASM bytecode
                    let bytecode = match base64::decode(&req.bytecode) {
                        Ok(bytes) => bytes,
                        Err(_) => {
                            return warp::reply::json(&serde_json::json!({
                                "status": "error",
                                "msg": "Invalid base64 bytecode"
                            }))
                        }
                    };

                    // Deploy to UVM (permissionless)
                    let block_number = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();

                    match engine.deploy_contract(
                        req.owner.clone(),
                        bytecode,
                        req.initial_state.unwrap_or_default(),
                        block_number,
                    ) {
                        Ok(contract_addr) => warp::reply::json(&serde_json::json!({
                            "status": "success",
                            "contract_address": contract_addr,
                            "owner": req.owner,
                            "deployed_at_block": block_number
                        })),
                        Err(e) => warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": e
                        })),
                    }
                },
            );

        // 8. POST /call-contract
        let wasm_call = wasm_engine.clone();
        let call = warp::path("call-contract")
            .and(warp::post())
            .and(warp::body::json())
            .and(with_state(wasm_call))
            .then(
                |req: CallContractRequest, engine: Arc<WasmEngine>| async move {
                    let call = ContractCall {
                        contract: req.contract_address,
                        function: req.function,
                        args: req.args,
                        gas_limit: req.gas_limit.unwrap_or(1000000),
                    };

                    match engine.call_contract(call) {
                        Ok(result) => warp::reply::json(&serde_json::json!({
                            "status": "success",
                            "result": result
                        })),
                        Err(e) => warp::reply::json(&serde_json::json!({
                            "status": "error",
                            "msg": e
                        })),
                    }
                },
            );

        // 9. GET /contract/:address
        let wasm_get = wasm_engine.clone();
        let get_contract = warp::path!("contract" / String)
            .and(with_state(wasm_get))
            .map(
                |addr: String, engine: Arc<WasmEngine>| match engine.get_contract(&addr) {
                    Ok(contract) => warp::reply::json(&serde_json::json!({
                        "status": "success",
                        "contract": {
                            "address": contract.address,
                            "code_hash": contract.code_hash,
                            "balance": contract.balance,
                            "owner": contract.owner,
                            "created_at_block": contract.created_at_block,
                            "state": contract.state
                        }
                    })),
                    Err(e) => warp::reply::json(&serde_json::json!({
                        "status": "error",
                        "msg": e
                    })),
                },
            );

        deploy
            .boxed()
            .or(call.boxed())
            .or(get_contract.boxed())
            .boxed()
    };

    #[cfg(not(feature = "vm"))]
    let deploy_route = {
        let deploy = warp::path("deploy-contract").and(warp::post()).map(|| {
            warp::reply::json(&serde_json::json!({"status":"error","msg":"VM feature not enabled"}))
        });
        let call = warp::path("call-contract").and(warp::post()).map(|| {
            warp::reply::json(&serde_json::json!({"status":"error","msg":"VM feature not enabled"}))
        });
        let get_contract = warp::path!("contract" / String).map(|_: String| {
            warp::reply::json(&serde_json::json!({"status":"error","msg":"VM feature not enabled"}))
        });
        deploy
            .boxed()
            .or(call.boxed())
            .or(get_contract.boxed())
            .boxed()
    };

    // 10. GET /metrics (Prometheus endpoint)
    let metrics_clone = metrics.clone();
    let ledger_metrics = ledger.clone();
    let db_metrics = database.clone();
    let metrics_route = warp::path("metrics")
        .and(with_state((metrics_clone, ledger_metrics, db_metrics)))
        .map(
            |(m, l, db): (Arc<UatMetrics>, Arc<Mutex<Ledger>>, Arc<UatDatabase>)| {
                // Update blockchain metrics before export
                {
                    let ledger_guard = safe_lock(&l);
                    m.update_blockchain_metrics(&ledger_guard);
                }

                // Update database metrics
                let stats = db.stats();
                m.update_db_metrics(&stats);

                // Export all metrics
                match m.export() {
                    Ok(output) => warp::reply::with_header(
                        output,
                        "Content-Type",
                        "text/plain; version=0.0.4",
                    ),
                    Err(e) => warp::reply::with_header(
                        format!("# Error exporting metrics: {}", e),
                        "Content-Type",
                        "text/plain",
                    ),
                }
            },
        );

    // 11. GET /node-info (Network metadata for CLI)
    let l_info = ledger.clone();
    let ab_info = address_book.clone();
    let my_addr_info = my_address.clone();
    let bv_info = bootstrap_validators.clone();
    let aw_info = anti_whale.clone();
    let node_info_route = warp::path("node-info")
        .and(with_state((l_info, ab_info, aw_info)))
        .map(
            move |(l, ab, aw): (
                Arc<Mutex<Ledger>>,
                Arc<Mutex<HashMap<String, String>>>,
                Arc<Mutex<AntiWhaleEngine>>,
            )| {
                let l_guard = safe_lock(&l);
                let aw_guard = safe_lock(&aw);
                // Protocol constant: 21,936,236 UAT total supply (immutable)
                // Validated against genesis_config.json on mainnet startup
                let total_supply = TOTAL_SUPPLY_VOID;
                let circulating = total_supply - l_guard.distribution.remaining_supply;

                // Validator count = genesis bootstrap validators
                // (Does NOT include treasury wallets with high balances)
                let validator_count = bv_info.len();
                let peer_count = safe_lock(&ab).len();
                let network = if uat_core::CHAIN_ID == 1 {
                    "uat-mainnet"
                } else {
                    "uat-testnet"
                };

                warp::reply::json(&serde_json::json!({
                    "chain_id": network,
                    "network": network,
                    "address": my_addr_info,
                    "version": env!("CARGO_PKG_VERSION"),
                    "block_height": l_guard.blocks.len(),
                    "validator_count": validator_count,
                    "peer_count": peer_count,
                    "total_supply": format_balance_precise(total_supply),
                    "circulating_supply": format_balance_precise(circulating),
                    "network_tps": 0,
                    "protocol": {
                        "base_fee_void": uat_core::BASE_FEE_VOID,
                        "pow_difficulty_bits": uat_core::MIN_POW_DIFFICULTY_BITS,
                        "void_per_uat": uat_core::VOID_PER_UAT,
                        "chain_id_numeric": uat_core::CHAIN_ID,
                        "anti_whale": {
                            "max_tx_per_window": aw_guard.config().max_tx_per_block,
                            "fee_scale_multiplier": aw_guard.config().fee_scale_multiplier,
                            "window_secs": AntiWhaleEngine::ACTIVITY_WINDOW_SECS
                        }
                    }
                }))
            },
        );

    // 12. GET /validators (List ALL active validators — genesis + dynamically registered)
    // Includes bootstrap validators from genesis AND user-registered validators
    // with balance >= MIN_VALIDATOR_STAKE_VOID (1000 UAT).
    let l_validators = ledger.clone();
    let ab_validators = address_book.clone();
    let my_addr_validators = my_address.clone();
    let bv_validators = bootstrap_validators.clone();
    let sm_validators = slashing_manager.clone();
    let validators_route = warp::path("validators")
        .and(with_state((l_validators, ab_validators)))
        .map(
            move |(l, ab): (Arc<Mutex<Ledger>>, Arc<Mutex<HashMap<String, String>>>)| {
                let l_guard = safe_lock(&l);
                let ab_guard = safe_lock(&ab);

                // Collect ALL validator addresses: genesis bootstrap + accounts with is_validator flag
                let mut all_validator_addrs: Vec<String> = bv_validators.clone();
                {
                    let sm_guard = safe_lock(&sm_validators);
                    for addr in sm_guard.get_all_validator_addresses() {
                        if !all_validator_addrs.contains(&addr) {
                            all_validator_addrs.push(addr);
                        }
                    }
                }
                // Also include accounts explicitly marked as validators (user-registered)
                for (addr, acc) in &l_guard.accounts {
                    if acc.is_validator && !all_validator_addrs.contains(addr) {
                        all_validator_addrs.push(addr.clone());
                    }
                }

                let validators: Vec<serde_json::Value> = all_validator_addrs
                    .iter()
                    .filter_map(|addr| {
                        l_guard.accounts.get(addr.as_str()).map(|acc| {
                            let is_self = addr == &my_addr_validators;
                            let in_peers = ab_guard.values().any(|v| v.contains(addr.as_str()));
                            let is_genesis = bv_validators.contains(addr);
                            let active =
                                is_self || in_peers || acc.balance >= MIN_VALIDATOR_STAKE_VOID;
                            serde_json::json!({
                                "address": addr,
                                "stake": acc.balance / VOID_PER_UAT,
                                "is_active": active,
                                "active": active,
                                "is_genesis": is_genesis,
                                "uptime_percentage": if active { 99.9 } else { 0.0 }
                            })
                        })
                    })
                    .collect();

                warp::reply::json(&serde_json::json!({
                    "validators": validators
                }))
            },
        );

    // 13. GET /balance/:address (Check balance - alias for CLI compatibility)
    let l_balance_alias = ledger.clone();
    let balance_alias_route = warp::path!("balance" / String)
        .and(with_state(l_balance_alias))
        .map(|addr: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            let full_addr = l_guard
                .accounts
                .keys()
                .find(|k| get_short_addr(k) == addr || **k == addr)
                .cloned()
                .unwrap_or(addr.clone());
            let bal = l_guard
                .accounts
                .get(&full_addr)
                .map(|a| a.balance)
                .unwrap_or(0);
            warp::reply::json(&serde_json::json!({
                "address": full_addr,
                "balance": format_balance_precise(bal),
                "balance_uat": format_balance_precise(bal),
                "balance_voi": bal
            }))
        });

    // 13b. GET /fee-estimate/:address (Dynamic fee estimate for anti-whale)
    // Returns estimated fee for the NEXT transaction from this address.
    // Wallet MUST call this before constructing a signed block.
    let aw_fee_estimate = anti_whale.clone();
    let fee_estimate_route = warp::path!("fee-estimate" / String)
        .and(with_state(aw_fee_estimate))
        .map(|addr: String, aw: Arc<Mutex<AntiWhaleEngine>>| {
            let aw_guard = safe_lock(&aw);
            let base_fee = uat_core::BASE_FEE_VOID;
            let estimated_fee = aw_guard.estimate_fee(&addr, base_fee as u64);
            let multiplier = estimated_fee / (base_fee as u64);
            let window_secs = AntiWhaleEngine::ACTIVITY_WINDOW_SECS;
            let max_tx = aw_guard.config().max_tx_per_block;
            let activity = aw_guard.get_activity(&addr);
            let (tx_count, window_remaining) = match activity {
                Some(a) => {
                    let now = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();
                    let elapsed = now.saturating_sub(a.window_start);
                    let remaining = if elapsed >= window_secs {
                        0
                    } else {
                        window_secs - elapsed
                    };
                    (a.tx_count, remaining)
                }
                None => (0, 0),
            };
            warp::reply::json(&serde_json::json!({
                "address": addr,
                "base_fee_void": base_fee,
                "estimated_fee_void": estimated_fee,
                "fee_multiplier": multiplier,
                "tx_count_in_window": tx_count,
                "max_tx_per_window": max_tx,
                "window_remaining_secs": window_remaining,
                "window_duration_secs": window_secs
            }))
        });

    // 14. GET /block (Latest block)
    let l_block = ledger.clone();
    let block_route = warp::path("block")
        .and(with_state(l_block))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            // Get latest block by timestamp (HashMap has no guaranteed order)
            let latest = l_guard.blocks.values().max_by_key(|b| b.timestamp);
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

    // 15. POST /faucet (TESTNET ONLY - Free UAT for testing)
    let l_faucet = ledger.clone();
    let db_faucet = database.clone();
    let fl_faucet = faucet_limiter.clone();
    let pk_faucet = node_public_key.clone();
    let sk_faucet = secret_key.clone();
    let faucet_route = warp::path("faucet")
        .and(warp::post())
        .and(warp::body::json())
        .and(with_state((l_faucet, db_faucet, fl_faucet, pk_faucet, sk_faucet)))
        .map(#[allow(clippy::type_complexity)] |req: serde_json::Value, (l, db, rate_lim, node_pk, node_sk): (Arc<Mutex<Ledger>>, Arc<UatDatabase>, Arc<EndpointRateLimiter>, Vec<u8>, Vec<u8>)| {
            if !testnet_config::get_testnet_config().should_enable_faucet() {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Faucet only available in Functional/Consensus testnet modes"
                }));
            }

            let address = req["address"].as_str().unwrap_or("");
            if address.is_empty() {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": "Address required"
                }));
            }

            // PERSISTENT cooldown: 1 faucet claim per 2 minutes per address (survives restart)
            const FAUCET_COOLDOWN_SECS: u64 = 120; // 2 minutes (testnet-friendly)
            if let Err(remaining) = db.check_faucet_cooldown(address, FAUCET_COOLDOWN_SECS) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "code": 429,
                    "msg": format!("Faucet cooldown active: try again in {} seconds", remaining)
                }));
            }

            // In-memory rate limit as secondary protection
            if let Err(wait_secs) = rate_lim.check_and_record(address) {
                return warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "code": 429,
                    "msg": format!("Rate limit exceeded: max 1 faucet claim per 2 minutes. Try again in {} seconds.", wait_secs)
                }));
            }

            let faucet_amount = 5_000u128 * VOID_PER_UAT; // 5k UAT (reduced from 100k to prevent exceeding validator stake)

            let mut l_guard = safe_lock(&l);

            // Ensure account exists
            if !l_guard.accounts.contains_key(address) {
                l_guard.accounts.insert(address.to_string(), AccountState {
                    head: "0".to_string(),
                    balance: 0,
                    block_count: 0,
                    is_validator: false,
                });
            }

            let state = l_guard.accounts.get(address).cloned().unwrap_or(AccountState {
                head: "0".to_string(),
                balance: 0,
                block_count: 0,
                is_validator: false,
            });

            // CRITICAL FIX: Create proper Mint block with PoW + signature, use process_block()
            // This ensures remaining_supply is properly deducted
            let mut faucet_block = Block {
                account: address.to_string(),
                previous: state.head.clone(),
                block_type: BlockType::Mint,
                amount: faucet_amount,
                link: format!("FAUCET:TESTNET:{}", std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs()),
                signature: "".to_string(),
                public_key: hex::encode(&node_pk),
                work: 0,
                timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                fee: 0,
            };

            solve_pow(&mut faucet_block);
            faucet_block.signature = hex::encode(
                uat_crypto::sign_message(faucet_block.signing_hash().as_bytes(), &node_sk).expect("BUG: signing failed — key corrupted")
            );

            match l_guard.process_block(&faucet_block) {
                Ok(hash) => {
                    let new_balance = l_guard.accounts.get(address)
                        .map(|a| a.balance).unwrap_or(0);

                    // Persist faucet cooldown to database (survives restart)
                    let _ = db.record_faucet_claim(address);

                    SAVE_DIRTY.store(true, Ordering::Relaxed);

                    warp::reply::json(&serde_json::json!({
                        "status": "success",
                        "msg": "Faucet claim successful",
                        "amount": faucet_amount / VOID_PER_UAT,
                        "new_balance": new_balance / VOID_PER_UAT,
                        "block_hash": hash
                    }))
                }
                Err(e) => {
                    warp::reply::json(&serde_json::json!({
                        "status": "error",
                        "msg": format!("Faucet mint failed: {}", e)
                    }))
                }
            }
        });

    // 16. GET /blocks/recent (Recent blocks for validator dashboard)
    let l_blocks = ledger.clone();
    let blocks_recent_route = warp::path!("blocks" / "recent")
        .and(with_state(l_blocks))
        .map(|l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            // SECURITY FIX #13: Sort by timestamp descending for deterministic recent blocks
            let mut block_list: Vec<(&String, &Block)> = l_guard.blocks.iter().collect();
            block_list.sort_by(|a, b| b.1.timestamp.cmp(&a.1.timestamp));
            let blocks: Vec<serde_json::Value> = block_list
                .iter()
                .take(10) // Last 10 blocks by timestamp
                .map(|(hash, b)| {
                    serde_json::json!({
                        "hash": hash,
                        "height": l_guard.blocks.len(),
                        "timestamp": b.timestamp,
                        "transactions_count": 1,
                        "account": b.account,
                        "amount": b.amount / VOID_PER_UAT
                    })
                })
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

    // 18. GET /account/:address (Account details - balance + history combined)
    let l_account = ledger.clone();
    let account_route = warp::path!("account" / String)
        .and(with_state(l_account))
        .map(|addr: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            let state = l_guard
                .accounts
                .get(&addr)
                .cloned()
                .unwrap_or(AccountState {
                    head: "0".to_string(),
                    balance: 0,
                    block_count: 0,
                    is_validator: false,
                });

            // Get transaction history for this account
            // FIX v1.0.7: Include from, to, timestamp fields + resolve actual
            // sender for Receive blocks (look up originating Send block)
            let mut transactions: Vec<serde_json::Value> = Vec::new();
            for (hash, block) in l_guard.blocks.iter() {
                if block.account == addr {
                    // Resolve `from` address: for Receive blocks, look up the Send block
                    // to get the actual sender instead of showing "SYSTEM"
                    let from_addr = match block.block_type {
                        BlockType::Send => block.account.clone(),
                        BlockType::Receive => {
                            // block.link = hash of the Send block that funded this Receive
                            l_guard.blocks.get(&block.link)
                                .map(|send_blk| send_blk.account.clone())
                                .unwrap_or_else(|| "SYSTEM".to_string())
                        },
                        _ => "SYSTEM".to_string(), // Mint, Slash, Change
                    };
                    // Resolve `to` address
                    let to_addr = match block.block_type {
                        BlockType::Receive => block.account.clone(),
                        _ => block.link.clone(), // Send→recipient, Mint→link
                    };
                    transactions.push(serde_json::json!({
                        "hash": hash,
                        "from": from_addr,
                        "to": to_addr,
                        "type": format!("{:?}", block.block_type).to_lowercase(),
                        "amount": format!("{}.{:011}", block.amount / VOID_PER_UAT, block.amount % VOID_PER_UAT),
                        "timestamp": block.timestamp,
                        "link": block.link,
                        "previous": block.previous,
                        "fee": block.fee
                    }));
                }
            }

            warp::reply::json(&serde_json::json!({
                "address": addr,
                "balance": format_balance_precise(state.balance),
                "balance_uat": format_balance_precise(state.balance),
                "balance_voi": state.balance,
                "block_count": state.block_count,
                "head_block": state.head,
                "transactions": transactions,
                "transaction_count": transactions.len()
            }))
        });

    // 19. GET / (Root endpoint - API welcome)
    let root_route = warp::path::end()
        .map(|| {
            let network_label = if uat_core::is_mainnet_build() { "mainnet" } else { "testnet" };
            warp::reply::json(&serde_json::json!({
                "name": "Unauthority (UAT) Blockchain API",
                "version": env!("CARGO_PKG_VERSION"),
                "network": network_label,
                "description": "Decentralized blockchain with Proof-of-Burn consensus",
                "endpoints": {
                    "health": "GET /health - Health check",
                    "node_info": "GET /node-info - Node information",
                    "balance": "GET /balance/{address} - Account balance",
                    "fee_estimate": "GET /fee-estimate/{address} - Dynamic fee estimate (anti-whale)",
                    "account": "GET /account/{address} - Account details + history",
                    "history": "GET /history/{address} - Transaction history",
                    "validators": "GET /validators - Active validators",
                    "peers": "GET /peers - Connected peers",
                    "block": "GET /block - Latest block",
                    "block_height": "GET /block/{height} - Block at height",
                    "whoami": "GET /whoami - Node's signing address",
                    "faucet": "POST /faucet {address} - Claim testnet tokens (Functional/Consensus testnet)",
                    "send": "POST /send {from, target, amount} - Send transaction",
                    "burn": "POST /burn {chain, tx_hash} - Proof-of-burn mint",
                    "consensus": "GET /consensus - aBFT consensus parameters and safety status",
                    "reward_info": "GET /reward-info - Validator reward pool status and epoch info"
                },
                "docs": "https://github.com/unauthoritymky-6236/unauthority-core",
                "status": "operational"
            }))
        });

    // 20. GET /slashing (Slashing statistics and validator safety)
    let sm_stats = slashing_manager.clone();
    let slashing_route =
        warp::path("slashing")
            .and(with_state(sm_stats))
            .map(|sm: Arc<Mutex<SlashingManager>>| {
                let sm_guard = safe_lock(&sm);
                let stats = sm_guard.get_safety_stats();
                let banned = sm_guard.get_banned_validators();
                let slashed = sm_guard.get_slashed_validators();
                let events = sm_guard.get_all_slash_events();

                let events_json: Vec<serde_json::Value> = events
                    .iter()
                    .map(|e| {
                        serde_json::json!({
                            "block_height": e.block_height,
                            "validator": e.validator_address,
                            "violation": format!("{:?}", e.violation_type),
                            "slash_amount_void": e.slash_amount_void,
                            "slash_bps": e.slash_bps,
                            "timestamp": e.timestamp
                        })
                    })
                    .collect();

                warp::reply::json(&serde_json::json!({
                    "safety_stats": {
                        "total_validators": stats.total_validators,
                        "active_validators": stats.active_validators,
                        "banned_count": stats.banned_count,
                        "slashed_count": stats.slashed_count,
                        "total_slashed_void": stats.total_slashed_void,
                        "total_slash_events": stats.total_slash_events
                    },
                    "banned_validators": banned,
                    "slashed_validators": slashed,
                    "recent_events": events_json
                }))
            });

    // 21. GET /slashing/:address (Validator-specific slashing info)
    let sm_profile = slashing_manager.clone();
    let slashing_profile_route = warp::path!("slashing" / String)
        .and(with_state(sm_profile))
        .map(|addr: String, sm: Arc<Mutex<SlashingManager>>| {
            let sm_guard = safe_lock(&sm);
            if let Some(profile) = sm_guard.get_profile(&addr) {
                let history: Vec<serde_json::Value> = profile
                    .slash_history
                    .iter()
                    .map(|e| {
                        serde_json::json!({
                            "block_height": e.block_height,
                            "violation": format!("{:?}", e.violation_type),
                            "slash_amount_void": e.slash_amount_void,
                            "slash_bps": e.slash_bps,
                            "timestamp": e.timestamp
                        })
                    })
                    .collect();

                warp::reply::json(&serde_json::json!({
                    "address": addr,
                    "status": format!("{:?}", profile.status),
                    "uptime_percent": profile.get_uptime_percent(),
                    "total_slashed_void": profile.total_slashed_void,
                    "violation_count": profile.violation_count,
                    "blocks_participated": profile.blocks_participated,
                    "total_blocks_observed": profile.total_blocks_observed,
                    "slash_history": history
                }))
            } else {
                warp::reply::json(&serde_json::json!({
                    "error": "Validator not found in slashing manager",
                    "address": addr
                }))
            }
        });

    // 22. GET /health (Health check endpoint)
    let l_health = ledger.clone();
    let db_health = database.clone();
    let health_route = warp::path("health")
        .and(with_state((l_health, db_health)))
        .map(move |(l, db): (Arc<Mutex<Ledger>>, Arc<UatDatabase>)| {
            let l_guard = safe_lock(&l);
            let db_stats = db.stats();

            // Check system health
            let is_healthy = !l_guard.accounts.is_empty() && db_stats.accounts_count > 0;
            let status = if is_healthy { "healthy" } else { "degraded" };

            warp::reply::json(&serde_json::json!({
                "status": status,
                "uptime_seconds": start_time.elapsed().as_secs(),
                "chain": {
                    "id": if uat_core::is_mainnet_build() { "uat-mainnet" } else { "uat-testnet" },
                    "accounts": l_guard.accounts.len(),
                    "blocks": l_guard.blocks.len()
                },
                "database": {
                    "accounts_count": db_stats.accounts_count,
                    "blocks_count": db_stats.blocks_count,
                    "size_on_disk": db_stats.size_on_disk
                },
                "version": env!("CARGO_PKG_VERSION"),
                "timestamp": std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs()
            }))
        });

    // 23. GET /block/:hash (Block explorer - get block by hash)
    let l_block_hash = ledger.clone();
    let block_by_hash_route = warp::path!("block" / String)
        .and(with_state(l_block_hash))
        .map(|hash: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            if let Some(block) = l_guard.blocks.get(&hash) {
                warp::reply::json(&serde_json::json!({
                    "status": "success",
                    "block": {
                        "hash": hash,
                        "account": block.account,
                        "previous": block.previous,
                        "type": format!("{:?}", block.block_type),
                        "amount": block.amount / VOID_PER_UAT,
                        "amount_voi": block.amount,
                        "link": block.link,
                        "signature": block.signature,
                        "public_key": block.public_key,
                        "work": block.work,
                        "timestamp": block.timestamp
                    }
                }))
            } else {
                warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": format!("Block not found: {}", hash)
                }))
            }
        });

    // 24. GET /transaction/:hash (Alias for block by hash - block explorer compatibility)
    let l_tx_hash = ledger.clone();
    let tx_by_hash_route = warp::path!("transaction" / String)
        .and(with_state(l_tx_hash))
        .map(|hash: String, l: Arc<Mutex<Ledger>>| {
            let l_guard = safe_lock(&l);
            if let Some(block) = l_guard.blocks.get(&hash) {
                warp::reply::json(&serde_json::json!({
                    "status": "success",
                    "transaction": {
                        "hash": hash,
                        "from": block.account.clone(),
                        "to": if block.block_type == BlockType::Send { block.link.clone() } else { block.account.clone() },
                        "type": format!("{:?}", block.block_type),
                        "amount": block.amount / VOID_PER_UAT,
                        "amount_voi": block.amount,
                        "timestamp": block.timestamp,
                        "signature": block.signature,
                        "confirmed": true
                    }
                }))
            } else {
                warp::reply::json(&serde_json::json!({
                    "status": "error",
                    "msg": format!("Transaction not found: {}", hash)
                }))
            }
        });

    // 25. GET /search/:query (Block explorer - search for address, block, or transaction)
    let l_search = ledger.clone();
    let ab_search = address_book.clone();
    let search_route = warp::path!("search" / String)
        .and(with_state((l_search, ab_search)))
        .map(
            #[allow(clippy::type_complexity)]
            |query: String, (l, ab): (Arc<Mutex<Ledger>>, Arc<Mutex<HashMap<String, String>>>)| {
                let l_guard = safe_lock(&l);
                let mut results = Vec::new();

                // Check if it's a full address
                if l_guard.accounts.contains_key(&query) {
                    if let Some(acc) = l_guard.accounts.get(&query) {
                        results.push(serde_json::json!({
                            "type": "account",
                            "address": query,
                            "balance": acc.balance / VOID_PER_UAT,
                            "block_count": acc.block_count
                        }));
                    }
                }

                // Check if it's a block hash
                if l_guard.blocks.contains_key(&query) {
                    results.push(serde_json::json!({
                        "type": "block",
                        "hash": query
                    }));
                }

                // Check if it's a short address
                let ab_guard = safe_lock(&ab);
                if let Some(full) = ab_guard.get(&query) {
                    if let Some(acc) = l_guard.accounts.get(full) {
                        results.push(serde_json::json!({
                            "type": "account",
                            "address": full,
                            "short_address": query,
                            "balance": acc.balance / VOID_PER_UAT,
                            "block_count": acc.block_count
                        }));
                    }
                }

                // Partial match on addresses
                if results.is_empty() {
                    for (addr, acc) in l_guard.accounts.iter() {
                        if addr.contains(&query) {
                            results.push(serde_json::json!({
                                "type": "account",
                                "address": addr,
                                "balance": acc.balance / VOID_PER_UAT,
                                "block_count": acc.block_count
                            }));
                            if results.len() >= 10 {
                                break;
                            } // Limit to 10 results
                        }
                    }
                }

                warp::reply::json(&serde_json::json!({
                    "query": query,
                    "results": results,
                    "count": results.len()
                }))
            },
        );

    // CORS configuration
    // SECURITY: Behind Tor hidden service, browser requests come from .onion origin.
    // Allow any origin since Tor hidden services are already access-controlled by
    // the .onion address itself. Same-origin would block legitimate Tor Browser users.
    let cors = if uat_core::is_mainnet_build() {
        warp::cors()
            .allow_any_origin() // .onion addresses serve as access control
            .allow_methods(vec!["GET", "POST", "OPTIONS"])
            .allow_headers(vec!["Content-Type", "Accept"])
    } else {
        warp::cors()
            .allow_any_origin()
            .allow_methods(vec!["GET", "POST", "PUT", "DELETE", "OPTIONS"])
            .allow_headers(vec!["Content-Type", "Authorization", "Accept"])
    };

    // 26. GET /sync (HTTP-based state sync for Tor peers)
    // Returns GZIP-compressed ledger state for peers that connect via HTTP
    let l_sync = ledger.clone();
    let sync_route = warp::path("sync")
        .and(warp::query::<std::collections::HashMap<String, String>>())
        .and(with_state(l_sync))
        .map(
            |params: std::collections::HashMap<String, String>, l: Arc<Mutex<Ledger>>| {
                let their_blocks: usize = params
                    .get("blocks")
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(0);

                let l_guard = safe_lock(&l);
                let our_blocks = l_guard.blocks.len();

                // Only send state if we have more blocks
                if our_blocks <= their_blocks {
                    return warp::reply::json(&serde_json::json!({
                        "status": "up_to_date",
                        "blocks": our_blocks
                    }));
                }

                // Collect non-Mint/Slash blocks only (those must go through consensus)
                let sync_blocks: std::collections::HashMap<String, &uat_core::Block> = l_guard
                    .blocks
                    .iter()
                    .filter(|(_, b)| !matches!(b.block_type, BlockType::Mint | BlockType::Slash))
                    .take(5000) // Cap at 5000 blocks per sync
                    .map(|(k, v)| (k.clone(), v))
                    .collect();

                let accounts_snapshot: std::collections::HashMap<&String, &AccountState> =
                    l_guard.accounts.iter().collect();

                warp::reply::json(&serde_json::json!({
                    "status": "sync",
                    "blocks": sync_blocks,
                    "accounts": accounts_snapshot,
                    "our_block_count": our_blocks,
                    "distribution": l_guard.distribution
                }))
            },
        );

    // 27. GET /consensus (aBFT consensus parameters and safety status)
    let abft_consensus_route = abft_consensus.clone();
    let l_consensus = ledger.clone();
    let consensus_route = warp::path("consensus")
        .and(with_state((abft_consensus_route, l_consensus)))
        .map(
            |(abft, l): (Arc<Mutex<ABFTConsensus>>, Arc<Mutex<Ledger>>)| {
                let abft_guard = safe_lock(&abft);
                let l_guard = safe_lock(&l);
                let stats = abft_guard.get_statistics();
                let active_validators = l_guard
                    .accounts
                    .iter()
                    .filter(|(_, a)| a.balance >= MIN_VALIDATOR_STAKE_VOID)
                    .count();

                warp::reply::json(&serde_json::json!({
                    "protocol": "aBFT (Weighted Confirmation)",
                    "safety": {
                        "byzantine_safe": abft_guard.is_byzantine_safe(0),
                        "total_validators": stats.total_validators,
                        "active_validators": active_validators,
                        "max_faulty": stats.max_faulty_validators,
                        "quorum_threshold": stats.quorum_threshold,
                        "formula": "f < n/3, quorum = 2f+1"
                    },
                    "confirmation": {
                        "send_threshold": SEND_CONSENSUS_THRESHOLD,
                        "burn_threshold": BURN_CONSENSUS_THRESHOLD,
                        "voting_model": "quadratic (sqrt(stake) * 1000)",
                        "signature_scheme": "Dilithium5 (post-quantum)"
                    },
                    "finality": {
                        "target_ms": 3000,
                        "blocks_finalized": stats.blocks_finalized,
                        "current_view": stats.current_view,
                        "current_sequence": stats.current_sequence
                    }
                }))
            },
        );

    // 28. GET /reward-info (Validator reward pool status)
    let rp_info = reward_pool.clone();
    let reward_info_route = warp::path("reward-info").and(with_state(rp_info)).map(
        |rp: Arc<Mutex<ValidatorRewardPool>>| {
            let pool = safe_lock(&rp);
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            let summary = pool.pool_summary();
            let remaining_secs = pool.epoch_remaining_secs(now);

            // Per-validator reward details
            let validators_json: Vec<serde_json::Value> = pool
                .validators
                .iter()
                .map(|(addr, v)| {
                    serde_json::json!({
                        "address": addr,
                        "is_genesis": v.is_genesis,
                        "join_epoch": v.join_epoch,
                        "stake_void": v.stake_void,
                        "uptime_pct": v.uptime_pct(),
                        "cumulative_rewards_void": v.cumulative_rewards_void,
                        "eligible": v.is_eligible(pool.current_epoch),
                        "heartbeats_current_epoch": v.heartbeats_current_epoch,
                        "expected_heartbeats": v.expected_heartbeats,
                    })
                })
                .collect();

            warp::reply::json(&serde_json::json!({
                "pool": {
                    "remaining_void": summary.remaining_void,
                    "remaining_uat": summary.remaining_void / VOID_PER_UAT,
                    "total_distributed_void": summary.total_distributed_void,
                    "total_distributed_uat": summary.total_distributed_void / VOID_PER_UAT,
                    "pool_exhaustion_pct": summary.pool_exhaustion_pct,
                },
                "epoch": {
                    "current_epoch": summary.current_epoch,
                    "epoch_reward_rate_void": summary.epoch_reward_rate_void,
                    "epoch_reward_rate_uat": summary.epoch_reward_rate_void / VOID_PER_UAT,
                    "halvings_occurred": summary.halvings_occurred,
                    "epoch_remaining_secs": remaining_secs,
                    "epoch_duration_secs": uat_core::REWARD_EPOCH_SECS,
                },
                "validators": {
                    "total": summary.total_validators,
                    "eligible": summary.eligible_validators,
                    "details": validators_json,
                },
                "config": {
                    "min_uptime_pct": uat_core::REWARD_MIN_UPTIME_PCT,
                    "probation_epochs": uat_core::REWARD_PROBATION_EPOCHS,
                    "halving_interval_epochs": uat_core::REWARD_HALVING_INTERVAL_EPOCHS,
                    "distribution_model": "sqrt(stake)-weighted proportional",
                    "genesis_excluded": true,
                }
            }))
        },
    );

    // Combine all routes with rate limiting
    // NOTE: Each route is .boxed() to prevent warp type recursion overflow (E0275)
    // when compiling in release mode. This breaks the deeply nested type chain.
    let group1 = root_route
        .boxed()
        .or(balance_route.boxed())
        .or(supply_route.boxed())
        .or(history_route.boxed())
        .or(peers_route.boxed())
        .or(send_route.boxed())
        .boxed();

    let group2 = burn_route
        .boxed()
        .or(deploy_route)
        .or(metrics_route.boxed())
        .or(node_info_route.boxed())
        .boxed();

    let group3 = validators_route
        .boxed()
        .or(balance_alias_route.boxed())
        .or(fee_estimate_route.boxed())
        .or(block_route.boxed())
        .or(faucet_route.boxed())
        .or(blocks_recent_route.boxed())
        .or(whoami_route.boxed())
        .boxed();

    let group4 = account_route
        .boxed()
        .or(health_route.boxed())
        .or(slashing_route.boxed())
        .or(slashing_profile_route.boxed())
        .or(block_by_hash_route.boxed())
        .or(tx_by_hash_route.boxed())
        .or(search_route.boxed())
        .or(sync_route.boxed())
        .or(consensus_route.boxed())
        .or(reward_info_route.boxed())
        .boxed();

    let routes = group1
        .or(group2)
        .or(group3)
        .or(group4)
        .with(cors) // Apply CORS
        .with(warp::log("api"))
        .recover(handle_rejection);

    // Apply rate limiting globally
    let routes_with_limit = rate_limit_filter.and(routes);

    // SECURITY FIX V4#11: Bind to 127.0.0.1 for Tor/production (prevents IP leak)
    // Set UAT_BIND_ALL=1 for local dev with multiple machines
    // FIX: Check for "1" specifically to prevent accidental exposure (e.g., UAT_BIND_ALL=0)
    let bind_addr: [u8; 4] = if std::env::var("UAT_BIND_ALL").unwrap_or_default() == "1" {
        [0, 0, 0, 0]
    } else {
        [127, 0, 0, 1] // Default: localhost only (safe for Tor hidden service)
    };
    println!(
        "🌍 API Server running at http://{}:{} (Rate Limit: 100 req/sec per IP)",
        if bind_addr == [0, 0, 0, 0] {
            "0.0.0.0"
        } else {
            "127.0.0.1"
        },
        api_port
    );
    // Flush stdout — when spawned from Flutter, stdout is a pipe (fully buffered)
    {
        use std::io::Write;
        let _ = std::io::stdout().flush();
    }
    warp::serve(routes_with_limit)
        .run((bind_addr, api_port))
        .await;
}

// Rate limit rejection handler
async fn handle_rejection(
    err: warp::Rejection,
) -> Result<impl warp::Reply, std::convert::Infallible> {
    if let Some(rate_limiter::filters::RateLimitExceeded { ip }) = err.find() {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 429,
            "msg": "Rate limit exceeded. Please slow down your requests.",
            "ip": ip.to_string()
        }));
        Ok(warp::reply::with_status(
            json,
            warp::http::StatusCode::TOO_MANY_REQUESTS,
        ))
    } else if err.is_not_found() {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 404,
            "msg": "Endpoint not found"
        }));
        Ok(warp::reply::with_status(
            json,
            warp::http::StatusCode::NOT_FOUND,
        ))
    } else {
        let json = warp::reply::json(&serde_json::json!({
            "status": "error",
            "code": 500,
            "msg": "Internal server error"
        }));
        Ok(warp::reply::with_status(
            json,
            warp::http::StatusCode::INTERNAL_SERVER_ERROR,
        ))
    }
}

async fn get_crypto_prices() -> (f64, f64) {
    // SECURITY: Route oracle requests through Tor SOCKS5 proxy if available
    // Prevents IP leak when fetching prices from clearweb APIs
    let proxy_url = std::env::var("UAT_SOCKS5_PROXY").unwrap_or_default();
    let client = if !proxy_url.is_empty() {
        match reqwest::Proxy::all(&proxy_url) {
            Ok(proxy) => reqwest::Client::builder()
                .user_agent("Mozilla/5.0")
                .timeout(Duration::from_secs(15))
                .proxy(proxy)
                .build()
                .unwrap_or_default(),
            Err(e) => {
                println!(
                    "⚠️ Oracle SOCKS5 proxy failed ({}): {} — using direct",
                    proxy_url, e
                );
                reqwest::Client::builder()
                    .user_agent("Mozilla/5.0")
                    .timeout(Duration::from_secs(10))
                    .build()
                    .unwrap_or_default()
            }
        }
    } else {
        reqwest::Client::builder()
            .user_agent("Mozilla/5.0")
            .timeout(Duration::from_secs(10))
            .build()
            .unwrap_or_default()
    };

    let url_coingecko =
        "https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=usd";
    let url_cryptocompare =
        "https://min-api.cryptocompare.com/data/pricemulti?fsyms=BTC,ETH&tsyms=USD";
    let url_kraken = "https://api.kraken.com/0/public/Ticker?pair=ETHUSD,XBTUSD"; // Kraken (global exchange)

    let mut eth_prices = Vec::new();
    let mut btc_prices = Vec::new();

    // 1. Fetch CoinGecko
    if let Ok(resp) = client.get(url_coingecko).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ethereum"]["usd"].as_f64() {
                eth_prices.push(p);
            }
            if let Some(p) = json["bitcoin"]["usd"].as_f64() {
                btc_prices.push(p);
            }
        }
    }

    // 2. Fetch CryptoCompare
    if let Ok(resp) = client.get(url_cryptocompare).send().await {
        if let Ok(json) = resp.json::<Value>().await {
            if let Some(p) = json["ETH"]["USD"].as_f64() {
                eth_prices.push(p);
            }
            if let Some(p) = json["BTC"]["USD"].as_f64() {
                btc_prices.push(p);
            }
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
                            if let Ok(p) = p_str.parse::<f64>() {
                                eth_prices.push(p);
                            }
                        }
                    }
                }
                if let Some(btc) = result.get("XXBTZUSD") {
                    if let Some(p_array) = btc["c"].as_array() {
                        if let Some(p_str) = p_array[0].as_str() {
                            if let Ok(p) = p_str.parse::<f64>() {
                                btc_prices.push(p);
                            }
                        }
                    }
                }
            }
        }
    }

    // Calculate Final Average
    // SECURITY: On production testnet level, require at least 1 real oracle price
    // Fallback prices are only used on functional/consensus levels
    let is_production_level = testnet_config::get_testnet_config().should_enable_oracle_consensus()
        && testnet_config::is_production_simulation();

    let final_eth = if eth_prices.is_empty() {
        if is_production_level {
            println!("🛑 PRODUCTION: All ETH oracle APIs failed — rejecting (fail-closed)");
            0.0 // Fail-closed: returning 0 will cause burn validation to reject
        } else {
            println!("⚠️ Oracle: No ETH prices from APIs, using testnet fallback $2500");
            2500.0
        }
    } else {
        eth_prices.iter().sum::<f64>() / eth_prices.len() as f64
    };

    let final_btc = if btc_prices.is_empty() {
        if is_production_level {
            println!("🛑 PRODUCTION: All BTC oracle APIs failed — rejecting (fail-closed)");
            0.0 // Fail-closed
        } else {
            println!("⚠️ Oracle: No BTC prices from APIs, using testnet fallback $83000");
            83000.0
        }
    } else {
        btc_prices.iter().sum::<f64>() / btc_prices.len() as f64
    };

    // SECURITY FIX #15: Sanity bounds to reject manipulated oracle prices
    // ETH reasonable range: $10 - $100,000 | BTC reasonable range: $100 - $10,000,000
    let final_eth = if !(10.0..=100_000.0).contains(&final_eth) {
        if is_production_level || final_eth == 0.0 {
            println!(
                "🛑 Oracle ETH price ${:.2} out of sanity bounds — fail-closed",
                final_eth
            );
            0.0
        } else {
            println!(
                "⚠️ Oracle ETH price ${:.2} out of sanity bounds, using fallback $2500",
                final_eth
            );
            2500.0
        }
    } else {
        final_eth
    };

    let final_btc = if !(100.0..=10_000_000.0).contains(&final_btc) {
        if is_production_level || final_btc == 0.0 {
            println!(
                "🛑 Oracle BTC price ${:.2} out of sanity bounds — fail-closed",
                final_btc
            );
            0.0
        } else {
            println!(
                "⚠️ Oracle BTC price ${:.2} out of sanity bounds, using fallback $83000",
                final_btc
            );
            83000.0
        }
    } else {
        final_btc
    };

    // Show successful source count (for debugging)
    println!(
        "📊 Oracle Consensus ({} APIs): ETH ${:.2}, BTC ${:.2}",
        eth_prices.len(),
        format_u128(final_eth as u128),
        format_u128(final_btc as u128)
    );

    (final_eth, final_btc)
}

async fn verify_eth_burn_tx(txid: &str) -> Option<f64> {
    // Functional Testnet: Accept any valid format TXID and mock burn amount
    if !testnet_config::get_testnet_config().should_enable_oracle_consensus() {
        let clean_txid = txid.trim().trim_start_matches("0x").to_lowercase();
        if clean_txid.len() == 64 && clean_txid.chars().all(|c| c.is_ascii_hexdigit()) {
            println!(
                "🧪 TESTNET (Functional): Accepting ETH TXID {} with mock amount 0.01 ETH",
                &clean_txid[..16]
            );
            return Some(0.01); // Mock 0.01 ETH burn (~30 UAT, within anti-whale limit)
        }
        return None;
    }

    let clean_txid = txid.trim().trim_start_matches("0x").to_lowercase();
    let url = format!("https://api.blockcypher.com/v1/eth/main/txs/{}", clean_txid);
    // SECURITY: Route through SOCKS5 proxy (Tor) to prevent IP leak
    let proxy_url = std::env::var("UAT_SOCKS5_PROXY").unwrap_or_default();
    let mut builder = reqwest::Client::builder().timeout(Duration::from_secs(10));
    if !proxy_url.is_empty() {
        if let Ok(proxy) = reqwest::Proxy::all(&proxy_url) {
            builder = builder.proxy(proxy);
        }
    }
    let client = builder.build().ok()?;
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
    // Functional Testnet: Accept any valid format TXID and mock burn amount
    if !testnet_config::get_testnet_config().should_enable_oracle_consensus() {
        let clean_txid = txid.trim().to_lowercase();
        if clean_txid.len() == 64 && clean_txid.chars().all(|c| c.is_ascii_hexdigit()) {
            println!(
                "🧪 TESTNET (Functional): Accepting BTC TXID {} with mock amount 0.001 BTC",
                &clean_txid[..16]
            );
            return Some(0.001); // Mock 0.001 BTC burn (~69 UAT, within anti-whale limit)
        }
        return None;
    }

    let url = format!("https://mempool.space/api/tx/{}", txid.trim());
    // SECURITY: Route through SOCKS5 proxy (Tor) to prevent IP leak
    let proxy_url = std::env::var("UAT_SOCKS5_PROXY").unwrap_or_default();
    let mut builder = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .timeout(Duration::from_secs(10));
    if !proxy_url.is_empty() {
        if let Ok(proxy) = reqwest::Proxy::all(&proxy_url) {
            builder = builder.proxy(proxy);
        }
    }
    let client = builder.build().ok()?;
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
    if full_addr.len() < 12 {
        return full_addr.to_string();
    }
    format!("uat_{}", &full_addr[..8])
}

/// SECURITY FIX #11: Format VOID balance as precise UAT string
/// Prevents integer division hiding sub-UAT amounts (e.g., 0.5 UAT → "0" with integer division)
fn format_balance_precise(void_amount: u128) -> String {
    format!(
        "{}.{:011}",
        void_amount / VOID_PER_UAT,
        void_amount % VOID_PER_UAT
    )
}

/// SECURITY FIX NEW#3: Convert f64 burn amount + price to VOID using integer math.
/// Single f64→u128 conversions have negligible error (~10^-15 relative).
/// Compounding multiple f64 multiplications is where precision loss occurs,
/// so we convert each f64 to integer base units FIRST, then multiply as u128.
/// FIX C11-C2: Returns Result to prevent silent fund loss on overflow.
fn calculate_mint_void(amt_coin: f64, price_usd: f64, symbol: &str) -> Result<u128, String> {
    // Convert coin amount to its smallest integer unit (single f64→u128, safe)
    let (amt_base, base_divisor): (u128, u128) = if symbol == "ETH" {
        ((amt_coin * 1e18).round() as u128, 1_000_000_000_000_000_000) // wei
    } else {
        ((amt_coin * 1e8).round() as u128, 100_000_000) // satoshi
    };
    // Convert price to micro-USD (6 decimal places, single f64→u128, safe)
    let price_micro: u128 = (price_usd * 1_000_000.0).round() as u128;

    // Integer math: usd_micro = (amt_base * price_micro) / base_divisor
    let usd_micro = amt_base
        .checked_mul(price_micro)
        .ok_or_else(|| "Overflow: burn value × price exceeds calculation range".to_string())?
        / base_divisor;

    // 1 UAT = $0.01 = 10,000 micro-USD
    // void = usd_micro * VOID_PER_UAT / 10,000
    let result = usd_micro
        .checked_mul(VOID_PER_UAT)
        .ok_or_else(|| "Overflow: mint amount exceeds u128".to_string())?
        / 10_000;
    Ok(result)
}

fn format_u128(n: u128) -> String {
    let s = n.to_string();
    if s.len() > 3 {
        let mut result = String::new();
        for (count, c) in s.chars().rev().enumerate() {
            if count > 0 && count % 3 == 0 {
                result.push('.');
            }
            result.push(c);
        }
        result.chars().rev().collect()
    } else {
        s
    }
}

// DEPRECATED: Old JSON-based save (kept for emergency backup)
#[allow(dead_code)]
fn save_to_disk_legacy(ledger: &Ledger) {
    if let Ok(data) = serde_json::to_string_pretty(ledger) {
        let _ = fs::write(LEDGER_FILE, &data);
        let _ = fs::create_dir_all("backups");
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let backup_path = format!("backups/ledger_{}.json", ts % 100);
        let _ = fs::write(backup_path, data);
    }
}

// NEW: Database-based save (ACID-compliant) with race condition protection
#[allow(dead_code)]
fn save_to_disk(ledger: &Ledger, db: &UatDatabase) {
    save_to_disk_internal(ledger, db, false);
}

// Internal save with force option
fn save_to_disk_internal(ledger: &Ledger, db: &UatDatabase, force: bool) {
    // Atomic check-and-set: prevents race condition where two tasks both pass the check
    if !force {
        if SAVE_IN_PROGRESS
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::Relaxed)
            .is_err()
        {
            // Another task is already saving — mark dirty so it will be retried
            SAVE_DIRTY.store(true, Ordering::Relaxed);
            return;
        }
    } else {
        SAVE_IN_PROGRESS.store(true, Ordering::SeqCst);
    }

    if let Err(e) = db.save_ledger(ledger) {
        eprintln!("❌ Database save failed: {}", e);
        // Fallback to JSON backup
        save_to_disk_legacy(ledger);
    }

    SAVE_IN_PROGRESS.store(false, Ordering::SeqCst);
    SAVE_DIRTY.store(false, Ordering::Relaxed);
}

// NEW: Load from database with JSON migration
fn load_from_disk(db: &UatDatabase) -> Ledger {
    // Try loading from database first
    if !db.is_empty() {
        match db.load_ledger() {
            Ok(ledger) => {
                println!("✅ Loaded ledger from database");
                return ledger;
            }
            Err(e) => {
                eprintln!("⚠️  Database load failed: {}", e);
            }
        }
    }

    // One-time migration: if legacy JSON file exists, migrate to DB then remove
    if std::path::Path::new(LEDGER_FILE).exists() {
        if let Ok(data) = fs::read_to_string(LEDGER_FILE) {
            if let Ok(ledger) = serde_json::from_str::<Ledger>(&data) {
                println!("📦 Migrating legacy JSON to database...");
                if let Err(e) = db.save_ledger(&ledger) {
                    eprintln!("❌ Migration failed: {}", e);
                } else {
                    println!(
                        "✅ Migration complete: {} accounts, {} blocks",
                        ledger.accounts.len(),
                        ledger.blocks.len()
                    );
                    let _ = fs::rename(LEDGER_FILE, format!("{}.migrated", LEDGER_FILE));
                }
                return ledger;
            }
        }
    }

    println!("🆕 Creating new ledger");
    Ledger::new()
}

/// Maximum PoW iterations before giving up (safety limit)
/// 16 zero bits should typically be found within ~200k attempts
const MAX_POW_ITERATIONS: u64 = 10_000_000;

fn solve_pow(block: &mut uat_core::Block) {
    println!(
        "⏳ Calculating PoW (Anti-Spam: 16 zero bits, limit: {}M iterations)...",
        MAX_POW_ITERATIONS / 1_000_000
    );
    let mut nonce: u64 = 0;
    loop {
        block.work = nonce;

        // Show progress every 100k attempts
        if nonce.is_multiple_of(100_000) && nonce > 0 {
            println!("   ... trying nonce #{}", nonce);
        }

        // Use the same validation logic as process_block (16 leading zero bits)
        if block.verify_pow() {
            break;
        }
        nonce += 1;

        // Safety limit: prevent infinite loop on malformed blocks
        if nonce >= MAX_POW_ITERATIONS {
            eprintln!(
                "⚠️ PoW safety limit reached ({} iterations). Using best nonce found.",
                MAX_POW_ITERATIONS
            );
            break;
        }
    }
    if nonce < MAX_POW_ITERATIONS {
        println!("✅ PoW found in {} iterations", nonce);
    }
}

// --- VISUALIZATION ---

fn print_history_table(blocks: Vec<&Block>) {
    println!("\n📜 TRANSACTION HISTORY (Newest -> Oldest)");
    println!(
        "+----------------+----------------+--------------------------+------------------------+"
    );
    println!(
        "| {:<14} | {:<14} | {:<24} | {:<22} |",
        "TYPE", "AMOUNT (UAT)", "DETAIL / LINK", "HASH"
    );
    println!(
        "+----------------+----------------+--------------------------+------------------------+"
    );

    for b in blocks {
        let amount_uat = b.amount / VOID_PER_UAT;
        let amt_str = format_u128(amount_uat);

        let (type_str, amt_display, info) = match b.block_type {
            BlockType::Mint => (
                "🔥 MINT",
                format!("+{}", amt_str),
                format!("Src: {}", &b.link[..10.min(b.link.len())]),
            ),
            BlockType::Send => (
                "📤 SEND",
                format!("-{}", amt_str),
                format!("To: {}", get_short_addr(&b.link)),
            ),
            BlockType::Receive => (
                "📥 RECEIVE",
                format!("+{}", amt_str),
                format!("From Hash: {}", &b.link[..8.min(b.link.len())]),
            ),
            BlockType::Change => (
                "🔄 CHANGE",
                "0".to_string(),
                format!("Rep: {}", get_short_addr(&b.link)),
            ),
            BlockType::Slash => (
                "⚖️ SLASH",
                format!("-{}", amt_str),
                format!("Evidence: {}", &b.link[..10.min(b.link.len())]),
            ),
        };

        let hash_short = if b.calculate_hash().len() > 8 {
            format!("...{}", &b.calculate_hash()[..8])
        } else {
            "-".to_string()
        };

        println!(
            "| {:<14} | {:<14} | {:<24} | {:<22} |",
            type_str, amt_display, info, hash_short
        );
    }
    println!(
        "+----------------+----------------+--------------------------+------------------------+\n"
    );
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // --- 1. LOGIKA PORT DINAMIS ---
    // Parse command line arguments
    let args: Vec<String> = std::env::args().collect();

    // Extended CLI arguments for Flutter Validator launcher
    let mut api_port: u16 = 3030;
    let mut data_dir_override: Option<String> = None;
    let mut node_id_override: Option<String> = None;
    let mut json_log = false; // Machine-readable logs for Flutter

    {
        let mut i = 1;
        while i < args.len() {
            match args[i].as_str() {
                "--port" => {
                    if let Some(v) = args.get(i + 1) {
                        api_port = v.parse().unwrap_or(3030);
                        i += 1;
                    }
                }
                "--data-dir" => {
                    if let Some(v) = args.get(i + 1) {
                        data_dir_override = Some(v.clone());
                        i += 1;
                    }
                }
                "--node-id" => {
                    if let Some(v) = args.get(i + 1) {
                        node_id_override = Some(v.clone());
                        i += 1;
                    }
                }
                "--json-log" => {
                    json_log = true;
                }
                "--config" => {
                    // Legacy: load from validator.toml
                    if let Some(config_path) = args.get(i + 1) {
                        if let Ok(config_content) = fs::read_to_string(config_path) {
                            if let Some(line) = config_content
                                .lines()
                                .find(|l| l.trim().starts_with("rest_port"))
                            {
                                if let Some(port_str) = line.split('=').nth(1) {
                                    api_port = port_str.trim().parse().unwrap_or(3030);
                                }
                            }
                        }
                        i += 1;
                    }
                }
                _ => {
                    // Legacy: bare port number as first arg
                    if i == 1 {
                        if let Ok(p) = args[i].parse::<u16>() {
                            api_port = p;
                        }
                    }
                }
            }
            i += 1;
        }
    }

    // When launched from Flutter (--json-log), stdout is a pipe (fully buffered).
    // Force line-buffering so JSON events and println! output reach Flutter immediately.
    if json_log {
        use std::io::Write;
        // Flush any pending output, then we rely on explicit flushes in json_event!
        let _ = std::io::stdout().flush();
    }

    // Structured JSON log helper for Flutter process monitoring
    // NOTE: Must flush stdout — when spawned from Flutter, stdout is a pipe
    // (fully buffered), not a TTY (line-buffered). Without flush, JSON events
    // never reach the Flutter process monitor.
    macro_rules! json_event {
        ($event:expr, $($key:expr => $val:expr),*) => {
            if json_log {
                let mut _j = serde_json::json!({"event": $event});
                $(_j[$key] = serde_json::json!($val);)*
                println!("{}", _j);
                use std::io::Write;
                let _ = std::io::stdout().flush();
            }
        };
    }

    // --- NEW: INITIALIZE DATABASE ---
    println!("🗄️  Initializing database...");
    // AUTO-DETECT NODE ID from override, env var, or port
    // TESTNET ONLY: Port-to-name mapping is a development convenience.
    // MAINNET: Validators are identified by their public key/address, not port.
    let node_id = node_id_override.unwrap_or_else(|| {
        std::env::var("UAT_NODE_ID").unwrap_or_else(|_| {
            if uat_core::is_testnet_build() {
                match api_port {
                    3030 => "validator-1".to_string(),
                    3031 => "validator-2".to_string(),
                    3032 => "validator-3".to_string(),
                    _ => format!("node-{}", api_port),
                }
            } else {
                format!("node-{}", api_port)
            }
        })
    });

    // Data directory: --data-dir override, or default node_data/<id>/
    let base_data_dir = data_dir_override.unwrap_or_else(|| format!("node_data/{}", node_id));

    println!("🆔 Node ID: {}", node_id);
    println!("📂 Data directory: {}/", base_data_dir);
    json_event!("init", "node_id" => &node_id, "data_dir" => &base_data_dir, "port" => api_port);

    // Create node-specific database path (CRITICAL: Multi-node isolation)
    let db_path = format!("{}/uat_database", base_data_dir);
    std::fs::create_dir_all(&base_data_dir)?;

    let database = match UatDatabase::open(&db_path) {
        Ok(db) => {
            let stats = db.stats();
            println!("✅ Database opened: {}", db_path);
            println!(
                "   {} blocks, {} accounts, {:.2} MB on disk",
                stats.blocks_count,
                stats.accounts_count,
                stats.size_on_disk as f64 / 1_048_576.0
            );
            Arc::new(db)
        }
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
        }
        Err(e) => {
            eprintln!("❌ Failed to initialize metrics: {}", e);
            return Err(e);
        }
    };

    // Use node-specific wallet file path
    // SECURITY: Wallet keys are encrypted at rest using age encryption.
    // The encryption password is derived from the node ID (for automated startup).
    // MAINNET: operators MUST set UAT_WALLET_PASSWORD — weak auto-key is rejected.
    let wallet_path = format!("{}/wallet.json", &base_data_dir);
    let wallet_password = match std::env::var("UAT_WALLET_PASSWORD") {
        Ok(pw) if pw.len() >= 12 => pw,
        Ok(pw) if !pw.is_empty() => {
            if uat_core::is_mainnet_build() {
                eprintln!(
                    "❌ FATAL: UAT_WALLET_PASSWORD must be at least 12 characters on mainnet."
                );
                return Err(Box::<dyn std::error::Error>::from(
                    "UAT_WALLET_PASSWORD too short for mainnet (min 12 chars)",
                ));
            }
            pw // Testnet: allow shorter passwords
        }
        _ => {
            if uat_core::is_mainnet_build() {
                eprintln!(
                    "❌ FATAL: UAT_WALLET_PASSWORD environment variable is REQUIRED on mainnet."
                );
                eprintln!("   export UAT_WALLET_PASSWORD='<strong-password-here>'");
                return Err(Box::<dyn std::error::Error>::from(
                    "UAT_WALLET_PASSWORD required for mainnet build",
                ));
            }
            // Testnet: auto-generate weak password (acceptable for testing)
            let auto = format!("uat-node-{}-autokey", &node_id);
            println!("⚠️  Using auto-generated wallet password (testnet only)");
            auto
        }
    };
    let keys: uat_crypto::KeyPair = if let Ok(data) = fs::read_to_string(&wallet_path) {
        // Try parsing as encrypted key first, fall back to legacy plaintext
        if let Ok(encrypted) = serde_json::from_str::<uat_crypto::EncryptedKey>(&data) {
            let sk =
                uat_crypto::decrypt_private_key(&encrypted, &wallet_password).map_err(|e| {
                    Box::<dyn std::error::Error>::from(format!(
                        "Wallet decrypt failed: {}. Set UAT_WALLET_PASSWORD if changed.",
                        e
                    ))
                })?;
            uat_crypto::KeyPair {
                public_key: encrypted.public_key,
                secret_key: sk,
            }
        } else if let Ok(plain_key) = serde_json::from_str::<uat_crypto::KeyPair>(&data) {
            // Legacy plaintext wallet — auto-migrate to encrypted
            eprintln!("⚠️  Migrating plaintext wallet to encrypted format...");
            let encrypted = uat_crypto::migrate_to_encrypted(&plain_key, &wallet_password)
                .map_err(|e| {
                    Box::<dyn std::error::Error>::from(format!("Migration failed: {}", e))
                })?;
            fs::write(&wallet_path, serde_json::to_string(&encrypted)?)?;
            println!("🔒 Wallet migrated to encrypted storage");
            plain_key
        } else {
            return Err(Box::from(
                "Failed to parse wallet file — corrupted or invalid format",
            ));
        }
    } else {
        let new_k = uat_crypto::generate_keypair();
        fs::create_dir_all(&base_data_dir)?;
        // Store encrypted from the start
        let encrypted = uat_crypto::migrate_to_encrypted(&new_k, &wallet_password)
            .map_err(|e| Box::<dyn std::error::Error>::from(format!("Encryption failed: {}", e)))?;
        fs::write(&wallet_path, serde_json::to_string(&encrypted)?)?;
        println!("🔑 Generated new encrypted keypair for {}", node_id);
        new_k
    };

    let my_address = uat_crypto::public_key_to_address(&keys.public_key);
    let my_short = get_short_addr(&my_address);
    let secret_key = keys.secret_key.clone();
    json_event!("wallet_ready", "address" => &my_address, "short" => &my_short);

    // FIX: Load ledger and genesis BEFORE wrapping in Arc to prevent race condition
    let mut ledger_state = load_from_disk(&database);

    // ══════════════════════════════════════════════════════════════════════
    // GENESIS LOADING — Network-aware with validation
    // ══════════════════════════════════════════════════════════════════════
    //
    // Mainnet:  Loads from genesis_config.json (gitignored, contains real keys)
    //           MUST exist and pass full validation. Node refuses to start without it.
    //           Validates: total_supply=21936236, address format, network="mainnet".
    //
    // Testnet:  Loads from testnet-genesis/testnet_wallets.json (git-tracked, test keys)
    //           Falls back gracefully if missing.
    //
    // Both paths use the same insert-if-absent logic to preserve existing state.
    //
    // bootstrap_validators: Populated from genesis — used by /validators and /node-info
    // to avoid hardcoding testnet-specific addresses that would break mainnet.
    let mut bootstrap_validators: Vec<String> = Vec::new();
    {
        let genesis_path = if uat_core::is_mainnet_build() {
            "genesis_config.json"
        } else {
            "testnet-genesis/testnet_wallets.json"
        };

        // MAINNET: genesis_config.json is REQUIRED — refuse to start without it
        if uat_core::is_mainnet_build() && !std::path::Path::new(genesis_path).exists() {
            eprintln!("❌ FATAL: genesis_config.json not found!");
            eprintln!("   Mainnet requires genesis_config.json at the working directory root.");
            eprintln!("   Generate with: cargo run -p genesis --bin genesis");
            return Err(Box::<dyn std::error::Error>::from(
                "Missing genesis_config.json for mainnet build",
            ));
        }

        if std::path::Path::new(genesis_path).exists() {
            if let Ok(genesis_json) = std::fs::read_to_string(genesis_path) {
                // Mainnet: use validated GenesisConfig parser
                // Testnet: use the raw JSON wallets parser (legacy format)
                if uat_core::is_mainnet_build() {
                    // SECURITY FIX: Validate genesis config BEFORE loading accounts.
                    // Prevents tampered genesis files from silently loading invalid state.
                    {
                        let genesis_config: genesis::GenesisConfig =
                            serde_json::from_str(&genesis_json)
                                .map_err(|e| {
                                    format!("Failed to parse genesis JSON for validation: {}", e)
                                })
                                .unwrap_or_else(|e| {
                                    eprintln!("❌ FATAL: {}", e);
                                    std::process::exit(1);
                                });
                        if let Err(e) = genesis::validate_genesis(&genesis_config) {
                            eprintln!("❌ FATAL: Genesis validation failed: {}", e);
                            return Err(Box::<dyn std::error::Error>::from(format!(
                                "Genesis validation failed: {}",
                                e
                            )));
                        }
                        // Extract bootstrap validator addresses from genesis config
                        if let Some(ref nodes) = genesis_config.bootstrap_nodes {
                            for node in nodes {
                                bootstrap_validators.push(node.address.clone());
                            }
                            println!(
                                "🔍 Loaded {} bootstrap validators from genesis",
                                bootstrap_validators.len()
                            );
                        }
                        println!("✅ Genesis config validated (supply, network, addresses)");
                    }
                    match genesis::load_genesis_from_file(genesis_path) {
                        Ok(accounts) => {
                            let mut loaded_count = 0;
                            let mut genesis_supply_deducted: u128 = 0;
                            for (address, state) in accounts {
                                if state.balance > 0
                                    && !ledger_state.accounts.contains_key(&address)
                                {
                                    genesis_supply_deducted += state.balance;
                                    ledger_state.accounts.insert(address, state);
                                    loaded_count += 1;
                                }
                            }
                            if loaded_count > 0 {
                                // NOTE: remaining_supply starts at PUBLIC_SUPPLY_CAP (20,400,700 UAT)
                                // which already EXCLUDES the dev allocation (7%). Dev wallets are
                                // a separate pre-genesis allocation, NOT minted from the PoB pool.
                                // Do NOT deduct genesis wallets from remaining_supply.
                                save_to_disk_internal(&ledger_state, &database, true);
                                println!(
                                    "🏦 MAINNET genesis: loaded {} accounts ({} VOID pre-allocated)",
                                    loaded_count, genesis_supply_deducted
                                );
                            }
                        }
                        Err(e) => {
                            eprintln!("❌ FATAL: Invalid genesis_config.json: {}", e);
                            return Err(Box::<dyn std::error::Error>::from(format!(
                                "Invalid genesis config: {}",
                                e
                            )));
                        }
                    }
                } else {
                    // Testnet: raw JSON with "wallets" array (legacy format)
                    if let Ok(genesis_data) =
                        serde_json::from_str::<serde_json::Value>(&genesis_json)
                    {
                        if let Some(wallets) = genesis_data["wallets"].as_array() {
                            let mut loaded_count = 0;
                            let mut genesis_supply_deducted: u128 = 0;

                            for wallet in wallets {
                                // FIX C1: Support both "balance_uat" and "genesis_balance_uat" field names
                                // testnet_wallets.json uses "genesis_balance_uat", mainnet uses "balance_uat"
                                let balance_str_opt = wallet["balance_uat"]
                                    .as_str()
                                    .or_else(|| wallet["genesis_balance_uat"].as_str());
                                if let (Some(address), Some(balance_str)) =
                                    (wallet["address"].as_str(), balance_str_opt)
                                {
                                    // FIX C11-C02: Validate testnet genesis wallet entries
                                    if !address.starts_with("UAT") || address.len() < 10 {
                                        eprintln!("⚠️ Testnet genesis: skipping invalid address format: {}", address);
                                        continue;
                                    }
                                    let balance_voi =
                                        genesis::parse_uat_to_void(balance_str).unwrap_or(0);
                                    if balance_voi == 0 {
                                        eprintln!("⚠️ Testnet genesis: skipping zero/invalid balance for {}", address);
                                        continue;
                                    }
                                    // Sanity: no single wallet should exceed total supply
                                    if balance_voi > 21_936_236u128 * VOID_PER_UAT {
                                        eprintln!("⚠️ Testnet genesis: skipping wallet {} (balance exceeds total supply)", address);
                                        continue;
                                    }
                                    // Track validator wallets for /validators endpoint
                                    // Detect by wallet_type field (testnet uses "BootstrapNode(N)")
                                    // or role field (mainnet uses "validator")
                                    let is_validator = wallet["wallet_type"]
                                        .as_str()
                                        .map(|wt| wt.starts_with("BootstrapNode"))
                                        .unwrap_or(false)
                                        || wallet["role"].as_str() == Some("validator");
                                    if is_validator {
                                        bootstrap_validators.push(address.to_string());
                                    }
                                    if !ledger_state.accounts.contains_key(address) {
                                        ledger_state.accounts.insert(
                                            address.to_string(),
                                            AccountState {
                                                head: "0".to_string(),
                                                balance: balance_voi,
                                                block_count: 0,
                                                is_validator,
                                            },
                                        );
                                        genesis_supply_deducted += balance_voi;
                                        loaded_count += 1;
                                    }
                                }
                            }

                            if loaded_count > 0 {
                                // FIX C11-L14: Validate aggregate balance doesn't exceed total supply
                                let max_supply_void = 21_936_236u128 * VOID_PER_UAT;
                                if genesis_supply_deducted > max_supply_void {
                                    eprintln!("❌ FATAL: Testnet genesis aggregate balance ({} VOID) exceeds total supply ({} VOID)",
                                        genesis_supply_deducted, max_supply_void);
                                    return Err(Box::<dyn std::error::Error>::from(
                                        "Testnet genesis aggregate balance exceeds total supply",
                                    ));
                                }
                                // NOTE: remaining_supply = PUBLIC_SUPPLY_CAP already excludes
                                // dev allocation. Genesis wallets are pre-allocated, not PoB-minted.
                                save_to_disk_internal(&ledger_state, &database, true);
                                println!(
                                    "🎁 Testnet genesis: loaded {} accounts ({} VOID pre-allocated)",
                                    loaded_count, genesis_supply_deducted
                                );
                                if !bootstrap_validators.is_empty() {
                                    println!(
                                        "🔍 Loaded {} bootstrap validators from testnet genesis",
                                        bootstrap_validators.len()
                                    );
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // VALIDATOR REWARD POOL — Initialize and register known validators
    // ══════════════════════════════════════════════════════════════════════
    // Uses genesis_timestamp from genesis_config.json (mainnet) or hardcoded (testnet).
    // Bootstrap validators are registered as is_genesis=true (excluded from rewards).
    // Pool is initialized from VALIDATOR_REWARD_POOL_VOID constant.
    let genesis_ts: u64 = if uat_core::is_mainnet_build() {
        // Re-parse genesis config for timestamp (lightweight — already validated above)
        std::fs::read_to_string("genesis_config.json")
            .ok()
            .and_then(|json| serde_json::from_str::<serde_json::Value>(&json).ok())
            .and_then(|v| v["genesis_timestamp"].as_u64())
            .unwrap_or(1_770_580_908)
    } else {
        1_770_580_908 // Testnet: hardcoded genesis timestamp
    };
    let mut reward_pool_state = ValidatorRewardPool::new(genesis_ts);

    // Register all bootstrap validators as genesis (excluded from rewards)
    for addr in &bootstrap_validators {
        let stake = ledger_state
            .accounts
            .get(addr)
            .map(|a| a.balance)
            .unwrap_or(0);
        reward_pool_state.register_validator(addr, true, stake);
    }

    // Register any other validators already in the ledger (non-genesis)
    for (addr, acct) in &ledger_state.accounts {
        if acct.is_validator && !bootstrap_validators.contains(addr) {
            reward_pool_state.register_validator(addr, false, acct.balance);
        }
    }

    // Set expected heartbeats for the first epoch (60-second heartbeat interval)
    reward_pool_state.set_expected_heartbeats(60);

    let reward_pool = Arc::new(Mutex::new(reward_pool_state));
    println!(
        "🏆 Validator reward pool initialized: {} UAT, epoch rate {} UAT/month",
        uat_core::VALIDATOR_REWARD_POOL_VOID / VOID_PER_UAT,
        uat_core::REWARD_RATE_INITIAL_VOID / VOID_PER_UAT
    );

    // Now wrap in Arc after all initialization is complete
    let ledger = Arc::new(Mutex::new(ledger_state));

    // Load persistent peer storage from database
    let initial_peers = match database.load_peers() {
        Ok(peers) => {
            if !peers.is_empty() {
                println!("📚 Loaded {} known peers from database", peers.len());
            }
            peers
        }
        Err(e) => {
            eprintln!("⚠️ Failed to load peers: {}", e);
            HashMap::new()
        }
    };
    let address_book = Arc::new(Mutex::new(initial_peers));

    let pending_burns = Arc::new(Mutex::new(HashMap::<
        String,
        (f64, f64, String, u128, u64, String),
    >::new()));

    let pending_sends = Arc::new(Mutex::new(HashMap::<String, (Block, u128)>::new()));

    // SECURITY FIX: Vote deduplication — track which validators have already voted
    // Prevents a single validator from reaching consensus alone by sending multiple votes
    let burn_voters = Arc::new(Mutex::new(HashMap::<String, HashSet<String>>::new()));
    let send_voters = Arc::new(Mutex::new(HashMap::<String, HashSet<String>>::new()));

    // NEW: Oracle Consensus (decentralized median pricing)
    let oracle_consensus = Arc::new(Mutex::new(OracleConsensus::new()));

    // NEW: Slashing Manager (validator accountability)
    let slashing_manager = Arc::new(Mutex::new(SlashingManager::new()));
    // Register existing validators from genesis (only accounts with is_validator flag)
    {
        let l = safe_lock(&ledger);
        let mut sm = safe_lock(&slashing_manager);
        for (addr, acc) in &l.accounts {
            if acc.is_validator {
                sm.register_validator(addr.clone());
            }
        }
        let registered = sm.get_safety_stats().total_validators;
        if registered > 0 {
            println!(
                "🛡️  SlashingManager: {} validators registered from genesis",
                registered
            );
        }
    }

    // NEW: Anti-Whale Engine (dynamic fee scaling + burn limits)
    let anti_whale_config = AntiWhaleConfig::new();
    let anti_whale = Arc::new(Mutex::new(AntiWhaleEngine::new(anti_whale_config)));
    {
        let aw = safe_lock(&anti_whale);
        println!(
            "🐋 Anti-Whale Engine initialized (max {} tx/block, max {} UAT burn/block)",
            aw.config.max_tx_per_block, aw.config.max_burn_per_block
        );
    }

    // NEW: Finality Checkpoint Manager (prevents long-range attacks)
    let checkpoint_db_path = format!("node_data/{}/checkpoints", node_id);
    let checkpoint_manager = match CheckpointManager::new(&checkpoint_db_path) {
        Ok(cm) => {
            let latest = cm.get_latest_checkpoint().ok().flatten();
            if let Some(cp) = &latest {
                println!(
                    "🏁 CheckpointManager: resuming from checkpoint at height {}",
                    cp.height
                );
            } else {
                println!(
                    "🏁 CheckpointManager: no checkpoints yet (will create every {} blocks)",
                    CHECKPOINT_INTERVAL
                );
            }
            Arc::new(Mutex::new(cm))
        }
        Err(e) => {
            eprintln!(
                "⚠️ Failed to open checkpoint DB: {} — continuing without checkpoints",
                e
            );
            // Create a fallback checkpoint manager with temp path
            let fallback_path = format!("node_data/{}/checkpoints_fallback", node_id);
            Arc::new(Mutex::new(
                CheckpointManager::new(&fallback_path).expect("Fallback checkpoint DB must work"),
            ))
        }
    };

    // Init own account in ledger if not exists
    {
        let mut l = safe_lock(&ledger);
        if !l.accounts.contains_key(&my_address) {
            if !testnet_config::get_testnet_config().should_enable_consensus() {
                // SECURITY FIX #7: Create proper Mint block for testnet initial balance
                // This deducts from distribution.remaining_supply (no free money)
                l.accounts.insert(
                    my_address.clone(),
                    AccountState {
                        head: "0".to_string(),
                        balance: 0,
                        block_count: 0,
                        is_validator: false,
                    },
                );

                let mut init_block = Block {
                    account: my_address.clone(),
                    previous: "0".to_string(),
                    block_type: BlockType::Mint,
                    amount: TESTNET_INITIAL_BALANCE,
                    link: format!(
                        "TESTNET:INITIAL:{}",
                        std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap_or_default()
                            .as_secs()
                    ),
                    signature: "".to_string(),
                    public_key: hex::encode(&keys.public_key),
                    work: 0,
                    timestamp: std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs(),
                    fee: 0,
                };

                solve_pow(&mut init_block);
                init_block.signature = hex::encode(
                    uat_crypto::sign_message(init_block.signing_hash().as_bytes(), &secret_key)
                        .expect("BUG: signing failed — key corrupted"),
                );

                match l.process_block(&init_block) {
                    Ok(_) => {
                        SAVE_DIRTY.store(true, Ordering::Relaxed);
                        println!("🎁 TESTNET (Functional): Node initialized with 1000 UAT via Mint block (supply deducted)");
                    }
                    Err(e) => {
                        println!(
                            "⚠️ TESTNET initial mint failed: {} — creating empty account",
                            e
                        );
                    }
                }
            } else {
                // Production: Create empty account (balance from Proof-of-Burn only)
                l.accounts.insert(
                    my_address.clone(),
                    AccountState {
                        head: "0".to_string(),
                        balance: 0,
                        block_count: 0,
                        is_validator: false,
                    },
                );
            }
        }
    }

    // FIX: Background task for debounced disk saves (prevents race conditions)
    // SECURITY FIX #15: Clone ledger snapshot THEN release lock BEFORE disk I/O
    let save_ledger = Arc::clone(&ledger);
    let save_database = Arc::clone(&database);
    let save_checkpoint_mgr = Arc::clone(&checkpoint_manager);
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(5));
        loop {
            interval.tick().await;

            // Only save if dirty and not currently saving
            if SAVE_DIRTY.load(Ordering::Relaxed) && !SAVE_IN_PROGRESS.load(Ordering::Relaxed) {
                // Clone ledger under lock, then release lock BEFORE disk I/O
                let (ledger_snapshot, block_count, validator_count) = {
                    let l = safe_lock(&save_ledger);
                    let bc = l.blocks.len() as u64;
                    let vc = l
                        .accounts
                        .iter()
                        .filter(|(_, a)| a.balance >= MIN_VALIDATOR_STAKE_VOID)
                        .count() as u32;
                    (l.clone(), bc, vc)
                }; // Lock released — API requests can proceed during save
                save_to_disk_internal(&ledger_snapshot, &save_database, false);

                // CHECKPOINT: Create finality checkpoint when block_count crosses next interval
                // FIX: Use >= instead of == to handle block-lattice where exact multiples may be skipped
                if block_count > 0 {
                    let mut cm = safe_lock(&save_checkpoint_mgr);
                    let latest_height = cm
                        .get_latest_checkpoint()
                        .ok()
                        .flatten()
                        .map(|cp| cp.height)
                        .unwrap_or(0);
                    let next_checkpoint =
                        ((latest_height / CHECKPOINT_INTERVAL) + 1) * CHECKPOINT_INTERVAL;

                    if block_count >= next_checkpoint {
                        // FIX P0-3: Snap block_count DOWN to aligned interval.
                        // In a block-lattice, block_count rarely lands exactly on a
                        // multiple of CHECKPOINT_INTERVAL. Without snapping, every
                        // checkpoint was silently rejected by is_valid_interval().
                        let checkpoint_height =
                            (block_count / CHECKPOINT_INTERVAL) * CHECKPOINT_INTERVAL;

                        // Calculate simple state root from account balances
                        let state_root = {
                            use sha3::{Digest, Keccak256};
                            let mut hasher = Keccak256::new();
                            let mut sorted_accounts: Vec<_> =
                                ledger_snapshot.accounts.iter().collect();
                            sorted_accounts.sort_by(|(a, _), (b, _)| a.cmp(b));
                            for (addr, state) in sorted_accounts {
                                hasher.update(addr.as_bytes());
                                hasher.update(state.balance.to_le_bytes());
                            }
                            hex::encode(hasher.finalize())
                        };

                        // Find latest block hash
                        let latest_block_hash = ledger_snapshot
                            .blocks
                            .values()
                            .max_by_key(|b| b.timestamp)
                            .map(|b| b.calculate_hash())
                            .unwrap_or_else(|| "genesis".to_string());

                        // SECURITY FIX S2: sig_count = 1 (only this node signed).
                        // Previously set to validator_count, falsely claiming full consensus.
                        // Multi-validator checkpoint coordination requires a separate protocol
                        // (future: CHECKPOINT_REQ/CHECKPOINT_RES gossip).
                        // For now, honestly report that only 1 validator signed.
                        let sig_count = 1_u32;
                        let checkpoint = FinalityCheckpoint::new(
                            checkpoint_height,
                            latest_block_hash,
                            validator_count.max(1),
                            state_root,
                            sig_count,
                        );

                        match cm.store_checkpoint(checkpoint) {
                            Ok(()) => println!("🏁 Checkpoint created at height {} (block_count={}, {} validators, sig_count=1/{})",
                                checkpoint_height, block_count, validator_count, validator_count),
                            Err(e) => eprintln!("⚠️ Checkpoint creation failed: {}", e),
                        }
                    }
                }
            }
        }
    });

    // FIX V4#15: Periodic cleanup of stale pending transactions
    // Pending sends/burns older than 5 minutes are removed to prevent memory leaks
    let cleanup_pending_sends = Arc::clone(&pending_sends);
    let cleanup_pending_burns = Arc::clone(&pending_burns);
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(60));
        loop {
            interval.tick().await;
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            const PENDING_TTL_SECS: u64 = 300; // 5 minute TTL for pending transactions

            // Clean stale pending sends
            if let Ok(mut ps) = cleanup_pending_sends.lock() {
                let before = ps.len();
                ps.retain(|_, (block, _)| now.saturating_sub(block.timestamp) < PENDING_TTL_SECS);
                let removed = before - ps.len();
                if removed > 0 {
                    println!(
                        "🧹 Cleaned {} stale pending sends (TTL: {}s)",
                        removed, PENDING_TTL_SECS
                    );
                }
            }

            // Clean stale pending burns by timestamp-based TTL
            // pending_burns: HashMap<txid, (f64_amount, f64_price, String_sym, u128_power, u64_created_at, String_recipient)>
            if let Ok(mut pb) = cleanup_pending_burns.lock() {
                let before = pb.len();
                pb.retain(|_, (_, _, _, _, created_at, _)| {
                    now.saturating_sub(*created_at) < PENDING_TTL_SECS
                });
                let removed = before - pb.len();
                if removed > 0 {
                    println!(
                        "🧹 Cleaned {} stale pending burns (TTL: {}s)",
                        removed, PENDING_TTL_SECS
                    );
                }
            }
        }
    });

    let (tx_out, rx_out) = mpsc::channel(32);
    let (tx_in, mut rx_in) = mpsc::channel(32);

    tokio::spawn(async move {
        let _ = UatNode::start(tx_in, rx_out).await;
    });

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

    let api_slashing = Arc::clone(&slashing_manager);
    let api_aw = Arc::clone(&anti_whale);
    let api_pk = keys.public_key.clone();
    let api_bootstrap = bootstrap_validators; // Move — only used by API server
    let api_reward_pool = Arc::clone(&reward_pool);

    tokio::spawn(async move {
        start_api_server(ApiServerConfig {
            ledger: api_ledger,
            tx_out: api_tx,
            pending_sends: api_pending_sends,
            pending_burns: api_pending_burns,
            address_book: api_address_book,
            my_address: api_addr,
            secret_key: api_key,
            api_port,
            oracle_consensus: api_oracle,
            metrics: api_metrics,
            database: api_database,
            slashing_manager: api_slashing,
            anti_whale: api_aw,
            node_public_key: api_pk,
            bootstrap_validators: api_bootstrap,
            reward_pool: api_reward_pool,
        })
        .await;
    });

    // --- NEW: JALANKAN gRPC SERVER (PRODUCTION READY) ---
    let grpc_ledger = Arc::clone(&ledger);
    let grpc_tx = tx_out.clone();
    let grpc_addr = my_address.clone();
    let grpc_port = api_port + 20000; // Dynamic gRPC port (REST+20000)

    tokio::spawn(async move {
        println!("🔧 Starting gRPC server on port {}...", grpc_port);
        // Flush stdout for pipe-buffered environments (Flutter process monitor)
        {
            use std::io::Write;
            let _ = std::io::stdout().flush();
        }
        if let Err(e) =
            grpc_server::start_grpc_server(grpc_ledger, grpc_addr, grpc_tx, grpc_port).await
        {
            eprintln!("❌ gRPC Server error: {}", e);
        }
    });

    // --- NEW: ORACLE PRICE BROADCASTER (Every 30 seconds) ---
    let oracle_tx = tx_out.clone();
    let oracle_addr = my_address.clone();
    let oracle_ledger = Arc::clone(&ledger);
    let oracle_sk = keys.secret_key.clone();
    let oracle_pk = keys.public_key.clone();

    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(30));
        loop {
            interval.tick().await;

            // Check if node is validator (min 1,000 UAT)
            let is_validator = {
                let l = safe_lock(&oracle_ledger);
                l.accounts
                    .get(&oracle_addr)
                    .map(|acc| acc.balance >= MIN_VALIDATOR_STAKE_VOID)
                    .unwrap_or(false)
            };

            if is_validator {
                // Fetch price from external oracle
                let (eth_price, btc_price) = get_crypto_prices().await;

                // Sign the oracle payload: "addr:eth:btc" with Dilithium5
                let payload = format!("{}:{}:{}", oracle_addr, eth_price, btc_price);
                let sig = match uat_crypto::sign_message(payload.as_bytes(), &oracle_sk) {
                    Ok(s) => hex::encode(s),
                    Err(e) => {
                        eprintln!("❌ Oracle sign error: {:?}", e);
                        continue;
                    }
                };
                let pk_hex = hex::encode(&oracle_pk);

                // Format: ORACLE_SUBMIT:addr:eth:btc:signature:pubkey
                let oracle_msg = format!(
                    "ORACLE_SUBMIT:{}:{}:{}:{}:{}",
                    oracle_addr, eth_price, btc_price, sig, pk_hex
                );
                let _ = oracle_tx.send(oracle_msg).await;

                println!(
                    "📊 Broadcasting signed oracle prices: ETH=${:.2}, BTC=${:.2}",
                    eth_price, btc_price
                );
            }
        }
    });

    // ══════════════════════════════════════════════════════════════════════
    // VALIDATOR REWARD SYSTEM — Heartbeat recording + Epoch distribution
    // ══════════════════════════════════════════════════════════════════════
    // - Records heartbeats every 60s for all known validators
    // - Checks epoch completion and distributes rewards
    // - Credits reward amounts to validator balances in the ledger
    let reward_ledger = Arc::clone(&ledger);
    let reward_pool_bg = Arc::clone(&reward_pool);
    let reward_my_addr = my_address.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(60));
        loop {
            interval.tick().await;

            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();

            let mut pool = safe_lock(&reward_pool_bg);

            // Record heartbeat for this node (proving liveness)
            pool.record_heartbeat(&reward_my_addr);

            // Check if the current epoch has ended
            if pool.is_epoch_complete(now) {
                // Set expected heartbeats before distribution (60s interval)
                pool.set_expected_heartbeats(60);

                // Distribute rewards for the completed epoch
                let rewards = pool.distribute_epoch_rewards();

                if !rewards.is_empty() {
                    // Credit reward amounts to validator balances in the ledger
                    let mut l = safe_lock(&reward_ledger);
                    let mut total_credited: u128 = 0;
                    for (addr, reward_void) in &rewards {
                        if let Some(acct) = l.accounts.get_mut(addr) {
                            acct.balance += reward_void;
                            total_credited += reward_void;
                        }
                    }
                    if total_credited > 0 {
                        SAVE_DIRTY.store(true, Ordering::Relaxed);
                        println!(
                            "🏆 Epoch {} rewards: {} UAT distributed to {} validators",
                            pool.current_epoch.saturating_sub(1),
                            total_credited / VOID_PER_UAT,
                            rewards.len()
                        );
                    }
                } else {
                    println!(
                        "🏆 Epoch {} complete: no eligible validators for rewards",
                        pool.current_epoch.saturating_sub(1)
                    );
                }
            }
        }
    });

    // Bootstrapping
    let tx_boot = tx_out.clone();
    let my_addr_boot = my_address.clone();
    let ledger_boot = Arc::clone(&ledger);

    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(3)).await; // Wait for P2P to initialize
        let bootstrap_list = get_bootstrap_nodes();
        if bootstrap_list.is_empty() {
            println!(
                "📡 No bootstrap nodes configured (set UAT_BOOTSTRAP_NODES for multi-node testnet)"
            );
        }
        for addr in &bootstrap_list {
            let _ = tx_boot.send(format!("DIAL:{}", addr)).await;
            tokio::time::sleep(Duration::from_secs(2)).await;
            let (s, b) = {
                let l = safe_lock(&ledger_boot);
                (
                    l.distribution.remaining_supply,
                    l.distribution.total_burned_usd,
                )
            };
            let _ = tx_boot
                .send(format!("ID:{}:{}:{}", my_addr_boot, s, b))
                .await;
        }

        // After bootstrapping, request state sync from peers (pull-based)
        if !bootstrap_list.is_empty() {
            tokio::time::sleep(Duration::from_secs(3)).await;
            let block_count = safe_lock(&ledger_boot).blocks.len();
            let _ = tx_boot
                .send(format!("SYNC_REQUEST:{}:{}", my_addr_boot, block_count))
                .await;
            println!(
                "📡 Requesting state sync from peers (local blocks: {})",
                block_count
            );
        }

        // Periodic ID re-announce (every 60s) so late-joining peers discover us
        let mut interval = tokio::time::interval(Duration::from_secs(60));
        loop {
            interval.tick().await;
            let (s, b) = {
                let l = safe_lock(&ledger_boot);
                (
                    l.distribution.remaining_supply,
                    l.distribution.total_burned_usd,
                )
            };
            let _ = tx_boot
                .send(format!("ID:{}:{}:{}", my_addr_boot, s, b))
                .await;
        }
    });

    println!("\n==================================================================");
    println!("                 UNAUTHORITY (UAT) ORACLE NODE                   ");
    println!("==================================================================");
    println!("🆔 MY ID        : {}", my_short);
    // Show .onion address if available, otherwise show bind address
    let onion_addr = std::env::var("UAT_ONION_ADDRESS").ok();
    if let Some(ref onion) = onion_addr {
        println!("🧅 REST API     : http://{}", onion);
    } else {
        println!("📡 REST API     : http://127.0.0.1:{}", api_port);
    }
    println!(
        "🔌 gRPC API     : 127.0.0.1:{} (8 services)",
        api_port + 20000
    );
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

    // Flush banner output before emitting the critical node_ready event
    {
        use std::io::Write;
        let _ = std::io::stdout().flush();
    }

    // Emit structured event for Flutter process monitor
    json_event!("node_ready",
        "address" => &my_address,
        "port" => api_port,
        "onion" => onion_addr.as_deref().unwrap_or("none")
    );

    let mut stdin = BufReader::new(io::stdin()).lines();
    let mut stdin_closed = false; // Track EOF — prevents tokio::select! panic in headless mode

    // Clone database, metrics, and slashing_manager for event loop
    let db_clone = Arc::clone(&database);
    let _metrics_clone = Arc::clone(&metrics);
    let slashing_clone = Arc::clone(&slashing_manager);
    let burn_voters_clone = Arc::clone(&burn_voters);
    let send_voters_clone = Arc::clone(&send_voters);

    loop {
        tokio::select! {
            result = stdin.next_line(), if !stdin_closed => {
                match result {
                    Ok(Some(line)) => {
                let p: Vec<&str> = line.split_whitespace().collect();
                if p.is_empty() { continue; }
                match p[0] {
                    "bal" => {
                        let l = safe_lock(&ledger);
                        let b = l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0);
                        println!("📊 Balance: {} UAT", format_u128(b / VOID_PER_UAT));
                    },
                    "whoami" => {
                        println!("🆔 My Short ID: {}", my_short);
                        println!("🔑 Full Address: {}", my_address);
                    },
                    "supply" => {
                        let l = safe_lock(&ledger);
                        println!("📉 Supply: {} UAT | 🔥 Burn: ${:.2}", format_u128(l.distribution.remaining_supply / VOID_PER_UAT), (l.distribution.total_burned_usd as f64) / 100.0);
                    },
                    "history" => {
                        let l = safe_lock(&ledger);
                        // 1. Determine target: user input or self if empty
                        let input_addr = if p.len() == 2 { p[1] } else { &my_address };

                        // 2. Find Full Address
                        let target_full = if input_addr.starts_with("uat_") {
                            // If user input short ID, search in address book
                            safe_lock(&address_book).get(input_addr).cloned()
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
                        let ab = safe_lock(&address_book);
                        println!("👥 Peers: {}", ab.len());
                        for (s, f) in ab.iter() { println!("  - {}: {}", s, f); }
                    },
                    "dial" => {
                        if p.len() == 2 {
                            let tx = tx_out.clone();
                            let ma = my_address.clone();
                            let (s, b) = { let l = safe_lock(&ledger); (l.distribution.remaining_supply, l.distribution.total_burned_usd) };
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

                            // 2. DEADLOCK FIX #4c: Check Ledger and Pending separately (never hold both)
                            let is_already_minted = {
                                let l = safe_lock(&ledger);
                                l.blocks.values().any(|b| {
                                    b.block_type == uat_core::BlockType::Mint &&
                                    (b.link == link_to_search || b.link.contains(&clean_txid))
                                })
                            }; // L dropped
                            let is_pending = safe_lock(&pending_burns).contains_key(&clean_txid);

                            if is_already_minted {
                                println!("❌ Failed: This TXID is already registered in Ledger (Double Claim prevented)!");
                                continue;
                            }

                            if is_pending {
                                println!("⏳ Please wait: This TXID is currently in network verification queue!");
                                continue;
                            }

                            // 4. PROCESS ORACLE (Use Consensus if available)
                            println!("📊 Contacting Oracle for {}...", coin_type.to_uppercase());

                            let consensus_price_opt = {
                                let oc_guard = safe_lock(&oracle_consensus);
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
                                // SECURITY FIX C-03: Use quadratic voting power × 1000
                                // to match VOTE_RES accumulation scale.
                                let my_balance = {
                                    let l = safe_lock(&ledger);
                                    l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0)
                                };
                                let my_power = calculate_voting_power(my_balance) * 1000;

                                // Insert to pending with initial Power = our balance
                                safe_lock(&pending_burns).insert(clean_txid.clone(), (amt, prc, sym.to_string(), my_power, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(), my_address.clone()));

                                // 5. BROADCAST TO NETWORK
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
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

                            let target_full = safe_lock(&address_book).get(target_short).cloned();

                            if let Some(d) = target_full {
                                // DEADLOCK FIX #4e: Never hold L and PS simultaneously.
                                // Step 1: Get state from Ledger (L lock only)
                                let state = {
                                    let l = safe_lock(&ledger);
                                    l.accounts.get(&my_address).cloned().unwrap_or(AccountState {
                                        head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                    })
                                }; // L dropped

                                // Step 2: Check pending total (PS lock only)
                                // FIX C11-M1: Only sum THIS sender's pending txs, not all
                                let pending_total: u128 = safe_lock(&pending_sends).values()
                                    .filter(|(b, _)| b.account == my_address)
                                    .map(|(b, _)| b.amount).sum();

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
                                    public_key: hex::encode(&keys.public_key), // Node's public key
                                    work: 0,
                                    timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                    fee: uat_core::BASE_FEE_VOID, // Protocol constant from uat-core
                                };

                                solve_pow(&mut blk);
                                let signing_hash = blk.signing_hash();
                                blk.signature = hex::encode(uat_crypto::sign_message(signing_hash.as_bytes(), &secret_key).expect("BUG: signing failed — key corrupted"));
                                let hash = blk.calculate_hash();

                                // Save to confirmation queue
                                safe_lock(&pending_sends).insert(hash.clone(), (blk.clone(), 0));

                                // Broadcast confirmation request (REQ) to network
                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
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
                    Ok(None) => {
                        // stdin EOF — running in headless/Flutter mode
                        stdin_closed = true;
                        if json_log {
                            // In Flutter mode, node keeps running without stdin
                            eprintln!("📡 Running in headless mode (stdin closed)");
                        }
                    },
                    Err(e) => {
                        eprintln!("⚠️ stdin error: {}", e);
                        stdin_closed = true;
                    },
                }
            },
            event = rx_in.recv() => {
                let Some(event) = event else {
                    // Network channel closed — P2P task exited/crashed
                    eprintln!("⚠️ Network channel closed, node running in offline mode");
                    // Keep node alive (API server still works) but just sleep
                    loop { tokio::time::sleep(Duration::from_secs(60)).await; }
                };
                if let NetworkEvent::NewBlock(data) = event {
                        if data.starts_with("ID:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() >= 4 {
                                let full = parts[1].to_string();
                                let rem_s = parts[2].parse::<u128>().unwrap_or(0);
                                let tot_b = parts[3].parse::<u128>().unwrap_or(0);

                                if full != my_address {
                                    let short = get_short_addr(&full);
                                    // FIX C12-09: Cap address_book to prevent memory DoS from
                                    // malicious peers flooding fake ID: messages.
                                    const MAX_PEERS: usize = 10_000;
                                    let is_new = {
                                        let mut ab = safe_lock(&address_book);
                                        if ab.len() >= MAX_PEERS && !ab.contains_key(&short) {
                                            None // Address book full; ignore new peer
                                        } else {
                                            let is_new = !ab.contains_key(&short);
                                            ab.insert(short.clone(), full.clone());
                                            Some(is_new)
                                        }
                                    }; // ab dropped — no MutexGuard held past this point
                                    if let Some(is_new) = is_new {

                                    // Persist peer to database for recovery after restart
                                    if is_new {
                                        if let Err(e) = db_clone.save_peer(&short, &full) {
                                            eprintln!("⚠️ Failed to persist peer {}: {}", short, e);
                                        }
                                    }

                                    // DEADLOCK FIX #4f: Never hold L and PS simultaneously.
                                    // Step 1: Ledger operations (L lock only)
                                    let (supply_data, full_state_json) = {
                                        let mut l = safe_lock(&ledger);

                                        // SECURITY FIX #2: Don't blindly trust peer's remaining_supply.
                                        // Instead, verify by recalculating from our own Mint blocks.
                                        // Only sync if peer claims LESS supply remaining AND our calculation confirms it.
                                        if rem_s < l.distribution.remaining_supply && rem_s != 0 {
                                            // Recalculate how much we've minted from our own blocks
                                            let total_minted: u128 = l.blocks.values()
                                                .filter(|b| b.block_type == BlockType::Mint)
                                                .map(|b| b.amount)
                                                .sum();
                                            let calculated_remaining = uat_core::distribution::PUBLIC_SUPPLY_CAP.saturating_sub(total_minted);

                                            // Only accept peer's value if it's close to our calculation
                                            // Allow 1% tolerance for network propagation delay
                                            let tolerance = uat_core::distribution::PUBLIC_SUPPLY_CAP / 100;
                                            if rem_s >= calculated_remaining.saturating_sub(tolerance)
                                                && rem_s <= calculated_remaining.saturating_add(tolerance) {
                                                l.distribution.remaining_supply = calculated_remaining;
                                                l.distribution.total_burned_usd = tot_b;
                                                SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                println!("🔄 Supply Verified & Synced with Peer: {} (calculated: {})", short, calculated_remaining);
                                            } else {
                                                println!("⚠️ Supply sync rejected from {}: peer claims {} but we calculated {}",
                                                    short, rem_s, calculated_remaining);
                                            }
                                        }

                                        println!("🤝 Handshake: {}", short);

                                        let supply = (l.distribution.remaining_supply, l.distribution.total_burned_usd);
                                        let json = if is_new { serde_json::to_string(&*l).ok() } else { None };
                                        (supply, json)
                                    }; // L dropped

                                    // Step 2: Pending transaction resend (PS lock only)
                                    let retry_msgs: Vec<(String, String)> = {
                                        let pending_map = safe_lock(&pending_sends);
                                        pending_map.iter().map(|(hash, (blk, _))| {
                                            let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
                                            (format!("CONFIRM_REQ:{}:{}:{}:{}", hash, blk.account, blk.amount, ts), hash[..8].to_string())
                                        }).collect()
                                    }; // PS dropped
                                    for (retry_msg, hash_short) in &retry_msgs {
                                        let _ = tx_out.send(retry_msg.clone()).await;
                                        println!("📡 Resending confirmation request to new peer for TX: {}", hash_short);
                                    }

                                    // Step 3: Send identity and state to new peer
                                    if is_new {
                                        let (s, b) = supply_data;
                                        let _ = tx_out.send(format!("ID:{}:{}:{}", my_address, s, b)).await;

                                        // Only send full state sync for small networks or small ledgers
                                        // This avoids flooding gossipsub with huge payloads in larger networks
                                        if let Some(full_state_json) = full_state_json {
                                            use flate2::write::GzEncoder;
                                            use flate2::Compression;
                                            use std::io::Write;

                                            let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
                                            let _ = encoder.write_all(full_state_json.as_bytes());
                                            if let Ok(compressed_bytes) = encoder.finish() {
                                                const MAX_SYNC_PAYLOAD: usize = 8 * 1024 * 1024; // 8 MB max (within gossipsub 10MB limit)
                                                if compressed_bytes.len() <= MAX_SYNC_PAYLOAD {
                                                    let encoded_data = base64::encode(&compressed_bytes);
                                                    let _ = tx_out.send(format!("SYNC_GZIP:{}", encoded_data)).await;
                                                    println!("📦 Sent state sync to new peer ({:.1} KB compressed)",
                                                        compressed_bytes.len() as f64 / 1024.0);
                                                } else {
                                                    println!("⚠️ State too large for gossipsub sync ({:.1} MB > 8 MB limit). New peer should use SYNC_REQUEST.",
                                                        compressed_bytes.len() as f64 / 1_048_576.0);
                                                }
                                            }
                                        }
                                    }
                                    } // end is_new scope
                                }
                            }
                        } else if let Some(encoded_data) = data.strip_prefix("SYNC_GZIP:") {
                            // V4#17: Rate limit SYNC_GZIP to prevent DDoS via large payloads
                            static LAST_SYNC: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
                            let now_secs = std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs();
                            let last = LAST_SYNC.load(Ordering::Relaxed);
                            if now_secs.saturating_sub(last) < 10 {
                                println!("⚠️ SYNC_GZIP rate limited (min 10s between syncs)");
                                continue;
                            }
                            LAST_SYNC.store(now_secs, Ordering::Relaxed);

                            if let Ok(compressed_bytes) = base64::decode(encoded_data) {
                                use flate2::read::GzDecoder;
                                use std::io::Read;

                                // SECURITY FIX NEW#4: Limit decompressed size to prevent decompression bomb
                                const MAX_DECOMPRESSED_SIZE: u64 = 50 * 1024 * 1024; // 50 MB max
                                let decoder = GzDecoder::new(&compressed_bytes[..]);
                                let mut limited_decoder = decoder.take(MAX_DECOMPRESSED_SIZE);
                                let mut decompressed_json = String::new();

                                if limited_decoder.read_to_string(&mut decompressed_json).is_ok() {
                                    if let Ok(incoming_ledger) = serde_json::from_str::<Ledger>(&decompressed_json) {
                                        let mut l = safe_lock(&ledger);
                                        let mut added_count = 0;
                                        let mut invalid_count = 0;

                                        // FIX C12-05: Remove 1000-block cap to allow full state sync.
                                        // Sort blocks by timestamp for O(n log n) sync instead of O(n²)
                                        let mut incoming_blocks: Vec<Block> = incoming_ledger.blocks.values()
                                            .cloned()
                                            .collect();
                                        incoming_blocks.sort_by_key(|b| b.timestamp);

                                        // Two-pass: first pass processes ordered blocks, second catches stragglers
                                        for pass in 0..2 {
                                            for blk in &incoming_blocks {
                                                // FIX C12-01b: Accept Mint/Slash blocks in SYNC if validly signed
                                                // by a staked validator. Blanket-reject caused new nodes to
                                                // permanently miss all minted balances.
                                                if matches!(blk.block_type, BlockType::Mint | BlockType::Slash) {
                                                    let sig_ok = hex::decode(&blk.signature).ok().and_then(|sig| {
                                                        hex::decode(&blk.public_key).ok().map(|pk| {
                                                            let sh = blk.signing_hash();
                                                            uat_crypto::verify_signature(sh.as_bytes(), &sig, &pk)
                                                        })
                                                    }).unwrap_or(false);
                                                    if !sig_ok || !blk.verify_pow() {
                                                        invalid_count += 1;
                                                        continue;
                                                    }
                                                }

                                                let hash = blk.calculate_hash();
                                                if l.blocks.contains_key(&hash) { continue; }

                                                if !l.accounts.contains_key(&blk.account) {
                                                    l.accounts.insert(blk.account.clone(), AccountState {
                                                        head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                                    });
                                                }

                                                match l.process_block(blk) {
                                                    Ok(_) => {
                                                        // 🛡️ SLASHING INTEGRATION: Record participation during sync
                                                        {
                                                            let mut sm = safe_lock(&slashing_clone);
                                                            let timestamp = std::time::SystemTime::now()
                                                                .duration_since(std::time::UNIX_EPOCH)
                                                                .unwrap_or_default()
                                                                .as_secs();

                                                            if let Some(acc) = l.accounts.get(&blk.account) {
                                                                if acc.balance >= MIN_VALIDATOR_STAKE_VOID {
                                                                    if sm.get_profile(&blk.account).is_none() {
                                                                        sm.register_validator(blk.account.clone());
                                                                    }
                                                                    let _ = sm.record_block_participation(&blk.account, l.blocks.len() as u64, timestamp);
                                                                }
                                                            }
                                                        }
                                                        added_count += 1;
                                                    },
                                                    Err(_) => {
                                                        if pass == 1 { invalid_count += 1; }
                                                    }
                                                }
                                            }
                                        }

                                        // 2. AUTOMATIC BLACKLIST: If garbage blocks > threshold, remove from address book
                                        const GARBAGE_BLOCK_THRESHOLD: usize = 10;
                                        if invalid_count > GARBAGE_BLOCK_THRESHOLD {
                                            println!("🚫 BLACKLIST: Peer sent {} garbage blocks (threshold: {}). Disconnecting...", invalid_count, GARBAGE_BLOCK_THRESHOLD);
                                            // Remove the peer that sent us this sync data
                                            // Note: In a real implementation we'd track which peer sent SYNC_GZIP
                                            let ab = safe_lock(&address_book);
                                            // Remove peers whose full addresses are contained in our address book
                                            // For now, log the event - full peer tracking requires connection-level metadata
                                            println!("🚫 {} peers in address book. Consider manual cleanup via 'peers' command.", ab.len());
                                        }

                                        if added_count > 0 {
                                            SAVE_DIRTY.store(true, Ordering::Relaxed);
                                            println!("📚 Sync Complete: {} new blocks validated", added_count);
                                        }
                                    }
                                }
                            }
                        } else if data.starts_with("SYNC_REQUEST:") {
                            // SECURITY P0-4: Rate-limited, per-requester sync response
                            // FORMAT: SYNC_REQUEST:<requester_address>:<their_block_count>
                            static SYNC_RESP_TIMES: std::sync::LazyLock<Mutex<HashMap<String, u64>>> =
                                std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() >= 3 {
                                let requester = parts[1].to_string();
                                let their_count: usize = parts[2].parse().unwrap_or(0);

                                // Per-requester rate limit: max 1 sync response per 30 seconds per peer
                                let now_secs = std::time::SystemTime::now()
                                    .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs();
                                {
                                    let mut times = safe_lock(&SYNC_RESP_TIMES);
                                    let last = times.get(&requester).copied().unwrap_or(0);
                                    if now_secs.saturating_sub(last) < 30 {
                                        continue; // Rate limited — skip silently
                                    }
                                    times.insert(requester.clone(), now_secs);
                                    // Evict old entries to prevent memory leak
                                    times.retain(|_, ts| now_secs.saturating_sub(*ts) < 300);
                                }

                                // Only respond if we have more blocks than the requester
                                let our_count = safe_lock(&ledger).blocks.len();
                                if our_count > their_count && requester != my_address {
                                    println!("📡 Sync request from {} (they have {} blocks, we have {})",
                                        get_short_addr(&requester), their_count, our_count);

                                    // Send only the BLOCKS the requester is missing (not full ledger)
                                    let sync_json = {
                                        let l = safe_lock(&ledger);
                                        serde_json::to_string(&*l).ok()
                                    };

                                    if let Some(json) = sync_json {
                                        use flate2::write::GzEncoder;
                                        use flate2::Compression;
                                        use std::io::Write;

                                        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
                                        let _ = encoder.write_all(json.as_bytes());
                                        if let Ok(compressed) = encoder.finish() {
                                            // Cap sync payload at 8MB
                                            if compressed.len() <= 8 * 1024 * 1024 {
                                                let encoded = base64::encode(&compressed);
                                                let _ = tx_out.send(format!("SYNC_GZIP:{}", encoded)).await;
                                                println!("📤 Sent state sync ({} blocks, {}KB compressed)", our_count, compressed.len() / 1024);
                                            }
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
                                // FIX C12-03: Wrap cloned secret key in Zeroizing for automatic
                                // zeroing when the async task completes (prevents key leakage in heap)
                                let vote_sk = Zeroizing::new(secret_key.clone());
                                let vote_pk = keys.public_key.clone();

                                tokio::spawn(async move {
                                    // 1. Check Ledger: Ensure this TXID has never been minted before
                                    let link_to_check = format!("{}:{}", coin_type.to_uppercase(), txid);
                                    let already_exists = {
                                        let l = safe_lock(&ledger_ref);
                                        l.blocks.values().any(|b| b.block_type == uat_core::BlockType::Mint && (b.link == link_to_check || b.link.contains(&txid)))
                                    };

                                    if already_exists {
                                        // IF DOUBLE CLAIM DETECTED FROM OTHER PEER
                                        if requester != my_addr_clone {
                                            println!("🚨 DOUBLE CLAIM DETECTED: {} trying to claim existing TXID!", get_short_addr(&requester));
                                            // SECURITY FIX S1: Sign SLASH_REQ with Dilithium5
                                            let slash_ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
                                            let slash_payload = format!("SLASH:{}:{}:{}:{}", requester, txid, my_addr_clone, slash_ts);
                                            let slash_sig = uat_crypto::sign_message(slash_payload.as_bytes(), &vote_sk).expect("BUG: signing failed");
                                            let slash_msg = format!("SLASH_REQ:{}:{}:{}:{}:{}:{}", requester, txid, my_addr_clone, slash_ts, hex::encode(&slash_sig), hex::encode(&vote_pk));
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

                                    let ts_res = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();

                                    // 3. Decision Logic: YES (Valid) or SLASH (Fake)
                                    if amount_opt.is_some() {
                                        // VALID TXID: Send VOTE_RES YES (signed with Dilithium5)
                                        let payload = format!("{}:{}:YES:{}:{}", txid, requester, my_addr_clone, ts_res);
                                        let sig = uat_crypto::sign_message(payload.as_bytes(), &vote_sk).expect("BUG: signing failed");
                                        let response = format!("VOTE_RES:{}:{}:YES:{}:{}:{}:{}", txid, requester, my_addr_clone, ts_res, hex::encode(&sig), hex::encode(&vote_pk));
                                        let _ = tx_vote.send(response).await;

                                        println!("🗳️ Casting YES vote for TXID: {} from {}",
                                            &txid[..8],
                                            get_short_addr(&requester)
                                        );
                                    } else {
                                        // SECURITY P2-6: TXID not verified — ABSTAIN instead of SLASH
                                        // The API may be unreachable, not necessarily fraud.
                                        // Double-claim detection (above) already handles confirmed fraud.
                                        println!("⚠️ TXID {} from {} could not be verified — abstaining (API may be down)",
                                            &txid[..std::cmp::min(8, txid.len())], get_short_addr(&requester));
                                    }
                                });
                            }
                        } else if data.starts_with("ORACLE_SUBMIT:") {
                            // FORMAT: ORACLE_SUBMIT:validator_address:eth_price:btc_price:signature:pubkey
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 6 {
                                let validator_addr = parts[1].to_string();
                                let eth_price: f64 = parts[2].parse().unwrap_or(0.0);
                                let btc_price: f64 = parts[3].parse().unwrap_or(0.0);
                                let sig_hex = parts[4];
                                let pk_hex = parts[5];

                                // SECURITY: Verify Dilithium5 signature on oracle submission
                                let payload = format!("{}:{}:{}", validator_addr, eth_price, btc_price);
                                let sig_bytes = hex::decode(sig_hex).unwrap_or_default();
                                let pk_bytes = hex::decode(pk_hex).unwrap_or_default();

                                if !uat_crypto::verify_signature(payload.as_bytes(), &sig_bytes, &pk_bytes) {
                                    println!("🚨 Rejected oracle submission: invalid signature from {}",
                                        get_short_addr(&validator_addr));
                                    continue;
                                }

                                // Verify public key matches claimed validator address
                                let derived_addr = uat_crypto::public_key_to_address(&pk_bytes);
                                if derived_addr != validator_addr {
                                    println!("🚨 Rejected oracle submission: address mismatch (claimed {} but key derives {})",
                                        get_short_addr(&validator_addr), get_short_addr(&derived_addr));
                                    continue;
                                }

                                // Verify submitter is a validator (min 1000 UAT stake)
                                {
                                    let l = safe_lock(&ledger);
                                    let is_validator = l.accounts.get(&validator_addr)
                                        .map(|a| a.balance >= MIN_VALIDATOR_STAKE_VOID)
                                        .unwrap_or(false);
                                    if !is_validator {
                                        println!("⚠️  Rejected oracle from non-validator: {}", get_short_addr(&validator_addr));
                                        continue;
                                    }
                                }

                                // Submit to oracle consensus (signature verified)
                                let mut oc = safe_lock(&oracle_consensus);
                                oc.submit_price(validator_addr.clone(), eth_price, btc_price);

                                // Check if consensus achieved
                                if let Some((eth_median, btc_median)) = oc.get_consensus_price() {
                                    println!("✅ Oracle Consensus: ETH=${:.2}, BTC=${:.2} (from {} validators)",
                                        eth_median, btc_median, oc.submission_count());
                                } else {
                                    println!("📊 Oracle submission from {} ({} more validators needed)",
                                        get_short_addr(&validator_addr),
                                        2_usize.saturating_sub(oc.submission_count())
                                    );
                                }
                            }
                        } else if data.starts_with("SLASH_REQ:") {
                            // FORMAT: SLASH_REQ:cheater_address:fake_txid:proposer_addr:timestamp:signature:pubkey (7 parts)
                            // SECURITY FIX S1: Verify Dilithium5 signature on SLASH_REQ (was unsigned).
                            let parts: Vec<&str> = data.split(':').collect();
                            if parts.len() == 7 {
                                let proposer_addr = parts[3].to_string();
                                let slash_sig_hex = parts[5];
                                let slash_pk_hex = parts[6];

                                // Verify cryptographic signature
                                let slash_payload = format!("SLASH:{}:{}:{}:{}", parts[1], parts[2], parts[3], parts[4]);
                                let slash_sig_bytes = hex::decode(slash_sig_hex).unwrap_or_default();
                                let slash_pk_bytes = hex::decode(slash_pk_hex).unwrap_or_default();

                                if !uat_crypto::verify_signature(slash_payload.as_bytes(), &slash_sig_bytes, &slash_pk_bytes) {
                                    println!("🚨 Rejected SLASH_REQ: invalid signature from {}", get_short_addr(&proposer_addr));
                                    continue;
                                }
                                // Verify pubkey matches claimed proposer address
                                let derived_proposer = uat_crypto::public_key_to_address(&slash_pk_bytes);
                                if derived_proposer != proposer_addr {
                                    println!("🚨 Rejected SLASH_REQ: pubkey mismatch for {}", get_short_addr(&proposer_addr));
                                    continue;
                                }
                            } else if parts.len() == 3 {
                                // Legacy unsigned format — reject on mainnet, warn on testnet
                                if uat_core::is_mainnet_build() {
                                    println!("🚨 Rejected unsigned SLASH_REQ (mainnet requires signed messages)");
                                    continue;
                                }
                                println!("⚠️ Accepted unsigned SLASH_REQ (testnet only — will be rejected on mainnet)");
                            } else {
                                continue;
                            }
                            {
                                let cheater_addr = parts[1].to_string();
                                let fake_txid = parts[2].to_string();

                                println!("⚖️  Slash proposal received for: {}", get_short_addr(&cheater_addr));

                                // Step 1: Validate this node is a validator
                                let my_balance = {
                                    let l = safe_lock(&ledger);
                                    l.accounts.get(&my_address).map(|a| a.balance).unwrap_or(0)
                                };
                                if my_balance < MIN_VALIDATOR_STAKE_VOID {
                                    println!("⚠️ Ignoring SLASH_REQ: this node is not a validator");
                                    continue;
                                }

                                // Step 2: Independently verify the evidence
                                // SECURITY P1-1: Check if cheater's TXID was already legitimately minted
                                // Evidence is valid if: cheater exists AND the TXID was NOT found in any
                                // Mint block's link field (i.e., it was never successfully burned/minted)
                                let is_valid_evidence = {
                                    let l = safe_lock(&ledger);
                                    let cheater_exists = l.accounts.contains_key(&cheater_addr);
                                    // Check that no Mint block references this TXID in its link
                                    let txid_was_minted = l.blocks.values().any(|b| {
                                        b.block_type == uat_core::BlockType::Mint && b.link.contains(&fake_txid)
                                    });
                                    cheater_exists && !txid_was_minted
                                };

                                if !is_valid_evidence {
                                    println!("⚠️ SLASH_REQ rejected: evidence not confirmed independently");
                                    continue;
                                }

                                // Step 3: Register vote in SlashingManager
                                let should_execute = {
                                    let mut sm = safe_lock(&slashing_manager);
                                    let stats = sm.get_safety_stats();
                                    let total_validators = stats.total_validators.max(1);
                                    let threshold = ((total_validators * 2 / 3) + 1) as usize;

                                    // Use propose_slash to register this vote
                                    let evidence_hash = format!("FAKE_TXID:{}", fake_txid);
                                    let now_ts = std::time::SystemTime::now()
                                        .duration_since(std::time::UNIX_EPOCH)
                                        .unwrap_or_default()
                                        .as_secs();
                                    let _ = sm.propose_slash(
                                        cheater_addr.clone(),
                                        uat_consensus::slashing::ViolationType::FraudulentTransaction,
                                        evidence_hash,
                                        my_address.clone(),
                                        now_ts,
                                    );

                                    // Check if enough validators have proposed slash for this address
                                    let proposal_count = sm.get_pending_proposals()
                                        .iter()
                                        .filter(|p| p.offender == cheater_addr && !p.executed)
                                        .count();

                                    println!("⚖️  Slash votes for {}: {}/{} (need {})",
                                        get_short_addr(&cheater_addr), proposal_count, total_validators, threshold);

                                    proposal_count >= threshold
                                };

                                if should_execute {
                                    // Consensus reached — execute the slash
                                    let slash_gossip: Option<String> = {
                                        let mut l = safe_lock(&ledger);
                                        let mut gossip = None;

                                        if let Some(state) = l.accounts.get(&cheater_addr).cloned() {
                                            if state.balance > 0 {
                                                // Penalty: 10% of total balance
                                                let penalty_amount = state.balance / 10;

                                                let mut slash_blk = Block {
                                                    account: cheater_addr.clone(),
                                                    previous: state.head.clone(),
                                                    block_type: BlockType::Slash,
                                                    amount: penalty_amount,
                                                    link: format!("PENALTY:FAKE_TXID:{}", fake_txid),
                                                    signature: "".to_string(),
                                                    public_key: hex::encode(&keys.public_key),
                                                    work: 0,
                                                    timestamp: std::time::SystemTime::now()
                                                        .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                                    fee: 0,
                                                };

                                                solve_pow(&mut slash_blk);
                                                if let Ok(sig) = uat_crypto::sign_message(slash_blk.signing_hash().as_bytes(), &secret_key) {
                                                    slash_blk.signature = hex::encode(sig);

                                                    match l.process_block(&slash_blk) {
                                                        Ok(hash) => {
                                                            SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                            gossip = Some(serde_json::to_string(&slash_blk).unwrap_or_default());
                                                            println!("🔨 SLASHED (consensus 2/3+1)! {} penalized {} UAT (block: {})",
                                                                get_short_addr(&cheater_addr),
                                                                penalty_amount / VOID_PER_UAT,
                                                                &hash[..8]
                                                            );
                                                        },
                                                        Err(e) => println!("⚠️ Slash block failed for {}: {}", get_short_addr(&cheater_addr), e),
                                                    }
                                                } else {
                                                    println!("⚠️ Slash signing failed for {}", get_short_addr(&cheater_addr));
                                                }
                                            }
                                        }
                                        gossip
                                    }; // l dropped
                                    if let Some(msg) = slash_gossip {
                                        let _ = tx_out.send(msg).await;
                                    }
                                } else {
                                    println!("⏳ Slash proposal registered, waiting for more validator votes...");
                                }
                            }
                        } else if data.starts_with("VOTE_RES:") {
                            let parts: Vec<&str> = data.split(':').collect();

                            // FORMAT: VOTE_RES:txid:requester:YES:voter_addr:timestamp:signature:pubkey (8 parts)
                            if parts.len() == 8 {
                                let txid = parts[1].to_string();
                                let requester = parts[2].to_string();
                                let voter_addr = parts[4].to_string();
                                let sig_hex = parts[6];
                                let pk_hex = parts[7];

                                // SECURITY P0-1: Verify Dilithium5 signature on vote
                                let payload = format!("{}:{}:YES:{}:{}", parts[1], parts[2], parts[4], parts[5]);
                                let sig_bytes = hex::decode(sig_hex).unwrap_or_default();
                                let pk_bytes = hex::decode(pk_hex).unwrap_or_default();

                                if !uat_crypto::verify_signature(payload.as_bytes(), &sig_bytes, &pk_bytes) {
                                    println!("🚨 Rejected VOTE_RES: invalid signature from {}", get_short_addr(&voter_addr));
                                    continue;
                                }
                                // Verify pubkey matches claimed voter address
                                let derived_addr = uat_crypto::public_key_to_address(&pk_bytes);
                                if derived_addr != voter_addr {
                                    println!("🚨 Rejected VOTE_RES: pubkey mismatch for {}", get_short_addr(&voter_addr));
                                    continue;
                                }

                                if requester == my_address {
                                    // DEADLOCK FIX #4d: Never hold PB and L simultaneously.
                                    // Step 1: Check if txid exists in pending (PB lock only)
                                    let txid_exists = {
                                        let pending = safe_lock(&pending_burns);
                                        pending.contains_key(&txid)
                                    }; // PB dropped

                                    if !txid_exists { continue; }

                                    // Step 2: Get voter balance (L lock only)
                                    let voter_balance = {
                                        let l_guard = safe_lock(&ledger);
                                        // SECURITY FIX #10: Use in-memory state (authoritative)
                                        // REMOVED: disk re-read that overwrote in-memory state
                                        l_guard.accounts.get(&voter_addr)
                                            .map(|a| a.balance)
                                            .unwrap_or(0)
                                    }; // L dropped

                                    // --- QUADRATIC VOTING: Power = √Stake (Anti-Whale) ---
                                    let voter_power_quadratic = calculate_voting_power(voter_balance);
                                    let voter_power_display = voter_balance / VOID_PER_UAT;

                                    if voter_power_quadratic == 0 {
                                        println!("⚠️ Vote ignored: {} (Stake {} UAT insufficient, need 1000 UAT min)",
                                            get_short_addr(&voter_addr),
                                            voter_power_display
                                        );
                                        continue;
                                    }

                                    // Step 3: Update votes and check threshold (PB lock only)
                                    let consensus_data = {
                                        // SECURITY FIX: Vote deduplication — prevent single validator from reaching consensus alone
                                        let mut voters = safe_lock(&burn_voters_clone);
                                        let voter_set = voters.entry(txid.clone()).or_default();
                                        if voter_set.contains(&voter_addr) {
                                            println!("⚠️ Duplicate burn vote from {} — ignored", get_short_addr(&voter_addr));
                                            continue;
                                        }
                                        voter_set.insert(voter_addr.clone());
                                        drop(voters);

                                        let mut pending = safe_lock(&pending_burns);
                                        if let Some(burn_info) = pending.get_mut(&txid) {
                                            // SECURITY FIX S4: Pure u128 integer math — no f64 truncation
                                            let power_scaled = voter_power_quadratic * 1000;
                                            burn_info.3 += power_scaled;

                                            println!("📩 Vote Received: {} (Stake: {} UAT, Quadratic Power: {}) | Progress: {}/20000",
                                                get_short_addr(&voter_addr),
                                                voter_power_display,
                                                voter_power_quadratic,
                                                burn_info.3
                                            );

                                            let threshold = if !testnet_config::get_testnet_config().should_enable_consensus() { TESTNET_FUNCTIONAL_THRESHOLD } else { BURN_CONSENSUS_THRESHOLD };
                                            if burn_info.3 >= threshold {
                                                println!("✅ Quadratic Stake Consensus Achieved (Total Power: {})!", burn_info.3);
                                                let (amt_coin, price, sym, _, _, recipient) = burn_info.clone();
                                                Some((amt_coin, price, sym, recipient))
                                            } else { None }
                                        } else { None }
                                    }; // PB dropped

                                    // Step 4: If consensus reached, mint (L lock only)
                                    if let Some((amt_coin, price, sym, mint_recipient)) = consensus_data {
                                        // SECURITY FIX NEW#3: Pure integer math via calculate_mint_void()
                                        let uat_to_mint = match calculate_mint_void(amt_coin, price, &sym) {
                                            Ok(v) => v,
                                            Err(e) => {
                                                eprintln!("❌ Mint calculation overflow: {}", e);
                                                continue;
                                            }
                                        };
                                        if uat_to_mint == 0 { continue; } // too small

                                        let mint_gossip: Option<String> = {
                                            let mut l = safe_lock(&ledger);

                                            // Ensure recipient account exists
                                            if !l.accounts.contains_key(&mint_recipient) {
                                                l.accounts.insert(mint_recipient.clone(), AccountState {
                                                    head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                                });
                                            }
                                            let state = l.accounts.get(&mint_recipient).cloned().unwrap_or(AccountState {
                                                head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                            });

                                            let mut mint_blk = Block {
                                                account: mint_recipient.clone(),
                                                previous: state.head.clone(),
                                                block_type: BlockType::Mint,
                                                amount: uat_to_mint,
                                                link: format!("Src:{}:{}:{}", sym, txid, price as u128),
                                                signature: "".to_string(),
                                                public_key: hex::encode(&keys.public_key),
                                                work: 0,
                                                timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                                fee: 0,
                                            };

                                            solve_pow(&mut mint_blk);
                                            let signing_hash = mint_blk.signing_hash();
                                            mint_blk.signature = hex::encode(uat_crypto::sign_message(signing_hash.as_bytes(), &secret_key).expect("BUG: signing failed — key corrupted"));

                                            match l.process_block(&mint_blk) {
                                                Ok(_) => {
                                                    SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                    println!("🔥 Minting Successful: +{} UAT to {}!", format_u128(uat_to_mint / VOID_PER_UAT), get_short_addr(&mint_recipient));
                                                    Some(serde_json::to_string(&mint_blk).unwrap_or_default())
                                                },
                                                Err(e) => { println!("❌ Failed to process Mint block: {}", e); None },
                                            }
                                        }; // L dropped
                                        if let Some(msg) = mint_gossip {
                                            let _ = tx_out.send(msg).await;
                                        }

                                        // Step 5: Remove from pending (PB lock only)
                                        safe_lock(&pending_burns).remove(&txid);
                                        safe_lock(&burn_voters_clone).remove(&txid);
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
                                // FIX C12-03: Zeroize cloned secret key on async task drop
                                let confirm_sk = Zeroizing::new(secret_key.clone());
                                let confirm_pk = keys.public_key.clone();

                                tokio::spawn(async move {
                                    // SECURITY P0-2: Verify the referenced block exists and matches claims
                                    let (sender_balance, block_valid) = {
                                        let l_guard = safe_lock(&ledger_ref);
                                        let bal = l_guard.accounts.get(&sender_addr).map(|a| a.balance).unwrap_or(0);
                                        // Verify: tx_hash exists in blocks, is a Send, matches sender and amount
                                        let valid = l_guard.blocks.get(&tx_hash).map(|b| {
                                            b.block_type == uat_core::BlockType::Send
                                                && b.account == sender_addr
                                                && b.amount == amount
                                        }).unwrap_or(false);
                                        (bal, valid)
                                    };

                                    if !block_valid {
                                        // P0-2: Block doesn't exist or doesn't match — don't vote
                                        return;
                                    }

                                    if sender_balance >= amount {
                                        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis();
                                        // SECURITY P0-1: Sign CONFIRM_RES with Dilithium5
                                        let payload = format!("{}:{}:YES:{}:{}", tx_hash, sender_addr, my_addr_clone, ts);
                                        let sig = uat_crypto::sign_message(payload.as_bytes(), &confirm_sk).expect("BUG: signing failed");
                                        let res = format!("CONFIRM_RES:{}:{}:YES:{}:{}:{}:{}", tx_hash, sender_addr, my_addr_clone, ts, hex::encode(&sig), hex::encode(&confirm_pk));
                                        let _ = tx_confirm.send(res).await;
                                    }
                                });
                            }
                        } else if data.starts_with("CONFIRM_RES:") {
                            let parts: Vec<&str> = data.split(':').collect();
                            // FORMAT: CONFIRM_RES:tx_hash:sender:YES:voter:timestamp:signature:pubkey (8 parts)
                            if parts.len() == 8 {
                                let tx_hash = parts[1].to_string();
                                let requester = parts[2].to_string();
                                let voter_addr = parts[4].to_string();
                                let sig_hex = parts[6];
                                let pk_hex = parts[7];

                                // SECURITY P0-1: Verify Dilithium5 signature on confirmation
                                let payload = format!("{}:{}:YES:{}:{}", parts[1], parts[2], parts[4], parts[5]);
                                let sig_bytes = hex::decode(sig_hex).unwrap_or_default();
                                let pk_bytes = hex::decode(pk_hex).unwrap_or_default();

                                if !uat_crypto::verify_signature(payload.as_bytes(), &sig_bytes, &pk_bytes) {
                                    println!("🚨 Rejected CONFIRM_RES: invalid signature from {}", get_short_addr(&voter_addr));
                                    continue;
                                }
                                let derived_addr = uat_crypto::public_key_to_address(&pk_bytes);
                                if derived_addr != voter_addr {
                                    println!("🚨 Rejected CONFIRM_RES: pubkey mismatch for {}", get_short_addr(&voter_addr));
                                    continue;
                                }

                                if requester == my_address {
                                    // DEADLOCK FIX #4g: Never hold PS and L simultaneously.
                                    // Step 1: Check if tx exists in pending (PS lock only)
                                    let tx_exists = {
                                        let pending = safe_lock(&pending_sends);
                                        pending.contains_key(&tx_hash)
                                    }; // PS dropped

                                    if !tx_exists { continue; }

                                    // Step 2: Get voter balance (L lock only)
                                    let voter_balance = {
                                        let l_guard = safe_lock(&ledger);
                                        // SECURITY FIX #10: Use in-memory state (authoritative)
                                        // REMOVED: disk re-read that overwrote in-memory state
                                        l_guard.accounts.get(&voter_addr).map(|a| a.balance).unwrap_or(0)
                                    }; // L dropped

                                    // --- QUADRATIC VOTING: Power = √Stake (Anti-Whale) ---
                                    let voter_power_quadratic = calculate_voting_power(voter_balance);
                                    let voter_power_display = voter_balance / VOID_PER_UAT;

                                    // Step 3: Update votes and check threshold (PS lock only)
                                    let finalize_data = {
                                        // SECURITY FIX: Vote deduplication — prevent single validator from reaching consensus alone
                                        let mut voters = safe_lock(&send_voters_clone);
                                        let voter_set = voters.entry(tx_hash.clone()).or_default();
                                        if voter_set.contains(&voter_addr) {
                                            println!("⚠️ Duplicate send vote from {} — ignored", get_short_addr(&voter_addr));
                                            continue;
                                        }
                                        voter_set.insert(voter_addr.clone());
                                        drop(voters);

                                        let mut pending = safe_lock(&pending_sends);
                                        if let Some((blk, total_power_votes)) = pending.get_mut(&tx_hash) {
                                            if voter_power_quadratic > 0 {
                                                // SECURITY FIX S4: Pure u128 integer math — no f64 truncation
                                                let power_scaled = voter_power_quadratic * 1000;
                                                *total_power_votes += power_scaled;
                                                println!("📩 Konfirmasi Power: {} (Stake: {} UAT, Quadratic: {}) | Total: {}/20000",
                                                    get_short_addr(&voter_addr), voter_power_display, voter_power_quadratic, total_power_votes
                                                );
                                            }

                                            let threshold: u128 = if !testnet_config::get_testnet_config().should_enable_consensus() { TESTNET_FUNCTIONAL_THRESHOLD } else { SEND_CONSENSUS_THRESHOLD };
                                            if *total_power_votes >= threshold {
                                                Some(blk.clone())
                                            } else { None }
                                        } else { None }
                                    }; // PS dropped

                                    // Step 4: If threshold met, finalize (L lock only, then SM lock only)
                                    if let Some(blk_to_finalize) = finalize_data {
                                        let process_success = {
                                            let mut l = safe_lock(&ledger);
                                            match l.process_block(&blk_to_finalize) {
                                                Ok(_) => {
                                                    // 🛡️ SLASHING INTEGRATION: Record finalization participation
                                                    {
                                                        let mut sm = safe_lock(&slashing_clone);
                                                        let timestamp = std::time::SystemTime::now()
                                                            .duration_since(std::time::UNIX_EPOCH)
                                                            .unwrap_or_default()
                                                            .as_secs();

                                                        if let Some(acc) = l.accounts.get(&blk_to_finalize.account) {
                                                            if acc.balance >= MIN_VALIDATOR_STAKE_VOID {
                                                                if sm.get_profile(&blk_to_finalize.account).is_none() {
                                                                    sm.register_validator(blk_to_finalize.account.clone());
                                                                }
                                                                let _ = sm.record_block_participation(&blk_to_finalize.account, l.blocks.len() as u64, timestamp);
                                                            }
                                                        }
                                                    }
                                                    SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                    true
                                                },
                                                Err(e) => {
                                                    println!("❌ Finalization Failed: {:?}", e);
                                                    false
                                                }
                                            }
                                        }; // L dropped

                                        if process_success {
                                            let _ = tx_out.send(serde_json::to_string(&blk_to_finalize).unwrap_or_default()).await;
                                            println!("✅ Transaction Confirmed (Power Verified) & Added to Ledger");

                                            // SECURITY FIX #5: Auto-create Receive block ONLY for our own address.
                                            // In block-lattice, Receive blocks must be signed by the RECIPIENT.
                                            // We can only sign for ourselves — remote recipients auto-receive
                                            // when they see the Send block via P2P gossip.
                                            if blk_to_finalize.block_type == BlockType::Send && blk_to_finalize.link == my_address {
                                                let send_hash = blk_to_finalize.calculate_hash();

                                                let recv_gossip: Option<String> = {
                                                    let mut l = safe_lock(&ledger);
                                                    if !l.accounts.contains_key(&my_address) {
                                                        l.accounts.insert(my_address.clone(), AccountState {
                                                            head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                                        });
                                                    }
                                                    if let Some(recv_state) = l.accounts.get(&my_address).cloned() {
                                                        let mut recv_blk = Block {
                                                            account: my_address.clone(),
                                                            previous: recv_state.head,
                                                            block_type: BlockType::Receive,
                                                            amount: blk_to_finalize.amount,
                                                            link: send_hash,
                                                            signature: "".to_string(),
                                                            public_key: hex::encode(&keys.public_key),
                                                            work: 0,
                                                            timestamp: std::time::SystemTime::now()
                                                                .duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                                            fee: 0,
                                                        };
                                                        solve_pow(&mut recv_blk);
                                                        recv_blk.signature = hex::encode(
                                                            uat_crypto::sign_message(recv_blk.signing_hash().as_bytes(), &secret_key).expect("BUG: signing failed — key corrupted")
                                                        );
                                                        match l.process_block(&recv_blk) {
                                                            Ok(_) => {
                                                                SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                                println!("📨 Auto-Receive created for self: +{} VOID",
                                                                    blk_to_finalize.amount);
                                                                Some(serde_json::to_string(&recv_blk).unwrap_or_default())
                                                            },
                                                            Err(e) => { println!("⚠️ Auto-Receive failed: {}", e); None },
                                                        }
                                                    } else { None }
                                                }; // l dropped
                                                if let Some(msg) = recv_gossip {
                                                    let _ = tx_out.send(msg).await;
                                                }
                                            }
                                        }
                                        // Step 5: Remove from pending (PS lock only)
                                        safe_lock(&pending_sends).remove(&tx_hash);
                                        safe_lock(&send_voters_clone).remove(&tx_hash);
                                    }
                                }
                            }
                        } else if let Ok(inc) = serde_json::from_str::<Block>(&data) {
                            // FIX C12-01: Mint/Slash blocks from P2P are accepted ONLY if they
                            // carry a valid validator signature + valid PoW. Previously blanket-
                            // rejected, which caused minted tokens to exist only on the originating
                            // node — splitting the ledger permanently across the network.
                            if matches!(inc.block_type, BlockType::Mint | BlockType::Slash) {
                                // Verify: non-empty signature, valid signature, valid PoW
                                if inc.signature.is_empty() || inc.public_key.is_empty() {
                                    println!("🚫 Rejected unsigned {:?} block from P2P", inc.block_type);
                                    continue;
                                }
                                let sig_ok = hex::decode(&inc.signature).ok().and_then(|sig| {
                                    hex::decode(&inc.public_key).ok().map(|pk| {
                                        let signing_hash = inc.signing_hash();
                                        uat_crypto::verify_signature(signing_hash.as_bytes(), &sig, &pk)
                                    })
                                }).unwrap_or(false);
                                if !sig_ok {
                                    println!("🚫 Rejected {:?} block from P2P: invalid signature", inc.block_type);
                                    continue;
                                }
                                if !inc.verify_pow() {
                                    println!("🚫 Rejected {:?} block from P2P: invalid PoW", inc.block_type);
                                    continue;
                                }
                                // Also verify the signing key maps to a known staked validator
                                let signer_addr = hex::decode(&inc.public_key)
                                    .map(|pk| uat_crypto::public_key_to_address(&pk))
                                    .unwrap_or_default();
                                let is_validator = {
                                    let l = safe_lock(&ledger);
                                    l.accounts.get(&signer_addr)
                                        .map(|a| a.balance >= MIN_VALIDATOR_STAKE_VOID)
                                        .unwrap_or(false)
                                };
                                if !is_validator {
                                    println!("🚫 Rejected {:?} block from P2P: signer {} is not a staked validator", inc.block_type, get_short_addr(&signer_addr));
                                    continue;
                                }
                                // Signature + PoW + staked validator → accept into ledger
                            }

                            // 🛡️ SLASHING INTEGRATION: Check for double-signing before processing
                            let block_hash = inc.calculate_hash();
                            let timestamp = std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .unwrap_or_default()
                                .as_secs();

                            // Phase 1: Account init + double-sign detection + optional slash (all synchronous)
                            let (double_sign_detected, ds_gossip) = {
                                let mut l = safe_lock(&ledger);
                                if !l.accounts.contains_key(&inc.account) {
                                    l.accounts.insert(inc.account.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0, is_validator: false });
                                }

                                let double_sign_detected = {
                                    let mut sm = safe_lock(&slashing_clone);
                                    // Register validator if not exists (only if flagged as validator)
                                    if sm.get_profile(&inc.account).is_none() {
                                        if let Some(acc) = l.accounts.get(&inc.account) {
                                            if acc.is_validator {
                                                sm.register_validator(inc.account.clone());
                                            }
                                        }
                                    }

                                    // SECURITY FIX V4#3: Use account's block_count as height
                                    // (was hardcoded 0 → false double-signing detection after every 2nd block)
                                    let block_height = l.accounts.get(&inc.account)
                                        .map(|a| a.block_count)
                                        .unwrap_or(0);
                                    sm.record_signature(&inc.account, block_height, block_hash.clone(), timestamp).is_err()
                                };

                                let mut gossip = None;
                                if double_sign_detected {
                                    println!("🚨 DOUBLE-SIGNING DETECTED from {}! Slashing...", get_short_addr(&inc.account));

                                    // Slash validator for double-signing (100%) via proper Slash block
                                    let staked_amount = l.accounts.get(&inc.account).map(|a| a.balance).unwrap_or(0);
                                    let mut sm = safe_lock(&slashing_clone);
                                    if let Ok(slashed) = sm.slash_double_signing(&inc.account, l.blocks.len() as u64, staked_amount, timestamp) {
                                        println!("⚖️ Validator {} slashed {} VOID (100%) for double-signing",
                                            get_short_addr(&inc.account), slashed);
                                        drop(sm);

                                        // FIX: Create proper Slash block instead of direct balance mutation
                                        // This ensures all nodes see the slash in the blockchain
                                        let cheater_state = l.accounts.get(&inc.account).cloned().unwrap_or(AccountState {
                                            head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                        });
                                        let mut slash_blk = Block {
                                            account: inc.account.clone(),
                                            previous: cheater_state.head.clone(),
                                            block_type: BlockType::Slash,
                                            amount: slashed,
                                            link: format!("PENALTY:DOUBLE_SIGN:{}", block_hash),
                                            signature: "".to_string(),
                                            public_key: hex::encode(&keys.public_key),
                                            work: 0,
                                            timestamp,
                                            fee: 0,
                                        };
                                        solve_pow(&mut slash_blk);
                                        slash_blk.signature = hex::encode(
                                            uat_crypto::sign_message(slash_blk.signing_hash().as_bytes(), &secret_key)
                                                .expect("BUG: signing failed")
                                        );
                                        match l.process_block(&slash_blk) {
                                            Ok(_) => {
                                                gossip = Some(serde_json::to_string(&slash_blk).unwrap_or_default());
                                                println!("⚖️ Slash block created and broadcast for {}", get_short_addr(&inc.account));
                                            },
                                            Err(e) => eprintln!("⚠️ Slash block failed: {}", e),
                                        }
                                        SAVE_DIRTY.store(true, Ordering::Relaxed);
                                    }
                                }
                                (double_sign_detected, gossip)
                            }; // l dropped — Phase 1 complete

                            if let Some(msg) = ds_gossip {
                                let _ = tx_out.send(msg).await;
                            }
                            if double_sign_detected {
                                continue; // Don't process the original block
                            }

                            // Phase 2: Process incoming block + tracking + auto-receive (all synchronous)
                            let phase2_gossip: Vec<String> = {
                                let mut l = safe_lock(&ledger);
                                let mut msgs = Vec::new();

                                match l.process_block(&inc) {
                                    Ok(block_hash) => {
                                        // 🛡️ SLASHING INTEGRATION: Record block participation for uptime tracking
                                        {
                                            let mut sm = safe_lock(&slashing_clone);
                                            let global_height = l.blocks.len() as u64;
                                            let _ = sm.record_block_participation(&inc.account, global_height, timestamp);

                                            // Check for downtime and slash if needed
                                            if let Some(acc) = l.accounts.get(&inc.account) {
                                                if let Ok(Some(slashed)) = sm.check_and_slash_downtime(
                                                    &inc.account,
                                                    global_height,
                                                    acc.balance,
                                                    timestamp
                                                ) {
                                                    println!("⚖️ Validator {} downtime penalty: {} VOID (1%)",
                                                        get_short_addr(&inc.account), slashed);

                                                    // Create proper Slash block for downtime penalty
                                                    let dt_state = l.accounts.get(&inc.account).cloned().unwrap_or(AccountState {
                                                        head: "0".to_string(), balance: 0, block_count: 0, is_validator: false,
                                                    });
                                                    let mut dt_slash = Block {
                                                        account: inc.account.clone(),
                                                        previous: dt_state.head.clone(),
                                                        block_type: BlockType::Slash,
                                                        amount: slashed,
                                                        link: format!("PENALTY:DOWNTIME:{}", global_height),
                                                        signature: "".to_string(),
                                                        public_key: hex::encode(&keys.public_key),
                                                        work: 0,
                                                        timestamp,
                                                        fee: 0,
                                                    };
                                                    solve_pow(&mut dt_slash);
                                                    dt_slash.signature = hex::encode(
                                                        uat_crypto::sign_message(dt_slash.signing_hash().as_bytes(), &secret_key)
                                                            .expect("BUG: signing failed")
                                                    );
                                                    if l.process_block(&dt_slash).is_ok() {
                                                        msgs.push(serde_json::to_string(&dt_slash).unwrap_or_default());
                                                    }
                                                }
                                            }
                                        }

                                        if inc.block_type == BlockType::Mint {
                                            let burn_val = inc.amount / VOID_PER_UAT;
                                            println!("🔥 Network Mint Verified: +{} UAT", format_u128(burn_val));
                                        }
                                        SAVE_DIRTY.store(true, Ordering::Relaxed);
                                        println!("✅ Block Verified: {:?} from {}", inc.block_type, get_short_addr(&inc.account));

                                        if inc.block_type == BlockType::Send && inc.link == my_address {
                                            if !l.accounts.contains_key(&my_address) {
                                                l.accounts.insert(my_address.clone(), AccountState { head: "0".to_string(), balance: 0, block_count: 0, is_validator: false });
                                            }
                                            if let Some(state) = l.accounts.get(&my_address).cloned() {
                                                let mut rb = Block {
                                                    account: my_address.clone(), previous: state.head, block_type: BlockType::Receive,
                                                    amount: inc.amount, link: block_hash, signature: "".to_string(),
                                                    public_key: hex::encode(&keys.public_key), // Node's public key
                                                    work: 0,
                                                    timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                                                    fee: 0,
                                                };
                                                solve_pow(&mut rb);
                                                rb.signature = hex::encode(uat_crypto::sign_message(rb.signing_hash().as_bytes(), &secret_key).expect("BUG: signing failed — key corrupted"));
                                                if l.process_block(&rb).is_ok() {
                                                    SAVE_DIRTY.store(true, Ordering::Relaxed);
                                                    msgs.push(serde_json::to_string(&rb).unwrap_or_default());
                                                    println!("📥 Incoming Transfer Received Automatically!");
                                                }
                                            }
                                        }
                                    },
                                    Err(e) => {
                                        println!("❌ Block Rejected: {:?} (Sender: {})", e, get_short_addr(&inc.account));
                                    }
                                }
                                msgs
                            }; // l dropped — Phase 2 complete
                            for msg in phase2_gossip {
                                let _ = tx_out.send(msg).await;
                            }
                        }
                    }
            }
            else => {
                // Both stdin (closed/EOF) and network channel (dropped) are inactive.
                // This happens in headless mode (nohup) when the P2P network task
                // hasn't sent any events yet. Sleep briefly and retry — the network
                // task may still produce events.
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    }
    Ok(())
}
