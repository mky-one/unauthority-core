# UNAUTHORITY TESTNET - QUICK COMMAND REFERENCE

## 🚀 START NODE (SINGLE COMMAND)
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core && \
rm -rf uat_database && \
pkill -f 'uat-node' && \
nohup target/release/uat-node 3030 > /tmp/uat_node.log 2>&1 & \
echo "Node PID: $(pgrep -f 'uat-node')"
```

## 🧪 RUN ALL TESTS (AUTOMATED)
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core
./test_testnet.sh
```

## 🔥 BURN TEST COMMANDS
```bash
# Test BTC Burn
curl -X POST http://localhost:3030/burn -H "Content-Type: application/json" \
-d '{"coin_type":"btc","txid":"2096b844178ecc776e050be7886e618ee111e2a68fcf70b28928b82b5f97dcc9"}' | jq

# Test ETH Burn
curl -X POST http://localhost:3030/burn -H "Content-Type: application/json" \
-d '{"coin_type":"eth","txid":"0x459ccd6fe488b0f826aef198ad5625d0275f5de1b77b905f85d6e71460c1f1aa"}' | jq
```

## 📊 QUICK STATUS CHECK
```bash
# All endpoints in one command
curl -s http://localhost:3030/node-info | jq '.chain_id, .total_supply, .block_height'
curl -s http://localhost:3030/supply | jq '.remaining_supply'
curl -s http://localhost:3030/validators | jq '.validators | length'
```

## 📝 VIEW LOGS
```bash
# Real-time logs
tail -f /tmp/uat_node.log

# Last 30 lines
tail -30 /tmp/uat_node.log

# Filter oracle activity
tail -100 /tmp/uat_node.log | grep -i "oracle\|burn\|vote"
```

## 🛑 STOP NODE
```bash
pkill -9 -f 'uat-node'
```

## 🔄 RESTART NODE
```bash
pkill -f 'uat-node' && sleep 2 && \
rm -rf uat_database && \
nohup target/release/uat-node 3030 > /tmp/uat_node.log 2>&1 &
```
