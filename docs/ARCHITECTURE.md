# Architecture — Unauthority (LOS) v1.0.9

## System Overview

Unauthority is a block-lattice (DAG) blockchain where each account maintains its own chain of blocks. A global ledger state is maintained via aBFT consensus across validators communicating over Tor hidden services.

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter Wallet / Validator             │
│                 (Dart + Rust via flutter_rust_bridge)     │
└─────────────────────────┬────────────────────────────────┘
                          │ REST / gRPC
┌─────────────────────────▼────────────────────────────────┐
│                      los-node                            │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌───────────┐  │
│  │ REST API │ │ gRPC API  │ │ P2P      │ │ CLI REPL  │  │
│  │ (Warp)   │ │ (Tonic)   │ │ Gossip   │ │ (stdin)   │  │
│  └────┬─────┘ └─────┬─────┘ └────┬─────┘ └─────┬─────┘  │
│       └──────────────┴────────────┴─────────────┘        │
│                          │                                │
│  ┌───────────────────────▼────────────────────────────┐  │
│  │              Shared State (Arc<Mutex<>>)            │  │
│  │  Ledger · Mempool · Oracle · Slashing · Rewards    │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                                │
│  ┌──────────┐ ┌──────────┤ ┌──────────┐ ┌────────────┐  │
│  │ los-core │ │los-consen│ │los-crypto│ │ los-vm     │  │
│  │          │ │sus       │ │          │ │            │  │
│  └──────────┘ └──────────┘ └──────────┘ └────────────┘  │
└──────────────────────────────────────────────────────────┘
                          │
              ┌───────────▼───────────┐
              │   Tor Hidden Service  │
              │   (.onion network)    │
              └───────────────────────┘
```

## Crate Dependency Graph

```
los-node (main binary)
├── los-core         (blockchain primitives)
├── los-consensus    (aBFT, slashing, checkpoints)
│   └── los-core
├── los-network      (P2P, Tor transport, fee scaling)
│   └── los-core
├── los-crypto       (Dilithium5, SHA-3)
├── los-vm           (WASM smart contracts)
│   └── los-core
└── los-cli          (CLI wallet)
    ├── los-core
    └── los-crypto
```

## Crate Details

### los-core
Blockchain primitives and core state management.

| Module | Purpose |
|---|---|
| `lib.rs` | Block, AccountState, Ledger, BlockType, PoW, genesis loading |
| `distribution.rs` | Supply distribution tracking & burn accounting |
| `oracle_consensus.rs` | Decentralized oracle BFT median aggregation (u128 micro-USD) |
| `bonding_curve.rs` | LOS pricing curve for Proof-of-Burn |
| `anti_whale.rs` | Anti-whale rate limiting and burn caps |
| `validator_config.rs` | Validator configuration structures |
| `validator_rewards.rs` | Reward pool distribution (√stake formula) |

### los-consensus
aBFT consensus engine, checkpointing, and slashing.

| Module | Purpose |
|---|---|
| `abft.rs` | Asynchronous BFT consensus rounds |
| `checkpoint.rs` | Periodic state checkpointing (RocksDB) |
| `slashing.rs` | Validator slashing for misbehavior |
| `voting.rs` | Quadratic voting (√stake) |

### los-network
Networking layer with Tor integration.

| Module | Purpose |
|---|---|
| `tor_transport.rs` | SOCKS5 proxy connections for Tor |
| `p2p_integration.rs` | Peer management, connection tracking |
| `p2p_encryption.rs` | Noise Protocol encryption for P2P |
| `fee_scaling.rs` | Dynamic fee calculation based on congestion |
| `slashing_integration.rs` | Network-level slashing triggers |
| `validator_rewards.rs` | Network-level reward distribution |

### los-crypto
Post-quantum cryptography via Dilithium5.

| Function | Purpose |
|---|---|
| `generate_keypair()` | Dilithium5 key generation with BIP39 seed |
| `sign_message()` | Message signing |
| `verify_signature()` | Signature verification |
| `public_key_to_address()` | Derive LOS address from public key |

### los-node
Main validator binary — the heart of the system.

| Module | Purpose |
|---|---|
| `main.rs` | REST API (Warp), P2P gossip, burn pipeline, CLI REPL |
| `grpc_server.rs` | gRPC API (Tonic) |
| `genesis.rs` | Genesis block loading from `genesis_config.json` |
| `db.rs` | RocksDB database layer |
| `mempool.rs` | Transaction mempool management |
| `metrics.rs` | Prometheus metrics (45+ gauges/counters) |
| `rate_limiter.rs` | API rate limiting |
| `testnet_config.rs` | Graduated testnet level configuration |
| `validator_api.rs` | Validator-specific API handlers |
| `validator_rewards.rs` | Epoch reward processing |

### los-vm
WebAssembly Virtual Machine for smart contracts.

| Module | Purpose |
|---|---|
| `lib.rs` | WASM runtime, contract deployment & execution |
| `oracle_connector.rs` | Oracle price feed for contracts |

### los-cli
Command-line interface for wallet and node management.

| Command | Purpose |
|---|---|
| `wallet` | Create/import wallet, check balance |
| `tx` | Send transactions |
| `query` | Query blocks, accounts, supply |
| `validator` | Register/unregister validator |

## Block-Lattice Structure

```
Account A:    [Genesis] → [Send 50] → [Send 20] → ...
Account B:    [Genesis] → [Receive 50] → [Send 10] → ...
Account C:    [Mint 100] → [Receive 10] → ...
```

Each account has its own chain. Cross-account operations (Send → Receive) reference the counterpart block via the `link` field. This enables lock-free parallel processing — transactions on different accounts don't contend.

## Block Types

| Type | Description |
|---|---|
| `Send` | Debit from sender account |
| `Receive` | Credit to receiver account |
| `Mint` | New tokens from genesis or burn rewards |
| `Burn` | Proof-of-Burn external asset destruction |
| `Change` | Representative/validator change |

## Gossip Protocol

Nodes communicate via HTTP-based gossip over Tor:

| Message | Format | Purpose |
|---|---|---|
| `ID:` | `ID:addr:supply:burned:ts` | Node identity announcement |
| `BLOCK:` | `BLOCK:{json}` | Block propagation |
| `CONFIRM_REQ:` | `CONFIRM_REQ:hash:sender:amt:ts:block_b64` | Block confirmation request |
| `VOTE_REQ:` | `VOTE_REQ:txid:requester:coin:ts:sig:pk` | Burn vote request |
| `VOTE_RES:` | `VOTE_RES:txid:requester:YES:voter:ts:sig:pk` | Burn vote response |
| `ORACLE_SUBMIT:` | `ORACLE_SUBMIT:addr:eth_micro:btc_micro:sig:pk` | Oracle price submission |
| `VALIDATOR_REG:` | `VALIDATOR_REG:{json}:sig:pk` | Validator registration |
| `SLASH_REQ:` | `SLASH_REQ:cheater:txid:proposer:ts:sig:pk` | Slashing proposal |

All gossip messages carrying state changes are signed with Dilithium5.

## Security Model

1. **Post-Quantum:** All signatures use Dilithium5 (NIST PQC standard)
2. **Byzantine Tolerance:** aBFT consensus tolerates f < n/3 faulty validators
3. **Tor-Only:** No clearnet exposure — all traffic over .onion
4. **Anti-Whale:** Quadratic voting prevents stake centralization
5. **Integer Math:** All consensus-critical arithmetic uses u128 — zero floating-point in the pipeline
6. **Slashing:** Validators penalized for double-signing and fake burn claims
