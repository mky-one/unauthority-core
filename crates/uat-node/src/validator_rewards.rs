// Validator rewards calculation module
// Distributes transaction fees to validators who finalize blocks

/// Calculate validator reward from a finalized Send block's fee.
/// Validators who participate in consensus for a block share its fee.
///
/// - `block_fee_void`: The fee (in VOID) attached to the Send block.
/// - `validator_count`: Number of validators who confirmed this block.
///
/// Returns the per-validator reward in VOID.
pub fn calculate_validator_reward(block_fee_void: u128, validator_count: u32) -> u128 {
    if validator_count == 0 || block_fee_void == 0 {
        return 0;
    }
    block_fee_void / (validator_count as u128)
}
