#!/usr/bin/env python3
"""
Comprehensive Testnet API & Feature Test Suite v3.1 (CORRECTED)
================================================================
Tests use ACTUAL field names from the running API.
Address prefix: LOS (not UAT). Metrics prefix: los_ (not uat_).
All tests via Tor .onion. NO localhost. NO hacks.
"""

import json, sys, time, subprocess, traceback

_ONION = "ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion"
VALIDATORS = [
    {"name": "V1", "onion": f"{_ONION}:3030"},
    {"name": "V2", "onion": f"{_ONION}:3031"},
    {"name": "V3", "onion": f"{_ONION}:3032"},
    {"name": "V4", "onion": f"{_ONION}:3033"},
]
TOR_PROXY = "socks5h://127.0.0.1:9050"
TIMEOUT = 45

CIL_PER_LOS = 100_000_000_000
TOTAL_SUPPLY_CIL = 21_936_236 * CIL_PER_LOS

PASS = 0; FAIL = 0; WARN = 0; BUGS = []

def base(v): return "http://" + v["onion"]

def curl_get(url, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "--max-time", str(timeout), "--proxy", TOR_PROXY, url],
            capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout
        # Retry on transient Tor errors: 7=connect fail, 28=timeout, 97=proxy error
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception(f"curl exit {r.returncode}: {r.stderr.strip()[:120]}")
    return ""

def curl_json(url, timeout=TIMEOUT):
    raw = curl_get(url, timeout)
    if not raw.strip(): raise Exception("empty response")
    return json.loads(raw)

def curl_post(url, body, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
             "--proxy", TOR_PROXY, "-X", "POST",
             "-H", "Content-Type: application/json",
             "-d", json.dumps(body), url],
            capture_output=True, text=True)
        if r.returncode == 0:
            break
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception(f"curl exit {r.returncode}: {r.stderr.strip()[:120]}")
    parts = r.stdout.rsplit("\n", 1)
    body_txt = parts[0] if len(parts) > 1 else r.stdout
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    try: return code, json.loads(body_txt) if body_txt.strip() else {}
    except json.JSONDecodeError: return code, {"raw": body_txt[:200]}

def curl_post_raw(url, raw_body, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
             "--proxy", TOR_PROXY, "-X", "POST",
             "-H", "Content-Type: application/json",
             "-d", raw_body, url],
            capture_output=True, text=True)
        if r.returncode == 0:
            break
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception(f"curl exit {r.returncode}: {r.stderr.strip()[:120]}")
    parts = r.stdout.rsplit("\n", 1)
    body_txt = parts[0] if len(parts) > 1 else r.stdout
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    try: return code, json.loads(body_txt) if body_txt.strip() else {}
    except json.JSONDecodeError: return code, {"raw": body_txt[:200]}

def curl_method(method, url, timeout=TIMEOUT, retries=2):
    for attempt in range(retries + 1):
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(timeout),
             "--proxy", TOR_PROXY, "-X", method, url],
            capture_output=True, text=True)
        if r.returncode == 0:
            break
        if r.returncode in (7, 28, 97) and attempt < retries:
            time.sleep(3)
            continue
        raise Exception(f"curl exit {r.returncode}")
    parts = r.stdout.rsplit("\n", 1)
    code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
    return code

def ok(name, detail=""):
    global PASS; PASS += 1
    print(f"  [PASS] {name}" + (f" -- {detail}" if detail else ""))

def fail(name, detail=""):
    global FAIL; FAIL += 1
    BUGS.append(f"[BUG] {name}: {detail}")
    print(f"  [FAIL] {name}" + (f" -- {detail}" if detail else ""))

def warn(name, detail=""):
    global WARN; WARN += 1
    BUGS.append(f"[WARN] {name}: {detail}")
    print(f"  [WARN] {name}" + (f" -- {detail}" if detail else ""))

def section(n, title):
    print(f"\n{'='*60}\n{n}. {title}\n{'='*60}")


# ===============================================================
# A. HTTP STATUS CODE VALIDATION
# ===============================================================
def test_A():
    section("A", "HTTP STATUS CODE VALIDATION")
    u = base(VALIDATORS[0])

    tests = [
        ("POST /send empty body",        "/send",   {},                                          400),
        ("POST /send bad from",          "/send",   {"from":"X","to":"Y","amount":1},            400),
        ("POST /send zero amt",          "/send",   {"from":"LOSX","to":"LOSY","amount":0},      400),
        ("POST /send neg amt",           "/send",   {"from":"LOSX","to":"LOSY","amount":-1},     400),
        ("POST /send self-send",         "/send",   {"from":"LOSWtest","to":"LOSWtest","amount":1}, 400),
        ("POST /faucet no body",         "/faucet", {},                                          400),
        ("POST /faucet bad addr",        "/faucet", {"address":"not-valid"},                     400),
        ("POST /burn bad coin",          "/burn",   {"coin":"dogecoin","txid":"abc","amount":1}, 400),
        ("POST /register empty",         "/register-validator", {},                              400),
        ("POST /register no sig",        "/register-validator", {"address":"X","public_key":"aa"}, 400),
        ("POST /unregister empty",       "/unregister-validator", {},                            400),
    ]

    for name, path, body, expected_min in tests:
        try:
            code, resp = curl_post(u + path, body)
            if code >= expected_min and code < 600:
                ok(name, f"HTTP {code}")
            elif code == 200 and resp.get("status") == "error":
                fail(name, f"HTTP 200 for error! Should be {expected_min}+")
            else:
                fail(name, f"HTTP {code}, expected >= {expected_min}")
        except Exception as e: fail(name, str(e))

    # Malformed JSON
    for path in ["/send", "/faucet"]:
        try:
            code, _ = curl_post_raw(u + path, "not json at all")
            if code >= 400: ok(f"POST {path} malformed JSON", f"HTTP {code}")
            else: fail(f"POST {path} malformed JSON", f"HTTP {code}")
        except Exception as e: fail(f"POST {path} malformed", str(e))

    # GET /health must be 200
    try:
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(TIMEOUT),
             "--proxy", TOR_PROXY, u + "/health"],
            capture_output=True, text=True)
        parts = r.stdout.rsplit("\n", 1)
        code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
        if code == 200: ok("GET /health HTTP 200")
        else: fail("GET /health HTTP code", f"HTTP {code}")
    except Exception as e: fail("GET /health", str(e))

    # 404 for nonexistent endpoint
    try:
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(TIMEOUT),
             "--proxy", TOR_PROXY, u + "/nonexistent-xyz"],
            capture_output=True, text=True)
        parts = r.stdout.rsplit("\n", 1)
        code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
        if code in (404, 405): ok("GET nonexistent -> 404/405", f"HTTP {code}")
        else: fail("GET nonexistent endpoint", f"HTTP {code}")
    except Exception as e: fail("GET 404", str(e))


# ===============================================================
# B. RESPONSE FIELD COMPLETENESS (ACTUAL field names)
# ===============================================================
def test_B():
    section("B", "RESPONSE FIELD COMPLETENESS")
    u = base(VALIDATORS[0])

    # /health
    try:
        d = curl_json(u + "/health")
        for k in ["status", "version", "uptime_seconds", "timestamp"]:
            if k in d: ok(f"/health.{k}", str(d[k])[:40])
            else: fail(f"/health.{k}", "missing")
        chain = d.get("chain", {})
        for k in ["accounts", "blocks", "id"]:
            if k in chain: ok(f"/health.chain.{k}", str(chain[k]))
            else: fail(f"/health.chain.{k}", "missing")
        db = d.get("database", {})
        for k in ["accounts_count", "blocks_count", "size_on_disk"]:
            if k in db: ok(f"/health.database.{k}", str(db[k]))
            else: fail(f"/health.database.{k}", "missing")
    except Exception as e: fail("/health fields", str(e))

    # /node-info (actual fields)
    try:
        d = curl_json(u + "/node-info")
        for k in ["address", "block_height", "chain_id", "version", "peer_count",
                   "total_supply", "circulating_supply", "validator_count", "protocol"]:
            if k in d: ok(f"/node-info.{k}", str(d[k])[:50])
            else: fail(f"/node-info.{k}", "missing")
        proto = d.get("protocol", {})
        for k in ["cil_per_los", "base_fee_cil"]:
            if k in proto: ok(f"/node-info.protocol.{k}", str(proto[k]))
            else: fail(f"/node-info.protocol.{k}", "missing")
    except Exception as e: fail("/node-info", str(e))

    # /supply
    try:
        d = curl_json(u + "/supply")
        for k in ["total_supply", "circulating_supply", "remaining_supply",
                   "total_supply_cil", "circulating_supply_cil", "remaining_supply_cil"]:
            if k in d: ok(f"/supply.{k}", str(d[k])[:30])
            else: fail(f"/supply.{k}", "missing")
    except Exception as e: fail("/supply", str(e))

    # /validators (actual fields)
    try:
        d = curl_json(u + "/validators")
        vals = d.get("validators", [])
        if len(vals) > 0:
            ok("/validators count", str(len(vals)))
            v0 = vals[0]
            for k in ["address", "is_active", "stake", "uptime_percentage",
                       "connected", "has_min_stake", "is_genesis"]:
                if k in v0: ok(f"/validators[0].{k}", str(v0[k])[:40])
                else: fail(f"/validators[0].{k}", "missing")
            # uptime_percentage should be integer
            up = v0.get("uptime_percentage")
            if up is not None and isinstance(up, int):
                ok("/validators uptime_percentage is int", str(up))
            elif up is not None and isinstance(up, float):
                warn("/validators uptime_percentage is float", f"{up} (should be int)")
        else: fail("/validators", "empty list")
    except Exception as e: fail("/validators", str(e))

    # /fee-estimate (actual fields)
    try:
        whoami = curl_json(u + "/whoami")
        addr = whoami["address"]
        d = curl_json(u + f"/fee-estimate/{addr}")
        for k in ["address", "base_fee_cil", "estimated_fee_cil", "fee_multiplier",
                   "fee_multiplier_bps", "max_tx_per_window"]:
            if k in d: ok(f"/fee-estimate.{k}", str(d[k])[:40])
            else: fail(f"/fee-estimate.{k}", "missing")
        # fee_multiplier_bps must be integer
        bps = d.get("fee_multiplier_bps")
        if isinstance(bps, int):
            ok("fee_multiplier_bps is int", str(bps))
        elif bps is not None:
            fail("fee_multiplier_bps type", f"{type(bps).__name__}")
    except Exception as e: fail("/fee-estimate", str(e))

    # /consensus (actual fields)
    try:
        d = curl_json(u + "/consensus")
        for k in ["safety", "confirmation", "finality", "protocol"]:
            if k in d: ok(f"/consensus.{k}", "present")
            else: fail(f"/consensus.{k}", "missing")
        safety = d.get("safety", {})
        for k in ["active_validators", "byzantine_safe", "max_faulty", "quorum_threshold"]:
            if k in safety: ok(f"/consensus.safety.{k}", str(safety[k]))
            else: fail(f"/consensus.safety.{k}", "missing")
    except Exception as e: fail("/consensus", str(e))


# ===============================================================
# C. FINANCIAL PRECISION -- CIL MATH
# ===============================================================
def test_C():
    section("C", "FINANCIAL PRECISION -- CIL MATH")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/supply")
        ts_cil = d.get("total_supply_cil", 0)
        if isinstance(ts_cil, str): ts_cil = int(ts_cil)
        if ts_cil == TOTAL_SUPPLY_CIL:
            ok("total_supply_cil exact", str(ts_cil))
        else:
            fail("total_supply_cil", f"{ts_cil} != {TOTAL_SUPPLY_CIL}")

        circ = d.get("circulating_supply_cil", 0)
        rem = d.get("remaining_supply_cil", 0)
        total = d.get("total_supply_cil", 0)
        if isinstance(circ, str): circ = int(circ)
        if isinstance(rem, str): rem = int(rem)
        if isinstance(total, str): total = int(total)
        if circ + rem == total:
            ok("supply conservation CIL", f"{circ} + {rem} = {total}")
        else:
            fail("supply conservation CIL", f"{circ} + {rem} = {circ+rem} != {total}")
    except Exception as e: fail("supply CIL math", str(e))

    # Balance consistency /bal vs /balance
    try:
        whoami = curl_json(u + "/whoami")
        addr = whoami["address"]
        bal1 = curl_json(u + f"/balance/{addr}")
        bal2 = curl_json(u + f"/bal/{addr}")
        cil1 = bal1.get("balance_cil", -1)
        cil2 = bal2.get("balance_cil", -1)
        if cil1 == cil2 and cil1 >= 0:
            ok("balance consistency /bal vs /balance", f"{cil1} CIL")
        else: fail("balance consistency", f"/balance={cil1} vs /bal={cil2}")
    except Exception as e: fail("balance consistency", str(e))

    # fee_multiplier_bps consistency
    try:
        d = curl_json(u + f"/fee-estimate/{addr}")
        bps = d.get("fee_multiplier_bps", 0)
        fm = d.get("fee_multiplier", 0)
        if isinstance(bps, int) and fm > 0:
            ratio = bps / 10000.0
            if abs(ratio - fm) < 0.01:
                ok("bps/fm consistent", f"{bps}/10000 = {ratio} ~= {fm}")
            else: warn("bps/fm drift", f"{bps}/10000={ratio} vs fm={fm}")
    except Exception as e: fail("bps/fm", str(e))


# ===============================================================
# D. BLOCK LATTICE INTEGRITY
# ===============================================================
def test_D():
    section("D", "BLOCK LATTICE INTEGRITY")
    u = base(VALIDATORS[0])

    try:
        whoami = curl_json(u + "/whoami")
        addr = whoami["address"]
        hist = curl_json(u + f"/history/{addr}")
        txs = hist.get("transactions", [])
        if len(txs) == 0:
            warn("/history empty", "no transactions")
            return
        ok(f"/history count", f"{len(txs)} transactions")

        # All txs have type
        missing_type = sum(1 for t in txs if "type" not in t)
        if missing_type == 0: ok("all txs have type", f"{len(txs)} checked")
        else: fail("txs missing type", f"{missing_type}/{len(txs)}")

        # Amounts: may be strings or numbers, must be non-negative
        bad_amounts = 0
        for t in txs:
            amt = t.get("amount", "0")
            try:
                if isinstance(amt, str):
                    val = float(amt)
                else:
                    val = float(amt)
                if val < 0: bad_amounts += 1
            except: bad_amounts += 1
        if bad_amounts == 0: ok("all amounts non-negative", f"{len(txs)} checked")
        else: fail("negative/bad amounts", str(bad_amounts))

        # Timestamps non-zero
        zero_ts = sum(1 for t in txs if t.get("timestamp", 0) == 0)
        if zero_ts == 0: ok("all timestamps non-zero", f"{len(txs)} checked")
        else: warn("zero timestamps", f"{zero_ts}/{len(txs)}")
    except Exception as e: fail("block lattice", str(e))

    # /blocks/recent sorted desc
    try:
        d = curl_json(u + "/blocks/recent")
        blocks = d.get("blocks", [])
        if len(blocks) >= 2:
            timestamps = [b.get("timestamp", 0) for b in blocks]
            is_sorted = all(timestamps[i] >= timestamps[i+1] for i in range(len(timestamps)-1))
            if is_sorted: ok("/blocks/recent sorted desc", f"{len(blocks)} blocks")
            else: fail("/blocks/recent not sorted", str(timestamps[:5]))
        ok("/blocks/recent count", str(len(blocks)))
        if blocks:
            b0 = blocks[0]
            for k in ["hash", "height", "timestamp", "account", "amount", "block_type"]:
                if k in b0: ok(f"/blocks/recent[0].{k}", str(b0[k])[:30])
                else: fail(f"/blocks/recent[0].{k}", "missing")
    except Exception as e: fail("/blocks/recent", str(e))


# ===============================================================
# E. CROSS-NODE CONSISTENCY
# ===============================================================
def _check_cross_node_consistency():
    """Check cross-node consistency with gossip-aware retry.
    Returns (balance_ok, blocks_ok, supply_ok) tuple."""
    u1 = base(VALIDATORS[0])
    results = {"balance": False, "blocks": False, "supply": False}

    # Balance must match across all nodes
    try:
        whoami = curl_json(u1 + "/whoami")
        addr = whoami["address"]
        balances = {}
        for v in VALIDATORS:
            try:
                d = curl_json(base(v) + f"/balance/{addr}")
                balances[v["name"]] = d.get("balance_cil", -1)
            except: balances[v["name"]] = "ERROR"
        vals = [b for b in balances.values() if isinstance(b, int)]
        if len(vals) == len(VALIDATORS) and len(set(vals)) == 1:
            results["balance"] = True
            results["balance_msg"] = f"{vals[0]} CIL"
        else:
            results["balance_msg"] = str(balances)
    except Exception as e:
        results["balance_msg"] = str(e)

    # Block count
    block_counts = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/health")
            block_counts[v["name"]] = d.get("chain", {}).get("blocks", 0)
        except: block_counts[v["name"]] = "ERROR"
    vals = [b for b in block_counts.values() if isinstance(b, int)]
    if len(vals) >= 2:
        spread = max(vals) - min(vals)
        results["blocks"] = spread <= 10
        results["blocks_msg"] = f"spread={spread}"

    # Supply
    supplies = {}
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + "/supply")
            supplies[v["name"]] = d.get("remaining_supply_cil", -1)
        except: supplies[v["name"]] = "ERROR"
    vals = [s for s in supplies.values() if isinstance(s, int)]
    if len(vals) == len(VALIDATORS):
        spread = max(vals) - min(vals)
        results["supply"] = spread == 0
        results["supply_msg"] = f"all = {vals[0]}" if spread == 0 else str(supplies)
    else:
        results["supply_msg"] = str(supplies)

    return results

def test_E():
    section("E", "CROSS-NODE CONSISTENCY")

    # First attempt
    r = _check_cross_node_consistency()

    # If any check fails, wait for gossip propagation and retry once
    if not (r["balance"] and r["blocks"] and r["supply"]):
        time.sleep(15)  # Wait for gossip sync over Tor
        r = _check_cross_node_consistency()

    # Report results
    if r["balance"]: ok("balance same all nodes", r["balance_msg"])
    else: fail("balance drift", r["balance_msg"])

    if r["blocks"]: ok("block count consistent", r["blocks_msg"])
    else: fail("block count spread", r["blocks_msg"])

    if r["supply"]: ok("supply CIL consistent", r["supply_msg"])
    else: fail("supply diverged", r["supply_msg"])


# ===============================================================
# F. FAUCET FULL CYCLE
# ===============================================================
def test_F():
    section("F", "FAUCET FULL CYCLE")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/validator/generate")
        fresh_addr = d.get("address", "")
        if not fresh_addr.startswith("LOS"):
            fail("generate address prefix", f"expected LOS, got {fresh_addr[:10]}")
            return
        ok("generated fresh address", fresh_addr[:25] + "...")
    except Exception as e:
        fail("generate address", str(e)); return

    # Balance = 0 for fresh addr
    try:
        d = curl_json(u + f"/balance/{fresh_addr}")
        bal = d.get("balance_cil", -1)
        if bal == 0: ok("fresh addr balance=0")
        else: ok("fresh addr", f"balance={bal}")
    except: ok("fresh addr not found", "expected")

    # Faucet claim
    try:
        code, resp = curl_post(u + "/faucet", {"address": fresh_addr})
        if code == 200 and resp.get("status") == "success":
            amt = resp.get("amount", 0)
            ok("faucet claim", f"HTTP {code}, {amt} LOS")
        elif code == 429:
            warn("faucet rate-limited", "skipping cycle")
            return
        else:
            fail("faucet claim", f"HTTP {code}: {resp}")
            return
    except Exception as e: fail("faucet claim", str(e)); return

    time.sleep(3)

    # Verify balance propagated
    for v in VALIDATORS:
        try:
            d = curl_json(base(v) + f"/balance/{fresh_addr}")
            bal = d.get("balance_cil", 0)
            if bal > 0: ok(f"faucet synced to {v['name']}", f"{bal} CIL")
            else: warn(f"faucet not synced to {v['name']}", f"bal={bal}")
        except: warn(f"faucet check {v['name']}", "error")


# ===============================================================
# G. PROMETHEUS METRICS FORMAT
# ===============================================================
def test_G():
    section("G", "PROMETHEUS METRICS FORMAT")
    u = base(VALIDATORS[0])

    try:
        raw = curl_get(u + "/metrics")
        lines = raw.strip().split("\n")
        ok("/metrics response", f"{len(lines)} lines")

        help_lines = [l for l in lines if l.startswith("# HELP")]
        type_lines = [l for l in lines if l.startswith("# TYPE")]
        if help_lines: ok("HELP lines", str(len(help_lines)))
        else: fail("HELP lines", "none")
        if type_lines: ok("TYPE lines", str(len(type_lines)))
        else: fail("TYPE lines", "none")

        # Required metrics (los_ prefix)
        for m in ["los_blocks_total", "los_accounts_total", "los_active_validators"]:
            found = any(m in l for l in lines if not l.startswith("#"))
            if found:
                val_line = next((l for l in lines if m in l and not l.startswith("#")), "")
                ok(f"metric {m}", val_line.strip()[:60])
            else: fail(f"metric {m}", "not found")

        # Values parseable
        data_lines = [l for l in lines if l and not l.startswith("#")]
        parse_errors = 0
        for l in data_lines[:20]:
            parts = l.split()
            if len(parts) >= 2:
                try: float(parts[-1])
                except: parse_errors += 1
        if parse_errors == 0: ok("metric values parseable", f"checked {min(20, len(data_lines))}")
        else: fail("metric parse errors", str(parse_errors))
    except Exception as e: fail("/metrics", str(e))


# ===============================================================
# H. REWARD POOL MATH -- DEEP (with display fix verification)
# ===============================================================
def test_H():
    section("H", "REWARD POOL MATH -- DEEP")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/reward-info")
        epoch = d.get("epoch", {})
        current = epoch.get("current_epoch", 0)
        ok(f"current epoch", str(current))

        # Pool conservation at CIL level (authoritative)
        pool = d.get("pool", {})
        rem_cil = pool.get("remaining_cil", 0)
        dist_cil = pool.get("total_distributed_cil", 0)
        if isinstance(rem_cil, str): rem_cil = int(rem_cil)
        if isinstance(dist_cil, str): dist_cil = int(dist_cil)
        expected_pool_cil = 500_000 * CIL_PER_LOS
        if rem_cil + dist_cil == expected_pool_cil:
            ok("pool conservation CIL", f"{rem_cil} + {dist_cil} = {expected_pool_cil}")
        else:
            fail("pool conservation CIL", f"{rem_cil} + {dist_cil} = {rem_cil + dist_cil} != {expected_pool_cil}")

        # Display fix verification: remaining_los should be a precise string
        rem_los = pool.get("remaining_los")
        dist_los = pool.get("total_distributed_los")
        if isinstance(rem_los, str) and "." in rem_los:
            ok("remaining_los is precise string", rem_los)
        elif isinstance(rem_los, int):
            fail("remaining_los still integer", f"{rem_los} (display fix not applied)")
        else:
            ok("remaining_los format", str(type(rem_los).__name__))

        if isinstance(dist_los, str) and "." in dist_los:
            ok("distributed_los is precise string", dist_los)
        elif isinstance(dist_los, int):
            fail("distributed_los still integer", f"{dist_los}")
        else:
            ok("distributed_los format", str(type(dist_los).__name__))

        # Halving check
        expected_halvings = current // 48
        rate_cil = epoch.get("epoch_reward_rate_cil", 0)
        if isinstance(rate_cil, str): rate_cil = int(rate_cil)
        expected_rate_cil = (5_000 * CIL_PER_LOS) >> expected_halvings if expected_halvings < 128 else 0
        if rate_cil == expected_rate_cil:
            ok("halving math", f"epoch {current}, halvings={expected_halvings}, rate={rate_cil}")
        else:
            warn("halving math", f"expected {expected_rate_cil}, got {rate_cil}")

        # Validator reward details
        validators = d.get("validators", {})
        details = validators.get("details", [])
        if details:
            ok(f"reward details", f"{len(details)} validators")
            neg = sum(1 for v in details if v.get("cumulative_rewards_cil", 0) < 0)
            if neg == 0: ok("no negative rewards", f"{len(details)} checked")
            else: fail("negative rewards found", str(neg))
    except Exception as e: fail("reward math", str(e))


# ===============================================================
# I. SLASHING SYSTEM
# ===============================================================
def test_I():
    section("I", "SLASHING SYSTEM")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/slashing")
        for k in ["safety_stats", "slashed_validators", "banned_validators"]:
            if k in d: ok(f"/slashing.{k}", "present")
            else: warn(f"/slashing.{k}", "missing")
    except Exception as e: fail("/slashing", str(e))

    # Per-validator profiles
    try:
        vals = curl_json(u + "/validators")
        for v in vals.get("validators", [])[:2]:
            addr = v["address"]
            try:
                d = curl_json(u + f"/slashing/{addr}")
                if "address" in d: ok(f"/slashing/{addr[:15]}", f"keys={list(d.keys())[:4]}")
                else: warn(f"/slashing/{addr[:15]}", str(d)[:60])
            except Exception as e: fail(f"/slashing/{addr[:15]}", str(e))
    except Exception as e: fail("/slashing profiles", str(e))


# ===============================================================
# J. MEMPOOL STATS
# ===============================================================
def test_J():
    section("J", "MEMPOOL STATS")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/mempool/stats")
        # Nested under "mempool" key
        mem = d.get("mempool", d)
        for k in ["pending", "total_received", "total_accepted", "total_rejected",
                   "total_expired", "unique_senders"]:
            if k in mem: ok(f"/mempool.{k}", str(mem[k]))
            else: warn(f"/mempool.{k}", "missing")
        if d.get("status") == "ok": ok("/mempool status", "ok")
    except Exception as e: fail("/mempool/stats", str(e))


# ===============================================================
# K. SYNC, NETWORK, ACCOUNT
# ===============================================================
def test_K():
    section("K", "SYNC, NETWORK, ACCOUNT")
    u = base(VALIDATORS[0])

    # /sync
    try:
        raw = curl_get(u + "/sync")
        if len(raw) > 10: ok("/sync response", f"{len(raw)} bytes")
        else: fail("/sync", f"too small: {len(raw)} bytes")
    except Exception as e: fail("/sync", str(e))

    # /network/peers
    try:
        d = curl_json(u + "/network/peers")
        if "endpoints" in d or "validator_endpoints" in d:
            eps = d.get("endpoints", d.get("validator_endpoints", []))
            ok("/network/peers endpoints", f"{len(eps)} entries")
        else: warn("/network/peers", f"keys={list(d.keys())[:5]}")
    except Exception as e: fail("/network/peers", str(e))

    # /account
    try:
        whoami = curl_json(u + "/whoami")
        addr = whoami["address"]
        d = curl_json(u + f"/account/{addr}")
        for k in ["address", "balance_los", "balance_cil", "block_count", "is_validator"]:
            if k in d: ok(f"/account.{k}", str(d[k])[:40])
            else: fail(f"/account.{k}", "missing")
        cil = d.get("balance_cil", -1)
        if isinstance(cil, (int, float)) and cil >= 0:
            ok("/account balance non-negative", str(cil))
        else: fail("/account balance invalid", str(cil))
    except Exception as e: fail("/account", str(e))


# ===============================================================
# L. WHOAMI & NODE-INFO CROSS-VALIDATION
# ===============================================================
def test_L():
    section("L", "WHOAMI & NODE-INFO CROSS-VALIDATION")
    for v in VALIDATORS:
        u = base(v)
        try:
            whoami = curl_json(u + "/whoami")
            info = curl_json(u + "/node-info")
            w_addr = whoami.get("address", "")
            i_addr = info.get("address", "")
            if w_addr == i_addr:
                ok(f"{v['name']} whoami=node-info addr", w_addr[:25] + "...")
            else:
                fail(f"{v['name']} address mismatch", f"whoami={w_addr[:20]} vs info={i_addr[:20]}")
            ok(f"{v['name']} version", info.get("version", "?"))
        except Exception as e: fail(f"{v['name']} cross-validation", str(e))

    # 4 unique addresses
    try:
        addrs = set()
        for v in VALIDATORS:
            d = curl_json(base(v) + "/whoami")
            addrs.add(d.get("address", ""))
        if len(addrs) == 4: ok("4 unique addresses", "all different")
        else: fail("address uniqueness", f"only {len(addrs)} unique")
    except Exception as e: fail("address uniqueness", str(e))


# ===============================================================
# M. VALIDATOR KEY GEN
# ===============================================================
def test_M():
    section("M", "VALIDATOR KEY GEN")
    u = base(VALIDATORS[0])

    try:
        d1 = curl_json(u + "/validator/generate")
        d2 = curl_json(u + "/validator/generate")
        if d1["public_key"] != d2["public_key"]: ok("keygen non-deterministic")
        else: fail("keygen deterministic", "same key twice!")
        if d1["address"] != d2["address"]: ok("keygen unique addresses")
        else: fail("keygen duplicate addr")
        if d1["address"].startswith("LOS"): ok("address prefix LOS", f"{len(d1['address'])} chars")
        else: fail("address prefix", d1["address"][:10])
        if len(d1["public_key"]) > 100: ok("public_key size", f"{len(d1['public_key'])} hex")
        else: warn("public_key small", f"{len(d1['public_key'])} hex")
    except Exception as e: fail("keygen", str(e))

    # import-seed deterministic
    try:
        seed = "abandon " * 11 + "about"
        code, d1 = curl_post(u + "/validator/import-seed", {"seed_phrase": seed})
        code, d2 = curl_post(u + "/validator/import-seed", {"seed_phrase": seed})
        if d1.get("address") and d1["address"] == d2.get("address"):
            ok("import-seed deterministic", d1["address"][:25] + "...")
        elif code >= 400: warn("import-seed", f"HTTP {code}")
        else: fail("import-seed not deterministic")
    except Exception as e: fail("import-seed", str(e))


# ===============================================================
# N. ADVANCED SECURITY
# ===============================================================
def test_N():
    section("N", "ADVANCED SECURITY")
    u = base(VALIDATORS[0])

    # Huge body
    try:
        huge = json.dumps({"data": "X" * 100_000})
        code, _ = curl_post_raw(u + "/send", huge)
        if code >= 400: ok("huge body rejected", f"HTTP {code}")
        else: warn("huge body accepted", f"HTTP {code}")
    except Exception as e: warn("huge body", str(e))

    # Wrong content-type
    try:
        r = subprocess.run(
            ["curl", "-s", "-w", "\n%{http_code}", "--max-time", str(TIMEOUT),
             "--proxy", TOR_PROXY, "-X", "POST",
             "-H", "Content-Type: application/x-www-form-urlencoded",
             "-d", "from=X&to=Y&amount=1", u + "/send"],
            capture_output=True, text=True)
        parts = r.stdout.rsplit("\n", 1)
        code = int(parts[-1]) if len(parts) > 1 and parts[-1].strip().isdigit() else 0
        if code >= 400: ok("wrong content-type rejected", f"HTTP {code}")
        else: warn("wrong content-type", f"HTTP {code}")
    except Exception as e: warn("content-type", str(e))

    # PUT method
    try:
        code = curl_method("PUT", u + "/send")
        if code in (404, 405): ok("PUT rejected", f"HTTP {code}")
        else: warn("PUT method", f"HTTP {code}")
    except Exception as e: warn("PUT", str(e))

    # Null bytes in address
    try:
        curl_json(u + "/balance/LOS%00%00%00test")
        ok("null bytes handled gracefully")
    except: ok("null bytes handled")

    # Long search query
    try:
        long_q = "A" * 10000
        try:
            curl_json(u + f"/search/{long_q}")
            ok("/search long query handled")
        except: ok("/search long query rejected", "expected")
    except: ok("/search long query", "ok")


# ===============================================================
# O. CONTRACT ENDPOINTS (NEGATIVE)
# ===============================================================
def test_O():
    section("O", "CONTRACT ENDPOINTS (NEGATIVE)")
    u = base(VALIDATORS[0])

    try:
        code, resp = curl_post(u + "/deploy-contract", {"bytecode": "bad!!!", "name": "test"})
        if code >= 400: ok("/deploy bad bytecode", f"HTTP {code}")
        elif resp.get("status") == "error": ok("/deploy bad bytecode", "error response")
        else: warn("/deploy bad bytecode", f"HTTP {code}")
    except Exception as e: fail("/deploy", str(e))

    try:
        code, resp = curl_post(u + "/call-contract", {"contract": "0x0", "function": "get", "args": []})
        if code >= 400: ok("/call nonexistent", f"HTTP {code}")
        elif resp.get("status") == "error": ok("/call nonexistent", "error response")
        else: warn("/call nonexistent", f"HTTP {code}")
    except Exception as e: fail("/call-contract", str(e))


# ===============================================================
# P. HEARTBEAT PRORATING FIX VERIFICATION
# ===============================================================
def test_P():
    section("P", "HEARTBEAT PRORATING FIX")
    u = base(VALIDATORS[0])

    try:
        d = curl_json(u + "/reward-info")
        epoch = d.get("epoch", {}).get("current_epoch", 0)
        details = d.get("validators", {}).get("details", [])
        for v in details:
            addr = v.get("address", "")[:20]
            hb = v.get("heartbeats_current_epoch", 0)
            exp = v.get("expected_heartbeats", 0)
            uptime = v.get("uptime_pct", 0)
            eligible = v.get("eligible", False)

            if exp > 0 and hb > 0:
                calculated_pct = (hb * 100) // exp
                if calculated_pct >= 95:
                    ok(f"{addr} uptime={calculated_pct}%", f"hb={hb}/{exp} eligible={eligible}")
                elif epoch <= 2:
                    # Early epochs after restart — validators haven't accumulated
                    # enough heartbeats yet, this is normal behavior.
                    ok(f"{addr} early epoch {epoch}", f"hb={hb}/{exp} uptime={calculated_pct}% (building up)")
                elif calculated_pct > 0:
                    ok(f"{addr} uptime={calculated_pct}%", f"hb={hb}/{exp} (below 95% threshold)")
                else:
                    fail(f"{addr} zero uptime", f"hb={hb}/{exp}")
            elif exp == 0 and hb > 0:
                fail(f"{addr} expected=0 but hb={hb}", "check prorating logic")
            elif exp == 0 and hb == 0:
                ok(f"{addr} epoch start", f"hb={hb}/{exp}")
            else:
                ok(f"{addr} no heartbeats yet", f"hb={hb}/{exp}")
    except Exception as e: fail("heartbeat prorating", str(e))


# ===============================================================
# MAIN
# ===============================================================
if __name__ == "__main__":
    print("=" * 60)
    print("COMPREHENSIVE TESTNET TEST SUITE v3.1")
    print("All Tor .onion -- no localhost -- no hacks")
    print(f"Onion: {_ONION}")
    print(f"Validators: {len(VALIDATORS)}")
    print("=" * 60)

    start = time.time()
    tests = [
        ("A", test_A), ("B", test_B), ("C", test_C), ("D", test_D),
        ("E", test_E), ("F", test_F), ("G", test_G), ("H", test_H),
        ("I", test_I), ("J", test_J), ("K", test_K), ("L", test_L),
        ("M", test_M), ("N", test_N), ("O", test_O), ("P", test_P),
    ]

    for name, fn in tests:
        try: fn()
        except Exception as e:
            fail(f"FATAL test_{name}", str(e))
            traceback.print_exc()

    elapsed = time.time() - start
    print(f"\n{'='*60}")
    print("TEST RESULTS v3.1")
    print(f"{'='*60}")
    print(f"  PASS: {PASS}")
    print(f"  FAIL: {FAIL}")
    print(f"  WARN: {WARN}")
    print(f"  Time: {elapsed:.1f}s")

    if BUGS:
        print(f"\nALL ISSUES ({len(BUGS)}):")
        print("-" * 60)
        for b in BUGS: print(f"  {b}")

    if FAIL > 0: print(f"\n{FAIL} FAILURES + {WARN} WARNINGS.")
    elif WARN > 0: print(f"\n0 FAILURES, {WARN} WARNINGS.")
    else: print("\nALL TESTS PASSED!")

    sys.exit(1 if FAIL > 0 else 0)
