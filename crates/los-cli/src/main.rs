// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UNAUTHORITY CLI - Command Line Interface for Validators & Users
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

use clap::{Parser, Subcommand};
use colored::*;
use std::path::PathBuf;

mod commands;

#[derive(Parser)]
#[command(name = "los-cli")]
#[command(about = "Unauthority CLI - Validator & Wallet Management", long_about = None)]
#[command(version)]
struct Cli {
    /// RPC endpoint URL (reads LOS_RPC_URL env var, or defaults to http://localhost:3030)
    /// For Tor: set LOS_RPC_URL=http://your-node.onion
    #[arg(
        short,
        long,
        env = "LOS_RPC_URL",
        default_value = "http://localhost:3030"
    )]
    rpc: String,

    /// Config directory (default: ~/.los)
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

    /// USP-01 Token operations
    Token {
        #[command(subcommand)]
        action: TokenCommands,
    },

    /// DEX (Decentralized Exchange) operations
    Dex {
        #[command(subcommand)]
        action: DexCommands,
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
        /// Amount in LOS (minimum 1000)
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
    /// Send LOS to address
    Send {
        /// Recipient address
        #[arg(short, long)]
        to: String,

        /// Amount in LOS
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

#[derive(Subcommand)]
enum DexCommands {
    /// List all DEX pools across all contracts
    Pools,

    /// Show pool info
    Pool {
        /// DEX contract address (LOSCon...)
        #[arg(short, long)]
        contract: String,

        /// Pool ID (e.g. POOL:LOS:TOKEN_A)
        #[arg(short, long)]
        pool_id: String,
    },

    /// Get a swap quote
    Quote {
        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Pool ID
        #[arg(short, long)]
        pool_id: String,

        /// Token to sell
        #[arg(short, long)]
        token_in: String,

        /// Amount to sell (atomic units)
        #[arg(short, long)]
        amount_in: u128,
    },

    /// Get LP position for a user
    Position {
        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Pool ID
        #[arg(short, long)]
        pool_id: String,

        /// User address
        #[arg(short, long)]
        user: String,
    },

    /// Deploy a DEX AMM contract
    Deploy {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Path to compiled WASM file
        #[arg(long)]
        wasm: String,
    },

    /// Create a new liquidity pool
    CreatePool {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Token A identifier
        #[arg(long)]
        token_a: String,

        /// Token B identifier
        #[arg(long)]
        token_b: String,

        /// Initial amount of Token A (atomic units)
        #[arg(long)]
        amount_a: String,

        /// Initial amount of Token B (atomic units)
        #[arg(long)]
        amount_b: String,

        /// Fee in basis points (default: 30 = 0.3%)
        #[arg(long)]
        fee_bps: Option<String>,
    },

    /// Add liquidity to a pool
    AddLiquidity {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Pool ID
        #[arg(short, long)]
        pool_id: String,

        /// Amount of Token A to add
        #[arg(long)]
        amount_a: String,

        /// Amount of Token B to add
        #[arg(long)]
        amount_b: String,

        /// Minimum LP tokens to receive (slippage protection)
        #[arg(long)]
        min_lp: String,
    },

    /// Remove liquidity from a pool
    RemoveLiquidity {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Pool ID
        #[arg(short, long)]
        pool_id: String,

        /// LP tokens to burn
        #[arg(long)]
        lp_amount: String,

        /// Minimum Token A to receive (slippage protection)
        #[arg(long)]
        min_a: String,

        /// Minimum Token B to receive (slippage protection)
        #[arg(long)]
        min_b: String,
    },

    /// Execute a token swap
    Swap {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// DEX contract address
        #[arg(short, long)]
        contract: String,

        /// Pool ID
        #[arg(short, long)]
        pool_id: String,

        /// Token to sell
        #[arg(long)]
        token_in: String,

        /// Amount to sell (atomic units)
        #[arg(long)]
        amount_in: String,

        /// Minimum amount to receive (slippage protection)
        #[arg(long)]
        min_out: String,

        /// Transaction deadline (unix timestamp, default: now + 5min)
        #[arg(long)]
        deadline: Option<u64>,
    },
}

#[derive(Subcommand)]
enum TokenCommands {
    /// List all deployed USP-01 tokens
    List,

    /// Show USP-01 token metadata
    Info {
        /// Token contract address (LOSCon...)
        address: String,
    },

    /// Query token balance for a holder
    Balance {
        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Holder address
        #[arg(long)]
        holder: String,
    },

    /// Query token allowance
    Allowance {
        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Owner address
        #[arg(short, long)]
        owner: String,

        /// Spender address
        #[arg(short, long)]
        spender: String,
    },

    /// Deploy a new USP-01 token
    Deploy {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Path to compiled WASM file
        #[arg(long)]
        wasm: String,

        /// Token name (1-64 chars)
        #[arg(long)]
        name: String,

        /// Token symbol (1-8 chars)
        #[arg(long)]
        symbol: String,

        /// Token decimals (0-18)
        #[arg(long, default_value = "11")]
        decimals: u8,

        /// Total supply (atomic units)
        #[arg(long)]
        total_supply: String,

        /// Max supply (0 = unlimited, atomic units)
        #[arg(long)]
        max_supply: Option<String>,

        /// Is this a wrapped asset?
        #[arg(long, default_value = "false")]
        is_wrapped: bool,

        /// Origin chain for wrapped asset (e.g. "ethereum")
        #[arg(long)]
        wrapped_origin: Option<String>,

        /// Bridge operator address for wrapped asset
        #[arg(long)]
        bridge_operator: Option<String>,
    },

    /// Distribute tokens (transfer from owner)
    Mint {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Recipient address
        #[arg(long)]
        to: String,

        /// Amount (atomic units)
        #[arg(long)]
        amount: String,
    },

    /// Transfer tokens to another address
    Transfer {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Recipient address
        #[arg(long)]
        to: String,

        /// Amount (atomic units)
        #[arg(long)]
        amount: String,
    },

    /// Approve spender allowance
    Approve {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Spender address
        #[arg(long)]
        spender: String,

        /// Amount to allow (atomic units)
        #[arg(long)]
        amount: String,
    },

    /// Burn tokens from your balance
    Burn {
        /// Wallet name
        #[arg(short, long)]
        wallet: String,

        /// Token contract address
        #[arg(short, long)]
        token: String,

        /// Amount to burn (atomic units)
        #[arg(long)]
        amount: String,
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
            .unwrap_or_else(|| std::path::PathBuf::from("."))
            .join(".los")
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
        Commands::Token { action } => {
            commands::token::handle(action, &cli.rpc, &config_dir).await?;
        }
        Commands::Dex { action } => commands::dex::handle(action, &cli.rpc, &config_dir).await?,
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
        "║      UNAUTHORITY (LOS) - CLI v0.1.0           ║"
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
