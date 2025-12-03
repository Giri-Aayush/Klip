#!/bin/bash

# Test script to verify confirmation widget button functionality
# This script monitors console logs while simulating user actions

echo "🧪 Starting Confirmation Button Test"
echo "===================================="

# Kill existing app
killall Clipboard 2>/dev/null
sleep 1

# Start app and capture logs
echo "📱 Starting app..."
open /Users/aayushgiri/Library/Developer/Xcode/DerivedData/Clipboard-hhexnolxxnhtekcgqpobxruuemjo/Build/Products/Debug/Clipboard.app

# Wait for app to initialize
echo "⏳ Waiting for app initialization (5s)..."
sleep 5

# Start log monitoring in background
LOG_FILE="/tmp/clipboard_test_$(date +%s).log"
log stream --predicate 'process == "Clipboard"' --level debug 2>&1 > "$LOG_FILE" &
LOG_PID=$!

echo "📝 Log monitoring started (PID: $LOG_PID)"
sleep 2

# Test 1: Copy Ethereum address
echo ""
echo "🧪 TEST 1: Copy Ethereum address"
echo "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC" | pbcopy
echo "   ✅ Address copied to clipboard"
sleep 2

# Check if crypto was detected
if grep -q "CRYPTO DETECTED: Ethereum" "$LOG_FILE"; then
    echo "   ✅ Crypto detection: PASS"
else
    echo "   ❌ Crypto detection: FAIL"
fi

# Check if confirmation widget shown
if grep -q "Showing confirmation widget" "$LOG_FILE"; then
    echo "   ✅ Confirmation widget shown: PASS"
else
    echo "   ❌ Confirmation widget shown: FAIL"
fi

# Wait for widget to appear
sleep 2

# Simulate ESC key press to test Skip functionality
echo ""
echo "🧪 TEST 2: Simulate ESC key (Skip)"
osascript -e 'tell application "System Events" to keystroke (ASCII character 27)' 2>/dev/null
sleep 1

# Check if Skip was triggered
if grep -q "Skip button ACTION triggered" "$LOG_FILE"; then
    echo "   ✅ Skip button triggered: PASS"
else
    echo "   ❌ Skip button triggered: FAIL"
    echo "   ⚠️  Button action not firing - hit testing blocked!"
fi

# Test 3: Try again with Space key (should trigger Protect)
echo ""
echo "🧪 TEST 3: Copy again and test Protect"
echo "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbC" | pbcopy
sleep 2

osascript -e 'tell application "System Events" to keystroke " "' 2>/dev/null
sleep 1

if grep -q "Protect button ACTION triggered" "$LOG_FILE"; then
    echo "   ✅ Protect button triggered: PASS"
else
    echo "   ❌ Protect button triggered: FAIL"
    echo "   ⚠️  Button action not firing - hit testing blocked!"
fi

# Kill log monitoring
kill $LOG_PID 2>/dev/null

echo ""
echo "📊 DETAILED LOG ANALYSIS"
echo "========================"

echo ""
echo "🔍 Button Action Triggers:"
grep "button ACTION triggered" "$LOG_FILE" | tail -5

echo ""
echo "🔍 Widget Show/Hide Events:"
grep -E "(Showing confirmation|Hiding confirmation|hideConfirmation)" "$LOG_FILE" | tail -10

echo ""
echo "🔍 Callback Execution:"
grep -E "(onConfirm|onDismiss) called" "$LOG_FILE" | tail -5

echo ""
echo "🔍 Auto-dismiss Events:"
grep "Confirmation timeout" "$LOG_FILE" | tail -3

echo ""
echo "📄 Full log saved to: $LOG_FILE"
echo ""
echo "🧪 Test Complete"
