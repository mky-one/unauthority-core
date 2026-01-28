use pqcrypto_dilithium::dilithium5::{
    keypair, 
    detached_sign, 
    verify_detached_signature,
    PublicKey as DilithiumPublicKey,
    SecretKey as DilithiumSecretKey,
};
use pqcrypto_traits::sign::{PublicKey, SecretKey, DetachedSignature};
use serde::{Serialize, Deserialize};

#[derive(Debug)]
pub enum CryptoError {
    InvalidKey,
    VerificationFailed,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct KeyPair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
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

/// Memverifikasi tanda tangan
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
}