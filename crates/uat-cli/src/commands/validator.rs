use crate::{print_error, print_info, print_success, ValidatorCommands};
use colored::*;
use std::path::Path;

pub async fn handle(
    action: ValidatorCommands,
    rpc: &str,
    config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    match action {
        ValidatorCommands::Stake { amount, wallet } => {
            stake(amount, &wallet, rpc, config_dir).await?
        }
        ValidatorCommands::Unstake { wallet } => unstake(&wallet, rpc, config_dir).await?,
        ValidatorCommands::Status { address } => show_status(&address, rpc).await?,
        ValidatorCommands::List => list_validators(rpc).await?,
    }
    Ok(())
}

async fn stake(
    amount: u64,
    wallet_name: &str,
    _rpc: &str,
    _config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    if amount < 1000 {
        print_error("Minimum stake is 1,000 UAT!");
        return Ok(());
    }

    print_info(&format!(
        "Staking {} UAT from wallet '{}'...",
        amount, wallet_name
    ));

    // TODO: Load wallet, sign transaction, broadcast
    println!();
    println!("{}", "⚠️  Stake transaction not yet implemented.".yellow());
    println!("{}", "Coming in next update.".dimmed());

    Ok(())
}

async fn unstake(
    wallet_name: &str,
    _rpc: &str,
    _config_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Unstaking from wallet '{}'...", wallet_name));

    println!();
    println!(
        "{}",
        "⚠️  Unstake transaction not yet implemented.".yellow()
    );

    Ok(())
}

async fn show_status(address: &str, rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying validator status for {}...", address));

    let client = reqwest::Client::new();
    let url = format!("{}/validators", rpc);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;

                // Find validator in list
                if let Some(validators) = data["validators"].as_array() {
                    if let Some(validator) = validators
                        .iter()
                        .find(|v| v["address"].as_str() == Some(address))
                    {
                        println!();
                        println!("{} {}", "Address:".bold(), address.green());
                        println!(
                            "{} {} UAT",
                            "Stake:".bold(),
                            validator["stake"].as_u64().unwrap_or(0).to_string().cyan()
                        );
                        println!(
                            "{} {}",
                            "Active:".bold(),
                            if validator["active"].as_bool().unwrap_or(false) {
                                "Yes".green()
                            } else {
                                "No".red()
                            }
                        );
                        print_success("Validator found!");
                    } else {
                        print_error("Validator not found in active set.");
                    }
                }
            } else {
                print_error(&format!("Failed to query: HTTP {}", response.status()));
            }
        }
        Err(e) => {
            print_error(&format!("Network error: {}", e));
        }
    }

    Ok(())
}

async fn list_validators(rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info("Fetching active validators...");

    let client = reqwest::Client::new();
    let url = format!("{}/validators", rpc);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;

                if let Some(validators) = data["validators"].as_array() {
                    println!();
                    println!("{}", "Active Validators:".bold());
                    println!();

                    for (i, validator) in validators.iter().enumerate() {
                        let address = validator["address"].as_str().unwrap_or("Unknown");
                        let stake = validator["stake"].as_u64().unwrap_or(0);

                        println!("  {}. {}", (i + 1).to_string().cyan(), address.green());
                        println!("     {}: {} UAT", "Stake".dimmed(), stake);
                        println!();
                    }

                    println!(
                        "{} {} {}",
                        "Total:".bold(),
                        validators.len().to_string().cyan(),
                        "validator(s)".dimmed()
                    );
                }
            } else {
                print_error(&format!("Failed to query: HTTP {}", response.status()));
            }
        }
        Err(e) => {
            print_error(&format!("Network error: {}", e));
        }
    }

    Ok(())
}
