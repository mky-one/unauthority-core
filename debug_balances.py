#!/usr/bin/env python3
"""Debug zero-balance issue for V2 and V4"""
import json
import urllib.request
import sys

NODES = {
    "V1": "http://localhost:3030",
    "V2": "http://localhost:3031",
    "V3": "http://localhost:3032",
    "V4": "http://localhost:3033",
}

VALIDATORS = {
    "V1": "LOSX1YFTHpMNEDH8hRku2XDkVhCtG28ZiM1s9",
    "V2": "LOSWxv2FpWd4eBTdap6Kt2sPrG8bcgyCyMP7L",
    "V3": "LOSWtaknGVs5jvqwX6zS1XPNeEPooh61XaxG7",
    "V4": "LOSWyvoJhUn1j9K5hTAKFcFhWPJiXUYQJWsnf",
}

def fetch(url):
    try:
        req = urllib.request.urlopen(url, timeout=5)
        return json.loads(req.read())
    except Exception as e:
        return {"error": str(e)}

print("=" * 70)
print("CROSS-NODE BALANCE COMPARISON")
print("=" * 70)
# Check each validator's balance as seen from EACH node
for vname, vaddr in VALIDATORS.items():
    print(f"\n--- {vname} ({vaddr[:12]}...) ---")
    for nname, nurl in NODES.items():
        data = fetch(f"{nurl}/balance/{vaddr}")
        if "error" in data:
            print(f"  {nname}: ERROR - {data['error']}")
        else:
            bal = data.get("balance_los", "?")
            blk = data.get("block_count", "?")
            head = str(data.get("head", "?"))[:16]
            print(f"  {nname}: balance={bal} LOS, blocks={blk}, head={head}...")

print("\n" + "=" * 70)
print("FULL TRANSACTION HISTORY FOR V2 (from V1)")
print("=" * 70)
data = fetch(f"{NODES['V1']}/history/{VALIDATORS['V2']}")
txs = data.get("transactions", [])
print(f"Total transactions: {len(txs)}")
running = 0
for i, t in enumerate(txs):
    ttype = t.get("type", "?")
    amt = t.get("amount", "0")
    frm = t.get("from", "?")
    to = t.get("to", "?")
    amt_f = float(amt) if amt else 0
    if ttype in ("genesis", "mint", "receive"):
        running += amt_f
    elif ttype == "send":
        running -= amt_f
    print(f"  [{i:2d}] {ttype:10s} amt={amt:>25s} from={frm[:12]:12s} to={to[:30]:30s} running~={running:.5f}")

print(f"\nExpected balance from history: {running:.11f} LOS")

print("\n" + "=" * 70)
print("FULL TRANSACTION HISTORY FOR V4 (from V1)")
print("=" * 70)
data = fetch(f"{NODES['V1']}/history/{VALIDATORS['V4']}")
txs = data.get("transactions", [])
print(f"Total transactions: {len(txs)}")
running = 0
for i, t in enumerate(txs):
    ttype = t.get("type", "?")
    amt = t.get("amount", "0")
    frm = t.get("from", "?")
    to = t.get("to", "?")
    amt_f = float(amt) if amt else 0
    if ttype in ("genesis", "mint", "receive"):
        running += amt_f
    elif ttype == "send":
        running -= amt_f
    print(f"  [{i:2d}] {ttype:10s} amt={amt:>25s} from={frm[:12]:12s} to={to[:30]:30s} running~={running:.5f}")

print(f"\nExpected balance from history: {running:.11f} LOS")

print("\n" + "=" * 70)
print("V2 HISTORY ON V2 ITSELF")
print("=" * 70)
data = fetch(f"{NODES['V2']}/history/{VALIDATORS['V2']}")
txs = data.get("transactions", [])
print(f"Total transactions: {len(txs)}")
running = 0
for i, t in enumerate(txs):
    ttype = t.get("type", "?")
    amt = t.get("amount", "0")
    frm = t.get("from", "?")
    to = t.get("to", "?")
    amt_f = float(amt) if amt else 0
    if ttype in ("genesis", "mint", "receive"):
        running += amt_f
    elif ttype == "send":
        running -= amt_f
    print(f"  [{i:2d}] {ttype:10s} amt={amt:>25s} from={frm[:12]:12s} to={to[:30]:30s} running~={running:.5f}")

print(f"\nExpected balance from V2's own history: {running:.11f} LOS")

print("\n" + "=" * 70)
print("V4 HISTORY ON V4 ITSELF")
print("=" * 70)
data = fetch(f"{NODES['V4']}/history/{VALIDATORS['V4']}")
txs = data.get("transactions", [])
print(f"Total transactions: {len(txs)}")
running = 0
for i, t in enumerate(txs):
    ttype = t.get("type", "?")
    amt = t.get("amount", "0")
    frm = t.get("from", "?")
    to = t.get("to", "?")
    amt_f = float(amt) if amt else 0
    if ttype in ("genesis", "mint", "receive"):
        running += amt_f
    elif ttype == "send":
        running -= amt_f
    print(f"  [{i:2d}] {ttype:10s} amt={amt:>25s} from={frm[:12]:12s} to={to[:30]:30s} running~={running:.5f}")

print(f"\nExpected balance from V4's own history: {running:.11f} LOS")

# Also check V1/V3 histories for comparison
print("\n" + "=" * 70)
print("V1 HISTORY ON V1 ITSELF (healthy node)")
print("=" * 70)
data = fetch(f"{NODES['V1']}/history/{VALIDATORS['V1']}")
txs = data.get("transactions", [])
print(f"Total transactions: {len(txs)}")
running = 0
for i, t in enumerate(txs):
    ttype = t.get("type", "?")
    amt = t.get("amount", "0")
    frm = t.get("from", "?")
    to = t.get("to", "?")
    amt_f = float(amt) if amt else 0
    if ttype in ("genesis", "mint", "receive"):
        running += amt_f
    elif ttype == "send":
        running -= amt_f
    print(f"  [{i:2d}] {ttype:10s} amt={amt:>25s} from={frm[:12]:12s} to={to[:30]:30s} running~={running:.5f}")

print(f"\nExpected balance from V1's own history: {running:.11f} LOS")

print("\nDONE")
