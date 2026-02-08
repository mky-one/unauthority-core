# 🧪 Unauthority Frontend Test Cases - Complete

**Date**: February 6, 2026  
**Apps Running**:
- Wallet: http://localhost:5173
- Validator: http://localhost:5176
- API: http://localhost:3030 (local dev)

---

## 📋 Test Wallets (Dev Only)

### Wallet #1 (Primary)
```
Address: UATe3f60907b490600ad76aa75ef7b1bdac43e77887
Seed: bulb key mother card recycle protect note boil balcony put ill figure walnut column sing acid favorite grape giraffe version hair wolf solve athlete
Initial: 191,942 UAT
```

### Wallet #2 (Secondary)
```
Address: UAT7df09d74dcce9228b723f1a3da462e409ecd70a6
Seed: guess fetch juice knee dust hospital enroll daughter voyage business able evidence nothing peace arrow dance area hood ribbon thank enrich tube sponsor unique
Initial: 191,942 UAT
```

### Wallet #3 (Tertiary)
```
Address: UATc9489029764f912bab2309ef28a15771df3eec25
Seed: option child again tongue drum laptop diet wrestle joy wall donkey wagon physical quit assist help vintage innocent bleak beauty jump bitter safe emerge
Initial: 191,942 UAT
```

---

## 🧪 TEST SUITE 1: WALLET APP (localhost:5173)

### Test 1.1: Health Check & Connection
**Purpose**: Verify wallet can connect to backend
**Steps**:
1. Open http://localhost:5173 in browser
2. Check console for errors
3. Wait 3 seconds for initial load
4. **Expected**: Green "Node Online" indicator, no errors

**Acceptance**:
- ✅ App loads without 404s
- ✅ "Node Online" shows green
- ✅ Console clear of errors
- ✅ Shows current block height > 0

---

### Test 1.2: Import Wallet - Valid Seed
**Purpose**: Test BIP39 seed import
**Steps**:
1. Click "Import Wallet" or "Restore"
2. Paste Wallet #1 seed
3. Click "Import" or "Restore"
4. Wait for key generation

**Expected**:
- ✅ Derives correct address: `UATe3f60907b490600ad76aa75ef7b1bdac43e77887`
- ✅ No errors in console
- ✅ Wallet shows up in UI

**Status**: _____

---

### Test 1.3: Import Wallet - Invalid Seed
**Purpose**: Test error handling for invalid seed
**Steps**:
1. Click "Import Wallet"
2. Paste invalid seed: `invalid word list that wont work`
3. Click "Import"

**Expected Error Message**:
- ✅ Shows error (cannot be empty or invalid)
- ✅ App doesn't crash
- ✅ Console has clear error

**Status**: _____

---

### Test 1.4: Check Balance - Valid Address
**Purpose**: Verify getBalance() API works
**Steps**:
1. Import Wallet #1
2. Wait 2 seconds for balance to load
3. Check balance display

**Expected**:
- ✅ Shows balance in UAT
- ✅ No 404 errors
- ✅ Balance > 0

**API Call**: `GET /balance/UATe3f60907b490600ad76aa75ef7b1bdac43e77887`  
**Backend Response**: `{"status": "success", "balance": 191942, "balance_uat": 191942}`

**Status**: _____

---

### Test 1.5: Faucet Claim - First Time
**Purpose**: Test requestFaucet() with success case
**Steps**:
1. Import Wallet #1
2. Click "Faucet" or "Claim Free UAT"
3. Wait for response

**Expected**:
- ✅ Success message displays
- ✅ Balance increases by 100,000 UAT
- ✅ No false positives (actual success)

**API Call**: `POST /faucet`  
**Backend Response**: `{"status": "success", "msg": "Faucet claim successful", "amount": 100000}`  
**Frontend Check**: `data.status === 'error'` ✅ FIXED

**Status**: _____

---

### Test 1.6: Faucet Claim - Recent Claim Error
**Purpose**: Test error handling when faucet called recently (cooldown)
**Steps**:
1. Click Faucet again immediately (within 1 hour)
2. Wait for response

**Expected Error**:
- ✅ Shows error message (cooldown, already claimed, etc)
- ❌ NOT treated as success (this was the bug!)
- ✅ Balance doesn't change

**API Call**: `POST /faucet`  
**Backend Response**: `{"status": "error", "msg": "Faucet claim already used. Try again in ..."}` (HTTP 200)  
**Frontend Check**: `data.status === 'error'` ✅ NOW WORKING

**Status**: _____

---

### Test 1.7: Send Transaction - Valid
**Purpose**: Test sendTransaction() success case
**Steps**:
1. Import Wallet #1 (sender)
2. Click "Send"
3. Fill:
   - To: `UAT7df09d74dcce9228b723f1a3da462e409ecd70a6` (Wallet #2)
   - Amount: `100` UAT
4. Click "Send"

**Expected**:
- ✅ Success message
- ✅ TX hash displayed
- ✅ Sender balance decreases by 100
- ✅ No false positives

**API Call**: `POST /send`  
**Backend Response**: `{"status": "success", "tx_hash": "...", "msg": "Transaction successful"}`

**Status**: _____

---

### Test 1.8: Send Transaction - Insufficient Balance
**Purpose**: Test error handling when balance too low
**Steps**:
1. Import Wallet #2 (less balance)
2. Click "Send"
3. Fill:
   - To: Wallet #1
   - Amount: `999,999,999` UAT (way more than available)
4. Click "Send"

**Expected Error**:
- ✅ Shows "Insufficient balance" error
- ❌ NOT treated as success
- ✅ No transaction created
- ✅ Balance unchanged

**API Call**: `POST /send`  
**Backend Response**: `{"status": "error", "msg": "Insufficient balance"}` (HTTP 200)  
**Frontend Check**: `data.status === 'error'` ✅ NOW WORKING

**Status**: _____

---

### Test 1.9: Send Transaction - Invalid Address
**Purpose**: Test error handling for bad recipient
**Steps**:
1. Import Wallet #1
2. Click "Send"
3. Fill:
   - To: `NOTAVALIDADDRESS`
   - Amount: `10`
4. Click "Send"

**Expected Error**:
- ✅ Shows validation error
- ✅ Request blocked by frontend OR
- ✅ Backend returns error properly

**Status**: _____

---

### Test 1.10: Transaction History
**Purpose**: Test getHistory() API
**Steps**:
1. Import Wallet #1
2. Scroll to "Transaction History" section
3. Wait 2 seconds

**Expected**:
- ✅ Shows list of past transactions
- ✅ Shows faucet claims, sends, receives
- ✅ No 404 errors

**API Call**: `GET /history/UATe3f60907b490600ad76aa75ef7b1bdac43e77887`

**Status**: _____

---

## 🧪 TEST SUITE 2: VALIDATOR APP (localhost:5176)

### Test 2.1: Dashboard Load
**Purpose**: Verify validator dashboard initializes
**Steps**:
1. Open http://localhost:5176
2. Wait 3 seconds

**Expected**:
- ✅ Shows dashboard with metrics
- ✅ Node status displays
- ✅ No console errors

**API Calls**:
- `GET /health`
- `GET /node-info`
- `GET /validators`

**Status**: _____

---

### Test 2.2: Validators List
**Purpose**: Test getValidators() API
**Steps**:
1. Look at "Validators" section
2. Wait 2 seconds

**Expected**:
- ✅ Shows 3 validators (or active ones)
- ✅ Shows address, stake, status
- ✅ No 404 errors

**API Call**: `GET /validators`

**Status**: _____

---

### Test 2.3: Recent Blocks - NOW FIXED
**Purpose**: Test getRecentBlocks() with fixed endpoint
**Steps**:
1. Click "Blocks" tab
2. Wait 2 seconds

**Expected**:
- ✅ Shows recent blocks (was 404 before fix!)
- ✅ Shows block hash, height, timestamp
- ✅ No 404 in console

**API Call**: `GET /blocks/recent` (was `/blocks` - FIXED!)

**Status**: _____

---

### Test 2.4: Block Auto-Refresh
**Purpose**: Test that blocks update every 15 seconds
**Steps**:
1. Go to Blocks tab
2. Note the block count
3. Wait 15 seconds
4. Check if new blocks appear

**Expected**:
- ✅ New blocks added to list
- ✅ Auto-refresh works without stalling UI
- ✅ No error messages

**Status**: _____

---

### Test 2.5: Network Settings
**Purpose**: Test endpoint configuration
**Steps**:
1. Click "Settings" 
2. Check current API URL
3. Try to change to custom URL
4. Test connection

**Expected**:
- ✅ Shows current endpoint (localhost:3030 or .onion)
- ✅ Can change URL
- ✅ "Test Connection" shows proper status

**API Call**: `GET /health` to test endpoint

**Status**: _____

---

### Test 2.6: Send Transaction from Validator
**Purpose**: Test sendTransaction() in validator context
**Steps**:
1. Click "Send" button
2. Fill wallet details
3. Send transaction

**Expected**:
- ✅ Same behavior as wallet
- ✅ Error handling works
- ✅ Balance updates

**Status**: _____

---

### Test 2.7: Node Info Display
**Purpose**: Test getNodeInfo() API
**Steps**:
1. Look at node info section
2. Check displayed data

**Expected**:
- ✅ Shows chain_id: "uat-mainnet"
- ✅ Shows block_height
- ✅ Shows validator_count
- ✅ Shows version

**API Call**: `GET /node-info`

**Status**: _____

---

## 🐛 CRITICAL BUG FIX VALIDATION

### Bug #1: requestFaucet() Response Handling - FIXED ✅
**Issue**: Backend returns HTTP 200 with `{"status": "error"}` but frontend only checked `response.ok`
```javascript
// BEFORE (WRONG):
if (!response.ok) return error;
return success; // FALSE POSITIVE!

// AFTER (CORRECT):
if (!response.ok || data.status === 'error') return error;
return success;
```

**Test Case**: Test 1.6 - Faucet Claim Error  
**Validation**: Error shows properly without false success

**Status**: _____

---

### Bug #2: sendTransaction() Response Handling - FIXED ✅
**Issue**: Same as faucet - HTTP 200 with `{"status": "error"}`

**Test Case**: Test 1.8 - Send with Insufficient Balance  
**Validation**: Error displays, balance doesn't change

**Status**: _____

---

### Bug #3: submitBurn() Response Handling - FIXED ✅
**Issue**: Proof-of-burn API returns HTTP 200 with status field

**Test Case**: Manual - attempt burn with invalid txid  
**Validation**: Shows proper error message

**Status**: _____

---

### Bug #4: /blocks Endpoint Mismatch - FIXED ✅
**Issue**: Frontend called `/blocks` but backend only has `/blocks/recent`

**Test Case**: Test 2.3 - Recent Blocks  
**Validation**: Blocks display (was 404 before)

**Status**: _____

---

## 📊 Test Results Summary

### Wallet App (5173)
- Test 1.1: _____ / ✅
- Test 1.2: _____ / ✅
- Test 1.3: _____ / ✅
- Test 1.4: _____ / ✅
- Test 1.5: _____ / ✅ (Faucet Success)
- Test 1.6: _____ / ✅ (Faucet Error - BUG FIX)
- Test 1.7: _____ / ✅ (Send Success)
- Test 1.8: _____ / ✅ (Send Error - BUG FIX)
- Test 1.9: _____ / ✅
- Test 1.10: _____ / ✅

### Validator App (5176)
- Test 2.1: _____ / ✅
- Test 2.2: _____ / ✅
- Test 2.3: _____ / ✅ (Blocks - BUG FIX)
- Test 2.4: _____ / ✅
- Test 2.5: _____ / ✅
- Test 2.6: _____ / ✅
- Test 2.7: _____ / ✅

### Bug Fixes
- Bug #1 (Faucet): _____ / ✅
- Bug #2 (Send): _____ / ✅
- Bug #3 (Burn): _____ / ✅
- Bug #4 (Blocks): _____ / ✅

---

## 🔍 Console Debugging

### Check Network Requests
**In Browser DevTools (F12)**:
```javascript
// See all API calls
// Network tab → filter by xhr
// Look for:
// - /health → 200 OK
// - /balance/* → 200 OK
// - /faucet → 200 OK (check response.status field!)
// - /send → 200 OK (check response.status field!)
// - /blocks/recent → 200 OK (was 404, now fixed)
```

### Check Console Errors
```javascript
// Should see:
// ✅ No 404 errors
// ✅ No "Cannot read property" errors
// ✅ Clear error messages from frontend

// Should NOT see:
// ❌ "/blocks 404 Not Found"
// ❌ "data.blocks is undefined"
// ❌ "Failed to fetch" (if backend running)
```

---

## 📝 How to Run Tests

### Quick Checklist
```bash
# 1. Check validators running
ps aux | grep uat-node | grep -v grep

# 2. Start wallet (Terminal 1)
cd frontend-wallet && npx vite --port 5173

# 3. Start validator (Terminal 2)
cd frontend-validator && npx vite --port 5176

# 4. Open in browser
open http://localhost:5173  # Wallet
open http://localhost:5176  # Validator

# 5. Run through test cases above
```

---

## ✅ Success Criteria

**Minimum Passing** (must all pass):
- [ ] Test 1.1 - Connection works
- [ ] Test 1.4 - Balance reads correctly
- [ ] Test 1.5 - Faucet success message shows
- [ ] Test 1.6 - Faucet error shows (BUG FIX!)
- [ ] Test 1.8 - Send error shows (BUG FIX!)
- [ ] Test 2.3 - Blocks display (BUG FIX!)

**Full Passing** (all tests):
- [ ] All 10 wallet tests pass
- [ ] All 7 validator tests pass
- [ ] All 4 bug fixes validated

---

**Created**: Feb 6, 2026  
**Framework**: React + TypeScript + Electron  
**API**: UAT REST (13 endpoints)  
**Fixes**: 4 critical bugs patched ✅
