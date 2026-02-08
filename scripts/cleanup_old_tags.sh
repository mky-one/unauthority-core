#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# CLEANUP OLD RELEASE TAGS
# ══════════════════════════════════════════════════════════════════════════════
# Removes old release tags (local + remote) that are no longer used.
# The new release system uses 'v*-testnet' tags only.
#
# Usage:
#   ./scripts/cleanup_old_tags.sh          # Dry run (show what would be deleted)
#   ./scripts/cleanup_old_tags.sh --force  # Actually delete tags
# ══════════════════════════════════════════════════════════════════════════════

set -e

DRY_RUN=true
if [ "${1}" = "--force" ]; then
    DRY_RUN=false
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🏷️  Tag Cleanup — Old Release Tags"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Tags to remove (old production/generic tags)
OLD_TAGS=(
    "v1.0.0"
    "v1.0.0-testnet"
    "v1.0.1-production"
    "v1.0.7-production"
    "v1.0.8-production"
    "v1.0.9-production"
)

echo "Tags to remove:"
for tag in "${OLD_TAGS[@]}"; do
    if git tag -l "$tag" | grep -q .; then
        echo "  🏷️  $tag (exists locally)"
    else
        echo "  ⏭️  $tag (not found locally, will try remote)"
    fi
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN — no tags will be deleted."
    echo "   Run with --force to actually delete tags:"
    echo "   ./scripts/cleanup_old_tags.sh --force"
    echo ""
    exit 0
fi

echo "🗑️  Deleting tags..."
echo ""

for tag in "${OLD_TAGS[@]}"; do
    # Delete local tag
    if git tag -l "$tag" | grep -q .; then
        git tag -d "$tag" 2>/dev/null && echo "  ✅ Deleted local tag: $tag" || true
    fi

    # Delete remote tag
    git push origin ":refs/tags/$tag" 2>/dev/null && echo "  ✅ Deleted remote tag: $tag" || echo "  ⏭️  Remote tag $tag not found or already deleted"
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Cleanup complete"
echo ""
echo "  To create a new testnet release, run:"
echo "    git tag v1.0.0-testnet.1"
echo "    git push origin v1.0.0-testnet.1"
echo ""
echo "  This triggers the GitHub Action to build installers for"
echo "  macOS, Linux, and Windows automatically."
echo "═══════════════════════════════════════════════════════════════"
