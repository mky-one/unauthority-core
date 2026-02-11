/// Unauthority gRPC Server Implementation
///
/// Provides 8 core gRPC services for external integration:
/// 1. GetBalance - Query account balance
/// 2. GetAccount - Get full account details
/// 3. GetBlock - Get block by hash
/// 4. GetLatestBlock - Get latest finalized block
/// 5. SendTransaction - Broadcast UAT transaction
/// 6. GetNodeInfo - Get node/oracle/supply info
/// 7. GetValidators - List all active validators
/// 8. GetBlockHeight - Get current blockchain height
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;
use tonic::{transport::Server, Request, Response, Status};
use uat_consensus::voting::calculate_voting_power;
use uat_core::{Ledger, MIN_VALIDATOR_STAKE_VOID, VOID_PER_UAT};

// Include generated protobuf code
pub mod proto {
    tonic::include_proto!("unauthority");
}

use proto::{
    uat_node_server::{UatNode, UatNodeServer},
    GetAccountRequest, GetAccountResponse, GetBalanceRequest, GetBalanceResponse,
    GetBlockHeightRequest, GetBlockHeightResponse, GetBlockRequest, GetBlockResponse,
    GetLatestBlockRequest, GetNodeInfoRequest, GetNodeInfoResponse, GetValidatorsRequest,
    GetValidatorsResponse, SendTransactionRequest, SendTransactionResponse, ValidatorInfo,
};

/// gRPC Service Implementation
pub struct UatGrpcService {
    ledger: Arc<Mutex<Ledger>>,
    my_address: String,
    #[allow(dead_code)] // Reserved for future gRPC send_transaction implementation
    tx_sender: mpsc::Sender<String>, // For broadcasting transactions
}

impl UatGrpcService {
    pub fn new(
        ledger: Arc<Mutex<Ledger>>,
        my_address: String,
        tx_sender: mpsc::Sender<String>,
    ) -> Self {
        Self {
            ledger,
            my_address,
            tx_sender,
        }
    }

    /// Helper: Convert short address to full address
    fn resolve_address(&self, addr: &str) -> Option<String> {
        let ledger = self.ledger.lock().ok()?;

        // If already full address, return
        if ledger.accounts.contains_key(addr) {
            return Some(addr.to_string());
        }

        // Try to find by short ID
        ledger
            .accounts
            .keys()
            .find(|k| k.starts_with(addr) || get_short_addr(k) == addr)
            .cloned()
    }
}

/// Helper function to get short address (first 8 chars after prefix)
fn get_short_addr(full: &str) -> String {
    if full.len() > 12 {
        format!("uat_{}", &full[4..12])
    } else {
        full.to_string()
    }
}

#[tonic::async_trait]
impl UatNode for UatGrpcService {
    /// 1. Get account balance
    async fn get_balance(
        &self,
        request: Request<GetBalanceRequest>,
    ) -> Result<Response<GetBalanceResponse>, Status> {
        let addr = request.into_inner().address;

        let full_addr = self
            .resolve_address(&addr)
            .ok_or_else(|| Status::not_found(format!("Address not found: {}", addr)))?;

        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        let account = ledger
            .accounts
            .get(&full_addr)
            .ok_or_else(|| Status::not_found("Account not found"))?;

        // FIX V4#21: Use string formatting to avoid u128→u64 truncation
        let balance_uat = account.balance / VOID_PER_UAT;
        let balance_remainder = account.balance % VOID_PER_UAT;

        let response = GetBalanceResponse {
            address: full_addr,
            balance_void: account.balance as u64, // Legacy field: may truncate >184 UAT
            balance_uat: balance_uat as f64 + (balance_remainder as f64 / VOID_PER_UAT as f64),
            block_count: account.block_count,
            head_block: account.head.clone(),
            balance_void_str: account.balance.to_string(), // Full-precision u128 as string
        };

        println!(
            "📊 gRPC GetBalance: {} -> {}.{} UAT",
            get_short_addr(&response.address),
            balance_uat,
            balance_remainder
        );

        Ok(Response::new(response))
    }

    /// 2. Get full account details
    async fn get_account(
        &self,
        request: Request<GetAccountRequest>,
    ) -> Result<Response<GetAccountResponse>, Status> {
        let addr = request.into_inner().address;

        let full_addr = self
            .resolve_address(&addr)
            .ok_or_else(|| Status::not_found(format!("Address not found: {}", addr)))?;

        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        let account = ledger
            .accounts
            .get(&full_addr)
            .ok_or_else(|| Status::not_found("Account not found"))?;

        // Check if validator (minimum 1,000 UAT stake)
        let min_stake = MIN_VALIDATOR_STAKE_VOID;
        let is_validator = account.balance >= min_stake;

        let response = GetAccountResponse {
            address: full_addr.clone(),
            balance_void: account.balance as u64,
            balance_uat: account.balance as f64 / VOID_PER_UAT as f64,
            block_count: account.block_count,
            head_block: account.head.clone(),
            is_validator,
            stake_void: if is_validator {
                account.balance.min(u64::MAX as u128) as u64
            } else {
                0
            },
            balance_void_str: account.balance.to_string(),
            stake_void_str: if is_validator {
                account.balance.to_string()
            } else {
                "0".to_string()
            },
        };

        println!(
            "🔍 gRPC GetAccount: {} (validator: {})",
            get_short_addr(&full_addr),
            is_validator
        );

        Ok(Response::new(response))
    }

    /// 3. Get block by hash
    async fn get_block(
        &self,
        request: Request<GetBlockRequest>,
    ) -> Result<Response<GetBlockResponse>, Status> {
        let hash = request.into_inner().block_hash;

        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        let block = ledger
            .blocks
            .get(&hash)
            .ok_or_else(|| Status::not_found(format!("Block not found: {}", hash)))?;

        // Get account balance from ledger (Block itself doesn't have balance field)
        let account_balance = ledger
            .accounts
            .get(&block.account)
            .map(|acc| acc.balance.min(u64::MAX as u128) as u64)
            .unwrap_or(0);

        let response = GetBlockResponse {
            block_hash: hash.clone(),
            account: block.account.clone(),
            previous_block: block.previous.clone(),
            link: block.link.clone(),
            block_type: format!("{:?}", block.block_type),
            amount: block.amount.min(u64::MAX as u128) as u64,
            balance: account_balance, // Account balance, not block balance
            signature: block.signature.clone(),
            timestamp: block.timestamp,     // Use actual block timestamp
            representative: "".to_string(), // Not implemented yet
        };

        println!(
            "📦 gRPC GetBlock: {} (type: {})",
            &hash[..12],
            response.block_type
        );

        Ok(Response::new(response))
    }

    /// 4. Get latest block (by highest timestamp)
    async fn get_latest_block(
        &self,
        _request: Request<GetLatestBlockRequest>,
    ) -> Result<Response<GetBlockResponse>, Status> {
        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        // FIX V4#20: Find ACTUAL latest block by timestamp (not random HashMap entry)
        let latest = ledger
            .blocks
            .iter()
            .max_by_key(|(_, block)| block.timestamp)
            .ok_or_else(|| Status::not_found("No blocks found"))?;

        let (hash, block) = latest;

        // Get account balance from ledger
        let account_balance = ledger
            .accounts
            .get(&block.account)
            .map(|acc| acc.balance.min(u64::MAX as u128) as u64)
            .unwrap_or(0);

        let response = GetBlockResponse {
            block_hash: hash.clone(),
            account: block.account.clone(),
            previous_block: block.previous.clone(),
            link: block.link.clone(),
            block_type: format!("{:?}", block.block_type),
            amount: block.amount.min(u64::MAX as u128) as u64,
            balance: account_balance,
            signature: block.signature.clone(),
            timestamp: block.timestamp,
            representative: "".to_string(),
        };

        println!(
            "🆕 gRPC GetLatestBlock: {} (ts: {})",
            &hash[..12.min(hash.len())],
            block.timestamp
        );

        Ok(Response::new(response))
    }

    /// 5. Send transaction
    /// NOTE: Transaction submission requires client-side signing, PoW, anti-whale checks,
    /// and consensus flow (CONFIRM_REQ/VOTE_REQ). Use the REST API POST /send endpoint
    /// which handles all of these. gRPC querying endpoints (GetBalance, GetBlock, etc.) are fully functional.
    async fn send_transaction(
        &self,
        _request: Request<SendTransactionRequest>,
    ) -> Result<Response<SendTransactionResponse>, Status> {
        // V4#8 FIX: Return UNIMPLEMENTED instead of silently dropping transactions.
        // The REST API at POST /send handles the full transaction flow:
        // 1. Client-side Dilithium5 signing
        // 2. Proof-of-Work computation
        // 3. Anti-whale fee scaling
        // 4. CONFIRM_REQ → VOTE_REQ → VOTE_RES → CONFIRM_RES consensus
        // 5. Auto-Receive for recipient
        //
        // gRPC send will be properly implemented when we add streaming support
        // for consensus feedback (estimated finality, vote progress, etc.)
        Err(Status::unimplemented(
            "SendTransaction is not available via gRPC. Use REST API POST /send endpoint which handles \
             Dilithium5 signing, PoW, anti-whale fees, and aBFT consensus flow. \
             All gRPC query endpoints (GetBalance, GetBlock, GetValidators, etc.) are fully functional."
        ))
    }

    /// 6. Get node info
    async fn get_node_info(
        &self,
        _request: Request<GetNodeInfoRequest>,
    ) -> Result<Response<GetNodeInfoResponse>, Status> {
        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        // Check if this node is validator
        let is_validator = ledger
            .accounts
            .get(&self.my_address)
            .map(|a| a.balance >= MIN_VALIDATOR_STAKE_VOID)
            .unwrap_or(false);

        // Oracle prices not available in gRPC context (use REST /oracle endpoint)
        // Return 0 to indicate no data rather than misleading hardcoded values
        let eth_price = 0.0_f64;
        let btc_price = 0.0_f64;

        // Calculate latest block height (count total blocks)
        let latest_height = ledger.blocks.len() as u64;

        let response = GetNodeInfoResponse {
            node_address: self.my_address.clone(),
            network_id: uat_core::CHAIN_ID as u32, // CHAIN_ID: 1=mainnet, 2=testnet
            chain_name: "Unauthority".to_string(),
            version: "0.1.0".to_string(),
            // FIX C11-M4: Use .min() saturation instead of hard-coding 0
            // u128 total supply overflows u64 — cap at u64::MAX for legacy field
            total_supply_void: (21_936_236u128 * uat_core::VOID_PER_UAT).min(u64::MAX as u128)
                as u64,
            remaining_supply_void: (ledger.distribution.remaining_supply).min(u64::MAX as u128)
                as u64,
            total_burned_usd: (ledger.distribution.total_burned_usd).min(u64::MAX as u128) as u64,
            eth_price_usd: eth_price,
            btc_price_usd: btc_price,
            peer_count: 0, // TODO: Get from P2P layer
            latest_block_height: latest_height,
            is_validator,
        };

        println!(
            "ℹ️  gRPC GetNodeInfo: {} (validator: {})",
            get_short_addr(&self.my_address),
            is_validator
        );

        Ok(Response::new(response))
    }

    /// 7. Get validators list
    async fn get_validators(
        &self,
        _request: Request<GetValidatorsRequest>,
    ) -> Result<Response<GetValidatorsResponse>, Status> {
        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        let min_stake = MIN_VALIDATOR_STAKE_VOID;

        // Filter accounts with minimum stake
        let validators: Vec<ValidatorInfo> = ledger
            .accounts
            .iter()
            .filter(|(_, acc)| acc.balance >= min_stake)
            .map(|(addr, acc)| {
                // Quadratic voting power: deterministic integer sqrt
                // SECURITY FIX: Use consensus isqrt() instead of f64 sqrt()
                // to ensure gRPC API returns same values as consensus engine.
                let voting_power = calculate_voting_power(acc.balance) as f64;

                ValidatorInfo {
                    address: addr.clone(),
                    // FIX C11-C3: .min() guard prevents wrapping on balances > u64::MAX
                    stake_void: acc.balance.min(u64::MAX as u128) as u64,
                    is_active: true, // TODO: Check uptime
                    voting_power,
                    rewards_earned: 0,     // TODO: Track from gas fees
                    uptime_percent: 100.0, // TODO: Calculate from monitoring
                }
            })
            .collect();

        let total_count = validators.len() as u32;

        println!("👥 gRPC GetValidators: {} active validators", total_count);

        let response = GetValidatorsResponse {
            validators,
            total_count,
        };

        Ok(Response::new(response))
    }

    /// 8. Get block height
    async fn get_block_height(
        &self,
        _request: Request<GetBlockHeightRequest>,
    ) -> Result<Response<GetBlockHeightResponse>, Status> {
        let ledger = self
            .ledger
            .lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;

        // Find latest block by timestamp (or use total count as height)
        let total_blocks = ledger.blocks.len() as u64;

        let latest_hash = ledger
            .blocks
            .iter()
            .max_by_key(|(_, b)| b.timestamp)
            .map(|(h, _)| h.clone())
            .unwrap_or_else(|| "0".to_string());

        let response = GetBlockHeightResponse {
            height: total_blocks,
            latest_block_hash: latest_hash,
            timestamp: chrono::Utc::now().timestamp() as u64,
        };

        println!("📏 gRPC GetBlockHeight: {}", response.height);

        Ok(Response::new(response))
    }
}

/// Start gRPC server (runs alongside REST API)
pub async fn start_grpc_server(
    ledger: Arc<Mutex<Ledger>>,
    my_address: String,
    tx_sender: mpsc::Sender<String>,
    grpc_port: u16,
) -> Result<(), Box<dyn std::error::Error>> {
    // FIX: Respect UAT_BIND_ALL env for Tor safety (same as REST API)
    let bind_addr = if std::env::var("UAT_BIND_ALL").unwrap_or_default() == "1" {
        format!("0.0.0.0:{}", grpc_port)
    } else {
        format!("127.0.0.1:{}", grpc_port)
    };
    let addr = bind_addr.parse()?;

    let service = UatGrpcService::new(ledger, my_address.clone(), tx_sender);

    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("🚀 gRPC Server STARTED");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("   Address: {}", addr);
    println!("   Node: {}", get_short_addr(&my_address));
    println!("   Services: 8 core gRPC endpoints");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    Server::builder()
        .add_service(UatNodeServer::new(service))
        .serve(addr)
        .await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use uat_core::AccountState;

    #[tokio::test]
    async fn test_grpc_get_balance() {
        let mut ledger = Ledger::new();
        ledger.accounts.insert(
            "test_address".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 500 * VOID_PER_UAT,
                block_count: 0,
                is_validator: false,
            },
        );

        let ledger = Arc::new(Mutex::new(ledger));
        let (tx, _rx) = mpsc::channel(1);

        let service = UatGrpcService::new(ledger, "node_address".to_string(), tx);

        let request = Request::new(GetBalanceRequest {
            address: "test_address".to_string(),
        });

        let response = service.get_balance(request).await.unwrap();
        let balance = response.into_inner();

        assert_eq!(balance.address, "test_address");
        assert_eq!(balance.balance_void, (500 * VOID_PER_UAT) as u64);
        assert_eq!(balance.balance_uat, 500.0);
    }

    #[tokio::test]
    async fn test_grpc_get_validators() {
        let mut ledger = Ledger::new();

        // Add 2 validators (min 1,000 UAT)
        ledger.accounts.insert(
            "validator1".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 5000 * VOID_PER_UAT,
                block_count: 0,
                is_validator: true,
            },
        );
        ledger.accounts.insert(
            "validator2".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 10000 * VOID_PER_UAT,
                block_count: 0,
                is_validator: true,
            },
        );

        // Add 1 non-validator (below min stake)
        ledger.accounts.insert(
            "regular_user".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 100 * VOID_PER_UAT,
                block_count: 0,
                is_validator: false,
            },
        );

        let ledger = Arc::new(Mutex::new(ledger));
        let (tx, _rx) = mpsc::channel(1);

        let service = UatGrpcService::new(ledger, "node".to_string(), tx);

        let request = Request::new(GetValidatorsRequest {});
        let response = service.get_validators(request).await.unwrap();
        let validators = response.into_inner();

        // Should return only 2 validators (min 1,000 UAT stake)
        assert_eq!(validators.total_count, 2);
        assert_eq!(validators.validators.len(), 2);

        // Check quadratic voting power
        let val1 = &validators.validators[0];
        assert!(val1.voting_power > 0.0);
        assert!(val1.is_active);
    }
}
