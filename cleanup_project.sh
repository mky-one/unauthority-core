#!/bin/bash
# Unauthority Project Cleanup Script
# Date: February 5, 2026
# Purpose: Remove duplicates, organize structure, prepare for GitHub public release

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   UNAUTHORITY - PROJECT CLEANUP & REORGANIZATION          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 1: CREATE DIRECTORY STRUCTURE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📂 Phase 1: Creating directory structure..."

mkdir -p docs/user
mkdir -p docs/developer
mkdir -p docs/internal
mkdir -p scripts

echo "   ✓ Created docs/{user,developer,internal}"
echo "   ✓ Created scripts/"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 2: MOVE USER DOCUMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "📚 Phase 2: Moving user documentation..."

# Move user-facing docs (if they exist)
[ -f "QUICKSTART.md" ] && mv QUICKSTART.md docs/user/ && echo "   ✓ Moved QUICKSTART.md"
[ -f "LAUNCH_GUIDE.md" ] && mv LAUNCH_GUIDE.md docs/user/ && echo "   ✓ Moved LAUNCH_GUIDE.md"
[ -f "TESTNET_LAUNCH.md" ] && mv TESTNET_LAUNCH.md docs/user/ && echo "   ✓ Moved TESTNET_LAUNCH.md"
[ -f "WALLET_TESTING_GUIDE.md" ] && mv WALLET_TESTING_GUIDE.md docs/user/ && echo "   ✓ Moved WALLET_TESTING_GUIDE.md"
[ -f "VALIDATOR_SETUP_GUIDE.md" ] && mv VALIDATOR_SETUP_GUIDE.md docs/user/ && echo "   ✓ Moved VALIDATOR_SETUP_GUIDE.md"
[ -f "WALLET_COMPLETE.md" ] && mv WALLET_COMPLETE.md docs/user/ && echo "   ✓ Moved WALLET_COMPLETE.md"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 3: MOVE DEVELOPER DOCUMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "👨‍💻 Phase 3: Moving developer documentation..."

[ -f "FRONTEND_ARCHITECTURE.md" ] && mv FRONTEND_ARCHITECTURE.md docs/developer/ && echo "   ✓ Moved FRONTEND_ARCHITECTURE.md"
[ -f "DEPLOYMENT_INSTRUCTIONS.md" ] && mv DEPLOYMENT_INSTRUCTIONS.md docs/developer/ && echo "   ✓ Moved DEPLOYMENT_INSTRUCTIONS.md"
[ -f "ORACLE_CONSENSUS_INTEGRATION.md" ] && mv ORACLE_CONSENSUS_INTEGRATION.md docs/developer/ && echo "   ✓ Moved ORACLE_CONSENSUS_INTEGRATION.md"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 4: MOVE INTERNAL DOCUMENTATION (WILL BE GITIGNORED)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "🔒 Phase 4: Moving internal documentation..."

[ -f "GITHUB_RELEASE_v1.0.0.md" ] && mv GITHUB_RELEASE_v1.0.0.md docs/internal/ && echo "   ✓ Moved GITHUB_RELEASE_v1.0.0.md"
[ -f "SEND_LIMITATION.md" ] && mv SEND_LIMITATION.md docs/internal/ && echo "   ✓ Moved SEND_LIMITATION.md"
[ -f "VALIDATOR_ADDRESSES.md" ] && mv VALIDATOR_ADDRESSES.md docs/internal/ && echo "   ✓ Moved VALIDATOR_ADDRESSES.md"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 5: DELETE DUPLICATE/INTERNAL DOCUMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "🗑️  Phase 5: Deleting duplicate/internal documentation..."

rm -f API_AUDIT.md && echo "   ✓ Deleted API_AUDIT.md"
rm -f BUG_FIXES_SUMMARY.md && echo "   ✓ Deleted BUG_FIXES_SUMMARY.md"
rm -f COMPLETION_SUMMARY.md && echo "   ✓ Deleted COMPLETION_SUMMARY.md"
rm -f DOCUMENTATION_UPDATE_SUMMARY.txt && echo "   ✓ Deleted DOCUMENTATION_UPDATE_SUMMARY.txt"
rm -f FIX_1_DYNAMIC_VALIDATOR_ADDRESSES.md && echo "   ✓ Deleted FIX_1_DYNAMIC_VALIDATOR_ADDRESSES.md"
rm -f FIX_2_SLASHING_INTEGRATION.md && echo "   ✓ Deleted FIX_2_SLASHING_INTEGRATION.md"
rm -f GENESIS_BIP39_COMPLETE.md && echo "   ✓ Deleted GENESIS_BIP39_COMPLETE.md"
rm -f GENESIS_IMPLEMENTATION_REPORT.md && echo "   ✓ Deleted GENESIS_IMPLEMENTATION_REPORT.md"
rm -f GENESIS_QUICK_START.md && echo "   ✓ Deleted GENESIS_QUICK_START.md"
rm -f GRPC_IMPLEMENTATION_REPORT.md && echo "   ✓ Deleted GRPC_IMPLEMENTATION_REPORT.md"
rm -f INTEGRATION_TESTS_COMPLETE.md && echo "   ✓ Deleted INTEGRATION_TESTS_COMPLETE.md"
rm -f PROJECT_CLEANUP_REPORT.md && echo "   ✓ Deleted PROJECT_CLEANUP_REPORT.md"
rm -f TASK_1_GENESIS_COMPLETION.md && echo "   ✓ Deleted TASK_1_GENESIS_COMPLETION.md"
rm -f TASK_2_VALIDATOR_REWARDS_COMPLETE.md && echo "   ✓ Deleted TASK_2_VALIDATOR_REWARDS_COMPLETE.md"
rm -f TASK_3_ANTI_WHALE_MECHANISMS_COMPLETE.md && echo "   ✓ Deleted TASK_3_ANTI_WHALE_MECHANISMS_COMPLETE.md"
rm -f USD_MIGRATION.md && echo "   ✓ Deleted USD_MIGRATION.md"
rm -f PRODUCTION_AUDIT_FINAL.md && echo "   ✓ Deleted PRODUCTION_AUDIT_FINAL.md"
rm -f PRODUCTION_READY_FINAL.md && echo "   ✓ Deleted PRODUCTION_READY_FINAL.md"
rm -f PRODUCTION_READY.md && echo "   ✓ Deleted PRODUCTION_READY.md"
rm -f PRIORITY_7_COMPLETE_SECURITY_AUDIT_PREP.md && echo "   ✓ Deleted PRIORITY_7_COMPLETE_SECURITY_AUDIT_PREP.md"
rm -f VALIDATOR_DASHBOARD_TODO.md && echo "   ✓ Deleted VALIDATOR_DASHBOARD_TODO.md"
rm -f PUBLIC_WALLET_TODO.md && echo "   ✓ Deleted PUBLIC_WALLET_TODO.md"
rm -f START_HERE.md && echo "   ✓ Deleted START_HERE.md"
rm -f TESTING_COMPLETE.md && echo "   ✓ Deleted TESTING_COMPLETE.md"
rm -f TESTNET_RESULTS.md && echo "   ✓ Deleted TESTNET_RESULTS.md"
rm -f QUICKSTART_UI.md && echo "   ✓ Deleted QUICKSTART_UI.md"
rm -f QUICK_COMMANDS.md && echo "   ✓ Deleted QUICK_COMMANDS.md"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 6: MOVE SCRIPTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "🔧 Phase 6: Moving scripts..."

# Move all .sh files to scripts/ (except cleanup_project.sh itself)
for file in *.sh; do
  if [ "$file" != "cleanup_project.sh" ] && [ -f "$file" ]; then
    mv "$file" scripts/ && echo "   ✓ Moved $file"
  fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 7: CREATE CONVENIENCE SYMLINKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "🔗 Phase 7: Creating convenience symlinks..."

# Remove old symlinks if exist
rm -f install.sh start.sh stop.sh

# Create new symlinks (check if target files exist first)
if [ -f "scripts/install_validator.sh" ]; then
  ln -s scripts/install_validator.sh install.sh
  echo "   ✓ Created install.sh → scripts/install_validator.sh"
elif [ -f "scripts/install_frontends.sh" ]; then
  ln -s scripts/install_frontends.sh install.sh
  echo "   ✓ Created install.sh → scripts/install_frontends.sh"
fi

if [ -f "scripts/launch_3_validators.sh" ]; then
  ln -s scripts/launch_3_validators.sh start.sh
  echo "   ✓ Created start.sh → scripts/launch_3_validators.sh"
elif [ -f "scripts/start_network.sh" ]; then
  ln -s scripts/start_network.sh start.sh
  echo "   ✓ Created start.sh → scripts/start_network.sh"
fi

if [ -f "scripts/stop_3_validators.sh" ]; then
  ln -s scripts/stop_3_validators.sh stop.sh
  echo "   ✓ Created stop.sh → scripts/stop_3_validators.sh"
elif [ -f "scripts/stop_network.sh" ]; then
  ln -s scripts/stop_network.sh stop.sh
  echo "   ✓ Created stop.sh → scripts/stop_network.sh"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 8: CLEAN EMPTY DIRECTORIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "🧹 Phase 8: Cleaning empty directories..."

# Find and remove empty directories (excluding target, node_modules, .git)
find . -type d -empty -not -path "./target/*" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "*/node_modules/*" -delete 2>/dev/null || true

echo "   ✓ Removed all empty directories"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 9: FINAL SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   ✅ CLEANUP COMPLETE                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Summary:"
echo "   • Moved documentation to docs/{user,developer,internal}"
echo "   • Deleted 26+ internal documentation files"
echo "   • Organized scripts into scripts/"
echo "   • Created convenience symlinks (install.sh, start.sh, stop.sh)"
echo "   • Removed all empty directories"
echo ""
echo "🔒 Next Steps:"
echo "   1. Verify .gitignore is up-to-date"
echo "   2. Run: git status"
echo "   3. Ensure sensitive files are NOT visible"
echo "   4. Commit: git add -A && git commit -m 'chore: project cleanup'"
echo ""
