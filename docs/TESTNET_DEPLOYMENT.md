# Testnet Deployment Guide

## Prerequisites

- Rust toolchain installed
- 8GB RAM minimum
- 50GB disk space
- Open ports: 3030-3032 (REST API), 4001-4003 (P2P), 9090-9092 (Prometheus)

## Quick Start (3 Commands)

```bash
# 1. Deploy infrastructure
./scripts/deploy_testnet.sh

# 2. Start all nodes
~/.uat/testnet/start_node_a.sh
~/.uat/testnet/start_node_b.sh
~/.uat/testnet/start_node_c.sh

# 3. Monitor network
./scripts/monitor_testnet.sh --watch
```

## Architecture

```
Testnet Network (3 Bootstrap Nodes)
├── Node A (Leader)
│   ├── REST API:    http://localhost:3030
│   ├── gRPC:        localhost:50051
│   ├── P2P:         localhost:4001
│   └── Prometheus:  http://localhost:9090/metrics
├── Node B
│   ├── REST API:    http://localhost:3031
│   ├── gRPC:        localhost:50052
│   ├── P2P:         localhost:4002
│   └── Prometheus:  http://localhost:9091/metrics
└── Node C
    ├── REST API:    http://localhost:3032
    ├── gRPC:        localhost:50053
    ├── P2P:         localhost:4003
    └── Prometheus:  http://localhost:9092/metrics
```

## Step-by-Step Deployment

### 1. Build Project

```bash
cargo build --release
```

This creates the `uat-node` binary at `target/release/uat-node`.

### 2. Deploy Testnet Infrastructure

```bash
./scripts/deploy_testnet.sh
```

This script:
- Creates directory structure at `~/.uat/testnet/`
- Generates config files for 3 nodes
- Creates start/stop scripts
- Configures networking (ports, bootstrap peers)

### 3. Start Nodes

Start each node in separate terminals:

```bash
# Terminal 1: Node A (Bootstrap Leader)
~/.uat/testnet/start_node_a.sh

# Terminal 2: Node B
~/.uat/testnet/start_node_b.sh

# Terminal 3: Node C
~/.uat/testnet/start_node_c.sh
```

Or start in background:

```bash
~/.uat/testnet/start_node_a.sh &
~/.uat/testnet/start_node_b.sh &
~/.uat/testnet/start_node_c.sh &
```

### 4. Verify Network

```bash
# Check node info
curl http://localhost:3030/node-info | jq

# Check validators
curl http://localhost:3030/validators | jq

# Check block height
curl http://localhost:3030/block | jq
```

### 5. Monitor Network

```bash
# One-time check
./scripts/monitor_testnet.sh

# Continuous monitoring (refresh every 5 seconds)
./scripts/monitor_testnet.sh --watch
```

## CLI Usage

### Create Wallet

```bash
cargo run --bin uat-cli -- wallet new my-wallet
```

This prompts for password and creates encrypted wallet at `~/.uat/wallets/my-wallet.json`.

### Check Balance

```bash
cargo run --bin uat-cli -- wallet balance UAT123... --rpc http://localhost:3030
```

### Send Transaction

```bash
cargo run --bin uat-cli -- tx send \
  --to UAT456... \
  --amount 100 \
  --from my-wallet \
  --rpc http://localhost:3030
```

### Stake as Validator

```bash
cargo run --bin uat-cli -- validator stake \
  --amount 1000 \
  --wallet my-wallet \
  --rpc http://localhost:3030
```

### Query Validators

```bash
cargo run --bin uat-cli -- query validators --rpc http://localhost:3030
```

## Stopping Testnet

```bash
# Stop all nodes
~/.uat/testnet/stop_all.sh

# Or stop individually
kill $(cat ~/.uat/testnet/node_a/pid)
kill $(cat ~/.uat/testnet/node_b/pid)
kill $(cat ~/.uat/testnet/node_c/pid)
```

## Logs

View real-time logs:

```bash
# Node A
tail -f ~/.uat/testnet/logs/node_a.log

# Node B
tail -f ~/.uat/testnet/logs/node_b.log

# Node C
tail -f ~/.uat/testnet/logs/node_c.log

# All nodes (requires multitail)
multitail ~/.uat/testnet/logs/*.log
```

## Troubleshooting

### Node Won't Start

```bash
# Check if port is in use
lsof -i :3030
lsof -i :4001

# Kill existing process
kill $(lsof -t -i :3030)

# Check logs
tail -50 ~/.uat/testnet/logs/node_a.log
```

### Nodes Out of Sync

```bash
# Check block heights
curl -s http://localhost:3030/node-info | jq .block_height
curl -s http://localhost:3031/node-info | jq .block_height
curl -s http://localhost:3032/node-info | jq .block_height

# If diff > 10 blocks, restart lagging node
~/.uat/testnet/stop_all.sh
~/.uat/testnet/start_node_a.sh
~/.uat/testnet/start_node_b.sh
~/.uat/testnet/start_node_c.sh
```

### Database Corruption

```bash
# Backup data
cp -r ~/.uat/testnet/node_a/data ~/.uat/testnet/node_a/data.backup

# Reset node
rm -rf ~/.uat/testnet/node_a/data

# Restart node (will sync from peers)
~/.uat/testnet/start_node_a.sh
```

## Performance Targets

- **TPS:** 998 transactions/second sustained
- **Finality:** 12.8ms average
- **Block Time:** 3 seconds
- **Uptime:** 99%+ (7.2 hours downtime/month allowed)
- **Memory:** < 2GB per node
- **CPU:** < 50% average per node

## Monitoring Metrics

Prometheus metrics available at:
- Node A: http://localhost:9090/metrics
- Node B: http://localhost:9091/metrics
- Node C: http://localhost:9092/metrics

Key metrics:
- `uat_transactions_per_second` - Current TPS
- `uat_finality_time_ms` - Time to finalize blocks
- `uat_block_height` - Current block height
- `uat_validator_count` - Active validators
- `uat_peer_count` - Connected peers
- `uat_mempool_size` - Pending transactions

## Security Checklist

- [x] Private keys encrypted with password (RISK-002 mitigated)
- [x] Multi-source oracle (4 BTC + 4 ETH sources, RISK-001 mitigated)
- [x] Finality checkpoints every 1,000 blocks (RISK-003 mitigated)
- [ ] Firewall rules configured (ports 3030-3032, 4001-4003 only)
- [ ] TLS enabled for REST API (optional for testnet)
- [ ] Rate limiting enabled (anti-DDoS)

## Timeline

- **Feb 4, 2026:** All P0 security fixes complete
- **Feb 5-10:** Local integration testing
- **Feb 11-17:** Deploy to production servers
- **Feb 18, 2026:** 🚀 **TESTNET LAUNCH**
- **Mar 18:** Testnet analysis (30 days complete)
- **May 1, 2026:** 🎊 **MAINNET LAUNCH** (Silent, anonymous)

## Support

This is a solo development project. No community support available yet.

For technical issues, review:
1. Logs at `~/.uat/testnet/logs/`
2. [KNOWN_RISKS.md](../docs/KNOWN_RISKS_AND_MITIGATIONS.md)
3. [API_REFERENCE.md](../api_docs/API_REFERENCE.md)

## Production Deployment (Post-Testnet)

For mainnet deployment:
1. Use real server IPs (not 127.0.0.1)
2. Configure firewall (iptables/ufw)
3. Enable TLS for REST API (Let's Encrypt)
4. Setup monitoring alerts (Prometheus + Grafana)
5. Backup private keys securely (offline storage)
6. Document recovery procedures

---

**Ready to launch testnet? Run: `./scripts/deploy_testnet.sh`**
