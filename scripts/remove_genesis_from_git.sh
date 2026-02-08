#!/bin/bash
# Remove genesis_config.json from git history
# WARNING: This rewrites git history - coordinate with any collaborators first!

set -e

cd "$(dirname "$0")/.."

echo "🔒 SECURITY FIX: Removing genesis_config.json from git history"
echo ""
echo "⚠️  This will rewrite git history!"
echo "⚠️  Any active clones will need to be re-cloned"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "📊 Current status:"
git log --all --oneline -- "*genesis_config.json" | head -5

echo ""
echo "🔧 Removing from history..."

# Method 1: git filter-branch (available on all git installations)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch genesis_config.json genesis/genesis_config.json' \
  --prune-empty --tag-name-filter cat -- --all

echo ""
echo "✅ Removed from git history!"
echo ""
echo "📊 Verification (should be empty):"
git log --all --oneline -- "*genesis_config.json" | head -5 || echo "✅ No commits found - successfully removed!"

echo ""
echo "🚀 Next steps:"
echo "1. Review changes: git log --oneline | head -10"
echo "2. Force push to remote: git push origin --force --all"
echo "3. Force push tags: git push origin --force --tags"
echo ""
echo "⚠️  WARNING: Collaborators must re-clone the repository!"
