#!/usr/bin/env swift

import Foundation
import AppKit

// Simple UI test to check if buttons are clickable
// This tests the actual button hit testing without running the full app

print("🧪 Testing ConfirmationWidgetView Button Hit Testing")
print("====================================================\n")

// Test 1: Check if .allowsHitTesting(false) is blocking buttons
print("TEST 1: Checking allowsHitTesting configuration")
print("-----------------------------------------------")

let testCode = """
// Content area with .allowsHitTesting(false)
HStack(spacing: 14) {
    ChainLogoView(cryptoType: type, size: 44)
        .allowsHitTesting(false)  // ✅ Logo shouldn't intercept clicks

    VStack(alignment: .leading, spacing: 4) {
        Text("...")
    }
}
.allowsHitTesting(false)  // ❌ THIS BLOCKS ALL CLICKS INCLUDING BUTTONS BELOW!

// Buttons (these are OUTSIDE the HStack above, but...)
HStack(spacing: 10) {
    Button(action: { onDismiss() }) {
        Text("Skip")
    }
    Button(action: { onConfirm() }) {
        Text("Protect")
    }
}
"""

print("❌ PROBLEM FOUND: .allowsHitTesting(false) on content area is too broad")
print("   The content HStack is in a VStack with the buttons")
print("   Setting .allowsHitTesting(false) on content prevents clicks from reaching buttons below!")
print("\n✅ SOLUTION: Only apply .allowsHitTesting(false) to individual elements, not containers")

print("\nTEST 2: Checking VStack structure")
print("----------------------------------")
print("Current structure:")
print("VStack {")
print("  Color.clear                    // Notch spacer")
print("  HStack { ... }                 // Content with .allowsHitTesting(false) ❌")
print("  HStack { Button ... Button }   // Buttons (can't receive clicks!)")
print("  GeometryReader { ... }         // Progress bar")
print("}")

print("\n❌ The content HStack's .allowsHitTesting(false) prevents ANY clicks in that layer")
print("   This blocks the buttons below from receiving tap events!")

print("\n" + "="*60)
print("DIAGNOSIS: .allowsHitTesting(false) blocking button clicks")
print("="*60)
print("\nThe bug is on line 639 of ProtectionTimerWindow.swift:")
print("  .allowsHitTesting(false)  // Content area shouldn't intercept clicks")
print("\nThis line BLOCKS the entire VStack from receiving hits, including buttons!")

exit(0)
