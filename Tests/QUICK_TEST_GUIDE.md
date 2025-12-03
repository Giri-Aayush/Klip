# Quick Manual Test Guide

## ✅ All Automated Tests PASSED

Build successful. No compilation errors. No undefined variables. Consistent messaging.

---

## Quick Test Checklist (5 minutes)

### Test 1: Basic Flow ⏱️ 1 min
```
1. Copy this: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC
2. Widget should appear INSTANTLY (no analyzing)
3. Click [Protect]
4. Timer should show "Address Protection Active"
   Subtitle: "Ethereum address"
```

**✅ PASS if:** Widget instant, timer shows, no analyzing animation

---

### Test 2: Same Address ⏱️ 30 sec
```
1. While protection active from Test 1
2. Copy THE SAME address again
3. Should NOT show widget
```

**✅ PASS if:** No duplicate widget appears

---

### Test 3: Different Content ⏱️ 30 sec
```
1. While protection active
2. Copy different text (e.g., "hello world")
3. Should show warning
```

**✅ PASS if:** Warning says "Protection Already Active" (NOT "Clipboard is locked")

---

### Test 4: Auto-Dismiss ⏱️ 15 sec
```
1. Copy: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
2. DON'T click anything
3. Watch countdown bar
4. Count to ~12 seconds
```

**✅ PASS if:** Widget dismisses at 12 seconds (±1 sec)

---

### Test 5: Option+Cmd+C ⏱️ 30 sec
```
1. Copy: 7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK
2. But use Option+Cmd+C (not Cmd+C)
3. Should see green toast
4. Then timer appears automatically
```

**✅ PASS if:** Toast → Timer (no confirmation widget)

---

## Console Checks

Open Xcode console (Cmd+Shift+Y) and look for:

### ✅ Good Messages
```
✅ [Confirmation] User clicked 'Enable Protection'
✅ [Security] User confirmed protection
🛡️  [PROTECTION ACTIVE] User tried to copy something else
ℹ️  SAME ADDRESS - User copied the same protected address
```

### ❌ Bad Messages (Should NOT appear)
```
❌ "CLIPBOARD LOCKED"
❌ "Clipboard is locked"
❌ "No pending protection to confirm"
❌ "protectedAddressHash"
```

---

## What Changed (Summary)

### Before (Bugs) → After (Fixed)

1. **Compilation:** ❌ Failed → ✅ Succeeds
2. **Button clicks:** ❌ Timeout race → ✅ 12s synchronized
3. **Same address:** ❌ Duplicate widget → ✅ Silently ignored
4. **Warning text:** ❌ "Clipboard is locked" → ✅ "Protection Already Active"
5. **Console logs:** ❌ "CLIPBOARD LOCKED" → ✅ "PROTECTION ACTIVE"
6. **Analyzing:** ❌ 2-second delay → ✅ Instant detection

---

## Quick Smoke Test (30 seconds)

```bash
# Just copy these 3 addresses quickly:
0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC  # Ethereum
1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa        # Bitcoin
7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK # Solana

# Expected:
- 3 widgets appear
- All show INSTANTLY
- No analyzing animation
- Click protect on first one
- Others should show "Protection Already Active"
```

---

## If Something Breaks

### Widget doesn't appear?
- Check accessibility permissions
- Check console for errors

### Button doesn't work?
- Check console for "No pending protection to confirm"
- If you see that, timeout is still mismatched

### Wrong message shows?
- Check if it says "locked" anywhere
- Should say "Protection Already Active"

### App crashes?
- Check console for error
- File bug report with stack trace

---

## Test Addresses

```
Bitcoin:  1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
Ethereum: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC
Solana:   7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK
```

---

**Time Required:** 5-10 minutes
**Prepared By:** Claude Code
**Last Updated:** 2025-10-27
