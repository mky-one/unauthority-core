#!/usr/bin/env python3
"""Check fee distribution to validators"""
import json
import urllib.request

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
        return json.loads(urllib.request.urlopen(url, timeout=5).read())
    except Exception as e:
        return {"error": str(e)}

# Check reward-info
ri = fetch(f"{NODES['V1']}/reward-info")
epoch = ri.get("epoch", {})
pool = ri.get("pool", {})
print(f"Current epoch: {epoch.get('current_epoch')}")
print(f"Pool: distributed={pool.get('total_distributed_los')} LOS, remaining={pool.get('remaining_los')} LOS")

# Check all validator histories for FEE_REWARD entries
print("\n=== FEE_REWARD blocks across all validators ===")
total_fee_rewards = 0
for vname, vaddr in VALIDATORS.items():
    data = fetch(f"{NODES['V1']}/history/{vaddr}")
    txs = data.get("transactions", [])
    fee_txs = [t for t in txs if "FEE_REWARD" in t.get("to", "")]
    if fee_txs:
        for ft in fee_txs:
            amt = float(ft.get("amount", 0))
            total_fee_rewards += amt
            print(f"  {vname}: FEE_REWARD {ft.get('to')} = {ft.get('amount')} LOS")
    else:
        print(f"  {vname}: No FEE_REWARD blocks yet")

print(f"\nTotal fee rewards distributed: {total_fee_rewards:.11f} LOS")

# Check slashing status
slash = fetch(f"{NODES['V1']}/slashing")
ss = slash.get("safety_stats", {})
print(f"\nSlashing: events={ss.get('total_slash_events')}, banned={ss.get('banned_count')}")

# Cross-node balance check
print("\n=== CROSS-NODE BALANCE CHECK ===")
for vname, vaddr in VALIDATORS.items():
    bals = []
    for nname, nurl in NODES.items():
        data = fetch(f"{nurl}/balance/{vaddr}")
        if "error" not in data:
            bals.append((nname, data.get("balance_los"), data.get("block_count")))
    
    all_same = len(set(b[1] for b in bals)) == 1
    status = "CONSISTENT" if all_same else "DIVERGENT!"
    print(f"  {vname}: {bals[0][1]} LOS, blocks={bals[0][2]} [{status}]")

# Supply check
supply = fetch(f"{NODES['V1']}/supply")
print(f"\nSupply remaining: {supply.get('remaining_supply')} LOS")

# Metrics
print("\n=== METRICS ===")
try:
    metrics_raw = urllib.request.urlopen(f"{NODES['V1']}/metrics", timeout=5).read().decode()
    for line in metrics_raw.split('\n'):
        if line.startswith('los_') and not line.startswith('#'):
            print(f"  {line}")
except:
    print("  Failed to fetch metrics")

print("\nDONE")
