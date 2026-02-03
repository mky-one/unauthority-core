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
use tonic::{transport::Server, Request, Response, Status};
use tokio::sync::mpsc;
use uat_core::{Ledger, VOID_PER_UAT};

// Include generated protobuf code
pub mod proto {
    tonic::include_proto!("unauthority");
}

use proto::{
    uat_node_server::{UatNode, UatNodeServer},
    GetBalanceRequest, GetBalanceResponse,
    GetAccountRequest, GetAccountResponse,
    GetBlockRequest, GetBlockResponse,
    GetLatestBlockRequest,
    SendTransactionRequest, SendTransactionResponse,
    GetNodeInfoRequest, GetNodeInfoResponse,
    GetValidatorsRequest, GetValidatorsResponse, ValidatorInfo,
    GetBlockHeightRequest, GetBlockHeightResponse,
};

/// gRPC Service Implementation
pub struct UatGrpcService {
    ledger: Arc<Mutex<Ledger>>,
    my_address: String,
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
        ledger.accounts
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
        
        let full_addr = self.resolve_address(&addr)
            .ok_or_else(|| Status::not_found(format!("Address not found: {}", addr)))?;
        
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        let account = ledger.accounts.get(&full_addr)
            .ok_or_else(|| Status::not_found("Account not found"))?;
        
        let response = GetBalanceResponse {
            address: full_addr,
            balance_void: account.balance as u64,
            balance_uat: account.balance as f64 / VOID_PER_UAT as f64,
            block_count: account.block_count as u64,
            head_block: account.head.clone(),
        };
        
        println!("📊 gRPC GetBalance: {} -> {} UAT", 
            get_short_addr(&response.address), response.balance_uat);
        
        Ok(Response::new(response))
    }

    /// 2. Get full account details
    async fn get_account(
        &self,
        request: Request<GetAccountRequest>,
    ) -> Result<Response<GetAccountResponse>, Status> {
        let addr = request.into_inner().address;
        
        let full_addr = self.resolve_address(&addr)
            .ok_or_else(|| Status::not_found(format!("Address not found: {}", addr)))?;
        
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        let account = ledger.accounts.get(&full_addr)
            .ok_or_else(|| Status::not_found("Account not found"))?;
        
        // Check if validator (minimum 1,000 UAT stake)
        let min_stake = 1000 * VOID_PER_UAT;
        let is_validator = account.balance >= min_stake;
        
        let response = GetAccountResponse {
            address: full_addr.clone(),
            balance_void: account.balance as u64,
            balance_uat: account.balance as f64 / VOID_PER_UAT as f64,
            block_count: account.block_count as u64,
            head_block: account.head.clone(),
            is_validator,
            stake_void: if is_validator { account.balance as u64 } else { 0 },
        };
        
        println!("🔍 gRPC GetAccount: {} (validator: {})", 
            get_short_addr(&full_addr), is_validator);
        
        Ok(Response::new(response))
    }

    /// 3. Get block by hash
    async fn get_block(
        &self,
        request: Request<GetBlockRequest>,
    ) -> Result<Response<GetBlockResponse>, Status> {
        let hash = request.into_inner().block_hash;
        
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        let block = ledger.blocks.get(&hash)
            .ok_or_else(|| Status::not_found(format!("Block not found: {}", hash)))?;
        
        // Get account balance from ledger (Block itself doesn't have balance field)
        let account_balance = ledger.accounts
            .get(&block.account)
            .map(|acc| acc.balance as u64)
            .unwrap_or(0);
        
        let response = GetBlockResponse {
            block_hash: hash.clone(),
            account: block.account.clone(),
            previous_block: block.previous.clone(),
            link: block.link.clone(),
            block_type: format!("{:?}", block.block_type),
            amount: block.amount as u64,
            balance: account_balance, // Account balance, not block balance
            signature: block.signature.clone(),
            timestamp: chrono::Utc::now().timestamp() as u64,
            representative: "".to_string(), // Not implemented yet
        };
        
        println!("📦 gRPC GetBlock: {} (type: {})", 
            &hash[..12], response.block_type);
        
        Ok(Response::new(response))
    }

    /// 4. Get latest block
    async fn get_latest_block(
        &self,
        _request: Request<GetLatestBlockRequest>,
    ) -> Result<Response<GetBlockResponse>, Status> {
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        // Find latest block (just get first for now - simplified)
        let latest = ledger.blocks
            .iter()
            .next()
            .ok_or_else(|| Status::not_found("No blocks found"))?;
        
        let (hash, block) = latest;
        
        // Get account balance from ledger
        let account_balance = ledger.accounts
            .get(&block.account)
            .map(|acc| acc.balance as u64)
            .unwrap_or(0);
        
        let response = GetBlockResponse {
            block_hash: hash.clone(),
            account: block.account.clone(),
            previous_block: block.previous.clone(),
            link: block.link.clone(),
            block_type: format!("{:?}", block.block_type),
            amount: block.amount as u64,
            balance: account_balance,
            signature: block.signature.clone(),
            timestamp: chrono::Utc::now().timestamp() as u64,
            representative: "".to_string(), // Not implemented
        };
        
        println!("🆕 gRPC GetLatestBlock: {}", &hash[..12]);
        
        Ok(Response::new(response))
    }

    /// 5. Send transaction
    async fn send_transaction(
        &self,
        request: Request<SendTransactionRequest>,
    ) -> Result<Response<SendTransactionResponse>, Status> {
        let req = request.into_inner();
        
        // Validate amount
        if req.amount_void == 0 {
            return Err(Status::invalid_argument("Amount must be greater than 0"));
        }
        
        // Resolve addresses
        let from = self.resolve_address(&req.from)
            .ok_or_else(|| Status::not_found("Sender address not found"))?;
        
        let to = self.resolve_address(&req.to)
            .ok_or_else(|| Status::not_found("Recipient address not found"))?;
        
        // Check balance
        {
            let ledger = self.ledger.lock()
                .map_err(|_| Status::internal("Failed to lock ledger"))?;
            
            let sender_balance = ledger.accounts
                .get(&from)
                .map(|a| a.balance)
                .unwrap_or(0);
            
            if sender_balance < req.amount_void as u128 {
                return Err(Status::failed_precondition(
                    format!("Insufficient balance: {} < {}", sender_balance, req.amount_void)
                ));
            }
        }
        
        // Broadcast transaction via P2P
        let tx_msg = format!("SEND:{}:{}:{}", from, to, req.amount_void);
        
        self.tx_sender.send(tx_msg).await
            .map_err(|e| Status::internal(format!("Failed to broadcast: {}", e)))?;
        
        // Generate tx hash (simplified - in production use proper hash)
        let tx_hash = format!("TX_{}", chrono::Utc::now().timestamp());
        
        let response = SendTransactionResponse {
            success: true,
            tx_hash: tx_hash.clone(),
            message: "Transaction broadcasted to network".to_string(),
            estimated_finality_ms: 3000, // aBFT consensus ~3 seconds
        };
        
        println!("💸 gRPC SendTransaction: {} -> {} ({} UAT) [{}]",
            get_short_addr(&from),
            get_short_addr(&to),
            req.amount_void as f64 / VOID_PER_UAT as f64,
            &tx_hash[..12]
        );
        
        Ok(Response::new(response))
    }

    /// 6. Get node info
    async fn get_node_info(
        &self,
        _request: Request<GetNodeInfoRequest>,
    ) -> Result<Response<GetNodeInfoResponse>, Status> {
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        // Check if this node is validator
        let is_validator = ledger.accounts
            .get(&self.my_address)
            .map(|a| a.balance >= 1000 * VOID_PER_UAT)
            .unwrap_or(false);
        
        // TODO: Get real oracle prices from consensus
        let eth_price = 50_000_000.0; // Placeholder
        let btc_price = 1_000_000_000.0; // Placeholder
        
        // Calculate latest block height (count total blocks)
        let latest_height = ledger.blocks.len() as u64;
        
        let response = GetNodeInfoResponse {
            node_address: self.my_address.clone(),
            network_id: 1, // 1 = mainnet
            chain_name: "Unauthority".to_string(),
            version: "0.1.0".to_string(),
            total_supply_void: (21_936_236 * VOID_PER_UAT) as u64,
            remaining_supply_void: ledger.distribution.remaining_supply as u64,
            total_burned_usd: ledger.distribution.total_burned_usd as u64,
            eth_price_usd: eth_price,
            btc_price_usd: btc_price,
            peer_count: 0, // TODO: Get from P2P layer
            latest_block_height: latest_height,
            is_validator,
        };
        
        println!("ℹ️  gRPC GetNodeInfo: {} (validator: {})", 
            get_short_addr(&self.my_address), is_validator);
        
        Ok(Response::new(response))
    }

    /// 7. Get validators list
    async fn get_validators(
        &self,
        _request: Request<GetValidatorsRequest>,
    ) -> Result<Response<GetValidatorsResponse>, Status> {
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        let min_stake = 1000 * VOID_PER_UAT;
        
        // Filter accounts with minimum stake
        let validators: Vec<ValidatorInfo> = ledger.accounts
            .iter()
            .filter(|(_, acc)| acc.balance >= min_stake)
            .map(|(addr, acc)| {
                // Quadratic voting power: sqrt(stake)
                let voting_power = (acc.balance as f64 / VOID_PER_UAT as f64).sqrt();
                
                ValidatorInfo {
                    address: addr.clone(),
                    stake_void: acc.balance as u64,
                    is_active: true, // TODO: Check uptime
                    voting_power,
                    rewards_earned: 0, // TODO: Track from gas fees
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
        let ledger = self.ledger.lock()
            .map_err(|_| Status::internal("Failed to lock ledger"))?;
        
        // Find latest block by timestamp (or use total count as height)
        let total_blocks = ledger.blocks.len() as u64;
        
        let latest_hash = ledger.blocks
            .keys()
            .next()
            .cloned()
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
    let addr = format!("0.0.0.0:{}", grpc_port).parse()?;
    
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
            },
        );
        
        let ledger = Arc::new(Mutex::new(ledger));
        let (tx, _rx) = mpsc::channel(1);
        
        let service = UatGrpcService::new(
            ledger,
            "node_address".to_string(),
            tx,
        );
        
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
            },
        );
        ledger.accounts.insert(
            "validator2".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 10000 * VOID_PER_UAT,
                block_count: 0,
            },
        );
        
        // Add 1 non-validator (below min stake)
        ledger.accounts.insert(
            "regular_user".to_string(),
            AccountState {
                head: "genesis".to_string(),
                balance: 100 * VOID_PER_UAT,
                block_count: 0,
            },
        );
        
        let ledger = Arc::new(Mutex::new(ledger));
        let (tx, _rx) = mpsc::channel(1);
        
        let service = UatGrpcService::new(
            ledger,
            "node".to_string(),
            tx,
        );
        
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
