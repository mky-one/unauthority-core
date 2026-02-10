# API Reference

Complete reference for the UAT node REST API and gRPC service.

**Version:** v1.0.3-testnet  
**Default REST port:** 3030  
**Default gRPC port:** 23030 (REST port + 20,000)

---

## Rate Limits

| Scope | Limit |
|-------|-------|
| Global | 100 req/s (burst 200) |
| `/send` | 10 per 60 seconds |
| `/burn` | 1 per 300 seconds |
| `/faucet` | 1 per 3,600 seconds |

CORS: All origins allowed (Tor .onion addresses provide access control).

---

## REST Endpoints

### General

#### `GET /`

Root endpoint — API description and available routes.

#### `GET /health`

Health check.

```json
{ "status": "healthy" }
```

Status is `"healthy"` or `"degraded"`.

#### `GET /node-info`

Node metadata.

```json
{
  "chain_id": "uat-testnet",
  "version": "1.0.3",
  "total_supply": 21936236,
  "circulating_supply": 1535536,
  "burned_supply": 0,
  "validators": [
    { "address": "UAT...", "stake": 1000, "active": true }
  ],
  "peers": 3,
  "estimated_finality_ms": 3000
}
```

#### `GET /whoami`

Returns this node's signing address.

```json
{ "address": "UATBwXk9..." }
```

#### `GET /metrics`

Prometheus-format metrics export for monitoring dashboards.

---

### Balance & Accounts

#### `GET /bal/{address}`

Account balance.

```json
{
  "address": "UAT...",
  "balance_void": 100000000000000,
  "balance_uat": 1000
}
```

#### `GET /balance/{address}`

Alias for `/bal/{address}` — same response format.

#### `GET /account/{address}`

Account details with recent transaction history.

```json
{
  "address": "UAT...",
  "balance_void": 100000000000000,
  "balance_uat": 1000,
  "block_count": 5,
  "history": [ ... ]
}
```

---

### Transactions

#### `POST /send`

Submit a signed transaction. Accepts client-signed blocks or node-signed (dev mode).

**Request body (client-signed):**

```json
{
  "from": "UAT...",
  "to": "UAT...",
  "amount": 100,
  "previous": "abc123...",
  "signature": "hex...",
  "public_key": "hex...",
  "work": "hex..."
}
```

**Request body (node-signed, dev mode):**

```json
{
  "to": "UAT...",
  "amount": 100
}
```

**Response:**

```json
{
  "status": "ok",
  "tx_hash": "abc123...",
  "block_hash": "def456..."
}
```

#### `GET /history/{address}`

Full transaction history for an address.

```json
[
  {
    "type": "Send",
    "hash": "abc...",
    "amount": 100,
    "timestamp": 1770580908,
    "link": "UAT..."
  }
]
```

#### `GET /transaction/{hash}`

Lookup a specific transaction by hash.

#### `GET /search/{query}`

Search across addresses, block hashes, and transaction hashes.

---

### Blocks

#### `GET /block`

Latest block by timestamp.

#### `GET /block/{hash}`

Block by hash (block explorer).

#### `GET /blocks/recent`

Last 10 blocks across all accounts.

---

### Supply

#### `GET /supply`

Supply statistics.

```json
{
  "total_supply_uat": 21936236,
  "total_supply_void": 2193623600000000000,
  "circulating_supply_uat": 1535536,
  "burned_supply_uat": 0,
  "public_supply_remaining_uat": 20400700
}
```

---

### Proof-of-Burn

#### `POST /burn`

Submit a Proof-of-Burn mint request. Burns ETH or BTC and mints proportional UAT.

**Request body:**

```json
{
  "burn_tx_id": "0xabc...",
  "burn_chain": "ETH",
  "burn_address": "0x000000000000000000000000000000000000dead",
  "burn_amount": "1.0",
  "recipient": "UAT..."
}
```

**Response:**

```json
{
  "status": "pending",
  "message": "Awaiting oracle consensus (2/3 validator confirmation)"
}
```

Burn addresses:
- ETH: `0x000000000000000000000000000000000000dead`
- BTC: `1BitcoinEaterAddressDontSendf59kuE`

---

### Faucet (Testnet Only)

#### `POST /faucet`

Claim testnet tokens.

**Request body:**

```json
{
  "address": "UAT..."
}
```

**Response:**

```json
{
  "status": "ok",
  "amount": 5000,
  "message": "5000 UAT sent to UAT..."
}
```

Rate limit: 1 claim per hour per address. Cooldown tracked in sled database.

---

### Validators

#### `GET /validators`

List bootstrap validators from genesis.

```json
{
  "validators": [
    {
      "address": "UAT...",
      "stake": 1000,
      "active": true,
      "voting_power": 316227
    }
  ]
}
```

Voting power = √(stake_in_void), demonstrating quadratic voting.

---

### Consensus & Slashing

#### `GET /consensus`

aBFT consensus parameters and safety status.

```json
{
  "type": "aBFT",
  "finality_time_ms": 3000,
  "byzantine_tolerance": 0.33,
  "min_votes_percent": 67,
  "total_validators": 4
}
```

#### `GET /slashing`

Global slashing statistics and validator safety.

#### `GET /slashing/{address}`

Slashing profile for a specific validator address.

---

### Smart Contracts

Requires `vm` feature flag.

#### `POST /deploy-contract`

Deploy a WASM smart contract.

**Request body:**

```json
{
  "bytecode": "<base64-encoded WASM>",
  "deployer": "UAT..."
}
```

Contract address = blake3 hash of bytecode.

Max bytecode: 1 MB. Max execution: 5 seconds.

#### `POST /call-contract`

Execute a contract function.

**Request body:**

```json
{
  "contract_address": "abc123...",
  "function": "transfer",
  "args": ["UAT...", "1000"]
}
```

#### `GET /contract/{address}`

Contract metadata and state.

---

### Peer Network

#### `GET /peers`

Connected P2P peers.

```json
{
  "peers": ["peer_id_1", "peer_id_2"],
  "count": 2
}
```

---

### State Sync

#### `GET /sync`

HTTP-based full state sync. Returns GZIP-compressed ledger state.

| Limit | Value |
|-------|-------|
| Max compressed | 8 MB |
| Max decompressed | 50 MB |
| Supply validation | 1% tolerance |

Rate limited to prevent abuse.

---

## gRPC API

The node also exposes a gRPC service on port `REST_PORT + 20000` (default: 23030).

**Proto file:** `uat.proto`

### Service: `UatNode`

| RPC | Request | Response | Description |
|-----|---------|----------|-------------|
| `GetBalance` | `address` | `balance_void`, `balance_uat` | Account balance |
| `GetAccount` | `address` | Account details | Full account info |
| `GetBlock` | `hash` | Block | Block by hash |
| `GetLatestBlock` | — | Block | Most recent block |
| `SendTransaction` | `from`, `to`, `amount`, `signature`, `public_key`, `previous`, `work` | `tx_hash`, `block_hash` | Submit transaction |
| `GetNodeInfo` | — | `chain_id`, `version`, `total_supply`, `peers`, `validators`, `estimated_finality_ms` | Node metadata |
| `GetValidators` | — | Validator list with `voting_power` | Active validators |
| `GetBlockHeight` | — | `height`, `latest_hash` | Chain height |

---

## Connecting via Tor

All testnet endpoints are accessible via Tor hidden services:

```bash
# Health check via Tor
curl --socks5-hostname 127.0.0.1:9052 \
  http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion/health

# Node info
curl --socks5-hostname 127.0.0.1:9052 \
  http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion/node-info

# Balance check
curl --socks5-hostname 127.0.0.1:9052 \
  http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion/bal/UATYourAddress
```

Tor SOCKS5 ports: `9052` (setup_tor_testnet.sh), `9150` (Tor Browser), `9050` (system Tor).
