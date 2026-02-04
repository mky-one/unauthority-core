# UAT Smart Contract Examples

This directory contains example smart contracts for the Unauthority (UAT) blockchain.

## Prerequisites

Install the WASM target for Rust:
```bash
rustup target add wasm32-unknown-unknown
```

## Building Contracts

Build all contracts:
```bash
cd examples/contracts
cargo build --release --target wasm32-unknown-unknown
```

WASM binaries will be in `target/wasm32-unknown-unknown/release/`.

## Contract Examples

### 1. Hello World (`hello_world.rs`)

**Purpose:** Demonstrates basic storage operations.

**Build:**
```bash
cargo build --release --target wasm32-unknown-unknown --bin hello_world
```

**Deploy:**
```bash
uat-cli deploy target/wasm32-unknown-unknown/release/hello_world.wasm
```

**Usage:**
```bash
# Set a value
uat-cli call <CONTRACT_ADDR> '{"Set": {"key": "greeting", "value": "Hello UAT"}}'

# Get a value
uat-cli call <CONTRACT_ADDR> '{"Get": {"key": "greeting"}}'

# List all keys
uat-cli call <CONTRACT_ADDR> '{"ListAll": {}}'

# Delete a key
uat-cli call <CONTRACT_ADDR> '{"Delete": {"key": "greeting"}}'
```

---

### 2. ERC20-like Token (`token.rs`)

**Purpose:** Fungible token with transfer and allowance mechanisms.

**Build:**
```bash
cargo build --release --target wasm32-unknown-unknown --bin token
```

**Deploy:**
```bash
uat-cli deploy target/wasm32-unknown-unknown/release/token.wasm \
  --init-args '{"name":"MyToken","symbol":"MTK","total_supply":1000000}'
```

**Usage:**
```bash
# Check balance
uat-cli call <CONTRACT_ADDR> '{"BalanceOf": {"account": "UAT123..."}}'

# Transfer tokens
uat-cli call <CONTRACT_ADDR> '{"Transfer": {"to": "UAT456...", "amount": 100}}'

# Approve spender
uat-cli call <CONTRACT_ADDR> '{"Approve": {"spender": "UAT789...", "amount": 50}}'

# Transfer from (using allowance)
uat-cli call <CONTRACT_ADDR> '{"TransferFrom": {"from": "UAT123...", "to": "UAT999...", "amount": 50}}'

# Get token info
uat-cli call <CONTRACT_ADDR> '{"TokenInfo": {}}'
```

---

### 3. Oracle Price Feed (`oracle_price_feed.rs`)

**Purpose:** Demonstrates oracle integration for fetching external price data.

**Build:**
```bash
cargo build --release --target wasm32-unknown-unknown --bin oracle_price_feed
```

**Deploy:**
```bash
uat-cli deploy target/wasm32-unknown-unknown/release/oracle_price_feed.wasm
```

**Usage:**
```bash
# Fetch latest BTC price from oracle
uat-cli call <CONTRACT_ADDR> '{"FetchPrice": {"asset": "BTC"}}'

# Get stored latest price
uat-cli call <CONTRACT_ADDR> '{"GetLatestPrice": {"asset": "BTC"}}'

# Get average price (last 10 periods)
uat-cli call <CONTRACT_ADDR> '{"GetAveragePrice": {"asset": "ETH", "periods": 10}}'

# Get price history (last 20 records)
uat-cli call <CONTRACT_ADDR> '{"GetPriceHistory": {"asset": "BTC", "limit": 20}}'

# Subscribe to price alerts
uat-cli call <CONTRACT_ADDR> '{"Subscribe": {"asset": "ETH", "threshold_percent": 5}}'
```

---

## Contract Development Guidelines

### Gas Optimization
- Use `opt-level = "z"` in `Cargo.toml` for smaller binaries
- Enable LTO (Link-Time Optimization)
- Avoid unnecessary allocations
- Use `#[inline]` for small functions

### Security Best Practices
- Validate all inputs
- Check for integer overflow (use `checked_*` methods)
- Implement proper access control
- Avoid reentrancy vulnerabilities
- Use safe arithmetic operations

### Testing
```bash
# Test contracts locally
cargo test

# Integration test with local node
uat-cli test <CONTRACT_WASM>
```

### Debugging
```bash
# Check WASM binary size
wasm-opt --version
wasm-opt -Oz input.wasm -o optimized.wasm

# Inspect WASM
wasm-objdump -x contract.wasm
```

## Advanced Topics

### Using External Libraries
Add dependencies in `Cargo.toml`:
```toml
[dependencies]
borsh = "0.10"  # Efficient serialization
```

### Calling Other Contracts
```rust
// In production, use host function:
let result = unsafe {
    host_call_contract(
        contract_addr.as_ptr(),
        method.as_ptr(),
        args.as_ptr()
    )
};
```

### Event Emission
```rust
// Emit events for frontend indexing
unsafe {
    host_emit_event(
        event_name.as_ptr(),
        event_data.as_ptr()
    );
}
```

## Resources

- [UVM Documentation](../../docs/developer/SMART_CONTRACTS.md)
- [UAT Whitepaper](../../docs/WHITEPAPER.md)
- [API Reference](../../api_docs/API_REFERENCE.md)
