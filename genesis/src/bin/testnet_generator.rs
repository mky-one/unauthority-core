/// UNAUTHORITY Testnet Genesis Generator v8.0
/// Uses CRYSTALS-Dilithium5 (Post-Quantum) via uat_crypto
///
/// DETERMINISTIC: Keypairs ARE derived from BIP39 seeds via
/// domain-separated SHA-256 → ChaCha20 DRBG → pqcrypto_dilithium::keypair()
/// Same seed phrase → same keypair → same address → importable in wallet!
///
/// This generator runs ONCE to produce testnet genesis. The output JSON
/// is committed and shared with all testnet participants.
///
/// SECURITY: This binary is for TESTNET ONLY. Mainnet genesis must be
/// generated offline with fresh random keys, NEVER from committed seeds.
/// The seed phrases below are PUBLIC testnet keys — they have zero value.
use bip39::{Language, Mnemonic};
use std::fs;

const VOID_PER_UAT: u128 = 100_000_000_000;
const TOTAL_SUPPLY_UAT: u128 = 21_936_236;
const DEV_ALLOCATION_PERCENT_NUM: u128 = 7;
const DEV_ALLOCATION_PERCENT_DEN: u128 = 100;
const DEV_TREASURY_COUNT: usize = 8;
const BOOTSTRAP_NODE_COUNT: usize = 4;
const BOOTSTRAP_NODE_STAKE_UAT: u128 = 1_000;

// TESTNET FIXED SEED PHRASES (PUBLIC - Safe to share)
// These serve as identifiers/labels. Keys are generated randomly via Dilithium5.
const TESTNET_SEEDS: [&str; 12] = [
    "riot draft insect furnace soldier faith recipe fabric auction public select diamond arrow topple naive wheel opinion kit thumb noble guitar addict monkey pipe",
    "piano auction estate truth identify time fine zero tackle make smoke voice candy hundred law pipe salute post rural dove icon donor pioneer satisfy",
    "brief just wise upset lounge ocean record project smile east artefact supreme anger blind turkey trigger yard peanut tiger lift casino baby disagree danger",
    "unlock rack arena aspect coast repair feed margin village slogan brief improve exile expose swift since inquiry high target clerk tongue weird three prevent",
    "wreck empty among right address raven warfare purpose divide shrug weird castle hockey walnut girl punch volcano transfer convince elite organ fiber you job",
    "boil envelope car carry rude penalty rapid modify smoke layer jealous awake fix purpose laptop advice convince fold comfort fall cute limit length lava",
    "ostrich orphan net leaf hint all pear nature agent road sniff tell thank slam plastic mercy gate expand muffin alarm front grape audit top",
    "panic solar raven ice thought define shuffle coffee nasty expect track artefact replace grid green goose arrive try cloud return elder bronze enrich feel",
    "setup sock trouble pencil perfect mushroom horn beef list sick weasel symptom undo picnic horn vehicle scrub begin electric shoulder equal chalk broken render",
    "nasty addict moral runway cage unique they bachelor middle park indicate chest era rigid once range awkward jar tomato elite engine filter service badge",
    "scare detail bag pass mixture differ step oven possible flight endorse tortoise glass gate edit emotion general drift frost coconut glimpse ask attitude poverty",
    "gold ensure reopen lunar choice camp milk tiger offer very move normal salute suffer sea unhappy nerve practice jealous edit cable sketch legal rely",
];

fn main() {
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║   UNAUTHORITY TESTNET GENESIS GENERATOR v8.0              ║");
    println!("║   Dilithium5 Post-Quantum Crypto                          ║");
    println!("║   PUBLIC - Safe to Share and Commit                       ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!("\n12 Wallets: 8 Dev Treasury + 4 Bootstrap Validators\n");

    // Integer math: dev allocation = total * 7 / 100
    let dev_allocation_void =
        (TOTAL_SUPPLY_UAT * DEV_ALLOCATION_PERCENT_NUM / DEV_ALLOCATION_PERCENT_DEN) * VOID_PER_UAT;
    let total_bootstrap_allocation_void =
        BOOTSTRAP_NODE_STAKE_UAT * (BOOTSTRAP_NODE_COUNT as u128) * VOID_PER_UAT;
    let allocation_per_treasury_void = dev_allocation_void / (DEV_TREASURY_COUNT as u128);
    let treasury_8_balance_void = allocation_per_treasury_void - total_bootstrap_allocation_void;

    let mut wallet_entries: Vec<String> = Vec::new();

    println!("===================================================");
    println!("TESTNET TREASURY WALLETS (Dilithium5 Post-Quantum)");
    println!("===================================================\n");

    for (i, &seed_phrase) in TESTNET_SEEDS[..DEV_TREASURY_COUNT].iter().enumerate() {
        let wallet_num = i + 1;

        // Validate seed phrase is valid BIP39
        let mnemonic = Mnemonic::parse_in_normalized(Language::English, seed_phrase)
            .expect("Invalid BIP39 seed phrase");

        // DETERMINISTIC: Derive Dilithium5 keypair from BIP39 seed
        let bip39_seed = mnemonic.to_seed("");
        let kp = uat_crypto::generate_keypair_from_seed(&bip39_seed);
        let pk_hex = hex::encode(&kp.public_key);
        let sk_hex = hex::encode(&kp.secret_key);
        let address = uat_crypto::public_key_to_address(&kp.public_key);

        let balance = if wallet_num == DEV_TREASURY_COUNT {
            treasury_8_balance_void
        } else {
            allocation_per_treasury_void
        };

        let balance_uat = balance / VOID_PER_UAT;
        let balance_remainder = balance % VOID_PER_UAT;

        println!("Treasury Wallet #{}:", wallet_num);
        println!("  Address:      {}", address);
        println!(
            "  Balance:      {}.{:011} UAT ({} VOID)",
            balance_uat, balance_remainder, balance
        );
        println!("  Seed Phrase:  {}", seed_phrase);
        println!("  Public Key:   {}...\n", &pk_hex[..64]);

        wallet_entries.push(format!(
            "    {{\n      \"wallet_type\": \"DevWallet({})\",\n      \"seed_phrase\": \"{}\",\n      \"address\": \"{}\",\n      \"balance_void\": \"{}\",\n      \"balance_uat\": \"{}.{:011}\",\n      \"public_key\": \"{}\",\n      \"private_key\": \"{}\",\n      \"note\": \"Dev Treasury #{}\"\n    }}",
            wallet_num, seed_phrase, address, balance,
            balance_uat, balance_remainder, pk_hex, sk_hex, wallet_num
        ));
    }

    println!("===================================================");
    println!("TESTNET BOOTSTRAP VALIDATORS (Dilithium5 Post-Quantum)");
    println!("===================================================\n");

    for i in 0..BOOTSTRAP_NODE_COUNT {
        let validator_num = i + 1;
        let seed_index = DEV_TREASURY_COUNT + i;
        let seed_phrase = TESTNET_SEEDS[seed_index];

        let mnemonic_parsed = Mnemonic::parse_in_normalized(Language::English, seed_phrase)
            .expect("Invalid BIP39 seed phrase");

        // DETERMINISTIC: Derive Dilithium5 keypair from BIP39 seed
        let bip39_seed = mnemonic_parsed.to_seed("");
        let kp = uat_crypto::generate_keypair_from_seed(&bip39_seed);
        let pk_hex = hex::encode(&kp.public_key);
        let sk_hex = hex::encode(&kp.secret_key);
        let address = uat_crypto::public_key_to_address(&kp.public_key);

        let balance = BOOTSTRAP_NODE_STAKE_UAT * VOID_PER_UAT;

        println!("Bootstrap Validator #{}:", validator_num);
        println!("  Address:      {}", address);
        println!(
            "  Balance:      {} UAT ({} VOID)",
            BOOTSTRAP_NODE_STAKE_UAT, balance
        );
        println!("  Seed Phrase:  {}", seed_phrase);
        println!("  Public Key:   {}...\n", &pk_hex[..64]);

        wallet_entries.push(format!(
            "    {{\n      \"wallet_type\": \"BootstrapNode({})\",\n      \"seed_phrase\": \"{}\",\n      \"address\": \"{}\",\n      \"balance_void\": \"{}\",\n      \"balance_uat\": \"{}\",\n      \"public_key\": \"{}\",\n      \"private_key\": \"{}\",\n      \"note\": \"Bootstrap Validator #{}\"\n    }}",
            validator_num, seed_phrase, address, balance,
            BOOTSTRAP_NODE_STAKE_UAT, pk_hex, sk_hex, validator_num
        ));
    }

    println!("===================================================");
    println!("ALLOCATION SUMMARY (TESTNET)");
    println!("===================================================");
    println!("Total Supply:     {} UAT", TOTAL_SUPPLY_UAT);
    println!(
        "Dev Allocation:   {} UAT (7%)",
        dev_allocation_void / VOID_PER_UAT
    );
    println!("Per Treasury:     {} VOID", allocation_per_treasury_void);
    println!(
        "Treasury 8:       {} VOID (after funding {} nodes)",
        treasury_8_balance_void, BOOTSTRAP_NODE_COUNT
    );
    println!(
        "Validators:       {} x {} UAT",
        BOOTSTRAP_NODE_COUNT, BOOTSTRAP_NODE_STAKE_UAT
    );
    println!("===================================================\n");

    // Build JSON manually
    let wallets_json = wallet_entries.join(",\n");
    let json = format!(
        "{{\n  \"network\": \"testnet\",\n  \"description\": \"Public testnet genesis - 12 wallets (8 dev + 4 validators)\",\n  \"warning\": \"FOR TESTNET ONLY - NEVER use these seeds on mainnet!\",\n  \"crypto\": \"CRYSTALS-Dilithium5 (Post-Quantum)\",\n  \"note\": \"BIP39 seeds deterministically derive Dilithium5 keypairs. Same seed = same address.\",\n  \"allocation\": {{\n    \"total_supply_uat\": \"{}\",\n    \"dev_allocation_uat\": \"{}\",\n    \"dev_allocation_percent\": \"7%\"\n  }},\n  \"wallets\": [\n{}\n  ]\n}}",
        TOTAL_SUPPLY_UAT,
        dev_allocation_void / VOID_PER_UAT,
        wallets_json
    );

    let output_path = "testnet-genesis/testnet_wallets.json";
    if let Err(e) = fs::create_dir_all("testnet-genesis") {
        eprintln!("Warning: Could not create directory: {}", e);
    }
    fs::write(output_path, &json).expect("Failed to write testnet_wallets.json");

    println!("Testnet genesis saved to: {}", output_path);
    println!("12 wallets with Dilithium5 post-quantum addresses");
    println!("Safe to commit to git - these are PUBLIC testnet seeds");
    println!("NOTE: Private keys included in output - store securely!");
    println!();
}
