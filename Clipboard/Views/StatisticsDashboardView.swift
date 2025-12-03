//
//  StatisticsDashboardView.swift
//  Clipboard
//
//  Comprehensive statistics dashboard with daily and monthly activity
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct StatisticsDashboardView: View {
    @ObservedObject var statsManager: StatisticsManager
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showingExportMenu = false
    @State private var showingResetConfirmation = false

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with time range selector
                headerSection

                // Quick stats cards
                quickStatsSection

                // Activity chart
                activityChartSection

                // Detailed breakdown
                detailedBreakdownSection

                // Milestones and achievements
                milestonesSection

                // Export and reset buttons
                actionButtonsSection
            }
            .padding()
        }
        .background(Color(hex: "0F1419"))
        .foregroundColor(.white)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Activity Dashboard")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }

            if selectedTimeRange == .today {
                HStack {
                    if let firstActivity = statsManager.todayStats.firstActivityTime {
                        Label("First Activity: \(firstActivity, style: .time)", systemImage: "sunrise")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if let peakHour = statsManager.todayStats.peakActivityHour {
                        Label("Peak Hour: \(peakHour):00", systemImage: "flame")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            quickStatCard(
                title: "Checks",
                value: formatNumber(getStatValue(.checks)),
                icon: "magnifyingglass",
                color: .blue
            )

            quickStatCard(
                title: "Addresses Copied",
                value: formatNumber(getStatValue(.addresses)),
                icon: "doc.on.clipboard",
                color: .green
            )

            quickStatCard(
                title: "Safe Pastes",
                value: formatNumber(getStatValue(.pastes)),
                icon: "checkmark.shield",
                color: .mint
            )

            quickStatCard(
                title: "Threats Blocked",
                value: formatNumber(getStatValue(.threats)),
                icon: "xmark.shield.fill",
                color: .red
            )
        }
    }

    private func quickStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Activity Chart Section

    private var activityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Timeline")
                .font(.headline)
                .foregroundColor(.white)

            if selectedTimeRange == .week {
                weeklyActivityChart
            } else if selectedTimeRange == .month {
                monthlyActivityChart
            } else {
                hourlyActivityChart
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var weeklyActivityChart: some View {
        if !statsManager.weeklyStats.isEmpty {
            Chart(statsManager.weeklyStats, id: \.date) { stat in
                BarMark(
                    x: .value("Day", dayLabel(for: stat.date)),
                    y: .value("Checks", stat.checksPerformed)
                )
                .foregroundStyle(Color.blue.gradient)

                if stat.threatsBlocked > 0 {
                    BarMark(
                        x: .value("Day", dayLabel(for: stat.date)),
                        y: .value("Threats", stat.threatsBlocked)
                    )
                    .foregroundStyle(Color.red.gradient)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.2))
                }
            }
        } else {
            Text("No weekly data available")
                .foregroundColor(.gray)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var monthlyActivityChart: some View {
        if let monthStats = statsManager.currentMonthStats {
            Chart(monthStats.dailyStats, id: \.date) { stat in
                LineMark(
                    x: .value("Date", stat.date),
                    y: .value("Activity", stat.checksPerformed)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", stat.date),
                    y: .value("Activity", stat.checksPerformed)
                )
                .foregroundStyle(Color.blue)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .foregroundStyle(.gray)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.2))
                }
            }
        } else {
            Text("No monthly data available")
                .foregroundColor(.gray)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var hourlyActivityChart: some View {
        // Create hourly data for today
        let hourlyData = (0..<24).map { hour in
            (hour: hour, count: getHourlyActivity(hour))
        }

        Chart(hourlyData, id: \.hour) { data in
            BarMark(
                x: .value("Hour", "\(data.hour)"),
                y: .value("Activity", data.count)
            )
            .foregroundStyle(
                data.hour == statsManager.todayStats.peakActivityHour ?
                Color.orange.gradient : Color.blue.gradient
            )
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks { value in
                if let hour = value.as(String.self),
                   let hourInt = Int(hour),
                   hourInt % 3 == 0 {
                    AxisValueLabel("\(hourInt):00")
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    // MARK: - Detailed Breakdown Section

    private var detailedBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown by Currency")
                .font(.headline)

            HStack(spacing: 20) {
                cryptoBreakdownCard(
                    type: "Bitcoin",
                    count: getStatValue(.bitcoin),
                    color: Color(hex: "F7931A"),
                    icon: "bitcoinsign.circle"
                )

                cryptoBreakdownCard(
                    type: "Ethereum",
                    count: getStatValue(.ethereum),
                    color: Color(hex: "627EEA"),
                    icon: "e.circle"
                )

                cryptoBreakdownCard(
                    type: "Solana",
                    count: getStatValue(.solana),
                    color: Color(hex: "8E3FD6"),
                    icon: "s.circle"
                )
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Protection Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Protection Metrics")
                    .font(.headline)

                HStack {
                    Label("Protection Activations", systemImage: "lock.shield")
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(getStatValue(.protections))")
                        .fontWeight(.semibold)
                }

                HStack {
                    Label("Total Protection Time", systemImage: "timer")
                        .foregroundColor(.blue)
                    Spacer()
                    Text(formatDuration(getStatValue(.protectionTime)))
                        .fontWeight(.semibold)
                }

                if selectedTimeRange == .allTime {
                    HStack {
                        Label("Current Streak", systemImage: "flame")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(statsManager.allTimeStats.currentStreak) days")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Longest Streak", systemImage: "trophy")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("\(statsManager.allTimeStats.longestStreak) days")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    private func cryptoBreakdownCard(type: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)

            Text(type)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Milestones Section

    @ViewBuilder
    private var milestonesSection: some View {
        if selectedTimeRange == .allTime && !statsManager.allTimeStats.milestonesReached.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Achievements")
                    .font(.headline)

                ForEach(Array(statsManager.allTimeStats.milestonesReached.keys.sorted()), id: \.self) { key in
                    if let date = statsManager.allTimeStats.milestonesReached[key] {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)

                            Text(milestoneTitle(for: key))
                                .font(.subheadline)

                            Spacer()

                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button(action: exportStatistics) {
                Label("Export Statistics", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: { showingResetConfirmation = true }) {
                Label("Reset Statistics", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .alert(isPresented: $showingResetConfirmation) {
            Alert(
                title: Text("Reset All Statistics?"),
                message: Text("This will permanently delete all your activity data. This action cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    statsManager.resetStatistics()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Helper Methods

    private enum StatType {
        case checks, addresses, pastes, threats, protections, protectionTime
        case bitcoin, ethereum, solana
    }

    private func getStatValue(_ type: StatType) -> Int {
        switch selectedTimeRange {
        case .today:
            return getStatFromDaily(statsManager.todayStats, type: type)
        case .yesterday:
            guard let yesterday = statsManager.yesterdayStats else { return 0 }
            return getStatFromDaily(yesterday, type: type)
        case .week:
            return statsManager.weeklyStats.reduce(0) { $0 + getStatFromDaily($1, type: type) }
        case .month:
            guard let month = statsManager.currentMonthStats else { return 0 }
            return getStatFromMonthly(month, type: type)
        case .allTime:
            return getStatFromAllTime(type)
        }
    }

    private func getStatFromDaily(_ stats: DailyStatistics, type: StatType) -> Int {
        switch type {
        case .checks: return stats.checksPerformed
        case .addresses: return stats.cryptoAddressesCopied
        case .pastes: return stats.safePastes
        case .threats: return stats.threatsBlocked
        case .protections: return stats.protectionActivations
        case .protectionTime: return Int(stats.totalProtectionTime)
        case .bitcoin: return stats.bitcoinCopies
        case .ethereum: return stats.ethereumCopies
        case .solana: return stats.solanaCopies
        }
    }

    private func getStatFromMonthly(_ stats: MonthlyStatistics, type: StatType) -> Int {
        switch type {
        case .checks: return stats.totalChecks
        case .addresses: return stats.totalCryptoAddresses
        case .pastes: return stats.totalSafePastes
        case .threats: return stats.totalThreatsBlocked
        case .protectionTime: return Int(stats.totalProtectionTime)
        default: return stats.dailyStats.reduce(0) { $0 + getStatFromDaily($1, type: type) }
        }
    }

    private func getStatFromAllTime(_ type: StatType) -> Int {
        switch type {
        case .checks: return statsManager.allTimeStats.totalChecks
        case .addresses: return statsManager.allTimeStats.totalCryptoAddresses
        case .pastes: return statsManager.allTimeStats.totalSafePastes
        case .threats: return statsManager.allTimeStats.totalThreatsBlocked
        case .protectionTime: return Int(statsManager.allTimeStats.totalProtectionTime)
        default: return 0
        }
    }

    private func getHourlyActivity(_ hour: Int) -> Int {
        // This would need to be tracked in real-time
        // For now, return simulated data
        if hour >= 9 && hour <= 17 {
            return Int.random(in: 10...50)
        }
        return Int.random(in: 0...10)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func milestoneTitle(for key: String) -> String {
        switch key {
        case "first_threat_blocked": return "First Threat Blocked"
        case "10_threats_blocked": return "10 Threats Blocked"
        case "100_threats_blocked": return "100 Threats Blocked"
        case "1000_threats_blocked": return "1000 Threats Blocked"
        default: return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func exportStatistics() {
        guard let data = statsManager.exportStatistics() else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "clipboard_guard_stats.json"
        panel.allowedContentTypes = [.json]

        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}