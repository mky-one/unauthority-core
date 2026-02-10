# CLI Reference

The `uat-cli` command-line tool for interacting with a running UAT node.

**Version:** v1.0.3-testnet

---

## Installation

```bash
cargo build --release --bin uat-cli
# Binary: target/release/uat-cli
```

---

## Global Options

| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--rpc <URL>` | `UAT_RPC_URL` | `http://localhost:3030` | Node RPC endpoint |
| `--config-dir <DIR>` | — | `~/.uat` | Configuration directory |

---

## Commands

### wallet

Manage local wallets.

```bash
# Create a new wallet (generates Dilithium5 keypair + BIP39 mnemonic)
uat-cli wallet new

# List all wallets in config directory
uat-cli wallet list

# Check balance for a wallet
uat-cli wallet balance --address UAT...

# Export wallet to file
uat-cli wallet export --address UAT... --output wallet.json

# Import wallet from file
uat-cli wallet import --file wallet.json
```

### validator

Manage validator operations.

```bash
# Stake to become a validator
uat-cli validator stake --amount 1000

# Unstake and begin exit
uat-cli validator unstake

# Check validator status
uat-cli validator status --address UAT...

# List all validators on the network
uat-cli validator list
```

### query

Query blockchain data.

```bash
# Get block by hash
uat-cli query block --hash abc123...

# Get account details
uat-cli query account --address UAT...

# Get node info (chain_id, version, supply, validators, peers)
uat-cli query info

# List validators with stakes
uat-cli query validators
```

### tx

Transaction operations.

```bash
# Send UAT to an address
uat-cli tx send --to UAT... --amount 100

# Check transaction status by hash
uat-cli tx status --hash abc123...
```

---

## Examples

### Full workflow: create wallet, check balance, send tokens

```bash
# Point to your node
export UAT_RPC_URL=http://127.0.0.1:3030

# Create wallet
uat-cli wallet new
# → Address: UATBwXk9...
# → Seed phrase: word1 word2 ... word24

# Check balance
uat-cli wallet balance --address UATBwXk9...
# → Balance: 0 UAT (0 VOID)

# After getting testnet tokens via faucet...
uat-cli tx send --to UATRecipient... --amount 50
# → TX hash: abc123...

# Verify
uat-cli tx status --hash abc123...
```

### Connect via Tor

```bash
# If your node is behind a Tor hidden service
export UAT_RPC_URL=http://your-node.onion

# Use with Tor SOCKS5 proxy
# Note: uat-cli uses reqwest, configure proxy via environment
export HTTPS_PROXY=socks5h://127.0.0.1:9052
export HTTP_PROXY=socks5h://127.0.0.1:9052

uat-cli query info
```

---

## Node Console Commands

When running `uat-node` interactively, these commands are available in the terminal:

| Command | Description |
|---------|-------------|
| `bal` | Show this node's balance |
| `whoami` | Show this node's address |
| `history` | Show transaction history |
| `send <address> <amount>` | Send UAT |
| `burn <amount>` | Proof-of-Burn |
| `supply` | Show supply statistics |
| `peers` | Show connected peers |
| `dial <multiaddr>` | Connect to a specific peer |
| `exit` | Graceful shutdown |
