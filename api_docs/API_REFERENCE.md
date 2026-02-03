# Unauthority (UAT) API Reference

## REST API Endpoints

### 1. POST /deploy-contract
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
curl -X POST http://localhost:8080/deploy-contract \
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
