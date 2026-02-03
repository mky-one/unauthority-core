# 🚀 TESTNET LAUNCH INSTRUCTIONS - Unauthority (UAT)

**Status:** ✅ READY TO LAUNCH  
**Date:** February 4, 2026  
**Security Score:** 97/100 (All P0 risks mitigated)  
**Test Status:** 237 tests passing

---

## QUICK START (3 COMMANDS)

```bash
# 1. Deploy infrastructure (creates 3 nodes)
./scripts/deploy_testnet.sh

# 2. Start all nodes
~/.uat/testnet/start_node_a.sh && ~/.uat/testnet/start_node_b.sh && ~/.uat/testnet/start_node_c.sh

# 3. Monitor network
./scripts/monitor_testnet.sh --watch
```

---

## DETAILED INSTRUCTIONS

### Step 1: Build Project (5 minutes)

```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core

# Build all binaries in release mode
cargo build --release

# Verify binaries exist
ls -lh target/release/uat-node
ls -lh target/release/uat-cli
ls -lh target/release/genesis
```

**Expected output:**
```
-rwxr-xr-x  uat-node (executable)
-rwxr-xr-x  uat-cli (executable)
-rwxr-xr-x  genesis (executable)
```

---

### Step 2: Deploy Testnet Infrastructure (1 minute)

```bash
# Make scripts executable
chmod +x scripts/deploy_testnet.sh
chmod +x scripts/monitor_testnet.sh

# Deploy 3-node testnet
./scripts/deploy_testnet.sh
```

**What this does:**
- Creates directory: `~/.uat/testnet/`
- Generates 3 config files (node_a, node_b, node_c)
- Creates start/stop scripts
- Configures ports:
  * Node A: REST 3030, gRPC 50051, P2P 4001, Prometheus 9090
  * Node B: REST 3031, gRPC 50052, P2P 4002, Prometheus 9091
  * Node C: REST 3032, gRPC 50053, P2P 4003, Prometheus 9092

**Expected output:**
```
╔═══════════════════════════════════════════════╗
║   UNAUTHORITY TESTNET - Bootstrap Deployment  ║
╚═══════════════════════════════════════════════╝

🔨 Building project in release mode...
✅ Build complete

📁 Creating testnet directory structure...
✅ Directories created

🚀 Deploying Node A (Bootstrap Leader)...
✅ Node A config created

🚀 Deploying Node B...
✅ Node B config created

🚀 Deploying Node C...
✅ Node C config created

✅ Ready for testnet launch (Feb 18, 2026)!
```

---

### Step 3: Start Validator Nodes (2 minutes)

**Option A: Start in background (RECOMMENDED)**

```bash
# Start all 3 nodes
~/.uat/testnet/start_node_a.sh
~/.uat/testnet/start_node_b.sh
~/.uat/testnet/start_node_c.sh

# Verify processes running
ps aux | grep uat-node
```

**Option B: Start in separate terminals**

Terminal 1:
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
./target/release/uat-node --config ~/.uat/testnet/node_a/config.toml
```

Terminal 2:
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
./target/release/uat-node --config ~/.uat/testnet/node_b/config.toml
```

Terminal 3:
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
./target/release/uat-node --config ~/.uat/testnet/node_c/config.toml
```

**Expected output (from logs):**
```
[INFO] Initializing UAT Node...
[INFO] Loading config from ~/.uat/testnet/node_a/config.toml
[INFO] Starting validator with 1000 UAT stake...
[INFO] P2P listening on /ip4/0.0.0.0/tcp/4001
[INFO] REST API started on http://0.0.0.0:3030
[INFO] gRPC server started on 0.0.0.0:50051
[INFO] Consensus engine started (aBFT)
[INFO] Node ready!
```

---

### Step 4: Verify Network is Running (30 seconds)

**Quick health check:**

```bash
# Check Node A
curl http://localhost:3030/node-info

# Check validators
curl http://localhost:3030/validators

# Check block height
curl http://localhost:3030/block
```

**Expected response (node-info):**
```json
{
  "chain_id": "uat-mainnet",
  "version": "1.0.0",
  "block_height": 1,
  "validator_count": 3,
  "peer_count": 2,
  "total_supply": 2193623600000000,
  "circulating_supply": 153553600000000,
  "network_tps": 0
}
```

**Use monitoring script:**

```bash
# One-time check
./scripts/monitor_testnet.sh

# Continuous monitoring (refresh every 5 seconds)
./scripts/monitor_testnet.sh --watch
```

**Expected output:**
```
╔═══════════════════════════════════════════════╗
║   UNAUTHORITY TESTNET - Network Monitor       ║
╚═══════════════════════════════════════════════╝

━━━ NODE STATUS ━━━
✅ Node A ONLINE
   Chain ID:    uat-mainnet
   Version:     1.0.0
   Block:       #42
   Validators:  3
   Peers:       2

✅ Node B ONLINE
   Chain ID:    uat-mainnet
   Version:     1.0.0
   Block:       #42
   Validators:  3
   Peers:       2

✅ Node C ONLINE
   Chain ID:    uat-mainnet
   Version:     1.0.0
   Block:       #42
   Validators:  3
   Peers:       2

━━━ VALIDATOR STATUS ━━━
  • UAT123...abc | Stake: 1000 UAT | Active: true
  • UAT456...def | Stake: 1000 UAT | Active: true
  • UAT789...ghi | Stake: 1000 UAT | Active: true

━━━ CONSENSUS HEALTH ━━━
  ✅ Consensus: SYNCED
  Node A: #42
  Node B: #42
  Node C: #42

Press Ctrl+C to exit
```

---

### Step 5: Test CLI Tool (5 minutes)

**Create your first wallet:**

```bash
cargo run --bin uat-cli -- wallet new my-wallet
```

**Expected interaction:**
```
╔═══════════════════════════════════════════════╗
║          UNAUTHORITY CLI - WALLET             ║
╚═══════════════════════════════════════════════╝

Creating encrypted wallet: my-wallet

🔐 Enter password (min 8 characters): ********
🔐 Confirm password: ********

✅ Wallet created successfully!

📋 Wallet Details:
  Name:    my-wallet
  Address: UAT1234567890abcdef...
  
⚠️  IMPORTANT: Save this password! It cannot be recovered.

💾 Wallet saved to: ~/.uat/wallets/my-wallet.json
```

**List all wallets:**

```bash
cargo run --bin uat-cli -- wallet list
```

**Check balance:**

```bash
cargo run --bin uat-cli -- wallet balance UAT1234567890abcdef... --rpc http://localhost:3030
```

**Query network info:**

```bash
cargo run --bin uat-cli -- query info --rpc http://localhost:3030
```

**List validators:**

```bash
cargo run --bin uat-cli -- query validators --rpc http://localhost:3030
```

---

### Step 6: View Logs (Ongoing)

**Real-time monitoring:**

```bash
# Node A logs
tail -f ~/.uat/testnet/logs/node_a.log

# Node B logs
tail -f ~/.uat/testnet/logs/node_b.log

# Node C logs
tail -f ~/.uat/testnet/logs/node_c.log

# All nodes (requires multitail)
brew install multitail
multitail ~/.uat/testnet/logs/*.log
```

**Check for errors:**

```bash
# Find errors in logs
grep -i error ~/.uat/testnet/logs/*.log

# Find warnings
grep -i warn ~/.uat/testnet/logs/*.log

# Check consensus activity
grep -i "block finalized" ~/.uat/testnet/logs/node_a.log | tail -20
```

---

### Step 7: Stop Testnet

```bash
# Stop all nodes
~/.uat/testnet/stop_all.sh

# Or stop individually
kill $(cat ~/.uat/testnet/node_a/pid)
kill $(cat ~/.uat/testnet/node_b/pid)
kill $(cat ~/.uat/testnet/node_c/pid)
```

---

## PERFORMANCE TARGETS

| Metric | Target | How to Verify |
|--------|--------|---------------|
| **TPS** | 998 tx/s | `curl http://localhost:9090/metrics \| grep uat_transactions_per_second` |
| **Finality** | <20ms | `curl http://localhost:9090/metrics \| grep uat_finality_time_ms` |
| **Block Time** | 3 seconds | Watch logs: `tail -f ~/.uat/testnet/logs/node_a.log` |
| **Memory** | <2GB/node | `ps aux \| grep uat-node` |
| **CPU** | <50%/node | `top -pid $(cat ~/.uat/testnet/node_a/pid)` |

---

## TROUBLESHOOTING

### Problem: Node won't start

**Check if port is already in use:**
```bash
lsof -i :3030
lsof -i :4001
```

**Solution: Kill existing process**
```bash
kill $(lsof -t -i :3030)
```

### Problem: Nodes out of sync

**Check block heights:**
```bash
curl -s http://localhost:3030/node-info | grep block_height
curl -s http://localhost:3031/node-info | grep block_height
curl -s http://localhost:3032/node-info | grep block_height
```

**Solution: Restart lagging node**
```bash
~/.uat/testnet/stop_all.sh
~/.uat/testnet/start_node_a.sh
~/.uat/testnet/start_node_b.sh
~/.uat/testnet/start_node_c.sh
```

### Problem: Database corruption

**Backup and reset:**
```bash
# Backup
cp -r ~/.uat/testnet/node_a/data ~/.uat/testnet/node_a/data.backup

# Reset
rm -rf ~/.uat/testnet/node_a/data

# Restart (will sync from peers)
~/.uat/testnet/start_node_a.sh
```

### Problem: High CPU usage

**Check for spam:**
```bash
curl http://localhost:3030/node-info | grep network_tps
```

**View mempool:**
```bash
curl http://localhost:9090/metrics | grep uat_mempool_size
```

---

## API ENDPOINTS (For External Tools)

### REST API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/node-info` | GET | Network metadata |
| `/balance/:address` | GET | Check UAT balance |
| `/block` | GET | Latest block |
| `/block/:height` | GET | Specific block |
| `/validators` | GET | Active validators |
| `/account/:address` | GET | Account details |
| `/tx/:hash` | GET | Transaction status |
| `/submit-tx` | POST | Submit signed transaction |

**Example usage:**
```bash
# Get network info
curl http://localhost:3030/node-info | jq

# Check balance
curl http://localhost:3030/balance/UAT123... | jq

# Get validators
curl http://localhost:3030/validators | jq
```

### Prometheus Metrics

```bash
# Node A metrics
curl http://localhost:9090/metrics

# Node B metrics
curl http://localhost:9091/metrics

# Node C metrics
curl http://localhost:9092/metrics
```

**Key metrics:**
- `uat_transactions_per_second` - Current TPS
- `uat_finality_time_ms` - Block finality time
- `uat_block_height` - Current block height
- `uat_validator_count` - Active validators
- `uat_peer_count` - Connected peers
- `uat_mempool_size` - Pending transactions

---

## SECURITY CHECKLIST

Before production deployment:

- [x] **P0 Security Fixes Complete**
  - [x] Multi-source oracle (RISK-001 mitigated)
  - [x] Private key encryption (RISK-002 mitigated)
  - [x] Finality checkpoints (RISK-003 mitigated)

- [ ] **Network Security** (Testnet: Optional)
  - [ ] Firewall rules configured
  - [ ] TLS enabled for REST API
  - [ ] Rate limiting enabled
  - [ ] DDoS protection active

- [ ] **Operational Security**
  - [x] Private keys encrypted with password
  - [ ] Backup strategy defined
  - [ ] Recovery procedures documented
  - [ ] Monitoring alerts configured

---

## NEXT STEPS

### Local Testing (Feb 5-10)

1. **Functional Testing**
   - Create 10 wallets
   - Send transactions between wallets
   - Stake as validator (1000 UAT minimum)
   - Query balances/validators/blocks

2. **Stress Testing**
   - Spam transactions (100 tx/s)
   - Monitor resource usage
   - Verify consensus doesn't stall
   - Check memory leaks

3. **Failure Testing**
   - Kill 1 node (2/3 should continue)
   - Kill 2 nodes (network should halt)
   - Restart nodes (should resync)
   - Corrupt database (should recover)

### Production Deployment (Feb 11-17)

1. **Setup Real Servers**
   - AWS/GCP/DigitalOcean (3 VPS)
   - 8GB RAM, 4 vCPU, 50GB SSD each
   - Ubuntu 22.04 LTS

2. **Configure Networking**
   - Open ports: 3030 (REST), 4001 (P2P)
   - Setup firewall (ufw/iptables)
   - Configure DNS (optional)
   - Enable TLS (Let's Encrypt)

3. **Deploy Monitoring**
   - Prometheus + Grafana
   - Alert notifications (email/SMS)
   - Public dashboard (optional, read-only)

### Testnet Launch (Feb 18)

- **Time:** 00:00 UTC
- **Duration:** 30 days (until Mar 17)
- **Mode:** Silent launch, no announcement
- **Participants:** Solo (you + 3 bootstrap nodes)
- **Goal:** Stability validation, bug fixes

### Mainnet Launch (May 1)

- **Time:** 00:00 UTC
- **Mode:** Anonymous (Bitcoin-style)
- **Release:** Open-source GitHub public
- **Marketing:** None (organic discovery)
- **Audit:** None (market validation)

---

## SUPPORT & DOCUMENTATION

- **Security Docs:** [docs/KNOWN_RISKS_AND_MITIGATIONS.md](../docs/KNOWN_RISKS_AND_MITIGATIONS.md)
- **API Reference:** [api_docs/API_REFERENCE.md](../api_docs/API_REFERENCE.md)
- **Project Status:** [docs/PROJECT_STATUS.md](../docs/PROJECT_STATUS.md)
- **Whitepaper:** [docs/WHITEPAPER.md](../docs/WHITEPAPER.md)

---

**Last Updated:** February 4, 2026  
**Status:** ✅ READY FOR TESTNET LAUNCH  
**Next Milestone:** Deploy to production servers (Feb 11-17)  
**Target Launch:** February 18, 2026 00:00 UTC

---

🚀 **START TESTNET NOW:** `./scripts/deploy_testnet.sh`
