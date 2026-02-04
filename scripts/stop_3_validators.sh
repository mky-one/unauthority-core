#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         STOPPING ALL VALIDATOR NODES                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

STOPPED=0
FAILED=0

for i in 1 2 3; do
    if [ -f node_data/validator-$i/pid.txt ]; then
        PID=$(cat node_data/validator-$i/pid.txt)
        if kill -0 $PID 2>/dev/null; then
            kill $PID 2>/dev/null
            echo "✅ Stopped Validator-$i (PID: $PID)"
            STOPPED=$((STOPPED+1))
        else
            echo "⚠️  Validator-$i (PID: $PID) - already stopped"
        fi
        rm node_data/validator-$i/pid.txt
    else
        echo "⚠️  Validator-$i - no PID file found"
        FAILED=$((FAILED+1))
    fi
done

echo ""
if [ $STOPPED -gt 0 ]; then
    echo "✅ Stopped $STOPPED validator(s)"
fi

if [ $FAILED -gt 0 ]; then
    echo "⚠️  $FAILED validator(s) had no PID file"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
