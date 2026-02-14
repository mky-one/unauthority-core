#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# LOS Testnet — .onion Stress Test via SOCKS5
# Tests ALL requests through the Tor network (never localhost!)
# ═══════════════════════════════════════════════════════════════════════
set -e

SOCKS_PORT="${1:-9052}"
TOTAL="${2:-20}"   # Total requests to fire
CONCURRENCY="${3:-4}" # Max parallel

# 4 bootstrap .onion nodes
ONIONS=(
  "drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion"
  "kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion"
  "w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion"
  "xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion"
)

echo "═══════════════════════════════════════════════════════"
echo "  LOS .onion Stress Test  (SOCKS5 port $SOCKS_PORT)"
echo "  $TOTAL requests, max $CONCURRENCY concurrent"
echo "═══════════════════════════════════════════════════════"
echo ""

# Pre-flight: verify Tor SOCKS5 is alive
if ! curl -s --socks5-hostname 127.0.0.1:$SOCKS_PORT -m 10 "http://${ONIONS[0]}/health" >/dev/null 2>&1; then
  echo "❌ Pre-flight FAILED: Cannot reach ${ONIONS[0]} via SOCKS5 port $SOCKS_PORT"
  echo "   Is Tor running? Try: lsof -nP -i tcp:$SOCKS_PORT"
  exit 1
fi
echo "✅ Pre-flight OK — Tor SOCKS5 on port $SOCKS_PORT is alive"
echo ""

# Endpoints to test (mix of read-only and state queries)
ENDPOINTS=(
  "/health"
  "/node-info"
  "/validators"
  "/block"
  "/reward-info"
  "/health"
  "/supply"
  "/blocks/recent"
)

PASS=0
FAIL=0
TIMEOUT=0
TOTAL_MS=0
MAX_MS=0
MIN_MS=999999
RESULTS_DIR=$(mktemp -d)

echo "🚀 Starting $TOTAL requests across 4 .onion nodes..."
echo ""

START_TIME=$(date +%s)

fire_request() {
  local req_num=$1
  local onion_idx=$(( (req_num - 1) % 4 ))
  local ep_idx=$(( (req_num - 1) % ${#ENDPOINTS[@]} ))
  local onion="${ONIONS[$onion_idx]}"
  local endpoint="${ENDPOINTS[$ep_idx]}"
  local url="http://$onion$endpoint"
  local result_file="$RESULTS_DIR/r_$req_num"
  
  local start_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --socks5-hostname "127.0.0.1:$SOCKS_PORT" \
    -m 45 \
    "$url" 2>/dev/null || echo "000")
  local end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end_ms - start_ms ))
  
  if [ "$http_code" = "200" ]; then
    echo "  [$req_num/$TOTAL] ✅ $endpoint → $onion (${elapsed}ms)"
    echo "PASS $elapsed" > "$result_file"
  elif [ "$http_code" = "000" ]; then
    echo "  [$req_num/$TOTAL] ⏰ $endpoint → $onion (TIMEOUT)"
    echo "TIMEOUT 0" > "$result_file"
  else
    echo "  [$req_num/$TOTAL] ❌ $endpoint → $onion (HTTP $http_code, ${elapsed}ms)"
    echo "FAIL $elapsed" > "$result_file"
  fi
}

# Fire requests in batches of $CONCURRENCY
for (( i=1; i<=TOTAL; i+=CONCURRENCY )); do
  pids=()
  for (( j=0; j<CONCURRENCY && (i+j)<=TOTAL; j++ )); do
    fire_request $((i + j)) &
    pids+=($!)
  done
  # Wait for batch to complete
  for pid in "${pids[@]}"; do
    wait $pid 2>/dev/null || true
  done
done

END_TIME=$(date +%s)
WALL_CLOCK=$(( END_TIME - START_TIME ))

# Collect results
for f in "$RESULTS_DIR"/r_*; do
  [ -f "$f" ] || continue
  read status ms < "$f"
  case "$status" in
    PASS)
      PASS=$((PASS + 1))
      TOTAL_MS=$((TOTAL_MS + ms))
      [ "$ms" -gt "$MAX_MS" ] && MAX_MS=$ms
      [ "$ms" -lt "$MIN_MS" ] && MIN_MS=$ms
      ;;
    FAIL) FAIL=$((FAIL + 1)) ;;
    TIMEOUT) TIMEOUT=$((TIMEOUT + 1)) ;;
  esac
done

rm -rf "$RESULTS_DIR"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RESULTS — .onion Stress Test"
echo "═══════════════════════════════════════════════════════"
echo "  Total:     $TOTAL requests"
echo "  Passed:    $PASS ✅"
echo "  Failed:    $FAIL ❌"
echo "  Timeout:   $TIMEOUT ⏰"
echo "  Wall time: ${WALL_CLOCK}s"

if [ "$PASS" -gt 0 ]; then
  AVG_MS=$((TOTAL_MS / PASS))
  echo "  Avg RTT:   ${AVG_MS}ms"
  echo "  Min RTT:   ${MIN_MS}ms"
  echo "  Max RTT:   ${MAX_MS}ms"
fi
echo "═══════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ] || [ "$TIMEOUT" -gt 0 ]; then
  echo "⚠️  Some requests failed — review above for details"
  exit 1
else
  echo "🎉 ALL $TOTAL requests succeeded via .onion!"
  exit 0
fi
