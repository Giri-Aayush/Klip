//
//  ProtectionTimerWindow.swift
//  Clipboard
//
//  Created by Aayush Giri on 19/10/25.
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit

/// Widget state for unified protection widget
enum ProtectionWidgetState: Equatable {
    case confirmation(address: String, type: CryptoType)
    case timer(type: CryptoType, timeRemaining: TimeInterval)

    static func == (lhs: ProtectionWidgetState, rhs: ProtectionWidgetState) -> Bool {
        switch (lhs, rhs) {
        case (.confirmation(let addr1, let type1), .confirmation(let addr2, let type2)):
            return addr1 == addr2 && type1 == type2
        case (.timer(let type1, let time1), .timer(let type2, let time2)):
            return type1 == type2 && abs(time1 - time2) < 0.1  // Compare times with tolerance
        default:
            return false
        }
    }
}

/// View model for the unified protection widget
class ProtectionWidgetViewModel: ObservableObject {
    @Published var state: ProtectionWidgetState
    @Published var warningMessage: String?
    @Published var showWarning: Bool = false
    var onDismiss: (() -> Void)?

    init(state: ProtectionWidgetState, onDismiss: @escaping () -> Void) {
        self.state = state
        self.onDismiss = onDismiss
    }

    // Transition from confirmation to timer state
    func transitionToTimer(type: CryptoType, timeRemaining: TimeInterval) {
        withAnimation(.smooth(duration: 0.4)) {
            self.state = .timer(type: type, timeRemaining: timeRemaining)
        }
    }

    // Update time for timer state
    func updateTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if case .timer(let type, let oldTime) = self.state {
                // Manually trigger objectWillChange before updating
                self.objectWillChange.send()
                self.state = .timer(type: type, timeRemaining: time)

                // Only log every second to avoid spam
                if Int(oldTime) != Int(time) {
                    print("⏱️  [ViewModel] Timer updated: \(Int(time))s → UI should refresh")
                }
            }
        }
    }

    func showWarning(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.warningMessage = message
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showWarning = true
            }

            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.hideWarning()
            }
        }
    }

    func hideWarning() {
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self?.showWarning = false
            }
            // Notify window to collapse
            self?.onWarningDismissed?()
        }
    }

    var onWarningDismissed: (() -> Void)?
}

/// Notchnook-style protection timer window - seamlessly integrated with MacBook notch
class ProtectionTimerWindow: NSWindow {

    private var hostingView: NSView?
    private var viewModel: ProtectionWidgetViewModel?

    // Callbacks for button actions
    private var onConfirmCallback: (() -> Void)?
    private var onSkipCallback: (() -> Void)?
    private var userResponded: Bool = false  // Prevent auto-dismiss race condition

    // Notchnook-style dimensions
    private let notchHeight: CGFloat = 32  // Actual MacBook notch height
    private let timerExpandedHeight: CGFloat = 70  // Minimal compact timer height
    private let timerExpandedHeightWithWarning: CGFloat = 70  // Same height when expanded
    private let confirmationExpandedHeight: CGFloat = 190  // Confirmation widget height (compact modern design)
    private let timerWidgetWidth: CGFloat = 100  // Ultra-compact shield design
    private let timerWidgetWidthExpanded: CGFloat = 280  // Expanded with warning
    private let confirmationWidgetWidth: CGFloat = 320  // Narrower for minimal design

    // CRITICAL: Override to prevent window from becoming key (prevents focus and desktop switching)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        // Get screen bounds
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        // CRITICAL: Window must extend INTO notch area
        // Start with window ABOVE visible screen, extending into notch
        let windowRect = NSRect(
            x: (screenFrame.width - confirmationWidgetWidth) / 2,  // Center horizontally
            y: screenFrame.maxY - notchHeight,         // Top edge extends into notch
            width: confirmationWidgetWidth,
            height: notchHeight  // Start collapsed (only notch visible)
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar + 1  // Above menu bar to access notch area
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false  // No shadow initially
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // CRITICAL: Prevent this window from activating the app and switching desktops
        self.hidesOnDeactivate = false
        self.styleMask.insert(.nonactivatingPanel)

        // Start invisible
        self.alphaValue = 0
    }

    /// Shows unified widget in confirmation state
    /// Auto-dismisses after 6 seconds if no action taken
    func showConfirmation(address: String, type: CryptoType, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        print("🔐 [UnifiedWidget] Showing confirmation state (6s timeout)")

        // Store callbacks
        self.onConfirmCallback = onConfirm
        self.onSkipCallback = onDismiss
        self.userResponded = false

        // Create view model in confirmation state
        viewModel = ProtectionWidgetViewModel(
            state: .confirmation(address: address, type: type),
            onDismiss: onDismiss
        )

        // Create unified widget view
        let widgetView = UnifiedProtectionWidgetView(
            viewModel: viewModel!,
            onConfirm: { [weak self] in
                self?.handleProtectButton()
            },
            onSkip: { [weak self] in
                self?.handleSkipButton()
            }
        )

        let hosting = NSHostingView(rootView: widgetView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.isOpaque = false
        hostingView = hosting
        self.contentView = hostingView
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = .clear

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let centerX = (screenFrame.width - confirmationWidgetWidth) / 2

        // Start collapsed in notch
        let startY = screenFrame.maxY - notchHeight
        self.setFrame(NSRect(x: centerX, y: startY, width: confirmationWidgetWidth, height: notchHeight), display: true)

        self.orderFrontRegardless()
        self.alphaValue = 1.0

        // Animate expansion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                let finalY = screenFrame.maxY - (self.notchHeight + self.confirmationExpandedHeight)
                let finalFrame = NSRect(
                    x: centerX,
                    y: finalY,
                    width: self.confirmationWidgetWidth,
                    height: self.notchHeight + self.confirmationExpandedHeight
                )

                self.animator().setFrame(finalFrame, display: true)
                self.hasShadow = true
            }
        }

        // Auto-dismiss after 6 seconds ONLY if user didn't respond
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            guard let self = self, self.isVisible, !self.userResponded else { return }
            print("⏱️  [UnifiedWidget] 6s timeout - auto-dismissing")
            self.handleSkipButton()
        }
    }

    /// Handle Protect button - transitions to timer state
    private func handleProtectButton() {
        guard !userResponded else {
            print("   ⚠️  [UnifiedWidget] Already responded, ignoring")
            return
        }
        userResponded = true
        print("✅ [UnifiedWidget] Protect button clicked - calling callback")
        HapticFeedback.shared.success()
        onConfirmCallback?()
    }

    /// Handle Skip button - dismisses widget
    private func handleSkipButton() {
        guard !userResponded else {
            print("   ⚠️  [UnifiedWidget] Already responded, ignoring")
            return
        }
        userResponded = true
        print("⏭️  [UnifiedWidget] Skip button clicked - dismissing")
        HapticFeedback.shared.light()
        onSkipCallback?()
        hideWidget()
    }

    /// Transitions widget from confirmation state to timer state (in-place morph)
    func transitionToTimer(type: CryptoType, timeRemaining: TimeInterval) {
        print("🔄 [UnifiedWidget] Transitioning to timer state (in-place)")

        guard let vm = viewModel else {
            print("   ⚠️  No viewModel - cannot transition")
            return
        }

        // Transition the view model state - SwiftUI will animate the content change
        vm.transitionToTimer(type: type, timeRemaining: timeRemaining)

        // Optionally resize window to fit timer layout (smaller/narrower)
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Animate to timer size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true

                let centerX = (screenFrame.width - self.timerWidgetWidth) / 2
                let finalY = screenFrame.maxY - (self.notchHeight + self.timerExpandedHeight)
                let timerFrame = NSRect(
                    x: centerX,
                    y: finalY,
                    width: self.timerWidgetWidth,
                    height: self.notchHeight + self.timerExpandedHeight
                )

                self.animator().setFrame(timerFrame, display: true)
            }
        }

        print("✅ [UnifiedWidget] Transition to timer complete")
    }

    /// Hides the widget completely
    private func hideWidget() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true

            // Collapse back into notch
            let currentWidth = self.frame.width
            let centerX = (screenFrame.width - currentWidth) / 2
            let collapsedY = screenFrame.maxY - notchHeight
            let collapsedFrame = NSRect(
                x: centerX,
                y: collapsedY,
                width: currentWidth,
                height: notchHeight
            )

            self.animator().setFrame(collapsedFrame, display: true)
            self.animator().alphaValue = 0
            self.hasShadow = false
        } completionHandler: {
            self.orderOut(nil)
            self.viewModel = nil
        }
    }

    /// Legacy method for compatibility
    @available(*, deprecated, message: "Use hideWidget() instead")
    private func hideConfirmation(completion: (() -> Void)? = nil) {
        hideWidget()
        completion?()
    }

    /// Shows critical alert when malware detected during confirmation
    func showHijackDuringConfirmation(original: String, hijacked: String) {
        print("🚨 [HijackAlert] Malware detected during confirmation!")
        print("   Original: \(original.prefix(20))...")
        print("   Hijacked: \(hijacked.prefix(20))...")
        // TODO: Will implement alert UI in next iteration
    }

    /// Shows "Protection Enabled" toast for Option+Cmd+C instant protection
    func showProtectionEnabledToast(for type: CryptoType) {
        let toastView = ProtectionEnabledToast(cryptoType: type)
        let hosting = NSHostingView(rootView: toastView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.isOpaque = false
        hostingView = hosting
        self.contentView = hostingView
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = .clear

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let toastWidth: CGFloat = 260
        let toastHeight: CGFloat = 70
        let centerX = (screenFrame.width - toastWidth) / 2
        let centerY = screenFrame.maxY - 120  // Below notch

        self.setFrame(NSRect(x: centerX, y: centerY, width: toastWidth, height: toastHeight), display: true)
        // Use orderFrontRegardless() to avoid activating the app
        self.orderFrontRegardless()
        self.alphaValue = 0

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0
        }

        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self?.animator().alphaValue = 0
            } completionHandler: {
                self?.orderOut(nil)
            }
        }
    }

    /// Shows protection timer directly (for instant protection)
    func showProtection(for type: CryptoType, timeRemaining: TimeInterval, onDismiss: @escaping () -> Void) {
        print("🪟 [ProtectionTimerWindow] showProtection() - creating unified widget in timer state")

        // Create view model in timer state
        viewModel = ProtectionWidgetViewModel(
            state: .timer(type: type, timeRemaining: timeRemaining),
            onDismiss: onDismiss
        )

        // Create unified widget view (in timer state)
        let widgetView = UnifiedProtectionWidgetView(
            viewModel: viewModel!,
            onConfirm: {}, // Not used in timer state
            onSkip: {}      // Not used in timer state
        )

        let hosting = NSHostingView(rootView: widgetView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.isOpaque = false
        hostingView = hosting
        self.contentView = hostingView
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = .clear

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let centerX = (screenFrame.width - timerWidgetWidth) / 2

        // Start collapsed in notch
        let startY = screenFrame.maxY - notchHeight
        self.setFrame(NSRect(x: centerX, y: startY, width: timerWidgetWidth, height: notchHeight), display: true)

        self.orderFrontRegardless()
        self.alphaValue = 1.0

        // Animate expansion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                let finalY = screenFrame.maxY - (self.notchHeight + self.timerExpandedHeight)
                let finalFrame = NSRect(
                    x: centerX,
                    y: finalY,
                    width: self.timerWidgetWidth,
                    height: self.notchHeight + self.timerExpandedHeight
                )

                self.animator().setFrame(finalFrame, display: true)
                self.hasShadow = true
            }
        }
    }

    /// Updates the countdown timer
    func updateTime(_ timeRemaining: TimeInterval) {
        print("🪟 [ProtectionTimerWindow] updateTime called with \(Int(timeRemaining))s")
        print("   ViewModel exists: \(viewModel != nil)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vm = self.viewModel else {
                print("⚠️  [ProtectionTimerWindow] Self or ViewModel is nil!")
                return
            }
            print("🪟 [ProtectionTimerWindow] Calling ViewModel.updateTime(\(Int(timeRemaining)))")
            vm.updateTime(timeRemaining)
        }
    }

    /// Shows warning message when clipboard changes - expands widget
    func showWarning(_ message: String) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Show warning in view model
            self.viewModel?.showWarning(message)

            // Animate width expansion
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                // Smooth ease-out for expansion
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                let centerX = (screenFrame.width - self.timerWidgetWidthExpanded) / 2
                let currentY = self.frame.origin.y
                let expandedFrame = NSRect(
                    x: centerX,
                    y: currentY,
                    width: self.timerWidgetWidthExpanded,
                    height: self.frame.height
                )

                self.animator().setFrame(expandedFrame, display: true)
            }
        }
    }

    /// Collapses widget back to compact size after warning dismissed
    private func collapseToCompactSize() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            // Smooth ease-in for collapse
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true

            let centerX = (screenFrame.width - self.timerWidgetWidth) / 2
            let currentY = self.frame.origin.y
            let compactFrame = NSRect(
                x: centerX,
                y: currentY,
                width: self.timerWidgetWidth,
                height: self.frame.height
            )

            self.animator().setFrame(compactFrame, display: true)
        }
    }

    /// Hides the protection timer - collapses back into notch seamlessly
    func hideProtection() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4  // Faster collapse
            // Smooth ease-in for natural collapse
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true

            // Collapse back into notch - shrink height upward
            let centerX = (screenFrame.width - timerWidgetWidth) / 2
            let collapsedY = screenFrame.maxY - notchHeight
            let collapsedFrame = NSRect(
                x: centerX,
                y: collapsedY,
                width: timerWidgetWidth,
                height: notchHeight
            )

            self.animator().setFrame(collapsedFrame, display: true)
            self.animator().alphaValue = 0
            self.hasShadow = false
        } completionHandler: {
            self.orderOut(nil)
            self.viewModel = nil
        }
    }
}

// MARK: - Unified Protection Widget View

/// Single widget that displays either confirmation or timer state with smooth transitions
struct UnifiedProtectionWidgetView: View {
    @ObservedObject var viewModel: ProtectionWidgetViewModel
    let onConfirm: () -> Void
    let onSkip: () -> Void

    @State private var hasResponded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Invisible notch area
            Color.clear
                .frame(height: 32)

            // Content changes based on state
            Group {
                switch viewModel.state {
                case .confirmation(let address, let type):
                    confirmationContent(address: address, type: type)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))

                case .timer(let type, let timeRemaining):
                    timerContent(type: type, timeRemaining: timeRemaining)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                }
            }
            .animation(.smooth(duration: 0.4), value: viewModel.state)
        }
        .background(widgetBackground)
    }

    // Confirmation state UI
    @ViewBuilder
    private func confirmationContent(address: String, type: CryptoType) -> some View {
        VStack(spacing: 0) {
            // Header with logo and address
            HStack(spacing: 14) {
                ChainLogoView(cryptoType: type, size: 44)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(type.rawValue) Detected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(maskAddress(address))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(height: 72)

            // Single Protect button with ESC hint
            HStack(spacing: 0) {
                // ESC hint on left
                HStack(spacing: 4) {
                    Text("ESC")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                    Text("to dismiss")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                }

                Spacer()

                // Protect button on right
                Button(action: {
                    print("🔘 [UnifiedWidget] Protect button tapped")
                    guard !hasResponded else { return }
                    hasResponded = true
                    onConfirm()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Protect")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.18, green: 0.7, blue: 0.32)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(hasResponded)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Progress bar (only show in confirmation state)
            ConfirmationProgressBar()
                .frame(height: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    // Timer state UI
    @ViewBuilder
    private func timerContent(type: CryptoType, timeRemaining: TimeInterval) -> some View {
        HStack(spacing: 16) {
            // Blue shield icon
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 44, height: 44)

                Image(systemName: "shield.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Protection Active")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if viewModel.showWarning {
                    Text(viewModel.warningMessage ?? "")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.27))
                } else {
                    Text("\(type.rawValue) address")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Time remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.blue)

                Text("remaining")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(height: 72)
    }

    private var widgetBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 36,
            bottomTrailingRadius: 36,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.03, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 36,
                bottomTrailingRadius: 36,
                topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
    }

    private func maskAddress(_ address: String) -> String {
        guard address.count > 10 else { return "***" }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper view for confirmation progress bar
struct ConfirmationProgressBar: View {
    @State private var countdown: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 2)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: geometry.size.width * countdown, height: 2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6.0)) {
                countdown = 0.0
            }
        }
    }
}

// MARK: - Legacy Views (kept for DynamicNotchKit compatibility)

/// Old confirmation widget view (used by DynamicNotchKit, deprecated)
@available(*, deprecated, message: "Use UnifiedProtectionWidgetView instead")
struct ConfirmationWidgetView: View {
    let address: String
    let type: CryptoType
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @State private var countdown: CGFloat = 1.0  // 1.0 to 0.0 (auto-dismiss timer)
    @State private var hasResponded: Bool = false  // Prevent double-clicks

    var body: some View {
        VStack(spacing: 0) {
            // Invisible notch area
            Color.clear
                .frame(height: 32)

            // Main content - compact and minimal
            HStack(spacing: 14) {
                // Chain logo from SVG
                ChainLogoView(cryptoType: type, size: 44)
                    .allowsHitTesting(false)  // Logo shouldn't intercept clicks

                // Content area
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(type.rawValue) Detected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(maskAddress(address))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(height: 72)  // Same height as other widgets

            // Buttons
            HStack(spacing: 10) {
                // Skip button
                Button(action: {
                    print("🔘 [ConfirmationWidget] Skip button ACTION triggered")
                    guard !hasResponded else {
                        print("   ⚠️  Already responded, ignoring")
                        return
                    }
                    print("   ✅ Setting hasResponded = true")
                    hasResponded = true
                    print("   📞 Calling onDismiss()...")
                    onDismiss()
                    print("   ✅ onDismiss() called")
                }) {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .disabled(hasResponded)

                // Protect button
                Button(action: {
                    print("🔘 [ConfirmationWidget] Protect button ACTION triggered")
                    guard !hasResponded else {
                        print("   ⚠️  Already responded, ignoring")
                        return
                    }
                    print("   ✅ Setting hasResponded = true")
                    hasResponded = true
                    print("   📞 Calling onConfirm()...")
                    onConfirm()
                    print("   ✅ onConfirm() called")
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11, weight: .semibold))

                        Text("Protect")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.18, green: 0.7, blue: 0.32)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(hasResponded)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 2)

                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: geometry.size.width * countdown, height: 2)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 36,
                bottomTrailingRadius: 36,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.09, blue: 0.16),
                        Color(red: 0.03, green: 0.05, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 36,
                    bottomTrailingRadius: 36,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        )
        .onAppear {
            // Start auto-dismiss countdown (10 seconds for user interaction)
            withAnimation(.linear(duration: 10.0)) {
                countdown = 0.0
            }
        }
    }

    private func maskAddress(_ address: String) -> String {
        guard address.count > 10 else { return "***" }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }

    private func cryptoEmoji(for type: CryptoType) -> String {
        switch type {
        case .bitcoin: return "₿"
        case .ethereum: return "Ξ"
        case .solana: return "◎"
        case .litecoin: return "Ł"
        case .dogecoin: return "Ð"
        case .monero: return "ɱ"
        case .unknown: return "🔐"
        }
    }
}


// MARK: - Protection Enabled Toast

/// Simple toast shown when user presses Option+Cmd+C for instant protection
struct ProtectionEnabledToast: View {
    let cryptoType: CryptoType

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            // Chain logo with checkmark overlay
            ZStack {
                ChainLogoView(cryptoType: cryptoType, size: 44)

                // Small checkmark overlay
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 14, y: 14)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Protected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Monitoring for 2:00")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Response time indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("5ms")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.green)

                Text("response")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.09, blue: 0.16),  // Dark navy
                            Color(red: 0.03, green: 0.05, blue: 0.10)   // Darker
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Same Address Toast

/// Toast shown when user copies the same address that's already protected
struct SameAddressToast: View {
    let cryptoType: CryptoType
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -10
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        HStack(spacing: 16) {
            // Chain logo with checkmark + glow ring for psychological "already protected" feedback
            ZStack {
                // Outer glow ring - psychological "safety" indicator
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 3)
                    .frame(width: 54, height: 54)
                    .scaleEffect(checkmarkScale * 1.2)

                ChainLogoView(cryptoType: cryptoType, size: 44)
                    .scaleEffect(checkmarkScale)

                // Small checkmark overlay
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 14, y: 14)
                    .scaleEffect(checkmarkScale)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Already Protected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Same \(cryptoType.rawValue) address")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Trust indicator - shows protection is active
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                Text("secure")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
            }
            .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.09, blue: 0.16),  // Dark navy
                            Color(red: 0.03, green: 0.05, blue: 0.10)   // Darker
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.4),  // Green glow - trust signal
                                    Color.green.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 5)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            // Satisfying entrance animation - psychological "reward" feeling
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
                rotation = 0
            }

            // Delayed checkmark pop - creates anticipation then satisfaction
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
                checkmarkScale = 1.0
            }
        }
    }
}

#Preview {
    let viewModel = ProtectionWidgetViewModel(
        state: .timer(type: .ethereum, timeRemaining: 95),
        onDismiss: {}
    )
    UnifiedProtectionWidgetView(
        viewModel: viewModel,
        onConfirm: {},
        onSkip: {}
    )
    .frame(width: 320, height: 200)
}
#endif
