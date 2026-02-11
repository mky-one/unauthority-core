# Validator Guide

How to run a UAT validator node — from setup to monitoring.

**Version:** v1.0.6-testnet

---

## Requirements

| Resource | Minimum |
|----------|---------|
| CPU | 2 cores |
| RAM | 2 GB |
| Disk | 10 GB SSD |
| Network | Tor hidden service (no public IP needed) |
| Stake | 1,000 UAT minimum |
| Rust | 1.75+ |
| Protobuf | 3.x+ (`protoc`) |

---

## 1. Build the Node

```bash
git clone https://github.com/unauthoritymky-6236/unauthority-core.git
cd unauthority-core
cargo build --release --bin uat-node
```

Binary: `target/release/uat-node`

---

## 2. Run in Dev Mode

The fastest way to start — testnet with auto-generated wallet:

```bash
./target/release/uat-node --dev
```

This starts a validator on `127.0.0.1:3030` (REST API) and `127.0.0.1:4001` (P2P).

Dev mode automatically:
- Generates a Dilithium5 keypair
- Loads testnet genesis (12 wallets, 4 bootstrap validators)
- Awards the node 1,000 UAT initial balance
- Enables faucet at `/faucet`
- Connects to bootstrap validators via Tor (if available)

---

## 3. Node CLI Flags

```
USAGE:
    uat-node [OPTIONS]

OPTIONS:
    --dev                    Run in testnet dev mode
    --port <PORT>            REST API port (default: 3030)
    --p2p-port <PORT>        P2P listen port (default: 4001)
    --data-dir <DIR>         Data directory (default: ./node_data)
    --bootstrap <ADDR>       Bootstrap peer multiaddr
    --tor-socks <HOST:PORT>  Tor SOCKS5 proxy (e.g., 127.0.0.1:9052)
    --tor-onion <HOST>       This node's .onion address
    --log-level <LEVEL>      Log verbosity: error, warn, info, debug, trace
```

---

## 4. Configuration via Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `UAT_BIND_ALL` | `0` | Set to `1` to bind `0.0.0.0` instead of `127.0.0.1` |
| `UAT_WALLET_PASSWORD` | — | Encrypt wallet at rest (required on mainnet, min 12 chars) |
| `UAT_NODE_ID` | — | Unique node identifier for multi-validator setups |
| `UAT_VALIDATOR_ADDRESS` | — | Override validator address |
| `UAT_PRIVKEY_PATH` | — | Path to encrypted private key file |
| `UAT_STAKE_VOID` | — | Override stake amount |
| `RUST_LOG` | `info` | Log level filter |

---

## 5. Validator Configuration (validator.toml)

The `validator.toml` file provides advanced configuration:

```toml
[node]
# Sentry/signer architecture
type = "sentry"                          # "sentry" or "signer"
signer_address = "127.0.0.1:31333"       # Signer node internal address

[network]
max_peers = 128
min_peers = 8
peer_discovery_interval = 300            # seconds
p2p_encryption = "noise_protocol"

[consensus]
type = "aBFT"
finality_time = 3                        # seconds
byzantine_tolerance = 0.33               # tolerate 33% faulty
min_votes = 67                           # % required for finality
vote_timeout = 5                         # seconds

[storage]
db_backend = "rocksdb"
prune_older_than = 90                    # days
snapshot_interval = 10000                # blocks

[logging]
level = "INFO"
format = "json"
metrics_port = 9090
```

---

## 6. Multi-Node Local Testnet

Run 4 validators locally using the provided script:

```bash
./start.sh
```

This launches validators on ports 3030–3033 (REST) and 4001–4004 (P2P) with `RUST_LOG=info`.

Stop all validators:

```bash
./stop.sh
```

---

## 7. Setup Tor Hidden Services

For production deployments, run validators as Tor hidden services:

```bash
./setup_tor_testnet.sh
```

This script:
1. Installs Tor (if not present)
2. Generates 4 hidden service directories
3. Creates `torrc` configuration
4. Outputs `.onion` addresses to `testnet-tor-info.json`

See [TOR_SETUP.md](TOR_SETUP.md) for detailed instructions.

---

## 8. Monitoring

### Health Check

```bash
curl http://127.0.0.1:3030/health
# {"status":"healthy"}     — node is operational
# {"status":"degraded"}    — node has issues
```

### Node Info

```bash
curl http://127.0.0.1:3030/node-info
# Returns: chain_id, version, total_supply, circulating_supply,
#          burned_supply, validators, peers, estimated_finality_ms
```

### Prometheus Metrics

```bash
curl http://127.0.0.1:3030/metrics
```

Available at `:9090` for Grafana dashboards. A pre-built dashboard is at `docs/grafana-dashboard.json`.

### Validator Status

```bash
# All validators
curl http://127.0.0.1:3030/validators

# Specific validator slashing profile
curl http://127.0.0.1:3030/slashing/UATYourAddress...

# Consensus parameters
curl http://127.0.0.1:3030/consensus
```

---

## 9. Slashing Rules

| Violation | Detection | Penalty |
|-----------|-----------|---------|
| **Double-signing** | Two blocks at same height | 100% stake burn + permanent ban |
| **Downtime** | < 95% uptime in 50,000 blocks | 1% stake burn |

Downtime window: 50,000 blocks (~5 hours). First slash triggers after 10,000 missed blocks (~1 hour).

Slash proposals require multi-validator confirmation — a single validator cannot unilaterally slash another.

---

## 10. Staking

Minimum stake: **1,000 UAT** (= 100,000,000,000,000 VOID).

Staking is implicit — any account with balance ≥ 1,000 UAT and running a validator node is considered an active validator.

Quadratic voting: your voting power = √(your_stake), not your_stake. This gives smaller validators proportionally more influence.

---

## 11. Validator Rewards

Validators earn UAT rewards for maintaining uptime. The reward system is epoch-based with quadratic fairness.

### How It Works

| Parameter | Value |
|-----------|-------|
| **Reward Pool** | 2,193,623 UAT (10% of total supply, reserved at genesis) |
| **Epoch Duration** | 24 hours (86,400 seconds) |
| **Initial Rate** | 50 UAT per epoch (distributed among all qualifying validators) |
| **Halving** | Every 365 epochs (~1 year), reward rate halves |
| **Min Uptime** | 95% heartbeats required to qualify |
| **Probation** | First 3 epochs after registration (no rewards) |
| **Heartbeat** | Every 60 seconds |

### Reward Distribution

At the end of each epoch:
1. Validators with < 95% uptime are excluded
2. Each qualifying validator's share = √(stake_in_void)
3. Rewards distributed proportionally to √stake shares
4. Rewards credited directly to validator account balances

### Genesis Validator Exclusion

The 4 bootstrap genesis validators are **permanently excluded** from rewards. They serve as initial network infrastructure funded by the development treasury.

### Monitoring Rewards

```bash
curl http://127.0.0.1:3030/reward-info
```

Returns: pool remaining, current epoch, epoch progress, per-validator heartbeats, uptime %, qualification status, and cumulative rewards.

### Monitor-Only Mode

The Flutter Validator Dashboard supports **monitor-only mode** — connect to any running node to view its status, reward stats, and `.onion` address without running your own validator. This is useful for remote monitoring.

---

## 12. Console Commands

When running interactively, the node provides a console:

```
> bal                    # Show this node's balance
> whoami                 # Show this node's address
> history                # Show transaction history
> send <address> <amount> # Send UAT to address
> burn <amount>          # Proof-of-Burn
> supply                 # Show supply stats
> peers                  # Show connected peers
> dial <multiaddr>       # Connect to a specific peer
> exit                   # Graceful shutdown
```

---

## 13. Docker Deployment

See [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for running validators via Docker Compose with Prometheus and Grafana monitoring.

---

## 14. Backup & Recovery

### Wallet Backup

The node's private key is stored in `node_data/wallet.json` (encrypted with `age` if `UAT_WALLET_PASSWORD` is set).

```bash
# Backup wallet
cp node_data/wallet.json /secure/backup/

# The wallet file contains the Dilithium5 keypair
# If encrypted, you need UAT_WALLET_PASSWORD to decrypt
```

### Ledger State

Ledger state is persisted to `node_data/ledger_state.json` with debounced writes every 5 seconds. On startup, the node loads this state and can sync missing blocks from peers.

### State Sync

New nodes can sync from existing peers via the `/sync` endpoint (GZIP-compressed, max 8MB/50MB decompressed). The node validates supply within 1% tolerance to detect malicious peers.
