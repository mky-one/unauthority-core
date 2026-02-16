# API Reference — Unauthority (LOS) v1.0.9

Complete REST API and gRPC API documentation for the `los-node` validator binary.

---

## Base URL

| Protocol | Address | Notes |
|---|---|---|
| **REST** | `http://127.0.0.1:3030` | Default port, configurable via `--port` |
| **gRPC** | `127.0.0.1:23030` | Always REST port + 20,000 |
| **Tor** | `http://YOUR_ONION.onion:3030` | Via SOCKS5 proxy |

## Authentication

No authentication required. Rate limiting is enforced per IP for state-changing endpoints.

## Error Format

All errors return:
```json
{ "status": "error", "msg": "Description of the error", "code": 400 }
```

---

## Table of Contents

- [Status Endpoints](#status-endpoints)
- [Account Endpoints](#account-endpoints)
- [Block Endpoints](#block-endpoints)
- [Transaction Endpoints](#transaction-endpoints)
- [Validator Endpoints](#validator-endpoints)
- [Consensus & Oracle](#consensus--oracle)
- [Smart Contract Endpoints](#smart-contract-endpoints)
- [Network Endpoints](#network-endpoints)
- [Utility Endpoints](#utility-endpoints)
- [gRPC API](#grpc-api)
- [Rate Limits](#rate-limits)

---

## Status Endpoints

### GET `/`

Node status overview with all available endpoints.

**Response:**
```json
{
  "name": "Unauthority (LOS) Blockchain API",
  "version": "1.0.9",
  "network": "mainnet",
  "status": "operational",
  "description": "Decentralized blockchain with Proof-of-Burn consensus",
  "endpoints": {
    "health": "GET /health - Health check",
    "supply": "GET /supply - Total supply, burned, remaining",
    "bal": "GET /bal/{address} - Account balance (short alias)",
    "send": "POST /send {from, target, amount} - Send transaction",
    "...": "..."
  }
}
```

### GET `/health`

Health check for monitoring and load balancing.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.9",
  "timestamp": 1771277598,
  "uptime_seconds": 86400,
  "chain": {
    "accounts": 8,
    "blocks": 42,
    "id": "los-mainnet"
  },
  "database": {
    "accounts_count": 8,
    "blocks_count": 42,
    "size_on_disk": 524287
  }
}
```

### GET `/node-info`

Detailed node information.

**Response:**
```json
{
  "node_id": "validator-1",
  "version": "1.0.9",
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "block_count": 42,
  "account_count": 8,
  "peers": 4,
  "is_validator": true,
  "uptime_seconds": 86400,
  "network": "mainnet"
}
```

### GET `/supply`

Total, circulating, and burned supply information.

**Response:**
```json
{
  "total_supply": "21936236.00000000000",
  "total_supply_cil": 2193623600000000000,
  "circulating_supply": "777823.00000000000",
  "circulating_supply_cil": 77782300000000000,
  "remaining_supply": "21158413.00000000000",
  "remaining_supply_cil": 2115841300000000000,
  "total_burned_usd": 0
}
```

### GET `/metrics`

Prometheus-compatible metrics output.

**Response:** (text/plain)
```
# HELP los_blocks_total Total blocks in ledger
los_blocks_total 42
# HELP los_accounts_total Total accounts
los_accounts_total 8
# HELP los_active_validators Active validator count
los_active_validators 4
# HELP los_peer_count Connected peers
los_peer_count 4
# HELP los_consensus_rounds aBFT consensus rounds
los_consensus_rounds 128
# HELP los_uptime_seconds Node uptime
los_uptime_seconds 86400
```

---

## Account Endpoints

### GET `/bal/{address}`

Get account balance. Returns balance in both CIL (atomic unit) and LOS.

**Example:** `GET /bal/LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1`

**Response:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "balance_cil": 100000000000000,
  "balance_cil_str": "100000000000000",
  "balance_los": "1000.00000000000",
  "block_count": 0,
  "head": "0"
}
```

### GET `/balance/{address}`

Alias for `/bal/{address}`. Same response format.

### GET `/account/{address}`

Full account details including balance, block count, validator status, and recent transaction history.

**Example:** `GET /account/LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1`

**Response:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "balance_cil": 100000000000000,
  "balance_los": "1000.00000000000",
  "block_count": 5,
  "head": "abc123...",
  "is_validator": true,
  "stake_cil": 100000000000000,
  "recent_blocks": [ ... ]
}
```

### GET `/history/{address}`

Transaction history for an address.

**Example:** `GET /history/LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1`

**Response:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "transactions": [
    {
      "hash": "abc123...",
      "type": "Send",
      "amount": 100000000000000,
      "from": "LOSX7dSt...",
      "to": "LOSWoNus...",
      "timestamp": 1771277598,
      "fee": 100000000
    }
  ]
}
```

### GET `/fee-estimate/{address}`

Estimate the transaction fee for an address. Fee varies based on network congestion and anti-whale scaling.

**Example:** `GET /fee-estimate/LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1`

**Response:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "fee_cil": 100000000,
  "fee_los": "0.00100000000"
}
```

---

## Block Endpoints

### GET `/block`

Latest block across all accounts.

**Response:**
```json
{
  "account": "LOSX7dSt...",
  "previous": "def456...",
  "block_type": "Send",
  "amount": 50000000000000,
  "link": "LOSWoNus...",
  "hash": "abc123...",
  "timestamp": 1771277598,
  "height": 42
}
```

### GET `/block/{hash}`

Get a specific block by its SHA-3 hash.

**Example:** `GET /block/abc123def456...`

### GET `/blocks/recent`

Recent blocks (last 50).

**Response:**
```json
{
  "blocks": [ ... ],
  "count": 50
}
```

---

## Transaction Endpoints

### POST `/send`

Send LOS to another address.

#### Client-Signed Transaction (Recommended)

The client signs the transaction with Dilithium5. This is the secure method used by wallets.

**Request:**
```json
{
  "from": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "target": "LOSWoNusVctuR9TJKtpWa8fZdisdWk3XgznML",
  "amount": 10,
  "amount_cil": 1000000000000,
  "signature": "hex_dilithium5_signature...",
  "public_key": "hex_dilithium5_public_key...",
  "previous": "hash_of_previous_block...",
  "timestamp": 1771277598,
  "fee": 100000000
}
```

**Fields:**
- `from` — Sender address
- `target` — Recipient address
- `amount` — Amount in LOS (or use `amount_cil` for atomic units)
- `signature` — Dilithium5 hex signature over the transaction payload
- `public_key` — Sender's Dilithium5 hex public key
- `previous` — Hash of the sender's latest block (from `/bal/{address}`)
- `timestamp` — Unix timestamp
- `fee` — Fee in CIL (from `/fee-estimate`)

#### Node-Signed Transaction (Testnet/Development)

For testing, only `target` and `amount` are required. The node signs with its own key.

**Request:**
```json
{
  "target": "LOSWoNusVctuR9TJKtpWa8fZdisdWk3XgznML",
  "amount": 10
}
```

**Response (both modes):**
```json
{
  "status": "ok",
  "hash": "abc123def456...",
  "from": "LOSX7dSt...",
  "to": "LOSWoNus...",
  "amount_cil": 1000000000000,
  "fee_cil": 100000000,
  "block_type": "Send"
}
```

### GET `/transaction/{hash}`

Look up a transaction by its hash.

**Example:** `GET /transaction/abc123def456...`

### GET `/search/{query}`

Search across blocks, accounts, and transaction hashes.

**Example:** `GET /search/LOSX7dSt`

---

## Transaction: Proof-of-Burn

### POST `/burn`

Burn ETH or BTC to receive LOS.

**Request:**
```json
{
  "coin_type": "eth",
  "txid": "0xabc123def456...",
  "recipient_address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1"
}
```

**Fields:**
- `coin_type` — `"eth"` or `"btc"`
- `txid` — Transaction hash of the burn on the source chain
- `recipient_address` — LOS address to receive minted tokens

**Process:**
1. Submit the burn TXID
2. Multi-validator oracle consensus verifies the burn amount and price
3. LOS is minted to the recipient proportional to USD value burned
4. All arithmetic uses u128 integer math (prices in micro-USD, amounts in wei/satoshi)

**Response:**
```json
{
  "status": "pending",
  "txid": "0xabc123...",
  "msg": "Burn submitted. Awaiting oracle consensus."
}
```

### POST `/reset-burn-txid`

Reset a stuck burn TXID (testnet only — disabled on mainnet).

---

## Validator Endpoints

### GET `/validators`

List all active validators.

**Response:**
```json
{
  "validators": [
    {
      "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
      "active": true,
      "connected": true,
      "has_min_stake": true,
      "is_genesis": true,
      "onion_address": "f3zfmh...nid.onion",
      "stake": 1000,
      "uptime_percentage": 99
    }
  ]
}
```

### POST `/register-validator`

Register as a network validator. Requires Dilithium5 signature and ≥1,000 LOS stake.

**Request:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "public_key": "hex_dilithium5_public_key...",
  "signature": "hex_dilithium5_signature...",
  "endpoint": "your-onion-address.onion:3030"
}
```

### POST `/unregister-validator`

Remove yourself from the validator set.

**Request:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "public_key": "hex_dilithium5_public_key...",
  "signature": "hex_dilithium5_signature..."
}
```

---

## Consensus & Oracle

### GET `/consensus`

aBFT consensus engine status and safety parameters.

**Response:**
```json
{
  "safety": {
    "active_validators": 4,
    "byzantine_threshold": 1,
    "byzantine_safe": true,
    "consensus_model": "aBFT"
  },
  "round": {
    "current": 128,
    "decided": 127
  }
}
```

### GET `/reward-info`

Validator reward pool and epoch information.

**Response:**
```json
{
  "epoch": {
    "current_epoch": 5,
    "epoch_reward_rate_los": 5000
  },
  "pool": {
    "remaining_los": 475000,
    "total_distributed_los": 25000
  },
  "validators": {
    "eligible": 4,
    "total": 4
  }
}
```

### GET `/slashing`

Global slashing statistics.

### GET `/slashing/{address}`

Slashing profile for a specific validator address.

---

## Smart Contract Endpoints

### POST `/deploy-contract`

Deploy a WASM smart contract to the UVM.

**Request:**
```json
{
  "wasm_hex": "0061736d...",
  "deployer": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
  "signature": "hex_signature...",
  "public_key": "hex_public_key..."
}
```

### POST `/call-contract`

Execute a function on a deployed smart contract.

**Request:**
```json
{
  "contract_id": "contract_address_or_hash",
  "function": "transfer",
  "args": ["LOSX7dSt...", "1000"],
  "caller": "LOSX7dSt...",
  "signature": "hex_signature...",
  "public_key": "hex_public_key..."
}
```

### GET `/contract/{id}`

Get the state and info of a deployed contract.

### GET `/contracts`

List all deployed contracts.

---

## Network Endpoints

### GET `/peers`

Connected peers and validator endpoints.

**Response:**
```json
{
  "peer_count": 4,
  "peers": [
    {
      "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1",
      "is_validator": true,
      "onion_address": "f3zfmh...nid.onion",
      "self": true,
      "short_address": "los_X7dStdPk"
    }
  ],
  "validator_endpoint_count": 4,
  "validator_endpoints": [
    {
      "address": "LOSX7dSt...",
      "onion_address": "f3zfmh...nid.onion"
    }
  ]
}
```

### GET `/network/peers`

Network-level peer discovery with endpoint information.

### GET `/mempool/stats`

Current mempool statistics.

**Response:**
```json
{
  "pending_transactions": 0,
  "pending_burns": 0,
  "queued": 0
}
```

### GET `/sync`

GZIP-compressed ledger state for node synchronization. Use `?from={block_count}` for incremental sync.

### GET `/whoami`

This node's signing address.

**Response:**
```json
{
  "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1"
}
```

---

## Utility Endpoints

### GET `/tor-health`

Tor hidden service self-check status.

**Response:**
```json
{
  "onion_reachable": true,
  "consecutive_failures": 0,
  "total_pings": 100,
  "total_failures": 2
}
```

### POST `/faucet`

Claim testnet tokens (disabled on mainnet).

**Request:**
```json
{ "address": "LOSX7dStdPkS9U4MFCmDQfpmvrbMa5WAZfQX1" }
```

---

## gRPC API

Protocol definition: [`los.proto`](../los.proto)

| RPC Method | Description |
|---|---|
| `GetBalance` | Account balance |
| `GetAccount` | Full account details |
| `GetBlock` | Block by hash |
| `GetLatestBlock` | Latest block |
| `SendTransaction` | Submit signed transaction |
| `GetNodeInfo` | Node information |
| `GetValidators` | Validator list |
| `GetBlockHeight` | Current block height |

**gRPC port:** Always REST port + 20,000 (default: `23030`).

---

## Rate Limits

| Endpoint | Limit |
|---|---|
| `/faucet` | 1 per address per 24 hours |
| `/send` | Anti-spam throttle per address |
| `/burn` | 1 per TXID (globally deduplicated) |
| All endpoints | Per-IP rate limiting |
