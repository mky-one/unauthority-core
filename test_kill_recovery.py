#!/usr/bin/env python3
"""
Kill & Recovery Test — Kill a node, send transactions, restart it, verify sync
"""
import json, time, sys, requests, subprocess, os

LOCAL = {
    "V1": "http://localhost:3030",
    "V2": "http://localhost:3031",
    "V3": "http://localhost:3032",
    "V4": "http://localhost:3033",
}

V1_ADDR = "LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9"
V3_ADDR = "LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7"
V4_ADDR = "LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf"
DEV1_ADDR = "LOSX48Joabv6fKAdQLhe4H8UNe4ABk3ppqPo8"
CIL_PER_LOS = 100_000_000_000

BINARY = "./target/release/los-node"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

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

def get(node, path, timeout=10):
    try:
        r = requests.get(f"{LOCAL[node]}{path}", timeout=timeout)
        if r.status_code == 200:
            return r.json()
    except:
        pass
    return None

def post(node, path, data, timeout=10):
    try:
        r = requests.post(f"{LOCAL[node]}{path}", json=data, timeout=timeout)
        return r.json()
    except:
        pass
    return None

def get_balance(node, addr):
    data = get(node, f"/balance/{addr}")
    return data.get("balance_cil", 0) if data else -1

def is_alive(node):
    try:
        r = requests.get(f"{LOCAL[node]}/health", timeout=3)
        return r.status_code == 200
    except:
        return False

print("=" * 70)
print("  UNAUTHORITY (LOS) — Kill & Recovery Test")
print("=" * 70)

# -------------------------------------------------------------------
print("\n━━━ Phase 1: Pre-kill state snapshot ━━━")
# -------------------------------------------------------------------

# Record all balances on all live nodes
pre_kill = {}
for addr in [V1_ADDR, V3_ADDR, V4_ADDR, DEV1_ADDR]:
    pre_kill[addr] = get_balance("V1", addr)
    print(f"  {addr[:20]}... = {pre_kill[addr] / CIL_PER_LOS:.6f} LOS")

test("All nodes alive before kill",
     all(is_alive(n) for n in ["V1", "V2", "V3", "V4"]),
     "Some nodes not responding")

# -------------------------------------------------------------------
print("\n━━━ Phase 2: Kill V3 ━━━")
# -------------------------------------------------------------------

# Find V3 PID (port 3032)
result = subprocess.run(["lsof", "-ti", ":3032"], capture_output=True, text=True)
v3_pid = result.stdout.strip()
if v3_pid:
    subprocess.run(["kill", "-9", v3_pid])
    print(f"  Killed V3 (PID: {v3_pid})")
    time.sleep(2)

test("V3 is dead after kill",
     not is_alive("V3"),
     "V3 still responding")

# -------------------------------------------------------------------
print("\n━━━ Phase 3: Transact while V3 is down ━━━")
# -------------------------------------------------------------------

# Send 3 LOS from V1 to V4 (via V1)
r = post("V1", "/send", {"target": V4_ADDR, "amount": 3})
test("Send V1→V4 accepted while V3 down",
     r and r.get("status") == "success",
     f"Got: {r}")

time.sleep(5)

# Send 2 LOS from V4 to Dev1 (via V4)
r2 = post("V4", "/send", {"target": DEV1_ADDR, "amount": 2})
test("Send V4→Dev1 accepted while V3 down",
     r2 and r2.get("status") == "success",
     f"Got: {r2}")

time.sleep(5)

# Record balances on live nodes
mid_balances = {}
for addr in [V1_ADDR, V3_ADDR, V4_ADDR, DEV1_ADDR]:
    mid_balances[addr] = get_balance("V1", addr)

test("V1 balance decreased after send",
     mid_balances[V1_ADDR] < pre_kill[V1_ADDR],
     f"Before: {pre_kill[V1_ADDR]}, Now: {mid_balances[V1_ADDR]}")

test("V4 balance changed after sends",
     mid_balances[V4_ADDR] != pre_kill[V4_ADDR],
     f"Before: {pre_kill[V4_ADDR]}, Now: {mid_balances[V4_ADDR]}")

# -------------------------------------------------------------------
print("\n━━━ Phase 4: Restart V3 ━━━")
# -------------------------------------------------------------------

ONIONS = {
    "V3": "3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion",
}
BOOT_ALL = "127.0.0.1:4001,127.0.0.1:4002,127.0.0.1:4003,127.0.0.1:4004"

env = os.environ.copy()
env.update({
    "LOS_NODE_ID": "validator-3",
    "LOS_TOR_SOCKS5": "127.0.0.1:9052",
    "LOS_ONION_ADDRESS": ONIONS["V3"],
    "LOS_P2P_PORT": "4003",
    "LOS_BOOTSTRAP_NODES": BOOT_ALL,
    "LOS_TESTNET_LEVEL": "consensus",
})

log_path = os.path.join(BASE_DIR, "node_data/validator-3/node.log")
with open(log_path, "a") as logf:
    subprocess.Popen(
        [BINARY, "--port", "3032", "--data-dir", "node_data/validator-3"],
        env=env, cwd=BASE_DIR,
        stdout=logf, stderr=logf
    )
print("  V3 restarted")

# Wait for V3 to come alive
alive = False
for i in range(15):
    time.sleep(2)
    if is_alive("V3"):
        alive = True
        break

test("V3 alive after restart",
     alive,
     "V3 not responding after 30s")

# -------------------------------------------------------------------
print("\n━━━ Phase 5: Wait for V3 to sync ━━━")
# -------------------------------------------------------------------

print("  Waiting up to 60s for V3 sync convergence...")
converged = False
for i in range(12):
    time.sleep(5)
    v1_bal = get_balance("V1", V1_ADDR)
    v3_bal = get_balance("V3", V1_ADDR)
    if v1_bal >= 0 and v3_bal >= 0 and v1_bal == v3_bal:
        converged = True
        print(f"  Converged after {(i+1)*5}s")
        break

test("V3 synced V1 balance after restart",
     converged,
     f"V1={get_balance('V1', V1_ADDR)}, V3={get_balance('V3', V1_ADDR)}")

# Check all balances
for addr in [V1_ADDR, V4_ADDR, DEV1_ADDR]:
    v1_bal = get_balance("V1", addr)
    v3_bal = get_balance("V3", addr)
    test(f"V3 agrees with V1 on {addr[:20]}...",
         v1_bal == v3_bal,
         f"V1={v1_bal}, V3={v3_bal}")

# -------------------------------------------------------------------
print("\n━━━ Phase 6: Post-recovery transactions ━━━")
# -------------------------------------------------------------------

# Send from V3 after recovery
r3 = post("V3", "/send", {"target": V1_ADDR, "amount": 1})
test("V3 can send tx after recovery",
     r3 and r3.get("status") == "success",
     f"Got: {r3}")

time.sleep(5)

# Verify on V1 and V4
v1_final = get_balance("V1", V1_ADDR)
v4_final = get_balance("V4", V1_ADDR)
test("V1 and V4 agree on V1 balance after recovery tx",
     v1_final == v4_final,
     f"V1={v1_final}, V4={v4_final}")

# -------------------------------------------------------------------
print(f"\n{'='*70}")
print(f"  KILL & RECOVERY RESULTS: {passed} passed, {failed} failed, {total} total")
print(f"{'='*70}")
sys.exit(0 if failed == 0 else 1)
