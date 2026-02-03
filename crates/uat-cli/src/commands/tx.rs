use crate::{TxCommands, print_error, print_info};
use std::path::Path;
use colored::*;

pub async fn handle(
    action: TxCommands,
    rpc: &str,
    config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    match action {
        TxCommands::Send { to, amount, from } => send_tx(&to, amount, &from, rpc, config_dir).await?,
        TxCommands::Status { hash } => query_status(&hash, rpc).await?,
    }
    Ok(())
}

async fn send_tx(
    to: &str,
    amount: u64,
    from_wallet: &str,
    _rpc: &str,
    _config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Sending {} UAT to {}...", amount, to));
    
    // TODO: Load wallet, sign transaction, broadcast
    println!();
    println!("{}", "⚠️  Send transaction not yet implemented.".yellow());
    println!("{}", "Coming in next update.".dimmed());
    println!();
    println!("{}", "Transaction details:".bold());
    println!("  From: {}", from_wallet);
    println!("  To: {}", to);
    println!("  Amount: {} UAT", amount);
    
    Ok(())
}

async fn query_status(tx_hash: &str, rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying transaction {}...", tx_hash));
    
    let client = reqwest::Client::new();
    let url = format!("{}/tx/{}", rpc, tx_hash);
    
    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;
                
                println!();
                println!("{} {}", "Transaction Hash:".bold(), tx_hash.green());
                println!("{} {}", "Status:".bold(), 
                    if data["confirmed"].as_bool().unwrap_or(false) {
                        "Confirmed ✓".green()
                    } else {
                        "Pending...".yellow()
                    });
                println!("{} {}", "Block Height:".bold(), 
                    data["block_height"].as_u64().unwrap_or(0));
                println!("{} {} → {}", "Transfer:".bold(), 
                    data["from"].as_str().unwrap_or("Unknown").dimmed(),
                    data["to"].as_str().unwrap_or("Unknown").dimmed());
                println!("{} {} UAT", "Amount:".bold(), 
                    data["amount"].as_u64().unwrap_or(0).to_string().cyan());
            } else {
                print_error(&format!("Transaction not found: HTTP {}", response.status()));
            }
        }
        Err(e) => {
            print_error(&format!("Network error: {}", e));
        }
    }
    
    Ok(())
}
