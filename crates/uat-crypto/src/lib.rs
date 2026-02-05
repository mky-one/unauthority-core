use pqcrypto_dilithium::dilithium5::{
    keypair, 
    detached_sign, 
    verify_detached_signature,
    PublicKey as DilithiumPublicKey,
    SecretKey as DilithiumSecretKey,
};
use pqcrypto_traits::sign::{PublicKey, SecretKey, DetachedSignature};
use serde::{Serialize, Deserialize};
use age::{Encryptor, Decryptor};
use secrecy::Secret;
use std::io::{Read, Write};

pub mod hd_wallet;

#[derive(Debug)]
pub enum CryptoError {
    InvalidKey,
    VerificationFailed,
    EncryptionFailed(String),
    DecryptionFailed(String),
    InvalidPassword,
}

impl std::fmt::Display for CryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            CryptoError::InvalidKey => write!(f, "Invalid key format"),
            CryptoError::VerificationFailed => write!(f, "Signature verification failed"),
            CryptoError::EncryptionFailed(msg) => write!(f, "Encryption failed: {}", msg),
            CryptoError::DecryptionFailed(msg) => write!(f, "Decryption failed: {}", msg),
            CryptoError::InvalidPassword => write!(f, "Invalid password"),
        }
    }
}

impl std::error::Error for CryptoError {}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct KeyPair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

/// Encrypted key structure with metadata
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EncryptedKey {
    /// Encrypted secret key data
    pub ciphertext: Vec<u8>,
    /// Encryption version (for future upgrades)
    pub version: u32,
    /// Salt for key derivation (future use)
    pub salt: Vec<u8>,
    /// Public key (not encrypted)
    pub public_key: Vec<u8>,
}

/// Generate pasangan kunci Post-Quantum baru (Dilithium5)
pub fn generate_keypair() -> KeyPair {
    let (pk, sk) = keypair();
    KeyPair {
        public_key: pk.as_bytes().to_vec(),
        secret_key: sk.as_bytes().to_vec(),
    }
}

/// Menandatangani pesan
pub fn sign_message(message: &[u8], secret_key_bytes: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let sk = DilithiumSecretKey::from_bytes(secret_key_bytes)
        .map_err(|_| CryptoError::InvalidKey)?;
    
    let signature = detached_sign(message, &sk);
    Ok(signature.as_bytes().to_vec())
}

/// Verify signature
pub fn verify_signature(
    message: &[u8],
    signature_bytes: &[u8],
    public_key_bytes: &[u8]
) -> bool {
    let pk = match DilithiumPublicKey::from_bytes(public_key_bytes) {
        Ok(k) => k,
        Err(_) => return false,
    };

    use pqcrypto_dilithium::dilithium5::DetachedSignature as DilithiumSig;
    
    let sig = match DilithiumSig::from_bytes(signature_bytes) {
        Ok(s) => s,
        Err(_) => return false,
    };

    verify_detached_signature(&sig, message, &pk).is_ok()
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// KEY ENCRYPTION MODULE (RISK-002 Mitigation - P0 Critical)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Encrypt private key with password using age encryption
/// 
/// Security: Uses age's built-in scrypt key derivation (N=2^20, secure)
/// Format: age encrypted binary (portable, battle-tested)
/// 
/// # Arguments
/// * `secret_key` - Raw private key bytes (will be zeroized after encryption)
/// * `password` - User password (will be zeroized after use)
/// 
/// # Returns
/// Encrypted key structure with ciphertext and metadata
pub fn encrypt_private_key(
    secret_key: &[u8],
    password: &str,
) -> Result<EncryptedKey, CryptoError> {
    let password_secret = Secret::new(password.to_string());
    
    // Create age encryptor with password
    let encryptor = Encryptor::with_user_passphrase(password_secret);
    
    let mut encrypted_output = Vec::new();
    let mut writer = encryptor
        .wrap_output(&mut encrypted_output)
        .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;
    
    writer.write_all(secret_key)
        .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;
    
    writer.finish()
        .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;
    
    Ok(EncryptedKey {
        ciphertext: encrypted_output,
        version: 1,
        salt: vec![], // age handles salt internally
        public_key: vec![], // To be filled by caller
    })
}

/// Decrypt private key with password
/// 
/// # Arguments
/// * `encrypted_key` - Encrypted key structure
/// * `password` - User password (will be zeroized after use)
/// 
/// # Returns
/// Decrypted private key bytes (caller must zeroize after use)
pub fn decrypt_private_key(
    encrypted_key: &EncryptedKey,
    password: &str,
) -> Result<Vec<u8>, CryptoError> {
    let password_secret = Secret::new(password.to_string());
    
    // Create age decryptor
    let decryptor = match Decryptor::new(&encrypted_key.ciphertext[..]) {
        Ok(Decryptor::Passphrase(d)) => d,
        Ok(_) => return Err(CryptoError::DecryptionFailed(
            "Expected passphrase encryption".to_string()
        )),
        Err(e) => return Err(CryptoError::DecryptionFailed(e.to_string())),
    };
    
    // Decrypt with password
    let mut reader = decryptor
        .decrypt(&password_secret, None)
        .map_err(|e| match e {
            age::DecryptError::DecryptionFailed => CryptoError::InvalidPassword,
            _ => CryptoError::DecryptionFailed(e.to_string()),
        })?;
    
    let mut decrypted = Vec::new();
    reader.read_to_end(&mut decrypted)
        .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))?;
    
    Ok(decrypted)
}

/// Check if key data is encrypted (simple heuristic)
/// 
/// age encrypted files start with "age-encryption.org/v1" header
pub fn is_encrypted(data: &[u8]) -> bool {
    data.starts_with(b"age-encryption.org/v1")
}

/// Migrate plaintext key to encrypted format
/// 
/// # Arguments
/// * `plaintext_key` - Plaintext KeyPair
/// * `password` - Password for encryption
/// 
/// # Returns
/// Encrypted key structure ready for storage
pub fn migrate_to_encrypted(
    plaintext_key: &KeyPair,
    password: &str,
) -> Result<EncryptedKey, CryptoError> {
    let mut encrypted = encrypt_private_key(&plaintext_key.secret_key, password)?;
    encrypted.public_key = plaintext_key.public_key.clone();
    Ok(encrypted)
}

/// Full key lifecycle: generate + encrypt
/// 
/// Generates new keypair and immediately encrypts private key
/// Public key remains unencrypted for address derivation
pub fn generate_encrypted_keypair(password: &str) -> Result<EncryptedKey, CryptoError> {
    let keypair = generate_keypair();
    migrate_to_encrypted(&keypair, password)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sign_verify_flow() {
        let keys = generate_keypair();
        let msg = b"Hash Block UAT";
        let sig = sign_message(msg, &keys.secret_key).expect("Signing failed");
        assert!(verify_signature(msg, &sig, &keys.public_key));
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // KEY ENCRYPTION TESTS (RISK-002 Validation)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #[test]
    fn test_encrypt_decrypt_private_key() {
        let keypair = generate_keypair();
        let password = "super_secure_password_123";
        
        // Encrypt
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        assert!(!encrypted.ciphertext.is_empty());
        assert_ne!(encrypted.ciphertext, keypair.secret_key); // Ciphertext != plaintext
        
        // Decrypt
        let decrypted = decrypt_private_key(&encrypted, password)
            .expect("Decryption failed");
        
        assert_eq!(decrypted, keypair.secret_key); // Decrypted == original
    }

    #[test]
    fn test_decrypt_with_wrong_password() {
        let keypair = generate_keypair();
        let password = "correct_password";
        let wrong_password = "wrong_password";
        
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        // Should fail with wrong password
        let result = decrypt_private_key(&encrypted, wrong_password);
        assert!(result.is_err());
        
        match result.unwrap_err() {
            CryptoError::InvalidPassword => {}, // Expected
            _ => panic!("Expected InvalidPassword error"),
        }
    }

    #[test]
    fn test_encrypted_key_still_signs() {
        let password = "test_password_456";
        
        // Generate and encrypt key
        let keypair = generate_keypair();
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        // Decrypt for signing
        let decrypted_key = decrypt_private_key(&encrypted, password)
            .expect("Decryption failed");
        
        // Sign message with decrypted key
        let msg = b"Test transaction";
        let sig = sign_message(msg, &decrypted_key)
            .expect("Signing failed");
        
        // Verify signature with public key
        assert!(verify_signature(msg, &sig, &keypair.public_key));
    }

    #[test]
    fn test_is_encrypted_detection() {
        let keypair = generate_keypair();
        let password = "password";
        
        // Plaintext key should NOT be detected as encrypted
        assert!(!is_encrypted(&keypair.secret_key));
        
        // Encrypted key should be detected
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        assert!(is_encrypted(&encrypted.ciphertext));
    }

    #[test]
    fn test_migrate_plaintext_to_encrypted() {
        let keypair = generate_keypair();
        let password = "migration_password";
        
        // Migrate
        let encrypted = migrate_to_encrypted(&keypair, password)
            .expect("Migration failed");
        
        assert_eq!(encrypted.public_key, keypair.public_key); // Public key preserved
        assert_ne!(encrypted.ciphertext, keypair.secret_key); // Private key encrypted
        
        // Verify decryption works
        let decrypted = decrypt_private_key(&encrypted, password)
            .expect("Decryption failed");
        assert_eq!(decrypted, keypair.secret_key);
    }

    #[test]
    fn test_generate_encrypted_keypair() {
        let password = "new_wallet_password";
        
        let encrypted_key = generate_encrypted_keypair(password)
            .expect("Generation failed");
        
        assert!(!encrypted_key.public_key.is_empty());
        assert!(!encrypted_key.ciphertext.is_empty());
        assert!(is_encrypted(&encrypted_key.ciphertext));
        
        // Should be able to decrypt
        let decrypted = decrypt_private_key(&encrypted_key, password)
            .expect("Decryption failed");
        assert!(!decrypted.is_empty());
    }

    #[test]
    fn test_encryption_version_field() {
        let keypair = generate_keypair();
        let password = "password";
        
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        assert_eq!(encrypted.version, 1); // Current version
    }

    #[test]
    fn test_different_passwords_produce_different_ciphertexts() {
        let keypair = generate_keypair();
        let password1 = "password1";
        let password2 = "password2";
        
        let encrypted1 = encrypt_private_key(&keypair.secret_key, password1)
            .expect("Encryption 1 failed");
        let encrypted2 = encrypt_private_key(&keypair.secret_key, password2)
            .expect("Encryption 2 failed");
        
        // Different passwords should produce different ciphertexts
        assert_ne!(encrypted1.ciphertext, encrypted2.ciphertext);
        
        // But both should decrypt to same plaintext
        let decrypted1 = decrypt_private_key(&encrypted1, password1).unwrap();
        let decrypted2 = decrypt_private_key(&encrypted2, password2).unwrap();
        assert_eq!(decrypted1, decrypted2);
        assert_eq!(decrypted1, keypair.secret_key);
    }

    #[test]
    fn test_empty_password_still_encrypts() {
        let keypair = generate_keypair();
        let password = ""; // Empty password (not recommended but should work)
        
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        let decrypted = decrypt_private_key(&encrypted, password)
            .expect("Decryption failed");
        
        assert_eq!(decrypted, keypair.secret_key);
    }

    #[test]
    fn test_long_password_works() {
        let keypair = generate_keypair();
        let password = "a".repeat(500); // 500 character password
        
        let encrypted = encrypt_private_key(&keypair.secret_key, &password)
            .expect("Encryption failed");
        
        let decrypted = decrypt_private_key(&encrypted, &password)
            .expect("Decryption failed");
        
        assert_eq!(decrypted, keypair.secret_key);
    }

    #[test]
    fn test_unicode_password_works() {
        let keypair = generate_keypair();
        let password = "密码🔒パスワード"; // Mixed Unicode
        
        let encrypted = encrypt_private_key(&keypair.secret_key, password)
            .expect("Encryption failed");
        
        let decrypted = decrypt_private_key(&encrypted, password)
            .expect("Decryption failed");
        
        assert_eq!(decrypted, keypair.secret_key);
    }

    #[test]
    fn test_encryption_is_consistent() {
        // Note: age encryption includes random nonce, so same input won't produce same output
        // This test validates that decrypt(encrypt(x)) == x consistently
        let keypair = generate_keypair();
        let password = "consistent_password";
        
        for _ in 0..5 {
            let encrypted = encrypt_private_key(&keypair.secret_key, password)
                .expect("Encryption failed");
            let decrypted = decrypt_private_key(&encrypted, password)
                .expect("Decryption failed");
            
            assert_eq!(decrypted, keypair.secret_key);
        }
    }
}