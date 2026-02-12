#!/usr/bin/env bash
# stop.sh — Stop all running Unauthority validator nodes
# Reads PID files from node_data/v*/pid.txt

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
STOPPED=0

for i in 1 2 3 4; do
    PID_FILE="$BASE_DIR/node_data/v${i}/pid.txt"

    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "🛑 Stopped validator $i (PID $PID)"
            STOPPED=$((STOPPED + 1))
        else
            echo "⏭️  Validator $i not running (stale PID $PID)"
        fi
        rm -f "$PID_FILE"
    else
        echo "⏭️  Validator $i — no PID file found"
    fi
done

if [[ $STOPPED -eq 0 ]]; then
    echo "ℹ️  No running validators found"
else
    echo "✅ Stopped $STOPPED validator(s)"
fi
