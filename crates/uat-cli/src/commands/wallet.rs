use crate::{WalletCommands, print_success, print_error, print_info};
use std::path::Path;
use uat_crypto::generate_encrypted_keypair;
use uat_core::VOID_PER_UAT;
use serde::{Serialize, Deserialize};
use colored::*;

#[allow(dead_code)]
#[derive(Serialize, Deserialize)]
struct WalletMetadata {
    name: String,
    address: String,
    created_at: u64,
}

pub async fn handle(
    action: WalletCommands,
    rpc: &str,
    config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    match action {
        WalletCommands::New { name } => create_new_wallet(&name, config_dir)?,
        WalletCommands::List => list_wallets(config_dir)?,
        WalletCommands::Balance { address } => show_balance(&address, rpc).await?,
        WalletCommands::Export { name, output } => export_wallet(&name, config_dir, &output)?,
        WalletCommands::Import { input, name } => import_wallet(&input, config_dir, &name)?,
    }
    Ok(())
}

fn create_new_wallet(name: &str, config_dir: &Path) -> Result<(), Box<dyn std::error::Error>> {
    println!("{}", "Creating new wallet...".yellow());
    println!();
    
    // Prompt for password
    let password = rpassword::prompt_password("Enter password for encryption: ")?;
    let password_confirm = rpassword::prompt_password("Confirm password: ")?;
    
    if password != password_confirm {
        print_error("Passwords do not match!");
        return Ok(());
    }
    
    if password.len() < 8 {
        print_error("Password must be at least 8 characters!");
        return Ok(());
    }
    
    // Generate encrypted keypair
    print_info("Generating Post-Quantum keypair (Dilithium5)...");
    let encrypted_key = generate_encrypted_keypair(&password)?;
    
    // Derive address from public key (Base58Check format)
    let address = uat_crypto::public_key_to_address(&encrypted_key.public_key);
    
    // Save wallet
    let wallet_dir = config_dir.join("wallets");
    std::fs::create_dir_all(&wallet_dir)?;
    
    let wallet_file = wallet_dir.join(format!("{}.json", name));
    if wallet_file.exists() {
        print_error(&format!("Wallet '{}' already exists!", name));
        return Ok(());
    }
    
    let wallet_data = serde_json::json!({
        "name": name,
        "address": address,
        "encrypted_key": encrypted_key,
        "created_at": std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_secs(),
    });
    
    std::fs::write(&wallet_file, serde_json::to_string_pretty(&wallet_data)?)?;
    
    println!();
    print_success(&format!("Wallet '{}' created successfully!", name));
    println!();
    println!("{} {}", "Address:".bold(), address.green());
    println!("{} {}", "Location:".bold(), wallet_file.display());
    println!();
    println!("{}", "⚠️  IMPORTANT: Keep your password safe! It cannot be recovered.".yellow().bold());
    
    Ok(())
}

fn list_wallets(config_dir: &Path) -> Result<(), Box<dyn std::error::Error>> {
    let wallet_dir = config_dir.join("wallets");
    
    if !wallet_dir.exists() {
        print_info("No wallets found. Create one with: uat-cli wallet new --name <name>");
        return Ok(());
    }
    
    println!("{}", "Available wallets:".bold());
    println!();
    
    let mut count = 0;
    for entry in std::fs::read_dir(&wallet_dir)? {
        let entry = entry?;
        let path = entry.path();
        
        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            let data = std::fs::read_to_string(&path)?;
            let wallet: serde_json::Value = serde_json::from_str(&data)?;
            
            let name = wallet["name"].as_str().unwrap_or("Unknown");
            let address = wallet["address"].as_str().unwrap_or("Unknown");
            
            println!("  {} {}", "•".cyan(), name.bold());
            println!("    {}: {}", "Address".dimmed(), address.green());
            println!();
            count += 1;
        }
    }
    
    if count == 0 {
        print_info("No wallets found.");
    } else {
        println!("{} {} {}", "Total:".bold(), count.to_string().cyan(), "wallet(s)".dimmed());
    }
    
    Ok(())
}

async fn show_balance(address: &str, rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying balance for {}...", address));
    
    let client = reqwest::Client::new();
    let url = format!("{}/balance/{}", rpc, address);
    
    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;
                let balance_voi = data["balance"].as_u64().unwrap_or(0);
                let balance_uat = balance_voi as f64 / VOID_PER_UAT as f64;
                
                println!();
                println!("{} {}", "Address:".bold(), address.green());
                println!("{} {} UAT", "Balance:".bold(), format!("{:.8}", balance_uat).cyan().bold());
                println!("{} {} VOI", "       ".dimmed(), balance_voi.to_string().dimmed());
            } else {
                print_error(&format!("Failed to query balance: HTTP {}", response.status()));
            }
        }
        Err(e) => {
            print_error(&format!("Network error: {}", e));
            print_info("Make sure the node is running on the specified RPC endpoint.");
        }
    }
    
    Ok(())
}

fn export_wallet(
    name: &str,
    config_dir: &Path,
    output: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let wallet_file = config_dir.join("wallets").join(format!("{}.json", name));
    
    if !wallet_file.exists() {
        print_error(&format!("Wallet '{}' not found!", name));
        return Ok(());
    }
    
    std::fs::copy(&wallet_file, output)?;
    print_success(&format!("Wallet exported to: {}", output.display()));
    println!("{}", "⚠️  Keep this file secure! It contains your encrypted private key.".yellow());
    
    Ok(())
}

fn import_wallet(
    input: &Path,
    config_dir: &Path,
    name: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    if !input.exists() {
        print_error(&format!("File not found: {}", input.display()));
        return Ok(());
    }
    
    let wallet_dir = config_dir.join("wallets");
    std::fs::create_dir_all(&wallet_dir)?;
    
    let wallet_file = wallet_dir.join(format!("{}.json", name));
    if wallet_file.exists() {
        print_error(&format!("Wallet '{}' already exists!", name));
        return Ok(());
    }
    
    std::fs::copy(input, &wallet_file)?;
    print_success(&format!("Wallet imported as '{}'", name));
    
    Ok(())
}
