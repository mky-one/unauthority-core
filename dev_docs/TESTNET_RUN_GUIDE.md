# Testnet Run Guide

Step-by-step instructions for running the Unauthority testnet locally on your machine.

---

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Rust | 1.75+ | `rustc --version` |
| Cargo | latest | `cargo --version` |
| curl | any | `curl --version` |
| jq | any (optional) | `jq --version` |

Install Rust (if not installed):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

---

## 1. Build the Node

From the project root directory:

```bash
cd /path/to/unauthority-core

# Release build (recommended — much faster runtime)
cargo build --release -p uat-node

# Verify binary exists
ls -la target/release/uat-node
```

Build time: ~2-5 minutes on first build, depending on your machine.

---

## 2. Start the 4-Validator Testnet

### Option A: Automatic (recommended)

```bash
chmod +x start.sh stop.sh
./start.sh
```

This starts 4 validator nodes:

| Node | REST API | gRPC | Node ID |
|------|----------|------|---------|
| Validator-1 | `http://localhost:3030` | `:23030` | validator-1 |
| Validator-2 | `http://localhost:3031` | `:23031` | validator-2 |
| Validator-3 | `http://localhost:3032` | `:23032` | validator-3 |
| Validator-4 | `http://localhost:3033` | `:23033` | validator-4 |

### Option B: Manual (single node, dev mode)

For quick testing with faucet enabled and instant finalization:

```bash
export UAT_TESTNET_LEVEL=functional
export UAT_NODE_ID=validator-1
./target/release/uat-node 3030
```

### Option C: Manual (single node, consensus mode)

Real aBFT consensus, real Dilithium5 signatures:

```bash
export UAT_TESTNET_LEVEL=consensus
export UAT_NODE_ID=validator-1
./target/release/uat-node 3030
```

---

## 3. Verify Nodes are Running

```bash
# Check all 4 nodes
for port in 3030 3031 3032 3033; do
  echo "--- Port $port ---"
  curl -s http://localhost:$port/node-info | jq .
done
```

Expected output per node:
```json
{
  "node_id": "validator-1",
  "version": "1.0.0",
  "uptime_seconds": 42,
  "block_count": 0,
  "account_count": 8
}
```

---

## 4. Check Genesis Balances

Genesis allocates 8 dev wallets + 4 bootstrap validators. Verify:

```bash
# Check total supply
curl -s http://localhost:3030/supply | jq .

# Check validators
curl -s http://localhost:3030/validators | jq .
```

---

## 5. Use the Faucet (Get Test UAT)

The faucet gives you **5,000 UAT** per request (1 claim per hour per address).

> Faucet is available in `functional` and `consensus` testnet modes only. Not available in `production` mode.

```bash
# Request test coins to any address
curl -s -X POST http://localhost:3030/faucet \
  -H "Content-Type: application/json" \
  -d '{"address": "UATtestMyWalletAddress123"}' | jq .
```

Expected response:
```json
{
  "status": "ok",
  "msg": "Faucet sent 5,000 UAT",
  "amount_uat": 5000,
  "tx_hash": "abc123..."
}
```

---

## 6. Send a Transaction

```bash
# Send 100 UAT from one address to another
curl -s -X POST http://localhost:3030/send \
  -H "Content-Type: application/json" \
  -d '{
    "from": "UATtestMyWalletAddress123",
    "to": "UATanotherAddress456",
    "amount_void": 10000000000000
  }' | jq .
```

> Note: `amount_void` is in VOID units. 1 UAT = 100,000,000,000 VOID (10^11).
> So 100 UAT = 10,000,000,000,000 VOID = `10000000000000`.

---

## 7. Check Balance

```bash
# Check specific account balance
curl -s http://localhost:3030/account/UATtestMyWalletAddress123 | jq .
```

---

## 8. Monitor the Network

```bash
# Node health
curl -s http://localhost:3030/node-info | jq .

# Connected peers
curl -s http://localhost:3030/peers | jq .

# Consensus status (only in consensus/production mode)
curl -s http://localhost:3030/consensus | jq .

# Oracle prices
curl -s http://localhost:3030/oracle-prices | jq .

# Metrics (Prometheus format)
curl -s http://localhost:3030/metrics

# List all blocks
curl -s http://localhost:3030/blocks | jq .

# Transaction history for an account
curl -s http://localhost:3030/history/UATtestMyWalletAddress123 | jq .
```

---

## 9. View Logs

```bash
# Live logs for validator-1
tail -f node_data/validator-1/logs/node.log

# Live logs for all validators
tail -f node_data/validator-*/logs/node.log

# Check for errors only
grep -i "error\|panic\|fail" node_data/validator-1/logs/node.log
```

---

## 10. Stop the Testnet

```bash
./stop.sh
```

Or manually:
```bash
# Kill all uat-node processes
pkill -f uat-node
```

---

## 11. Reset Data (Fresh Start)

To wipe all node data and start fresh:

```bash
./stop.sh
rm -rf node_data/
./start.sh
```

---

## Testnet Modes Reference

Set via `UAT_TESTNET_LEVEL` environment variable:

| Level | Value | Faucet | Consensus | Signatures | Use Case |
|-------|-------|--------|-----------|------------|----------|
| 1 | `functional` | Yes | Instant | Skipped | UI/API testing, single node |
| 2 | `consensus` | Yes | Real aBFT (67%) | Dilithium5 | Multi-node consensus testing |
| 3 | `production` | No | Real aBFT (67%) | Dilithium5 | Mainnet simulation |

Default (no env var): **Level 2 (consensus)**

---

## Connect Flutter Wallet to Local Testnet

1. Start at least one node (see Step 2 above)
2. Open the Flutter Wallet app
3. Go to Settings and set the node URL:
   ```
   http://localhost:3030
   ```
4. Create or import a wallet
5. Use the faucet to get test UAT (in-app or via curl above)

---

## Connect Flutter Validator Dashboard

1. Start at least one node (see Step 2 above)
2. Open the Flutter Validator app
3. Set the node URL to `http://localhost:3030`
4. The dashboard will display:
   - Node status and uptime
   - Validator set and stakes
   - Block production stats
   - Network peer information

---

## Full API Endpoint Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/node-info` | Node ID, version, uptime, block/account counts |
| GET | `/supply` | Total supply, remaining, burned amounts |
| GET | `/validators` | Active validator set with stakes |
| GET | `/account/:address` | Balance and account state |
| GET | `/blocks` | All blocks in the ledger |
| GET | `/block/:hash` | Single block by hash |
| GET | `/history/:address` | Transaction history for address |
| GET | `/peers` | Connected P2P peers |
| GET | `/whoami` | This node's address |
| GET | `/consensus` | aBFT consensus status |
| GET | `/oracle-prices` | Aggregated oracle price data |
| GET | `/metrics` | Prometheus-format metrics |
| GET | `/pending` | Pending transactions |
| GET | `/slashing-events` | Slashing history |
| GET | `/distribution` | Token distribution stats |
| GET | `/wrapped-assets` | Wrapped asset (wBTC, wETH) balances |
| POST | `/send` | Send UAT between accounts |
| POST | `/faucet` | Request test UAT (testnet only) |
| POST | `/burn` | Burn ETH/BTC to mint UAT |
| POST | `/stake` | Stake UAT to become validator |
| POST | `/unstake` | Unstake validator deposit |
| POST | `/deploy-contract` | Deploy WASM smart contract |
| POST | `/call-contract` | Execute contract call |

---

## Troubleshooting

### "Faucet only available in Functional/Consensus testnet modes"
You're running in `production` mode. Set the env var:
```bash
export UAT_TESTNET_LEVEL=functional
```
Then restart the node.

### Port already in use
```bash
# Check what's using the port
lsof -i :3030
# Kill the process or use a different port
./target/release/uat-node 4040
```

### Database lock error
Another node process is using the same data directory. Stop it first:
```bash
./stop.sh
# or
pkill -f uat-node
```

### Build fails
```bash
# Update Rust toolchain
rustup update

# Clean and rebuild
cargo clean
cargo build --release -p uat-node
```

---

## Run Automated Tests

```bash
# All 226 unit tests
cargo test --workspace

# Specific crate
cargo test -p uat-core
cargo test -p uat-crypto
cargo test -p uat-consensus
cargo test -p uat-vm
```
