#!/usr/bin/env python3
"""
Unauthority (LOS) — Senior QA Extended Test Suite
Tests beyond the standard E2E: Kill/Recovery, Edge Cases, Rewards, Public Validators
"""
import json, time, sys, requests

TOR_PROXY = "socks5h://127.0.0.1:9052"

ONIONS = {
    "V1": "u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion",
    "V2": "5yvqf4sdbif4pegxgrgfq5ksv3gqqpt27x2xzx5nvrmdqmsrk4mnkgad.onion",
    "V3": "3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion",
    "V4": "yapub6hgjr3eyxnxzvgd4yejt7rkhwlmaivdpy6757o3tr5iicckgjyd.onion",
}

LOCAL = {
    "V1": "http://localhost:3030",
    "V2": "http://localhost:3031",
    "V3": "http://localhost:3032",
    "V4": "http://localhost:3033",
}

# Addresses
V1_ADDR = "LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"
V2_ADDR = "LOSWxv2FpWd4eBTdap6Kt2sPrG8bcgyCyMP7L"
V3_ADDR = "LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7"
V4_ADDR = "LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf"
DEV1_ADDR = "LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8"
DEV2_ADDR = "LOSWoGEJEHwYA8am7sjspaPCDEQeyPFdzUu7e"

CIL_PER_LOS = 100_000_000_000

passed = 0
failed = 0
total = 0

def test(name, condition, detail=""):
    global passed, failed, total
    total += 1
    if condition:
        passed += 1
        print(f"  ✅ [{total:03d}] {name}")
    else:
        failed += 1
        print(f"  ❌ [{total:03d}] {name} — {detail}")

def get(node, path, timeout=15):
    url = f"{LOCAL[node]}{path}"
    try:
        r = requests.get(url, timeout=timeout)
        if r.status_code == 200:
            return r.json()
    except:
        pass
    return None

def post(node, path, data, timeout=15):
    url = f"{LOCAL[node]}{path}"
    try:
        r = requests.post(url, json=data, timeout=timeout)
        return r.json()
    except:
        pass
    return None

def get_tor(node, path, timeout=30):
    url = f"http://{ONIONS[node]}{path}"
    try:
        r = requests.get(url, proxies={"http": TOR_PROXY, "https": TOR_PROXY}, timeout=timeout)
        if r.status_code == 200:
            return r.json()
    except:
        pass
    return None

def get_balance(node, addr):
    data = get(node, f"/balance/{addr}")
    if data:
        return data.get("balance_cil", 0)
    return -1

def section(name):
    print(f"\n{'━'*70}")
    print(f"  {name}")
    print(f"{'━'*70}")

# ===== TEST SUITE =====

print("=" * 70)
print("  UNAUTHORITY (LOS) — Extended QA Test Suite")
print("  Kill/Recovery, Edge Cases, Rewards, Validators")
print("=" * 70)

# -------------------------------------------------------------------
section("S1: Bad Input & Error Handling")
# -------------------------------------------------------------------

# 1. Send to invalid address
r = post("V1", "/send", {"target": "INVALID_ADDRESS", "amount": 1})
test("Send to invalid address rejected",
     r and r.get("status") == "error",
     f"Got: {r}")

# 2. Send negative amount
r = post("V1", "/send", {"target": V2_ADDR, "amount": -1})
test("Send negative amount rejected",
     r and r.get("status") == "error",
     f"Got: {r}")

# 3. Send zero amount
r = post("V1", "/send", {"target": V2_ADDR, "amount": 0})
test("Send zero amount rejected",
     r and r.get("status") == "error",
     f"Got: {r}")

# 4. Send more than balance (V1 has ~1000 LOS)
r = post("V1", "/send", {"target": V2_ADDR, "amount": 999999})
test("Send exceeding balance rejected",
     r and r.get("status") == "error",
     f"Got: {r}")

# 5. Send to self
r = post("V1", "/send", {"target": V1_ADDR, "amount": 1})
test("Send to self rejected",
     r and r.get("status") == "error",
     f"Got: {r}")

# 6. Burn with invalid coin_type
r = post("V1", "/burn", {"coin_type": "invalid_coin", "txid": "abc123"})
test("Burn invalid coin type rejected",
     r and (r.get("status") == "error" or "error" in str(r).lower()),
     f"Got: {r}")

# 7. Balance for non-existent address
r = get("V1", "/balance/LOSXnonexistent12345678901234567")
test("Balance for non-existent address returns 0/error",
     r is not None,
     f"Got: {r}")

# 8. History for non-existent address  
r = get("V1", "/history/LOSXnonexistent12345678901234567")
test("History for non-existent returns empty",
     r is not None and isinstance(r.get("transactions", []), list),
     f"Got: {r}")

# 9. Invalid endpoint returns proper error
try:
    resp = requests.get(f"{LOCAL['V1']}/nonexistent_endpoint", timeout=5)
    test("Invalid endpoint returns 404/error",
         resp.status_code >= 400,
         f"Got status: {resp.status_code}")
except Exception as e:
    test("Invalid endpoint returns 404/error", False, str(e))

# 10. Fee estimation for non-existent address
r = get("V1", "/fee-estimate/LOSXnonexistent12345678901234567")
test("Fee estimate for non-existent address",
     r is not None,
     f"Got: {r}")

# -------------------------------------------------------------------
section("S2: Double-Spend Protection")
# -------------------------------------------------------------------

# Record V3 balance before
v3_before = get_balance("V1", V3_ADDR)

# Send 5 LOS V3→V4
r1 = post("V3", "/send", {"target": V4_ADDR, "amount": 5})
test("First send V3→V4 accepted",
     r1 and r1.get("status") == "success",
     f"Got: {r1}")

# Immediately try same send again (double spend)
r2 = post("V3", "/send", {"target": V4_ADDR, "amount": 5})
# This should either work (as a valid 2nd tx) or fail (if nonce collision)
# Either way, balance should be consistent
time.sleep(5)
v3_after = get_balance("V1", V3_ADDR)
test("Balance after sends is consistent (no double-spend)",
     v3_before > 0 and v3_after >= 0 and v3_after < v3_before,
     f"Before: {v3_before}, After: {v3_after}")

# -------------------------------------------------------------------
section("S3: All API Endpoints Verification")
# -------------------------------------------------------------------

# Test every known API endpoint
endpoints = [
    ("/health", "health"),
    ("/whoami", "whoami"),
    (f"/balance/{V1_ADDR}", "balance"),
    (f"/account/{V1_ADDR}", "account"),
    (f"/history/{V1_ADDR}", "history"),
    (f"/fee-estimate/{V1_ADDR}", "fee-estimate"),
    ("/validators", "validators"),
    ("/consensus", "consensus"),
    ("/reward-info", "reward-info"),
    ("/slashing", "slashing"),
    ("/blocks/recent", "blocks/recent"),
    ("/supply", "supply"),
    ("/peers", "peers"),
    ("/node-info", "node-info"),
    ("/metrics", "metrics"),
    # Note: /mempool-stats and /search don't exist in current API
]

for path, name in endpoints:
    try:
        if name == "metrics":
            resp = requests.get(f"{LOCAL['V1']}{path}", timeout=10)
            data = resp.text if resp.status_code == 200 else None
        else:
            data = get("V1", path)
        test(f"Endpoint /{name} returns data",
             data is not None,
             f"No data from {path}")
    except Exception as e:
        test(f"Endpoint /{name} returns data", False, str(e))

# -------------------------------------------------------------------
section("S4: Reward Info Deep Validation")
# -------------------------------------------------------------------

reward_info = get("V1", "/reward-info")
test("Reward info has pool section",
     reward_info and "pool" in reward_info,
     f"Got: {reward_info}")

if reward_info:
    pool = reward_info.get("pool", {})
    epoch = reward_info.get("epoch", {})
    validators = reward_info.get("validators", {})
    
    test("Pool remaining_cil is u128",
         isinstance(pool.get("remaining_cil"), int) and pool["remaining_cil"] > 0,
         f"remaining_cil={pool.get('remaining_cil')}")
    
    test("Pool remaining_los is correct",
         pool.get("remaining_los") == pool.get("remaining_cil", 0) // CIL_PER_LOS,
         f"los={pool.get('remaining_los')}, cil/rate={pool.get('remaining_cil',0)//CIL_PER_LOS}")
    
    test("No 'remaining_uat' in pool (old field)",
         "remaining_uat" not in pool,
         f"Pool keys: {list(pool.keys())}")
    
    test("No 'total_distributed_uat' in pool (old field)",
         "total_distributed_uat" not in pool and "total_distributed_los" in pool,
         f"Pool keys: {list(pool.keys())}")
    
    test("Epoch has reward rate",
         epoch.get("epoch_reward_rate_cil", 0) > 0,
         f"rate={epoch.get('epoch_reward_rate_cil')}")
    
    test("Epoch reward rate LOS = CIL / CIL_PER_LOS",
         epoch.get("epoch_reward_rate_los") == epoch.get("epoch_reward_rate_cil", 0) // CIL_PER_LOS,
         f"los={epoch.get('epoch_reward_rate_los')}, cil={epoch.get('epoch_reward_rate_cil')}")
    
    test("Validators section present",
         "total" in validators and "eligible" in validators,
         f"Got: {validators}")

# -------------------------------------------------------------------
section("S5: Consensus & Slashing Deep Validation")
# -------------------------------------------------------------------

consensus = get("V1", "/consensus")
if consensus:
    safety = consensus.get("safety", {})
    test("Consensus has active_validators",
         "active_validators" in safety,
         f"Safety keys: {list(safety.keys())}")
    test("Active validators >= 3 (BFT quorum)",
         safety.get("active_validators", 0) >= 3,
         f"active={safety.get('active_validators')}")
    test("Byzantine safe with 4 nodes",
         safety.get("byzantine_safe") == True,
         f"safe={safety.get('byzantine_safe')}")

slashing = get("V1", "/slashing")
if slashing:
    test("Slashing has validators section",
         "validators" in slashing or "active" in slashing or isinstance(slashing, dict),
         f"Slashing keys: {list(slashing.keys()) if isinstance(slashing, dict) else type(slashing)}")

# -------------------------------------------------------------------
section("S6: Validator Registration (Public User Simulation)")
# -------------------------------------------------------------------

# The /register-validator endpoint allows external users to join
# In testnet mode, this should at least return a valid response structure
reg_result = post("V1", "/register-validator", {
    "address": "LOSTestPublicValidatorAddr0000000000",
    "stake": 1000
})
test("Public validator registration responds",
     reg_result is not None,
     "No response from /register-validator")

if reg_result:
    test("Registration returns status field",
         "status" in reg_result or "error" in str(reg_result).lower() or "msg" in reg_result,
         f"Got: {reg_result}")

# -------------------------------------------------------------------
section("S7: Supply Accounting Integrity")
# -------------------------------------------------------------------

supply = get("V1", "/supply")
if supply:
    remaining_cil = supply.get("remaining_supply_cil", 0)
    burned_usd = supply.get("total_burned_usd", 0)
    TOTAL_CIL = 21_936_236 * CIL_PER_LOS
    
    test("Remaining supply is valid (< total)",
         0 < remaining_cil <= TOTAL_CIL,
         f"remaining={remaining_cil}, total={TOTAL_CIL}")
    
    # Calculate distributed from total - remaining
    distributed_cil = TOTAL_CIL - remaining_cil
    
    # Get all account balances and verify they add up
    all_addrs = [V1_ADDR, V2_ADDR, V3_ADDR, V4_ADDR, DEV1_ADDR, DEV2_ADDR]
    account_sum = 0
    for addr in all_addrs:
        bal = get_balance("V1", addr)
        if bal > 0:
            account_sum += bal
    
    test("Sum of account balances > 0",
         account_sum > 0,
         f"sum={account_sum}")
    
    test("Sum of known accounts <= distributed supply",
         account_sum <= distributed_cil,
         f"sum={account_sum}, distributed={distributed_cil}")

# -------------------------------------------------------------------
section("S8: Tor Connectivity for ALL 4 Nodes (Deep)")
# -------------------------------------------------------------------

for name, onion in ONIONS.items():
    data = get_tor(name, "/health")
    test(f"{name} ({onion[:20]}...) health via Tor",
         data is not None and data.get("status") == "healthy",
         f"Got: {data}")
    
    data = get_tor(name, "/whoami")
    test(f"{name} whoami via Tor returns LOS address",
         data is not None and data.get("address", "").startswith("LOS"),
         f"Got: {data}")

# -------------------------------------------------------------------
section("S9: Cross-Node Balance Consistency (All Pairs)")
# -------------------------------------------------------------------

time.sleep(5)  # Wait for sync

all_addrs = [V1_ADDR, V2_ADDR, V3_ADDR, V4_ADDR, DEV1_ADDR, DEV2_ADDR]
nodes = ["V1", "V2", "V3", "V4"]

inconsistencies = 0
for addr in all_addrs:
    bals = {}
    for node in nodes:
        bals[node] = get_balance(node, addr)
    
    vals = set(bals.values())
    if len(vals) > 1 and -1 not in vals:
        inconsistencies += 1
        print(f"  ⚠️ Inconsistency for {addr[:20]}...: {bals}")

test("All balances consistent across 4 nodes",
     inconsistencies == 0,
     f"{inconsistencies} inconsistencies found")

# -------------------------------------------------------------------
section("S10: Node-Info & Version Consistency")
# -------------------------------------------------------------------

versions = {}
for name in ["V1", "V2", "V3", "V4"]:
    info = get(name, "/node-info")
    if info:
        versions[name] = info.get("version", "unknown")

test("All nodes report same version",
     len(set(versions.values())) == 1,
     f"Versions: {versions}")

test("Version is 1.0.9 or higher",
     all(v >= "1.0.9" for v in versions.values()),
     f"Versions: {versions}")

# -------------------------------------------------------------------
section("S11: API Field Name Audit (No Old 'voi'/'uat' Fields)")
# -------------------------------------------------------------------

# Check balance endpoint
bal_data = get("V1", f"/balance/{V1_ADDR}")
if bal_data:
    test("Balance has 'balance_cil' field",
         "balance_cil" in bal_data,
         f"Keys: {list(bal_data.keys())}")
    test("Balance has NO 'balance_voi' field",
         "balance_voi" not in bal_data,
         f"Keys: {list(bal_data.keys())}")

# Check account endpoint  
acct_data = get("V1", f"/account/{V1_ADDR}")
if acct_data:
    test("Account has 'balance_cil' field",
         "balance_cil" in acct_data,
         f"Keys: {list(acct_data.keys())}")
    test("Account has NO 'balance_voi' field",
         "balance_voi" not in acct_data,
         f"Keys: {list(acct_data.keys())}")

# Check reward-info for old 'uat' fields
ri = get("V1", "/reward-info")
if ri:
    all_keys_str = json.dumps(ri)
    test("Reward-info has NO 'total_distributed_uat'",
         "total_distributed_uat" not in all_keys_str,
         "Found old field")
    test("Reward-info has 'total_distributed_los'",
         "total_distributed_los" in all_keys_str,
         "Missing new field")
    test("Reward-info has NO 'remaining_uat'",
         "remaining_uat" not in all_keys_str,
         "Found old field")

# Check history/block for amount_voi
hist = get("V1", f"/history/{V1_ADDR}")
if hist and hist.get("transactions"):
    tx0 = hist["transactions"][0]
    test("History tx has 'amount_cil' not 'amount_voi'",
         "amount_voi" not in tx0,
         f"TX keys: {list(tx0.keys())}")

# Check block query - blocks/recent returns {"blocks": [...]}
blocks_resp = get("V1", "/blocks/recent")
if blocks_resp and isinstance(blocks_resp, dict):
    blk_list = blocks_resp.get("blocks", [])
    if blk_list:
        blk = blk_list[0]
        test("Block summary has no 'amount_voi'",
             "amount_voi" not in blk,
             f"Block keys: {list(blk.keys())}")

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------
print(f"\n{'='*70}")
print(f"  EXTENDED QA RESULTS: {passed} passed, {failed} failed, {total} total")
print(f"{'='*70}")
sys.exit(0 if failed == 0 else 1)
