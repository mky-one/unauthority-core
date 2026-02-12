#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "╔═══════════════════════════════════════════════════╗"
echo "║  UMTP Phase 1: Global Refactor UAT → LOS         ║"
echo "╚═══════════════════════════════════════════════════╝"

# ── Step 1: Update Cargo.toml files ──
echo ""
echo "📦 Updating Cargo.toml files..."

for f in $(find . -name "Cargo.toml" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's|crates/uat-core|crates/los-core|g' \
    -e 's|crates/uat-crypto|crates/los-crypto|g' \
    -e 's|crates/uat-consensus|crates/los-consensus|g' \
    -e 's|crates/uat-network|crates/los-network|g' \
    -e 's|crates/los-node|crates/los-node|g' \
    -e 's|crates/uat-vm|crates/los-vm|g' \
    -e 's|crates/los-cli|crates/los-cli|g' \
    -e 's|../uat-core|../los-core|g' \
    -e 's|../uat-crypto|../los-crypto|g' \
    -e 's|../uat-consensus|../los-consensus|g' \
    -e 's|../uat-network|../los-network|g' \
    -e 's|../los-node|../los-node|g' \
    -e 's|../uat-vm|../los-vm|g' \
    -e 's|../los-cli|../los-cli|g' \
    -e 's|name = "uat-core"|name = "los-core"|g' \
    -e 's|name = "uat-crypto"|name = "los-crypto"|g' \
    -e 's|name = "uat-consensus"|name = "los-consensus"|g' \
    -e 's|name = "uat-network"|name = "los-network"|g' \
    -e 's|name = "los-node"|name = "los-node"|g' \
    -e 's|name = "uat-vm"|name = "los-vm"|g' \
    -e 's|name = "los-cli"|name = "los-cli"|g' \
    -e 's|uat-core = |los-core = |g' \
    -e 's|uat-crypto = |los-crypto = |g' \
    -e 's|uat-consensus = |los-consensus = |g' \
    -e 's|uat-network = |los-network = |g' \
    -e 's|uat-vm = |los-vm = |g' \
    -e 's|los-cli = |los-cli = |g' \
    -e 's|uat-core/mainnet|los-core/mainnet|g' \
    "$f"
  echo "  ✅ $f"
done

# ── Step 2: Update Rust source files — crate imports ──
echo ""
echo "🔄 Updating Rust crate imports (uat_ → los_)..."

for f in $(find . -name "*.rs" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's/uat_core/los_core/g' \
    -e 's/uat_crypto/los_crypto/g' \
    -e 's/uat_consensus/los_consensus/g' \
    -e 's/uat_network/los_network/g' \
    -e 's/uat_node/los_node/g' \
    -e 's/uat_vm/los_vm/g' \
    -e 's/uat_cli/los_cli/g' \
    "$f"
done
echo "  ✅ Crate imports updated"

# ── Step 3: Update Rust source — VOID → CIL, UAT → LOS constants ──
echo ""
echo "🔄 Updating constants (VOID→CIL, UAT→LOS)..."

for f in $(find . -name "*.rs" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's/CIL_PER_LOS/CIL_PER_LOS/g' \
    -e 's/MIN_VALIDATOR_STAKE_VOID/MIN_VALIDATOR_STAKE_CIL/g' \
    -e 's/BASE_FEE_VOID/BASE_FEE_CIL/g' \
    -e 's/VALIDATOR_REWARD_POOL_VOID/VALIDATOR_REWARD_POOL_CIL/g' \
    -e 's/REWARD_RATE_INITIAL_VOID/REWARD_RATE_INITIAL_CIL/g' \
    -e 's/remaining_void/remaining_cil/g' \
    -e 's/total_distributed_void/total_distributed_cil/g' \
    -e 's/cumulative_rewards_void/cumulative_rewards_cil/g' \
    -e 's/stake_cil/stake_cil/g' \
    -e 's/balance_cil/balance_cil/g' \
    -e 's/epoch_reward_rate_void/epoch_reward_rate_cil/g' \
    -e 's/accumulated_fees_void/accumulated_fees_cil/g' \
    -e 's/remaining_supply_cil/remaining_supply_cil/g' \
    -e 's/TOTAL_SUPPLY_UAT/TOTAL_SUPPLY_LOS/g' \
    -e 's/TOTAL_SUPPLY_VOID/TOTAL_SUPPLY_CIL/g' \
    -e 's/TESTNET_INITIAL_BALANCE/TESTNET_INITIAL_BALANCE/g' \
    -e 's/MIN_TX_FEE_VOID/MIN_TX_FEE_CIL/g' \
    -e 's/MAX_MINT_PER_BLOCK/MAX_MINT_PER_BLOCK/g' \
    -e 's/pool_exhaustion_pct/pool_exhaustion_bps/g' \
    "$f"
done
echo "  ✅ Constants updated"

# ── Step 4: Update display/doc strings ──
echo ""
echo "🔄 Updating display strings..."

for f in $(find . -name "*.rs" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's/UAT Blockchain/LOS Blockchain/g' \
    -e 's/Unauthority (UAT)/Unauthority (LOS)/g' \
    -e 's/1 UAT/1 LOS/g' \
    -e 's/VOID units/CIL units/g' \
    -e 's/VOID (de/CIL (de/g' \
    -e 's/VOID (/CIL (/g' \
    -e 's/in VOID/in CIL/g' \
    -e 's/500,000 UAT/500,000 LOS/g' \
    -e 's/5,000 LOS/5,000 LOS/g' \
    -e 's/1000 LOS/1000 LOS/g' \
    -e 's/1,000 LOS/1,000 LOS/g' \
    -e 's/amount {} VOID/amount {} CIL/g' \
    -e 's/{} VOID/{} CIL/g' \
    -e 's/needs {} VOID/needs {} CIL/g' \
    -e 's|// VOID|// CIL|g' \
    -e 's/ UAT / LOS /g' \
    -e 's/ UAT,/ LOS,/g' \
    -e 's/ UAT)/ LOS)/g' \
    -e 's/ UAT"/ LOS"/g' \
    -e 's/ UAT\./ LOS./g' \
    -e 's/"UAT /"LOS /g' \
    -e 's/ UAT\// LOS\//g' \
    "$f"
done
echo "  ✅ Display strings updated"

# ── Step 5: Update struct/type names ──  
echo ""
echo "🔄 Updating struct/type names..."

for f in $(find . -name "*.rs" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's/UatBehaviour/LosBehaviour/g' \
    -e 's/UatNode/LosNode/g' \
    -e 's/UatDatabase/LosDatabase/g' \
    -e 's/LosMetrics/LosMetrics/g' \
    -e 's/uat-blocks/los-blocks/g' \
    -e 's/uat-mainnet/los-mainnet/g' \
    -e 's/uat-testnet/los-testnet/g' \
    -e 's/UAT_BOOTSTRAP/LOS_BOOTSTRAP/g' \
    -e 's/UAT_TOR/LOS_TOR/g' \
    -e 's/UAT_BIND/LOS_BIND/g' \
    -e 's/UAT_API/LOS_API/g' \
    -e 's/UAT_TESTNET/LOS_TESTNET/g' \
    -e 's/UAT_DATA/LOS_DATA/g' \
    -e 's/UAT_P2P/LOS_P2P/g' \
    -e 's/UAT_GRPC/LOS_GRPC/g' \
    -e 's/UAT_GENESIS/LOS_GENESIS/g' \
    -e 's/UAT_ORACLE/LOS_ORACLE/g' \
    -e 's/uat_database/los_database/g' \
    "$f"
done
echo "  ✅ Struct/type names updated"

# ── Step 6: Update address prefix in crypto ──
echo ""
echo "🔄 Updating address prefix (UAT → LOS)..."

for f in $(find . -name "*.rs" -not -path "*/target/*" -not -path "*/node_modules/*"); do
  sed -i '' \
    -e 's/starts_with("LOS")/starts_with("LOS")/g' \
    -e 's/"UAT ORACLE/"LOS ORACLE/g' \
    "$f"
done
echo "  ✅ Address prefix updated"

# ── Step 7: Update binary name in uat-vm ──
echo ""
echo "🔄 Updating binary names..."
if [ -f "crates/los-vm/Cargo.toml" ]; then
  sed -i '' 's|name = "uat-vm"|name = "los-vm"|g' crates/los-vm/Cargo.toml
fi
echo "  ✅ Binary names updated"

# ── Step 8: Rename node binary references ──
echo ""
echo "🔄 Updating los-node binary reference..."
grep -rl 'los-node' . --include="*.sh" --include="*.py" --include="*.toml" --include="*.yml" --include="*.yaml" --include="*.json" --include="*.md" --include="Dockerfile" 2>/dev/null | grep -v target | grep -v node_modules | while read f; do
  sed -i '' 's/los-node/los-node/g' "$f" 2>/dev/null || true
done
echo "  ✅ Binary references updated"

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  ✅ PHASE 1 COMPLETE — Refactor Applied           ║"
echo "╚═══════════════════════════════════════════════════╝"
