# Unauthority (UAT) — Tor Testnet Guide

> **Privacy-First Blockchain Testnet**
> No VPS. No domains. No KYC. Only Tor .onion addresses.

## Quick Start (30 seconds)

```bash
# 1. Start the Tor testnet (builds node + starts Tor + 4 validators)
./setup_tor_testnet.sh

# 2. Test locally
curl http://localhost:3030/node-info | jq

# 3. Test via Tor (from any device with Tor Browser)
# Open: http://<your-onion-address>/node-info

# 4. Stop everything
./stop_tor_testnet.sh
```

## Prerequisites

| Requirement | Check | Install |
|---|---|---|
| **Rust** | `rustc --version` | [rustup.rs](https://rustup.rs/) |
| **Tor** | `tor --version` | `brew install tor` (macOS) / `apt install tor` (Linux) |
| **jq** (optional) | `jq --version` | `brew install jq` |

> The setup script **auto-installs Tor** via Homebrew/apt if not found.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    YOUR MACHINE (localhost)                         │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐│
│  │ Validator-1  │  │ Validator-2  │  │ Validator-3  │  │Validator-4 ││
│  │ REST :3030   │  │ REST :3031   │  │ REST :3032   │  │REST :3033  ││
│  │ P2P  :4001   │  │ P2P  :4002   │  │ P2P  :4003   │  │P2P  :4004  ││
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘│
│         │                 │                 │                │      │
│  ┌──────┴─────────────────┴─────────────────┴────────────────┴─────┐│
│  │                        TOR DAEMON (SOCKS5 :9052)                ││
│  │  hs-validator-1 → abc123...onion                                ││
│  │  hs-validator-2 → def456...onion                                ││
│  │  hs-validator-3 → ghi789...onion                                ││
│  │  hs-validator-4 → jkl012...onion                                ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                              │ Tor Network
                    ┌─────────┴──────────┐
                    │                    │
              ┌─────┴─────┐       ┌─────┴─────┐
              │ Friend #1 │       │ Friend #2 │
              │ Tor Browser│       │ Flutter   │
              │ or Wallet  │       │ Wallet    │
              └───────────┘       └───────────┘
```

**Key concepts:**
- Each validator binds to `127.0.0.1` (never exposed to clearnet)
- Tor creates a unique `.onion` address per validator
- External users connect to `.onion` addresses through Tor
- Validators connect to each other via SOCKS5 → Tor  
- `.onion` addresses are **persistent** across restarts

## Testnet Commands

### Start / Stop
```bash
./setup_tor_testnet.sh      # Start everything (Tor + 4 validators)
./stop_tor_testnet.sh       # Stop everything
```

### Health & Status
```bash
# Local (fast, direct)
curl http://localhost:3030/health
curl http://localhost:3030/node-info | jq
curl http://localhost:3030/supply | jq
curl http://localhost:3030/validators | jq

# Via Tor (how external users see it)
curl --socks5-hostname 127.0.0.1:9052 http://<onion>/health
```

### Wallet Operations (via curl)
```bash
# Get balance
curl http://localhost:3030/balance/UAT_ADDRESS_HERE

# Request faucet (testnet only)
curl -X POST http://localhost:3030/faucet -H 'Content-Type: application/json' \
  -d '{"address": "UAT_ADDRESS_HERE"}'

# Send transaction
curl -X POST http://localhost:3030/send -H 'Content-Type: application/json' \
  -d '{"from": "SENDER", "target": "RECIPIENT", "amount": 10, "signature": "test", "public_key": "test"}'
```

### Logs
```bash
tail -f node_data/validator-1/logs/node.log   # Validator logs
tail -f ~/.uat-testnet-tor/tor.log            # Tor logs
```

## Connecting the Flutter Wallet

The Flutter wallet has **bundled Tor support**. It automatically:
1. Detects an existing Tor proxy (ports 9250, 9150, 9052, 9050)
2. Or starts its own Tor instance
3. Connects to the `.onion` address

### For development (localhost):
In the wallet, switch to `local` mode — connects directly to `http://localhost:3030`.

### For remote testing:
Set the wallet URL to `http://<your-onion-address>` (from `testnet-tor-info.json`).

## Sharing Your Testnet With Friends

1. Run `./setup_tor_testnet.sh` on your machine
2. Check `testnet-tor-info.json` for your `.onion` addresses
3. Share the primary `.onion` address with friends
4. Friends can:
   - **Tor Browser**: Open `http://<onion>/node-info`
   - **Flutter Wallet**: Enter `.onion` address in settings
   - **curl**: `curl --socks5-hostname 127.0.0.1:9150 http://<onion>/health`

> **Your friends do NOT need to run any node.** They just need Tor Browser
> or a Tor-enabled wallet to connect.

## File Reference

| File | Purpose |
|---|---|
| `setup_tor_testnet.sh` | Start Tor + 4 validators with hidden services |
| `stop_tor_testnet.sh` | Stop all validators + Tor daemon |
| `testnet-tor-info.json` | Generated: all `.onion` addresses & connection info |
| `~/.uat-testnet-tor/` | Tor data directory (hidden service keys) |
| `node_data/validator-N/` | Validator data, logs, PID files |

## Environment Variables

| Variable | Example | Purpose |
|---|---|---|
| `UAT_TOR_SOCKS5` | `127.0.0.1:9052` | SOCKS5 proxy for Tor connections |
| `UAT_ONION_ADDRESS` | `abc123...onion` | This node's `.onion` address |
| `UAT_P2P_PORT` | `4001` | libp2p listen port |
| `UAT_BOOTSTRAP_NODES` | `abc.onion:4001,def.onion:4001` | Peer discovery |
| `UAT_RPC_URL` | `http://abc.onion` | CLI default RPC endpoint |
| `UAT_TESTNET_MODE` | `graduated` | Enable graduated testnet levels |

## Troubleshooting

### Tor daemon crashes immediately
```bash
# Check config
tor --verify-config -f ~/.uat-testnet-tor/torrc
# Check logs
tail -50 ~/.uat-testnet-tor/tor.log
```

### Validators show OFFLINE
```bash
# Check if process is running
ps aux | grep uat-node
# Check log
tail -50 node_data/validator-1/logs/node.log
```

### .onion address not resolving (from Tor Browser)
- Ensure your machine's `setup_tor_testnet.sh` is still running
- .onion resolution takes time — wait 30-60 seconds after first start
- Try refreshing in Tor Browser

### Reset everything
```bash
./stop_tor_testnet.sh
rm -rf ~/.uat-testnet-tor
rm -rf node_data/
# New .onion addresses will be generated on next run
./setup_tor_testnet.sh
```
