//
//  StatisticsManager.swift
//  Clipboard
//
//  Manages activity statistics with daily and monthly tracking
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

/// Represents a single day's activity statistics
struct DailyStatistics: Codable, Identifiable {
    let id = UUID()
    let date: Date
    var checksPerformed: Int
    var cryptoAddressesCopied: Int
    var safePastes: Int
    var threatsBlocked: Int
    var protectionActivations: Int
    var totalProtectionTime: TimeInterval // in seconds

    // Breakdown by crypto type
    var bitcoinCopies: Int
    var ethereumCopies: Int
    var solanaCopies: Int
    var otherCryptoCopies: Int // For litecoin, dogecoin, monero, etc.

    // Time-based metrics
    var peakActivityHour: Int? // 0-23
    var firstActivityTime: Date?
    var lastActivityTime: Date?

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.checksPerformed = 0
        self.cryptoAddressesCopied = 0
        self.safePastes = 0
        self.threatsBlocked = 0
        self.protectionActivations = 0
        self.totalProtectionTime = 0
        self.bitcoinCopies = 0
        self.ethereumCopies = 0
        self.solanaCopies = 0
        self.otherCryptoCopies = 0
    }
}

/// Aggregated monthly statistics
struct MonthlyStatistics: Codable {
    let month: Date // First day of month
    let dailyStats: [DailyStatistics]

    var totalChecks: Int {
        dailyStats.reduce(0) { $0 + $1.checksPerformed }
    }

    var totalCryptoAddresses: Int {
        dailyStats.reduce(0) { $0 + $1.cryptoAddressesCopied }
    }

    var totalSafePastes: Int {
        dailyStats.reduce(0) { $0 + $1.safePastes }
    }

    var totalThreatsBlocked: Int {
        dailyStats.reduce(0) { $0 + $1.threatsBlocked }
    }

    var totalProtectionTime: TimeInterval {
        dailyStats.reduce(0) { $0 + $1.totalProtectionTime }
    }

    var averageDailyChecks: Double {
        guard !dailyStats.isEmpty else { return 0 }
        return Double(totalChecks) / Double(dailyStats.count)
    }

    var mostActiveDay: DailyStatistics? {
        dailyStats.max { $0.checksPerformed < $1.checksPerformed }
    }

    var protectionRate: Double {
        guard totalCryptoAddresses > 0 else { return 0 }
        return Double(dailyStats.reduce(0) { $0 + $1.protectionActivations }) / Double(totalCryptoAddresses)
    }
}

/// Manages all application statistics with persistence
class StatisticsManager: ObservableObject {

    // MARK: - Published Properties

    @Published var todayStats: DailyStatistics
    @Published var yesterdayStats: DailyStatistics?
    @Published var weeklyStats: [DailyStatistics] = []
    @Published var currentMonthStats: MonthlyStatistics?
    @Published var allTimeStats: AllTimeStatistics

    // MARK: - Private Properties

    private let statsDirectory: URL
    private let allTimeStatsFile: URL
    private let saveQueue = DispatchQueue(label: "com.klip.stats", qos: .background)
    private var saveTimer: Timer?
    private var hourlyActivity: [Int: Int] = [:] // Hour -> Activity count

    // MARK: - All-Time Statistics

    struct AllTimeStatistics: Codable {
        var totalDaysActive: Int
        var totalChecks: Int
        var totalCryptoAddresses: Int
        var totalSafePastes: Int
        var totalThreatsBlocked: Int
        var totalProtectionTime: TimeInterval
        var firstUseDate: Date
        var lastResetDate: Date?

        var mostProductiveDay: Date?
        var mostProductiveDayCount: Int

        var longestStreak: Int
        var currentStreak: Int
        var lastActiveDate: Date?

        // Milestones
        var milestonesReached: [String: Date] // e.g., "100_threats_blocked": Date

        init() {
            self.totalDaysActive = 0
            self.totalChecks = 0
            self.totalCryptoAddresses = 0
            self.totalSafePastes = 0
            self.totalThreatsBlocked = 0
            self.totalProtectionTime = 0
            self.firstUseDate = Date()
            self.mostProductiveDayCount = 0
            self.longestStreak = 0
            self.currentStreak = 0
            self.milestonesReached = [:]
        }
    }

    // MARK: - Initialization

    init() {
        // Setup directories
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        self.statsDirectory = appSupport.appendingPathComponent("Klip/Statistics")
        self.allTimeStatsFile = statsDirectory.appendingPathComponent("all_time_stats.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: statsDirectory,
                                                 withIntermediateDirectories: true)

        // Load or initialize stats
        self.todayStats = DailyStatistics(date: Date())
        self.allTimeStats = AllTimeStatistics()

        loadStatistics()
        setupAutoSave()
        loadWeeklyStats()
        loadCurrentMonthStats()
    }

    // MARK: - Public Methods

    /// Records a clipboard check
    func recordCheck() {
        todayStats.checksPerformed += 1
        allTimeStats.totalChecks += 1

        // Track hourly activity
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyActivity[hour, default: 0] += 1
        updatePeakHour()

        // Update activity times
        if todayStats.firstActivityTime == nil {
            todayStats.firstActivityTime = Date()
        }
        todayStats.lastActivityTime = Date()
    }

    /// Records a crypto address copy event
    func recordCryptoCopy(type: CryptoType) {
        todayStats.cryptoAddressesCopied += 1
        allTimeStats.totalCryptoAddresses += 1

        // Track by type
        switch type {
        case .bitcoin:
            todayStats.bitcoinCopies += 1
        case .ethereum:
            todayStats.ethereumCopies += 1
        case .solana:
            todayStats.solanaCopies += 1
        case .litecoin, .dogecoin, .monero, .unknown:
            todayStats.otherCryptoCopies += 1
        }

        recordCheck() // Also counts as a check
    }

    /// Records a safe paste event
    func recordSafePaste() {
        todayStats.safePastes += 1
        allTimeStats.totalSafePastes += 1
    }

    /// Records a blocked threat
    func recordThreatBlocked() {
        todayStats.threatsBlocked += 1
        allTimeStats.totalThreatsBlocked += 1

        // Check milestones
        checkMilestones()
    }

    /// Records protection activation
    func recordProtectionActivation(duration: TimeInterval = 120) {
        todayStats.protectionActivations += 1
        todayStats.totalProtectionTime += duration
        allTimeStats.totalProtectionTime += duration
    }

    /// Gets statistics for a specific date range
    func getStatistics(from startDate: Date, to endDate: Date) -> [DailyStatistics] {
        var stats: [DailyStatistics] = []

        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            if let dailyStats = loadDailyStats(for: currentDate) {
                stats.append(dailyStats)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return stats
    }

    /// Exports statistics to JSON
    func exportStatistics() -> Data? {
        let exportData = [
            "today": todayStats,
            "week": weeklyStats,
            "currentMonth": currentMonthStats as Any,
            "allTime": allTimeStats
        ] as [String : Any]

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    /// Resets all statistics (with confirmation)
    func resetStatistics() {
        // Clear all saved files
        try? FileManager.default.removeItem(at: statsDirectory)
        try? FileManager.default.createDirectory(at: statsDirectory,
                                                 withIntermediateDirectories: true)

        // Reset in-memory stats
        todayStats = DailyStatistics(date: Date())
        yesterdayStats = nil
        weeklyStats = []
        currentMonthStats = nil
        allTimeStats = AllTimeStatistics()
        allTimeStats.lastResetDate = Date()

        saveStatistics()
    }

    // MARK: - Private Methods

    private func setupAutoSave() {
        // Save every 30 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.saveStatistics()
        }

        // Save on app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveOnTermination),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        // Check for date change
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkDateChange()
        }
    }

    @objc private func saveOnTermination() {
        saveStatistics()
    }

    private func checkDateChange() {
        let now = Date()
        let calendar = Calendar.current

        if !calendar.isDateInToday(todayStats.date) {
            // Save today's stats as yesterday
            saveStatistics()

            // Archive today's stats
            archiveDailyStats(todayStats)

            // Update yesterday reference
            yesterdayStats = todayStats

            // Start new day
            todayStats = DailyStatistics(date: now)
            hourlyActivity.removeAll()

            // Update streaks
            updateStreaks()

            // Reload weekly and monthly stats
            loadWeeklyStats()
            loadCurrentMonthStats()
        }
    }

    private func updatePeakHour() {
        if let (hour, _) = hourlyActivity.max(by: { $0.value < $1.value }) {
            todayStats.peakActivityHour = hour
        }
    }

    private func updateStreaks() {
        let calendar = Calendar.current

        // Update current streak
        if let lastActive = allTimeStats.lastActiveDate {
            let daysDiff = calendar.dateComponents([.day], from: lastActive, to: Date()).day ?? 0

            if daysDiff == 1 {
                // Consecutive day
                allTimeStats.currentStreak += 1
            } else if daysDiff > 1 {
                // Streak broken
                allTimeStats.currentStreak = 1
            }
            // If daysDiff == 0, same day, don't change streak
        } else {
            // First day
            allTimeStats.currentStreak = 1
        }

        // Update longest streak
        if allTimeStats.currentStreak > allTimeStats.longestStreak {
            allTimeStats.longestStreak = allTimeStats.currentStreak
        }

        allTimeStats.lastActiveDate = Date()
        allTimeStats.totalDaysActive += 1
    }

    private func checkMilestones() {
        let milestones = [
            (1, "first_threat_blocked"),
            (10, "10_threats_blocked"),
            (100, "100_threats_blocked"),
            (1000, "1000_threats_blocked")
        ]

        for (count, key) in milestones {
            if allTimeStats.totalThreatsBlocked == count &&
               allTimeStats.milestonesReached[key] == nil {
                allTimeStats.milestonesReached[key] = Date()
                print("🏆 Milestone reached: \(key)")
            }
        }
    }

    // MARK: - Persistence

    private func saveStatistics() {
        saveQueue.async {
            // Save today's stats
            self.saveDailyStats(self.todayStats)

            // Save all-time stats
            if let encoded = try? JSONEncoder().encode(self.allTimeStats) {
                try? encoded.write(to: self.allTimeStatsFile)
            }
        }
    }

    private func loadStatistics() {
        // Load today's stats
        if let loaded = loadDailyStats(for: Date()) {
            todayStats = loaded
        }

        // Load yesterday's stats
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           let loaded = loadDailyStats(for: yesterday) {
            yesterdayStats = loaded
        }

        // Load all-time stats
        if let data = try? Data(contentsOf: allTimeStatsFile),
           let decoded = try? JSONDecoder().decode(AllTimeStatistics.self, from: data) {
            allTimeStats = decoded
        }
    }

    private func saveDailyStats(_ stats: DailyStatistics) {
        let fileName = dailyStatsFileName(for: stats.date)
        let fileURL = statsDirectory.appendingPathComponent(fileName)

        if let encoded = try? JSONEncoder().encode(stats) {
            try? encoded.write(to: fileURL)
        }
    }

    private func loadDailyStats(for date: Date) -> DailyStatistics? {
        let fileName = dailyStatsFileName(for: date)
        let fileURL = statsDirectory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(DailyStatistics.self, from: data) else {
            return nil
        }

        return decoded
    }

    private func archiveDailyStats(_ stats: DailyStatistics) {
        saveDailyStats(stats)

        // Update most productive day
        if stats.checksPerformed > allTimeStats.mostProductiveDayCount {
            allTimeStats.mostProductiveDay = stats.date
            allTimeStats.mostProductiveDayCount = stats.checksPerformed
        }
    }

    private func dailyStatsFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "daily_\(formatter.string(from: date)).json"
    }

    private func loadWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        var stats: [DailyStatistics] = []

        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today),
               let dailyStats = loadDailyStats(for: date) {
                stats.append(dailyStats)
            }
        }

        weeklyStats = stats.reversed() // Oldest to newest
    }

    private func loadCurrentMonthStats() {
        let calendar = Calendar.current
        let now = Date()

        // Get first day of month
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return
        }

        // Load all days of current month
        var dailyStats: [DailyStatistics] = []
        var currentDate = monthStart

        while calendar.isDate(currentDate, equalTo: now, toGranularity: .month) {
            if let stats = loadDailyStats(for: currentDate) {
                dailyStats.append(stats)
            }
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDay
            } else {
                break
            }
        }

        currentMonthStats = MonthlyStatistics(month: monthStart, dailyStats: dailyStats)
    }
}