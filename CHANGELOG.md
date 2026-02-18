# Changelog

All notable changes to the Unauthority (LOS) project are documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.0.10] — 2026-02-18

### Changed

- **License changed from Apache-2.0 to AGPL-3.0** — Prevents proprietary forks and closes the network services loophole. All validators running modified code must publish their source. Aligned with blockchain industry standard (Uniswap v3, Aave v3, Lido).
- All SPDX headers updated to `AGPL-3.0-only`.
- All README badges, CONTRIBUTING.md, and SECURITY.md updated.
- **Release workflows converted from Testnet to Mainnet** — Both Flutter Wallet and Validator release pipelines now build with mainnet tags and production release settings.

### Added

- **Smart Contract Developer Guide** (`docs/SMART_CONTRACTS.md`) — Complete guide for writing, compiling, deploying, and interacting with WASM contracts on UVM. Includes SDK reference, USP-01 token standard, DEX AMM, security guidelines, and gas limits.
- **Code of Conduct** (`CODE_OF_CONDUCT.md`) — Contributor Covenant v2.1.
- **Linux desktop entries** — XDG `.desktop` files and icon install rules for both Flutter Wallet and Validator on Linux.
- **App launcher icons** — LOS hexagon logo applied to macOS, Windows, Linux, and Web for both Flutter apps.

---

## [1.0.9] — 2025-06-17

### Mainnet Launch

The first production release of the Unauthority blockchain, running on the live Tor network with 4 bootstrap validators.

### Added

- **Mainnet genesis** with 8 accounts and 21,936,236 LOS total supply.
- **4 bootstrap validators** operating as Tor Hidden Services (.onion).
- **aBFT consensus** with asynchronous Byzantine Fault Tolerance.
- **Block-lattice (DAG)** architecture for parallel transaction processing.
- **Post-quantum cryptography** using Dilithium5 for all signing operations.
- **SHA-3 (Keccak-256)** for all hashing operations.
- **USP-01 token standard** for native fungible tokens and wrapped assets.
- **DEX AMM smart contracts** via WASM Virtual Machine (UVM).
- **46 REST API endpoints** covering accounts, blocks, transactions, validators, contracts, tokens, and DEX.
- **gRPC API** on port `REST + 20,000` for high-performance integrations.
- **Validator reward system**: 500,000 LOS non-inflationary pool, 5,000 LOS/epoch with halving every 48 epochs.
- **Quadratic voting** (√Stake) for anti-whale governance.
- **Dynamic fee scaling** based on network utilization.
- **Proof-of-Burn** mechanism for deflationary pressure.
- **Oracle price feed** contract for on-chain price data.
- **Flutter Wallet** app (macOS) for sending, receiving, and burning LOS.
- **Flutter Validator Dashboard** (macOS) for node monitoring and management.
- **Tor integration** — all nodes auto-generate .onion addresses on startup.
- **Peer discovery** via bootstrap node list with latency-based selection.
- **RocksDB** persistent storage for blocks, accounts, and state.
- **Comprehensive documentation**: Whitepaper, API Reference, Architecture, Validator Guide, Tor Setup, Exchange Integration.

### Security

- Zero `unwrap()` calls in production code paths.
- Zero floating-point arithmetic in consensus or financial logic.
- Integer square root (`isqrt`) for all reward calculations.
- All arithmetic uses checked/saturating operations to prevent overflow.
- Network isolation: Mainnet and Testnet peers cannot contaminate each other.

---

## [1.0.8] — 2025-06-10

### Testnet Phase

Pre-mainnet testing release deployed on the live Tor network.

### Added

- Full testnet deployment with 4 validators on Tor Hidden Services.
- End-to-end transaction testing over the Tor network.
- Validator registration and staking workflow.
- Cross-node balance verification.
- Node crash recovery testing.
- Epoch reward distribution testing.

### Fixed

- Peer contamination bug where testnet peers could leak into mainnet peer tables.
- Network badge incorrectly showing "testnet" in mainnet builds.
- `/tokens` and `/dex/pools` endpoints returning 404 on empty state.
- Genesis reward pool incorrectly included in circulating supply.

---

## [1.0.7] — 2025-06-01

### Added

- Smart contract compilation pipeline (Rust → WASM).
- DEX AMM contract with constant-product market maker.
- USP-01 token deployment and transfer operations.
- Oracle price feed contract.

### Changed

- Upgraded consensus voting to use quadratic weight (√Stake).
- Improved Tor circuit management with automatic reconnection.

---

## [1.0.6] — 2025-05-20

### Added

- gRPC API alongside REST endpoints.
- Validator metrics endpoint (`/metrics`).
- Slashing logic for double-signing (100% stake) and downtime (1% stake).
- CLI tool (`los-cli`) for wallet and validator management.

### Fixed

- Block ordering edge case in DAG traversal.
- Duplicate transaction detection across parallel chains.

---

## [1.0.5] — 2025-05-10

### Added

- Flutter Validator Dashboard with real-time node monitoring.
- Flutter Wallet with QR code scanning and transaction history.
- `flutter_rust_bridge` integration for Dilithium5 crypto operations in Dart.
- macOS `.dmg` installer builds for both apps.

### Changed

- Migrated all crypto operations from Dart to Rust via FRB.

---

## [1.0.0] — 2025-04-15

### Initial Release

- Core blockchain engine with block-lattice structure.
- Dilithium5 key generation, signing, and verification.
- SHA-3 block hashing.
- Basic REST API for account and transaction operations.
- Tor Hidden Service auto-generation for validator nodes.
- Genesis configuration with fixed 21,936,236 LOS supply.
- RocksDB storage backend.

---

## Genesis Allocation

| Category | Amount (LOS) |
|---|---|
| Dev Treasury 1 | 428,113 |
| Dev Treasury 2 | 245,710 |
| Dev Treasury 3 | 50,000 |
| Dev Treasury 4 | 50,000 |
| Bootstrap Validators (4 × 1,000) | 4,000 |
| **Dev Total** | **777,823** |
| **Public Allocation** | **21,158,413** |
| **Total Supply** | **21,936,236** |

---

[1.0.10]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.10
[1.0.9]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.9
[1.0.8]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.8
[1.0.7]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.7
[1.0.6]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.6
[1.0.5]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.5
[1.0.0]: https://github.com/mky-one/unauthority-core/releases/tag/v1.0.0
