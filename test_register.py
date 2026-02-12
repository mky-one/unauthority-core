#!/usr/bin/env python3
"""Test validator registration with Dilithium5 signing"""
import json
import urllib.request
import time
import subprocess
import sys

# Read Dev2's wallet info from testnet_wallets.json to get public key
with open("testnet-genesis/testnet_wallets.json") as f:
    wallets_data = json.load(f)
    wallets = wallets_data["wallets"]

# Dev2 is index 1 (Dev1=0, Dev2=1)
dev2 = wallets[1]
dev2_addr = dev2["address"]
dev2_pk_hex = dev2["public_key"]
dev2_sk_hex = dev2["private_key"]

print(f"Dev2 address: {dev2_addr}")
print(f"Dev2 PK length: {len(dev2_pk_hex)//2} bytes")
print(f"Dev2 SK length: {len(dev2_sk_hex)//2} bytes")

# Get current balance
req = urllib.request.urlopen(f"http://localhost:3030/balance/{dev2_addr}", timeout=5)
bal_data = json.loads(req.read())
print(f"Dev2 balance: {bal_data['balance_los']} LOS")

# The registration requires a signature of "REGISTER_VALIDATOR:<address>:<timestamp>"
# We need to sign with Dilithium5. Since we can't do that easily in Python,
# let's instead test what happens when we send the correct address and pk
# but wrong signature (should fail with "Signature verification failed")

timestamp = int(time.time())
print(f"\nTimestamp: {timestamp}")

# Test 1: Invalid signature (correct address + pk, wrong sig)
print("\n=== TEST 1: Wrong signature ===")
fake_sig = "00" * 100  # Obviously wrong signature
payload = json.dumps({
    "address": dev2_addr,
    "public_key": dev2_pk_hex,
    "signature": fake_sig,
    "timestamp": timestamp
}).encode()

req = urllib.request.Request(
    "http://localhost:3030/register-validator",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
print(f"  Result: {resp}")
assert resp["status"] == "error", "Should fail with wrong sig"
assert "Signature" in resp["msg"] or "signature" in resp["msg"].lower(), f"Expected sig error, got: {resp['msg']}"
print("  PASS: Correctly rejected invalid signature")

# Test 2: Mismatched public key
print("\n=== TEST 2: Wrong public key ===")
wrong_pk = "00" * 2592  # Wrong key, correct length
payload = json.dumps({
    "address": dev2_addr,
    "public_key": wrong_pk,
    "signature": fake_sig,
    "timestamp": timestamp
}).encode()

req = urllib.request.Request(
    "http://localhost:3030/register-validator",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
print(f"  Result: {resp}")
assert resp["status"] == "error", "Should fail with wrong pk"
print(f"  PASS: Correctly rejected ({resp['msg']})")

# Test 3: Stale timestamp  
print("\n=== TEST 3: Stale timestamp ===")
payload = json.dumps({
    "address": dev2_addr,
    "public_key": dev2_pk_hex,
    "signature": fake_sig,
    "timestamp": 1000  # Very old timestamp
}).encode()

req = urllib.request.Request(
    "http://localhost:3030/register-validator",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
print(f"  Result: {resp}")
assert resp["status"] == "error", "Should fail with old timestamp"
print(f"  PASS: Correctly rejected ({resp['msg']})")

# Test 4: Invalid address format
print("\n=== TEST 4: Invalid address ===")
payload = json.dumps({
    "address": "INVALID_ADDRESS",
    "public_key": dev2_pk_hex,
    "signature": fake_sig,
    "timestamp": timestamp
}).encode()

req = urllib.request.Request(
    "http://localhost:3030/register-validator",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
print(f"  Result: {resp}")
assert resp["status"] == "error", "Should fail with invalid address"
print(f"  PASS: Correctly rejected ({resp['msg']})")

# Test 5: V1 (already registered genesis validator) with correct pk
# This should say "already registered" AFTER passing all checks
print("\n=== TEST 5: Already registered validator ===")
v1_wallet = wallets[2]  # V1 is index 2 in testnet_wallets (after Dev1, Dev2)
print(f"  V1 address: {v1_wallet['address']}")

# Since V1 is in bootstrap_validators, it will return "Already registered"
# even before crypto check... but actually the check order matters
payload = json.dumps({
    "address": v1_wallet["address"],
    "public_key": v1_wallet["public_key"],
    "signature": fake_sig,  # Still wrong sig, but bootstrap check is before sig check? Let's see
    "timestamp": timestamp
}).encode()

req = urllib.request.Request(
    "http://localhost:3030/register-validator",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
print(f"  Result: {resp}")
# The sig check happens before the "already registered" check, so this will fail on sig
print(f"  Response status: {resp['status']}, msg: {resp['msg']}")

print("\n=== ALL REGISTER-VALIDATOR TESTS COMPLETE ===")
