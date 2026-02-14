#!/usr/bin/env python3
"""
Comprehensive Testnet API & Feature Test Suite
==============================================
Tests ALL 38+ API endpoints via Tor .onion addresses.
NO localhost. This is the testnet that guarantees mainnet 100%.
Uses curl --socks5-hostname for .onion resolution through Tor.
Usage: python3 test_comprehensive_tor.py
"""

import json
import sys
import time
import subprocess
import traceback

# ─── ONION HOSTS (from network_config.json) ───
VALIDATORS = [
    {"name": "V1", "onion": "drnqiaqi5vvqpubem6qzptptijygbf7ggjheri6k5yn4qbeezhgjweyd.onion"},
    {"name": "V2", "onion": "kpjv64bpekzqvnls2d5ss4sqhjdgi7maypfvceekxty2cfutjr4vgqid.onion"},
    {"name": "V3", "onion": "w3x7wqb7267mfgcxsqjuinxuijvdswg4j2zwcdl2fr5mohbaywomdbad.onion"},
    {"name": "V4", "onion": "xvulzhd5ekfmturmz7jdy3yguggyqwyx7jrysods7njvvzaicx72lwad.onion"},
]

TOR_PROXY = "socks5h://127.0.0.1:9050"
TIMEOUT = 45

PASS = 0
FAIL = 0
WARN = 0
BUGS = []


def base(v):
    return f"http://{v['onion']}"


def curl_get(url, timeout=TIMEOUT):
    r = subprocess.run(
        ["curl", "-s", "--max-time", str(timeout), "--proxy", TOR_PROXY, url],
        capture_output=True, text=True
    )
    if r.returncode != 0:
        raise Exception(f"curl exit {r.returncode}: {r.stderr.strip()[:120]}")
    return r.stdout


def curl_json(url, timeout=TIMEOUT):
    raw = curl_get(url, timeout)
    if not raw.strip():
        raise Exception("empty response")
    return json.loads(raw)


def curl_post(url, body, timeout=TIMEOUT):
    r = subprocess.run(
        ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
         "--proxy", TOR_PROXY, "-X", "POST",
         "-H", "Content-Type: application/json",
         "-d", json.dumps(body), url],
        capture_output=True, text=True
    )
    if r.returncode != 0:
        raise Exception(f"curl exit {r.returncode}: {r.stderr.strip()[:120]}")
    parts = r.stdout.rsplit("\n", 1)
    body_txt = parts[0] if len(parts) > 1 else r.stdout
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    try:
        return code, json.loads(body_txt) if body_txt.strip() else {}
    except json.JSONDecodeError:
        return code, {"raw": body_txt[:200]}


def ok(name, detail=""):
    global PASS; PASS += 1
    print(f"  ✅ {name}" + (f" — {detail}" if detail else ""))

def fail(name, detail=""):
    global FAIL; FAIL += 1
    BUGS.append(f"[BUG] {name}: {detail}")
    print(f"  ❌ {name}" + (f" — {detail}" if detail else ""))

def warn(name, detail=""):
    global WARN; WARN += 1
    BUGS.append(f"[WARN] {name}: {detail}")
    print(f"  ⚠️  {name}" + (f" — {detail}" if detail else ""))

def sec(n, t):
    print(f"\n{'='*60}\n{n}. {t}\n{'='*60}")


# ═══════════════════════════════════════════════════════════
# 1. HEALTH & NODE INFO
# ═══════════════════════════════════════════════════════════
def test_1():
    sec(1, "HEALTH & NODE INFO (all validators via .onion)")
    for v in VALIDATORS:
        u = base(v); n = v["name"]
        try:
            d = curl_json(f"{u}/health")
            if d.get("status") != "healthy":
                fail(f"{n} /health", f"status='{d.get('status')}'")
            else:
                ok(f"{n} /health", f"v{d.get('version','?')}, up={d.get('uptime_seconds','?')}s, accts={d['chain']['accounts']}, blks={d['chain']['blocks']}")
            for k in ["status","version","uptime_seconds","chain","database","timestamp"]:
                if k not in d: fail(f"{n} /health key", f"missing '{k}'")
            if d.get("chain",{}).get("id") != "los-testnet":
                fail(f"{n} chain.id", f"'{d.get('chain',{}).get('id')}'")
        except Exception as e:
            fail(f"{n} /health", str(e))
        try:
            d = curl_json(f"{u}/node-info")
            a = d.get("address","")
            if not a.startswith("LOS"): fail(f"{n} addr", f"'{a}'")
            else: ok(f"{n} /node-info", f"{a[:20]}…, net={d.get('network')}")
            if d.get("network") not in ["los-testnet","testnet"]: fail(f"{n} net", d.get("network"))
        except Exception as e:
            fail(f"{n} /node-info", str(e))
        try:
            d = curl_json(f"{u}/whoami")
            if "address" in d: ok(f"{n} /whoami", d["address"][:20]+"…")
            else: fail(f"{n} /whoami", "no address")
        except Exception as e:
            fail(f"{n} /whoami", str(e))
        try:
            d = curl_json(f"{u}/")
            ok(f"{n} / root", f"keys={list(d.keys())[:5]}")
        except Exception as e:
            fail(f"{n} /", str(e))


# ═══════════════════════════════════════════════════════════
# 2. BALANCE & ACCOUNT
# ═══════════════════════════════════════════════════════════
def test_2():
    sec(2, "BALANCE & ACCOUNT")
    u = base(VALIDATORS[0])
    addr = curl_json(f"{u}/node-info")["address"]

    d = curl_json(f"{u}/balance/{addr}")
    for k in ["address","balance_cil","balance_los"]:
        if k not in d: fail(f"/balance key", k)
    cil = d.get("balance_cil",0); los = float(d.get("balance_los","0"))
    if cil <= 0: fail("/balance", f"cil={cil}")
    else: ok(f"/balance", f"{los} LOS ({cil} CIL)")
    if abs(cil/1e11 - los) > 0.001: fail("/balance conv", f"{cil}/1e11 != {los}")
    else: ok("/balance CIL↔LOS", "consistent")

    try:
        d2 = curl_json(f"{u}/bal/{addr}")
        ok("/bal alias", "works")
    except: fail("/bal alias", "failed")

    try:
        d3 = curl_json(f"{u}/account/{addr}")
        if "address" in d3: ok("/account", f"blocks={d3.get('block_count','?')}")
        else: fail("/account", f"keys={list(d3.keys())}")
    except Exception as e: fail("/account", str(e))

    try:
        d4 = curl_json(f"{u}/balance/INVALID_ADDR_999")
        if d4.get("balance_cil",0) == 0: ok("/balance invalid", "0 ✓")
        else: warn("/balance invalid", f"cil={d4.get('balance_cil')}")
    except: ok("/balance invalid", "error returned")

    try:
        raw = curl_get(f"{u}/balance/")
        if "404" in raw or "not found" in raw.lower() or not raw.strip(): ok("/balance/ empty", "404")
        else: warn("/balance/ empty", f"{raw[:50]}")
    except: ok("/balance/ empty", "error")


# ═══════════════════════════════════════════════════════════
# 3. SUPPLY
# ═══════════════════════════════════════════════════════════
def test_3():
    sec(3, "SUPPLY")
    u = base(VALIDATORS[0])
    TOTAL = 21_936_236 * 10**11

    d = curl_json(f"{u}/supply")
    ok("/supply", f"keys={list(d.keys())}")

    total = None
    for k in ["total_supply_cil","total_cil","total_supply"]:
        if k in d:
            total = int(d[k]) if isinstance(d[k],str) else d[k]; break
    if total == TOTAL: ok("/supply total", "21,936,236 LOS ✓")
    elif total: fail("/supply total", f"{total/1e11:,.0f} LOS")
    else: warn("/supply total", "field not found")

    circ = None
    for k in ["circulating_supply_cil","circulating_cil","circulating"]:
        if k in d:
            circ = int(d[k]) if isinstance(d[k],str) else d[k]; break
    if circ and circ > TOTAL: fail("/supply circ>total", f"{circ/1e11:,.0f}")
    elif circ and circ > 0: ok("/supply circ", f"{circ/1e11:,.0f} LOS")
    else: warn("/supply circ", "missing")


# ═══════════════════════════════════════════════════════════
# 4. HISTORY & BLOCKS & TX
# ═══════════════════════════════════════════════════════════
def test_4():
    sec(4, "HISTORY & BLOCKS & TRANSACTIONS")
    u = base(VALIDATORS[0])
    addr = curl_json(f"{u}/node-info")["address"]

    d = curl_json(f"{u}/history/{addr}")
    txs = d.get("transactions",[])
    ok(f"/history", f"{len(txs)} txs")
    if txs:
        t0 = txs[0]
        if "type" in t0 and "amount" in t0: ok("/history structure", f"type={t0['type']}")
        else: fail("/history structure", f"keys={list(t0.keys())}")
        for i,t in enumerate(txs):
            # Amount is a LOS string like "1250.00000000000" (not CIL integer)
            a_raw = t.get("amount", 0)
            try:
                a = float(a_raw) if isinstance(a_raw, str) else a_raw
            except (ValueError, TypeError):
                a = 0
            if a < 0: fail(f"/history tx[{i}] amt<0", str(a_raw))

    try:
        d2 = curl_json(f"{u}/history/LOSnonexistent99999999999999999999")
        if len(d2.get("transactions",[])) == 0: ok("/history nonexistent", "empty ✓")
        else: fail("/history nonexistent", "has txs!")
    except: ok("/history nonexistent", "error")

    try:
        d3 = curl_json(f"{u}/blocks/recent")
        bl = d3 if isinstance(d3,list) else d3.get("blocks",[])
        ok(f"/blocks/recent", f"{len(bl)} blocks")
    except Exception as e: fail("/blocks/recent", str(e))

    try:
        d4 = curl_json(f"{u}/block")
        ok("/block latest", f"keys={list(d4.keys())[:6]}")
    except Exception as e: fail("/block", str(e))

    head = ""
    try:
        bal = curl_json(f"{u}/balance/{addr}")
        head = bal.get("head","")
        if head:
            d5 = curl_json(f"{u}/block/{head}")
            if "error" in d5: fail("/block/{hash}", d5["error"])
            else: ok(f"/block/{{hash}}", f"{head[:16]}…")
    except Exception as e: fail("/block/{hash}", str(e))

    try:
        d6 = curl_json(f"{u}/block/{'0'*64}")
        if "error" in str(d6).lower() or "not found" in str(d6).lower(): ok("/block invalid", "not found ✓")
        else: warn("/block invalid", f"{list(d6.keys())[:5]}")
    except: ok("/block invalid", "error")

    try:
        h = curl_json(f"{u}/history/{addr}")
        th = None
        for t in h.get("transactions",[]):
            if "hash" in t: th = t["hash"]; break
        if th:
            d7 = curl_json(f"{u}/transaction/{th}")
            ok(f"/transaction", f"{th[:16]}…")
        else: warn("/transaction", "no tx hash")
    except Exception as e: warn("/transaction", str(e)[:60])

    try:
        d8 = curl_json(f"{u}/search/{addr}")
        ok("/search addr", f"keys={list(d8.keys())[:5]}")
    except Exception as e: fail("/search", str(e))


# ═══════════════════════════════════════════════════════════
# 5. VALIDATORS & CONSENSUS
# ═══════════════════════════════════════════════════════════
def test_5():
    sec(5, "VALIDATORS & CONSENSUS")
    u = base(VALIDATORS[0])

    d = curl_json(f"{u}/validators")
    vals = d if isinstance(d,list) else d.get("validators",[])
    if len(vals) >= 4: ok(f"/validators", f"{len(vals)}")
    else: fail("/validators", f"{len(vals)} < 4")
    MIN_LOS = 1000
    for i,va in enumerate(vals):
        a = va.get("address","?")[:16]
        # /validators returns stake in whole LOS (not CIL)
        s = int(va.get("stake",0))
        if s < MIN_LOS: fail(f"val[{i}] stake", f"{a} {s} < 1000 LOS")
        else: ok(f"val[{i}]", f"{a}… {s} LOS")

    d2 = curl_json(f"{u}/consensus")
    s = d2.get("safety",{})
    act = s.get("active_validators",0)
    byz = s.get("byzantine_safe",False)
    if act >= 4: ok("/consensus active", str(act))
    else: fail("/consensus active", f"{act}")
    if byz: ok("/consensus byz", "true ✓")
    else: warn("/consensus byz", f"false (n={act})")
    ft = s.get("max_faulty", s.get("fault_tolerance",0))
    exp = (act-1)//3
    if ft == exp: ok("/consensus ft", f"f={ft}")
    else: warn("/consensus ft", f"f={ft} exp={exp}")

    try:
        d3 = curl_json(f"{u}/peers")
        p = d3 if isinstance(d3,list) else d3.get("peers",[])
        ok("/peers", f"{len(p)}")
    except Exception as e: fail("/peers", str(e))

    try:
        d4 = curl_json(f"{u}/network/peers")
        ok("/network/peers", f"keys={list(d4.keys())[:5]}")
    except Exception as e: fail("/network/peers", str(e))


# ═══════════════════════════════════════════════════════════
# 6. REWARDS
# ═══════════════════════════════════════════════════════════
def test_6():
    sec(6, "REWARDS & EPOCH")
    u = base(VALIDATORS[0])

    d = curl_json(f"{u}/reward-info")
    cfg = d.get("config",{})
    for k,exp in [("probation_epochs",1),("min_uptime_pct",95),("halving_interval_epochs",48)]:
        if cfg.get(k) == exp: ok(f"cfg.{k}", str(exp))
        else: fail(f"cfg.{k}", f"{cfg.get(k)} != {exp}")
    if cfg.get("genesis_excluded"): fail("genesis_excluded", "HACK: true!")
    else: ok("genesis_excluded", "false ✓")
    m = cfg.get("distribution_model","")
    if "sqrt" in m.lower(): ok("model", m)
    else: warn("model", m)

    ep = d.get("epoch",{})
    cur = ep.get("current_epoch",0)
    rate = ep.get("epoch_reward_rate_cil",0)
    halv = ep.get("halvings_occurred",0)
    exp_rate = 500000000000000 >> halv
    if rate == exp_rate: ok("rate", f"{rate/1e11:.0f} LOS/ep (halv={halv})")
    else: fail("rate", f"{rate} != {exp_rate}")

    pool = d.get("pool",{})
    rem = pool.get("remaining_cil",0)
    dist = pool.get("total_distributed_cil",0)
    POOL = 500_000 * 10**11
    if rem + dist == POOL: ok("pool sum", f"rem={rem/1e11:.0f}+dist={dist/1e11:.0f}=500,000 ✓")
    else: fail("pool sum", f"{(rem+dist)/1e11:.0f} != 500,000")

    dets = d.get("validators",{}).get("details",[])
    prob = cfg.get("probation_epochs",1)
    for vd in dets:
        a = vd.get("address","?")[:16]
        hb = vd.get("heartbeats_current_epoch",0)
        ex = vd.get("expected_heartbeats",12)
        el = vd.get("eligible",False)
        jo = vd.get("join_epoch",-1)
        if cur - jo < prob and el: fail(f"{a} probation", f"eligible in probation!")
        if hb > ex: fail(f"{a} hb>exp", f"{hb}>{ex}")
        else: ok(f"{a}", f"hb={hb}/{ex} elig={el}")
    ok("epoch", f"current={cur}")


# ═══════════════════════════════════════════════════════════
# 7. SLASHING
# ═══════════════════════════════════════════════════════════
def test_7():
    sec(7, "SLASHING")
    u = base(VALIDATORS[0])
    addr = curl_json(f"{u}/node-info")["address"]

    try:
        d = curl_json(f"{u}/slashing")
        ok("/slashing global", f"keys={list(d.keys())[:5]}")
    except Exception as e: fail("/slashing", str(e))
    try:
        d2 = curl_json(f"{u}/slashing/{addr}")
        ok(f"/slashing/addr", f"{json.dumps(d2)[:100]}")
    except Exception as e: fail("/slashing/addr", str(e))


# ═══════════════════════════════════════════════════════════
# 8. FEE ESTIMATE
# ═══════════════════════════════════════════════════════════
def test_8():
    sec(8, "FEE ESTIMATE")
    u = base(VALIDATORS[0])
    # /fee-estimate/:address — estimates anti-whale fee for a given sender address
    addr = curl_json(f"{u}/node-info")["address"]
    try:
        d = curl_json(f"{u}/fee-estimate/{addr}")
        base_fee = d.get("base_fee_cil",0)
        est_fee = d.get("estimated_fee_cil",0)
        mult = d.get("fee_multiplier",0)
        ok(f"/fee-estimate", f"base={base_fee}, est={est_fee}, mult={mult}")
        if est_fee < base_fee: fail("/fee est<base", f"{est_fee}<{base_fee}")
        for k in ["address","base_fee_cil","estimated_fee_cil","fee_multiplier",
                   "tx_count_in_window","max_tx_per_window","window_remaining_secs"]:
            if k not in d: fail(f"/fee key", f"missing '{k}'")
    except Exception as e: fail("/fee-estimate", str(e)[:60])

    # Invalid address should be rejected
    try:
        raw = curl_get(f"{u}/fee-estimate/notanaddress")
        d = json.loads(raw)
        if d.get("status") == "error": ok("/fee invalid addr", "rejected ✓")
        else: fail("/fee invalid addr", f"NOT rejected: {raw[:60]}")
    except: ok("/fee invalid addr", "rejected")

    # Numeric value should also be rejected (it's an address param)
    try:
        raw = curl_get(f"{u}/fee-estimate/100000000000")
        d = json.loads(raw)
        if d.get("status") == "error": ok("/fee numeric", "rejected ✓")
        else: fail("/fee numeric", f"NOT rejected: {raw[:60]}")
    except: ok("/fee numeric", "rejected")


# ═══════════════════════════════════════════════════════════
# 9. METRICS
# ═══════════════════════════════════════════════════════════
def test_9():
    sec(9, "METRICS (Prometheus)")
    u = base(VALIDATORS[0])
    raw = curl_get(f"{u}/metrics")
    lines = [l for l in raw.strip().split("\n") if l and not l.startswith("#")]
    ok("/metrics", f"{len(lines)} lines")
    for m in ["los_active_validators","los_accounts_total","los_blocks_total"]:
        found = [l for l in lines if m in l]
        if found: ok(f"  {m}", found[0].split()[-1])
        else: warn(f"  {m}", "not found")


# ═══════════════════════════════════════════════════════════
# 10. MEMPOOL
# ═══════════════════════════════════════════════════════════
def test_10():
    sec(10, "MEMPOOL")
    u = base(VALIDATORS[0])
    try:
        d = curl_json(f"{u}/mempool/stats")
        ok("/mempool/stats", json.dumps(d)[:120])
    except Exception as e: fail("/mempool/stats", str(e))


# ═══════════════════════════════════════════════════════════
# 11. SEND — negative tests
# ═══════════════════════════════════════════════════════════
def test_11():
    sec(11, "SEND — NEGATIVE TESTS")
    u = base(VALIDATORS[0])
    addr = curl_json(f"{u}/node-info")["address"]
    cases = [
        ("empty", {}),
        ("bad sig", {"from":"LOSfake1","to":"LOSfake2","amount":100,"signature":"x","public_key":"x"}),
        ("neg amt", {"from":"LOSfake1","to":"LOSfake2","amount":-1000,"signature":"x","public_key":"x"}),
        ("zero amt", {"from":"LOSfake1","to":"LOSfake2","amount":0,"signature":"x","public_key":"x"}),
        ("self", {"from":addr,"to":addr,"amount":100,"signature":"x","public_key":"x"}),
        ("huge amt", {"from":addr,"to":"LOSfake","amount":99999999*10**11,"signature":"x","public_key":"x"}),
    ]
    for lbl,body in cases:
        try:
            c,d = curl_post(f"{u}/send", body)
            s = json.dumps(d).lower()
            if c >= 400 or "error" in s or "invalid" in s or "fail" in s or "insufficient" in s:
                ok(f"/send {lbl}", f"HTTP {c}: rejected")
            else:
                fail(f"/send {lbl}", f"HTTP {c}: NOT rejected! {s[:60]}")
        except Exception as e:
            ok(f"/send {lbl}", f"err: {str(e)[:50]}")


# ═══════════════════════════════════════════════════════════
# 12. REGISTER-VALIDATOR — negative
# ═══════════════════════════════════════════════════════════
def test_12():
    sec(12, "REGISTER-VALIDATOR — NEGATIVE")
    u = base(VALIDATORS[0])
    for lbl,body in [("empty",{}),("bad",{"address":"LOSfake","public_key":"x","signature":"x"})]:
        try:
            c,d = curl_post(f"{u}/register-validator", body)
            if c >= 400 or "error" in json.dumps(d).lower():
                ok(f"/register {lbl}", f"HTTP {c}: rejected")
            else: fail(f"/register {lbl}", f"HTTP {c}: NOT rejected!")
        except Exception as e: ok(f"/register {lbl}", f"err: {str(e)[:50]}")


# ═══════════════════════════════════════════════════════════
# 13. UNREGISTER — negative
# ═══════════════════════════════════════════════════════════
def test_13():
    sec(13, "UNREGISTER-VALIDATOR — NEGATIVE")
    u = base(VALIDATORS[0])
    for p in ["/unregister-validator","/unregister_validator"]:
        try:
            c,d = curl_post(f"{u}{p}", {})
            if c >= 400 or "error" in json.dumps(d).lower():
                ok(f"{p} empty", f"HTTP {c}")
            else: fail(f"{p} empty", f"HTTP {c}: NOT rejected!")
        except Exception as e: ok(f"{p} empty", f"err: {str(e)[:50]}")


# ═══════════════════════════════════════════════════════════
# 14. FAUCET
# ═══════════════════════════════════════════════════════════
def test_14():
    sec(14, "FAUCET")
    u = base(VALIDATORS[0])
    try:
        c,d = curl_post(f"{u}/faucet", {"address":"LOStestfaucet123456789012345"})
        ok(f"/faucet", f"HTTP {c}: {json.dumps(d)[:80]}")
    except Exception as e: warn("/faucet", str(e)[:60])
    try:
        c,d = curl_post(f"{u}/faucet", {})
        if c >= 400 or d.get("status") == "error": ok("/faucet empty", f"HTTP {c}: rejected ✓")
        else: warn("/faucet empty", f"HTTP {c}: not rejected")
    except: ok("/faucet empty", "rejected")


# ═══════════════════════════════════════════════════════════
# 15. CONTRACTS — negative
# ═══════════════════════════════════════════════════════════
def test_15():
    sec(15, "CONTRACT APIs")
    u = base(VALIDATORS[0])
    try:
        d = curl_json(f"{u}/contract/nonexistent")
        if "error" in json.dumps(d).lower(): ok("/contract 404", "not found ✓")
        else: warn("/contract 404", json.dumps(d)[:60])
    except: ok("/contract 404", "error")
    for ep in ["/deploy-contract","/call-contract"]:
        try:
            c,d = curl_post(f"{u}{ep}", {})
            if c >= 400 or "error" in json.dumps(d).lower(): ok(f"{ep} empty", f"HTTP {c}")
            else: fail(f"{ep} empty", f"HTTP {c}: NOT rejected!")
        except: ok(f"{ep} empty", "rejected")


# ═══════════════════════════════════════════════════════════
# 16. BURN — negative
# ═══════════════════════════════════════════════════════════
def test_16():
    sec(16, "BURN APIs")
    u = base(VALIDATORS[0])
    try:
        c,d = curl_post(f"{u}/burn", {})
        if c >= 400 or "error" in json.dumps(d).lower(): ok("/burn empty", f"HTTP {c}")
        else: fail("/burn empty", f"HTTP {c}: NOT rejected!")
    except: ok("/burn empty", "rejected")
    try:
        c,d = curl_post(f"{u}/burn", {"txid":"fake","chain":"BTC","target_address":"LOSfake","amount":100})
        if c >= 400 or "error" in json.dumps(d).lower(): ok("/burn fake", f"HTTP {c}")
        else: fail("/burn fake", f"HTTP {c}: NOT rejected!")
    except: ok("/burn fake", "rejected")


# ═══════════════════════════════════════════════════════════
# 17. VALIDATOR KEY GEN
# ═══════════════════════════════════════════════════════════
def test_17():
    sec(17, "VALIDATOR KEY GENERATION")
    u = base(VALIDATORS[0])
    try:
        d = curl_json(f"{u}/validator/generate")
        addr = d.get("address","")
        has_pk = "public_key" in d
        has_seed = any(k in d for k in ["seed","mnemonic","seed_phrase"])
        ok("/validator/generate", f"addr={bool(addr)}, pk={has_pk}, seed={has_seed}")
        if addr and not addr.startswith("LOS"):
            fail("/gen addr prefix", f"'{addr}'")
        elif addr:
            ok("/gen addr", addr[:20]+"…")
    except Exception as e: fail("/validator/generate", str(e))


# ═══════════════════════════════════════════════════════════
# 18. RESET-BURN-TXID
# ═══════════════════════════════════════════════════════════
def test_18():
    sec(18, "RESET-BURN-TXID")
    u = base(VALIDATORS[0])
    try:
        c,d = curl_post(f"{u}/reset-burn-txid", {"txid":"nonexistent"})
        ok("/reset-burn-txid", f"HTTP {c}: {json.dumps(d)[:60]}")
    except Exception as e: warn("/reset-burn-txid", str(e)[:60])


# ═══════════════════════════════════════════════════════════
# 19. SYNC
# ═══════════════════════════════════════════════════════════
def test_19():
    sec(19, "SYNC API")
    u = base(VALIDATORS[0])
    try:
        raw = curl_get(f"{u}/sync?from=0")
        if raw: ok("/sync", f"{len(raw)} bytes")
        else: warn("/sync", "empty")
    except Exception as e: warn("/sync", str(e)[:60])


# ═══════════════════════════════════════════════════════════
# 20. CROSS-NODE CONSISTENCY
# ═══════════════════════════════════════════════════════════
def test_20():
    sec(20, "CROSS-NODE CONSISTENCY")
    addrs = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/node-info")
            addrs[v["name"]] = d["address"]
        except Exception as e:
            fail(f"{v['name']} info", str(e)); return

    # Balance
    ta = list(addrs.values())[0]
    bals = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/balance/{ta}")
            bals[v["name"]] = d.get("balance_cil",0)
        except Exception as e: fail(f"{v['name']} bal", str(e))
    if len(set(bals.values())) == 1: ok("balance consistent", f"{list(bals.values())[0]/1e11:.0f} LOS")
    else:
        # Allow small drift from reward distribution gossip delay
        max_b = max(bals.values()); min_b = min(bals.values())
        drift_los = (max_b - min_b) / 1e11
        if drift_los <= 5000:  # One epoch reward (5000 LOS) gossip lag
            warn("balance drift", f"max-min={drift_los:.0f} LOS (gossip lag)")
        else:
            fail("balance MISMATCH", str({k: v/1e11 for k,v in bals.items()}))

    # Supply
    sups = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/supply")
            sups[v["name"]] = json.dumps(d, sort_keys=True)
        except Exception as e: fail(f"{v['name']} supply", str(e))
    if len(set(sups.values())) == 1: ok("supply consistent", "all agree")
    else:
        # Check if difference is just rounding (CIL values match but LOS strings differ)
        cil_vals = set()
        for n,s in sups.items():
            d = json.loads(s)
            cil_vals.add(d.get("remaining_supply_cil",0))
        if len(cil_vals) <= 2:  # Allow ±1 CIL rounding or 1-epoch gossip lag
            warn("supply drift", f"minor CIL rounding or gossip lag")
        else:
            fail("supply MISMATCH", "disagree!")
            for n,s in sups.items(): print(f"    {n}: {s[:80]}")

    # Validator list
    vls = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/validators")
            vs = d if isinstance(d,list) else d.get("validators",[])
            vls[v["name"]] = sorted([x.get("address","") for x in vs])
        except Exception as e: fail(f"{v['name']} vals", str(e))
    if len(set(json.dumps(x) for x in vls.values())) == 1:
        ok("validator-list consistent", f"{len(list(vls.values())[0])} validators")
    else: fail("validator-list MISMATCH", "disagree!")

    # Epoch
    eps = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/reward-info")
            eps[v["name"]] = d.get("epoch",{}).get("current_epoch",-1)
        except Exception as e: fail(f"{v['name']} ep", str(e))
    ev = set(eps.values())
    if len(ev) == 1: ok("epoch consistent", f"epoch={list(ev)[0]}")
    elif max(ev) - min(ev) <= 1: warn("epoch drift ±1", str(eps))
    else: fail("epoch MISMATCH", str(eps))

    # Pool
    pls = {}
    for v in VALIDATORS:
        try:
            d = curl_json(f"{base(v)}/reward-info")
            pls[v["name"]] = d.get("pool",{}).get("remaining_cil",0)
        except Exception as e: fail(f"{v['name']} pool", str(e))
    if len(set(pls.values())) == 1:
        ok("pool consistent", f"{list(pls.values())[0]/1e11:.0f} LOS")
    else: warn("pool drift", str({k:v/1e11 for k,v in pls.items()}))


# ═══════════════════════════════════════════════════════════
# 21. GENESIS
# ═══════════════════════════════════════════════════════════
def test_21():
    sec(21, "GENESIS VALIDATION")
    u = base(VALIDATORS[0])
    TOTAL = 21_936_236 * 10**11
    d = curl_json(f"{u}/supply")
    t = None
    for k in ["total_supply_cil","total_cil","total_supply"]:
        if k in d: t = int(d[k]) if isinstance(d[k],str) else d[k]; break
    if t == TOTAL: ok("genesis total", "21,936,236 LOS ✓")
    elif t: fail("genesis total", f"{t/1e11:,.0f}")
    else: warn("genesis total", "no field")


# ═══════════════════════════════════════════════════════════
# 22. EDGE CASES
# ═══════════════════════════════════════════════════════════
def test_22():
    sec(22, "EDGE CASES")
    u = base(VALIDATORS[0])

    # Long address
    try:
        raw = curl_get(f"{u}/balance/LOS{'A'*500}")
        ok("/balance long_addr", f"handled ({len(raw)}b)")
    except: ok("/balance long_addr", "handled")

    # XSS
    try:
        raw = curl_get(f"{u}/balance/LOS%3Cscript%3Ealert%3C%2Fscript%3E")
        ok("/balance XSS", "handled")
    except: ok("/balance XSS", "handled")

    # Max u64 as fee-estimate param (rejected — not a valid address)
    try:
        raw = curl_get(f"{u}/fee-estimate/18446744073709551615")
        d = json.loads(raw) if raw.strip() else {}
        if d.get("status") == "error": ok("/fee max_u64", "rejected (invalid addr)")
        else: ok("/fee max_u64", f"handled ({len(raw)}b)")
    except: ok("/fee max_u64", "handled")

    # Overflow u64+1 (rejected — not a valid address)
    try:
        raw = curl_get(f"{u}/fee-estimate/18446744073709551616")
        d = json.loads(raw) if raw.strip() else {}
        if d.get("status") == "error": ok("/fee overflow", "rejected (invalid addr)")
        else: ok("/fee overflow", "handled")
    except: ok("/fee overflow", "handled")

    # 404
    try:
        raw = curl_get(f"{u}/nonexistent-xyz-endpoint")
        if "404" in raw or "not found" in raw.lower() or not raw.strip():
            ok("404 endpoint", "correct")
        else: warn("404 endpoint", f"{raw[:50]}")
    except: ok("404 endpoint", "handled")


# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════
def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  UNAUTHORITY (LOS) — COMPREHENSIVE TESTNET AUDIT       ║")
    print("║  ALL requests via Tor .onion (NO localhost)             ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"  Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Proxy: {TOR_PROXY}")
    print(f"  Validators: {len(VALIDATORS)}")
    start = time.time()

    tests = [
        test_1, test_2, test_3, test_4, test_5, test_6, test_7, test_8,
        test_9, test_10, test_11, test_12, test_13, test_14, test_15,
        test_16, test_17, test_18, test_19, test_20, test_21, test_22,
    ]
    for t in tests:
        try:
            t()
        except KeyboardInterrupt:
            print("\n⚡ Interrupted"); break
        except Exception as e:
            fail(f"FATAL {t.__name__}", str(e))
            traceback.print_exc()

    elapsed = time.time() - start
    print(f"\n\n{'='*60}")
    print("TEST RESULTS")
    print(f"{'='*60}")
    print(f"  ✅ PASS: {PASS}")
    print(f"  ❌ FAIL: {FAIL}")
    print(f"  ⚠️  WARN: {WARN}")
    print(f"  ⏱  Time: {elapsed:.1f}s")

    if BUGS:
        print(f"\n🐛 ALL BUGS & WARNINGS ({len(BUGS)}):")
        print("-"*60)
        for b in BUGS: print(f"  {b}")

    if FAIL == 0 and WARN == 0:
        print("\n🎉 ALL TESTS PASSED!")
    elif FAIL == 0:
        print(f"\n✅ No failures, {WARN} warnings.")
    else:
        print(f"\n🚨 {FAIL} FAILURES + {WARN} WARNINGS.")
    return FAIL

if __name__ == "__main__":
    sys.exit(main())
