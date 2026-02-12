# Architecture

Technical architecture of the Unauthority blockchain.

**Version:** v1.0.6-testnet

---

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter Apps                       │
│   ┌─────────────────┐     ┌──────────────────────┐     │
│   │  flutter_wallet  │     │  flutter_validator   │     │
│   │  (Send/Receive)  │     │  (Monitor/Manage)    │     │
│   └────────┬─────────┘     └──────────┬───────────┘     │
│            │     flutter_rust_bridge (FFI)    │          │
│            │     ┌────────────────────┐      │          │
│            └─────┤ los_crypto_ffi.so  ├──────┘          │
│                  │ (Dilithium5 native)│                  │
│                  └────────────────────┘                  │
└─────────────────────────┬───────────────────────────────┘
                          │ REST / gRPC (via Tor)
┌─────────────────────────▼───────────────────────────────┐
│                       los-node                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ REST API │  │  gRPC    │  │  P2P     │  │Console │  │
│  │ (warp)   │  │ (tonic)  │  │ (libp2p) │  │(stdin) │  │
│  │ :3030    │  │ :23030   │  │ :4001    │  │        │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       └──────────────┴─────────────┴────────────┘       │
│                          │                              │
│  ┌───────────────────────▼────────────────────────────┐ │
│  │                   los-core                         │ │
│  │  Ledger (block-lattice) · Accounts · Supply math   │ │
│  │  Anti-whale · Distribution · Oracle consensus      │ │
│  │  Validator Rewards (epoch-based, √stake)           │ │
│  └───────────┬──────────────┬──────────────┬──────────┘ │
│              │              │              │             │
│  ┌───────────▼──┐  ┌───────▼──────┐  ┌───▼──────────┐  │
│  │  los-crypto  │  │los-consensus │  │  los-network  │  │
│  │  Dilithium5  │  │  aBFT        │  │  libp2p      │  │
│  │  BLAKE2b     │  │  Quadratic   │  │  GossipSub   │  │
│  │  Base58Check │  │  Voting      │  │  Tor/SOCKS5  │  │
│  │  age encrypt │  │  Slashing    │  │  Noise       │  │
│  │              │  │  Checkpoints │  │  mDNS        │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│              │                                          │
│  ┌───────────▼──┐                                       │
│  │   los-vm     │                                       │
│  │  Wasmer      │                                       │
│  │  Cranelift   │                                       │
│  │  WASM exec   │                                       │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

---

## Crate Dependency Graph

```
                    los-node (v1.0.6)
                   /     |     \      \
                  /      |      \      \
           los-core  los-crypto  los-network  los-vm
               |         |          |
         los-consensus   |    los-consensus
               |         |
          los-crypto  (standalone)
```

| Crate | Version | Lines | Purpose |
|-------|---------|-------|---------|
| `los-node` | 1.0.6 | ~5,100 | Full node binary — REST + gRPC + P2P + console + reward engine |
| `los-core` | 0.1.0 | ~2,800 | Ledger, block types, accounts, supply math, anti-whale, oracle, validator rewards |
| `los-crypto` | 0.1.0 | ~620 | Dilithium5 keypairs, address derivation, key encryption |
| `los-consensus` | 0.1.0 | ~2,700 | aBFT protocol, quadratic voting, slashing, checkpoints |
| `los-network` | 0.1.0 | ~1,200 | libp2p, GossipSub, Tor transport, fee scaling |
| `los-vm` | 0.1.0 | ~830 | WASM smart contracts (Wasmer + Cranelift) |
| `los-cli` | 0.1.0 | ~250 | Command-line interface (reqwest + clap) |
| `genesis` | 2.0.0 | ~200 | Genesis block generator (BIP39 + deterministic keygen) |

---

## Block-Lattice Structure

Each account has its own chain. Transactions are paired:

```
Alice's chain:           Bob's chain:
┌──────────┐            ┌──────────┐
│ Block #3 │            │ Block #5 │
│ Send 100 ├───────────►│ Receive  │
│ to Bob   │            │ from     │
│          │            │ Alice    │
└──────────┘            └──────────┘
```

### Block Hashing

```
signing_hash = Keccak-256(
    chain_id      ||    // 1 = mainnet, 2 = testnet
    account       ||    // LOS... address
    previous      ||    // Hash of previous block
    representative ||   // Delegated voting address
    balance       ||    // Balance AFTER this block (CIL)
    link          ||    // Recipient / Send hash / Burn proof
    fee           ||    // Transaction fee (CIL)
    timestamp          // Unix timestamp
)

block_hash = Keccak-256(signing_hash || signature)
```

### Block Validation Chain

```
1. Verify PoW (16 leading zero bits)
2. Verify Dilithium5 signature
3. Verify account binding (public_key → address)
4. Verify block sequence (previous hash matches)
5. Verify timestamp (±300s drift tolerance)
6. Block-type-specific validation:
   - Send: balance ≥ amount + fee, not blocked by anti-whale
   - Receive: matching Send block exists, not already received
   - Mint: oracle consensus confirmed, within supply cap
   - Slash: multi-validator confirmation
```

---

## Cryptographic Architecture

### Key Hierarchy

```
BIP39 Mnemonic (24 words)
    │
    ▼
BIP39 Seed (64 bytes)
    │
    ▼ SHA-256("los-dilithium5-keygen-v1") = salt
    │ SHA-256(salt || seed) = derived_seed (32 bytes)
    │
    ▼ ChaCha20-seeded Dilithium5 keygen
┌───────────────┐
│ Public Key    │ (2,592 bytes)
│ Secret Key    │ (4,864 bytes)
└───────┬───────┘
        │
        ▼ BLAKE2b-512 → first 20 bytes → version 0x4A
        │ → SHA-256(SHA-256()) → first 4 bytes (checksum)
        │ → Base58(versioned + checksum) → prepend "LOS"
        │
        ▼
LOS Address (e.g., "LOSBwXk9m2P3dU7...")
```

### Cross-Platform Consistency

Both Rust (node/genesis) and Dart (Flutter apps) use identical derivation:

| Step | Rust | Dart |
|------|------|------|
| BIP39 | `bip39` crate | `bip39` package |
| Seed derivation | `sha2::Sha256` | FFI → Rust `sha2::Sha256` |
| Keygen | `pqcrypto-dilithium` (patched internals) | FFI → same Rust lib |
| Address | `blake2`, `bs58` | FFI → same Rust lib |

The `pqcrypto-internals-seeded` patch enables deterministic keypair generation from a seed, ensuring the same mnemonic produces the same address everywhere.

---

## Consensus Flow

```
                    ┌─────────┐
                    │ Leader  │
                    │(round-  │
                    │ robin)  │
                    └────┬────┘
                         │
              1. Pre-prepare (block)
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │Validator│    │Validator│    │Validator│
    │   A     │    │   B     │    │   C     │
    └────┬────┘    └────┬────┘    └────┬────┘
         │              │              │
         │    2. Prepare (verify + broadcast)
         │              │              │
         └──────────────┼──────────────┘
                        │
              3. Commit (when ≥ 2/3 prepare)
                        │
                        ▼
                  Block Finalized
                  (< 3 seconds)

Byzantine tolerance: f = ⌊(n-1)/3⌋
Quorum: ≥ 67% of validators must agree
Voting power: √(stake) — quadratic, not linear
```

---

## Network Topology

```
┌─────────────────────────────────┐
│           TOR NETWORK           │
│                                 │
│  ┌───────┐  ┌───────┐          │
│  │.onion │  │.onion │  ...     │
│  │Node 1 │  │Node 2 │          │
│  └───┬───┘  └───┬───┘          │
│      │          │               │
│      └────┬─────┘               │
│           │                     │
│    GossipSub topic:             │
│    "uat-blocks"                 │
│                                 │
│    Transport: Noise Protocol    │
│    Mux: Yamux                   │
│    Max message: 10 MB           │
│    Heartbeat: 1 second          │
└─────────────────────────────────┘
```

### P2P Message Flow

```
Block Created → Sign (Dilithium5) → PoW (16-bit)
    → GossipSub broadcast → Peers validate
    → aBFT vote round → Finalize (< 3s)
```

### Tor Integration Details

| Setting | Value |
|---------|-------|
| Default bind | `127.0.0.1` (prevents IP leak) |
| SOCKS5 proxy | Configurable via `--tor-socks` |
| mDNS | Disabled when Tor active |
| Flutter proxy | Port 9250 (bundled) or 9150 (Tor Browser) |

---

## Storage Architecture

```
node_data/
├── wallet.json           # Dilithium5 keypair (age-encrypted)
├── ledger_state.json     # Full account balances + block history
├── sled/                 # Embedded key-value store
│   ├── faucet_cooldowns  # Per-address faucet rate limiting
│   ├── checkpoints       # aBFT checkpoint data
│   └── slashing          # Validator slashing records
└── tor/                  # Tor hidden service keys (if configured)
```

### Persistence

- **Ledger**: Debounced writes to `ledger_state.json` every 5 seconds with checkpoint
- **Faucet**: Persistent cooldowns in sled (survives restart)
- **Reward Pool**: In-memory state, re-initialized from genesis on restart (sled persistence planned for mainnet)
- **State sync**: GZIP-compressed HTTP-based full sync (`/sync` endpoint)
- **Deadlock prevention**: Never hold two `Arc<Mutex>` simultaneously

---

## WASM Virtual Machine (UVM)

```
Deploy:                          Execute:
┌──────────┐                    ┌──────────┐
│ WASM     │ validate magic     │ Function │ spawn thread
│ bytecode │────────────►       │ call     │──────────►
│ (≤1MB)   │ blake3 addr        │          │ timeout 5s
└──────────┘                    └──────────┘
                                     │
                               abort flag on timeout
```

| Limit | Value |
|-------|-------|
| Max bytecode | 1 MB |
| Max execution | 5 seconds |
| Gas per KB | 100 |
| Gas per ms | 10 |
| Mint via contract | **Permanently disabled** |

---

## Security Layers

```
Layer 1: Cryptography
├── Dilithium5 (post-quantum signatures)
├── BLAKE2b-160 + Base58Check (addresses)
├── Keccak-256 (block hashing)
├── age + scrypt (key encryption at rest)
└── Zeroize (memory zeroing)

Layer 2: Consensus
├── aBFT (2/3 quorum)
├── Quadratic voting (√stake)
├── Multi-validator slash confirmation
├── Checkpoint persistence (sled)
└── Integer-only math (no f64)

Layer 3: Network
├── Tor hidden services (.onion)
├── Noise Protocol (P2P encryption)
├── mDNS disabled under Tor
├── Rate limiting (100/s global)
└── Decompression bomb protection (50MB)

Layer 4: Application
├── Zero admin keys
├── No pause/upgrade/kill functions
├── Supply verification (1% tolerance)
├── Vote deduplication
└── Stale pending cleanup (60s TTL)
```
