# Smart Contracts — Unauthority (LOS)

UVM (Unauthority Virtual Machine), USP-01 token standard, WASM contract development, and deployment guide.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Contract Lifecycle](#contract-lifecycle)
3. [Development Setup](#development-setup)
4. [SDK Reference (los-sdk)](#sdk-reference-los-sdk)
5. [Host Functions](#host-functions)
6. [USP-01 Token Standard](#usp-01-token-standard)
7. [Gas Metering](#gas-metering)
8. [Oracle Integration](#oracle-integration)
9. [Deployment](#deployment)
10. [Execution](#execution)
11. [Example Contracts](#example-contracts)
12. [Security Considerations](#security-considerations)
13. [Limitations](#limitations)

---

## Architecture

The Unauthority Virtual Machine (UVM) executes WASM (WebAssembly) smart contracts:

```
┌────────────────────────────────────────────┐
│              Contract Call                  │
│  (contract_address, function, args, gas)   │
└──────────────────┬─────────────────────────┘
                   ▼
┌──────────────────────────────────────────────┐
│              WasmEngine (los-vm)              │
│  ┌──────────────────────────────────────┐    │
│  │  Wasmer Runtime + Cranelift Backend  │    │
│  │  ┌────────────────────────────────┐  │    │
│  │  │  Gas Metering (1 instr = 1 gas)│  │    │
│  │  └────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────┐  │    │
│  │  │  16 Host Functions (SDK)       │  │    │
│  │  │  state, events, crypto, ctx    │  │    │
│  │  └────────────────────────────────┘  │    │
│  └──────────────────────────────────────┘    │
│  ┌──────────────────────────────────────┐    │
│  │  Contract Storage (BTreeMap)          │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

**Runtime:** Wasmer with Cranelift compiler backend
**Metering:** wasmer-middlewares (1 WASM instruction = 1 gas unit)
**Timeout:** 5 seconds wall-clock maximum

---

## Contract Lifecycle

```
1. Develop    (Rust → WASM via cargo build --target wasm32-unknown-unknown)
2. Deploy     (POST /contract/deploy with bytecode + gas)
3. Execute    (POST /contract/execute with function + args + gas)
4. Query      (GET /contract/{address}/{key})
5. Events     (emitted via host function, included in ContractResult)
```

### Contract Address

Deterministic address derived via blake3 hash:

```
address = "LOSCon" + hex(blake3(bytecode))[..40]
```

This means the same bytecode always produces the same contract address, enabling reproducible deployments.

---

## Development Setup

### Prerequisites

```bash
# Add WASM target
rustup target add wasm32-unknown-unknown

# Verify
rustup target list | grep wasm32
```

### Project Structure

```
my-contract/
├── Cargo.toml
└── src/
    └── lib.rs
```

### Cargo.toml

```toml
[package]
name = "my-contract"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
los-sdk = { path = "../../crates/los-sdk" }

[profile.release]
opt-level = "z"      # Minimize binary size
lto = true           # Link-time optimization
codegen-units = 1    # Max optimization
strip = true         # Strip debug symbols
```

### Build

```bash
cargo build --release --target wasm32-unknown-unknown
# Output: target/wasm32-unknown-unknown/release/my_contract.wasm
```

### Contract Template

```rust
#![no_std]
extern crate los_sdk;
use los_sdk::*;

#[no_mangle]
pub extern "C" fn init() {
    // Called once on deployment
    state::set_str("owner", &caller());
    state::set_u128("total_supply", 0);
    log("Contract initialized");
}

#[no_mangle]
pub extern "C" fn my_function() {
    let sender = caller();
    let amount = arg(0)
        .and_then(|s| s.parse::<u128>().ok())
        .unwrap_or(0);

    // Business logic here
    state::set_u128("balance", amount);
    event::emit("Transfer", &format!("{{\"from\":\"{}\",\"amount\":{}}}", sender, amount));
    set_return_str("success");
}
```

---

## SDK Reference (los-sdk)

The `los-sdk` crate is a `#![no_std]` library targeting `wasm32-unknown-unknown`. It provides all APIs a contract needs to interact with the blockchain.

### State Management

```rust
// String key-value
state::set("key", "value");
let val: Option<String> = state::get("key");

// Typed helpers
state::set_str("name", "My Token");
state::set_u128("balance", 1_000_000);
state::set_u64("timestamp", 1234567890);

let name: Option<String> = state::get_str("name");
let balance: Option<u128> = state::get_u128("balance");
let ts: Option<u64> = state::get_u64("timestamp");

// Delete and check
state::del("temp_key");
let exists: bool = state::exists("balance");
```

### Events

```rust
// Emit event with JSON data
event::emit("Transfer", "{\"from\":\"LOS...\",\"to\":\"LOS...\",\"amount\":100}");
event::emit("Approval", "{\"owner\":\"LOS...\",\"spender\":\"LOS...\"}");
```

Events are collected in the `ContractResult` and can be queried by clients.

### Context

```rust
let sender: String = caller();          // Who called this contract
let me: String = self_address();        // This contract's address
let bal: u128 = balance();              // This contract's CIL balance
let now: u64 = timestamp();             // Current block timestamp
```

### Arguments

```rust
let count: u32 = arg_count();           // Number of arguments
let first: Option<String> = arg(0);     // First argument
let second: Option<String> = arg(1);    // Second argument
```

### Transfer

```rust
// Send CIL from contract to recipient
match transfer("LOSrecipient...", 1_000_000) {
    Ok(()) => log("Transfer successful"),
    Err(e) => abort(e),
}
```

### Crypto

```rust
let hash: [u8; 32] = crypto::blake3(b"some data");
```

### Return Value

```rust
set_return_str("success");
set_return(b"binary data");
```

### Logging & Abort

```rust
log("Debug message");              // Logged but not visible to users
abort("Fatal error: invalid state");   // Terminates execution, reverts state
```

---

## Host Functions

The UVM exposes 16 host functions to WASM contracts:

| # | Category | Extern Function | Description |
|---|---|---|---|
| 1 | State | `host_state_set(k_ptr, k_len, v_ptr, v_len)` | Write key-value |
| 2 | State | `host_state_get(k_ptr, k_len) → ptr` | Read value (returns ptr+len) |
| 3 | State | `host_state_del(k_ptr, k_len)` | Delete key |
| 4 | State | `host_state_exists(k_ptr, k_len) → i32` | Check existence |
| 5 | Events | `host_emit_event(type_ptr, type_len, data_ptr, data_len)` | Emit event |
| 6 | Crypto | `host_blake3(data_ptr, data_len, out_ptr)` | Blake3 hash |
| 7 | Context | `host_caller(out_ptr, out_len) → i32` | Get caller address |
| 8 | Context | `host_self_address(out_ptr, out_len) → i32` | Get contract address |
| 9 | Context | `host_balance() → i64` | Get contract balance |
| 10 | Context | `host_timestamp() → i64` | Get block timestamp |
| 11 | Args | `host_arg_count() → i32` | Argument count |
| 12 | Args | `host_arg(idx, out_ptr, out_len) → i32` | Get argument |
| 13 | Transfer | `host_transfer(addr_ptr, addr_len, amount) → i32` | Send CIL |
| 14 | Return | `host_set_return(ptr, len)` | Set return value |
| 15 | Logging | `host_log(ptr, len)` | Debug log |
| 16 | Abort | `host_abort(ptr, len) → !` | Abort execution |

### Memory Protocol

Host-to-guest writes use the exported `__los_alloc(size) → ptr` function. The SDK provides a bump allocator that grows WASM linear memory as needed.

---

## USP-01 Token Standard

The native fungible token standard for Unauthority.

### Interface

Every USP-01 contract must export these functions:

```rust
#[no_mangle] pub extern "C" fn name()           // → token name
#[no_mangle] pub extern "C" fn symbol()          // → token ticker
#[no_mangle] pub extern "C" fn decimals()        // → decimal places
#[no_mangle] pub extern "C" fn total_supply()    // → total supply
#[no_mangle] pub extern "C" fn balance_of()      // arg(0) = address → balance
#[no_mangle] pub extern "C" fn transfer()        // arg(0) = to, arg(1) = amount
#[no_mangle] pub extern "C" fn approve()         // arg(0) = spender, arg(1) = amount
#[no_mangle] pub extern "C" fn allowance()       // arg(0) = owner, arg(1) = spender → amount
#[no_mangle] pub extern "C" fn transfer_from()   // arg(0) = from, arg(1) = to, arg(2) = amount
```

### Events (standard)

| Event | Data |
|---|---|
| `Transfer` | `{"from": "LOS...", "to": "LOS...", "amount": "1000"}` |
| `Approval` | `{"owner": "LOS...", "spender": "LOS...", "amount": "500"}` |

### Use Cases

- **Custom tokens** — any project can issue tokens on Unauthority
- **Wrapped assets** — wBTC, wETH via Proof-of-Burn bridge
- **Stablecoins** — using oracle price feeds
- **Governance tokens** — for DAO voting

---

## Gas Metering

### Model

Deterministic gas metering via wasmer-middlewares:

```
1 WASM instruction = 1 gas unit
1 gas unit = 1 CIL (GAS_PRICE_CIL = 1)
```

### Costs

| Operation | Gas Cost |
|---|---|
| WASM instruction | 1 |
| Contract compilation | 100 per KB bytecode |
| State write | Part of WASM instructions (no extra charge) |
| State read | Part of WASM instructions |
| Event emit | Part of WASM instructions |
| Transfer | Part of WASM instructions |

### Limits

| Limit | Value |
|---|---|
| Default gas limit | 1,000,000 |
| Max bytecode size | 1 MB |
| Wall-clock timeout | 5 seconds |
| Max thread leaks | 16 |

### Fee Structure

```
deployment_fee = max(gas_used × GAS_PRICE_CIL, MIN_DEPLOY_FEE_CIL)
execution_fee = gas_used × GAS_PRICE_CIL
```

Where `MIN_DEPLOY_FEE_CIL = 1,000,000,000` (0.01 LOS minimum deploy fee).

### Determinism

Gas metering is deterministic — the same contract call with the same inputs always consumes the same gas on all validators. This is critical for consensus, as validators must agree on execution results.

---

## Oracle Integration

Smart contracts can access the decentralized oracle price feeds:

### Oracle Connector Module

```rust
// Inside los-vm/src/oracle_connector.rs
fn get_oracle_price(pair: &str) -> Option<u128> {
    // Returns price in micro-USD (1 USD = 1,000,000)
    // e.g., "ETH/USD" → 2_500_000_000 ($2,500.00)
}
```

### Available Price Feeds

| Pair | Format | Example |
|---|---|---|
| `ETH/USD` | micro-USD | 2,500,000,000 ($2,500) |
| `BTC/USD` | micro-USD | 83,000,000,000 ($83,000) |

### Security

- Prices are BFT median of all validator submissions
- Outliers (>20% deviation) are rejected
- Zero prices are rejected
- All values are u128 — cannot be NaN/Inf/negative

---

## Deployment

### Via REST API

```bash
# Build the contract
cargo build --release --target wasm32-unknown-unknown

# Deploy (Base64-encoded bytecode)
BYTECODE=$(base64 < target/wasm32-unknown-unknown/release/my_contract.wasm)

curl -X POST http://127.0.0.1:3030/contract/deploy \
  -H "Content-Type: application/json" \
  -d "{
    \"bytecode\": \"$BYTECODE\",
    \"deployer\": \"LOSyour_address...\",
    \"gas_limit\": 1000000
  }"
```

### Response

```json
{
  "status": "deployed",
  "contract_address": "LOSCona1b2c3d4e5f6...",
  "code_hash": "3a7b8c9d...",
  "gas_used": 2340
}
```

---

## Execution

### Via REST API

```bash
curl -X POST http://127.0.0.1:3030/contract/execute \
  -H "Content-Type: application/json" \
  -d "{
    \"contract\": \"LOSCona1b2c3d4e5f6...\",
    \"function\": \"transfer\",
    \"args\": [\"LOSrecipient...\", \"1000000\"],
    \"caller\": \"LOSsender...\",
    \"gas_limit\": 500000
  }"
```

### Response

```json
{
  "success": true,
  "output": "ok",
  "gas_used": 12450,
  "state_changes": {
    "balance:LOSsender...": "900000",
    "balance:LOSrecipient...": "1100000"
  },
  "events": [
    {
      "contract": "LOSCona1b2c3d4e5f6...",
      "event_type": "Transfer",
      "data": {"from": "LOSsender...", "to": "LOSrecipient...", "amount": "1000000"},
      "timestamp": 1234567890
    }
  ]
}
```

### Query State

```bash
# Read a specific key from contract storage
curl http://127.0.0.1:3030/contract/LOSCona1b2c3d4e5f6.../balance:LOSowner...
```

---

## Example Contracts

Example contracts are available in `examples/contracts/`:

| Contract | File | Description |
|---|---|---|
| Hello World | `hello_world.rs` | Basic contract demonstrating SDK usage |
| Simple Storage | `simple_storage.rs` | Key-value storage contract |
| Token | `token.rs` | USP-01 fungible token implementation |
| DEX AMM | `dex_amm.rs` | Constant-product AMM (x*y=k) |
| Oracle Price Feed | `oracle_price_feed.rs` | Oracle integration example |

### Building Examples

```bash
cd examples/contracts
cargo build --release --target wasm32-unknown-unknown
```

---

## Security Considerations

### WASM Sandboxing

- WASM runs in a memory-safe sandbox (wasmer)
- No filesystem access, no network access, no syscalls
- All external interactions go through the 16 host functions
- Gas metering prevents infinite loops
- Wall-clock timeout (5s) prevents resource exhaustion

### State Isolation

- Each contract has its own `BTreeMap<String, String>` storage
- Contracts cannot read/write other contracts' state
- Transfers between contracts go through the host function

### Reentrancy

- Host `transfer()` does not re-enter WASM execution
- State changes are atomic within a single call
- No callback mechanism exists (no reentrancy vector)

### Integer-Only

- Contract balance is `u128` CIL
- All arithmetic should use checked operations
- The SDK uses `u128` for amounts — no floating point

---

## Limitations

| Limitation | Details |
|---|---|
| Max bytecode | 1 MB |
| Max execution time | 5 seconds |
| Max gas | User-specified (default 1M) |
| No cross-contract calls | Contracts cannot call other contracts (planned) |
| No upgradability | Deployed bytecode is immutable |
| Single-thread | WASM execution is single-threaded |
| State format | String key-value only (JSON serialization recommended) |
| No floating point | WASM f32/f64 available but non-deterministic — avoid in consensus |
