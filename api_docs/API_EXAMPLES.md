# UAT API Examples & Usage Guide

Comprehensive examples for all REST API and gRPC endpoints with real-world use cases.

## Base Configuration

```bash
# Default REST API endpoint
export UAT_API="http://localhost:8080"

# For other nodes
# export UAT_API="http://localhost:8081"  # Validator 2
# export UAT_API="http://localhost:8082"  # Validator 3
```

---

## 1. Node Information & Health

### Get Node Info
Returns node metadata, version, sync status, and network info.

**Request:**
```bash
curl -X GET "${UAT_API}/node-info"
```

**Response:**
```json
{
  "node_id": "QmXx...abc123",
  "version": "0.1.0",
  "chain_id": "unauthority-mainnet",
  "latest_block": 15234,
  "latest_block_hash": "0xabcd...",
  "sync_status": "synced",
  "peer_count": 47,
  "validator_mode": true,
  "uptime_seconds": 3600,
  "network": {
    "total_validators": 128,
    "active_validators": 121,
    "total_stake": 2193623600000000
  }
}
```

**Use Cases:**
- Health monitoring for load balancers
- Sync status verification before sending transactions
- Network statistics for dashboards

---

## 2. Balance & Account Operations

### Get Balance
Query UAT balance for any address.

**Request:**
```bash
# Single address
curl -X GET "${UAT_API}/balance/UAT1a2b3c4d5e6f7g8h9i0j"

# Multiple addresses (comma-separated)
curl -X GET "${UAT_API}/balance/UAT1abc...,UAT2def...,UAT3ghi..."
```

**Response:**
```json
{
  "address": "UAT1a2b3c4d5e6f7g8h9i0j",
  "balance": 1500000000000,
  "balance_uat": "15000.00000000",
  "balance_voi": 1500000000000,
  "nonce": 42,
  "is_validator": true,
  "staked_amount": 100000000000
}
```

**Conversion:**
- 1 UAT = 100,000,000 VOI (Void)
- Example: `1500000000000 VOI = 15000 UAT`

**Error Response:**
```json
{
  "error": "Account not found",
  "address": "UAT1invalid..."
}
```

---

## 3. Transaction Operations

### Send Transaction
Transfer UAT between accounts.

**Request:**
```bash
curl -X POST "${UAT_API}/send" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UAT1sender...",
    "to": "UAT2receiver...",
    "amount": 100000000000,
    "gas_limit": 21000,
    "gas_price": 1000,
    "nonce": 42,
    "signature": "0x123abc..."
  }'
```

**Parameters:**
- `from`: Sender address (UAT format)
- `to`: Recipient address
- `amount`: Amount in VOI (1 UAT = 100,000,000 VOI)
- `gas_limit`: Maximum gas units (default: 21000 for simple transfer)
- `gas_price`: Price per gas unit in VOI (minimum: 1000)
- `nonce`: Transaction count for sender (get from `/balance`)
- `signature`: Ed25519 signature of transaction hash

**Response (Success):**
```json
{
  "success": true,
  "tx_hash": "0xabcd1234...",
  "block_height": 15235,
  "gas_used": 21000,
  "fee_paid": 21000000,
  "finality_time_ms": 2847
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Insufficient balance",
  "required": 121000000000,
  "available": 100000000000
}
```

**Common Errors:**
- `"Insufficient balance"` - Not enough UAT for amount + fees
- `"Invalid nonce"` - Nonce doesn't match account state
- `"Invalid signature"` - Cryptographic signature verification failed
- `"Gas limit too low"` - Increase gas_limit
- `"Account not found"` - Sender address doesn't exist

**Calculate Total Cost:**
```
Total = Amount + (GasLimit × GasPrice)
Example: 100 UAT + (21000 × 1000 VOI) = 10000000000 + 21000000 = 10021000000 VOI
```

---

### Get Transaction by Hash
Retrieve transaction details and confirmation status.

**Request:**
```bash
curl -X GET "${UAT_API}/transaction/0xabcd1234..."
```

**Response:**
```json
{
  "tx_hash": "0xabcd1234...",
  "from": "UAT1sender...",
  "to": "UAT2receiver...",
  "amount": 100000000000,
  "gas_used": 21000,
  "gas_price": 1000,
  "fee_paid": 21000000,
  "nonce": 42,
  "block_height": 15235,
  "block_hash": "0xblock...",
  "timestamp": 1738713600,
  "confirmations": 12,
  "status": "confirmed",
  "signature": "0x123abc..."
}
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

### Get Block Range
Fetch multiple consecutive blocks.

**Request:**
```bash
# Get blocks 100-110
curl -X GET "${UAT_API}/blocks?start=100&end=110"

# Get last 10 blocks
curl -X GET "${UAT_API}/blocks?limit=10"
```

**Response:**
```json
{
  "start_height": 100,
  "end_height": 110,
  "count": 11,
  "blocks": [
    {
      "height": 100,
      "hash": "0x...",
      "timestamp": 1738710000,
      "tx_count": 45
    }
  ]
}
```

---

## 5. Validator Operations

### Get Validator List
Returns all active validators with stake info.

**Request:**
```bash
# All validators
curl -X GET "${UAT_API}/validators"

# Only active validators
curl -X GET "${UAT_API}/validators?active=true"

# Sort by stake (descending)
curl -X GET "${UAT_API}/validators?sort=stake&order=desc"
```

**Response:**
```json
{
  "total_validators": 128,
  "active_validators": 121,
  "total_stake": 219362360000000000,
  "validators": [
    {
      "address": "UAT_val1...",
      "stake": 500000000000000,
      "stake_uat": "5000000.00",
      "voting_power": 2236.06,
      "commission_rate": 5.0,
      "uptime_percent": 99.87,
      "blocks_produced": 1247,
      "last_active_block": 15240,
      "status": "active",
      "slashed": false
    }
  ]
}
```

**Validator Status:**
- `"active"` - Participating in consensus
- `"inactive"` - Insufficient stake or downtime
- `"jailed"` - Slashed and temporarily banned

**Voting Power Calculation:**
```
VotingPower = sqrt(TotalStake)
Example: sqrt(5000000 UAT) = 2236.06
```

---

### Stake/Unstake Tokens
Lock UAT to become validator or increase voting power.

**Stake Request:**
```bash
curl -X POST "${UAT_API}/stake" \
  -H "Content-Type: application/json" \
  -d '{
    "validator_address": "UAT_val1...",
    "amount": 100000000000,
    "delegator_address": "UAT_delegator...",
    "signature": "0xsig..."
  }'
```

**Unstake Request:**
```bash
curl -X POST "${UAT_API}/unstake" \
  -H "Content-Type: application/json" \
  -d '{
    "validator_address": "UAT_val1...",
    "amount": 50000000000,
    "delegator_address": "UAT_delegator...",
    "signature": "0xsig..."
  }'
```

**Response:**
```json
{
  "success": true,
  "tx_hash": "0xstake...",
  "new_stake": 150000000000,
  "new_voting_power": 387.30,
  "unlock_height": 15500
}
```

**Important:**
- Minimum stake: 1,000 UAT (100,000,000,000 VOI)
- Unstaking period: ~7 days (100 blocks)
- Rewards auto-claim on unstake

---

## 6. Smart Contract Operations

### Deploy Contract
Upload WASM bytecode to blockchain.

**Request:**
```bash
curl -X POST "${UAT_API}/contract/deploy" \
  -H "Content-Type: application/json" \
  -d '{
    "bytecode": "0x0061736d01000000...",
    "init_args": "{\"name\":\"MyToken\",\"supply\":1000000}",
    "gas_limit": 500000,
    "deployer": "UAT1deployer...",
    "signature": "0xsig..."
  }'
```

**Response:**
```json
{
  "success": true,
  "contract_address": "UAT_CONTRACT_abc123...",
  "tx_hash": "0xdeploy...",
  "gas_used": 387420,
  "deployment_cost": 387420000
}
```

---

### Call Contract
Execute contract function (state-changing).

**Request:**
```bash
curl -X POST "${UAT_API}/contract/call" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_address": "UAT_CONTRACT_abc123...",
    "method": "transfer",
    "args": "{\"to\":\"UAT2...\",\"amount\":100}",
    "caller": "UAT1caller...",
    "gas_limit": 100000,
    "signature": "0xsig..."
  }'
```

**Response:**
```json
{
  "success": true,
  "tx_hash": "0xcall...",
  "return_value": "{\"success\":true,\"message\":\"Transferred 100 tokens\"}",
  "gas_used": 45000,
  "events": [
    {
      "event_type": "Transfer",
      "data": {
        "from": "UAT1...",
        "to": "UAT2...",
        "amount": 100
      }
    }
  ]
}
```

---

### Query Contract (Read-Only)
Execute view function without transaction.

**Request:**
```bash
curl -X POST "${UAT_API}/contract/query" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_address": "UAT_CONTRACT_abc123...",
    "method": "balanceOf",
    "args": "{\"account\":\"UAT1...\"}"
  }'
```

**Response:**
```json
{
  "success": true,
  "return_value": "{\"balance\":5000}",
  "gas_used": 0
}
```

**Note:** Query operations are free (no gas cost).

---

## 7. Proof-of-Burn (PoB) Operations

### Get Burn Address
Retrieve BTC/ETH deposit addresses for UAT acquisition.

**Request:**
```bash
curl -X POST "${UAT_API}/pob/get-burn-address" \
  -H "Content-Type: application/json" \
  -d '{
    "uat_address": "UAT1recipient...",
    "asset": "BTC"
  }'
```

**Response:**
```json
{
  "uat_address": "UAT1recipient...",
  "burn_address": "bc1q...bitcoin_address",
  "asset": "BTC",
  "current_rate": 456.78,
  "expires_at": 1738717200,
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
FROM="UAT1sender..."
TO="UAT2receiver..."
AMOUNT=100000000000  # 1000 UAT
API="http://localhost:8080"

# Step 1: Get current nonce
NONCE=$(curl -s "${API}/balance/${FROM}" | jq -r '.nonce')

# Step 2: Calculate gas
GAS_LIMIT=21000
GAS_PRICE=1000
TOTAL_FEE=$((GAS_LIMIT * GAS_PRICE))

# Step 3: Check balance
BALANCE=$(curl -s "${API}/balance/${FROM}" | jq -r '.balance')
REQUIRED=$((AMOUNT + TOTAL_FEE))

if [ $BALANCE -lt $REQUIRED ]; then
  echo "Insufficient balance: need $REQUIRED, have $BALANCE"
  exit 1
fi

# Step 4: Create and sign transaction
TX_DATA=$(cat <<EOF
{
  "from": "${FROM}",
  "to": "${TO}",
  "amount": ${AMOUNT},
  "gas_limit": ${GAS_LIMIT},
  "gas_price": ${GAS_PRICE},
  "nonce": ${NONCE}
}
EOF
)

# Sign with private key (use uat-cli in production)
SIGNATURE=$(echo -n "${TX_DATA}" | openssl dgst -sha256 -sign private.key | base64)

# Step 5: Send transaction
RESPONSE=$(curl -s -X POST "${API}/send" \
  -H "Content-Type: application/json" \
  -d "${TX_DATA}" | jq -r '.tx_hash')

echo "Transaction sent: ${RESPONSE}"

# Step 6: Wait for confirmation
while true; do
  STATUS=$(curl -s "${API}/transaction/${RESPONSE}" | jq -r '.status')
  if [ "$STATUS" = "confirmed" ]; then
    echo "Transaction confirmed!"
    break
  fi
  echo "Waiting for confirmation... (status: ${STATUS})"
  sleep 3
done
```

---

### Example 2: Monitor Validator Performance
```bash
#!/bin/bash

VALIDATOR="UAT_validator1..."
API="http://localhost:8080"

while true; do
  DATA=$(curl -s "${API}/validators" | jq ".validators[] | select(.address==\"${VALIDATOR}\")")
  
  STAKE=$(echo $DATA | jq -r '.stake_uat')
  VOTING_POWER=$(echo $DATA | jq -r '.voting_power')
  UPTIME=$(echo $DATA | jq -r '.uptime_percent')
  BLOCKS=$(echo $DATA | jq -r '.blocks_produced')
  STATUS=$(echo $DATA | jq -r '.status')
  
  echo "$(date) | Stake: ${STAKE} UAT | Power: ${VOTING_POWER} | Uptime: ${UPTIME}% | Blocks: ${BLOCKS} | Status: ${STATUS}"
  
  sleep 60
done
```

---

### Example 3: Smart Contract Interaction
```bash
#!/bin/bash

CONTRACT="UAT_CONTRACT_token..."
API="http://localhost:8080"

# Check token balance (free query)
check_balance() {
  curl -s -X POST "${API}/contract/query" \
    -H "Content-Type: application/json" \
    -d "{
      \"contract_address\": \"${CONTRACT}\",
      \"method\": \"balanceOf\",
      \"args\": \"{\\\"account\\\":\\\"$1\\\"}\"
    }" | jq -r '.return_value'
}

# Transfer tokens (paid transaction)
transfer_tokens() {
  curl -s -X POST "${API}/contract/call" \
    -H "Content-Type: application/json" \
    -d "{
      \"contract_address\": \"${CONTRACT}\",
      \"method\": \"transfer\",
      \"args\": \"{\\\"to\\\":\\\"$1\\\",\\\"amount\\\":$2}\",
      \"caller\": \"$3\",
      \"gas_limit\": 100000,
      \"signature\": \"$4\"
    }" | jq -r '.tx_hash'
}

# Usage
BALANCE=$(check_balance "UAT1...")
echo "Current balance: $BALANCE"

TX_HASH=$(transfer_tokens "UAT2..." 100 "UAT1..." "0xsig...")
echo "Transfer TX: $TX_HASH"
```

---

## Error Codes Reference

| Code | Message                    | Solution                              |
|------|----------------------------|---------------------------------------|
| 400  | Invalid request format     | Check JSON syntax                     |
| 401  | Invalid signature          | Re-sign with correct private key      |
| 403  | Insufficient balance       | Add more UAT to account               |
| 404  | Account/TX not found       | Verify address/hash is correct        |
| 409  | Nonce mismatch             | Get latest nonce from `/balance`      |
| 429  | Rate limit exceeded        | Reduce request frequency              |
| 500  | Internal server error      | Check node logs, retry later          |
| 503  | Node not synced            | Wait for sync to complete             |

---

## Rate Limits

Default rate limits per IP:
- General endpoints: 100 requests/minute
- `/send` endpoint: 10 requests/minute
- `/contract/call`: 20 requests/minute
- `/contract/query`: 200 requests/minute (free reads)

**Bypass Rate Limits:**
Contact validator operators for API key (enterprise only).

---

## WebSocket Subscriptions (Real-Time)

### Subscribe to New Blocks
```javascript
const ws = new WebSocket('ws://localhost:8080/ws');

ws.send(JSON.stringify({
  subscribe: 'blocks'
}));

ws.onmessage = (event) => {
  const block = JSON.parse(event.data);
  console.log(`New block: ${block.height}`);
};
```

### Subscribe to Address Transactions
```javascript
ws.send(JSON.stringify({
  subscribe: 'address',
  address: 'UAT1...'
}));
```

---

## Production Best Practices

1. **Always use HTTPS** in production (not HTTP)
2. **Verify SSL certificates** to prevent MITM attacks
3. **Implement retry logic** with exponential backoff
4. **Cache node-info** for 30 seconds (avoid spam)
5. **Monitor rate limits** and implement queuing
6. **Use multiple RPC endpoints** for redundancy
7. **Validate all responses** before processing
8. **Never log private keys** or signatures
9. **Use environment variables** for addresses/keys
10. **Test on testnet first** before mainnet deployment

---

## Additional Resources

- [Full REST API Reference](API_REFERENCE.md)
- [gRPC Protocol Documentation](../uat.proto)
- [Smart Contract Development Guide](../examples/contracts/README.md)
- [Node Operation Manual](user/NODE_SETUP.md)
- [Whitepaper](WHITEPAPER.md)
