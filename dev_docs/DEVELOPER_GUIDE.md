# Developer Guide — Unauthority (LOS)

Build, test, contribute, and understand the development workflow.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Setup](#repository-setup)
3. [Build](#build)
4. [Run Tests](#run-tests)
5. [Run a Local Node](#run-a-local-node)
6. [Project Structure](#project-structure)
7. [Coding Standards](#coding-standards)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Common Tasks](#common-tasks)
10. [Debugging](#debugging)
11. [Contributing](#contributing)

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Rust | 1.75+ (stable) | All backend code |
| Cargo | (bundled with Rust) | Build system |
| Tor | 0.4.7+ | SOCKS5 proxy for integration tests |
| Protobuf Compiler | 3.x | gRPC proto compilation (build.rs) |
| Git | 2.x | Version control |
| Flutter | 3.x | Frontend apps (optional) |

### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustup target add wasm32-unknown-unknown   # For smart contract examples
```

### Install Protobuf Compiler

```bash
# macOS
brew install protobuf

# Ubuntu/Debian
sudo apt install protobuf-compiler
```

### Install Tor (for integration tests)

```bash
# macOS
brew install tor && brew services start tor

# Ubuntu/Debian
sudo apt install tor && sudo systemctl start tor
```

---

## Repository Setup

```bash
git clone git@github.com:mky-one/unauthority-core.git
cd unauthority-core
```

The repository uses a Cargo workspace with the following members:

```
unauthority-core/
├── Cargo.toml              # Workspace root
├── crates/
│   ├── los-node/           # Main validator binary (uat-node)
│   ├── los-core/           # Blockchain primitives
│   ├── los-consensus/      # aBFT, slashing, voting
│   ├── los-network/        # P2P, Tor transport
│   ├── los-crypto/         # Dilithium5, SHA-3
│   ├── los-vm/             # WASM smart contracts
│   ├── los-cli/            # CLI wallet
│   └── los-sdk/            # Smart contract SDK (no_std)
├── genesis/                # Genesis generators
├── examples/contracts/     # Example WASM contracts
├── tests/                  # Integration tests
├── flutter_wallet/         # Flutter wallet app
└── flutter_validator/      # Flutter validator dashboard
```

---

## Build

### Debug Build

```bash
cargo build
```

### Release Build (optimized)

```bash
cargo build --release
```

Binary output: `target/release/uat-node`

### Build with Mainnet Feature

```bash
cargo build --release --features mainnet
```

The `mainnet` feature flag:
- Enables strict genesis validation
- Disables testnet bonding curve (`f64::ln()`)
- Disables mock contract dispatch
- Requires `genesis_config.json` to be present

### Build Specific Crate

```bash
cargo build -p los-core
cargo build -p los-consensus
cargo build -p los-node --release
```

### Check for Warnings

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

**Zero warnings policy:** All code must compile with zero clippy warnings.

---

## Run Tests

### All Tests

```bash
cargo test --release
```

### Specific Crate

```bash
cargo test --release -p los-core
cargo test --release -p los-consensus
cargo test --release -p los-crypto
cargo test --release -p los-network
cargo test --release -p los-vm
cargo test --release -p los-cli
```

### Specific Test

```bash
cargo test --release -p los-core test_validator_rewards
cargo test --release -p los-consensus test_quadratic_voting
```

### Test Summary

```bash
cargo test --release 2>&1 | grep 'test result:'
```

Current status: **226 tests, 0 failures, 0 warnings.**

### Integration Tests

```bash
cargo test --release --test integration_test
cargo test --release --test e2e_los_mainnet
```

---

## Run a Local Node

### Minimal (Auto-Bootstrap)

```bash
cargo run --release -- --port 3030 --data-dir ./my-node --node-id dev-node
```

The node will:
1. Load genesis config (embedded at compile-time)
2. Auto-detect Tor SOCKS5 at `127.0.0.1:9050`
3. Bootstrap peers from genesis `.onion` addresses
4. Start REST API on port 3030, P2P on 4030, gRPC on 23030

### With Manual Configuration

```bash
export LOS_NETWORK=testnet
export LOS_TOR_SOCKS=127.0.0.1:9050
export LOS_BOOTSTRAP_PEERS="abc.onion:4030,def.onion:4031"

cargo run --release -- \
  --port 3030 \
  --data-dir ./my-node \
  --node-id dev-node
```

### Verify It's Running

```bash
curl http://127.0.0.1:3030/status
```

### CLI Flags

| Flag | Default | Description |
|---|---|---|
| `--port` | `3030` | REST API port |
| `--data-dir` | `./data` | Persistent data directory |
| `--node-id` | `node` | Node identifier for logs |

### Port Derivation

From the `--port` flag:
- REST API: `--port` value (e.g., 3030)
- P2P Gossip: `--port + 1000` (e.g., 4030)
- gRPC: `--port + 20000` (e.g., 23030)

---

## Project Structure

### Crate Dependencies

```
los-node ── top-level binary
├── los-core       ── Block, Ledger, AccountState, constants
├── los-consensus  ── aBFT, slashing, voting, checkpoints
│   └── los-core
├── los-network    ── P2P, Tor, fee scaling
│   └── los-core
├── los-crypto     ── Dilithium5, key management
├── los-vm         ── WASM engine, contract execution
│   └── los-core
├── los-cli        ── CLI wallet/query tool
│   ├── los-core
│   └── los-crypto
└── los-sdk        ── Smart contract SDK (no_std, wasm32)
```

### Key Files

| File | Purpose |
|---|---|
| `crates/los-node/src/main.rs` | ~9000 lines. REST API, P2P gossip, burn pipeline, epoch processing |
| `crates/los-core/src/lib.rs` | Block, AccountState, Ledger, process_block validation |
| `crates/los-consensus/src/abft.rs` | aBFT consensus engine |
| `crates/los-consensus/src/slashing.rs` | Validator slashing logic |
| `crates/los-consensus/src/voting.rs` | Quadratic voting |
| `crates/los-network/src/tor_transport.rs` | Tor SOCKS5 transport |
| `crates/los-crypto/src/lib.rs` | Dilithium5 key management |
| `crates/los-vm/src/lib.rs` | WASM smart contract engine |
| `genesis/src/lib.rs` | Genesis config parsing |
| `genesis_config.json` | Mainnet genesis configuration |

---

## Coding Standards

### Mandatory Rules

1. **No `unwrap()` in production code** — use `?`, `match`, or `.unwrap_or_default()`
2. **No `f32`/`f64` in consensus-critical paths** — use `u128` integer math
3. **No `TODO` or `unimplemented!()`** — all code must be complete
4. **Zero clippy warnings** — enforce with `cargo clippy -- -D warnings`
5. **All public functions must have doc comments**
6. **Use `checked_mul`/`checked_add`** for overflow-sensitive arithmetic

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Crate | `los-{name}` | `los-core`, `los-vm` |
| Module | `snake_case` | `oracle_consensus.rs` |
| Struct | `PascalCase` | `AccountState`, `WasmEngine` |
| Function | `snake_case` | `calculate_voting_power()` |
| Constant | `SCREAMING_SNAKE` | `CIL_PER_LOS`, `BASE_FEE_CIL` |
| Amount variables | suffix `_cil` for CIL, `_los` for LOS | `balance_cil`, `stake_los` |

### Error Handling

```rust
// Good — propagate errors
fn process() -> Result<(), Box<dyn Error>> {
    let data = read_file()?;
    let block = parse_block(&data)?;
    Ok(())
}

// Good — handle gracefully
match ledger.process_block(&block) {
    Ok(ProcessResult::Applied(hash)) => log::info!("Applied: {}", hash),
    Ok(ProcessResult::Duplicate(hash)) => log::debug!("Duplicate: {}", hash),
    Err(e) => log::error!("Failed: {}", e),
}

// BAD — never do this
let result = something.unwrap(); // panics on None/Err
```

### Integer Math

```rust
// Good — integer-only
let reward = budget
    .checked_mul(isqrt(stake))
    .unwrap_or(0)
    / total_weight;

// Good — basis points (10,000 = 100%)
let uptime_bps = (heartbeats * 10_000) / total_expected;
let eligible = uptime_bps >= 9_500; // 95%

// BAD — never use float in consensus
let ratio = stake as f64 / total as f64; // NON-DETERMINISTIC
```

---

## CI/CD Pipeline

### GitHub Actions

The CI pipeline runs on every push and pull request:

1. **Format Check** — `cargo fmt --check`
2. **Clippy Lint** — `cargo clippy --all-targets -- -D warnings`
3. **Build** — `cargo build --release`
4. **Unit Tests** — `cargo test --release` (all crates)
5. **Integration Tests** — `cargo test --release --test integration_test`

### Pre-Push Checklist

```bash
# 1. Format
cargo fmt

# 2. Lint (zero warnings)
cargo clippy --all-targets --all-features -- -D warnings

# 3. Build
cargo build --release

# 4. Test
cargo test --release

# 5. All good? Push.
git push origin main
```

---

## Common Tasks

### Add a New REST Endpoint

1. Open `crates/los-node/src/main.rs`
2. Find the Warp route definitions (search for `warp::path`)
3. Add a new route:

```rust
let my_route = warp::path("my-endpoint")
    .and(warp::get())
    .and(ledger_filter.clone())
    .and_then(handle_my_endpoint);
```

4. Implement the handler function
5. Add the route to the `routes` combinator
6. Update `docs/API_REFERENCE.md`

### Add a New Block Type

1. Add variant to `BlockType` enum in `crates/los-core/src/lib.rs`
2. Add serialization handling
3. Add validation in `Ledger::process_block()`
4. Add consensus handling in `crates/los-consensus/src/abft.rs`
5. Add tests
6. Update `docs/ARCHITECTURE.md`

### Add a New Consensus Constant

1. Add to `crates/los-core/src/lib.rs` (constants section)
2. Use `u128` for any financial/consensus value
3. Add unit tests
4. Document in `dev_docs/CONSENSUS.md`

### Modify Genesis

1. Update allocation in `genesis/src/lib.rs`
2. Update generators in `genesis/src/bin/`
3. Regenerate testnet wallets: `cargo run -p genesis --bin testnet_generator`
4. Update `genesis_config.json`
5. Document in `dev_docs/GENESIS.md`

---

## Debugging

### Enable Trace Logging

```bash
export LOS_LOG_LEVEL=trace
cargo run --release -- --port 3030 --data-dir ./debug-node --node-id debug
```

### Check Prometheus Metrics

```bash
curl http://127.0.0.1:3030/metrics
```

45+ metrics available including block counts, peer counts, consensus rounds, fees, and more.

### Inspect Ledger State

```bash
# All accounts
curl http://127.0.0.1:3030/accounts

# Specific account
curl http://127.0.0.1:3030/account/LOSxxxxxxx

# Account history
curl http://127.0.0.1:3030/account/LOSxxxxxxx/history

# Supply breakdown
curl http://127.0.0.1:3030/supply
```

### Debug P2P Issues

```bash
# Check connected peers
curl http://127.0.0.1:3030/peers

# Check Tor connectivity
curl --socks5-hostname 127.0.0.1:9050 http://YOUR_ONION.onion:3030/status
```

### Common Build Issues

| Issue | Solution |
|---|---|
| `protoc not found` | Install: `brew install protobuf` or `apt install protobuf-compiler` |
| `pqcrypto build fails` | Ensure C compiler available: `xcode-select --install` (macOS) |
| `wasmer link error` | Clean and rebuild: `cargo clean && cargo build --release` |
| `sled lock conflict` | Stop any running node using the same `--data-dir` |

---

## Contributing

### Branch Strategy

- `main` — stable, always green CI
- Feature branches — `feature/my-feature`
- Fix branches — `fix/issue-description`

### Pull Request Process

1. Create a feature/fix branch
2. Make changes, ensuring zero clippy warnings
3. Run full test suite: `cargo test --release`
4. Push and create PR against `main`
5. PR must pass CI (format, lint, build, test)
6. Squash merge after approval

### Commit Messages

```
<type>: <short description>

Types: feat, fix, docs, refactor, test, ci, chore
Examples:
  feat: add oracle price caching
  fix: prevent overflow in reward calculation
  docs: update API reference for /burn endpoint
```
