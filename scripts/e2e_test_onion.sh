#!/bin/bash
# Comprehensive E2E API Test via Tor .onion
ONION="ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion"
S="--socks5-hostname 127.0.0.1:9050"
PASS=0; FAIL=0; BUGS=""

check() {
  local name="$1" result="$2" expect="$3"
  if echo "$result" | grep -q "$expect"; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name → GOT: $result"
    FAIL=$((FAIL+1))
    BUGS="$BUGS\n❌ $name: $result"
  fi
}

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  LOS COMPREHENSIVE E2E TEST VIA TOR .ONION           ║"
echo "╚═══════════════════════════════════════════════════════╝"

echo ""
echo "=== SECTION 1: READ APIs ==="

R=$(curl -s $S "http://$ONION/" 2>/dev/null)
check "GET / (API root)" "$(echo $R | python3 -c 'import sys,json; print(json.load(sys.stdin).get("name",""))' 2>/dev/null)" "Unauthority"

R=$(curl -s $S "http://$ONION/node-info" 2>/dev/null)
check "GET /node-info" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("version",""))' 2>/dev/null)" "1.0"

R=$(curl -s $S "http://$ONION/health" 2>/dev/null)
check "GET /health" "$(echo $R | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))' 2>/dev/null)" "healthy"

R=$(curl -s $S "http://$ONION/balance/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /balance/{addr}" "$(echo $R | python3 -c 'import sys,json; print(json.load(sys.stdin).get("balance_los","")[:4])' 2>/dev/null)" "5000"

R=$(curl -s $S "http://$ONION/bal/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /bal/{addr}" "$(echo $R | python3 -c 'import sys,json; print(json.load(sys.stdin).get("balance_los","")[:4])' 2>/dev/null)" "5000"

R=$(curl -s $S "http://$ONION/supply" 2>/dev/null)
check "GET /supply" "$(echo $R | python3 -c 'import sys,json; print("OK" if float(json.load(sys.stdin).get("remaining_supply","0").strip()) > 0 else "EMPTY")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/peers" 2>/dev/null)
check "GET /peers" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("peer_count",0))' 2>/dev/null)" "3"

R=$(curl -s $S "http://$ONION/validators" 2>/dev/null)
check "GET /validators" "$(echo $R | python3 -c 'import sys,json; print("OK" if "validators" in json.load(sys.stdin) else "MISSING")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/consensus" 2>/dev/null)
check "GET /consensus" "$(echo $R | python3 -c 'import sys,json; print(json.load(sys.stdin).get("is_safe",""))' 2>/dev/null)" "true"

R=$(curl -s $S "http://$ONION/metrics" 2>/dev/null)
check "GET /metrics" "$(echo $R | head -1 | grep -c 'los_')" "1"

R=$(curl -s $S "http://$ONION/whoami" 2>/dev/null)
check "GET /whoami" "$(echo $R | python3 -c 'import sys,json; print("OK" if json.load(sys.stdin).get("address","").startswith("LOS") else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/history/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /history/{addr}" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "history" in d or "transactions" in d else "MISSING")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/account/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /account/{addr}" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "balance" in str(d) else "MISSING")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/blocks/recent" 2>/dev/null)
check "GET /blocks/recent" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if isinstance(d, list) or "blocks" in d else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/block" 2>/dev/null)
check "GET /block (latest)" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "block_type" in str(d) or "account" in str(d) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/slashing" 2>/dev/null)
check "GET /slashing" "$(echo $R | python3 -c 'import sys,json; print("OK" if isinstance(json.load(sys.stdin), dict) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/fee-estimate/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /fee-estimate/{addr}" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "fee_multiplier" in d or "multiplier" in str(d) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/reward-info" 2>/dev/null)
check "GET /reward-info" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "epoch" in str(d) or "reward" in str(d).lower() else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/network/peers" 2>/dev/null)
check "GET /network/peers" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if isinstance(d, (list, dict)) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/mempool/stats" 2>/dev/null)
check "GET /mempool/stats" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if isinstance(d, dict) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/search/LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8" 2>/dev/null)
check "GET /search/{query}" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if isinstance(d, dict) else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/sync?blocks=0" 2>/dev/null)
check "GET /sync" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "blocks" in d or "accounts" in d else "BAD")' 2>/dev/null)" "OK"

echo ""
echo "=== SECTION 2: EDGE CASES ==="

R=$(curl -s $S "http://$ONION/balance/INVALID_ADDRESS" 2>/dev/null)
check "Balance invalid addr" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("balance_los","0")[:1])' 2>/dev/null)" "0"

R=$(curl -s $S "http://$ONION/balance/LOSWs5d47nNq1ZKHehwG7R59JTambEYFNvy2TEXTRA" 2>/dev/null)
check "Balance extra chars" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "error" in str(d).lower() or d.get("balance_los","0").startswith("0") else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S -X POST "http://$ONION/send" -H 'Content-Type: application/json' -d '{}' 2>/dev/null)
check "Send empty body" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if d.get("status")=="error" or d.get("code",0)>=400 else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S -X POST "http://$ONION/burn" -H 'Content-Type: application/json' -d '{}' 2>/dev/null)
check "Burn empty body" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if d.get("status")=="error" or d.get("code",0)>=400 else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S -X POST "http://$ONION/send" -H 'Content-Type: application/json' -d '{"target":"LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8","amount":0}' 2>/dev/null)
check "Send 0 amount" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if d.get("status")=="error" or "0" in d.get("msg","") else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S -X POST "http://$ONION/send" -H 'Content-Type: application/json' -d '{"target":"LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8","amount":-10}' 2>/dev/null)
check "Send negative amount" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if d.get("status")=="error" or d.get("code",0)>=400 else "BAD")' 2>/dev/null)" "OK"

R=$(curl -s $S -X POST "http://$ONION/send" -H 'Content-Type: application/json' -d '{"target":"LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8","amount":999999999}' 2>/dev/null)
check "Send > balance" "$(echo $R | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if "error" in str(d.get("status","")).lower() or "insufficient" in str(d).lower() else "BAD: "+str(d))' 2>/dev/null)" "OK"

R=$(curl -s $S "http://$ONION/nonexistent-endpoint" 2>/dev/null)
check "404 nonexistent" "$(echo $R | python3 -c 'import sys; r=sys.stdin.read(); print("OK" if "404" in r or "Not Found" in r or len(r)==0 else "BAD: "+r[:80])' 2>/dev/null)" "OK"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RESULTS: $PASS PASS / $FAIL FAIL"
echo "═══════════════════════════════════════════════════════"
if [ $FAIL -gt 0 ]; then
  echo "BUGS FOUND:"
  echo -e "$BUGS"
fi
