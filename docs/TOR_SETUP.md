# Tor Network Setup — Unauthority (LOS) v1.0.9

## Overview

Unauthority runs **exclusively** on the Tor network. Both mainnet and testnet validators expose their services as `.onion` hidden services. No clearnet (DNS/IP) connectivity is used in production.

## Prerequisites

### Install Tor

**macOS:**
```bash
brew install tor
brew services start tor
```

**Ubuntu/Debian:**
```bash
sudo apt install tor
sudo systemctl enable tor
sudo systemctl start tor
```

**Verify Tor is running:**
```bash
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

## Hidden Service Configuration

### 1. Create a Hidden Service for Your Validator

Edit `/etc/tor/torrc` (Linux) or `/opt/homebrew/etc/tor/torrc` (macOS Homebrew):

```
# LOS Validator Hidden Service
HiddenServiceDir /var/lib/tor/los-validator/
HiddenServicePort 3030 127.0.0.1:3030    # REST API
HiddenServicePort 4001 127.0.0.1:4001    # P2P gossip
HiddenServicePort 23030 127.0.0.1:23030  # gRPC
```

### 2. Restart Tor

```bash
sudo systemctl restart tor
# or on macOS:
brew services restart tor
```

### 3. Get Your .onion Address

```bash
sudo cat /var/lib/tor/los-validator/hostname
# Output: abc123def456xyz.onion
```

### 4. Configure the Node

```bash
export LOS_ONION_ADDRESS='abc123def456xyz.onion'
export LOS_SOCKS5_PROXY='socks5h://127.0.0.1:9050'
```

The node will:
- Announce its `.onion` address to peers during handshake
- Use the SOCKS5 proxy for all outbound connections to other `.onion` peers
- Register the onion address when joining the validator set

## Multi-Validator Local Testnet with Tor

For testing, you can run multiple hidden services on one machine:

```
# Validator 1
HiddenServiceDir /var/lib/tor/los-v1/
HiddenServicePort 3030 127.0.0.1:3030
HiddenServicePort 4001 127.0.0.1:4001

# Validator 2
HiddenServiceDir /var/lib/tor/los-v2/
HiddenServicePort 3031 127.0.0.1:3031
HiddenServicePort 4002 127.0.0.1:4002

# Validator 3
HiddenServiceDir /var/lib/tor/los-v3/
HiddenServicePort 3032 127.0.0.1:3032
HiddenServicePort 4003 127.0.0.1:4003

# Validator 4
HiddenServiceDir /var/lib/tor/los-v4/
HiddenServicePort 3033 127.0.0.1:3033
HiddenServicePort 4004 127.0.0.1:4004
```

## Peer Discovery

### Bootstrap Nodes

Set the initial peer list via environment variable:

```bash
export LOS_BOOTSTRAP_NODES='abc123.onion:4001,def456.onion:4001,ghi789.onion:4001'
```

Format: comma-separated `address:port` pairs.

### Dynamic Discovery

Once connected, nodes exchange peer tables automatically:
1. The node sends `ID:address:supply:burned:timestamp` on connection
2. Peers respond with their known peer lists
3. The node maintains a dynamic peer table sorted by latency/uptime

## Flutter App Tor Connectivity

Both `flutter_wallet` and `flutter_validator` bundle Tor via `flutter_rust_bridge`:

1. **Fetch Peers:** Download the list of available `.onion` nodes
2. **Latency Check:** Ping available peers through SOCKS5
3. **Select Best Host:** Connect to the most stable external peer

**Important:** The Flutter validator app MUST connect to **external** peers, never its own local node. This ensures it verifies network consensus integrity from an outside perspective.

## Troubleshooting

### Tor Not Connecting
```bash
# Check if Tor is running
systemctl status tor

# Check SOCKS5 proxy
curl --socks5-hostname 127.0.0.1:9050 http://check.torproject.org

# Check hidden service directory permissions
ls -la /var/lib/tor/los-validator/
```

### Peer Connection Issues
```bash
# Test connectivity to a peer
curl --socks5-hostname 127.0.0.1:9050 http://PEER_ONION_ADDRESS.onion:3030/health

# Check your node's peer list
curl http://localhost:3030/peers
```

### Hidden Service Not Accessible
- Ensure `HiddenServiceDir` has correct permissions (Tor user ownership)
- Ensure port mappings match your `--port` configuration
- Wait 30-60 seconds after restart for the hidden service to propagate

## Security Notes

1. **Never expose REST API ports** to the public internet — Tor handles all external routing
2. **Bind to localhost** by default (127.0.0.1) — set `LOS_BIND_ALL=1` only if needed behind a reverse proxy
3. **Each validator gets a unique `.onion`** — this is its network identity
4. **SOCKS5 proxy** routes all outbound traffic through Tor, preventing IP leaks
