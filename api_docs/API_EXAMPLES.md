# UAT API Examples & Usage Guide

Comprehensive examples for all 13 REST API endpoints with real-world use cases.

---

## Base Configuration

```bash
# Production/Testnet
export UAT_API="<domain testnet/mainnet>"

# Available endpoints:
# Testnet (Tor): http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion
# Mainnet (TBD): Coming Q2 2026
# Local Dev:     http://localhost:3030
```

**Example:**
```bash
# For Tor testnet (requires torsocks)
export UAT_API="http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion"

# For local development
export UAT_API="http://localhost:3030"
```

---

## 1. Node Information & Health

### 1.1 Get Node Info
Returns node metadata, version, sync status, and network info.

**Request:**
```bash
curl "${UAT_API}/node-info"

# Or with torsocks for Tor testnet:
torsocks curl "${UAT_API}/node-info"
```

**Response:**
```json
{
  "node_id": "uat_0f0728fd",
  "version": "1.0.0",
  "chain": "uat-mainnet",
  "consensus": "aBFT",
  "block_height": 15234,
  "latest_block_hash": "0xabcd1234...",
  "validators": 128,
  "active_validators": 121,
  "total_accounts": 1523,
  "total_supply_uat": 21936236,
  "peer_count": 47,
  "uptime_seconds": 3600
}
```

**Use Cases:**
- Health monitoring for load balancers
- Sync status verification before sending transactions
- Network statistics for dashboards
- Validator performance tracking

---

### 1.2 Health Check
Quick health status for monitoring systems.

**Request:**
```bash
curl "${UAT_API}/health"
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "timestamp": 1738742400,
  "chain": {
    "id": "uat-mainnet",
    "blocks": 15234,
    "accounts": 1523
  },
  "database": {
    "size_on_disk": 524287000,
    "blocks_count": 15234,
    "accounts_count": 1523
  }
}
```

**Use Cases:**
- Load balancer health checks
- Kubernetes liveness/readiness probes
- Uptime monitoring (Pingdom, UptimeRobot)
- Automated alerting systems

---

## 2. Balance & Account Operations

### 2.1 Get Balance
Query UAT balance for any address.

---

## 3. Transaction Operations

### 3.1 Send Transaction
Transfer UAT between accounts.

**Request:**
```bash
curl -X POST "${UAT_API}/send" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
    "target": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
    "amount": 1000000,
    "signature": "0xsig123..."
  }'
```

**Request Fields:**
- `from` (optional): Sender address (defaults to node's address)
- `target` (required): Recipient address  
- `amount` (required): Amount in VOID (1 UAT = 1,000,000 VOID)
- `signature` (optional): Pre-signed transaction signature
- `previous` (optional): Previous block hash
- `work` (optional): PoW nonce

**Response (Success):**
```json
{
  "success": true,
  "tx_hash": "0xtx123...",
  "block_height": 12346,
  "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "to": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
  "amount_uat": 1,
  "fee_uat": 0.01,
  "timestamp": 1738742450
}
```

**Response (Error - Insufficient Balance):**
```json
{
  "success": false,
  "error": "Insufficient balance",
  "required": 1000000,
  "available": 500000
}
```

**Use Cases:**
- Peer-to-peer payments
- Exchange withdrawals
- Merchant payments
- Smart contract interactions

---

### 3.2 Request Testnet Tokens (Faucet)
Get 100 UAT for testing (1-hour cooldown).

**Request:**
```bash
curl -X POST "${UAT_API}/faucet" \
  -H "Content-Type: application/json" \
  -d '{"address":"UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"}'
```

**Response (Success):**
```json
{
  "success": true,
  "amount_uat": 100,
  "tx_hash": "0xfaucet123...",
  "cooldown_seconds": 3600,
  "next_request_at": 1738746000
}
```

**Response (Cooldown Active):**
```json
{
  "success": false,
  "error": "Cooldown active",
  "remaining_seconds": 2400,
  "next_request_at": 1738746000
}
```

**Limits:**
- 100 UAT per request
- 1-hour cooldown per address  
- Max 10 requests per IP per day

**Use Cases:**
- New wallet testing
- dApp development
- Integration testing
- Demo applications

**Response:**
```json
{
  "address": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "balance_uat": 19194200,
  "balance_void": 19194200000000,
  "nonce": 42
}
```

**Conversion:**
- 1 UAT = 1,000,000 VOID (6 decimals)
- Example: `19194200000000 VOID = 19,194,200 UAT`

**Error Response:**
```json
{
  "error": "Account not found",
  "address": "UAT1invalid...",
  "balance_uat": 0
}
```

**Use Cases:**
- Wallet balance display
- Transaction validation (check sufficient balance)
- Exchange deposit/withdrawal verification
- Portfolio tracking

---

### 2.2 Get Full Account Info
Combines balance + transaction history in one call.

**Request:**
```bash
curl "${UAT_API}/account/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"
```

**Response:**
```json
{
  "address": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "balance_uat": 19194200,
  "balance_void": 19194200000000,
  "nonce": 42,
  "transactions": [
    {
      "type": "receive",
      "from": "genesis",
      "amount_uat": 19194200,
      "timestamp": 1738742000,
      "block_height": 0
    },
    {
      "type": "send",
      "to": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
      "amount_uat": 100,
      "timestamp": 1738742400,
      "block_height": 1234
    }
  ],
  "tx_count": 2
}
```

**Use Cases:**
- Wallet dashboard (balance + recent activity)
- Account overview page
- Export transaction history
- Tax reporting

---

### 2.3 Get Transaction History
Detailed transaction history for an address.

**Request:**
```bash
curl "${UAT_API}/history/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"
```

**Response:**
```json
{
  "address": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "transactions": [
    {
      "type": "send",
      "to": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
      "amount_uat": 100,
      "timestamp": 1738742400,
      "tx_hash": "0xabcd...",
      "block_height": 1234,
      "status": "confirmed"
    },
    {
      "type": "receive",
      "from": "faucet",
      "amount_uat": 100,
      "timestamp": 1738742000,
      "tx_hash": "0xdef0...",
      "block_height": 1200
    }
  ],
  "total_sent_uat": 100,
  "total_received_uat": 19194300,
  "tx_count": 2
}
```

**Use Cases:**
- Transaction history page in wallet
- CSV export for accounting
- Audit trail
- Payment verification

---

## 3. Transaction Operations

### 3.1 Send Transaction
Transfer UAT between accounts.

**Request:**
```bash
curl -X POST "${UAT_API}/send" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
    "target": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
    "amount": 1000000,
    "signature": "0xsig123..."
  }'
```

**Request Fields:**
- `from` (optional): Sender address (defaults to node's address)
- `target` (required): Recipient address  
- `amount` (required): Amount in VOID (1 UAT = 1,000,000 VOID)
- `signature` (optional): Pre-signed transaction signature
- `previous` (optional): Previous block hash
- `work` (optional): PoW nonce

**Response (Success):**
```json
{
  "success": true,
  "tx_hash": "0xtx123...",
  "block_height": 12346,
  "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "to": "UAT387d447f008fae00f012877b8ffbb49e0aadddd7",
  "amount_uat": 1,
  "fee_uat": 0.01,
  "timestamp": 1738742450
}
```

**Response (Error - Insufficient Balance):**
```json
{
  "success": false,
  "error": "Insufficient balance",
  "required": 1000000,
  "available": 500000
}
```

**Use Cases:**
- Peer-to-peer payments
- Exchange withdrawals
- Merchant payments
- Smart contract interactions

---

### 3.2 Request Testnet Tokens (Faucet)
Get 100 UAT for testing (1-hour cooldown).

**Request:**
```bash
curl -X POST "${UAT_API}/faucet" \
  -H "Content-Type: application/json" \
  -d '{"address":"UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"}'
```

**Response (Success):**
```json
{
  "success": true,
  "amount_uat": 100,
  "tx_hash": "0xfaucet123...",
  "cooldown_seconds": 3600,
  "next_request_at": 1738746000
}
```

**Response (Cooldown Active):**
```json
{
  "success": false,
  "error": "Cooldown active",
  "remaining_seconds": 2400,
  "next_request_at": 1738746000
}
```

**Limits:**
- 100 UAT per request
- 1-hour cooldown per address  
- Max 10 requests per IP per day

**Use Cases:**
- New wallet testing
- dApp development
- Integration testing
- Demo applications

---

### 3.3 Proof-of-Burn (ETH/BTC → UAT)
Convert burned ETH/BTC to UAT.

**Request:**
```bash
curl -X POST "${UAT_API}/burn" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
    "chain": "ethereum",
    "tx_hash": "0xeth_burn_tx...",
    "amount_eth": "0.1"
  }'
```

**Request Fields:**
- `from`: UAT address to receive burned tokens
- `chain`: "ethereum" or "bitcoin"
- `tx_hash`: ETH/BTC burn transaction hash
- `amount_eth` / `amount_btc`: Amount burned

**ETH Burn Address:** `0x000000000000000000000000000000000000dEaD`  
**BTC Burn Address:** `1BitcoinEaterAddressDontSendf59kuE`

**Response (Success):**
```json
{
  "success": true,
  "uat_minted": 1000,
  "burn_tx": "0xeth_burn_tx...",
  "uat_tx": "0xuat_mint_tx...",
  "verification_blocks": 12,
  "status": "confirmed"
}
```

**Response (Pending):**
```json
{
  "success": false,
  "status": "pending",
  "confirmations": 5,
  "required_confirmations": 12,
  "estimated_completion": "~10 minutes"
}
```

**Conversion Rates:**
- ETH: Dynamic based on oracle price
- BTC: Dynamic based on oracle price
- Min burn: 0.01 ETH or 0.001 BTC

**Use Cases:**
- Convert ETH/BTC holdings to UAT
- Participate in deflationary tokenomics
- Multi-chain liquidity bridging

---

## 4. Network & Validator Operations

### 4.1 List Active Validators
Get all validators with stakes and performance metrics.

**Request:**
```bash
curl "${UAT_API}/validators"
```

**Response:**
```json
{
  "validators": [
    {
      "address": "UAT9e6ed5183acbb802aba83e31420c6dc96d976405",
      "stake_uat": 100000,
      "voting_power": 316.22,
      "uptime": 99.9,
      "blocks_proposed": 1234,
      "last_active": 1738742400,
      "status": "active"
    },
    {
      "address": "UAT3f8ff6ffc3e9161964b5ff4cf288b87e99c456fe",
      "stake_uat": 50000,
      "voting_power": 223.60,
      "uptime": 98.5,
      "blocks_proposed": 987,
      "last_active": 1738742380,
      "status": "active"
    }
  ],
  "total_validators": 128,
  "active_validators": 121,
  "total_stake_uat": 2193623600
}
```

**Voting Power Formula:**
- Quadratic: `voting_power = sqrt(stake_uat)`
- Example: `sqrt(100000) = 316.22`

**Use Cases:**
- Validator selection for delegation
- Network health monitoring
- Performance tracking
- Reward distribution calculation

---

### 4.2 Get Connected Peers
List all connected peer nodes in the network.

**Request:**
```bash
curl "${UAT_API}/peers"
```

**Response:**
```json
{
  "peers": [
    {
      "peer_id": "12D3KooWAbc123...",
      "address": "/ip4/1.2.3.4/tcp/30303",
      "type": "clearnet",
      "latency_ms": 45,
      "connected_since": 1738740000,
      "is_validator": true
    },
    {
      "peer_id": "12D3KooWXyz789...",
      "address": "/onion3/abc123...xyz.onion/tcp/30303",
      "type": "tor",
      "latency_ms": 250,
      "connected_since": 1738741000,
      "is_validator": false
    }
  ],
  "total_peers": 47,
  "clearnet_peers": 25,
  "tor_peers": 22
}
```

**Use Cases:**
- Network topology visualization
- Peer latency monitoring
- Tor vs clearnet ratio analysis
- Connection debugging

---

## 5. Block & Blockchain Queries

### 5.1 Get Latest Block
Retrieve the most recent block.

**Request:**
```bash
curl "${UAT_API}/block"
```

**Response:**
```json
{
  "height": 12345,
  "hash": "0xblock123...",
  "previous_hash": "0xblock122...",
  "timestamp": 1738742400,
  "validator": "UAT9e6ed5183acbb802aba83e31420c6dc96d976405",
  "transactions": 24,
  "total_volume_uat": 15420,
  "state_root": "0xstate...",
  "size_bytes": 8192
}
```

---

### 5.2 Get Block by Height
Query specific block by height number.

**Request:**
```bash
curl "${UAT_API}/block/1000"
```

**Response:**
```json
{
  "height": 1000,
  "hash": "0xblock1000...",
  "previous_hash": "0xblock999...",
  "timestamp": 1738640000,
  "validator": "UAT3f8ff6ffc3e9161964b5ff4cf288b87e99c456fe",
  "transactions": [
    {
      "tx_hash": "0xtx1...",
      "from": "UAT0d15ab...",
      "to": "UAT387d44...",
      "amount_uat": 100
    }
  ],
  "tx_count": 15,
  "state_root": "0xstate1000..."
}
```

**Use Cases:**
- Block explorer
- Historical data analysis
- Audit trail verification
- Transaction confirmation
```

**Transaction Status:**
- `"pending"` - In mempool, not yet included in block
- `"confirmed"` - Included in finalized block
- `"failed"` - Execution failed (check error field)

---

### Get Account Transactions
Fetch transaction history for an address.

**Request:**
```bash
# Get last 50 transactions (default)
curl -X GET "${UAT_API}/account/UAT1abc.../transactions"

# Paginated results
curl -X GET "${UAT_API}/account/UAT1abc.../transactions?limit=100&offset=50"

# Filter by type
curl -X GET "${UAT_API}/account/UAT1abc.../transactions?type=sent"
curl -X GET "${UAT_API}/account/UAT1abc.../transactions?type=received"
```

**Response:**
```json
{
  "address": "UAT1abc...",
  "total_transactions": 342,
  "transactions": [
    {
      "tx_hash": "0xaaa...",
      "type": "sent",
      "from": "UAT1abc...",
      "to": "UAT2def...",
      "amount": 50000000000,
      "fee_paid": 21000000,
      "block_height": 15240,
      "timestamp": 1738714000,
      "status": "confirmed"
    },
    {
      "tx_hash": "0xbbb...",
      "type": "received",
      "from": "UAT3ghi...",
      "to": "UAT1abc...",
      "amount": 200000000000,
      "fee_paid": 21000000,
      "block_height": 15238,
      "timestamp": 1738713800,
      "status": "confirmed"
    }
  ]
}
```

---

## 4. Block Operations

### Get Block by Height
Retrieve full block data including all transactions.

**Request:**
```bash
# Specific block
curl -X GET "${UAT_API}/block/15235"

# Latest block
curl -X GET "${UAT_API}/block/latest"
```

**Response:**
```json
{
  "height": 15235,
  "hash": "0xblock123...",
  "previous_hash": "0xblock122...",
  "timestamp": 1738713600,
  "validator": "UAT_validator1...",
  "transactions_count": 87,
  "transactions": [
    {
      "tx_hash": "0xtx1...",
      "from": "UAT1...",
      "to": "UAT2...",
      "amount": 100000000000
    }
  ],
  "gas_used": 1827000,
  "gas_limit": 10000000,
  "rewards": {
    "validator_reward": 1827000,
    "block_subsidy": 0
  },
  "signature": "0xsig...",
  "finalized": true
}
```

**Query Parameters:**
- `include_transactions=false` - Exclude tx details for faster response
- `format=compact` - Return minimal block metadata only

---

## 4. Block Operations

(Already documented - see API_REFERENCE.md for GET /block and GET /block/:height)

---

## 5. Validator Operations

(Already documented - see API_REFERENCE.md for GET /validators)

---

## 6. Smart Contract Operations

### 6.1 Deploy Contract
Upload WASM bytecode to blockchain.

**Request:**
```bash
curl -X POST "${UAT_API}/deploy-contract" \
  -H "Content-Type: application/json" \
  -d '{
    "bytecode": "0x0061736d01000000...",
    "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
    "initial_balance": 1000000,
    "gas_limit": 5000000
  }'
```

**Response:**
```json
{
  "success": true,
  "contract_address": "UATc1a2b3c4d5e6f7890abcdef1234567890abcde",
  "tx_hash": "0xdeploy123...",
  "gas_used": 2500000
}
```

---

### 6.2 Call Contract
Execute contract function.

**Request:**
```bash
curl -X POST "${UAT_API}/call-contract" \
  -H "Content-Type: application/json" \
  -d '{
    "contract": "UATc1a2b3c4d5e6f7890abcdef1234567890abcde",
    "method": "transfer",
    "args": ["UAT387d447f...", "1000000"],
    "from": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
    "gas_limit": 100000
  }'
```

**Response:**
```json
{
  "success": true,
  "result": "true",
  "gas_used": 45000,
  "tx_hash": "0xcall123..."
}
```

---

### 6.3 Query Contract
Read contract state (no gas).

**Request:**
```bash
curl "${UAT_API}/contract/UATc1a2b3c4d5e6f7890abcdef1234567890abcde"
```

**Response:**
```json
{
  "address": "UATc1a2b3c4d5e6f7890abcdef1234567890abcde",
  "balance_uat": 1500,
  "code_hash": "0xcode123...",
  "owner": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"
}
```

---

## 7. WebSocket API (Real-time)

### 7.1 Subscribe to Blocks
Real-time block notifications.

**JavaScript:**
```javascript
const ws = new WebSocket('ws://' + UAT_API.replace('http://', '') + '/ws');

ws.onopen = () => {
  ws.send(JSON.stringify({type: 'subscribe', channel: 'blocks'}));
};

ws.onmessage = (event) => {
  console.log('New block:', JSON.parse(event.data));
};
```

**For Tor (requires torsocks + wscat):**
```bash
torsocks wscat -c ws://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion/ws
```

---

### 7.2 Subscribe to Address
Monitor address transactions.

**Request:**
```javascript
ws.send(JSON.stringify({
  type: 'subscribe',
  channel: 'address',
  address: 'UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd'
}));
```

**Response:**
```json
{
  "type": "transaction",
  "tx_hash": "0xtx123...",
  "from": "UAT387d447f...",
  "to": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "amount_uat": 5
}
```

---

## 8. Advanced Use Cases

### 8.1 Batch Queries
Query multiple addresses.

**Request:**
```bash
curl -X POST "${UAT_API}/batch/balances" \
  -H "Content-Type: application/json" \
  -d '{
    "addresses": [
      "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
      "UAT387d447f008fae00f012877b8ffbb49e0aadddd7"
    ]
  }'
```

---

### 8.2 Pagination
Efficient history retrieval.

**Request:**
```bash
curl "${UAT_API}/history/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd?limit=50&offset=0"
curl "${UAT_API}/history/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd?limit=50&offset=50"
```

---

### 8.3 Error Handling
Retry with exponential backoff.

**Bash:**
```bash
for i in 1 2 4 8; do
  response=$(curl -s "${UAT_API}/balance/UAT0d15ab...")
  [ $? -eq 0 ] && echo "$response" && break
  sleep $i
done
```

---

## 9. Development Setup

### Local Node
```bash
cd /path/to/unauthority-core
cargo run --bin uat-node

export UAT_API="http://localhost:3030"
curl "${UAT_API}/node-info"
```

### Tor Testnet
```bash
brew install torsocks  # macOS
export UAT_API="http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion"
torsocks curl "${UAT_API}/health"
```

### Mainnet (Q2 2026)
```bash
export UAT_API="<mainnet domain>"
```

---

## 10. Integration Patterns

### Wallet
```bash
# 1. Generate address (client-side)
# 2. Request faucet
curl -X POST "${UAT_API}/faucet" -d '{"address":"UAT..."}'
# 3. Check balance
curl "${UAT_API}/balance/UAT..."
# 4. Send
curl -X POST "${UAT_API}/send" -d '{...}'
```

### Exchange
```bash
# 1. Monitor deposits (WebSocket)
# 2. Batch balance checks
# 3. Confirm via /history
# 4. Process withdrawals via /send
```

---

## Appendix

### Error Codes
- `400` - Bad request
- `404` - Not found
- `429` - Rate limit exceeded
- `500` - Server error

### Response Times
- Health: <50ms
- Balance: <100ms
- Transaction: ~2-3s
- Contract deploy: ~5s

### Rate Limits
- 100 req/second per IP
- Use keep-alive connections

### Support
- GitHub: https://github.com/unauthority/unauthority-core
- Docs: https://docs.unauthority.org
  "min_amount": 0.001
}
```

**Supported Assets:**
- `"BTC"` - Bitcoin (minimum: 0.001 BTC)
- `"ETH"` - Ethereum (minimum: 0.01 ETH)

**Rate Calculation:**
```
UAT_Received = BTC_Sent × Current_Rate × Bonding_Curve_Multiplier
```

---

### Verify Burn Transaction
Check status of BTC/ETH burn and UAT credit.

**Request:**
```bash
curl -X GET "${UAT_API}/pob/verify/0xbtc_tx_hash..."
```

**Response:**
```json
{
  "burn_tx_hash": "0xbtc_tx_hash...",
  "asset": "BTC",
  "amount_burned": 0.05,
  "confirmations": 6,
  "required_confirmations": 6,
  "status": "confirmed",
  "uat_credited": 2283.90000000,
  "uat_address": "UAT1recipient...",
  "rate_applied": 45678.00,
  "bonding_multiplier": 1.0,
  "oracle_price": 45678.00,
  "credited_at_block": 15245
}
```

**Burn Status:**
- `"pending"` - Waiting for confirmations (BTC: 6, ETH: 32)
- `"confirmed"` - UAT credited to account
- `"rejected"` - Invalid burn (wrong asset, amount too low)

---

## 8. Network Statistics

### Get Network Stats
Overview of blockchain metrics.

**Request:**
```bash
curl -X GET "${UAT_API}/stats"
```

**Response:**
```json
{
  "network": {
    "chain_id": "unauthority-mainnet",
    "genesis_time": 1706745600,
    "current_block": 15240,
    "avg_block_time_ms": 2847,
    "total_transactions": 8742156,
    "tps_current": 47.3,
    "tps_peak": 152.8
  },
  "supply": {
    "total_supply": 2193623600000000,
    "circulating_supply": 2040070000000000,
    "burned_supply": 0,
    "staked_supply": 1280000000000000,
    "staking_ratio": 62.73
  },
  "validators": {
    "total": 128,
    "active": 121,
    "jailed": 2,
    "min_stake": 100000000000,
    "total_stake": 1280000000000000
  },
  "fees": {
    "avg_gas_price": 1500,
    "total_fees_burned": 0,
    "total_fees_paid": 183452000000
  }
}
```

---

## 9. Mempool Operations

### Get Pending Transactions
View transactions waiting for inclusion.

**Request:**
```bash
# All pending
curl -X GET "${UAT_API}/mempool"

# High priority only
curl -X GET "${UAT_API}/mempool?min_gas_price=5000"
```

**Response:**
```json
{
  "pending_count": 234,
  "total_gas": 4920000,
  "transactions": [
    {
      "tx_hash": "0xpending...",
      "from": "UAT1...",
      "to": "UAT2...",
      "amount": 100000000000,
      "gas_price": 5000,
      "nonce": 43,
      "received_at": 1738713650,
      "priority": "high"
    }
  ]
}
```

---

## 10. Oracle Price Feed

### Get Current Prices
Query decentralized oracle for asset prices.

**Request:**
```bash
# Single asset
curl -X GET "${UAT_API}/oracle/price/BTC"

# Multiple assets
curl -X GET "${UAT_API}/oracle/prices?assets=BTC,ETH"
```

**Response:**
```json
{
  "asset": "BTC",
  "price_usd": 4567800,
  "price_formatted": "$45,678.00",
  "timestamp": 1738713600,
  "confidence": 95,
  "sources_count": 7,
  "median_calculation": true,
  "next_update_in": 300
}
```

**Price Update Frequency:**
- BTC/ETH: Every 5 minutes
- Confidence threshold: Minimum 90%
- Data sources: 7 independent oracles (median of 7)

---

## Complete Usage Examples

### Example 1: Send UAT with CLI Tool
```bash
#!/bin/bash

# Configuration
FROM="UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"
TO="UAT387d447f008fae00f012877b8ffbb49e0aadddd7"
AMOUNT=1000000  # 1 UAT in VOID

# Step 1: Get balance
BALANCE=$(curl -s "${UAT_API}/balance/${FROM}" | jq -r '.balance_void')

# Step 2: Send transaction
RESPONSE=$(curl -s -X POST "${UAT_API}/send" \
  -H "Content-Type: application/json" \
  -d "{
    \"from\": \"${FROM}\",
    \"target\": \"${TO}\",
    \"amount\": ${AMOUNT}
  }" | jq -r '.tx_hash')

echo "Transaction sent: ${RESPONSE}"
```

---

### Example 2: Monitor Validator Performance
```bash
#!/bin/bash

VALIDATOR="UAT9e6ed5183acbb802aba83e31420c6dc96d976405"

while true; do
  DATA=$(curl -s "${UAT_API}/validators" | jq ".validators[] | select(.address==\"${VALIDATOR}\")")
  
  STAKE=$(echo $DATA | jq -r '.stake_uat')
  VOTING_POWER=$(echo $DATA | jq -r '.voting_power')
  UPTIME=$(echo $DATA | jq -r '.uptime')
  BLOCKS=$(echo $DATA | jq -r '.blocks_proposed')
  
  echo "$(date) | Stake: ${STAKE} UAT | Power: ${VOTING_POWER} | Uptime: ${UPTIME}% | Blocks: ${BLOCKS}"
  
  sleep 60
done
```

---

### Example 3: Smart Contract Interaction
```bash
#!/bin/bash

CONTRACT="UATc1a2b3c4d5e6f7890abcdef1234567890abcde"

# Query contract state (free)
check_contract() {
  curl -s "${UAT_API}/contract/${CONTRACT}" | jq '.'
}

# Call contract method
call_contract() {
  curl -s -X POST "${UAT_API}/call-contract" \
    -H "Content-Type: application/json" \
    -d "{
      \"contract\": \"${CONTRACT}\",
      \"method\": \"transfer\",
      \"args\": [\"$1\", \"$2\"],
      \"from\": \"$3\",
      \"gas_limit\": 100000
    }" | jq -r '.tx_hash'
}

# Usage
check_contract
TX_HASH=$(call_contract "UAT387d44..." "1000000" "UAT0d15ab...")
echo "Transfer TX: $TX_HASH"
```

---

## Error Codes Reference

| Code | Message                    | Solution                              |
|------|----------------------------|---------------------------------------|
| 400  | Invalid request format     | Check JSON syntax                     |
| 403  | Insufficient balance       | Add more UAT to account               |
| 404  | Account/TX not found       | Verify address/hash is correct        |
| 429  | Rate limit exceeded        | Reduce request frequency (max 100/s)  |
| 500  | Internal server error      | Check node logs, retry later          |
| 503  | Node not synced            | Wait for sync to complete             |

---

## Rate Limits

Default rate limits per IP:
- All endpoints: **100 requests/second**
- Use `Connection: keep-alive` for efficiency

---

## Production Best Practices

1. **Use placeholder format** `<domain testnet/mainnet>` in code
2. **Set UAT_API environment variable** dynamically
3. **Use torsocks for Tor testnet** access
4. **Implement retry logic** with exponential backoff
5. **Cache node-info** for 30 seconds (avoid spam)
6. **Use multiple RPC endpoints** for redundancy
7. **Validate all responses** before processing
8. **Never log private keys** or signatures
9. **Test on testnet first** before mainnet
10. **Monitor validator uptime** (minimum 99%)

---

## Additional Resources

- [Full REST API Reference](API_REFERENCE.md)
- [Testnet Operation Guide](../docs/TESTNET_OPERATION.md)
- [Tor Browser Installation (macOS)](../docs/TOR_BROWSER_INSTALL_MAC.md)
- [Whitepaper](../docs/WHITEPAPER.md)
- [GitHub Repository](https://github.com/unauthority/unauthority-core)
