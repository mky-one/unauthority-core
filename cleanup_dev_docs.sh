#!/bin/bash

echo "🗑️  Cleaning up dev-only documentation..."

# List of dev-only docs to remove
rm -f docs/INSTALLER_STRATEGY.md
rm -f docs/INSTALLER_BUILD_GUIDE.md
rm -f docs/FAQ_INSTALLER.md
rm -f docs/TESTNET_VS_MAINNET.md
rm -f docs/REMOTE_TESTNET_GUIDE.md
rm -f docs/AUDITOR_CODE_WALKTHROUGH.md
rm -f docs/SECURITY_AUDIT_PREPARATION.md
rm -f docs/ECONOMIC_SECURITY_REVIEW.md
rm -f docs/ATTACK_SURFACE_ANALYSIS.md
rm -f docs/KNOWN_RISKS_AND_MITIGATIONS.md
rm -f docs/user/LAUNCH_GUIDE.md
rm -f docs/user/WALLET_COMPLETE.md
rm -f docs/user/TESTNET_LAUNCH.md
rm -f scripts/STATUS.sh
rm -f scripts/QUICKSTART.sh

echo "✅ Dev docs removed. Keeping only:"
echo "   - README.md (main project overview)"
echo "   - API_REFERENCE.md (public API docs)"
echo "   - API_EXAMPLES.md (usage examples)"
echo "   - WHITEPAPER.md (technical whitepaper)"
echo "   - TESTNET_OPERATION.md (testnet guide)"
echo "   - INSTALLATION.md (installation guide)"
echo "   - DOCKER_DEPLOYMENT.md (deployment guide)"

# Update .gitignore to prevent re-adding
if ! grep -q "# Dev-only documentation" .gitignore; then
    cat >> .gitignore << 'EOF'

# Dev-only documentation (not for public repo)
**/INSTALLER_*.md
**/FAQ_*.md
**/LAUNCH_GUIDE.md
**/WALLET_COMPLETE.md
**/TESTNET_VS_MAINNET.md
**/REMOTE_TESTNET_GUIDE.md
**/AUDITOR_CODE_WALKTHROUGH.md
**/SECURITY_AUDIT_PREPARATION.md
**/ECONOMIC_SECURITY_REVIEW.md
**/ATTACK_SURFACE_ANALYSIS.md
**/KNOWN_RISKS_AND_MITIGATIONS.md
**/STATUS.sh
**/QUICKSTART.sh
EOF
    echo "✅ .gitignore updated to prevent re-adding dev docs"
else
    echo "ℹ️  .gitignore already configured"
fi

echo ""
echo "✅ Cleanup complete!"
