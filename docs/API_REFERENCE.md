# API Reference — Unauthority (LOS) v1.0.9

## Base URL

- **REST:** `http://localhost:3030` (or node's API port)
- **gRPC:** `localhost:23030` (REST port + 20,000)

## Authentication

No authentication required. Rate limiting is enforced per IP and per address for state-changing endpoints.

---

## Read Endpoints

### GET `/`
Node status overview and API endpoint index.

**Response:**
```json
{
  "name": "Unauthority (LOS) Node",
  "version": "1.0.9",
  "node_id": "node-3030",
  "address": "LOSW...",
  "network": "testnet",
  "block_count": 42,
  "account_count": 6,
  "uptime_seconds": 3600,
  "endpoints": { ... }
}
```

### GET `/health`
Health check for monitoring.

**Response:** `200 OK`
```json
{ "status": "healthy", "block_count": 42, "account_count": 6 }
```

### GET `/node-info`
Detailed node information.

**Response:**
```json
{
  "node_id": "node-3030",
  "version": "1.0.9",
  "address": "LOSW...",
  "block_count": 42,
  "account_count": 6,
  "peers": 3,
  "is_validator": true,
  "uptime_seconds": 3600,
  "testnet_level": "consensus"
}
```

### GET `/bal/{address}`
Get balance in CIL (atomic units). Alias: `/balance/{address}`.

**Response:**
```json
{ "address": "LOSW...", "balance": 100000000000000, "balance_los": 1000 }
```

### GET `/supply`
Total and circulating supply data.

**Response:**
```json
{
  "total_supply_cil": 2193623600000000000,
  "total_supply_los": 21936236,
  "remaining_supply_cil": 2125841300000000000,
  "circulating_cil": 67782300000000000,
  "total_burned_usd": 0
}
```

### GET `/history/{address}`
Transaction history for an account.

**Response:**
```json
{
  "address": "LOSW...",
  "transactions": [
    {
      "hash": "abc123...",
      "type": "Send",
      "amount": 100000000000000,
      "from": "LOSW...",
      "to": "LOSX...",
      "timestamp": 1739000000,
      "fee": 100000000
    }
  ]
}
```

### GET `/block`
Latest block across all accounts.

### GET `/block/{hash}`
Get a specific block by its hash.

### GET `/blocks/recent`
Recent blocks (last 50).

### GET `/transaction/{hash}`
Get a specific transaction by hash (searches blocks).

### GET `/search/{query}`
Search across blocks, accounts, and transaction hashes.

### GET `/validators`
List active validators (accounts with ≥1,000 LOS stake).

**Response:**
```json
{
  "validators": [
    {
      "address": "LOSW...",
      "stake_cil": 100000000000000,
      "stake_los": 1000,
      "block_count": 5,
      "is_registered": true
    }
  ],
  "count": 4
}
```

### GET `/consensus`
aBFT consensus engine status.

**Response:**
```json
{
  "safety": {
    "active_validators": 4,
    "byzantine_threshold": 1,
    "byzantine_safe": true,
    "consensus_model": "aBFT"
  },
  "round": { "current": 12, "decided": 11 }
}
```

### GET `/reward-info`
Validator reward pool and epoch information.

**Response:**
```json
{
  "epoch": { "current_epoch": 5, "epoch_reward_rate_los": 5000 },
  "pool": { "remaining_los": 475000, "total_distributed_los": 25000 },
  "validators": { "eligible": 4, "total": 4 }
}
```

### GET `/slashing`
Global slashing status summary.

### GET `/slashing/{address}`
Slashing profile for a specific validator.

### GET `/metrics`
Prometheus-compatible metrics output.

### GET `/fee-estimate/{amount}`
Estimate transaction fee for given CIL amount.

### GET `/whoami`
This node's address.

### GET `/account/{address}`
Full account details (balance, head block, block count, validator status).

### GET `/peers`
Connected peer addresses.

### GET `/network/peers`
Network peer discovery with endpoint information.

### GET `/mempool/stats`
Current mempool statistics.

### GET `/sync?from={block_count}`
GZIP-compressed ledger state for peer sync. Use `from` query parameter to request incremental sync.

### GET `/contract/{id}`
Get deployed WASM contract state.

---

## Write Endpoints

### POST `/send`
Send LOS to another address.

**Request Body:**
```json
{
  "target": "LOSX1YFT...",
  "amount": 10,
  "from": "LOSW...",
  "signature": "hex...",
  "public_key": "hex...",
  "previous": "hash...",
  "timestamp": 1739000000,
  "fee": 100000000
}
```

For node-signed transactions (no client signature), only `target` and `amount` are required.

For client-signed transactions, `signature`, `public_key`, `previous`, `timestamp`, and optionally `amount_cil` (if sending in CIL directly) are required.

### POST `/burn`
Proof-of-Burn: burn ETH or BTC to receive LOS.

**Request Body:**
```json
{
  "coin_type": "eth",
  "txid": "0xabc123...",
  "recipient_address": "LOSW..."
}
```

**Oracle Pipeline:** Burns are verified through a multi-validator oracle consensus mechanism. Prices are stored as micro-USD (u128, 6 decimal places). ETH amounts are in wei, BTC in satoshi. All arithmetic is pure integer — no floating-point in the consensus pipeline.

### POST `/faucet`
Request testnet tokens (testnet only, disabled on mainnet).

**Request Body:**
```json
{ "address": "LOSW..." }
```

### POST `/register-validator`
Register as a network validator. Requires Dilithium5 signature and minimum 1,000 LOS stake.

**Request Body:**
```json
{
  "address": "LOSW...",
  "public_key": "hex...",
  "signature": "hex...",
  "endpoint": "abc123.onion:3030"
}
```

### POST `/unregister-validator`
Unregister from validator set.

### POST `/deploy-contract`
Deploy a WASM smart contract.

### POST `/call-contract`
Execute a function on a deployed contract.

### POST `/reset-burn-txid`
Reset a stuck burn TXID (testnet only).

---

## gRPC API

Protocol definition: `los.proto`

| RPC | Description |
|---|---|
| `GetBalance` | Account balance |
| `GetAccount` | Account details |
| `GetBlock` | Block by hash |
| `GetLatestBlock` | Latest block |
| `SendTransaction` | Submit transaction |
| `GetNodeInfo` | Node information |
| `GetValidators` | Validator list |
| `GetBlockHeight` | Current block height |

---

## Rate Limits

| Endpoint | Limit |
|---|---|
| `/faucet` | 1 per address per 24h |
| `/send` | Anti-spam throttle |
| `/burn` | 1 per TXID (globally deduplicated) |

## Error Format

All errors return JSON:
```json
{ "status": "error", "msg": "Description of what went wrong" }
```
