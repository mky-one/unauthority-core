# CLI Reference

The `los-cli` command-line tool for interacting with a running LOS node.

**Version:** v1.0.6-testnet

---

## Installation

```bash
cargo build --release --bin los-cli
# Binary: target/release/los-cli
```

---

## Global Options

| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--rpc <URL>` | `LOS_RPC_URL` | `http://localhost:3030` | Node RPC endpoint |
| `--config-dir <DIR>` | — | `~/.uat` | Configuration directory |

---

## Commands

### wallet

Manage local wallets.

```bash
# Create a new wallet (generates Dilithium5 keypair + BIP39 mnemonic)
los-cli wallet new

# List all wallets in config directory
los-cli wallet list

# Check balance for a wallet
los-cli wallet balance --address LOS...

# Export wallet to file
los-cli wallet export --address LOS... --output wallet.json

# Import wallet from file
los-cli wallet import --file wallet.json
```

### validator

Manage validator operations.

```bash
# Stake to become a validator
los-cli validator stake --amount 1000

# Unstake and begin exit
los-cli validator unstake

# Check validator status
los-cli validator status --address LOS...

# List all validators on the network
los-cli validator list
```

### query

Query blockchain data.

```bash
# Get block by hash
los-cli query block --hash abc123...

# Get account details
los-cli query account --address LOS...

# Get node info (chain_id, version, supply, validators, peers)
los-cli query info

# List validators with stakes
los-cli query validators
```

### tx

Transaction operations.

```bash
# Send LOS to an address
los-cli tx send --to LOS... --amount 100

# Check transaction status by hash
los-cli tx status --hash abc123...
```

---

## Examples

### Full workflow: create wallet, check balance, send tokens

```bash
# Point to your node
export LOS_RPC_URL=http://127.0.0.1:3030

# Create wallet
los-cli wallet new
# → Address: LOSBwXk9...
# → Seed phrase: word1 word2 ... word24

# Check balance
los-cli wallet balance --address LOSBwXk9...
# → Balance: 0 LOS (0 CIL)

# After getting testnet tokens via faucet...
los-cli tx send --to LOSRecipient... --amount 50
# → TX hash: abc123...

# Verify
los-cli tx status --hash abc123...
```

### Connect via Tor

```bash
# If your node is behind a Tor hidden service
export LOS_RPC_URL=http://your-node.onion

# Use with Tor SOCKS5 proxy
# Note: los-cli uses reqwest, configure proxy via environment
export HTTPS_PROXY=socks5h://127.0.0.1:9052
export HTTP_PROXY=socks5h://127.0.0.1:9052

los-cli query info
```

---

## Node Console Commands

When running `los-node` interactively, these commands are available in the terminal:

| Command | Description |
|---------|-------------|
| `bal` | Show this node's balance |
| `whoami` | Show this node's address |
| `history` | Show transaction history |
| `send <address> <amount>` | Send LOS |
| `burn <amount>` | Proof-of-Burn |
| `supply` | Show supply statistics |
| `peers` | Show connected peers |
| `dial <multiaddr>` | Connect to a specific peer |
| `exit` | Graceful shutdown |
