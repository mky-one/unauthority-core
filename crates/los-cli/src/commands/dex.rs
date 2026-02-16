use colored::Colorize;

/// Handle DEX subcommands.
pub async fn handle(
    action: crate::DexCommands,
    rpc: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    match action {
        crate::DexCommands::Pools => list_pools(rpc).await,
        crate::DexCommands::Pool { contract, pool_id } => pool_info(rpc, &contract, &pool_id).await,
        crate::DexCommands::Quote {
            contract,
            pool_id,
            token_in,
            amount_in,
        } => get_quote(rpc, &contract, &pool_id, &token_in, amount_in).await,
        crate::DexCommands::Position {
            contract,
            pool_id,
            user,
        } => get_position(rpc, &contract, &pool_id, &user).await,
    }
}

async fn list_pools(rpc: &str) -> Result<(), Box<dyn std::error::Error>> {
    let url = format!("{}/dex/pools", rpc);
    let resp: serde_json::Value = reqwest::get(&url).await?.json().await?;

    if resp["status"] == "success" {
        let count = resp["count"].as_u64().unwrap_or(0);
        println!("{}", format!("DEX Pools ({})", count).cyan().bold());
        println!("{}", "─".repeat(70));

        if let Some(pools) = resp["pools"].as_array() {
            for pool in pools {
                let pid = pool["pool_id"].as_str().unwrap_or("?");
                let ta = pool["token_a"].as_str().unwrap_or("?");
                let tb = pool["token_b"].as_str().unwrap_or("?");
                let ra = pool["reserve_a"].as_u64().unwrap_or(0);
                let rb = pool["reserve_b"].as_u64().unwrap_or(0);
                let contract = pool["contract"].as_str().unwrap_or("?");
                println!(
                    "  {} {} / {} | Reserves: {} / {} | Contract: {}",
                    pid.yellow(),
                    ta.green(),
                    tb.green(),
                    ra.to_string().white(),
                    rb.to_string().white(),
                    &contract[..16.min(contract.len())],
                );
            }
        }
        if count == 0 {
            println!("  {}", "No pools found".dimmed());
        }
    } else {
        let msg = resp["msg"].as_str().unwrap_or("Unknown error");
        eprintln!("{} {}", "Error:".red().bold(), msg);
    }

    Ok(())
}

async fn pool_info(
    rpc: &str,
    contract: &str,
    pool_id: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let url = format!("{}/dex/pool/{}/{}", rpc, contract, pool_id);
    let resp: serde_json::Value = reqwest::get(&url).await?.json().await?;

    if resp["status"] == "success" {
        let pool = &resp["pool"];
        println!("{}", "Pool Info".cyan().bold());
        println!("{}", "─".repeat(50));
        println!(
            "  Pool ID:     {}",
            pool["pool_id"].as_str().unwrap_or("?").yellow()
        );
        println!(
            "  Token A:     {}",
            pool["token_a"].as_str().unwrap_or("?").green()
        );
        println!(
            "  Token B:     {}",
            pool["token_b"].as_str().unwrap_or("?").green()
        );
        println!("  Reserve A:   {}", pool["reserve_a"]);
        println!("  Reserve B:   {}", pool["reserve_b"]);
        println!("  Total LP:    {}", pool["total_lp"]);
        println!("  Fee (bps):   {}", pool["fee_bps"]);
        println!("  Creator:     {}", pool["creator"].as_str().unwrap_or("?"));
        println!("  Last Trade:  {}", pool["last_trade"]);
    } else {
        let msg = resp["msg"].as_str().unwrap_or("Unknown error");
        eprintln!("{} {}", "Error:".red().bold(), msg);
    }

    Ok(())
}

async fn get_quote(
    rpc: &str,
    contract: &str,
    pool_id: &str,
    token_in: &str,
    amount_in: u128,
) -> Result<(), Box<dyn std::error::Error>> {
    let url = format!(
        "{}/dex/quote/{}/{}/{}/{}",
        rpc, contract, pool_id, token_in, amount_in
    );
    let resp: serde_json::Value = reqwest::get(&url).await?.json().await?;

    if resp["status"] == "success" {
        let q = &resp["quote"];
        println!("{}", "Swap Quote".cyan().bold());
        println!("{}", "─".repeat(40));
        println!("  Amount Out:      {}", q["amount_out"].to_string().green());
        println!("  Fee:             {}", q["fee"].to_string().yellow());
        println!(
            "  Price Impact:    {} bps",
            q["price_impact_bps"].to_string().white()
        );
    } else {
        let msg = resp["msg"].as_str().unwrap_or("Unknown error");
        eprintln!("{} {}", "Error:".red().bold(), msg);
    }

    Ok(())
}

async fn get_position(
    rpc: &str,
    contract: &str,
    pool_id: &str,
    user: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let url = format!("{}/dex/position/{}/{}/{}", rpc, contract, pool_id, user);
    let resp: serde_json::Value = reqwest::get(&url).await?.json().await?;

    if resp["status"] == "success" {
        println!("{}", "LP Position".cyan().bold());
        println!("{}", "─".repeat(40));
        println!("  LP Shares:   {}", resp["lp_shares"].to_string().green());
        println!("  User:        {}", user);
        println!("  Pool:        {}", pool_id);
    } else {
        let msg = resp["msg"].as_str().unwrap_or("Unknown error");
        eprintln!("{} {}", "Error:".red().bold(), msg);
    }

    Ok(())
}
