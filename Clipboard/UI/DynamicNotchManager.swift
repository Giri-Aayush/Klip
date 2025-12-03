//
//  DynamicNotchManager.swift
//  Clipboard
//
//  Created by Aayush Giri on 23/10/25.
//

import SwiftUI
import DynamicNotchKit

/// Manager for all Dynamic Island/Notch interactions
@MainActor
class DynamicNotchManager {

    // Unified notch for confirmation → timer flow (using DynamicNotchKit!)
    private var unifiedNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?
    private var unifiedViewModel: ProtectionWidgetViewModel?

    // Toast notifications use DynamicNotchKit
    private var toastNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?

    // MARK: - Unified Widget (Confirmation → Timer) with DynamicNotchKit

    /// Shows the unified widget in confirmation state
    func showConfirmation(address: String, type: CryptoType, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        print("🔐 [DynamicNotch] Showing unified widget in confirmation state with DynamicNotchKit")

        // Create view model in confirmation state
        let viewModel = ProtectionWidgetViewModel(
            state: .confirmation(address: address, type: type),
            onDismiss: onDismiss
        )
        unifiedViewModel = viewModel

        // Create unified widget view with id based on state for proper re-rendering
        let widgetView = UnifiedProtectionWidgetView(
            viewModel: viewModel,
            onConfirm: {
                print("🔘 [DynamicNotch] onConfirm called")
                HapticFeedback.shared.success()
                onConfirm()
            },
            onSkip: {
                print("⏭️  [DynamicNotch] onSkip called")
                HapticFeedback.shared.light()
                onDismiss()
            }
        )
        .id(UUID()) // Force SwiftUI to treat this as a new view

        // Create DynamicNotch with the unified widget
        unifiedNotch = DynamicNotch(
            hoverBehavior: [.keepVisible],
            style: .notch(topCornerRadius: 20, bottomCornerRadius: 25)
        ) {
            AnyView(widgetView)
        } compactLeading: {
            EmptyView()
        } compactTrailing: {
            EmptyView()
        }

        Task {
            await unifiedNotch?.expand()
            // Make window accept clicks
            unifiedNotch?.windowController?.window?.makeKey()
        }
    }

    /// Transitions from confirmation to timer (SYNCHRONOUS: hide → then show)
    func transitionToTimer(type: CryptoType, timeRemaining: TimeInterval) async {
        print("🔄 [DynamicNotch] Step 1: Hiding confirmation widget")

        // Step 1: Hide the confirmation widget and wait for it to complete
        let notchToHide = unifiedNotch
        unifiedNotch = nil
        unifiedViewModel = nil

        // CRITICAL: WAIT for hide to complete before showing timer
        await notchToHide?.hide()
        print("✅ [DynamicNotch] Step 2: Confirmation hidden, now showing timer")

        // Step 2: Now show the timer widget (this function won't return until widget is shown)
        await showTimerDirectly(type: type, timeRemaining: timeRemaining)
        print("✅ [DynamicNotch] Step 3: Timer widget fully shown - transition complete")
    }

    /// Shows timer directly (for instant protection without confirmation)
    func showTimerDirectly(type: CryptoType, timeRemaining: TimeInterval) async {
        print("🎯 [DynamicNotch] Showing timer widget directly with DynamicNotchKit")

        // Create view model in timer state
        let viewModel = ProtectionWidgetViewModel(
            state: .timer(type: type, timeRemaining: timeRemaining),
            onDismiss: {}
        )
        unifiedViewModel = viewModel

        // Create unified widget view (in timer state)
        let widgetView = UnifiedProtectionWidgetView(
            viewModel: viewModel,
            onConfirm: {}, // Not used in timer state
            onSkip: {}     // Not used in timer state
        )

        // Create DynamicNotch
        unifiedNotch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .notch(topCornerRadius: 20, bottomCornerRadius: 25)
        ) {
            AnyView(widgetView)
        } compactLeading: {
            EmptyView()
        } compactTrailing: {
            EmptyView()
        }

        // WAIT for expand to complete before returning
        await unifiedNotch?.expand()
        print("✅ [DynamicNotch] Timer widget expansion complete")
    }

    /// Updates the timer display
    func updateTimer(_ timeRemaining: TimeInterval) {
        unifiedViewModel?.updateTime(timeRemaining)
    }

    /// Check if there's an active widget (to prevent double-showing)
    func hasActiveWidget() -> Bool {
        return unifiedNotch != nil
    }

    /// Hides the unified widget
    func hideWidget() {
        print("🚪 [DynamicNotch] Hiding unified widget")

        // CRITICAL: Clear references IMMEDIATELY to prevent double-hide
        let notchToHide = unifiedNotch
        unifiedNotch = nil
        unifiedViewModel = nil

        Task {
            await notchToHide?.hide()
        }
    }

    // MARK: - Warnings

    /// Shows a warning message in the timer widget
    func showWarning(_ message: String) async {
        print("⚠️  [DynamicNotch] Showing warning: \(message)")
        HapticFeedback.shared.warning()
        unifiedViewModel?.showWarning(message)
    }

    /// Hides the protection timer
    func hideProtectionTimer() async {
        print("🚪 [DynamicNotch] Hiding protection timer")

        // CRITICAL: Clear references IMMEDIATELY to prevent double-hide
        let notchToHide = unifiedNotch
        unifiedNotch = nil
        unifiedViewModel = nil

        // FIX: Don't await - let hide run in background to prevent 15s blocking
        Task {
            await notchToHide?.hide()
            print("✅ [DynamicNotch] Hide animation completed in background")
        }
    }

    // MARK: - Toast Notifications

    /// Shows "Protection Enabled" toast
    func showProtectionEnabledToast(for type: CryptoType) async {
        print("✅ [DynamicNotch] Showing protection enabled toast")

        // Haptic feedback for protection enabled
        HapticFeedback.shared.success()

        let view = ProtectionEnabledToast(cryptoType: type)

        toastNotch = DynamicNotch(
            hoverBehavior: [],
            style: .notch(topCornerRadius: 20, bottomCornerRadius: 25)
        ) {
            AnyView(view)
        } compactLeading: {
            EmptyView()
        } compactTrailing: {
            EmptyView()
        }
        await toastNotch?.expand()

        // Auto-hide after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            await hideToast()
        }
    }

    /// Shows "Same Address Protected" toast
    func showSameAddressToast(for type: CryptoType) async {
        print("✅ [DynamicNotch] Showing same address toast")

        // Save current timer state before hiding
        let savedViewModel = unifiedViewModel
        let savedTimeRemaining: TimeInterval?
        if case .timer(_, let time) = savedViewModel?.state {
            savedTimeRemaining = time
        } else {
            savedTimeRemaining = nil
        }

        // Hide unified widget temporarily (timer will pause)
        if hasActiveWidget() {
            print("   💾 Saving timer state and hiding widget temporarily")
            let notchToHide = unifiedNotch
            unifiedNotch = nil
            unifiedViewModel = nil

            Task {
                await notchToHide?.hide()
            }
        }

        // Light haptic for "already protected" feedback
        HapticFeedback.shared.light()

        // Show toast
        let view = SameAddressToast(cryptoType: type)

        toastNotch = DynamicNotch(
            hoverBehavior: [],
            style: .notch(topCornerRadius: 20, bottomCornerRadius: 25)
        ) {
            AnyView(view)
        } compactLeading: {
            EmptyView()
        } compactTrailing: {
            EmptyView()
        }
        await toastNotch?.expand()

        // Auto-hide after 2 seconds and restore timer widget
        Task {
            try? await Task.sleep(for: .seconds(2))
            await hideToast()

            // Restore timer widget if we had saved state
            if let timeRemaining = savedTimeRemaining {
                print("   🔄 Restoring timer widget after toast")
                await restoreTimerWidget(type: type, timeRemaining: timeRemaining)
            }
        }
    }

    /// Restores the timer widget after showing same address toast
    private func restoreTimerWidget(type: CryptoType, timeRemaining: TimeInterval) async {
        print("🔄 [DynamicNotch] Restoring timer widget (time: \(Int(timeRemaining))s)")

        // Create view model in timer state with saved time
        let viewModel = ProtectionWidgetViewModel(
            state: .timer(type: type, timeRemaining: timeRemaining),
            onDismiss: {}
        )
        unifiedViewModel = viewModel

        // Create unified widget view (in timer state)
        let widgetView = UnifiedProtectionWidgetView(
            viewModel: viewModel,
            onConfirm: {}, // Not used in timer state
            onSkip: {}     // Not used in timer state
        )

        // Create DynamicNotch
        unifiedNotch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .notch(topCornerRadius: 20, bottomCornerRadius: 25)
        ) {
            AnyView(widgetView)
        } compactLeading: {
            EmptyView()
        } compactTrailing: {
            EmptyView()
        }

        await unifiedNotch?.expand()
        print("✅ [DynamicNotch] Timer widget restored")
    }

    /// Hides the toast
    func hideToast() async {
        await toastNotch?.hide()
        toastNotch = nil
    }
}
