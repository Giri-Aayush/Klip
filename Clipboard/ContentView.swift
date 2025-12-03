//
//  ContentView.swift
//  Clipboard
//
//  Created by Aayush Giri on 18/10/25.
//

import SwiftUI

struct ContentView: View {

    // MARK: - Observed Objects

    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject var clipboardMonitor: ClipboardMonitor
    @ObservedObject var statisticsManager: StatisticsManager

    // MARK: - State

    @State private var selectedTab: Tab = .dashboard

    // MARK: - Body

    var body: some View {
        Group {
            if licenseManager.isLicensed {
                // Main App Interface
                mainInterface
            } else {
                // Activation Screen
                ActivationView(licenseManager: licenseManager)
            }
        }
    }

    // MARK: - Main Interface

    @ViewBuilder
    private var mainInterface: some View {
        #if os(macOS)
        macOSInterface
        #elseif os(iOS)
        iOSInterface
        #endif
    }

    #if os(macOS)
    private var macOSInterface: some View {
        TabView(selection: $selectedTab) {
            DashboardView(clipboardMonitor: clipboardMonitor, statsManager: statisticsManager)
                .tabItem {
                    Label("Dashboard", systemImage: "shield.checkered")
                }
                .tag(Tab.dashboard)

            SettingsView(
                licenseManager: licenseManager,
                clipboardMonitor: clipboardMonitor
            )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    #endif

    #if os(iOS)
    private var iOSInterface: some View {
        TabView(selection: $selectedTab) {
            DashboardView(clipboardMonitor: clipboardMonitor, statsManager: statisticsManager)
                .tabItem {
                    Label("Dashboard", systemImage: "shield.checkered")
                }
                .tag(Tab.dashboard)

            SettingsView(
                licenseManager: licenseManager,
                clipboardMonitor: clipboardMonitor
            )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
    #endif

    // MARK: - Tab Enum

    enum Tab {
        case dashboard
        case settings
    }
}

#Preview("Licensed") {
    ContentView(
        licenseManager: {
            let manager = LicenseManager()
            manager.isLicensed = true
            return manager
        }(),
        clipboardMonitor: {
            let monitor = ClipboardMonitor()
            monitor.isMonitoring = true
            monitor.checksToday = 247
            return monitor
        }(),
        statisticsManager: StatisticsManager()
    )
}

#Preview("Unlicensed") {
    ContentView(
        licenseManager: LicenseManager(),
        clipboardMonitor: ClipboardMonitor(),
        statisticsManager: StatisticsManager()
    )
}
