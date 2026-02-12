# API Reference

Complete reference for the LOS node REST API and gRPC service.

**Version:** v1.0.6-testnet  
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
  "chain_id": "los-testnet",
  "version": "1.0.6",
  "total_supply": 21936236,
  "circulating_supply": 677823,
  "burned_supply": 0,
  "validators": [
    { "address": "LOS...", "stake": 1000, "active": true }
  ],
  "peers": 3,
  "estimated_finality_ms": 3000
}
```

#### `GET /whoami`

Returns this node's signing address.

```json
{ "address": "LOSBwXk9..." }
```

#### `GET /metrics`

Prometheus-format metrics export for monitoring dashboards.

---

### Balance & Accounts

#### `GET /bal/{address}`

Account balance.

```json
{
  "address": "LOS...",
  "balance_cil": 100000000000000,
  "balance_los": 1000
}
```

#### `GET /balance/{address}`

Alias for `/bal/{address}` — same response format.

#### `GET /account/{address}`

Account details with recent transaction history.

```json
{
  "address": "LOS...",
  "balance_cil": 100000000000000,
  "balance_los": 1000,
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
  "from": "LOS...",
  "to": "LOS...",
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
  "to": "LOS...",
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
    "link": "LOS..."
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
  "total_supply_los": 21936236,
  "total_supply_cil": 2193623600000000000,
  "circulating_supply_los": 677823,
  "burned_supply_los": 0,
  "public_supply_remaining_los": 21258413
}
```

---

### Proof-of-Burn

#### `POST /burn`

Submit a Proof-of-Burn mint request. Burns ETH or BTC and mints proportional LOS.

**Request body:**

```json
{
  "burn_tx_id": "0xabc...",
  "burn_chain": "ETH",
  "burn_address": "0x000000000000000000000000000000000000dead",
  "burn_amount": "1.0",
  "recipient": "LOS..."
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
  "address": "LOS..."
}
```

**Response:**

```json
{
  "status": "ok",
  "amount": 5000,
  "message": "5000 LOS sent to LOS..."
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
      "address": "LOS...",
      "stake": 1000,
      "active": true,
      "voting_power": 316227
    }
  ]
}
```

Voting power = √(stake_in_cil), demonstrating quadratic voting.

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

### Validator Rewards

#### `GET /reward-info`

Validator reward pool status, current epoch, and per-validator reward details.

```json
{
  "pool_remaining_cil": 219362360000000000,
  "pool_remaining_los": "2193623.60000000000",
  "total_distributed_cil": 0,
  "current_epoch": 0,
  "epoch_start": 1770580908,
  "epoch_duration_secs": 86400,
  "epoch_remaining_secs": 43200,
  "current_rate_cil_per_epoch": 5000000000000,
  "current_rate_los_per_epoch": "50.00000000000",
  "halving_interval_epochs": 365,
  "validators": [
    {
      "address": "LOS...",
      "heartbeats": 720,
      "expected_heartbeats": 1440,
      "uptime_pct": 50.0,
      "qualified": false,
      "sqrt_stake": 316227766016,
      "is_genesis": true,
      "cumulative_reward_cil": 0
    }
  ],
  "config": {
    "pool_total_cil": 219362360000000000,
    "epoch_secs": 86400,
    "initial_rate_cil": 5000000000000,
    "halving_interval_epochs": 365,
    "min_uptime_pct": 95,
    "probation_epochs": 3
  }
}
```

Validators with ≥ 95% uptime qualify for epoch rewards. Reward shares are proportional to √stake (quadratic). Genesis bootstrap validators are excluded from rewards. The reward rate halves every 365 epochs (~1 year).

#### `GET /fee-estimate`

Dynamic fee estimate based on current network activity and anti-whale parameters.

```json
{
  "base_fee_cil": 100000,
  "recommended_fee_cil": 100000,
  "spam_multiplier": 1,
  "network_load": "low"
}
```

---

### Smart Contracts

Requires `vm` feature flag.

#### `POST /deploy-contract`

Deploy a WASM smart contract.

**Request body:**

```json
{
  "bytecode": "<base64-encoded WASM>",
  "deployer": "LOS..."
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
  "args": ["LOS...", "1000"]
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

**Proto file:** `los.proto`

### Service: `LosNode`

| RPC | Request | Response | Description |
|-----|---------|----------|-------------|
| `GetBalance` | `address` | `balance_cil`, `balance_los` | Account balance |
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
  http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/health

# Node info
curl --socks5-hostname 127.0.0.1:9052 \
  http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/node-info

# Balance check
curl --socks5-hostname 127.0.0.1:9052 \
  http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/bal/LOSYourAddress
```

Tor SOCKS5 ports: `9052` (setup_tor_testnet.sh), `9150` (Tor Browser), `9050` (system Tor).
