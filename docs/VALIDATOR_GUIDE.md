# Validator Guide — Unauthority (LOS) v1.0.9

## Overview

Running a validator node on Unauthority means hosting a Tor hidden service that participates in aBFT consensus. This guide covers setup for both testnet and mainnet.

## Requirements

| Component | Minimum |
|---|---|
| **OS** | Linux / macOS |
| **Rust** | 1.75+ |
| **RAM** | 2 GB |
| **Disk** | 10 GB SSD |
| **Tor** | Installed and running |
| **Stake** | 1,000 LOS minimum |
| **Uptime** | ≥95% for reward eligibility |

## Building

```bash
# Clone the repository
git clone https://github.com/your-org/unauthority-core.git
cd unauthority-core

# Testnet build
cargo build --release

# Mainnet build (strict: no faucet, no mock oracle, signature validation enforced)
cargo build --release -p los-node -p los-cli --features los-core/mainnet
```

The binary is at `target/release/los-node`.

## Tor Hidden Service Setup

Each validator MUST have its own `.onion` address. The node automatically generates one on startup if Tor is configured, but you can also set it up manually.

### Option 1: Manual Tor Configuration

Add to your `torrc`:
```
HiddenServiceDir /var/lib/tor/los-validator/
HiddenServicePort 3030 127.0.0.1:3030
HiddenServicePort 4001 127.0.0.1:4001
```

Restart Tor:
```bash
sudo systemctl restart tor
```

Your `.onion` address is in `/var/lib/tor/los-validator/hostname`.

### Option 2: Environment Variable

```bash
export LOS_ONION_ADDRESS=$(cat /var/lib/tor/los-validator/hostname)
```

The node will announce this address to the network for peer discovery.

## Starting a Validator Node

### Testnet (Consensus Level)
```bash
export LOS_NODE_ID='my-validator'
export LOS_TESTNET_LEVEL='consensus'
export LOS_ONION_ADDRESS='your-onion-address.onion'
export LOS_SOCKS5_PROXY='socks5h://127.0.0.1:9050'
export LOS_BOOTSTRAP_NODES='peer1.onion:4001,peer2.onion:4001'

./target/release/los-node --port 3030 --data-dir node_data/my-validator
```

### Mainnet
```bash
export LOS_WALLET_PASSWORD='your-strong-password'
export LOS_NODE_ID='my-validator'
export LOS_ONION_ADDRESS='your-onion-address.onion'
export LOS_SOCKS5_PROXY='socks5h://127.0.0.1:9050'
export LOS_BOOTSTRAP_NODES='boot1.onion:4001,boot2.onion:4001'

./target/release/los-node --port 3030 --data-dir node_data/my-validator
```

## Registering as a Validator

After your node is running and funded with ≥1,000 LOS:

```bash
curl -X POST http://localhost:3030/register-validator \
  -H "Content-Type: application/json" \
  -d '{
    "address": "YOUR_LOS_ADDRESS",
    "public_key": "YOUR_HEX_PUBLIC_KEY",
    "signature": "HEX_SIGNATURE_OF_REGISTER_PAYLOAD",
    "endpoint": "your-onion-address.onion:3030"
  }'
```

The registration is signed with Dilithium5 and gossiped to all peers.

## Validator Responsibilities

1. **Block Confirmation:** Vote on incoming blocks from peers
2. **Burn Verification:** Verify ETH/BTC burn transactions via oracle
3. **Oracle Submission:** Submit price feeds for burn valuation
4. **Uptime:** Maintain ≥95% uptime for reward eligibility

## Reward Distribution

| Parameter | Value |
|---|---|
| **Total Pool** | 500,000 LOS |
| **Per Epoch** | 5,000 LOS (halving every 48 epochs) |
| **Formula** | `reward = budget × √(your_stake) / Σ√(all_stakes)` |
| **Min Stake** | 1,000 LOS |
| **Min Uptime** | 95% |

Rewards use integer square root (`isqrt`) — never floating-point.

## Slashing Conditions

| Offense | Penalty |
|---|---|
| Double-signing a block | Stake reduction |
| Submitting fake burn TXID | Stake reduction + blacklist |
| Extended downtime (>5%) | Reward ineligibility |
| Oracle price manipulation | Outlier detection + penalty |

## Monitoring

### Prometheus Metrics
```bash
curl http://localhost:3030/metrics
```

Key metrics:
- `los_active_validators` — Number of active validators
- `los_blocks_total` — Total blocks processed
- `los_accounts_total` — Total accounts
- `los_consensus_rounds` — aBFT rounds completed

### Health Check
```bash
curl http://localhost:3030/health
```

### Node Status
```bash
curl http://localhost:3030/node-info
```

## Data Directory Structure

```
node_data/my-validator/
├── los_database/          # RocksDB ledger data
├── checkpoints/           # Periodic state checkpoints
├── wallet.json.enc        # Encrypted wallet (Dilithium5 keypair)
└── pid.txt                # Process ID file
```

## Unregistering

```bash
curl -X POST http://localhost:3030/unregister-validator \
  -H "Content-Type: application/json" \
  -d '{
    "address": "YOUR_LOS_ADDRESS",
    "public_key": "YOUR_HEX_PUBLIC_KEY",
    "signature": "HEX_SIGNATURE"
  }'
```
