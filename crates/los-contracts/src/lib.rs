//! # LOS Production Smart Contracts
//!
//! This crate contains the production `#![no_std]` WASM smart contracts
//! for the Unauthority (LOS) blockchain.
//!
//! ## Contracts
//!
//! | Contract       | Binary         | Description                                        |
//! |----------------|----------------|----------------------------------------------------|
//! | USP-01 Token   | `usp01_token`  | Native Fungible Token Standard (ERC-20 equivalent) |
//! | DEX AMM        | `dex_amm`      | Constant Product AMM (x·y=k) decentralized exchange|
//!
//! ## Compilation
//!
//! These contracts are compiled to `wasm32-unknown-unknown` for deployment on the UVM:
//!
//! ```bash
//! # Build all contracts
//! cargo build --target wasm32-unknown-unknown --release --manifest-path crates/los-contracts/Cargo.toml
//!
//! # Build individual contract
//! cargo build --target wasm32-unknown-unknown --release --manifest-path crates/los-contracts/Cargo.toml --bin usp01_token
//! cargo build --target wasm32-unknown-unknown --release --manifest-path crates/los-contracts/Cargo.toml --bin dex_amm
//! ```
//!
//! ## Architecture
//!
//! All contracts use `los-sdk` for host function interaction:
//! - Key-value state storage (decimal strings for numerics)
//! - Event emission for indexing
//! - Caller/context introspection
//! - Native CIL transfers
//!
//! **Important:** Numeric values are stored as decimal strings
//! (not LE bytes) to avoid `String::from_utf8_lossy` corruption
//! in `Contract.state: BTreeMap<String, String>`.
