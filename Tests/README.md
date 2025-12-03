# Klip Test Suite

Comprehensive integration tests for Klip protection flow.

## Quick Start

### Run All Tests

```bash
# Using Xcode
open Clipboard.xcodeproj
# Press Cmd + U

# Using xcodebuild
xcodebuild test -scheme Clipboard -destination 'platform=macOS'
```

### Run Specific Test

```bash
xcodebuild test -scheme Clipboard \
  -destination 'platform=macOS' \
  -only-testing:KlipFlowTests/testInstantAddressDetection
```

## Test Files

```
Tests/
├── KlipFlowTests.swift   # Main test suite (8 tests)
├── TEST_RESULTS.md                 # Detailed test results documentation
└── README.md                       # This file
```

## Test Coverage

### Critical Tests (Must Pass) ✅

1. **Instant Address Detection** - Verifies no analyzing animation
2. **Cmd+C → Protect Button Flow** - Verifies protection activation
3. **Complete Flow Integration** - End-to-end user flow
4. **Pattern Matching Accuracy** - Crypto address detection

### High Priority Tests ✅

5. **Copying Same Address** - Verifies duplicate detection ignored
6. **Clipboard Locked vs Protection Active** - Verifies correct messaging

### Medium Priority Tests ✅

7. **Protection Timer Text** - Verifies UI text correctness
8. **Auto-Dismiss Timeout** - Verifies 12-second timeout

## Test Scenarios

### Scenario 1: Normal Protection Flow

```
User copies Bitcoin address
  ↓
Widget appears: "Bitcoin Detected"
  ↓
User clicks "Protect"
  ↓
Timer shows: "Address Protection Active"
  ↓
Protection active for 2 minutes
```

**Expected:** ✅ All steps execute successfully

### Scenario 2: Same Address Copy

```
Protection active for Ethereum
  ↓
User copies same Ethereum address
  ↓
No widget appears (silently ignored)
```

**Expected:** ✅ No duplicate widget

### Scenario 3: Different Address Copy

```
Protection active for Bitcoin
  ↓
User copies different text
  ↓
Warning: "Protection Already Active"
  ↓
Clipboard reverts to protected address
```

**Expected:** ✅ Warning shown, content reverted

### Scenario 4: Timeout

```
User copies crypto address
  ↓
Widget appears with 12s countdown
  ↓
User doesn't click anything
  ↓
Widget auto-dismisses at 12 seconds
```

**Expected:** ✅ Auto-dismiss at 12.0s ±0.5s

## Manual Testing

### Prerequisites

- macOS 14.0+
- Xcode 15.0+
- Accessibility permissions granted
- Klip app installed

### Test Checklist

#### Basic Flow
- [ ] Copy Bitcoin address → Widget appears
- [ ] Click "Protect" → Timer shows
- [ ] Wait 2 minutes → Protection expires
- [ ] Copy Ethereum address → Widget appears
- [ ] Press Esc → Widget dismisses

#### Edge Cases
- [ ] Copy same address twice → No duplicate widget
- [ ] Copy during protection → Warning shown
- [ ] Let widget timeout → Auto-dismisses at 12s
- [ ] Copy non-crypto text → No widget
- [ ] Copy empty string → No widget

#### Option+Cmd+C (Instant Protection)
- [ ] Press Option+Cmd+C → Toast shows
- [ ] Timer appears automatically
- [ ] Protection active for 2 minutes

#### UI/UX
- [ ] Widget matches notch style
- [ ] Animations are smooth
- [ ] Text is readable
- [ ] Colors match design
- [ ] Gradient backgrounds correct

## Test Data

### Valid Crypto Addresses

```swift
// Bitcoin
let btcP2PKH = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
let btcP2SH = "3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy"
let btcBech32 = "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"

// Ethereum
let ethStandard = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC"
let ethChecksum = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"

// Solana
let solana = "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"
```

### Invalid Input

```swift
let invalid = [
    "random text",
    "0xINVALID",
    "1234567890",
    "",
    "almost_0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC"
]
```

## Debugging Tests

### Enable Verbose Logging

```swift
// In test file
override func setUp() {
    super.setUp()
    // Enable debug logging
    UserDefaults.standard.set(true, forKey: "DebugLoggingEnabled")
}
```

### View Console Output

```bash
# Run tests with verbose output
xcodebuild test -scheme Clipboard \
  -destination 'platform=macOS' \
  | grep "🧪"
```

### Common Issues

#### Tests Timing Out

- Check timeout values (should be 12s for auto-dismiss)
- Verify main thread operations
- Check for deadlocks in async code

#### Tests Failing Randomly

- Race conditions in async code
- Insufficient wait time in expectations
- Main thread synchronization issues

#### Pattern Matching Failures

- Verify regex patterns in `CryptoPatternMatcher`
- Check test address validity
- Ensure proper trimming/normalization

## Results

See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed test results and metrics.

**Latest Results:** ✅ 8/8 tests passing

## Contributing

When adding new tests:

1. Follow existing test structure
2. Add test to this README
3. Update TEST_RESULTS.md
4. Include console output examples
5. Document expected behavior

## License

Same as Klip main project.
