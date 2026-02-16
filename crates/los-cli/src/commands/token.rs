use crate::{print_error, print_info, print_success, TokenCommands};
use colored::*;

pub async fn handle(action: TokenCommands, rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    match action {
        TokenCommands::List => list_tokens(rpc).await?,
        TokenCommands::Info { address } => token_info(&address, rpc).await?,
        TokenCommands::Balance { token, holder } => token_balance(&token, &holder, rpc).await?,
        TokenCommands::Allowance {
            token,
            owner,
            spender,
        } => token_allowance(&token, &owner, &spender, rpc).await?,
    }
    Ok(())
}

async fn list_tokens(rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info("Querying USP-01 tokens...");

    let client = reqwest::Client::new();
    let url = format!("{}/tokens", rpc);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;
                let count = data["count"].as_u64().unwrap_or(0);

                if count == 0 {
                    print_info("No USP-01 tokens deployed yet.");
                    return Ok(());
                }

                println!("{}", "USP-01 Tokens:".bold());
                println!();

                if let Some(tokens) = data["tokens"].as_array() {
                    for token in tokens {
                        let name = token["name"].as_str().unwrap_or("Unknown");
                        let symbol = token["symbol"].as_str().unwrap_or("???");
                        let contract = token["contract"].as_str().unwrap_or("Unknown");
                        let total_supply = token["total_supply"].as_u64().unwrap_or(0);
                        let decimals = token["decimals"].as_u64().unwrap_or(0);
                        let is_wrapped = token["is_wrapped"].as_bool().unwrap_or(false);

                        println!("  {} {} ({})", "•".cyan(), name.bold(), symbol.yellow());
                        println!("    {}: {}", "Contract".dimmed(), contract.green());
                        println!(
                            "    {}: {} ({} decimals)",
                            "Supply".dimmed(),
                            total_supply.to_string().cyan(),
                            decimals
                        );
                        if is_wrapped {
                            let origin = token["wrapped_origin"].as_str().unwrap_or("unknown");
                            println!(
                                "    {}: {} ({})",
                                "Type".dimmed(),
                                "Wrapped Asset".yellow(),
                                origin
                            );
                        }
                        println!();
                    }
                }

                println!(
                    "{} {} {}",
                    "Total:".bold(),
                    count.to_string().cyan(),
                    "token(s)".dimmed()
                );
            } else {
                print_error(&format!("Server error: {}", response.status()));
            }
        }
        Err(e) => print_error(&format!("Connection failed: {}", e)),
    }
    Ok(())
}

async fn token_info(address: &str, rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying token info for {}...", address));

    let client = reqwest::Client::new();
    let url = format!("{}/token/{}", rpc, address);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;

                if data["status"].as_str() == Some("error") {
                    print_error(data["msg"].as_str().unwrap_or("Unknown error"));
                    return Ok(());
                }

                let token = &data["token"];
                let name = token["name"].as_str().unwrap_or("Unknown");
                let symbol = token["symbol"].as_str().unwrap_or("???");
                let decimals = token["decimals"].as_u64().unwrap_or(0);
                let total_supply = token["total_supply"].as_u64().unwrap_or(0);
                let max_supply = token["max_supply"].as_u64().unwrap_or(0);
                let is_wrapped = token["is_wrapped"].as_bool().unwrap_or(false);
                let owner = token["owner"].as_str().unwrap_or("Unknown");
                let contract = token["contract"].as_str().unwrap_or(address);

                println!();
                println!("{}", "USP-01 Token Info".bold().underline());
                println!();
                println!(
                    "  {}: {} ({})",
                    "Name".bold(),
                    name.green(),
                    symbol.yellow()
                );
                println!("  {}: {}", "Contract".bold(), contract.green());
                println!("  {}: {}", "Owner".bold(), owner);
                println!("  {}: {}", "Decimals".bold(), decimals);
                println!(
                    "  {}: {}",
                    "Total Supply".bold(),
                    total_supply.to_string().cyan()
                );
                if max_supply > 0 {
                    println!(
                        "  {}: {}",
                        "Max Supply".bold(),
                        max_supply.to_string().cyan()
                    );
                }
                if is_wrapped {
                    let origin = token["wrapped_origin"].as_str().unwrap_or("unknown");
                    let bridge = token["bridge_operator"].as_str().unwrap_or("none");
                    println!(
                        "  {}: {} ({})",
                        "Type".bold(),
                        "Wrapped Asset".yellow(),
                        origin
                    );
                    println!("  {}: {}", "Bridge Operator".bold(), bridge);
                }
                println!("  {}: {}", "Standard".bold(), "USP-01".cyan());
                println!();
            } else {
                print_error(&format!("Server error: {}", response.status()));
            }
        }
        Err(e) => print_error(&format!("Connection failed: {}", e)),
    }
    Ok(())
}

async fn token_balance(
    token: &str,
    holder: &str,
    rpc: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying token balance for {}...", holder));

    let client = reqwest::Client::new();
    let url = format!("{}/token/{}/balance/{}", rpc, token, holder);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;

                if data["status"].as_str() == Some("error") {
                    print_error(data["msg"].as_str().unwrap_or("Unknown error"));
                    return Ok(());
                }

                let balance = data["balance"].as_str().unwrap_or("0");
                println!();
                println!("  {}: {}", "Token".bold(), token.green());
                println!("  {}: {}", "Holder".bold(), holder);
                println!("  {}: {}", "Balance".bold(), balance.cyan().bold());
                println!();

                print_success("Balance retrieved successfully");
            } else {
                print_error(&format!("Server error: {}", response.status()));
            }
        }
        Err(e) => print_error(&format!("Connection failed: {}", e)),
    }
    Ok(())
}

async fn token_allowance(
    token: &str,
    owner: &str,
    spender: &str,
    rpc: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    print_info(&format!("Querying allowance: {} -> {}...", owner, spender));

    let client = reqwest::Client::new();
    let url = format!("{}/token/{}/allowance/{}/{}", rpc, token, owner, spender);

    match client.get(&url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let data: serde_json::Value = response.json().await?;

                if data["status"].as_str() == Some("error") {
                    print_error(data["msg"].as_str().unwrap_or("Unknown error"));
                    return Ok(());
                }

                let allowance = data["allowance"].as_str().unwrap_or("0");
                println!();
                println!("  {}: {}", "Token".bold(), token.green());
                println!("  {}: {}", "Owner".bold(), owner);
                println!("  {}: {}", "Spender".bold(), spender);
                println!("  {}: {}", "Allowance".bold(), allowance.cyan().bold());
                println!();

                print_success("Allowance retrieved successfully");
            } else {
                print_error(&format!("Server error: {}", response.status()));
            }
        }
        Err(e) => print_error(&format!("Connection failed: {}", e)),
    }
    Ok(())
}
