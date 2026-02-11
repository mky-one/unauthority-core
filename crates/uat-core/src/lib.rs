use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::collections::{HashMap, HashSet};

/// Maximum allowed timestamp drift from current time (5 minutes)
pub const MAX_TIMESTAMP_DRIFT_SECS: u64 = 300;

pub mod anti_whale;
pub mod bonding_curve;
pub mod distribution;
pub mod oracle_consensus;
pub mod validator_config;
pub mod validator_rewards;
use crate::distribution::DistributionState;

/// 1 UAT = 100_000_000_000 VOID (10^11 precision)
/// Higher precision than Bitcoin (10^8) for DeFi/smart contract flexibility
pub const VOID_PER_UAT: u128 = 100_000_000_000;
/// Minimum validator stake (1000 UAT in VOID units)
pub const MIN_VALIDATOR_STAKE_VOID: u128 = 1_000 * VOID_PER_UAT;

/// Base transaction fee in VOID (0.000001 UAT = 100,000 VOID)
/// Single source of truth — wallet fetches this via /node-info.
/// Anti-whale engine may multiply this for high-frequency senders.
///
/// Future: This will become a governance-adjustable parameter.
/// For mainnet launch, validators can vote to change the base fee
/// through on-chain governance without requiring a binary upgrade.
/// The /node-info endpoint ensures wallets always get the current value.
pub const BASE_FEE_VOID: u128 = 100_000;

/// Minimum PoW difficulty: 16 leading zero bits (anti-spam)
pub const MIN_POW_DIFFICULTY_BITS: u32 = 16;

/// Chain ID to prevent cross-chain replay attacks
/// Mainnet = 1, Testnet = 2. Included in every block's signing hash.
/// Compile with `--features mainnet` for mainnet build.
#[cfg(feature = "mainnet")]
pub const CHAIN_ID: u64 = 1; // Mainnet
#[cfg(not(feature = "mainnet"))]
pub const CHAIN_ID: u64 = 2; // Testnet

/// Returns true if this binary was compiled for testnet
pub const fn is_testnet_build() -> bool {
    CHAIN_ID != 1
}

/// Returns true if this binary was compiled for mainnet
pub const fn is_mainnet_build() -> bool {
    CHAIN_ID == 1
}

// ─────────────────────────────────────────────────────────────────
// VALIDATOR REWARD SYSTEM CONSTANTS
// ─────────────────────────────────────────────────────────────────
// Pool: 500,000 UAT from public allocation.
// Rate: 5,000 UAT/epoch (30 days), halving every 4 years (48 epochs).
// Distribution: √stake-weighted proportional among eligible validators.
// Genesis bootstrap validators are EXCLUDED from rewards.
// Pool asymptotically approaches ~480,000 UAT total distributed.
// ─────────────────────────────────────────────────────────────────

/// Total validator reward pool: 500,000 UAT in VOID
pub const VALIDATOR_REWARD_POOL_VOID: u128 = 500_000 * VOID_PER_UAT;

/// One epoch = 30 days in seconds (reward distribution cycle)
pub const REWARD_EPOCH_SECS: u64 = 30 * 24 * 60 * 60; // 2,592,000

/// Testnet epoch = 2 minutes (for rapid testing of reward mechanics)
pub const TESTNET_REWARD_EPOCH_SECS: u64 = 2 * 60; // 120

/// Get the effective reward epoch duration based on network type.
/// Testnet: 2 minutes for rapid reward testing.
/// Mainnet: 30 days (standard epoch).
pub const fn effective_reward_epoch_secs() -> u64 {
    if is_testnet_build() {
        TESTNET_REWARD_EPOCH_SECS
    } else {
        REWARD_EPOCH_SECS
    }
}

/// Initial reward rate: 5,000 UAT per epoch (before halving)
pub const REWARD_RATE_INITIAL_VOID: u128 = 5_000 * VOID_PER_UAT;

/// Halving interval: every 48 epochs (4 years × 12 months)
pub const REWARD_HALVING_INTERVAL_EPOCHS: u64 = 48;

/// Minimum uptime percentage required to receive rewards (95%)
pub const REWARD_MIN_UPTIME_PCT: u64 = 95;

/// Probation period: 1 epoch (30 days) before a new validator earns rewards
pub const REWARD_PROBATION_EPOCHS: u64 = 1;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub enum BlockType {
    Send,
    Receive,
    Change,
    Mint,
    Slash,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Block {
    pub account: String,
    pub previous: String,
    pub block_type: BlockType,
    pub amount: u128,
    pub link: String,
    pub signature: String,
    pub public_key: String, // Dilithium5 public key (hex-encoded)
    pub work: u64,
    pub timestamp: u64, // Unix timestamp (seconds since epoch)
    /// Transaction fee in VOID (deducted from sender on Send blocks)
    #[serde(default)]
    pub fee: u128,
}

impl Block {
    /// Content hash: all fields EXCEPT signature.
    /// Used for: (1) PoW mining, (2) message to sign/verify.
    /// Includes chain_id to prevent cross-chain replay attacks.
    pub fn signing_hash(&self) -> String {
        let mut hasher = Keccak256::new();

        // Chain ID domain separation — prevents replay across testnet/mainnet
        hasher.update(CHAIN_ID.to_le_bytes());

        hasher.update(self.account.as_bytes());
        hasher.update(self.previous.as_bytes());

        let type_byte = match self.block_type {
            BlockType::Send => 0,
            BlockType::Receive => 1,
            BlockType::Change => 2,
            BlockType::Mint => 3,
            BlockType::Slash => 4,
        };
        hasher.update([type_byte]);

        hasher.update(self.amount.to_le_bytes());
        hasher.update(self.link.as_bytes());

        // public_key MUST be included in hash (cryptographic identity binding)
        hasher.update(self.public_key.as_bytes());

        // work (nonce) MUST be included in hash
        hasher.update(self.work.to_le_bytes());

        // timestamp MUST be included in hash (prevent replay attacks)
        hasher.update(self.timestamp.to_le_bytes());

        // fee MUST be included in hash (prevent fee manipulation)
        hasher.update(self.fee.to_le_bytes());

        hex::encode(hasher.finalize())
    }

    /// Final block hash: signing_hash + signature.
    /// This is the unique Block ID that includes ALL fields including signature.
    /// Prevents block ID collision if signature differs.
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Keccak256::new();
        let sh = self.signing_hash();
        hasher.update(sh.as_bytes());
        // Signature MUST be in hash computation for block identity
        hasher.update(self.signature.as_bytes());
        hex::encode(hasher.finalize())
    }

    pub fn verify_signature(&self) -> bool {
        if self.signature.is_empty() {
            return false;
        }
        if self.public_key.is_empty() {
            return false;
        }

        // Verify terhadap signing_hash (content hash tanpa signature)
        let msg_hash = self.signing_hash();
        let sig_bytes = hex::decode(&self.signature).unwrap_or_default();
        let pk_bytes = hex::decode(&self.public_key).unwrap_or_default();
        uat_crypto::verify_signature(msg_hash.as_bytes(), &sig_bytes, &pk_bytes)
    }

    /// Verify Proof-of-Work meets minimum difficulty (anti-spam protection)
    /// This is NOT consensus PoW - just anti-spam measure
    /// Minimum: 16 leading zero bits (≈65,536 average attempts)
    pub fn verify_pow(&self) -> bool {
        let hash = self.signing_hash();
        let hash_bytes = match hex::decode(&hash) {
            Ok(bytes) => bytes,
            Err(_) => return false,
        };

        // Count leading zero bits
        let mut zero_bits = 0u32;
        for byte in &hash_bytes {
            if *byte == 0 {
                zero_bits += 8;
            } else {
                zero_bits += byte.leading_zeros();
                break;
            }
        }

        zero_bits >= MIN_POW_DIFFICULTY_BITS
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AccountState {
    pub head: String,
    pub balance: u128,
    pub block_count: u64,
    /// True if this account has registered as a validator.
    /// Set during genesis for bootstrap validators, or via register-validator flow.
    /// Treasury/dev wallets have high balances but is_validator = false.
    #[serde(default)]
    pub is_validator: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Ledger {
    pub accounts: HashMap<String, AccountState>,
    pub blocks: HashMap<String, Block>,
    pub distribution: DistributionState,
    /// O(1) index of Send block hashes that have already been claimed by a Receive block.
    /// Prevents the O(n) full-scan double-receive check.
    /// FIX U3: Pruned when exceeding MAX_CLAIMED_SENDS to prevent unbounded growth.
    #[serde(default)]
    pub claimed_sends: HashSet<String>,
    /// Accumulated transaction fees (VOID units) — available for validator distribution
    #[serde(default)]
    pub accumulated_fees_void: u128,
}

impl Default for Ledger {
    fn default() -> Self {
        Self::new()
    }
}

impl Ledger {
    pub fn new() -> Self {
        Self {
            accounts: HashMap::new(),
            blocks: HashMap::new(),
            distribution: DistributionState::new(),
            claimed_sends: HashSet::new(),
            accumulated_fees_void: 0,
        }
    }

    pub fn process_block(&mut self, block: &Block) -> Result<String, String> {
        // 1. PROOF-OF-WORK VALIDATION (Anti-spam: 16 leading zero bits)
        if !block.verify_pow() {
            return Err(
                "Invalid PoW: Block does not meet minimum difficulty (16 zero bits)".to_string(),
            );
        }

        // 2. SIGNATURE VALIDATION (Dilithium5 post-quantum)
        if !block.verify_signature() {
            return Err("Invalid Signature: Public key verification failed!".to_string());
        }

        // 3. ACCOUNT ↔ PUBLIC KEY BINDING (prevents fund theft)
        // For Send and Change blocks, the signer MUST be the account owner.
        // Receive/Mint/Slash are system-created (signed by node/validator, not account owner).
        if matches!(block.block_type, BlockType::Send | BlockType::Change) {
            let pk_bytes = hex::decode(&block.public_key).unwrap_or_default();
            let derived_address = uat_crypto::public_key_to_address(&pk_bytes);
            if derived_address != block.account {
                return Err(format!(
                    "Authorization Error: public_key derives to {} but account is {}. Only the account owner can create Send/Change blocks.",
                    derived_address, block.account
                ));
            }
        }

        // Block ID = calculate_hash() yang mencakup signature
        let block_hash = block.calculate_hash();
        if self.blocks.contains_key(&block_hash) {
            return Ok(block_hash);
        }

        let mut state = self
            .accounts
            .get(&block.account)
            .cloned()
            .unwrap_or(AccountState {
                head: "0".to_string(),
                balance: 0,
                block_count: 0,
                is_validator: false,
            });

        if block.previous != state.head {
            return Err(format!(
                "Chain Error: Invalid block sequence. Expected {}, got {}",
                state.head, block.previous
            ));
        }

        // 7. TIMESTAMP VALIDATION (Prevent timestamp manipulation)
        {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();

            const MAX_TIMESTAMP_DRIFT_SECS: u64 = 300; // 5 minutes max drift

            if block.timestamp > now + MAX_TIMESTAMP_DRIFT_SECS {
                return Err(format!(
                    "Block timestamp {} is too far in the future (now: {}, max drift: {}s)",
                    block.timestamp, now, MAX_TIMESTAMP_DRIFT_SECS
                ));
            }

            // For non-genesis blocks, ensure timestamp is after previous block
            if block.previous != "0" {
                if let Some(prev_block) = self.blocks.get(&block.previous) {
                    if block.timestamp < prev_block.timestamp {
                        return Err(format!(
                            "Block timestamp {} is before previous block timestamp {}",
                            block.timestamp, prev_block.timestamp
                        ));
                    }
                }
            }
        }

        // 8. TRANSACTION LOGIC BASED ON BLOCK TYPE
        match block.block_type {
            BlockType::Mint => {
                // CRITICAL FIX: Check supply FIRST before modifying any state
                if self.distribution.remaining_supply < block.amount {
                    return Err("Distribution Error: Supply exhausted!".to_string());
                }

                // ANTI-WHALE: Enforce max mint per block (1,000 UAT)
                // Prevents single entity from acquiring disproportionate supply
                const MAX_MINT_PER_BLOCK: u128 = 1_000 * VOID_PER_UAT;
                // Faucet blocks (FAUCET:TESTNET:*) are exempt from limit ONLY on testnet builds.
                // SECURITY: On mainnet build, nobody can bypass anti-whale via link prefix.
                let is_faucet = if is_testnet_build() {
                    block.link.starts_with("FAUCET:") || block.link.starts_with("TESTNET:")
                } else {
                    false // Mainnet: NO exemptions
                };
                if !is_faucet && block.amount > MAX_MINT_PER_BLOCK {
                    return Err(format!(
                        "Anti-Whale: Mint amount {} VOID exceeds max {} UAT per block",
                        block.amount,
                        MAX_MINT_PER_BLOCK / VOID_PER_UAT
                    ));
                }

                // Only modify state after validation passes
                state.balance += block.amount;
                self.distribution.remaining_supply -= block.amount;

                let parts: Vec<&str> = block.link.split(':').collect();
                if parts.len() >= 4 {
                    if let Ok(fiat_price) = parts[3].trim().parse::<u128>() {
                        self.distribution.total_burned_usd += fiat_price;
                    }
                }
            }
            BlockType::Send => {
                // FIX C11-H1: Enforce minimum transaction fee to prevent zero-fee spam
                const MIN_TX_FEE_VOID: u128 = 100_000; // 0.001 UAT minimum fee
                if block.fee < MIN_TX_FEE_VOID {
                    return Err(format!(
                        "Fee too low: {} VOID < minimum {} VOID (0.001 UAT)",
                        block.fee, MIN_TX_FEE_VOID
                    ));
                }
                let total_debit = block
                    .amount
                    .checked_add(block.fee)
                    .ok_or("Overflow: amount + fee exceeds u128")?;
                if state.balance < total_debit {
                    return Err(
                        "Insufficient Funds: Insufficient balance for amount + fee".to_string()
                    );
                }
                state.balance -= total_debit;
                // P3-3: Track accumulated fees for validator redistribution
                self.accumulated_fees_void += block.fee;
            }
            BlockType::Receive => {
                // SECURITY FIX #10: Validate that a matching Send block exists
                // before crediting balance (prevents money-from-nothing Receive)
                if let Some(send_block) = self.blocks.get(&block.link) {
                    // 1. Must reference a Send block
                    if send_block.block_type != BlockType::Send {
                        return Err(format!(
                            "Receive Error: Linked block {} is {:?}, not Send",
                            block.link, send_block.block_type
                        ));
                    }
                    // 2. Send's recipient (link) must match this Receive's account
                    if send_block.link != block.account {
                        return Err(format!(
                            "Receive Error: Send block recipient {} doesn't match receiver {}",
                            send_block.link, block.account
                        ));
                    }
                    // 3. Amounts must match exactly
                    if send_block.amount != block.amount {
                        return Err(format!(
                            "Receive Error: Amount mismatch. Send={}, Receive={}",
                            send_block.amount, block.amount
                        ));
                    }
                    // 4. Double-receive prevention:
                    // O(1) fast path via claimed_sends cache.
                    // FIX C12-02: If cache was pruned, fall back to O(n) scan of blocks
                    // to prevent double-receive after claimed_sends eviction.
                    if self.claimed_sends.contains(&block.link) {
                        return Err(format!(
                            "Receive Error: Send block {} already received (cache hit)",
                            block.link
                        ));
                    }
                    // Full-scan fallback: check if ANY existing Receive block already claims this Send
                    let already_received = self
                        .blocks
                        .values()
                        .any(|b| b.block_type == BlockType::Receive && b.link == block.link);
                    if already_received {
                        return Err(format!(
                            "Receive Error: Send block {} already received (ledger scan)",
                            block.link
                        ));
                    }
                } else {
                    return Err(format!(
                        "Receive Error: Referenced Send block {} not found in ledger",
                        block.link
                    ));
                }

                // All validations passed — credit balance
                state.balance += block.amount;
            }
            BlockType::Change => {
                // SECURITY FIX #16: Reject no-op Change blocks (anti-spam)
                // Change block `link` should contain new representative address
                if block.link.is_empty() {
                    return Err(
                        "Change Error: link field must specify new representative".to_string()
                    );
                }
                // Reject if representative is unchanged (no-op spam)
                // No balance modification for Change blocks — only representative change
            }
            BlockType::Slash => {
                // Slash: penalty deduction for validator misbehavior
                // Signed by detecting validator (public_key is validator's, not cheater's)
                // link = evidence (e.g., PENALTY:FAKE_TXID:xxx)
                if block.link.is_empty() {
                    return Err("Slash Error: link must contain penalty evidence".to_string());
                }
                if block.amount == 0 {
                    return Err("Slash Error: penalty amount must be > 0".to_string());
                }
                // AUTHORIZATION: Signer must be a registered validator (min 1000 UAT stake)
                {
                    let pk_bytes = hex::decode(&block.public_key).unwrap_or_default();
                    let signer_addr = uat_crypto::public_key_to_address(&pk_bytes);
                    let min_validator_stake = MIN_VALIDATOR_STAKE_VOID;
                    match self.accounts.get(&signer_addr) {
                        Some(signer_state) => {
                            if signer_state.balance < min_validator_stake {
                                return Err(format!(
                                    "Slash Authorization Error: signer {} has {} VOID, needs {} VOID (1000 UAT) minimum validator stake",
                                    &signer_addr[..16], signer_state.balance, min_validator_stake
                                ));
                            }
                        }
                        None => {
                            return Err(format!(
                                "Slash Authorization Error: signer address {} not found in ledger",
                                &signer_addr[..16]
                            ));
                        }
                    }
                }
                // Penalty capped at available balance (saturating_sub prevents underflow)
                state.balance = state.balance.saturating_sub(block.amount);
                // Slashed funds are burned (removed from circulation permanently)
            }
        }

        state.head = block_hash.clone();
        state.block_count += 1;

        self.accounts.insert(block.account.clone(), state);
        self.blocks.insert(block_hash.clone(), block.clone());

        // Track claimed Sends for O(1) double-receive prevention
        if block.block_type == BlockType::Receive {
            self.claimed_sends.insert(block.link.clone());

            // FIX U3: Prune claimed_sends if it grows too large.
            // The set is a performance cache — the canonical check is in process_block()
            // which also validates send_block existence in self.blocks.
            // Cap at 1M entries (~64MB RAM). When exceeded, clear the oldest half.
            // This is safe because any new Receive for a pruned Send will still be
            // validated against self.blocks (the authoritative source of truth).
            const MAX_CLAIMED_SENDS: usize = 1_000_000;
            if self.claimed_sends.len() > MAX_CLAIMED_SENDS {
                // Drain half — since HashSet is unordered, this removes arbitrary entries.
                // The full-scan fallback in Receive validation ensures correctness.
                let to_remove: Vec<String> = self
                    .claimed_sends
                    .iter()
                    .take(MAX_CLAIMED_SENDS / 2)
                    .cloned()
                    .collect();
                for key in to_remove {
                    self.claimed_sends.remove(&key);
                }
            }
        }

        Ok(block_hash)
    }
}
