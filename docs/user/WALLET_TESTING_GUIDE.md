# 🧪 UNAUTHORITY WALLET - TESTING CHECKLIST

## Phase 1: Welcome Screen (Existing Wallet)
- [ ] Logo appears (SVG or gradient fallback)
- [ ] Title "Unauthority Wallet" visible
- [ ] Subtitle "Burn BTC/ETH to mint UAT" visible
- [ ] 3 buttons visible:
  - [ ] "Create New Wallet"
  - [ ] "Import from Seed Phrase"
  - [ ] "Import from Private Key"
- [ ] Security warning message displays
- [ ] Dark theme applies correctly

---

## Phase 2: Create New Wallet
**Click: "Create New Wallet"**

- [ ] Page shows 12-word seed phrase
- [ ] Words displayed in numbered grid (1-12)
- [ ] "Copy to Clipboard" button works
- [ ] "Download Backup" button works (downloads .txt file)
- [ ] Backup confirmation checkbox visible
- [ ] "I saved my seed phrase" message shows until checkbox checked
- [ ] After checking: "Confirm & Create Wallet" button enables
- [ ] Click confirm → Redirected to Dashboard

---

## Phase 3: Dashboard
**After creating wallet:**

### Header Section
- [ ] "Unauthority Wallet" title visible
- [ ] "Burn BTC/ETH to Mint UAT" subtitle visible
- [ ] Node status indicator shows:
  - [ ] Green + "Node Online" (if node running)
  - [ ] Red + "Node Offline" (if node not running)
- [ ] Oracle prices display (if node online):
  - [ ] "ETH: $2,500" (example)
  - [ ] "BTC: $95,000" (example)

### Balance Card
- [ ] Large balance display (starting at 0 UAT)
- [ ] Blue-to-cyan gradient background
- [ ] Refresh button (circular icon)
- [ ] USD value display "≈ $0.00 USD" (1 UAT = $0.01)

### Wallet Info Cards
- [ ] **Wallet Address Card:**
  - [ ] Shows "UAT..." address
  - [ ] Copy button works (copies to clipboard)
  - [ ] After copying, shows ✓ checkmark momentarily

- [ ] **Public Key Card:**
  - [ ] Shows hex public key
  - [ ] Copy button functional

- [ ] **Private Key Card:**
  - [ ] Shows "Hide" button initially
  - [ ] Click "Hide" → Shows asterisks (••••••)
  - [ ] Click "Show" → Reveals full private key
  - [ ] Red border warning indicator
  - [ ] "Never share!" warning text displays
  - [ ] Copy button only appears when Show mode

### Network Stats (if node online)
- [ ] **Total Supply:** Shows "21.936M UAT"
- [ ] **Remaining Supply:** Shows number
- [ ] **Total Burned:** Shows "$0" initially

### Offline Warning (if node offline)
- [ ] Yellow/red warning box appears
- [ ] Message: "⚠️ Node offline - Start your Unauthority node"
- [ ] Shows command: `./target/release/uat-node 3030`

---

## Phase 4: Tab Navigation
**Click each tab and verify:**

### Dashboard Tab
- [ ] Tab highlights when active
- [ ] Content displays correctly

### Burn to Mint Tab
- [ ] Tab highlights
- [ ] Shows BTC and ETH tabs/buttons
- [ ] **BTC Section:**
  - [ ] QR code displays for burn address
  - [ ] Address: `1BitcoinEaterAddressDontSendf59kuE`
  - [ ] "Copy address" button works
  - [ ] TXID input field visible
  - [ ] "Submit Burn Transaction" button visible

- [ ] **ETH Section:**
  - [ ] QR code displays for burn address
  - [ ] Address: `0x000000000000000000000000000000000000dEaD`
  - [ ] Copy button works
  - [ ] TXID input visible
  - [ ] Submit button functional

- [ ] Bonding curve explanation visible
- [ ] "Example: 0.01 BTC = XXX UAT" shows estimate

### Send Tab
- [ ] Tab highlights
- [ ] **Form fields:**
  - [ ] "Recipient Address" input with placeholder
  - [ ] "Amount (UAT)" input field
  - [ ] "MAX" button (right side of amount)
  - [ ] Current balance display
  - [ ] "Available: 0.00000000 UAT" shows

- [ ] **Form validation:**
  - [ ] Click MAX → Amount field fills with balance
  - [ ] Invalid address format → Error message
  - [ ] Amount > balance → "Insufficient balance" error
  - [ ] Valid inputs → "Send Transaction" button enables

- [ ] **Send success/error:**
  - [ ] Success: Message shows "Successfully sent X UAT to UAT..."
  - [ ] Error: Shows error message (e.g., node offline)

### History Tab
- [ ] Tab highlights
- [ ] Empty state message: "No transactions yet"
- [ ] After transactions: Shows list with:
  - [ ] Transaction type (Send/Receive/Burn)
  - [ ] Amount with +/- indicator
  - [ ] Recipient/Sender address
  - [ ] Timestamp
  - [ ] Refresh button works

---

## Phase 5: Import Wallet

### Import from Seed Phrase
**Go back: Click logo/title to reset, then "Import from Seed Phrase"**

- [ ] 12-word input field visible
- [ ] Placeholder text shows example
- [ ] Paste seed from earlier backup
- [ ] Click "Import" → Wallet loads
- [ ] Verify same address as before

### Import from Private Key
**Go back, then "Import from Private Key"**

- [ ] Private key hex input visible
- [ ] Paste private key from Dashboard
- [ ] Click "Import" → Wallet loads
- [ ] Verify same address appears

---

## Phase 6: Real Node Connection Test

**In separate terminal, start node:**
```bash
./target/release/uat-node 3030
```

Then check wallet:
- [ ] Node status turns GREEN (from RED)
- [ ] Oracle prices appear in header
- [ ] Network stats populate:
  - [ ] Total Supply
  - [ ] Remaining Supply
  - [ ] Total Burned amount

---

## Phase 7: Edge Cases & Error Handling

- [ ] **Missing logo:** SVG logo displays (or fallback icon)
- [ ] **Very large balance:** Format with commas properly
- [ ] **Copy button:** Copies correct text to clipboard
- [ ] **Show/Hide private key:** Toggles correctly
- [ ] **Invalid seed phrase:** Shows error message
- [ ] **Invalid private key:** Shows error message
- [ ] **Network error:** Graceful error message, not crash
- [ ] **Resize window:** Layout responsive (mobile-friendly check)

---

## Phase 8: Performance & UX

- [ ] Page loads quickly (< 2s)
- [ ] No console errors (F12 → Console)
- [ ] Clicking buttons is responsive (no lag)
- [ ] Text copy animations work smooth
- [ ] Scrolling smooth on History tab
- [ ] Mobile view responsive (test with F12 device mode)

---

## Phase 9: Security Checks

- [ ] ✅ Private key **never** sent to server
- [ ] ✅ All data stored locally (browser storage)
- [ ] ✅ No sensitive data in logs
- [ ] ✅ Copy action uses secure clipboard API
- [ ] ✅ Seed phrase displayed once (on creation)
- [ ] ✅ Private key hidden by default
- [ ] ✅ Warning colors (red) on sensitive info

---

## Phase 10: Real Burn Test (Optional - Testnet Only)

**Prerequisites:** Node running + testnet BTC faucet

1. Get testnet BTC from: https://testnet.bitcoin.com/
2. Copy wallet address from Dashboard
3. In wallet Burn tab → BTC section
4. Send 0.001 BTC to burn address in QR code
5. Copy TXID from Bitcoin testnet explorer
6. Paste TXID in wallet Burn form
7. Click "Submit Burn Transaction"
8. Check:
   - [ ] Validators process burn (watch node logs)
   - [ ] Balance updates to show minted UAT
   - [ ] Transaction appears in History
   - [ ] Amount = X BTC × bonding curve rate

---

## Summary

**Pass Criteria:** All items in Phase 1-8 ✅  
**Bonus:** Phase 9-10 completed ✅

**Total: ___ / ___ tests passed**

---

## Bug Report Template (If Found)

```
**Title:** [Brief description]
**Steps to Reproduce:**
1. 
2. 
3. 

**Expected:** 
Actual:** 
**Screenshots:** [attach]
```
