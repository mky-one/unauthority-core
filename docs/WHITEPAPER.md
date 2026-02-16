# Whitepaper — Unauthority (LOS) v1.0.9

**Lattice Of Sovereignty: A Post-Quantum, Tor-Native Block-Lattice Blockchain**

*February 2026*

---

## Abstract

Unauthority (LOS) is a decentralized, permissionless blockchain built on a block-lattice (DAG) structure with asynchronous Byzantine Fault Tolerant (aBFT) consensus. It operates exclusively over Tor hidden services, ensuring censorship resistance and network-level privacy. All cryptographic operations use Dilithium5 (NIST Post-Quantum Cryptography standard), and all consensus-critical arithmetic uses fixed-point integer math (u128) to guarantee cross-node determinism.

## 1. Design Principles

1. **Privacy First:** No clearnet. All validators and clients communicate over `.onion` addresses.
2. **Post-Quantum Security:** Dilithium5 signatures resist both classical and quantum attacks.
3. **Deterministic Consensus:** Zero floating-point in the consensus pipeline. All values stored as integer representations (CIL for balances, micro-USD for prices, wei/satoshi for burn amounts).
4. **Fixed Supply:** 21,936,236 LOS — no inflation, no minting beyond the genesis allocation and Proof-of-Burn mechanism.
5. **Anti-Centralization:** Quadratic voting (√Stake) prevents whale dominance.

## 2. Block-Lattice Structure

Unlike traditional blockchains where all transactions compete for space in global blocks, Unauthority uses a block-lattice structure (inspired by Nano/Block Lattice designs):

- Each account maintains its own chain of blocks
- Transactions between accounts create linked block pairs (Send → Receive)
- Accounts can be updated in parallel without global contention
- A global ledger state tracks all account balances and block hashes

### Block Types

| Type | Description |
|---|---|
| `Send` | Debit from sender, `link` field references the recipient |
| `Receive` | Credit to receiver, `link` references the sending block |
| `Mint` | Token creation (genesis or burn rewards) |
| `Burn` | Proof-of-Burn destruction event |
| `Change` | Representative/validator delegation change |

### Block Fields

```
Block {
    account:    String,     // Owner address (LOSW... or LOSX...)
    previous:   String,     // Hash of previous block in this chain
    block_type: BlockType,  // Send | Receive | Mint | Burn | Change
    amount:     u128,       // Amount in CIL (atomic units)
    link:       String,     // Context-dependent (recipient, source, burn proof)
    signature:  String,     // Dilithium5 hex signature
    public_key: String,     // Dilithium5 hex public key
    work:       u64,        // Proof-of-Work nonce (spam prevention)
    timestamp:  u64,        // Unix timestamp
    fee:        u128,       // Transaction fee in CIL
}
```

## 3. Consensus: Asynchronous BFT

Unauthority uses aBFT consensus for block finalization:

1. **Block Proposal:** A validator creates a block and gossips a `CONFIRM_REQ` to peers
2. **Voting:** Peers validate the block (signature, balance, PoW) and send votes
3. **Finalization:** Once ≥2/3 of validators (by quadratic stake weight) confirm, the block is finalized
4. **Safety:** The system tolerates f < n/3 Byzantine (malicious/faulty) validators

### Quadratic Voting

Instead of raw stake-weighted voting:
```
vote_weight = √(stake)
```

This prevents any single whale from dominating consensus while still rewarding larger stakes.

## 4. Token Economics

### Supply Distribution

| Allocation | Amount (LOS) | Amount (CIL) | Percentage |
|---|---|---|---|
| Public (Proof-of-Burn) | 21,158,413 | 2,115,841,300,000,000,000 | ~96.5% |
| Dev Treasury 1 | 428,113 | 42,811,300,000,000,000 | ~1.95% |
| Dev Treasury 2 | 245,710 | 24,571,000,000,000,000 | ~1.12% |
| Dev Treasury 3 | 50,000 | 5,000,000,000,000,000 | ~0.23% |
| Dev Treasury 4 | 50,000 | 5,000,000,000,000,000 | ~0.23% |
| Bootstrap Validators (4) | 4,000 | 400,000,000,000,000 | ~0.02% |
| **Total** | **21,936,236** | **2,193,623,600,000,000,000** | **100%** |

### Unit System

| Unit | CIL Value |
|---|---|
| 1 LOS | 100,000,000,000 CIL (10¹¹) |
| 1 CIL | 1 (atomic unit) |

### Validator Reward Pool

- **Budget:** 500,000 LOS (allocated from dev treasury, non-inflationary)
- **Per Epoch:** 5,000 LOS, halving every 48 epochs
- **Distribution Formula:**
  ```
  reward_i = epoch_budget × isqrt(stake_i) / Σ isqrt(stake_all)
  ```
  Where `isqrt` is integer square root — no floating-point.
- **Eligibility:** Minimum 1,000 LOS stake, ≥95% uptime

## 5. Proof-of-Burn

Users acquire LOS by burning ETH or BTC to provably unspendable addresses:

| Asset | Burn Address |
|---|---|
| ETH | `0x000000000000000000000000000000000000dEaD` |
| BTC | `1BitcoinEaterAddressDontSendf59kuE` |

### Burn Pipeline (Deterministic Integer Math)

1. **Submit TXID:** User submits a burn TX hash via `/burn` API
2. **Oracle Consensus:** Multiple validators fetch prices from external APIs, submit prices as micro-USD (u128, 1 USD = 1,000,000 micro-USD)
3. **Median Aggregation:** BFT median of all validator price submissions (resists manipulation)
4. **Amount Verification:** Burn amount fetched from blockchain explorer (wei for ETH, satoshi for BTC)
5. **CIL Calculation:** Pure u128 arithmetic — `cil = amount_base × price_micro / base_divisor × cil_per_los / 1_000_000`
6. **Multi-Validator Vote:** ≥2 independent validators must verify the TXID
7. **Mint Block:** Created on consensus achievement

### Anti-Manipulation

- **Outlier Detection:** Oracle prices deviating >20% from median (in basis points) are flagged
- **Double-Claim Prevention:** Each TXID can only be claimed once (globally deduplicated)
- **Slashing:** Validators submitting fake TXIDs or manipulated prices face stake reduction

## 6. Smart Contracts (UVM)

Unauthority supports smart contracts compiled to WebAssembly (WASM):

- **USP-01:** Native Fungible Token Standard (enables wrapped assets: wBTC, wETH)
- **Runtime:** UVM (Unauthority Virtual Machine) executes WASM bytecode
- **Deployment:** Via `/deploy-contract` API endpoint
- **Execution:** Via `/call-contract` API endpoint
- **Oracle Access:** Contracts can query oracle price feeds

## 7. Network Layer

### Transport

All inter-node communication occurs over Tor hidden services:

- Each validator hosts a `.onion` address
- Gossip protocol uses HTTP POST over Tor SOCKS5
- Signed gossip messages prevent spoofing (Dilithium5)

### Peer Discovery

1. Bootstrap from hardcoded seed nodes
2. Exchange peer tables during ID handshake
3. Maintain dynamic peer table sorted by latency/uptime
4. Automatic reconnection on failure

### Gossip Messages

| Message | Purpose |
|---|---|
| `ID` | Node identity and supply announcement |
| `BLOCK` | Block propagation |
| `CONFIRM_REQ` / `CONFIRM_RES` | Block confirmation voting |
| `VOTE_REQ` / `VOTE_RES` | Burn verification voting |
| `ORACLE_SUBMIT` | Price oracle submissions |
| `VALIDATOR_REG` / `VALIDATOR_UNREG` | Validator set changes |
| `SLASH_REQ` | Slashing proposals |

## 8. Security Analysis

### Post-Quantum Resistance
Dilithium5 is a NIST-standardized lattice-based signature scheme. It provides:
- 256-bit classical security
- 128-bit quantum security (against Grover/Shor)
- Compact signatures (~4.6 KB)

### Determinism Guarantee
All consensus-critical computation uses `u128` integer arithmetic:
- Prices: micro-USD (6 decimal places)
- ETH amounts: wei (18 decimal places)
- BTC amounts: satoshi (8 decimal places)
- Outlier detection: basis points (0-10000)
- No `f32`/`f64` in the consensus pipeline

### Tor Privacy
- No IP addresses exposed — only `.onion`
- SOCKS5 proxy prevents DNS and IP leaks
- Each validator is a distinct hidden service

### Anti-Whale Mechanisms
- √Stake quadratic voting limits whale influence
- Dynamic fee scaling increases costs during congestion
- Burn rate limits per address prevent rapid accumulation

## 9. Conclusion

Unauthority (LOS) combines post-quantum cryptography, Tor-native networking, DAG structure, and aBFT consensus to create a blockchain that is genuinely decentralized, private, and resistant to both classical and quantum adversaries. The fixed supply and Proof-of-Burn distribution ensure fair token allocation without centralized gatekeeping.
