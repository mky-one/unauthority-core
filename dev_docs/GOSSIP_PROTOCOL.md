# Gossip Protocol — Unauthority (LOS)

P2P message formats, gossip topology, peer discovery, and network communication.

---

## Table of Contents

1. [Overview](#overview)
2. [Transport Layer](#transport-layer)
3. [Message Types](#message-types)
4. [Gossip Topology](#gossip-topology)
5. [Peer Discovery](#peer-discovery)
6. [Peer Management](#peer-management)
7. [Message Format](#message-format)
8. [Flow: Block Propagation](#flow-block-propagation)
9. [Flow: Burn Verification](#flow-burn-verification)
10. [Flow: Oracle Submission](#flow-oracle-submission)
11. [Security](#security)
12. [Configuration](#configuration)

---

## Overview

Unauthority's P2P network runs **exclusively over Tor hidden services** using HTTP POST gossip messages. Each validator maintains a peer table of other validators' `.onion` addresses and communicates via SOCKS5 proxied HTTP requests.

```
Validator A (.onion:4030)
    │
    │──── HTTP POST (via Tor SOCKS5) ────▶ Validator B (.onion:4031)
    │                                       │
    │◀─── HTTP POST (via Tor SOCKS5) ──────│
    │
    │──── HTTP POST (via Tor SOCKS5) ────▶ Validator C (.onion:4032)
    │                                       │
    │◀─── HTTP POST (via Tor SOCKS5) ──────│
```

### Why HTTP over Tor?

- **Reliability** — HTTP gives definitive success/failure per message (vs UDP)
- **NAT traversal** — Tor hidden services work behind any firewall
- **Privacy** — No IP exposure; `.onion` addresses are cryptographic
- **Simplicity** — Standard HTTP tooling for debugging

### Trade-off

HTTP over Tor adds ~500ms-2s latency per hop. The block-lattice architecture mitigates this — per-account chains enable parallel processing, and finality targets <3s over Tor.

---

## Transport Layer

### Libp2p + Tor Integration

The network stack uses libp2p for peer management with custom Tor transport:

```
┌─────────────────────────────┐
│         Gossipsub            │  ← Message broadcasting
│    Topic: "los-blocks"       │
├─────────────────────────────┤
│      Noise Protocol          │  ← End-to-end encryption
│    XX handshake pattern      │
├─────────────────────────────┤
│      TCP / SOCKS5 Proxy      │  ← Tor SOCKS5 tunneling
│   127.0.0.1:9050 → .onion   │
├─────────────────────────────┤
│      Tor Network             │  ← Onion-routed transport
│   Hidden Service ↔ Hidden Service │
└─────────────────────────────┘
```

### SOCKS5 Proxy

The `TorDialer` creates local TCP proxy sockets that tunnel through Tor:

```
Local app → 127.0.0.1:{random_port} → SOCKS5 127.0.0.1:9050 → Tor → peer.onion:4030
```

This is transparent to libp2p — it sees a regular TCP connection to a local port.

### Port Scheme

| Service | Port Formula | Example (base 3030) |
|---|---|---|
| REST API | `--port` | 3030 |
| P2P Gossip | `--port + 1000` | 4030 |
| gRPC | `--port + 20000` | 23030 |

---

## Message Types

| Message ID | Direction | Purpose |
|---|---|---|
| `ID` | Broadcast | Node identity announcement (address, version, capabilities) |
| `BLOCK` | Broadcast | New finalized block propagation |
| `CONFIRM_REQ` | Broadcast | Request confirmation votes for a Send transaction |
| `CONFIRM_ACK` | Response | Confirmation vote response |
| `VOTE_REQ` | Broadcast | Request burn verification votes |
| `VOTE_RES` | Response | Burn verification vote with signed result |
| `ORACLE_SUBMIT` | Broadcast | Oracle price submission (ETH/USD, BTC/USD) |
| `PEER_REQ` | Request | Request peer table |
| `PEER_RES` | Response | Share known peers |
| `VIEW_CHANGE` | Broadcast | aBFT view change proposal |

### Message Priority

| Priority | Messages | Behavior |
|---|---|---|
| Critical | `VIEW_CHANGE`, `BLOCK` | Sent immediately, retry on failure |
| High | `CONFIRM_REQ`, `VOTE_REQ` | Process before normal queue |
| Normal | `CONFIRM_ACK`, `VOTE_RES`, `ORACLE_SUBMIT` | Standard FIFO processing |
| Low | `ID`, `PEER_REQ`, `PEER_RES` | Background, non-blocking |

---

## Gossip Topology

### Full Mesh (Current)

With the current validator set size (4-100 validators), all nodes maintain direct connections to all other nodes:

```
    V1 ←──────▶ V2
    ↕  ╲      ╱  ↕
    ↕    ╲  ╱    ↕
    ↕    ╱  ╲    ↕
    ↕  ╱      ╲  ↕
    V3 ←──────▶ V4
```

Each node gossips messages to **all** connected peers. With Tor latency factored in, this ensures rapid convergence.

### Gossipsub

The libp2p Gossipsub implementation manages:
- **Topic:** `"los-blocks"` — single topic for all gossip messages
- **Max message size:** 10 MB (accommodates Dilithium5 signatures ~4.6KB)
- **Deduplication:** Message IDs prevent re-processing

### mDNS Discovery

- **Enabled:** When Tor is NOT active (local testing)
- **Disabled:** When Tor is active (production)

When Tor is active, mDNS is wrapped in `Toggle(None)` to prevent IP leaks.

---

## Peer Discovery

### Auto-Bootstrap (v1.0.9+)

On startup, the node:

1. **Read genesis config** — embedded at compile-time in the binary
2. **Extract bootstrap peers** — `.onion` addresses from genesis validator entries
3. **Detect Tor SOCKS5** — probe `127.0.0.1:9050` with 500ms timeout
4. **Dial bootstrap peers** — connect via SOCKS5 to each `.onion:p2p_port`
5. **Exchange peer tables** — learn about additional peers from connected nodes

```
┌──────────────┐     ┌──────────────┐
│  New Node    │     │ Bootstrap V1  │
│              │────▶│ (.onion:4030) │
│              │◀────│               │
│  peer_table  │     │  + peer_table │
│  [V1]        │     │  [V1,V2,V3,V4]│
└──────┬───────┘     └──────────────┘
       │
       │ Now knows V2, V3, V4...
       │
       ├──────▶ Connect to V2 (.onion:4031)
       ├──────▶ Connect to V3 (.onion:4032)
       └──────▶ Connect to V4 (.onion:4033)
```

### Manual Override

```bash
# Override bootstrap peers (comma-separated)
export LOS_BOOTSTRAP_PEERS="abc.onion:4030,def.onion:4031,ghi.onion:4032"

# Custom Tor SOCKS5 port
export LOS_TOR_SOCKS="127.0.0.1:9150"
```

### Bootstrap Node Format

Supported formats for `LOS_BOOTSTRAP_PEERS`:

```
abc123.onion:4030          # Onion with port
abc123.onion               # Onion with default P2P port
/ip4/127.0.0.1/tcp/4030   # Multiaddr (local testing)
```

### Reconnection

If peer count drops below minimum:
- **Testnet:** Reconnect every 60 seconds
- **Mainnet:** Reconnect every 180 seconds

The reconnection loop re-dials all bootstrap nodes and attempts to restore connections.

---

## Peer Management

### Peer Session

Each connection is tracked as a `PeerSession`:

```rust
struct PeerSession {
    peer_id: String,        // Peer's libp2p ID
    session_id: String,     // Unique session identifier
    established_at: u64,    // Connection timestamp
    messages_sent: u64,     // Outgoing message count
    messages_received: u64, // Incoming message count
}
```

### Network Statistics

```rust
struct NetworkStats {
    total_peers: u64,        // All known peers
    connected_peers: u64,    // Currently connected
    bytes_sent: u64,         // Total bytes out
    bytes_received: u64,     // Total bytes in
    security_events: u64,    // Suspicious activity count
}
```

### Node Roles

```rust
enum NodeRole {
    Validator, // Full consensus participant
    Sentry,    // Relay node (shields validator)
    Full,      // Full node (no consensus)
}
```

---

## Message Format

### HTTP Gossip

P2P messages are JSON-encoded HTTP POST requests:

```http
POST /gossip HTTP/1.1
Host: peer.onion:4030
Content-Type: application/json

{
  "type": "BLOCK",
  "payload": { ... },
  "sender": "LOSsender_address...",
  "timestamp": 1234567890,
  "signature": "hex_dilithium5_signature"
}
```

### Gossipsub Messages

For libp2p gossipsub, messages are serialized bytes on the `"los-blocks"` topic:

```rust
// Publish
gossipsub.publish(topic, message_bytes)?;

// Subscribe
gossipsub.subscribe(&topic)?;
```

---

## Flow: Block Propagation

```
Validator A (creates block)
    │
    │── 1. Process block locally (validate, add to ledger)
    │── 2. Gossip BLOCK to all peers
    │
    ├──▶ Validator B: validate → add to ledger → ACK
    ├──▶ Validator C: validate → add to ledger → ACK
    └──▶ Validator D: validate → add to ledger → ACK
```

### Send Transaction with Confirmation

```
Client → POST /send → Validator A
    │
    │── 1. Validate Send block (PoW, signature, balance, fee)
    │── 2. Add to sender's chain
    │── 3. Gossip CONFIRM_REQ to all peers
    │
    ├──▶ Validator B: validate → return CONFIRM_ACK (signed weight)
    ├──▶ Validator C: validate → return CONFIRM_ACK (signed weight)
    └──▶ Validator D: validate → return CONFIRM_ACK (signed weight)
    │
    │── 4. Collect votes until threshold (20,000 weight, ≥2 voters)
    │── 5. Auto-create Receive block on recipient's chain
    │── 6. Gossip BLOCK (receive) to all peers
    │── 7. Return result to client
```

---

## Flow: Burn Verification

```
Client → POST /burn { txid: "0xabc..." } → Validator A
    │
    │── 1. Gossip VOTE_REQ to all peers
    │
    ├──▶ Validator B:
    │      a. Fetch burn TX from blockchain explorer
    │      b. Verify amount and dead address
    │      c. Fetch ETH/BTC price → ORACLE_SUBMIT
    │      d. Sign and return VOTE_RES
    │
    ├──▶ Validator C: (same process)
    └──▶ Validator D: (same process)
    │
    │── 2. Collect VOTE_RES until threshold
    │── 3. BFT median of oracle prices
    │── 4. Calculate yield (integer formula)
    │── 5. Create Mint block
    │── 6. Gossip BLOCK to all peers
    │── 7. Return result to client
```

---

## Flow: Oracle Submission

```
Every 60 seconds (submission window):
    │
    Validator A:
    │── Fetch ETH/BTC prices from public API
    │── Gossip ORACLE_SUBMIT { eth_usd: 2500000000, btc_usd: 83000000000 }
    │
    Validator B:
    │── Fetch ETH/BTC prices from public API
    │── Gossip ORACLE_SUBMIT { eth_usd: 2501000000, btc_usd: 82990000000 }
    │
    Validator C:
    │── Fetch ETH/BTC prices from public API
    │── Gossip ORACLE_SUBMIT { eth_usd: 2499500000, btc_usd: 83010000000 }
    │
    Aggregation (each validator independently):
    │── Sort all submitted prices
    │── Calculate integer median
    │── Reject outliers (>20% deviation from median)
    │── Store consensus price for burn calculations
```

---

## Security

### IP Leak Prevention

When Tor is active:
- All TCP listeners bind to `127.0.0.1` only
- mDNS discovery is disabled (wrapped in `Toggle(None)`)
- No clearnet connections are initiated
- All peer connections go through SOCKS5 proxy

### Message Authentication

- All gossip messages include Dilithium5 signatures
- Messages without valid signatures are dropped
- Consensus messages include Keccak256 keyed MAC
- Message source validated against known validator set

### Replay Prevention

- Messages include timestamps — stale messages rejected
- Block hash deduplication prevents re-processing
- Gossipsub message IDs prevent gossip loops

### Rate Limiting

- P2P message rate limiting per peer
- Security events tracked in `NetworkStats`
- Peers exceeding rate limits may be disconnected

### Encryption

All P2P traffic is encrypted at two layers:

1. **Tor encryption** — 3-hop onion routing, AES-128
2. **Noise Protocol** — XX handshake, end-to-end encryption between peers

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LOS_BOOTSTRAP_PEERS` | *(from genesis)* | Comma-separated `onion:port` peers |
| `LOS_TOR_SOCKS` | `127.0.0.1:9050` | Tor SOCKS5 proxy address |
| `LOS_SOCKS5_PROXY` | *(alias for above)* | Alternative env var name |
| `LOS_ONION_ADDRESS` | *(auto-detect)* | This node's `.onion` address |
| `LOS_P2P_PORT` | `--port + 1000` | P2P gossip port |

### Gossipsub Parameters

| Parameter | Value |
|---|---|
| Topic | `"los-blocks"` |
| Max message size | 10 MB |
| Heartbeat interval | 1 second |
| History length | 5 |
| History gossip | 3 |

### Reconnection

| Network | Interval | Trigger |
|---|---|---|
| Testnet | 60 seconds | `connected_peers < bootstrap_count` |
| Mainnet | 180 seconds | `connected_peers < bootstrap_count` |

### Timeouts

| Operation | Timeout |
|---|---|
| Tor SOCKS5 detection | 500ms |
| SOCKS5 connection | 30 seconds (Tor circuit building) |
| HTTP request | 60 seconds |
| Peer liveness | 300 seconds (5 minutes before marking dead) |
