use bip39::{Language, Mnemonic};
use sha3::{Digest, Keccak256};
use hex;
use ed25519_dalek::{SigningKey, VerifyingKey};
use rand::rngs::OsRng;

/// HD Wallet implementation (BIP39-based, simplified)
pub struct HdWallet {
    /// Mnemonic seed phrase
    mnemonic: Mnemonic,
    /// Seed bytes derived from mnemonic
    seed: Vec<u8>,
}

impl HdWallet {
    /// Create new HD wallet from mnemonic
    pub fn from_mnemonic(mnemonic_str: &str) -> Result<Self, String> {
        let mnemonic = Mnemonic::from_phrase(mnemonic_str, Language::English)
            .map_err(|e| format!("Invalid mnemonic: {}", e))?;

        let seed = mnemonic.to_seed("");

        Ok(Self {
            mnemonic,
            seed,
        })
    }

    /// Generate new HD wallet with random mnemonic
    pub fn generate(word_count: usize) -> Result<Self, String> {
        let word_count = match word_count {
            12 | 15 | 18 | 21 | 24 => word_count,
            _ => return Err("Word count must be 12, 15, 18, 21, or 24".to_string()),
        };

        let mnemonic = Mnemonic::generate(word_count)
            .map_err(|e| format!("Failed to generate mnemonic: {}", e))?;

        Self::from_mnemonic(&mnemonic.phrase())
    }

    /// Derive key at specific index (simplified BIP44-like derivation)
    pub fn derive_key(&self, account: u32, change: u32, index: u32) -> Result<(Vec<u8>, Vec<u8>, String), String> {
        // Derive child seed by hashing master seed with derivation path
        let mut hasher = Keccak256::new();
        hasher.update(&self.seed);
        hasher.update(b"m/44'/21936236'/");
        hasher.update(account.to_le_bytes());
        hasher.update(b"'/");
        hasher.update(change.to_le_bytes());
        hasher.update(b"/");
        hasher.update(index.to_le_bytes());
        
        let child_seed = hasher.finalize();
        
        // Use first 32 bytes as Ed25519 private key
        let mut secret_key_bytes = [0u8; 32];
        secret_key_bytes.copy_from_slice(&child_seed[0..32]);
        
        let signing_key = SigningKey::from_bytes(&secret_key_bytes);
        let verifying_key = signing_key.verifying_key();
        
        let secret_key = signing_key.to_bytes().to_vec();
        let public_key = verifying_key.to_bytes().to_vec();
        
        // Generate UAT address from public key
        let address = Self::public_key_to_address(&public_key);

        Ok((secret_key, public_key, address))
    }

    /// Convert public key to UAT address
    fn public_key_to_address(public_key: &[u8]) -> String {
        let mut hasher = Keccak256::new();
        hasher.update(public_key);
        let hash = hasher.finalize();
        format!("UAT{}", hex::encode(&hash[..20]))
    }

    /// Get mnemonic phrase
    pub fn mnemonic(&self) -> &str {
        self.mnemonic.phrase()
    }

    /// Derive multiple addresses (for account discovery)
    pub fn derive_addresses(&self, account: u32, count: u32) -> Result<Vec<(u32, String)>, String> {
        let mut addresses = Vec::new();
        for index in 0..count {
            let (_, _, address) = self.derive_key(account, 0, index)?;
            addresses.push((index, address));
        }
        Ok(addresses)
    }

    /// Check if address belongs to this wallet
    pub fn owns_address(&self, address: &str, max_search: u32) -> Result<Option<u32>, String> {
        for index in 0..max_search {
            let (_, _, derived_address) = self.derive_key(0, 0, index)?;
            if derived_address == address {
                return Ok(Some(index));
            }
        }
        Ok(None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hd_wallet_generation() {
        let wallet = HdWallet::generate(12).unwrap();
        assert!(!wallet.mnemonic().is_empty());
    }

    #[test]
    fn test_hd_wallet_from_mnemonic() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let wallet = HdWallet::from_mnemonic(mnemonic).unwrap();
        assert_eq!(wallet.mnemonic(), mnemonic);
    }

    #[test]
    fn test_derive_key() {
        let wallet = HdWallet::generate(12).unwrap();
        let (secret, public, address) = wallet.derive_key(0, 0, 0).unwrap();

        assert!(!secret.is_empty());
        assert!(!public.is_empty());
        assert!(address.starts_with("UAT"));
    }

    #[test]
    fn test_derive_multiple_addresses() {
        let wallet = HdWallet::generate(12).unwrap();
        let addresses = wallet.derive_addresses(0, 5).unwrap();

        assert_eq!(addresses.len(), 5);
        for (index, address) in addresses {
            assert!(address.starts_with("UAT"));
            assert!(index < 5);
        }
    }

    #[test]
    fn test_deterministic_derivation() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let wallet1 = HdWallet::from_mnemonic(mnemonic).unwrap();
        let wallet2 = HdWallet::from_mnemonic(mnemonic).unwrap();

        let (_, _, addr1) = wallet1.derive_key(0, 0, 0).unwrap();
        let (_, _, addr2) = wallet2.derive_key(0, 0, 0).unwrap();

        assert_eq!(addr1, addr2);
    }

    #[test]
    fn test_owns_address() {
        let wallet = HdWallet::generate(12).unwrap();
        let (_, _, address) = wallet.derive_key(0, 0, 5).unwrap();

        let index = wallet.owns_address(&address, 10).unwrap();
        assert_eq!(index, Some(5));
    }
}
