# Unauthority (LOS) — Technical Whitepaper

**Version:** 1.0.6-testnet  
**Date:** February 2026

---

## Abstract

Unauthority (LOS) is a Layer-1 blockchain designed for absolute immutability. There are no admin keys, no pause functions, no upgrade mechanisms. Once deployed, the chain is autonomous and cannot be altered by any party.

The system combines a **block-lattice (DAG) structure** with **aBFT consensus**, **post-quantum cryptography** (CRYSTALS-Dilithium5), and **Tor-only networking** to create a permissionless, censorship-resistant financial network.

Total supply is fixed at **21,936,236 LOS**, distributed 93% via Proof-of-Burn and 7% to the development treasury.

---

## 1. Ledger Structure: Block-Lattice

LOS uses a **block-lattice** architecture where each account maintains its own blockchain. This eliminates global block ordering for simple transfers and enables high throughput.

### Block Types

| Type | Purpose | Link Field |
|------|---------|------------|
| `Send` | Transfer value to another account | Recipient address |
| `Receive` | Accept incoming Send | Hash of the Send block |
| `Change` | Update representative (delegated voting) | New representative address |
| `Mint` | Create new LOS via Proof-of-Burn consensus | Burn proof data |
| `Slash` | Penalize misbehaving validators | Evidence hash |

### Block Fields

```
account:         Account address (LOS...)
previous:        Hash of previous block in this account's chain
representative:  Delegated voting representative
balance:         Account balance after this block (in CIL)
link:            Context-dependent (see above)
fee:             Transaction fee (minimum 100,000 CIL = 0.001 LOS)
timestamp:       Unix timestamp (±300s drift tolerance)
work:            Proof-of-work nonce (16-bit difficulty, anti-spam only)
signature:       CRYSTALS-Dilithium5 signature
hash:            Keccak-256(signing_hash || signature)
```

### Hash Construction

```
signing_hash = Keccak-256(chain_id || account || previous || representative || balance || link || fee || timestamp)
block_hash   = Keccak-256(signing_hash || signature)
```

---

## 2. Consensus: Asynchronous Byzantine Fault Tolerance

### 2.1 Protocol

LOS implements aBFT with three-phase voting:

1. **Pre-prepare** — Leader proposes a block
2. **Prepare** — Validators verify and broadcast prepare messages
3. **Commit** — Upon 2/3+ prepare votes, validators broadcast commit

A block is finalized when it receives commit votes from ≥ 2/3 of validators. Target finality: **< 3 seconds**.

Byzantine tolerance: `f = ⌊(n-1)/3⌋` — the network tolerates up to f faulty validators out of n total.

### 2.2 Quadratic Voting

Voting power is proportional to the **square root of stake**, not the raw stake:

$$\text{voting\_power} = \sqrt{\text{stake\_in\_cil}}$$

This prevents whale concentration. A validator with 100,000 LOS has only 10× the voting power of one with 1,000 LOS (not 100×).

Implementation uses deterministic integer square root via Newton's method on `u128` with 6-decimal precision.

### 2.3 Slashing

| Violation | Penalty | Consequence |
|-----------|---------|-------------|
| Double-signing | 100% stake burn | Permanent ban |
| Downtime | 1% stake burn per epoch | Warning / eventual unstaking |

Downtime is measured as: < 95% uptime within a rolling window of 50,000 blocks. A minimum of 10,000 missed blocks triggers the first slash.

Slash proposals require multi-validator confirmation to prevent abuse.

### 2.4 Checkpoints

Every 1,000 blocks, a checkpoint is created with 67% quorum. Checkpoints are persisted to disk (sled) and prevent long-range attacks.

---

## 3. Cryptography

### 3.1 CRYSTALS-Dilithium5

All signatures use **CRYSTALS-Dilithium5** — a NIST PQC Level 5 lattice-based signature scheme. This provides security against both classical and quantum computing attacks.

| Parameter | Value |
|-----------|-------|
| Public key size | 2,592 bytes |
| Secret key size | 4,864 bytes |
| Signature size | 4,627 bytes |
| Security level | NIST Level 5 (AES-256 equivalent) |

### 3.2 Address Derivation

```
public_key  →  BLAKE2b-512  →  first 20 bytes  →  prepend version byte 0x4A
            →  SHA-256(SHA-256(versioned))  →  first 4 bytes (checksum)
            →  Base58(versioned + checksum)  →  prepend "LOS"
```

Example address: `LOSBwXk9m2P3dU7N5R1Qj8K4vL6Y...`

### 3.3 Deterministic Key Generation (v1.0.3+)

BIP39 mnemonic (24 words) → 64-byte seed → domain-separated derivation:

```
salt    = SHA-256("los-dilithium5-keygen-v1")
derived = SHA-256(salt || bip39_seed)  →  32-byte ChaCha20 seed
keypair = Dilithium5::keypair_from_seed(derived)
```

This produces identical keypairs across Rust (node) and Dart (Flutter wallet) implementations.

### 3.4 Key Encryption

Private keys are encrypted at rest using the `age` crate with scrypt KDF. On mainnet, a minimum 12-character password is required (`LOS_WALLET_PASSWORD`). Node auto-migrates plaintext keys to encrypted format.

### 3.5 Memory Safety

All key material implements `Zeroize` on `Drop` — private keys are overwritten with zeros when they go out of scope. Flutter wallet also zeros seed bytes in Dart after FFI calls.

---

## 4. Networking

### 4.1 Transport

LOS uses **libp2p** with the following configuration:

- **Protocol**: GossipSub on topic `"uat-blocks"`
- **Encryption**: Noise Protocol Framework
- **Multiplexing**: Yamux
- **Discovery**: mDNS (disabled under Tor to prevent DNS leaks)
- **Max message size**: 10 MB

### 4.2 Tor Integration

All public-facing nodes run as **Tor hidden services (.onion)**. The network:

- Binds to `127.0.0.1` by default (prevents IP exposure)
- Routes all P2P traffic through SOCKS5 proxy
- Disables mDNS when Tor is active (prevents DNS leaks)
- Supports both direct Multiaddr and `.onion` bootstrap formats

The Flutter wallet and validator apps include **bundled Tor** — zero-configuration connectivity.

### 4.3 P2P Message Types

| Message | Purpose |
|---------|---------|
| `ID` | Node identity announcement |
| `SYNC_GZIP` | Compressed full-state sync (max 8MB, 50MB decompressed) |
| `SYNC_REQUEST` | Request state from peers |
| `VOTE_REQ` / `VOTE_RES` | Burn consensus voting |
| `CONFIRM_REQ` / `CONFIRM_RES` | Send transaction confirmation |
| `ORACLE_SUBMIT` | Price oracle broadcast |
| `SLASH_REQ` | Slashing proposal |
| Raw Block JSON | Block propagation |

---

## 5. Token Economics

### 5.1 Supply

| Parameter | Value |
|-----------|-------|
| Total supply | 21,936,236 LOS |
| Smallest unit | 1 CIL |
| Conversion | 1 LOS = 10^11 CIL (100,000,000,000) |
| Inflation | **Zero** — supply is fixed forever |

### 5.2 Distribution

| Allocation | LOS | Percentage |
|------------|-----|-----------|
| Public (Proof-of-Burn) | 20,400,700 | 93% |
| Dev Treasury (8 wallets) | 1,535,536 | 7% |
| **Total** | **21,936,236** | **100%** |

Dev Treasury: Wallets #1–#7 hold 191,942 LOS each. Wallet #8 holds 187,942 LOS (funded 4 bootstrap validators at 1,000 LOS each).

### 5.3 Proof-of-Burn Minting

New LOS is minted by verifiably burning ETH or BTC:

1. User burns ETH/BTC to a dead address (`0x...dead` / `1BitcoinEater...`)
2. User submits burn proof (txid) to LOS network
3. Oracle consensus verifies the burn via external price feeds
4. If ≥ 2/3 validators confirm, LOS is minted proportionally

Mint calculation uses **pure integer math** (no floating-point):

```
1 LOS = $0.01 = 10,000 micro-USD
mint_cil = (burn_micro_usd * CIL_PER_LOS) / 10,000
```

Oracle sources: CoinGecko, CryptoCompare, Kraken (via Tor SOCKS5 proxy).  
Sanity bounds: ETH $10–$100,000 · BTC $100–$10,000,000. Oracle fails closed on mainnet.

### 5.4 Anti-Whale Mechanisms

- **Quadratic Voting**: voting_power = √(stake) — dampens whale influence
- **Dynamic Fee Scaling**: fees multiply 2× per additional tx beyond 10 tx/minute per account
- **Activity Windows**: 60-second rolling windows track per-account tx frequency
- **Max burn per block**: 1,000 LOS (anti-abuse)

### 5.5 Transaction Fees

| Parameter | Value |
|-----------|-------|
| Minimum fee | 0.001 LOS (100,000 CIL) |
| Base gas price | 1,000 CIL |
| Max gas per tx | 10,000,000 |
| Gas per byte | 10 |
| Spam threshold | 10 tx/s per account |
| Spam scaling | 2^n (exponential) |

### 5.6 Validator Rewards

Validators are incentivized through an epoch-based reward system drawn from a dedicated reward pool.

| Parameter | Value |
|-----------|-------|
| Reward pool | 2,193,623 LOS (~10% of total supply) |
| Epoch duration | 24 hours (86,400 seconds) |
| Initial rate | 50 LOS per epoch |
| Halving schedule | Every 365 epochs (~1 year) |
| Minimum uptime | 95% (heartbeats per epoch) |
| Probation period | 3 epochs after registration |
| Heartbeat interval | 60 seconds |

Reward distribution uses **quadratic fairness**:

$$\text{share}_i = \frac{\sqrt{\text{stake}_i}}{\sum_j \sqrt{\text{stake}_j}} \times \text{epoch\_reward}$$

This ensures smaller validators receive proportionally larger rewards relative to their stake, preventing whale concentration of reward income. Genesis bootstrap validators are permanently excluded from rewards.

The reward halving follows the formula:

$$\text{rate}(e) = \frac{\text{initial\_rate}}{2^{\lfloor e / 365 \rfloor}}$$

where $e$ is the current epoch number. This creates a deflationary reward schedule that asymptotically approaches zero, ensuring the reward pool lasts indefinitely.

---

## 6. Smart Contracts (UVM)

The **Unauthority Virtual Machine (UVM)** executes WASM smart contracts:

| Parameter | Value |
|-----------|-------|
| Engine | Wasmer + Cranelift |
| Max bytecode | 1 MB |
| Max execution time | 5 seconds |
| Gas: per KB bytecode | 100 |
| Gas: per ms execution | 10 |

Contract deployment validates WASM magic bytes (`\0asm`), computes a blake3 address hash, and stores bytecode on-chain. Execution runs in a sandboxed thread with an abort flag.

**Security invariant**: `mint` via contract is **permanently disabled** — only PoB consensus can create new tokens.

---

## 7. Genesis

### 7.1 Mainnet Genesis

Defined in `genesis_config.json`:

- Network ID: 1 (`uat-mainnet`)
- Total supply: 2,193,623,600,000,000,000 CIL (= 21,936,236 LOS)
- Dev supply: 153,553,600,000,000,000 CIL (= 1,535,536 LOS, 7%)
- 8 dev treasury wallets + 4 bootstrap validators (1,000 LOS each)

### 7.2 Testnet Genesis

Defined in `testnet-genesis/testnet_wallets.json`:

- Network ID: 2 (`uat-testnet`)
- Identical allocation structure to mainnet
- All wallets have BIP39 seed phrases and deterministic Dilithium5 keypairs
- Faucet available: 5,000 LOS per claim, 1-hour cooldown

---

## 8. Security Properties

| Property | Implementation |
|----------|---------------|
| Zero admin keys | No pause, upgrade, or kill switch in code |
| Integer-only math | No `f64` in consensus, supply, or mint calculations |
| Post-quantum signatures | Dilithium5 (NIST Level 5) for all block signatures |
| Key encryption at rest | `age` crate with scrypt KDF |
| Memory zeroing | `Zeroize` on `Drop` for all key material |
| P2P encryption | Noise Protocol Framework via libp2p |
| Tor-only networking | Default bind `127.0.0.1`, mDNS disabled under Tor |
| Decompression limit | 50 MB max for sync payloads |
| Rate limiting | 100 req/s global, per-endpoint cooldowns |
| Slash consensus | Multi-validator confirmation required |
| Supply verification | 1% tolerance check on state sync |

---

## 9. Crate Structure

```
crates/
├── los-core        # Ledger, accounts, block types, supply math, anti-whale, validator rewards
├── los-crypto      # Dilithium5, address derivation, key encryption
├── los-consensus   # aBFT protocol, quadratic voting, slashing, checkpoints
├── los-network     # libp2p, GossipSub, Tor transport, fee scaling
├── los-vm          # WASM smart contract engine (Wasmer + Cranelift)
├── los-node        # Full node binary — REST API + gRPC + P2P
└── los-cli         # Command-line interface
```

Both Flutter apps (`flutter_wallet/`, `flutter_validator/`) use `flutter_rust_bridge` (FFI) to call native Dilithium5 functions compiled per platform.

---

## References

- CRYSTALS-Dilithium: [pq-crystals.org/dilithium](https://pq-crystals.org/dilithium/)
- libp2p: [libp2p.io](https://libp2p.io/)
- Wasmer: [wasmer.io](https://wasmer.io/)
- Tor Project: [torproject.org](https://www.torproject.org/)
- BIP39: [github.com/bitcoin/bips/blob/master/bip-0039.mediawiki](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
