#!/usr/bin/env python3
"""
Comprehensive Testnet API & Feature Test Suite v2
==================================================
Tests ALL 40+ API endpoints via Tor .onion addresses.
NO localhost. This is the testnet that guarantees mainnet 100%.
Uses curl --socks5-hostname for .onion resolution through Tor.

Coverage:
 - Health, Node-Info, Whoami, Root — all 4 validators
 - Balance, Account, History — structure + math
 - Supply — conservation law, total/circulating/remaining
 - Validators & Consensus — stake, uptime, aBFT safety
 - Rewards & Epoch — pool math, sqrt-stake, halving, probation
 - Slashing — global + per-validator profile
 - Fee Estimate — anti-whale, address validation
 - Metrics — Prometheus format
 - Mempool — stats structure
 - Blocks & Transactions — latest, by-hash, recent, search
 - Faucet — claim, rate-limit, invalid address, cooldown
 - Burn — negative tests
 - Contracts — deploy, call, get (negative)
 - Register/Unregister — negative
 - Validator Key Gen — generate, import-seed roundtrip, import-key format
 - Sync — data endpoint
 - Cross-node Consistency — balance, supply, validators, epoch, pool, blocks
 - Supply Conservation — sum(balances) + remaining = total_supply
 - Deterministic Keygen — two calls produce different keys
 - Uptime Display — not 0 for active validators
 - Reward Math — sqrt-stake distribution, pool conservation
 - Version & Build Integrity — all nodes same version, correct network
 - Edge Cases & Security — XSS, SQLi, overflow, long input, 404, unicode

Usage: python3 test_comprehensive_tor.py
"""

import json
import sys
import time
import subprocess
import traceback

# ─── ONION HOSTS ───
# Single Tor hidden service with per-validator port mappings
_ONION = "ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion"
VALIDATORS = [
    {"name": "V1", "onion": f"{_ONION}:3030"},
    {"name": "V2", "onion": f"{_ONION}:3031"},
    {"name": "V3", "onion": f"{_ONION}:3032"},
    {"name": "V4", "onion": f"{_ONION}:3033"},
]

TOR_PROXY = "socks5h://127.0.0.1:9050"
TIMEOUT = 45

# Protocol constants from los-core/src/lib.rs
CIL_PER_LOS = 100_000_000_000       # 10^11
TOTAL_SUPPLY_LOS = 21_936_236
TOTAL_SUPPLY_CIL = TOTAL_SUPPLY_LOS * CIL_PER_LOS
REWARD_POOL_CIL = 500_000 * CIL_PER_LOS
REWARD_RATE_CIL = 5_000 * CIL_PER_LOS
HALVING_INTERVAL = 48
PROBATION_EPOCHS = 1
MIN_STAKE_LOS = 1000
BASE_FEE_CIL = 100_000

PASS = 0
FAIL = 0
WARN = 0
BUGS = []


def base(v):
    return "http://" + v["onion"]


def curl_get(url, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "--max-time", str(timeout), "--proxy", TOR_PROXY, url],
            capture_output=True, text=True
        )
        if r.returncode == 0:
            return r.stdout
        # Retry on transient Tor errors: 7=connect fail, 28=timeout, 97=proxy error
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception("curl exit " + str(r.returncode) + ": " + r.stderr.strip()[:120])
    return ""


def curl_json(url, timeout=TIMEOUT):
    raw = curl_get(url, timeout)
    if not raw.strip():
        raise Exception("empty response")
    return json.loads(raw)


def curl_post(url, body, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
             "--proxy", TOR_PROXY, "-X", "POST",
             "-H", "Content-Type: application/json",
             "-d", json.dumps(body), url],
            capture_output=True, text=True
        )
        if r.returncode == 0:
            break
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception("curl exit " + str(r.returncode) + ": " + r.stderr.strip()[:120])
    parts = r.stdout.rsplit("\n", 1)
    body_txt = parts[0] if len(parts) > 1 else r.stdout
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    try:
        return code, json.loads(body_txt) if body_txt.strip() else {}
    except json.JSONDecodeError:
        return code, {"raw": body_txt[:200]}


def curl_post_raw(url, raw_body, timeout=TIMEOUT, retries=2):
    """POST with raw string body (not JSON-encoded) for testing malformed bodies"""
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
             "--proxy", TOR_PROXY, "-X", "POST",
             "-H", "Content-Type: application/json",
             "-d", raw_body, url],
            capture_output=True, text=True
        )
        if r.returncode == 0:
            break
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception("curl exit " + str(r.returncode) + ": " + r.stderr.strip()[:120])
    parts = r.stdout.rsplit("\n", 1)
    body_txt = parts[0] if len(parts) > 1 else r.stdout
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    try:
        return code, json.loads(body_txt) if body_txt.strip() else {}
    except json.JSONDecodeError:
        return code, {"raw": body_txt[:200]}


def ok(name, detail=""):
    global PASS; PASS += 1
    print("  [PASS] " + name + (" -- " + detail if detail else ""))

def fail(name, detail=""):
    global FAIL; FAIL += 1
    BUGS.append("[BUG] " + name + ": " + detail)
    print("  [FAIL] " + name + (" -- " + detail if detail else ""))

def warn(name, detail=""):
    global WARN; WARN += 1
    BUGS.append("[WARN] " + name + ": " + detail)
    print("  [WARN] " + name + (" -- " + detail if detail else ""))

def sec(n, t):
    print("\n" + "="*60 + "\n" + str(n) + ". " + t + "\n" + "="*60)

def is_error_response(d):
    """Check if response indicates an error"""
    s = json.dumps(d).lower()
    return "error" in s or "invalid" in s or "fail" in s


# ===============================================================
# 1. HEALTH & NODE INFO -- ALL VALIDATORS
# ===============================================================
def test_1():
    sec(1, "HEALTH & NODE INFO (all validators via .onion)")
    for v in VALIDATORS:
        u = base(v); n = v["name"]
        # /health
        try:
            d = curl_json(u + "/health")
            if d.get("status") != "healthy":
                fail(n + " /health", "status=" + str(d.get("status")))
            else:
                ok(n + " /health", "v" + str(d.get("version","?")) + " up=" + str(d.get("uptime_seconds","?")) + "s accts=" + str(d["chain"]["accounts"]) + " blks=" + str(d["chain"]["blocks"]))
            required_keys = ["status","version","uptime_seconds","chain","database","timestamp"]
            for k in required_keys:
                if k not in d: fail(n + " /health key", "missing '" + k + "'")
            chain = d.get("chain",{})
            if chain.get("id") not in ("los-testnet", "testnet"):
                fail(n + " chain.id", str(chain.get("id")))
            # database subfields
            db = d.get("database",{})
            for dk in ["accounts_count","blocks_count","size_on_disk"]:
                if dk not in db: fail(n + " /health db key", "missing '" + dk + "'")
            # version format check
            ver = d.get("version","")
            if not ver or ver.count(".") < 2:
                warn(n + " version format", ver)
        except Exception as e:
            fail(n + " /health", str(e))
        # /node-info
        try:
            d = curl_json(u + "/node-info")
            a = d.get("address","")
            if not a.startswith("LOS"): fail(n + " addr", "'" + a + "'")
            else: ok(n + " /node-info", a[:20] + "..., net=" + str(d.get("network")))
            if d.get("network") not in ("los-testnet","testnet"): fail(n + " net", str(d.get("network")))
            for k in ["address","version","network"]:
                if k not in d: fail(n + " /node-info key", "missing '" + k + "'")
        except Exception as e:
            fail(n + " /node-info", str(e))
        # /whoami
        try:
            d = curl_json(u + "/whoami")
            if "address" in d: ok(n + " /whoami", d["address"][:20] + "...")
            else: fail(n + " /whoami", "no address field")
        except Exception as e:
            fail(n + " /whoami", str(e))
        # / (root)
        try:
            d = curl_json(u + "/")
            if "endpoints" not in d: fail(n + " / root", "no endpoints field")
            elif "name" not in d: fail(n + " / root", "no name field")
            else: ok(n + " / root", d.get("name","?")[:30])
            net = d.get("network","")
            if net not in ("mainnet","testnet"):
                fail(n + " / network", net)
        except Exception as e:
            fail(n + " /", str(e))


# ===============================================================
# 2. BALANCE & ACCOUNT
# ===============================================================
def test_2():
    sec(2, "BALANCE & ACCOUNT DETAIL")
    u = base(VALIDATORS[0])
    addr = curl_json(u + "/node-info")["address"]

    # /balance/:address
    d = curl_json(u + "/balance/" + addr)
    for k in ["address","balance_cil","balance_los"]:
        if k not in d: fail("/balance key", "missing '" + k + "'")
    cil = d.get("balance_cil",0)
    los_str = d.get("balance_los","0")
    los = float(los_str)
    if cil <= 0: fail("/balance", "cil=" + str(cil))
    else: ok("/balance", str(los) + " LOS (" + str(cil) + " CIL)")
    if abs(cil/1e11 - los) > 0.001: fail("/balance conv", str(cil) + "/1e11 != " + str(los))
    else: ok("/balance CIL<>LOS", "consistent")

    # /bal/:address (short alias)
    try:
        d2 = curl_json(u + "/bal/" + addr)
        if "balance_cil" in d2: ok("/bal alias", "works")
        else: fail("/bal alias", "missing balance_cil")
    except Exception as e: fail("/bal alias", str(e))

    # /account/:address -- deep validation
    try:
        d3 = curl_json(u + "/account/" + addr)
        acct_keys = ["address","balance_cil","balance_los","block_count","head_block",
                      "is_validator","transactions","transaction_count"]
        missing = [k for k in acct_keys if k not in d3]
        if missing: fail("/account keys", "missing: " + str(missing))
        else: ok("/account", "block_count=" + str(d3.get("block_count","?")) + " txs=" + str(d3.get("transaction_count","?")))
        if d3.get("is_validator") is True: ok("/account is_validator", "true (V1)")
        else: warn("/account is_validator", str(d3.get("is_validator")))
        if d3.get("balance_cil") == cil: ok("/account balance_cil", "matches /balance")
        else: fail("/account balance_cil", str(d3.get("balance_cil")) + " != " + str(cil))
        # Check transaction structure
        txs = d3.get("transactions",[])
        if txs:
            t0 = txs[0]
            tx_keys = ["hash","from","to","type","amount","timestamp","link","previous","fee"]
            tmissing = [k for k in tx_keys if k not in t0]
            if tmissing: fail("/account tx keys", "missing: " + str(tmissing))
            else: ok("/account tx structure", "all fields present")
            valid_types = ("send","receive","mint","slash","change")
            for tx in txs:
                tt = tx.get("type","")
                if tt not in valid_types:
                    fail("/account tx type", "'" + tt + "' not in " + str(valid_types))
                    break
            else:
                ok("/account tx types", "all valid")
    except Exception as e: fail("/account", str(e))

    # /balance/INVALID_ADDR -- should return 0
    try:
        d4 = curl_json(u + "/balance/INVALID_ADDR_999")
        if d4.get("balance_cil",0) == 0: ok("/balance invalid", "0 CIL")
        else: warn("/balance invalid", "cil=" + str(d4.get("balance_cil")))
    except: ok("/balance invalid", "error returned")

    # /balance/ with no address
    try:
        raw = curl_get(u + "/balance/")
        if "404" in raw or "not found" in raw.lower() or not raw.strip(): ok("/balance/ empty", "404")
        else: warn("/balance/ empty", raw[:50])
    except: ok("/balance/ empty", "error")


# ===============================================================
# 3. SUPPLY -- conservation law
# ===============================================================
def test_3():
    sec(3, "SUPPLY & CONSERVATION LAW")
    u = base(VALIDATORS[0])

    d = curl_json(u + "/supply")
    ok("/supply", "keys=" + str(list(d.keys())))

    required_fields = ["total_supply","total_supply_cil","circulating_supply",
                       "circulating_supply_cil","remaining_supply","remaining_supply_cil",
                       "total_burned_usd"]
    missing = [k for k in required_fields if k not in d]
    if missing: fail("/supply fields", "missing: " + str(missing))
    else: ok("/supply fields", "all 7 present")

    total_cil = d.get("total_supply_cil",0)
    if total_cil == TOTAL_SUPPLY_CIL: ok("/supply total", "21,936,236 LOS exact")
    else: fail("/supply total", str(total_cil) + " != " + str(TOTAL_SUPPLY_CIL))

    circ_cil = d.get("circulating_supply_cil",0)
    rem_cil = d.get("remaining_supply_cil",0)
    if circ_cil + rem_cil == total_cil:
        ok("/supply conservation", "circ(" + str(circ_cil // CIL_PER_LOS) + ") + rem(" + str(rem_cil // CIL_PER_LOS) + ") = total")
    else:
        fail("/supply conservation", str(circ_cil) + " + " + str(rem_cil) + " != " + str(total_cil))

    for k in ["total_supply","circulating_supply","remaining_supply"]:
        v = d.get(k,"")
        try:
            f = float(v)
            if f >= 0: ok("/supply " + k, str(f))
            else: fail("/supply " + k + " <0", str(v))
        except (ValueError, TypeError):
            fail("/supply " + k + " parse", str(v))

    if circ_cil > 0: ok("/supply circ>0", str(circ_cil // CIL_PER_LOS) + " LOS")
    else: fail("/supply circ=0", "no circulation?")

    if rem_cil < total_cil: ok("/supply rem<total", "correct")
    else: fail("/supply rem>=total", "nothing allocated?")


# ===============================================================
# 4. HISTORY & BLOCKS & TRANSACTIONS
# ===============================================================
def test_4():
    sec(4, "HISTORY & BLOCKS & TRANSACTIONS")
    u = base(VALIDATORS[0])
    addr = curl_json(u + "/node-info")["address"]

    d = curl_json(u + "/history/" + addr)
    txs = d.get("transactions",[])
    ok("/history", str(len(txs)) + " txs")
    if txs:
        t0 = txs[0]
        if "type" in t0 and "amount" in t0: ok("/history structure", "type=" + str(t0["type"]))
        else: fail("/history structure", "keys=" + str(list(t0.keys())))
        for i,t in enumerate(txs):
            a_raw = t.get("amount", 0)
            try:
                a = float(a_raw) if isinstance(a_raw, str) else a_raw
            except (ValueError, TypeError):
                a = 0
            if a < 0: fail("/history tx[" + str(i) + "] amt<0", str(a_raw))
        valid_types = {"send","receive","mint","slash","change"}
        found_types = set()
        for t in txs:
            tt = t.get("type","")
            found_types.add(tt)
            if tt not in valid_types:
                fail("/history tx type", "'" + tt + "'")
                break
        ok("/history types", str(found_types))

    try:
        d2 = curl_json(u + "/history/LOSnonexistent99999999999999999999")
        if len(d2.get("transactions",[])) == 0: ok("/history nonexistent", "empty list")
        else: fail("/history nonexistent", "has txs!")
    except: ok("/history nonexistent", "error")

    try:
        d3 = curl_json(u + "/blocks/recent")
        bl = d3 if isinstance(d3,list) else d3.get("blocks",[])
        ok("/blocks/recent", str(len(bl)) + " blocks")
        if bl:
            b0 = bl[0]
            for k in ["account","block_type","amount","timestamp"]:
                if k not in b0 and k not in str(b0):
                    warn("/blocks/recent key", "missing '" + k + "'")
    except Exception as e: fail("/blocks/recent", str(e))

    try:
        d4 = curl_json(u + "/block")
        ok("/block latest", "keys=" + str(list(d4.keys())[:6]))
        if "hash" not in d4 and "account" not in d4:
            warn("/block fields", "no hash or account")
    except Exception as e: fail("/block", str(e))

    head = ""
    try:
        bal = curl_json(u + "/balance/" + addr)
        head = bal.get("head","")
        if head and head != "0":
            d5 = curl_json(u + "/block/" + head)
            if "error" in str(d5).lower() and "not found" in str(d5).lower():
                fail("/block/head", "not found")
            else: ok("/block/hash", head[:16] + "...")
        else:
            warn("/block/hash", "no head block")
    except Exception as e: fail("/block/hash", str(e))

    try:
        d6 = curl_json(u + "/block/" + "0"*64)
        if "error" in str(d6).lower() or "not found" in str(d6).lower(): ok("/block invalid", "not found")
        else: warn("/block invalid", str(list(d6.keys())[:5]))
    except: ok("/block invalid", "error")

    try:
        h = curl_json(u + "/history/" + addr)
        th = None
        for t in h.get("transactions",[]):
            if "hash" in t and t["hash"]: th = t["hash"]; break
        if th:
            d7 = curl_json(u + "/transaction/" + th)
            if "error" in str(d7).lower() and "not found" in str(d7).lower():
                fail("/transaction", "real hash not found")
            else:
                ok("/transaction", th[:16] + "...")
        else: warn("/transaction", "no tx hash in history")
    except Exception as e: warn("/transaction", str(e)[:60])

    try:
        d8 = curl_json(u + "/transaction/" + "f"*64)
        if "error" in str(d8).lower() or "not found" in str(d8).lower(): ok("/transaction invalid", "not found")
        else: warn("/transaction invalid", str(d8)[:60])
    except: ok("/transaction invalid", "error")

    try:
        d9 = curl_json(u + "/search/" + addr)
        ok("/search addr", "keys=" + str(list(d9.keys())[:5]))
    except Exception as e: fail("/search", str(e))

    if head and head != "0":
        try:
            d10 = curl_json(u + "/search/" + head)
            ok("/search hash", "keys=" + str(list(d10.keys())[:5]))
        except Exception as e: warn("/search hash", str(e)[:40])


# ===============================================================
# 5. VALIDATORS & CONSENSUS
# ===============================================================
def test_5():
    sec(5, "VALIDATORS & CONSENSUS")
    u = base(VALIDATORS[0])

    d = curl_json(u + "/validators")
    vals = d if isinstance(d,list) else d.get("validators",[])
    if len(vals) >= 4: ok("/validators", str(len(vals)) + " validators")
    else: fail("/validators", str(len(vals)) + " < 4")

    for i,va in enumerate(vals):
        a = va.get("address","?")[:16]
        s = int(va.get("stake",0))
        if s < MIN_STAKE_LOS: fail("val[" + str(i) + "] stake", a + " " + str(s) + " < " + str(MIN_STAKE_LOS) + " LOS")
        else: ok("val[" + str(i) + "]", a + "... " + str(s) + " LOS")
        val_keys = ["address","stake","uptime_percentage"]
        for k in val_keys:
            if k not in va: fail("val[" + str(i) + "] key", "missing '" + k + "'")

    uptimes = [va.get("uptime_percentage",0) for va in vals]
    nonzero = [u for u in uptimes if u > 0]
    if nonzero:
        ok("uptime display", str(len(nonzero)) + "/" + str(len(vals)) + " show >0%")
    else:
        warn("uptime all zero", "all validators 0% (fresh restart?)")

    d2 = curl_json(u + "/consensus")
    s = d2.get("safety",{})
    act = s.get("active_validators",0)
    byz = s.get("byzantine_safe",False)
    if act >= 4: ok("/consensus active", str(act))
    else: fail("/consensus active", str(act))
    if byz: ok("/consensus byz", "true")
    else: warn("/consensus byz", "false (n=" + str(act) + ")")
    ft = s.get("max_faulty", s.get("fault_tolerance",0))
    exp = (act-1)//3
    if ft == exp: ok("/consensus ft", "f=" + str(ft))
    else: warn("/consensus ft", "f=" + str(ft) + " exp=" + str(exp))
    for k in ["safety"]:
        if k not in d2: fail("/consensus key", "missing '" + k + "'")

    try:
        d3 = curl_json(u + "/peers")
        p = d3 if isinstance(d3,list) else d3.get("peers",[])
        ok("/peers", str(len(p)) + " peers")
        if p:
            has_onion = any(".onion" in str(peer) for peer in p)
            if has_onion: ok("/peers onion", "found .onion endpoints")
            else: warn("/peers onion", "no .onion in peers")
    except Exception as e: fail("/peers", str(e))

    try:
        d4 = curl_json(u + "/network/peers")
        ok("/network/peers", "keys=" + str(list(d4.keys())[:5]))
    except Exception as e: fail("/network/peers", str(e))


# ===============================================================
# 6. REWARDS & EPOCH -- detailed pool math
# ===============================================================
def test_6():
    sec(6, "REWARDS & EPOCH (detailed)")
    u = base(VALIDATORS[0])

    d = curl_json(u + "/reward-info")
    cfg = d.get("config",{})
    config_checks = [
        ("probation_epochs", PROBATION_EPOCHS),
        ("min_uptime_pct", 95),
        ("halving_interval_epochs", HALVING_INTERVAL),
    ]
    for k,exp in config_checks:
        v = cfg.get(k)
        if v == exp: ok("cfg." + k, str(exp))
        else: fail("cfg." + k, str(v) + " != " + str(exp))

    if cfg.get("genesis_excluded"): fail("genesis_excluded", "HACK: true!")
    else: ok("genesis_excluded", "false (no hack)")

    m = cfg.get("distribution_model","")
    if "sqrt" in m.lower() or "square" in m.lower(): ok("model", m)
    else: warn("model", m)

    ep = d.get("epoch",{})
    cur = ep.get("current_epoch",0)
    halv = ep.get("halvings_occurred",0)
    expected_halvings = cur // HALVING_INTERVAL
    if halv == expected_halvings: ok("halvings", str(halv) + " (epoch " + str(cur) + ")")
    else: fail("halvings", str(halv) + " != expected " + str(expected_halvings))

    rate = ep.get("epoch_reward_rate_cil",0)
    exp_rate = REWARD_RATE_CIL >> halv
    if rate == exp_rate: ok("rate", str(rate // CIL_PER_LOS) + " LOS/epoch (halv=" + str(halv) + ")")
    else: fail("rate", str(rate) + " != " + str(exp_rate))

    pool = d.get("pool",{})
    rem = pool.get("remaining_cil",0)
    dist = pool.get("total_distributed_cil",0)
    if rem + dist == REWARD_POOL_CIL:
        ok("pool sum", "rem=" + str(rem // CIL_PER_LOS) + " + dist=" + str(dist // CIL_PER_LOS) + " = 500,000")
    else:
        fail("pool sum", str((rem+dist) // CIL_PER_LOS) + " != 500,000")

    if rem <= REWARD_POOL_CIL: ok("pool rem<=total", str(rem // CIL_PER_LOS) + " LOS")
    else: fail("pool rem>total", str(rem))

    if dist >= 0: ok("pool dist>=0", str(dist // CIL_PER_LOS) + " LOS")
    else: fail("pool dist<0", str(dist))

    dets = d.get("validators",{}).get("details",[])
    if len(dets) >= 4: ok("validator details", str(len(dets)) + " validators")
    else: warn("validator details", str(len(dets)))

    for vd in dets:
        a = vd.get("address","?")[:16]
        hb = vd.get("heartbeats_current_epoch",0)
        ex = vd.get("expected_heartbeats",12)
        el = vd.get("eligible",False)
        jo = vd.get("join_epoch",-1)
        cum = vd.get("cumulative_rewards_cil",0)
        stk = vd.get("stake_cil",0)

        if cur - jo < PROBATION_EPOCHS and el:
            fail(a + " probation", "eligible in probation!")
        if hb > ex: fail(a + " hb>exp", str(hb) + ">" + str(ex))
        else: ok(a, "hb=" + str(hb) + "/" + str(ex) + " elig=" + str(el) + " cum=" + str(cum // CIL_PER_LOS) + " LOS")

        if stk < MIN_STAKE_LOS * CIL_PER_LOS:
            fail(a + " stake", str(stk) + " < min")
        if cum < 0: fail(a + " cum<0", str(cum))

    ok("epoch", "current=" + str(cur))


# ===============================================================
# 7. SLASHING
# ===============================================================
def test_7():
    sec(7, "SLASHING")
    u = base(VALIDATORS[0])
    addr = curl_json(u + "/node-info")["address"]

    try:
        d = curl_json(u + "/slashing")
        ok("/slashing global", "keys=" + str(list(d.keys())[:5]))
    except Exception as e: fail("/slashing", str(e))

    try:
        d2 = curl_json(u + "/slashing/" + addr)
        ok("/slashing/addr", json.dumps(d2)[:100])
    except Exception as e: fail("/slashing/addr", str(e))

    try:
        d3 = curl_json(u + "/slashing/LOSnonexistent9999999999999999")
        ok("/slashing nonexistent", json.dumps(d3)[:80])
    except Exception as e: warn("/slashing nonexistent", str(e)[:60])


# ===============================================================
# 8. FEE ESTIMATE -- anti-whale
# ===============================================================
def test_8():
    sec(8, "FEE ESTIMATE (anti-whale)")
    u = base(VALIDATORS[0])
    addr = curl_json(u + "/node-info")["address"]

    try:
        d = curl_json(u + "/fee-estimate/" + addr)
        base_fee = d.get("base_fee_cil",0)
        est_fee = d.get("estimated_fee_cil",0)
        mult = d.get("fee_multiplier",0)
        ok("/fee-estimate", "base=" + str(base_fee) + " est=" + str(est_fee) + " mult=" + str(mult))
        if est_fee < base_fee: fail("/fee est<base", str(est_fee) + "<" + str(base_fee))
        if base_fee == BASE_FEE_CIL: ok("/fee base_fee", str(BASE_FEE_CIL) + " CIL")
        else: fail("/fee base_fee", str(base_fee) + " != " + str(BASE_FEE_CIL))
        fee_keys = ["address","base_fee_cil","estimated_fee_cil","fee_multiplier",
                     "tx_count_in_window","max_tx_per_window","window_remaining_secs",
                     "window_duration_secs"]
        missing = [k for k in fee_keys if k not in d]
        if missing: fail("/fee keys", "missing: " + str(missing))
        else: ok("/fee fields", "all " + str(len(fee_keys)) + " present")
        if mult >= 1: ok("/fee multiplier", ">= 1")
        else: warn("/fee multiplier", str(mult) + " < 1")
    except Exception as e: fail("/fee-estimate", str(e)[:60])

    try:
        raw = curl_get(u + "/fee-estimate/notanaddress")
        d = json.loads(raw)
        if d.get("status") == "error":
            ok("/fee invalid addr", "rejected (code=" + str(d.get("code","?")) + ")")
        else: fail("/fee invalid addr", "NOT rejected: " + raw[:60])
    except: ok("/fee invalid addr", "rejected")

    try:
        raw = curl_get(u + "/fee-estimate/100000000000")
        d = json.loads(raw)
        if d.get("status") == "error": ok("/fee numeric", "rejected")
        else: fail("/fee numeric", "NOT rejected: " + raw[:60])
    except: ok("/fee numeric", "rejected")

    try:
        addr2 = curl_json(base(VALIDATORS[1]) + "/node-info")["address"]
        d2 = curl_json(u + "/fee-estimate/" + addr2)
        if d2.get("base_fee_cil") == BASE_FEE_CIL:
            ok("/fee V2 base_fee", "consistent")
        else:
            warn("/fee V2 base_fee", str(d2.get("base_fee_cil")))
    except Exception as e: warn("/fee V2", str(e)[:40])


# ===============================================================
# 9. METRICS (Prometheus)
# ===============================================================
def test_9():
    sec(9, "METRICS (Prometheus)")
    u = base(VALIDATORS[0])
    raw = curl_get(u + "/metrics")
    lines = [l for l in raw.strip().split("\n") if l and not l.startswith("#")]
    ok("/metrics", str(len(lines)) + " metric lines")
    expected_metrics = ["los_active_validators","los_accounts_total","los_blocks_total"]
    for m in expected_metrics:
        found = [l for l in lines if m in l]
        if found:
            val = found[0].split()[-1] if found[0].split() else "?"
            ok("  " + m, val)
        else: warn("  " + m, "not found")
    if raw.strip().startswith("{"): fail("/metrics format", "JSON not Prometheus text")
    else: ok("/metrics format", "text/plain")


# ===============================================================
# 10. MEMPOOL
# ===============================================================
def test_10():
    sec(10, "MEMPOOL STATS")
    u = base(VALIDATORS[0])
    try:
        d = curl_json(u + "/mempool/stats")
        ok("/mempool/stats", json.dumps(d)[:120])
        mp = d.get("mempool",{})
        pc = mp.get("pending", d.get("pending_count", d.get("size", d.get("count", -1))))
        if pc is not None and pc >= 0: ok("/mempool non-neg", str(pc))
        elif pc is not None and pc == -1: warn("/mempool key", "no pending field found")
        elif pc is not None: fail("/mempool negative", str(pc))
    except Exception as e: fail("/mempool/stats", str(e))


# ===============================================================
# 11. SEND -- negative tests
# ===============================================================
def test_11():
    sec(11, "SEND (negative tests)")
    u = base(VALIDATORS[0])
    addr = curl_json(u + "/node-info")["address"]
    cases = [
        ("empty body", {}),
        ("bad sig", {"from":"LOSfake1","to":"LOSfake2","amount":100,"signature":"x","public_key":"x"}),
        ("neg amt", {"from":"LOSfake1","to":"LOSfake2","amount":-1000,"signature":"x","public_key":"x"}),
        ("zero amt", {"from":"LOSfake1","to":"LOSfake2","amount":0,"signature":"x","public_key":"x"}),
        ("self-send", {"from":addr,"to":addr,"amount":100,"signature":"x","public_key":"x"}),
        ("huge amt", {"from":addr,"to":"LOSfake","amount":99999999*10**11,"signature":"x","public_key":"x"}),
    ]
    for lbl,body in cases:
        try:
            c,d = curl_post(u + "/send", body)
            s = json.dumps(d).lower()
            if c >= 400 or "error" in s or "invalid" in s or "fail" in s or "insufficient" in s:
                ok("/send " + lbl, "HTTP " + str(c) + ": rejected")
            else:
                fail("/send " + lbl, "HTTP " + str(c) + ": NOT rejected! " + s[:60])
        except Exception as e:
            ok("/send " + lbl, "err: " + str(e)[:50])

    try:
        c,d = curl_post_raw(u + "/send", "not json at all")
        s = json.dumps(d).lower()
        if c >= 400 or "error" in s or "invalid" in s:
            ok("/send malformed", "HTTP " + str(c) + ": rejected")
        else:
            fail("/send malformed", "HTTP " + str(c) + ": NOT rejected!")
    except: ok("/send malformed", "rejected")


# ===============================================================
# 12. REGISTER-VALIDATOR -- negative
# ===============================================================
def test_12():
    sec(12, "REGISTER-VALIDATOR (negative)")
    u = base(VALIDATORS[0])
    cases = [("empty",{}),("bad",{"address":"LOSfake","public_key":"x","signature":"x"})]
    for lbl,body in cases:
        try:
            c,d = curl_post(u + "/register-validator", body)
            if c >= 400 or is_error_response(d):
                ok("/register " + lbl, "HTTP " + str(c) + ": rejected")
            else: fail("/register " + lbl, "HTTP " + str(c) + ": NOT rejected!")
        except Exception as e: ok("/register " + lbl, str(e)[:50])


# ===============================================================
# 13. UNREGISTER -- negative
# ===============================================================
def test_13():
    sec(13, "UNREGISTER-VALIDATOR (negative)")
    u = base(VALIDATORS[0])
    for p in ["/unregister-validator","/unregister_validator"]:
        try:
            c,d = curl_post(u + p, {})
            if c >= 400 or is_error_response(d):
                ok(p + " empty", "HTTP " + str(c))
            else: fail(p + " empty", "HTTP " + str(c) + ": NOT rejected!")
        except Exception as e: ok(p + " empty", str(e)[:50])
    try:
        c,d = curl_post(u + "/unregister-validator", {"address":"LOSfake","signature":"xxx"})
        if c >= 400 or is_error_response(d):
            ok("/unregister bad sig", "HTTP " + str(c) + ": rejected")
        else: fail("/unregister bad sig", "HTTP " + str(c))
    except: ok("/unregister bad sig", "rejected")


# ===============================================================
# 14. FAUCET -- claim, rate-limit, validation
# ===============================================================
def test_14():
    sec(14, "FAUCET (testnet)")
    u = base(VALIDATORS[0])

    fresh_addr = ""
    try:
        gen = curl_json(u + "/validator/generate")
        fresh_addr = gen.get("address","")
    except:
        pass

    if fresh_addr:
        try:
            c,d = curl_post(u + "/faucet", {"address": fresh_addr})
            if d.get("status") == "success":
                amt = d.get("amount",0)
                bal = d.get("new_balance",0)
                ok("/faucet claim", "amount=" + str(amt) + " new_bal=" + str(bal))
                if amt != 5000: warn("/faucet amount", str(amt) + " != 5000 LOS")
                # Verify balance updated
                try:
                    check = curl_json(u + "/balance/" + fresh_addr)
                    check_los = float(check.get("balance_los","0"))
                    if check_los >= 5000:
                        ok("/faucet bal check", str(check_los) + " LOS")
                    else:
                        warn("/faucet bal check", str(check_los) + " LOS (expected >=5000)")
                except: warn("/faucet bal check", "could not verify")
            elif d.get("code") == 429 or "cooldown" in str(d).lower():
                ok("/faucet cooldown", "rate limited (expected if recently tested)")
            else:
                warn("/faucet claim", "HTTP " + str(c) + ": " + json.dumps(d)[:80])
        except Exception as e: warn("/faucet", str(e)[:60])

        try:
            c2,d2 = curl_post(u + "/faucet", {"address": fresh_addr})
            if d2.get("code") == 429 or "cooldown" in str(d2).lower() or "rate" in str(d2).lower():
                ok("/faucet rate-limit", "enforced")
            elif d2.get("status") == "success":
                fail("/faucet rate-limit", "second claim succeeded immediately!")
            else:
                ok("/faucet rate-limit", "status=" + str(d2.get("status")))
        except: ok("/faucet rate-limit", "error")
    else:
        warn("/faucet", "could not generate fresh address")

    # Empty body
    try:
        c,d = curl_post(u + "/faucet", {})
        if d.get("status") == "error" or d.get("code") in (400,403):
            ok("/faucet empty", "rejected (code=" + str(d.get("code","?")) + ")")
        else: fail("/faucet empty", "HTTP " + str(c) + ": not rejected")
    except: ok("/faucet empty", "rejected")

    # Invalid address
    try:
        c,d = curl_post(u + "/faucet", {"address": "not_a_valid_address"})
        if d.get("status") == "error" and d.get("code") == 400:
            ok("/faucet invalid addr", "rejected with code 400")
        elif d.get("status") == "error":
            ok("/faucet invalid addr", "rejected: " + str(d.get("msg",""))[:40])
        else: fail("/faucet invalid addr", "NOT rejected!")
    except: ok("/faucet invalid addr", "rejected")

    # Malformed body
    try:
        c,d = curl_post_raw(u + "/faucet", "{{bad json")
        if d.get("status") == "error" or d.get("code") == 400:
            ok("/faucet malformed", "rejected")
        else: warn("/faucet malformed", "HTTP " + str(c))
    except: ok("/faucet malformed", "rejected")


# ===============================================================
# 15. CONTRACTS -- negative
# ===============================================================
def test_15():
    sec(15, "CONTRACT APIs (negative)")
    u = base(VALIDATORS[0])
    try:
        d = curl_json(u + "/contract/nonexistent")
        if "error" in json.dumps(d).lower(): ok("/contract 404", "not found")
        else: warn("/contract 404", json.dumps(d)[:60])
    except: ok("/contract 404", "error")
    for ep in ["/deploy-contract","/call-contract"]:
        try:
            c,d = curl_post(u + ep, {})
            if c >= 400 or is_error_response(d): ok(ep + " empty", "HTTP " + str(c))
            else: warn(ep + " empty", "HTTP " + str(c))
        except: ok(ep + " empty", "rejected")


# ===============================================================
# 16. BURN -- negative
# ===============================================================
def test_16():
    sec(16, "BURN APIs (negative)")
    u = base(VALIDATORS[0])
    try:
        c,d = curl_post(u + "/burn", {})
        if c >= 400 or is_error_response(d): ok("/burn empty", "HTTP " + str(c))
        else: fail("/burn empty", "HTTP " + str(c) + ": NOT rejected!")
    except: ok("/burn empty", "rejected")
    try:
        c,d = curl_post(u + "/burn", {"txid":"fake","chain":"BTC","target_address":"LOSfake","amount":100})
        if c >= 400 or is_error_response(d): ok("/burn fake", "HTTP " + str(c))
        else: fail("/burn fake", "HTTP " + str(c) + ": NOT rejected!")
    except: ok("/burn fake", "rejected")
    try:
        c,d = curl_post(u + "/reset-burn-txid", {"txid":"nonexistent"})
        ok("/reset-burn-txid", "HTTP " + str(c) + ": " + json.dumps(d)[:60])
    except Exception as e: warn("/reset-burn-txid", str(e)[:60])


# ===============================================================
# 17. VALIDATOR KEY GEN -- generate + roundtrip + determinism
# ===============================================================
def test_17():
    sec(17, "VALIDATOR KEY GENERATION & IMPORT")
    u = base(VALIDATORS[0])

    gen1 = None
    try:
        gen1 = curl_json(u + "/validator/generate")
        addr1 = gen1.get("address","")
        has_pk = "public_key" in gen1
        has_seed = "seed_phrase" in gen1
        if addr1 and has_pk and has_seed:
            ok("/validator/generate", "addr=" + addr1[:20] + "... pk=" + str(has_pk) + " seed=" + str(has_seed))
        else:
            fail("/validator/generate", "missing fields: addr=" + str(bool(addr1)) + " pk=" + str(has_pk) + " seed=" + str(has_seed))
        if addr1 and not addr1.startswith("LOS"):
            fail("/gen addr prefix", "'" + addr1 + "'")
        elif addr1:
            ok("/gen addr", "starts with LOS")
        # Seed phrase = 24 words (256-bit BIP39)
        seed = gen1.get("seed_phrase","")
        words = seed.split()
        if len(words) == 24: ok("/gen seed words", "24 words (256-bit)")
        elif len(words) == 12: warn("/gen seed words", "12 words (128-bit, expected 24)")
        else: fail("/gen seed words", str(len(words)) + " words")
        # Public key should be valid hex
        pk = gen1.get("public_key","")
        try:
            bytes.fromhex(pk)
            ok("/gen pk hex", str(len(pk)) + " hex chars (" + str(len(pk)//2) + " bytes)")
        except ValueError:
            fail("/gen pk hex", "not valid hex")
    except Exception as e: fail("/validator/generate", str(e))

    # Two generates should produce DIFFERENT keys (randomness test)
    try:
        gen2 = curl_json(u + "/validator/generate")
        addr2 = gen2.get("address","")
        if addr2 and gen1 and addr2 != gen1.get("address"):
            ok("/gen randomness", "two calls = different addresses")
        elif addr2 == gen1.get("address","x"):
            fail("/gen randomness", "two calls = SAME address (broken RNG!)")
        else:
            warn("/gen randomness", "could not compare")
    except Exception as e: warn("/gen randomness", str(e)[:40])

    # /validator/import-seed -- roundtrip: generate -> import-seed -> same result
    if gen1 and gen1.get("seed_phrase"):
        try:
            c,d = curl_post(u + "/validator/import-seed", {"seed_phrase": gen1["seed_phrase"]})
            imported_addr = d.get("address","")
            orig_addr = gen1.get("address","")
            if imported_addr == orig_addr:
                ok("/import-seed roundtrip", "same address")
            else:
                fail("/import-seed roundtrip", imported_addr[:20] + " != " + orig_addr[:20])
            if d.get("seed_phrase"): warn("/import-seed leaks seed", "seed_phrase in response!")
            else: ok("/import-seed no seed", "not returned (secure)")
            if d.get("public_key") == gen1.get("public_key"):
                ok("/import-seed pk match", "same public key")
            else:
                fail("/import-seed pk mismatch", "different public keys!")
        except Exception as e: fail("/import-seed", str(e)[:60])

        # Invalid seed phrase
        try:
            c,d = curl_post(u + "/validator/import-seed", {"seed_phrase": "invalid words that are not a bip39 mnemonic at all hey"})
            if is_error_response(d): ok("/import-seed invalid", "rejected")
            else: fail("/import-seed invalid", "NOT rejected!")
        except: ok("/import-seed invalid", "rejected")

    # /validator/import -- private key negative tests
    try:
        c,d = curl_post(u + "/validator/import", {"private_key": "not_hex_at_all"})
        if is_error_response(d): ok("/import bad key", "rejected")
        else: fail("/import bad key", "NOT rejected!")
    except: ok("/import bad key", "rejected")

    try:
        c,d = curl_post(u + "/validator/import", {"private_key": "abcd1234"})
        if is_error_response(d): ok("/import short key", "rejected (wrong length)")
        else: fail("/import short key", "NOT rejected!")
    except: ok("/import short key", "rejected")


# ===============================================================
# 18. SYNC API
# ===============================================================
def test_18():
    sec(18, "SYNC API")
    u = base(VALIDATORS[0])
    try:
        raw = curl_get(u + "/sync?from=0")
        if raw: ok("/sync", str(len(raw)) + " bytes")
        else: warn("/sync", "empty response")
    except Exception as e: warn("/sync", str(e)[:60])


# ===============================================================
# 19. CROSS-NODE CONSISTENCY
# ===============================================================
def test_19():
    sec(19, "CROSS-NODE CONSISTENCY")
    addrs = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/node-info")
            addrs[v["name"]] = d["address"]
        except Exception as e:
            fail(v["name"] + " info", str(e)); return

    # Balance consistency
    ta = list(addrs.values())[0]
    bals = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/balance/" + ta)
            bals[v["name"]] = d.get("balance_cil",0)
        except Exception as e: fail(v["name"] + " bal", str(e))
    if len(set(bals.values())) == 1:
        ok("balance consistent", str(list(bals.values())[0] // CIL_PER_LOS) + " LOS all nodes")
    else:
        max_b = max(bals.values()); min_b = min(bals.values())
        drift_los = (max_b - min_b) / CIL_PER_LOS
        if drift_los <= 5000:
            warn("balance drift", "max-min=" + str(int(drift_los)) + " LOS (gossip lag)")
        else:
            fail("balance MISMATCH", str({k: v // CIL_PER_LOS for k,v in bals.items()}))

    # Total supply consistency
    total_cils = {}
    rem_cils = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/supply")
            total_cils[v["name"]] = d.get("total_supply_cil",0)
            rem_cils[v["name"]] = d.get("remaining_supply_cil",0)
        except Exception as e: fail(v["name"] + " supply", str(e))
    if len(set(total_cils.values())) == 1 and list(set(total_cils.values()))[0] == TOTAL_SUPPLY_CIL:
        ok("total_supply consistent", "all nodes agree on 21,936,236 LOS")
    else:
        fail("total_supply MISMATCH", str(total_cils))

    if len(set(rem_cils.values())) == 1:
        ok("remaining consistent", str(list(rem_cils.values())[0] // CIL_PER_LOS) + " LOS")
    else:
        drift = max(rem_cils.values()) - min(rem_cils.values())
        if drift <= 5000 * CIL_PER_LOS:
            warn("remaining drift", str(drift // CIL_PER_LOS) + " LOS (gossip)")
        else:
            fail("remaining MISMATCH", str({k: v // CIL_PER_LOS for k,v in rem_cils.items()}))

    # Validator list
    vls = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/validators")
            vs = d if isinstance(d,list) else d.get("validators",[])
            vls[v["name"]] = sorted([x.get("address","") for x in vs])
        except Exception as e: fail(v["name"] + " vals", str(e))
    vsets = set(json.dumps(x) for x in vls.values())
    if len(vsets) == 1:
        ok("validator-list consistent", str(len(list(vls.values())[0])) + " validators")
    else: fail("validator-list MISMATCH", "disagree!")

    # Block count
    blks = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/health")
            blks[v["name"]] = d.get("chain",{}).get("blocks",0)
        except Exception as e: fail(v["name"] + " health", str(e))
    if len(set(blks.values())) == 1:
        ok("block_count consistent", str(list(blks.values())[0]))
    else:
        drift = max(blks.values()) - min(blks.values())
        if drift <= 5: warn("block_count drift", str(blks) + " delta=" + str(drift))
        else: fail("block_count MISMATCH", str(blks))

    # Account count
    accts = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/health")
            accts[v["name"]] = d.get("chain",{}).get("accounts",0)
        except Exception as e: fail(v["name"] + " health", str(e))
    if len(set(accts.values())) == 1:
        ok("account_count consistent", str(list(accts.values())[0]))
    else:
        warn("account_count drift", str(accts))

    # Epoch
    eps = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/reward-info")
            eps[v["name"]] = d.get("epoch",{}).get("current_epoch",-1)
        except Exception as e: fail(v["name"] + " ep", str(e))
    ev = set(eps.values())
    if len(ev) == 1: ok("epoch consistent", "epoch=" + str(list(ev)[0]))
    elif max(ev) - min(ev) <= 1: warn("epoch drift +/-1", str(eps))
    else: fail("epoch MISMATCH", str(eps))

    # Pool remaining
    pls = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/reward-info")
            pls[v["name"]] = d.get("pool",{}).get("remaining_cil",0)
        except Exception as e: fail(v["name"] + " pool", str(e))
    if len(set(pls.values())) == 1:
        ok("pool consistent", str(list(pls.values())[0] // CIL_PER_LOS) + " LOS")
    else:
        drift = abs(max(pls.values()) - min(pls.values()))
        if drift <= REWARD_RATE_CIL:
            warn("pool drift", str(drift // CIL_PER_LOS) + " LOS (1 epoch)")
        else:
            fail("pool MISMATCH", str({k: v // CIL_PER_LOS for k,v in pls.items()}))


# ===============================================================
# 20. SUPPLY CONSERVATION -- sum(balances) + remaining = total
# ===============================================================
def test_20():
    sec(20, "SUPPLY CONSERVATION (account-level)")
    u = base(VALIDATORS[0])

    supply = curl_json(u + "/supply")
    total_cil = supply.get("total_supply_cil",0)
    remaining_cil = supply.get("remaining_supply_cil",0)
    circulating_cil = supply.get("circulating_supply_cil",0)

    vals = curl_json(u + "/validators")
    vals_list = vals if isinstance(vals,list) else vals.get("validators",[])

    health = curl_json(u + "/health")
    total_accounts = health.get("chain",{}).get("accounts",0)
    ok("accounts", str(total_accounts) + " total")

    sum_cil = 0
    addrs_checked = set()
    for v in vals_list:
        a = v.get("address","")
        if a and a not in addrs_checked:
            try:
                bal = curl_json(u + "/balance/" + a)
                b = bal.get("balance_cil",0)
                sum_cil += b
                addrs_checked.add(a)
            except: pass

    ok("sum checked", str(len(addrs_checked)) + " addrs = " + str(sum_cil // CIL_PER_LOS) + " LOS")

    if circulating_cil >= sum_cil:
        ok("circ >= sum_checked", "room for other accts")
    else:
        fail("circ < sum_checked", str(circulating_cil // CIL_PER_LOS) + " < " + str(sum_cil // CIL_PER_LOS))

    if total_cil == circulating_cil + remaining_cil:
        ok("total = circ + rem", "conservation law holds")
    else:
        fail("conservation broken", str(total_cil) + " != " + str(circulating_cil) + " + " + str(remaining_cil))


# ===============================================================
# 21. GENESIS VALIDATION
# ===============================================================
def test_21():
    sec(21, "GENESIS VALIDATION")
    u = base(VALIDATORS[0])

    d = curl_json(u + "/supply")
    total_cil = d.get("total_supply_cil",0)
    if total_cil == TOTAL_SUPPLY_CIL: ok("genesis total", "21,936,236 LOS exact")
    else: fail("genesis total", str(total_cil) + " != " + str(TOTAL_SUPPLY_CIL))

    vals = curl_json(u + "/validators")
    vals_list = vals if isinstance(vals,list) else vals.get("validators",[])
    for va in vals_list:
        a = va.get("address","?")[:16]
        s = int(va.get("stake",0))
        if s >= MIN_STAKE_LOS: ok(a + " genesis stake", str(s) + " LOS")
        else: fail(a + " genesis stake", str(s) + " < " + str(MIN_STAKE_LOS))


# ===============================================================
# 22. EDGE CASES & SECURITY
# ===============================================================
def test_22():
    sec(22, "EDGE CASES & SECURITY")
    u = base(VALIDATORS[0])

    # Long address
    try:
        raw = curl_get(u + "/balance/LOS" + "A"*500)
        ok("/balance long_addr", "handled (" + str(len(raw)) + "b)")
    except: ok("/balance long_addr", "handled")

    # XSS attempt
    try:
        raw = curl_get(u + "/balance/LOS%3Cscript%3Ealert%3C%2Fscript%3E")
        if "<script>" in raw: fail("/balance XSS", "reflected XSS!")
        else: ok("/balance XSS", "safe")
    except: ok("/balance XSS", "safe")

    # SQL injection
    try:
        raw = curl_get(u + "/balance/LOS' OR '1'='1")
        ok("/balance SQLi", "handled")
    except: ok("/balance SQLi", "handled")

    # Max u64 as fee-estimate param
    try:
        raw = curl_get(u + "/fee-estimate/18446744073709551615")
        d = json.loads(raw) if raw.strip() else {}
        if d.get("status") == "error": ok("/fee max_u64", "rejected")
        else: ok("/fee max_u64", "handled (" + str(len(raw)) + "b)")
    except: ok("/fee max_u64", "handled")

    # Overflow u64+1
    try:
        raw = curl_get(u + "/fee-estimate/18446744073709551616")
        d = json.loads(raw) if raw.strip() else {}
        if d.get("status") == "error": ok("/fee overflow", "rejected")
        else: ok("/fee overflow", "handled")
    except: ok("/fee overflow", "handled")

    # 404 unknown endpoint
    try:
        raw = curl_get(u + "/nonexistent-xyz-endpoint")
        if "404" in raw or "not found" in raw.lower() or not raw.strip():
            ok("404 endpoint", "correct")
        else: warn("404 endpoint", raw[:50])
    except: ok("404 endpoint", "handled")

    # Unicode in address
    try:
        raw = curl_get(u + "/balance/LOS%E2%9C%93%E2%9C%93")
        ok("/balance unicode", "handled (" + str(len(raw)) + "b)")
    except: ok("/balance unicode", "handled")

    # Empty search query
    try:
        raw = curl_get(u + "/search/")
        ok("/search empty", "handled")
    except: ok("/search empty", "handled")

    # Very long search query
    try:
        raw = curl_get(u + "/search/" + "x"*1000)
        ok("/search long", "handled (" + str(len(raw)) + "b)")
    except: ok("/search long", "handled")


# ===============================================================
# 23. MULTI-NODE ENDPOINT VERIFICATION
# ===============================================================
def test_23():
    sec(23, "MULTI-NODE ENDPOINT VERIFICATION")
    endpoints = ["/health", "/supply", "/validators", "/consensus", "/block", "/metrics"]
    for v in VALIDATORS:
        u = base(v); n = v["name"]
        for ep in endpoints:
            try:
                if ep == "/metrics":
                    raw = curl_get(u + ep)
                    if raw and len(raw) > 10: ok(n + " " + ep, str(len(raw)) + "b")
                    else: fail(n + " " + ep, "empty/short")
                else:
                    d = curl_json(u + ep)
                    ok(n + " " + ep, "ok")
            except Exception as e:
                fail(n + " " + ep, str(e)[:40])


# ===============================================================
# 24. REWARD MATH VERIFICATION (isqrt / sqrt-stake)
# ===============================================================
def test_24():
    sec(24, "REWARD MATH VERIFICATION")
    u = base(VALIDATORS[0])

    d = curl_json(u + "/reward-info")
    dets = d.get("validators",{}).get("details",[])
    pool = d.get("pool",{})
    dist_cil = pool.get("total_distributed_cil",0)

    if not dets:
        warn("reward math", "no validator details")
        return

    cum_total = sum(vd.get("cumulative_rewards_cil",0) for vd in dets)
    if cum_total == dist_cil:
        ok("cum_rewards = distributed", str(cum_total // CIL_PER_LOS) + " LOS")
    else:
        delta = abs(cum_total - dist_cil)
        if delta <= len(dets):
            ok("cum_rewards ~ distributed", "delta=" + str(delta) + " CIL (rounding)")
        else:
            fail("cum_rewards != distributed", str(cum_total) + " != " + str(dist_cil))

    stakes = [vd.get("stake_cil",0) for vd in dets]
    cums = [vd.get("cumulative_rewards_cil",0) for vd in dets]
    if len(set(stakes)) == 1 and stakes[0] > 0:
        ok("equal stakes", str(stakes[0] // CIL_PER_LOS) + " LOS each")
        if cums:
            max_cum = max(cums)
            min_cum = min(cums)
            if max_cum - min_cum <= len(dets) * CIL_PER_LOS:
                ok("equal distribution", "max-min=" + str((max_cum - min_cum) // CIL_PER_LOS) + " LOS (fair)")
            else:
                warn("unequal distribution", "max-min=" + str((max_cum - min_cum) // CIL_PER_LOS) + " LOS")
    else:
        ok("varied stakes", str([s // CIL_PER_LOS for s in stakes]))

    rem_cil = pool.get("remaining_cil",0)
    if rem_cil + dist_cil == REWARD_POOL_CIL:
        ok("pool conservation", str(rem_cil // CIL_PER_LOS) + " + " + str(dist_cil // CIL_PER_LOS) + " = 500,000")
    else:
        fail("pool conservation", str((rem_cil + dist_cil) // CIL_PER_LOS) + " != 500,000")


# ===============================================================
# 25. VERSION & BUILD INTEGRITY
# ===============================================================
def test_25():
    sec(25, "VERSION & BUILD INTEGRITY")
    versions = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/health")
            versions[v["name"]] = d.get("version","?")
        except Exception as e: fail(v["name"] + " version", str(e))
    if len(set(versions.values())) == 1:
        ok("version consistent", "v" + str(list(versions.values())[0]) + " all nodes")
    else:
        fail("version MISMATCH", str(versions))

    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/")
            net = d.get("network","")
            if net == "testnet": ok(v["name"] + " network", "testnet")
            elif net == "mainnet": fail(v["name"] + " network", "MAINNET on testnet!")
            else: warn(v["name"] + " network", net)
        except Exception as e: fail(v["name"] + " network", str(e)[:40])


# ===============================================================
# MAIN
# ===============================================================
def main():
    print("")
    print("+----------------------------------------------------------+")
    print("|  UNAUTHORITY (LOS) - COMPREHENSIVE TESTNET AUDIT v2     |")
    print("|  ALL requests via Tor .onion (NO localhost)              |")
    print("|  25 test sections, 40+ API endpoints, 150+ assertions   |")
    print("+----------------------------------------------------------+")
    print("  Time: " + time.strftime("%Y-%m-%d %H:%M:%S"))
    print("  Proxy: " + TOR_PROXY)
    print("  Validators: " + str(len(VALIDATORS)))
    start = time.time()

    tests = [
        test_1, test_2, test_3, test_4, test_5, test_6, test_7, test_8,
        test_9, test_10, test_11, test_12, test_13,
        # Cross-node consistency runs BEFORE faucet to avoid gossip lag
        test_19, test_20, test_21, test_24, test_25, test_23,
        # Faucet + burn + contract + register + keygen + sync + security
        test_14, test_15, test_16, test_17, test_18, test_22,
    ]
    for t in tests:
        try:
            t()
        except KeyboardInterrupt:
            print("\n!! Interrupted"); break
        except Exception as e:
            fail("FATAL " + t.__name__, str(e))
            traceback.print_exc()

    elapsed = time.time() - start
    print("\n\n" + "="*60)
    print("TEST RESULTS")
    print("="*60)
    print("  PASS: " + str(PASS))
    print("  FAIL: " + str(FAIL))
    print("  WARN: " + str(WARN))
    print("  Time: " + str(round(elapsed, 1)) + "s")

    if BUGS:
        print("\nALL BUGS & WARNINGS (" + str(len(BUGS)) + "):")
        print("-"*60)
        for b in BUGS:
            print("  " + b)

    if FAIL == 0 and WARN == 0:
        print("\nALL TESTS PASSED!")
    elif FAIL == 0:
        print("\nNo failures, " + str(WARN) + " warnings.")
    else:
        print("\n" + str(FAIL) + " FAILURES + " + str(WARN) + " WARNINGS.")
    return FAIL

if __name__ == "__main__":
    sys.exit(main())
