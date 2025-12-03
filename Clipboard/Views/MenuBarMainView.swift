//
//  MenuBarMainView.swift
//  Clipboard
//
//  Main view for menu bar popover with tabs for dashboard, settings, and license
//

import SwiftUI

struct MenuBarMainView: View {
    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject var clipboardMonitor: ClipboardMonitor
    @ObservedObject var statisticsManager: StatisticsManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with app name and status
            headerView

            Divider()

            if licenseManager.isLicensed {
                // Licensed view with tabs
                TabView(selection: $selectedTab) {
                    // Statistics Dashboard
                    StatisticsDashboardView(statsManager: statisticsManager)
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.xaxis")
                        }
                        .tag(0)

                    // Settings
                    SettingsView(licenseManager: licenseManager,
                               clipboardMonitor: clipboardMonitor)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(1)

                    // License Info
                    LicenseInfoView(licenseManager: licenseManager)
                        .tabItem {
                            Label("License", systemImage: "key.fill")
                        }
                        .tag(2)
                }
            } else {
                // Unlicensed view
                UnlicensedMenuView(licenseManager: licenseManager)
            }
        }
        .background(Color(hex: "0F1419"))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Klip")
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(clipboardMonitor.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(clipboardMonitor.isMonitoring ? "Protection Active" : "Protection Inactive")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Quick actions
            HStack(spacing: 8) {
                if licenseManager.isLicensed {
                    Button(action: {
                        clipboardMonitor.isMonitoring ?
                            clipboardMonitor.stopMonitoring() :
                            clipboardMonitor.startMonitoring()
                    }) {
                        Image(systemName: clipboardMonitor.isMonitoring ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(clipboardMonitor.isMonitoring ? "Pause Protection" : "Start Protection")
                }

                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit Klip")
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Unlicensed Menu View

struct UnlicensedMenuView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var selectedOption = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedOption) {
                Text("Activate License").tag(0)
                Text("Try Free").tag(1)
                Text("About").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Content based on selection
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedOption {
                    case 0:
                        LicenseActivationView(licenseManager: licenseManager)
                    case 1:
                        FreeTrialView()
                    case 2:
                        AboutView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - License Activation View

struct LicenseActivationView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var email = ""
    @State private var licenseKey = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isActivating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activate Your License")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your email and license key to activate Klip")
                .font(.caption)
                .foregroundColor(.gray)

            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.gray)

                TextField("your@email.com", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // License key field
            VStack(alignment: .leading, spacing: 4) {
                Text("License Key")
                    .font(.caption)
                    .foregroundColor(.gray)

                TextField("CGRD-XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }

            if showError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }

            HStack {
                Button("Activate") {
                    activateLicense()
                }
                .buttonStyle(ProminentButtonStyle())
                .disabled(email.isEmpty || licenseKey.isEmpty || isActivating)

                if isActivating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Help text
            VStack(alignment: .leading, spacing: 8) {
                Text("Need a license?")
                    .font(.caption)
                    .fontWeight(.semibold)

                Link("Purchase at klip.app",
                     destination: URL(string: "https://klip.app")!)
                    .font(.caption)

                Text("Test License: CGRD-TEST-YEAR-2024-DEMO")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
    }

    private func activateLicense() {
        isActivating = true
        showError = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if licenseManager.validateAndActivate(email: email, licenseKey: licenseKey) {
                // Success - the view will automatically update
                isActivating = false
            } else {
                showError = true
                errorMessage = "Invalid license key or email. Please check and try again."
                isActivating = false
            }
        }
    }
}

// MARK: - Free Trial View

struct FreeTrialView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Try Klip Free")
                .font(.title2)
                .fontWeight(.bold)

            Text("Experience full protection for 7 days")
                .font(.subheadline)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "shield.checkered",
                          title: "Real-time Protection",
                          description: "Instant detection of clipboard hijacking")

                FeatureRow(icon: "chart.bar.xaxis",
                          title: "Activity Dashboard",
                          description: "Track threats and usage statistics")

                FeatureRow(icon: "lock.shield",
                          title: "Paste Blocking",
                          description: "Prevent malicious paste attempts")
            }
            .padding(.vertical)

            Button("Start Free Trial") {
                // TODO: Implement free trial activation
                print("Free trial requested")
            }
            .buttonStyle(ProminentButtonStyle())
        }
    }
}

// MARK: - License Info View

struct LicenseInfoView: View {
    @ObservedObject var licenseManager: LicenseManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // License status card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            Text("License Active")
                                .font(.headline)

                            if let email = licenseManager.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()
                    }

                    Divider()

                    if let licenseData = licenseManager.licenseData {
                        InfoRow(label: "Type",
                               value: licenseData.product == .lifetime ? "Lifetime" : "Annual")

                        InfoRow(label: "License ID",
                               value: String(licenseData.licenseId.prefix(8)) + "...")

                        if let expiresAt = licenseData.expiresAt {
                            InfoRow(label: "Expires",
                                   value: DateFormatter.localizedString(from: expiresAt,
                                                                       dateStyle: .medium,
                                                                       timeStyle: .none))
                        } else {
                            InfoRow(label: "Expires", value: "Never")
                        }

                        if let daysRemaining = licenseData.daysUntilExpiry {
                            InfoRow(label: "Days Remaining", value: "\(daysRemaining)")
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                // Actions
                VStack(spacing: 12) {
                    Button("Deactivate License") {
                        licenseManager.deactivate()
                    }
                    .buttonStyle(DestructiveButtonStyle())

                    Link("Manage Subscription",
                         destination: URL(string: "https://klip.app/account")!)
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Klip")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.gray)

            Text("Protecting your cryptocurrency transactions from clipboard hijacking malware")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)

            Divider()

            VStack(spacing: 8) {
                Link("Website", destination: URL(string: "https://klip.app")!)
                Link("Support", destination: URL(string: "https://klip.app/support")!)
                Link("Privacy Policy", destination: URL(string: "https://klip.app/privacy")!)
            }
            .font(.caption)

            Text("© 2024 Klip. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top)
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Button Styles

struct ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}