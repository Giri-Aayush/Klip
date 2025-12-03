//
//  ClipboardApp.swift
//  Clipboard
//
//  Created by Aayush Giri on 18/10/25.
//

import SwiftUI
import UserNotifications

#if os(macOS)
import AppKit

// CRITICAL: AppDelegate to prevent automatic window opening and desktop switching
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventMonitor: Any?
    var statisticsManager: StatisticsManager?
    var clipboardMonitor: ClipboardMonitor?
    var licenseManager: LicenseManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL: Set activation policy to accessory to prevent dock icon and app switching
        NSApp.setActivationPolicy(.accessory)

        // Create the popover
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = true

        // Add menu bar icon so users can still access the app
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Use emoji for better visibility
            button.title = "📋"

            // Also try to add an image
            if let image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Klip") {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
                // If image works, clear the title
                button.title = ""
            }

            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "Klip - Click for Dashboard"
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            print("✅ Menu bar icon created successfully")
            print("   Button frame: \(button.frame)")
            print("   Has image: \(button.image != nil)")
            print("   Title: '\(button.title)'")
        } else {
            print("❌ Failed to create menu bar button")
        }

        // Don't add global event monitor here - it requires accessibility permissions
        // The popover's transient behavior will handle dismissal automatically
    }

    @objc func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else {
            print("❌ No status bar button available")
            return
        }

        // Create a simple view if managers aren't ready yet
        if statisticsManager == nil || clipboardMonitor == nil || licenseManager == nil {
            print("⚠️ Managers not ready, showing simple view")
            let simpleView = VStack {
                Text("Klip")
                    .font(.title2)
                    .padding()
                Text("Loading...")
                    .foregroundColor(.gray)
            }
            .frame(width: 300, height: 100)
            .background(Color(NSColor.controlBackgroundColor))

            popover?.contentViewController = NSHostingController(rootView: simpleView)
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            return
        }

        guard let statsManager = statisticsManager,
              let clipboardMonitor = clipboardMonitor,
              let licenseManager = licenseManager else { return }

        // Create the main menu bar view with all options
        let mainView = MenuBarMainView(
            licenseManager: licenseManager,
            clipboardMonitor: clipboardMonitor,
            statisticsManager: statsManager
        )
        .frame(width: licenseManager.isLicensed ? 800 : 450,
               height: licenseManager.isLicensed ? 600 : 500)

        popover?.contentViewController = NSHostingController(rootView: mainView)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Add smooth fade-in animation
        popover?.contentViewController?.view.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            popover?.contentViewController?.view.animator().alphaValue = 1.0
        }
    }

    func closePopover() {
        // Smooth fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            popover?.contentViewController?.view.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.popover?.performClose(nil)
        })
    }

    @objc func showMainWindow() {
        // Legacy method - now we use popover instead
        togglePopover()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}
#endif

@main
struct ClipboardApp: App {

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    // MARK: - State Objects

    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var clipboardMonitor = ClipboardMonitor()
    @StateObject private var statisticsManager = StatisticsManager()

    #if os(macOS)
    private let floatingIndicator = FloatingIndicatorWindow()
    private let blockedPasteAlert = BlockedPasteAlertWindow()
    private let notchManager = DynamicNotchManager()
    @StateObject private var pasteDetector = PasteDetector()
    private let pasteBlocker = PasteBlocker()
    #endif

    // Timer needs to be in a class wrapper for mutation
    #if os(macOS)
    private class TimerWrapper {
        var timer: Timer?
    }
    private let timerWrapper = TimerWrapper()
    #endif

    // MARK: - Initialization

    init() {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    // MARK: - Body

    var body: some Scene {
        #if os(macOS)
        // Empty window group - we use menu bar only
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    // Delay initialization to ensure everything is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Link statistics manager to clipboard monitor
                        clipboardMonitor.statsManager = statisticsManager

                        // Pass state objects to AppDelegate for menu bar popover
                        appDelegate.statisticsManager = statisticsManager
                        appDelegate.clipboardMonitor = clipboardMonitor
                        appDelegate.licenseManager = licenseManager

                        setupApp()

                        // Hide the main window immediately
                        for window in NSApp.windows {
                            window.close()
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
        .commandsRemoved()
        #else
        WindowGroup {
            ContentView(
                licenseManager: licenseManager,
                clipboardMonitor: clipboardMonitor,
                statisticsManager: statisticsManager
            )
            .onAppear {
                clipboardMonitor.statsManager = statisticsManager
                setupApp()
            }
        }
        #endif
    }

    // MARK: - Setup

    private func setupApp() {
        let notificationManager = NotificationManager.shared

        // Request notification permission
        Task {
            await notificationManager.requestAuthorization()
        }

        // Temporarily disable paste detector to isolate crash issue
        #if os(macOS)
        // TEMPORARILY DISABLED - Paste detection can cause system errors
        // Will re-enable once core functionality is stable
        if false {
        pasteDetector.onCopyDetected = { [self] in
            // Record timestamp for time-correlation
            clipboardMonitor.lastUserCopyTime = pasteDetector.lastUserCopyTimestamp
            print("⏱️  [Copy] Cmd+C detected at \(Date())")
        }

        // Setup INTENTIONAL COPY detector (Option+Cmd+C) - Instant protection
        pasteDetector.onIntentionalCopyDetected = { [self] in
            print("🔐 [IntentionalCopy] Option+Cmd+C detected - INSTANT PROTECTION")

            // CHECK: If protection is already active, show warning instead
            if self.clipboardMonitor.protectionActive {
                print("⚠️  [IntentionalCopy] Protection already active - showing locked warning")

                // Play beep for audio feedback
                #if os(macOS)
                NSSound.beep()
                #endif

                // Show warning in notch
                Task { @MainActor in
                    await self.notchManager.showWarning("🛡️ Protection Already Active")
                }
                return
            }

            // CRITICAL: Wait for clipboard to update (copy event happens AFTER keypress)
            // Option+Cmd+C means user is ABOUT to copy - clipboard updates ~50ms later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Read clipboard to check if it's a crypto address
                #if os(macOS)
                guard let clipboardContent = NSPasteboard.general.string(forType: .string) else {
                    print("⚠️  No string in clipboard")
                    return
                }
                #endif

                // Detect crypto type using pattern matcher
                let patternMatcher = PatternMatcher()
                guard let detectedType = patternMatcher.detectCryptoType(clipboardContent) else {
                    print("ℹ️  Not a crypto address - ignoring Option+Cmd+C")
                    return
                }

                print("✅ Crypto address detected: \(detectedType.rawValue)")

                // Show toast notification first
                Task { @MainActor in
                    await self.notchManager.showProtectionEnabledToast(for: detectedType)

                    // Wait for toast to auto-hide (2 seconds) plus animation time
                    try? await Task.sleep(for: .seconds(2.8))

                    // Ensure toast is fully hidden before showing timer
                    await self.notchManager.hideToast()

                    // Now enable protection (this will trigger onProtectionConfirmed callback which shows timer)
                    self.clipboardMonitor.enableInstantProtection(address: clipboardContent, type: detectedType)
                }
            }
        }

        // Setup ESCAPE key detector - dismiss protection OR confirmation widget
        pasteDetector.onEscapePressed = { [self] in
            // Check if there's an active confirmation widget OR active protection
            if notchManager.hasActiveWidget() {
                print("🔓 [Escape] User dismissed widget")

                // If protection is active, stop it
                if clipboardMonitor.protectionActive {
                    print("   Stopping active protection")
                    timerWrapper.timer?.invalidate()
                    timerWrapper.timer = nil
                    clipboardMonitor.stopProtection()
                } else {
                    print("   Dismissing confirmation widget")
                    clipboardMonitor.dismissPendingProtection()
                }

                // Hide the widget (works for both confirmation and timer)
                Task { @MainActor in
                    print("🚪 [Escape] Hiding widget...")
                    await notchManager.hideProtectionTimer()
                    print("✅ [Escape] Widget hidden")
                }
            } else {
                print("ℹ️  Escape pressed but no active widget")
            }
        }

        // Setup PASTE detector (Cmd+V)
        pasteDetector.onPasteDetected = { [self] in
            // Check if we're actively protecting a crypto address
            guard clipboardMonitor.protectionActive,
                  let protectedAddress = clipboardMonitor.monitoredContent,
                  let type = clipboardMonitor.lastDetectedCryptoType else {
                print("ℹ️  Paste detected but no active protection")
                return
            }

            // Read current clipboard to verify it's actually a crypto address
            #if os(macOS)
            guard let currentClipboard = NSPasteboard.general.string(forType: .string) else {
                print("ℹ️  Paste detected but clipboard has no string (likely image/file)")
                return
            }
            #endif

            // Verify current clipboard matches the protected address
            if currentClipboard == protectedAddress {
                print("✅ PASTE VERIFIED - Protected \(type.rawValue) address pasted safely!")
                DispatchQueue.main.async {
                    floatingIndicator.showPaste(for: type)
                }

                // Update statistics
                DispatchQueue.main.async {
                    clipboardMonitor.pasteCount += 1
                }

                // Stop protection after successful paste
                clipboardMonitor.stopProtection()

                // Hide the protection timer
                hideProtectionTimer()
            } else {
                print("ℹ️  Paste detected but content doesn't match protected address")
                print("   Protected: \(String(protectedAddress.prefix(20)))...")
                print("   Current:   \(String(currentClipboard.prefix(20)))...")
            }
        }

        // Setup paste blocker
        pasteBlocker.shouldBlockPaste = { [self] in
            return clipboardMonitor.checkIfShouldBlockPaste()
        }

        pasteBlocker.onPasteBlocked = { [self] original, hijacked in
            print("🚨 PASTE BLOCKED - Showing red alert at cursor!")

            // Strong haptic feedback for blocked paste (error)
            HapticFeedback.shared.error()

            DispatchQueue.main.async {
                blockedPasteAlert.showBlocked(original: original, hijacked: hijacked)
            }

            // Also increment threats blocked counter
            clipboardMonitor.threatsBlocked += 1
        }
        } // End of if false block - paste detector disabled
        #endif

        // Setup clipboard monitoring callbacks - NEW OPT-IN FLOW
        clipboardMonitor.onCryptoDetected = { [self] address, type in
            print("📋 CRYPTO DETECTED: \(type.rawValue) address")
            print("   🔒 Hash captured immediately")

            // Show confirmation widget in notch
            #if os(macOS)
            DispatchQueue.main.async {
                // Show blue copy indicator at cursor
                floatingIndicator.showCopy(for: type)

                // Show confirmation widget (asks user to enable protection)
                self.showConfirmationWidget(address: address, type: type)
            }
            #endif
        }

        clipboardMonitor.onProtectionConfirmed = { [self] type, address in
            print("🛡️ PROTECTION CONFIRMED by user (Option+Cmd+C instant protection)")

            // This callback is ONLY for Option+Cmd+C instant protection
            // For normal Cmd+C flow, the timer is shown via transitionWidgetToTimer()
            // So we need to check if we already have a confirmation widget showing
            #if os(macOS)
            // Only show timer if we don't already have a widget transition in progress
            // (This callback is triggered by both instant protection AND regular confirmation)
            // For regular confirmation, we handle it in the onConfirm callback
            // For instant protection, there's no confirmation widget, so show timer directly
            if !notchManager.hasActiveWidget() {
                Task { @MainActor [clipboardMonitor, notchManager] in
                    print("   🎯 Showing timer for instant protection (no confirmation widget)")
                    await notchManager.showTimerDirectly(type: type, timeRemaining: clipboardMonitor.protectionTimeRemaining)
                    self.startTimerUpdateLoop(for: type)
                }
            } else {
                print("   ⏭️  Skipping timer show - widget transition already in progress")
            }
            #endif
        }

        clipboardMonitor.onMalwareDetectedDuringConfirmation = { [self] original, hijacked in
            print("🚨 MALWARE DETECTED DURING CONFIRMATION!")

            // Show critical alert
            #if os(macOS)
            DispatchQueue.main.async {
                self.blockedPasteAlert.showHijackDuringConfirmation(
                    original: original,
                    hijacked: hijacked
                )
            }
            #endif
        }

        clipboardMonitor.onClipboardLockWarning = { [self] message in
            print("🛡️  [PROTECTION ACTIVE] \(message)")

            // Show warning in notch
            #if os(macOS)
            Task { @MainActor in
                await self.notchManager.showWarning("🛡️ Protection Already Active")
            }
            #endif
        }

        clipboardMonitor.onSameAddressCopied = { [self] type in
            print("✅ SAME ADDRESS: User copied protected address again")

            // Show satisfying "already protected" toast
            #if os(macOS)
            Task { @MainActor in
                await self.notchManager.showSameAddressToast(for: type)
            }
            #endif
        }

        clipboardMonitor.onCryptoPasted = { [self] address, type in
            print("✅ PASTE: \(type.rawValue) address pasted & verified!")

            // Show green "verified" indicator
            #if os(macOS)
            DispatchQueue.main.async {
                floatingIndicator.showPaste(for: type)
            }
            #endif
        }

        // Hijack detected during protection (when paste is attempted)
        clipboardMonitor.onHijackDetected = { original, attempted in
            print("🚨 Hijack detected on paste attempt!")
            // Paste blocker will show red alert at cursor
        }

        // Auto-start monitoring if licensed
        print("🔍 [Setup] Checking license status...")
        print("   Licensed: \(licenseManager.isLicensed)")

        if licenseManager.isLicensed {
            print("✅ [Setup] License valid - starting clipboard monitoring")
            clipboardMonitor.startMonitoring()
        } else {
            print("❌ [Setup] No valid license - monitoring NOT started")
        }
    }

    // MARK: - Protection Flow Management

    #if os(macOS)
    private func showConfirmationWidget(address: String, type: CryptoType) {
        print("🔐 [Confirmation] Showing unified widget in confirmation state")

        // Show unified widget in confirmation state
        notchManager.showConfirmation(
            address: address,
            type: type,
            onConfirm: { [clipboardMonitor] in
                print("✅ [Confirmation] Protect button clicked - activating protection")

                // Immediately activate protection (no delays, no async)
                clipboardMonitor.confirmProtection()

                // Now SYNCHRONOUSLY transition: hide confirmation → show timer
                let timeRemaining = clipboardMonitor.protectionTimeRemaining
                Task { @MainActor in
                    await self.transitionWidgetToTimer(type: type, timeRemaining: timeRemaining)
                }
            },
            onDismiss: { [clipboardMonitor] in
                print("❌ [Confirmation] User dismissed - clearing protection")
                clipboardMonitor.dismissPendingProtection()
            }
        )
    }

    // Transitions the unified widget from confirmation to timer state (SYNCHRONOUS)
    private func transitionWidgetToTimer(type: CryptoType, timeRemaining: TimeInterval) async {
        print("🔄 [UnifiedWidget] Starting synchronous transition")

        // SYNCHRONOUSLY: hide confirmation → show timer (awaits completion)
        await notchManager.transitionToTimer(type: type, timeRemaining: timeRemaining)

        print("✅ [UnifiedWidget] Transition complete, starting timer loop")
        // Start timer update loop
        startTimerUpdateLoop(for: type)
    }

    // Start timer update loop for unified widget
    private func startTimerUpdateLoop(for type: CryptoType) {
        print("🔄 [TimerLoop] Starting timer update loop")

        // Stop any existing timer
        timerWrapper.timer?.invalidate()
        timerWrapper.timer = nil

        var lastLoggedSecond = -1
        timerWrapper.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak timerWrapper, weak clipboardMonitor, weak notchManager] _ in
            guard let monitor = clipboardMonitor else { return }
            let timeRemaining = monitor.protectionTimeRemaining

            // Log every second to avoid spam
            let currentSecond = Int(timeRemaining)
            if currentSecond != lastLoggedSecond {
                print("🔄 [TimerLoop] Updating: \(currentSecond)s, active: \(monitor.protectionActive)")
                lastLoggedSecond = currentSecond
            }

            if timeRemaining > 0 && monitor.protectionActive {
                // Update the view model time
                DispatchQueue.main.async {
                    notchManager?.updateTimer(timeRemaining)
                }
            } else {
                // Protection expired or stopped
                print("⏹️  [ProtectionTimer] Stopping (time: \(timeRemaining)s, active: \(monitor.protectionActive))")
                timerWrapper?.timer?.invalidate()
                timerWrapper?.timer = nil
                Task { @MainActor in
                    print("🚪 [TimerExpired] Hiding widget...")
                    await notchManager?.hideProtectionTimer()
                    print("✅ [TimerExpired] Widget hidden")
                }
            }
        }
    }

    private func hideProtectionTimer() {
        timerWrapper.timer?.invalidate()
        timerWrapper.timer = nil
        Task { @MainActor in
            await notchManager.hideProtectionTimer()
        }
    }
    #endif
}
