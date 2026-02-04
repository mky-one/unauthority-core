use serde::{Deserialize, Serialize};
use warp::Filter;

#[derive(Serialize, Deserialize)]
pub struct GenerateKeysResponse {
    pub seed_phrase: String,
    pub private_key: String,
    pub public_key: String,
    pub address: String,
}

#[derive(Deserialize)]
pub struct ImportPrivateKeyRequest {
    pub private_key: String,
}

#[derive(Deserialize)]
pub struct ImportSeedPhraseRequest {
    pub seed_phrase: String,
}

#[derive(Deserialize)]
pub struct StartValidatorRequest {
    pub public_key: String,
    pub encrypted_private_key: String,
    pub password_hash: String,
    pub rest_port: Option<u16>,
}

#[derive(Serialize)]
pub struct ValidatorStatusResponse {
    pub is_running: bool,
    pub address: Option<String>,
    pub uptime_seconds: u64,
    pub connected_peers: usize,
}

/// Generate new validator keys with BIP39 seed phrase
pub fn generate_validator_keys() -> Result<GenerateKeysResponse, String> {
    // Generate 24-word BIP39 seed phrase
    let mnemonic = bip39::Mnemonic::generate(24)
        .map_err(|e| format!("Failed to generate mnemonic: {}", e))?;
    
    let seed_phrase = mnemonic.to_string();
    
    // Derive keypair from seed
    let seed = mnemonic.to_seed("");
    let keypair = uat_crypto::generate_keypair_from_seed(&seed);
    
    let private_key = hex::encode(&keypair.secret_key);
    let public_key = hex::encode(&keypair.public_key);
    let address = format!("uat_{}", &public_key[..12]); // Short address format
    
    Ok(GenerateKeysResponse {
        seed_phrase,
        private_key,
        public_key,
        address,
    })
}

/// Import validator keys from private key
pub fn import_private_key(private_key: &str) -> Result<GenerateKeysResponse, String> {
    // Decode private key
    let secret_bytes = hex::decode(private_key)
        .map_err(|_| "Invalid private key hex format".to_string())?;
    
    if secret_bytes.len() != 32 {
        return Err("Private key must be 32 bytes".to_string());
    }
    
    // Derive public key
    let keypair = uat_crypto::keypair_from_secret(&secret_bytes);
    let public_key = hex::encode(&keypair.public_key);
    let address = format!("uat_{}", &public_key[..12]);
    
    Ok(GenerateKeysResponse {
        seed_phrase: "⚠️ IMPORTED KEY - NO SEED PHRASE AVAILABLE".to_string(),
        private_key: private_key.to_string(),
        public_key,
        address,
    })
}

/// Import validator keys from BIP39 seed phrase
pub fn import_seed_phrase(seed_phrase: &str) -> Result<GenerateKeysResponse, String> {
    // Parse and validate seed phrase
    let mnemonic = bip39::Mnemonic::parse(seed_phrase)
        .map_err(|e| format!("Invalid seed phrase: {}", e))?;
    
    // Derive keypair
    let seed = mnemonic.to_seed("");
    let keypair = uat_crypto::generate_keypair_from_seed(&seed);
    
    let private_key = hex::encode(&keypair.secret_key);
    let public_key = hex::encode(&keypair.public_key);
    let address = format!("uat_{}", &public_key[..12]);
    
    Ok(GenerateKeysResponse {
        seed_phrase: seed_phrase.to_string(),
        private_key,
        public_key,
        address,
    })
}

/// Warp filter for validator key management routes
pub fn validator_routes() -> impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone {
    let generate = warp::path!("validator" / "generate")
        .and(warp::get())
        .map(|| {
            match generate_validator_keys() {
                Ok(keys) => warp::reply::json(&keys),
                Err(e) => warp::reply::json(&serde_json::json!({
                    "error": e
                })),
            }
        });
    
    let import_key = warp::path!("validator" / "import")
        .and(warp::post())
        .and(warp::body::json())
        .map(|req: ImportPrivateKeyRequest| {
            match import_private_key(&req.private_key) {
                Ok(keys) => warp::reply::json(&keys),
                Err(e) => warp::reply::json(&serde_json::json!({
                    "error": e
                })),
            }
        });
    
    let import_seed = warp::path!("validator" / "import-seed")
        .and(warp::post())
        .and(warp::body::json())
        .map(|req: ImportSeedPhraseRequest| {
            match import_seed_phrase(&req.seed_phrase) {
                Ok(keys) => warp::reply::json(&keys),
                Err(e) => warp::reply::json(&serde_json::json!({
                    "error": e
                })),
            }
        });
    
    generate.or(import_key).or(import_seed)
}
