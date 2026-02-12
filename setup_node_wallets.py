#!/usr/bin/env python3
"""
Pre-populate each validator node's wallet.json with the genesis wallet keypair.
This ensures node_address == wallet_address so consensus voting power works.
"""
import json, os

# Load genesis wallets
with open('testnet-genesis/testnet_wallets.json') as f:
    genesis = json.load(f)

# Get the 4 bootstrap validator wallets (indices 2,3,4,5)
bootstrap_wallets = genesis['wallets'][2:6]

for i, wallet in enumerate(bootstrap_wallets, 1):
    # Convert hex strings to byte arrays
    pk_hex = wallet['public_key']
    sk_hex = wallet['private_key']
    
    pk_bytes = list(bytes.fromhex(pk_hex))
    sk_bytes = list(bytes.fromhex(sk_hex))
    
    # Create KeyPair JSON (plaintext format that node can load)
    keypair = {
        "public_key": pk_bytes,
        "secret_key": sk_bytes
    }
    
    # Clean node data dir (fresh start) but keep dirs
    node_dir = f'node_data/validator-{i}'
    # Remove old ledger/db/log files but keep the directory
    for root, dirs, files in os.walk(node_dir):
        for f_name in files:
            fpath = os.path.join(root, f_name)
            os.remove(fpath)
    os.makedirs(os.path.join(node_dir, 'logs'), exist_ok=True)
    
    wallet_path = os.path.join(node_dir, 'wallet.json')
    with open(wallet_path, 'w') as f:
        json.dump(keypair, f)
    
    print(f"Validator-{i}: wallet={wallet['address']}, pk_len={len(pk_bytes)}, sk_len={len(sk_bytes)}")
    print(f"  Written to {wallet_path} ({os.path.getsize(wallet_path)} bytes)")

print("\nDone! All 4 wallet.json files created.")
print("Nodes will now start with genesis wallet identities.")
