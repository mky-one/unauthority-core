# 🧪 QUICK TEST GUIDE - Copy & Paste Ready

## 🚀 Setup (1 minute)

### Terminal 1: Wallet App
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core/frontend-wallet
npx vite --port 5173
```

### Terminal 2: Validator App  
```bash
cd /Users/moonkey-code/Documents/monkey-one/project/unauthority-core/frontend-validator
npx vite --port 5176
```

### Terminal 3: Check Validators Running
```bash
ps aux | grep "uat-node 30" | grep -v grep
```

**Should see 3 processes:**
```
uat-node 3030 ✅
uat-node 3031 ✅
uat-node 3032 ✅
```

---

## 📱 Test #1: Wallet Health Check (2 minutes)

**Open**: http://localhost:5173

1. Wait 3 seconds for load
2. Look for **"Node Online"** indicator → should be 🟢 GREEN
3. Check browser console (F12 → Console tab)
   - ✅ Should be clean (no red errors)
   - ❌ Should NOT see "404" or "Cannot connect"

**PASS Criteria**: Green indicator + no console errors

**Result**: ✅ PASS / ❌ FAIL

---

## 🪙 Test #2: Faucet Success (2 minutes)

**Still on**: http://localhost:5173

### Setup:
1. Click "Import Wallet" (or "New Wallet" if fresh)
2. Click "Restore from Seed" 
3. Paste this seed:
```
bulb key mother card recycle protect note boil balcony put ill figure walnut column sing acid favorite grape giraffe version hair wolf solve athlete
```
4. Click "Restore" or "Import"
5. Wait for address to appear

### Test Faucet:
1. Click "Faucet" or "Get Free UAT" button
2. Should see SUCCESS message like:
   ```
   ✅ Faucet claim successful
   Amount: 100,000 UAT
   ```
3. Balance should increase by 100,000

**PASS Criteria**: Success message appears, balance increases

**Result**: ✅ PASS / ❌ FAIL

---

## ⚠️ Test #3: Faucet Error Handling - CRITICAL BUG FIX ⚠️

**Still on**: http://localhost:5173

### This is the BUG FIX TEST - MUST PASS!

1. Click "Faucet" button AGAIN (immediately after first claim)
2. Should see **ERROR** message:
   ```
   ❌ Faucet claim already used or still in cooldown
   ```

**IMPORTANT**: 
- ❌ Should NOT say "Success"
- ✅ Should say "Error" or similar
- ✅ Balance should NOT increase

**Why This Matters**:
Backend returns HTTP 200 with `{"status": "error"}` in response body.
Old code only checked HTTP status → FALSE POSITIVE (said success when error).
NEW CODE checks `data.status` field → CORRECT!

**PASS Criteria**: Error message shows, NOT success

**Result**: ✅ PASS / ❌ FAIL ← **CRITICAL**

---

## 💸 Test #4: Send Transaction Success (3 minutes)

**Still on**: http://localhost:5173

### Setup - Get Wallet #2 Address:
```
UAT7df09d74dcce9228b723f1a3da462e409ecd70a6
```

### Test:
1. Click "Send" button
2. Fill form:
   - **To Address**: `UAT7df09d74dcce9228b723f1a3da462e409ecd70a6`
   - **Amount**: `100` (UAT)
   - **Fee**: (leave default)
3. Click "Send"
4. Should see SUCCESS:
   ```
   ✅ Transaction successful
   TX Hash: ...
   ```

**PASS Criteria**: Success message, balance decreases

**Result**: ✅ PASS / ❌ FAIL

---

## ⚠️ Test #5: Send Error Handling - CRITICAL BUG FIX ⚠️

**Still on**: http://localhost:5173

### This is the 2nd BUG FIX TEST - MUST PASS!

1. Click "Send" again
2. Fill form with IMPOSSIBLE amount:
   - **To**: `UAT7df09d74dcce9228b723f1a3da462e409ecd70a6`
   - **Amount**: `999,999,999` ← More than you have!
3. Click "Send"
4. Should see **ERROR**:
   ```
   ❌ Insufficient balance
   ```

**IMPORTANT**:
- ❌ Should NOT say "Success"
- ✅ Should say "Insufficient balance" or similar error
- ✅ No transaction should be created
- ✅ Balance should NOT decrease

**Why This Matters**:
Same bug as faucet - HTTP 200 with error body.
OLD CODE said "Success" (false positive).
NEW CODE checks `data.status` → CORRECT!

**PASS Criteria**: Error message shows, balance unchanged

**Result**: ✅ PASS / ❌ FAIL ← **CRITICAL**

---

## 💼 Test #6: Validator Dashboard (2 minutes)

**Open**: http://localhost:5176

1. Wait 3 seconds for load
2. Should see dashboard with metrics
3. Look for "Validators" section:
   - ✅ Should show 3 validators
   - ✅ Each with address, stake, status
4. No console errors (F12 → Console)

**PASS Criteria**: Dashboard loads, validators shown

**Result**: ✅ PASS / ❌ FAIL

---

## ⚠️ Test #7: Blocks Tab - CRITICAL BUG FIX ⚠️

**Still on**: http://localhost:5176

### This is the 3rd BUG FIX TEST - MUST PASS!

1. Click "Blocks" tab (or "Recent Blocks")
2. Should see table with recent blocks:
   ```
   Height    Hash              Transactions  Timestamp
   ────────────────────────────────────────────────
   123       abc123def...      2             2:30 PM
   122       def456ghi...      1             2:29 PM
   121       ghi789jkl...      3             2:28 PM
   ```

**IMPORTANT - This was the BUG**:
- ❌ BEFORE: Shows "404 Not Found"
- ✅ AFTER: Shows blocks (endpoint fixed: /blocks → /blocks/recent)

**PASS Criteria**: Blocks display (NOT 404), table visible

**Result**: ✅ PASS / ❌ FAIL ← **CRITICAL**

---

## 📋 Test #8: Blocks Auto-Refresh (1 minute)

**Still on**: http://localhost:5176 Blocks tab

1. Note the number of blocks shown
2. Wait 15 seconds (auto-refresh interval)
3. New blocks should appear at top
4. UI should be responsive (no freezing)

**PASS Criteria**: New blocks appear, no hanging

**Result**: ✅ PASS / ❌ FAIL

---

## 🎯 CRITICAL TESTS SUMMARY

**Must All Pass for Release:**

| Test | Purpose | Status |
|------|---------|--------|
| **Test #3** | Faucet error not treated as success | ✅ / ❌ |
| **Test #5** | Send error not treated as success | ✅ / ❌ |
| **Test #7** | Blocks display (endpoint fixed) | ✅ / ❌ |

---

## 📊 Final Results

```
Test #1 (Health Check):     ✅ / ❌
Test #2 (Faucet Success):   ✅ / ❌
Test #3 (Faucet Error):     ✅ / ❌  ⚠️  CRITICAL
Test #4 (Send Success):     ✅ / ❌
Test #5 (Send Error):       ✅ / ❌  ⚠️  CRITICAL
Test #6 (Dashboard):        ✅ / ❌
Test #7 (Blocks):           ✅ / ❌  ⚠️  CRITICAL
Test #8 (Auto-Refresh):     ✅ / ❌

CRITICAL TESTS:             __/3  ← MUST BE 3/3
TOTAL:                      __/8
```

---

## 🐛 Bug Fixes Summary

| Bug | Fix | Validated By |
|-----|-----|--------------|
| requestFaucet() false positive | Check `data.status === 'error'` | Test #3 |
| sendTransaction() false positive | Check `data.status === 'error'` | Test #5 |
| submitBurn() false positive | Check `data.status === 'error'` | Manual |
| /blocks endpoint 404 | Changed to `/blocks/recent` | Test #7 |

---

## 🔧 If Tests Fail

### Test #3 or #5 Fails (Still shows "Success"):
1. Check file: `frontend-wallet/src/utils/api.ts`
2. Look for `requestFaucet()` or `sendTransaction()`
3. Verify code has: `data.status === 'error'`
4. Hard refresh browser (Cmd+Shift+R on Mac)

### Test #7 Fails (Still shows 404):
1. Check file: `frontend-validator/src/utils/api.ts`
2. Look for `getRecentBlocks()`
3. Verify URL is `/blocks/recent` (not `/blocks`)
4. Hard refresh browser

### Any Test Shows Console Errors:
1. Open DevTools (F12)
2. Click "Network" tab
3. Repeat the failing action
4. Look at API responses:
   - Response Status should be `200 OK`
   - Response Body should have clear message
5. Check browser console for JavaScript errors

---

## ✅ Success Criteria

**Minimum (MUST HAVE)**:
- [ ] Tests #3, #5, #7 all PASS ← Critical bug fixes
- [ ] No console errors
- [ ] No network 404s (except expected)

**Full Success**:
- [ ] All 8 tests PASS
- [ ] Dashboard responsive
- [ ] Blocks auto-refresh works
- [ ] Balance updates correctly

---

**Quick Links**:
- Wallet: http://localhost:5173
- Validator: http://localhost:5176  
- Test Cases (Detailed): TEST_CASES.md
- Test Summary: TEST_SUMMARY.md

**Estimated Time**: 15-20 minutes for all tests  
**Critical Time**: 5 minutes for 3 critical tests

Let's go! 🚀
