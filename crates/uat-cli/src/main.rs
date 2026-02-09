// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UNAUTHORITY CLI - Command Line Interface for Validators & Users
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

use clap::{Parser, Subcommand};
use colored::*;
use std::path::PathBuf;

mod commands;

#[derive(Parser)]
#[command(name = "uat-cli")]
#[command(about = "Unauthority CLI - Validator & Wallet Management", long_about = None)]
#[command(version)]
struct Cli {
    /// RPC endpoint URL (reads UAT_RPC_URL env var, or defaults to http://localhost:3030)
    /// For Tor: set UAT_RPC_URL=http://your-node.onion
    #[arg(short, long, env = "UAT_RPC_URL", default_value = "http://localhost:3030")]
    rpc: String,

    /// Config directory (default: ~/.uat)
    #[arg(short, long)]
    config_dir: Option<PathBuf>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Wallet management
    Wallet {
        #[command(subcommand)]
        action: WalletCommands,
    },

    /// Validator operations
    Validator {
        #[command(subcommand)]
        action: ValidatorCommands,
    },

    /// Query blockchain state
    Query {
        #[command(subcommand)]
        action: QueryCommands,
    },

    /// Transaction operations
    Tx {
        #[command(subcommand)]
        action: TxCommands,
    },
}

#[derive(Subcommand)]
enum WalletCommands {
    /// Create new wallet
    New {
        /// Wallet name
        #[arg(short, long)]
        name: String,
    },

    /// List all wallets
    List,

    /// Show wallet balance
    Balance {
        /// Wallet address
        address: String,
    },

    /// Export wallet (encrypted)
    Export {
        /// Wallet name
        name: String,

        /// Output file path
        #[arg(short, long)]
        output: PathBuf,
    },

    /// Import wallet
    Import {
        /// Input file path
        input: PathBuf,

        /// Wallet name
        #[arg(short, long)]
        name: String,
    },
}

#[derive(Subcommand)]
enum ValidatorCommands {
    /// Stake tokens to become validator
    Stake {
        /// Amount in UAT (minimum 1000)
        #[arg(short, long)]
        amount: u64,

        /// Wallet name
        #[arg(short, long)]
        wallet: String,
    },

    /// Unstake tokens
    Unstake {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,
    },

    /// Show validator status
    Status {
        /// Validator address
        address: String,
    },

    /// List all active validators
    List,
}

#[derive(Subcommand)]
enum QueryCommands {
    /// Get block by height
    Block {
        /// Block height
        height: u64,
    },

    /// Get account state
    Account {
        /// Account address
        address: String,
    },

    /// Get network info
    Info,

    /// Get validator set
    Validators,
}

#[derive(Subcommand)]
enum TxCommands {
    /// Send UAT to address
    Send {
        /// Recipient address
        #[arg(short, long)]
        to: String,

        /// Amount in UAT
        #[arg(short, long)]
        amount: u64,

        /// Sender wallet name
        #[arg(short, long)]
        from: String,
    },

    /// Query transaction status
    Status {
        /// Transaction hash
        hash: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    // Print banner
    print_banner();

    // Get config directory
    let config_dir = cli.config_dir.unwrap_or_else(|| {
        dirs::home_dir()
            .expect("Could not find home directory")
            .join(".uat")
    });

    // Ensure config directory exists
    std::fs::create_dir_all(&config_dir)?;

    match cli.command {
        Commands::Wallet { action } => {
            commands::wallet::handle(action, &cli.rpc, &config_dir).await?;
        }
        Commands::Validator { action } => {
            commands::validator::handle(action, &cli.rpc, &config_dir).await?;
        }
        Commands::Query { action } => {
            commands::query::handle(action, &cli.rpc).await?;
        }
        Commands::Tx { action } => {
            commands::tx::handle(action, &cli.rpc, &config_dir).await?;
        }
    }

    Ok(())
}

fn print_banner() {
    println!(
        "{}",
        "╔═══════════════════════════════════════════════╗".cyan()
    );
    println!(
        "{}",
        "║      UNAUTHORITY (UAT) - CLI v0.1.0           ║"
            .cyan()
            .bold()
    );
    println!(
        "{}",
        "║   Permissionless | Immutable | Decentralized  ║".cyan()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════════════╝".cyan()
    );
    println!();
}

// Additional utility for colored output
#[allow(dead_code)]
fn print_success(msg: &str) {
    println!("{} {}", "✓".green().bold(), msg);
}

#[allow(dead_code)]
fn print_error(msg: &str) {
    eprintln!("{} {}", "✗".red().bold(), msg);
}

#[allow(dead_code)]
fn print_info(msg: &str) {
    println!("{} {}", "ℹ".blue().bold(), msg);
}
