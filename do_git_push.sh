#!/bin/bash
set -e
cd "$(dirname "$0")"

# Check if we need to add files
STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
if [ "$STAGED" -eq "0" ]; then
    echo "Staging all files..."
    git add -A
fi

# Check if there's a pending commit or we need to reset
LOG=$(git log --oneline -1 2>/dev/null || echo "")
if echo "$LOG" | grep -q "refactor: complete"; then
    echo "Previous commit exists, resetting..."
    git reset HEAD~
    git add -A
fi

# Commit using file
echo "Committing..."
git commit -F .git_commit_msg

echo "Commit done!"
git log --oneline -1

# Push to branch
echo "Pushing to mky-one-uat-to-los..."
git push -u origin mky-one-uat-to-los

echo "Push done!"
rm -f .git_commit_msg
