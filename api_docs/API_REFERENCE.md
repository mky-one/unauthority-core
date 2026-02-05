# Unauthority (UAT) API Reference

**Version:** 1.0  
**Base URL:** `<domain testnet/mainnet>`

**Available Domains:**
- **Testnet (Tor):** `http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion`
- **Mainnet (TBD):** Coming Q2 2026
- **Local Development:** `http://localhost:3030`

**Note:** Replace `<domain testnet/mainnet>` with actual endpoint URL.

---

## REST API Endpoints (13 Total)

### 1. GET /node-info
**Get node information and chain statistics**

**Request:**
```bash
curl <domain testnet/mainnet>/node-info
```

**Response:**
```json
{
  "node_id": "uat_0f0728fd",
  "version": "1.0.0",
  "chain": "uat-mainnet",
  "consensus": "aBFT",
  "block_height": 12345,
  "latest_block_hash": "0xabcd...",
  "validators": 128,
  "total_accounts": 1523,
  "total_supply_uat": 21936236,
  "peer_count": 47,
  "uptime_seconds": 3600
}
```

---

### 2. GET /health
**Health check endpoint for monitoring**

**Request:**
```bash
curl <domain testnet/mainnet>/health
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
    "blocks": 12345,
    "accounts": 1523
  },
  "database": {
    "size_on_disk": 524287000,
    "blocks_count": 12345,
    "accounts_count": 1523
  }
}
```

---

### 3. GET /balance/:address
**Get account balance**

**Request:**
```bash
curl <domain testnet/mainnet>/balance/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd
```

**Response:**
```json
{
  "address": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "balance_uat": 19194200,
  "balance_void": 19194200000000,
  "nonce": 42
}
```

---

### 4. GET /account/:address
**Get full account information (balance + history combined)**

**Request:**
```bash
curl <domain testnet/mainnet>/account/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd
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

---

### 5. GET /history/:address
**Get transaction history for an address**

**Request:**
```bash
curl <domain testnet/mainnet>/history/UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd
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

---

### 6. GET /validators
**List all active validators**

**Request:**
```bash
curl <domain testnet/mainnet>/validators
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

---

### 7. GET /peers
**Get connected peer nodes**

**Request:**
```bash
curl <domain testnet/mainnet>/peers
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

---

### 8. GET /block
**Get latest block information**

**Request:**
```bash
curl <domain testnet/mainnet>/block
```

**Response:**
```json
{
  "height": 12345,
  "hash": "0xabcd1234...",
  "previous_hash": "0xdef5678...",
  "timestamp": 1738742400,
  "transactions": 15,
  "validator": "UAT9e6ed5183acbb802aba83e31420c6dc96d976405",
  "size_bytes": 4096,
  "tx_hashes": [
    "0xtx1...",
    "0xtx2..."
  ]
}
```

---

### 9. GET /block/:height
**Get block at specific height**

**Request:**
```bash
curl <domain testnet/mainnet>/block/1234
```

**Response:**
```json
{
  "height": 1234,
  "hash": "0xabcd1234...",
  "previous_hash": "0xdef5678...",
  "timestamp": 1738740000,
  "transactions": 8,
  "validator": "UAT3f8ff6ffc3e9161964b5ff4cf288b87e99c456fe",
  "size_bytes": 2048,
  "merkle_root": "0xmerkle...",
  "tx_hashes": [
    "0xtx1...",
    "0xtx2..."
  ]
}
```

---

### 10. GET /whoami
**Get current node's address**

**Request:**
```bash
curl <domain testnet/mainnet>/whoami
```

**Response:**
```json
{
  "address": "UAT9e6ed5183acbb802aba83e31420c6dc96d976405",
  "node_id": "uat_0f0728fd",
  "is_validator": true,
  "stake_uat": 100000
}
```

---

### 11. POST /faucet
**Request testnet tokens (100 UAT, 1-hour cooldown)**

**Request:**
```bash
curl -X POST <domain testnet/mainnet>/faucet \
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

---

### 12. POST /send
**Send UAT to another address**

**Request:**
```bash
curl -X POST <domain testnet/mainnet>/send \
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
- `previous` (optional): Previous block hash for client-side signing
- `work` (optional): PoW nonce if pre-computed

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

**Response (Error):**
```json
{
  "success": false,
  "error": "Insufficient balance",
  "required": 1000000,
  "available": 500000
}
```

---

### 13. POST /burn
**Burn ETH/BTC to mint UAT (Proof-of-Burn)**

**Request:**
```bash
curl -X POST <domain testnet/mainnet>/burn \
  -H "Content-Type: application/json" \
  -d '{
    "coin_type": "eth",
    "txid": "0xeth_tx_hash...",
    "recipient_address": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd"
  }'
```

**Request Fields:**
- `coin_type` (required): "eth" or "btc"
- `txid` (required): Transaction hash on ETH/BTC blockchain
- `recipient_address` (optional): UAT address to receive minted tokens (defaults to sender)

**Burn Addresses:**
- **ETH:** `0x000000000000000000000000000000000000dEaD`
- **BTC:** `1111111111111111111114oLvT2`

**Response (Success):**
```json
{
  "success": true,
  "burn_tx": "0xeth_tx_hash...",
  "mint_tx": "0xuat_mint_hash...",
  "burned_amount_eth": 1.0,
  "burned_value_usd": 3000.0,
  "minted_uat": 3000,
  "exchange_rate": "1 ETH = 3000 UAT",
  "oracle_price_eth_usd": 3000.0,
  "recipient": "UAT0d15ab29bb71ff7d37b298fb65db95773a5ee8fd",
  "timestamp": 1738742500
}
```

**Response (Pending Verification):**
```json
{
  "success": false,
  "status": "pending",
  "message": "Waiting for oracle verification (3/5 confirmations)",
  "confirmations": 2,
  "required_confirmations": 5,
  "estimated_completion": 1738742600
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Transaction not found on ETH blockchain",
  "txid": "0xeth_tx_hash..."
}
```

---

## Smart Contract Endpoints (Optional)

### POST /deploy-contract
**Deploy a WASM smart contract (Permissionless)**

```json
Request:
{
  "owner": "alice",
  "bytecode": "AGFzbQEAAAABBwFgAn9/AX8DAgEABwcBA2FkZAAACgkBBwAgACABags=",
  "initial_state": {
    "counter": "0"
  }
}

Response (Success):
{
  "status": "success",
  "contract_address": "contract_alice_0_1738627200",
  "owner": "alice",
  "deployed_at_block": 1738627200
}

Response (Error):
{
  "status": "error",
  "msg": "Invalid WASM bytecode (missing magic header)"
}
```

**Details:**
- `bytecode`: Base64-encoded WASM binary module
- `initial_state`: Optional key-value state storage
- Returns deterministic contract address
- No whitelist or permission required

---

### 2. POST /call-contract
**Execute a smart contract function**

```json
Request:
{
  "contract_address": "contract_alice_0_1738627200",
  "function": "add",
  "args": ["5", "7"],
  "gas_limit": 1000000
}

Response (Success):
{
  "status": "success",
  "result": {
    "success": true,
    "output": "12",
    "gas_used": 60,
    "state_changes": {}
  }
}

Response (Error):
{
  "status": "error",
  "msg": "Contract not found"
}
```

**Details:**
- Executes real WASM bytecode via wasmer
- Falls back to mock dispatch for built-in functions
- Gas limit prevents infinite loops
- State changes persisted on success

---

### 3. GET /contract/:address
**Get contract information**

```json
Response:
{
  "status": "success",
  "contract": {
    "address": "contract_alice_0_1738627200",
    "code_hash": "a1b2c3d4e5f6",
    "balance": 5000,
    "owner": "alice",
    "created_at_block": 1738627200,
    "state": {
      "counter": "42"
    }
  }
}
```

---

### 4. GET /balance/:address
**Get account balance**

---

### 5. GET /supply
**Get total supply and distribution**

---

### 6. GET /history/:address
**Get transaction history**

---

### 7. GET /peers
**Get connected peers**

---

### 8. POST /send
**Send UAT to another address**

---

### 9. POST /burn
**Burn ETH/BTC for UAT (Proof-of-Burn)**

---

## gRPC API

### Service: UatService

#### GetBalance(address: string) → BalanceResponse
#### GetAccount(address: string) → AccountInfo
#### GetBlock(block_number: uint64) → BlockInfo
#### GetLatestBlock() → BlockInfo
#### GetBlockHeight() → uint64
#### SendTransaction(from, to, amount) → tx_hash
#### GetNodeInfo() → NodeInfo
#### GetValidators() → ValidatorInfo[]

---

## Smart Contract Development

### Supported Languages
- Rust (compile to WASM)
- C++ (compile to WASM)
- AssemblyScript
- Go (TinyGo)

### Example Contract (Rust)
```rust
#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

Compile:
```bash
rustc --target wasm32-unknown-unknown --crate-type=cdylib contract.rs -o contract.wasm
```

Deploy:
```bash
BASE64=$(base64 < contract.wasm)
curl -X POST <domain testnet/mainnet>/deploy-contract \
  -H "Content-Type: application/json" \
  -d "{\"owner\":\"alice\",\"bytecode\":\"$BASE64\"}"
```

---

## Security Features

### Sentry Node Architecture
- Validators hidden behind public sentry nodes
- Rate limiting: 100 RPS per IP
- Max connections: 10 per IP
- IP blacklist support

### Anti-Whale Mechanisms
- Dynamic fee scaling on spam
- Quadratic voting power: $\sqrt{stake}$
- Burn limits per block

### Consensus
- Asynchronous Byzantine Fault Tolerance (aBFT)
- <3 second finality
- Post-quantum cryptography (CRYSTALS-Dilithium)
