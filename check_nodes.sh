#!/bin/bash
sleep 3
for port in 3030 3031 3032 3033; do
  echo -n "V$((port-3029)): "
  curl -s http://localhost:$port/health | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'],d['version'],d['chain']['blocks'])" 2>/dev/null || echo "DOWN"
done
