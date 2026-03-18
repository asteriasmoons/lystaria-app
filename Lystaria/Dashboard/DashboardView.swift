//
//  DashboardView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/11/26.
//

import SwiftUI
import SwiftData
import Foundation

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - Data Queries

    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var journalEntries: [JournalEntry]

    @Query(sort: \MoodLog.createdAt, order: .reverse)
    private var moodLogs: [MoodLog]


    @Query(sort: \HabitLog.dayStart, order: .reverse)
    private var habitLogs: [HabitLog]

    @Query(sort: \ReadingStats.updatedAt, order: .reverse)
    private var readingStats: [ReadingStats]

    @Query(sort: \DailyTarotRecord.updatedAt, order: .reverse)
    private var tarotRecords: [DailyTarotRecord]

    @Query(sort: \DailyHoroscopeRecord.updatedAt, order: .reverse)
    private var horoscopeRecords: [DailyHoroscopeRecord]


    @StateObject private var stepHealth = HealthKitManager.shared
    @StateObject private var waterHealth = WaterHealthKitManager.shared
    @StateObject private var onboarding = OnboardingManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("waterGoalFlOz") private var waterGoal: Double = 80
    @AppStorage("stepGoal") private var stepGoal: Double = 5000
    @EnvironmentObject private var appState: AppState

    @State private var showToolbox = false
    @State private var momentumRefreshID = UUID()
    @State private var moonPhaseData = MoonPhaseCalculator.calculate(for: Date())
    @State private var dashboardDayRefreshID = UUID()


    @State private var selectedZodiacSign: String = ""
    @State private var isFetchingHoroscope = false
    @State private var horoscopeError: String? = nil
    @State private var selectedHoroscopeTab: HoroscopeCardTab = .daily
    @State private var previewHoroscope: DailyHoroscope? = nil

    private var dashboardCalendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    private var startOfToday: Date {
        dashboardCalendar.startOfDay(for: Date())
    }

    private var startOfTomorrow: Date {
        dashboardCalendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
    }

    private func isToday(_ date: Date) -> Bool {
        dashboardCalendar.isDate(date, inSameDayAs: Date())
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = dashboardCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private let zodiacSigns = [
        "Aries", "Taurus", "Gemini", "Cancer",
        "Leo", "Virgo", "Libra", "Scorpio",
        "Sagittarius", "Capricorn", "Aquarius", "Pisces"
    ]

    enum HoroscopeCardTab: String, CaseIterable, Identifiable {
        case daily
        case picker

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily:
                return "Daily"
            case .picker:
                return "Explore"
            }
        }
    }

    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var currentReadingStats: ReadingStats? {
        guard let currentUserId else { return nil }
        let matches = readingStats.filter { $0.userId == currentUserId }
        return matches.max(by: { $0.updatedAt < $1.updatedAt })
    }

    private var currentDailyHoroscope: DailyHoroscope? {
        guard let record = horoscopeRecords.first(where: { $0.dayKey == todayKey }) else {
            return nil
        }

        return DailyHoroscope(
            sign: record.sign,
            message: record.message
        )
    }


    private func fetchDailyHoroscope() {
        guard !selectedZodiacSign.isEmpty else { return }

        if selectedHoroscopeTab == .daily,
           let existing = horoscopeRecords.first(where: { $0.dayKey == todayKey }),
           existing.sign.caseInsensitiveCompare(selectedZodiacSign) == .orderedSame,
           !existing.message.isEmpty {
            return
        }

        isFetchingHoroscope = true
        horoscopeError = nil

        Task {
            do {
                let horoscope = try await HoroscopeService.shared.fetchHoroscope(for: selectedZodiacSign)

                await MainActor.run {
                    if selectedHoroscopeTab == .daily {
                        if let existing = horoscopeRecords.first(where: { $0.dayKey == todayKey }) {
                            existing.sign = horoscope.sign
                            existing.message = horoscope.message
                            existing.updatedAt = Date()
                        } else {
                            let record = DailyHoroscopeRecord(
                                dayKey: todayKey,
                                sign: horoscope.sign,
                                message: horoscope.message
                            )
                            modelContext.insert(record)
                        }
                        try? modelContext.save()
                    } else {
                        previewHoroscope = horoscope
                    }
                    isFetchingHoroscope = false
                }
            } catch {
                await MainActor.run {
                    horoscopeError = "Couldn’t load horoscope right now."
                    isFetchingHoroscope = false
                }
            }
        }
    }

    private func clearPreviewHoroscope() {
        previewHoroscope = nil
        horoscopeError = nil
    }

    private var currentDailyTarotTip: DailyTarotTip? {
        guard let record = tarotRecords.first(where: { $0.dayKey == todayKey }) else {
            return nil
        }

        return DailyTarotTip(
            id: record.tipId,
            title: record.title,
            keywords: record.keywords,
            message: record.message
        )
    }

    private func drawDailyTarotTip() {
        guard currentDailyTarotTip == nil, !localDailyTarotTips.isEmpty else { return }
        guard let tip = localDailyTarotTips.randomElement() else { return }

        let record = DailyTarotRecord(
            dayKey: todayKey,
            tipId: tip.id,
            title: tip.title,
            keywords: tip.keywords,
            message: tip.message
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func refreshMomentumHealthData() {
        Task {
            await stepHealth.fetchTodaySteps()
            await waterHealth.fetchTodayWater()
        }
    }

    private func refreshMomentumCard() {
        momentumRefreshID = UUID()
    }

    private func refreshMoonPhaseData() {
        moonPhaseData = MoonPhaseCalculator.calculate(for: Date())
    }

    private func refreshForNewDay() {
        dashboardDayRefreshID = UUID()
        refreshMomentumHealthData()
        refreshMomentumCard()
        refreshMoonPhaseData()
    }


    // MARK: - System Activation Checks

    // NOTE:
    // These currently return false so the file compiles safely.
    // Replace the TODO sections with your real SwiftData / HealthKit queries.

    private var journaledToday: Bool {
        journalEntries.contains { isToday($0.createdAt) }
    }

    private var moodLoggedToday: Bool {
        moodLogs.contains { isToday($0.createdAt) }
    }

    private var habitCompletedToday: Bool {
        habitLogs.contains { log in
            log.count > 0 && isToday(log.dayStart)
        }
    }

    private var waterLoggedToday: Bool {
        waterHealth.todayWaterFlOz > 0
    }

    private var stepsLoggedToday: Bool {
        stepHealth.todaySteps > 0
    }

    private var readingLoggedToday: Bool {
        guard let lastCheckIn = currentReadingStats?.lastCheckInDate else { return false }
        return dashboardCalendar.isDate(lastCheckIn, inSameDayAs: Date())
    }


    private var activatedCount: Int {
        [
            journaledToday,
            moodLoggedToday,
            habitCompletedToday,
            waterLoggedToday,
            stepsLoggedToday,
            readingLoggedToday
        ]
        .filter { $0 }
        .count
    }

    private var moodDayAverages: [Date: Double] {
        let grouped = Dictionary(grouping: moodLogs) {
            dashboardCalendar.startOfDay(for: $0.createdAt)
        }

        return grouped.reduce(into: [Date: Double]()) { partial, pair in
            let scores = pair.value.map(\.score)
            guard !scores.isEmpty else { return }
            partial[pair.key] = scores.reduce(0, +) / Double(scores.count)
        }
    }

    private var journalDayStarts: Set<Date> {
        Set(journalEntries.map { dashboardCalendar.startOfDay(for: $0.createdAt) })
    }

    private var habitDayStarts: Set<Date> {
        Set(
            habitLogs
                .filter { $0.count > 0 }
                .map { dashboardCalendar.startOfDay(for: $0.dayStart) }
        )
    }

    private func averageMood(on days: Set<Date>) -> Double? {
        let matching = moodDayAverages.filter { days.contains($0.key) }.map(\.value)
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0, +) / Double(matching.count)
    }

    private func averageMood(on predicate: (Date) -> Bool) -> Double? {
        let matching = moodDayAverages.filter { predicate($0.key) }.map(\.value)
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0, +) / Double(matching.count)
    }

    private var journalMoodAverage: Double? {
        averageMood(on: journalDayStarts)
    }

    private var habitMoodAverage: Double? {
        averageMood(on: habitDayStarts)
    }

    private var waterGoalMoodAverage: Double? {
        averageMood { day in
            guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { return false }
            let total = waterHealth.totalWaterFlOz(from: day, to: nextDay) ?? 0
            return total >= waterGoal
        }
    }

    private var stepGoalMoodAverage: Double? {
        averageMood { day in
            guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { return false }
            let total = stepHealth.totalSteps(from: day, to: nextDay) ?? 0
            return total >= stepGoal
        }
    }

    private var wellnessInsights: [WellnessInsightItem] {
        var items: [WellnessInsightItem] = []

        if let avg = journalMoodAverage {
            items.append(
                WellnessInsightItem(
                    title: "Journal Days",
                    detail: "Your mood averages \(String(format: "%.1f", avg)) / 5 on days you journal."
                )
            )
        }

        if let avg = waterGoalMoodAverage {
            items.append(
                WellnessInsightItem(
                    title: "Hydrated Days",
                    detail: "Your mood averages \(String(format: "%.1f", avg)) / 5 on days you hit your water goal."
                )
            )
        }

        if let avg = stepGoalMoodAverage {
            items.append(
                WellnessInsightItem(
                    title: "Active Days",
                    detail: "Your mood averages \(String(format: "%.1f", avg)) / 5 on days you hit your step goal."
                )
            )
        }

        if let avg = habitMoodAverage {
            items.append(
                WellnessInsightItem(
                    title: "Habit Days",
                    detail: "Your mood averages \(String(format: "%.1f", avg)) / 5 on days you complete habits."
                )
            )
        }

        return Array(items.prefix(4))
    }

    private var last7DayStarts: [Date] {
        let today = dashboardCalendar.startOfDay(for: Date())

        return (0..<7)
            .compactMap { offset in
                dashboardCalendar.date(byAdding: .day, value: -offset, to: today)
            }
            .map { dashboardCalendar.startOfDay(for: $0) }
            .sorted()
    }

    private func activeDayCount(in activeDays: Set<Date>) -> Int {
        last7DayStarts.reduce(0) { partial, day in
            partial + (activeDays.contains(day) ? 1 : 0)
        }
    }

    private var readingDayStarts: Set<Date> {
        guard let stats = currentReadingStats else { return [] }

        let formatter = DateFormatter()
        formatter.calendar = dashboardCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let historyDates = stats.checkInHistory.compactMap { formatter.date(from: $0) }
        let normalizedHistoryDates = historyDates.map { dashboardCalendar.startOfDay(for: $0) }

        if !normalizedHistoryDates.isEmpty {
            return Set(normalizedHistoryDates)
        }

        guard let lastCheckInDate = stats.lastCheckInDate else { return [] }
        return [dashboardCalendar.startOfDay(for: lastCheckInDate)]
    }

    private var waterActiveDayStarts: Set<Date> {
        Set(
            last7DayStarts.filter { day in
                guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { return false }
                let total = waterHealth.totalWaterFlOz(from: day, to: nextDay) ?? 0
                return total > 0
            }
        )
    }

    private var stepActiveDayStarts: Set<Date> {
        Set(
            last7DayStarts.filter { day in
                guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { return false }
                let total = stepHealth.totalSteps(from: day, to: nextDay) ?? 0
                return total > 0
            }
        )
    }

    private func currentStreak(from activeDays: Set<Date>) -> Int {
        let today = dashboardCalendar.startOfDay(for: Date())
        let startDay: Date

        if activeDays.contains(today) {
            startDay = today
        } else if let yesterday = dashboardCalendar.date(byAdding: .day, value: -1, to: today),
                  activeDays.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startDay

        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = dashboardCalendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private var moodDayStarts: Set<Date> {
        Set(moodLogs.map { dashboardCalendar.startOfDay(for: $0.createdAt) })
    }

    private var journalCurrentStreak: Int {
        currentStreak(from: journalDayStarts)
    }

    private var moodCurrentStreak: Int {
        currentStreak(from: moodDayStarts)
    }

    private var habitCurrentStreak: Int {
        currentStreak(from: habitDayStarts)
    }

    private var waterCurrentStreak: Int {
        currentStreak(from: waterActiveDayStarts)
    }

    private var stepCurrentStreak: Int {
        currentStreak(from: stepActiveDayStarts)
    }

    private var readingCurrentStreak: Int {
        currentReadingStats?.streakDays ?? 0
    }

    private var consistencyAreaScores: [ConsistencyAreaScore] {
        [
            ConsistencyAreaScore(title: "Journaling", activeDays: activeDayCount(in: journalDayStarts)),
            ConsistencyAreaScore(title: "Mood", activeDays: activeDayCount(in: moodDayStarts)),
            ConsistencyAreaScore(title: "Habits", activeDays: activeDayCount(in: habitDayStarts)),
            ConsistencyAreaScore(title: "Water Tracking", activeDays: activeDayCount(in: waterActiveDayStarts)),
            ConsistencyAreaScore(title: "Steps", activeDays: activeDayCount(in: stepActiveDayStarts)),
            ConsistencyAreaScore(title: "Reading", activeDays: activeDayCount(in: readingDayStarts))
        ]
    }

    private var mostConsistentArea: ConsistencyAreaScore? {
        consistencyAreaScores.max { lhs, rhs in
            if lhs.activeDays == rhs.activeDays {
                return lhs.title > rhs.title
            }
            return lhs.activeDays < rhs.activeDays
        }
    }

    private var leastActiveArea: ConsistencyAreaScore? {
        consistencyAreaScores.min { lhs, rhs in
            if lhs.activeDays == rhs.activeDays {
                return lhs.title > rhs.title
            }
            return lhs.activeDays < rhs.activeDays
        }
    }

    private var strongestStreakItem: ConsistencyStreakItem? {
        let streaks = [
            ConsistencyStreakItem(title: "Journaling", streakDays: journalCurrentStreak),
            ConsistencyStreakItem(title: "Mood", streakDays: moodCurrentStreak),
            ConsistencyStreakItem(title: "Habits", streakDays: habitCurrentStreak),
            ConsistencyStreakItem(title: "Water Tracking", streakDays: waterCurrentStreak),
            ConsistencyStreakItem(title: "Steps", streakDays: stepCurrentStreak),
            ConsistencyStreakItem(title: "Reading", streakDays: readingCurrentStreak)
        ]
        .filter { $0.streakDays > 0 }

        return streaks.max { lhs, rhs in
            if lhs.streakDays == rhs.streakDays {
                return lhs.title > rhs.title
            }
            return lhs.streakDays < rhs.streakDays
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            header

                            Rectangle()
                                .fill(LColors.glassBorder)
                                .frame(height: 1)

                            DashboardMoonPhaseCard(data: moonPhaseData)

                            DailyMomentumCard(
                                activatedCount: activatedCount,
                                totalCount: 6,
                                items: [
                                    .init(title: "Journal", systemImage: "notesfill", isActive: journaledToday),
                                    .init(title: "Mood", systemImage: "facefill", isActive: moodLoggedToday),
                                    .init(title: "Habits", systemImage: "goalsparkle", isActive: habitCompletedToday),
                                    .init(title: "Water", systemImage: "dropfill", isActive: waterLoggedToday),
                                    .init(title: "Steps", systemImage: "shoefill", isActive: stepsLoggedToday),
                                    .init(title: "Reading", systemImage: "sparklebook", isActive: readingLoggedToday)
                                ]
                            )
                            .id(momentumRefreshID)

                            DashboardTarotCard(
                                tip: currentDailyTarotTip,
                                onDraw: drawDailyTarotTip
                            )

                            horoscopeCard

                            DashboardConsistencyCard(
                                mostConsistent: mostConsistentArea,
                                needsAttention: leastActiveArea,
                                strongestStreak: strongestStreakItem,
                                leastActiveThisWeek: leastActiveArea
                            )
                            .id(dashboardDayRefreshID)

                            WellnessWallCard(items: wellnessInsights)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: max(proxy.size.width - (LSpacing.pageHorizontal * 2), 0), alignment: .topLeading)
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.top, 14)
                        .padding(.bottom, 120)
                    }
                    .clipped()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showToolbox) {
                ToolboxView()
            }
            // MARK: - REFRESH MOMENTUM CARD HELPERS
            .onAppear {
                refreshForNewDay()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshForNewDay()
                }
            }


            .onChange(of: journalEntries.count) { _, _ in
                refreshMomentumCard()
            }
            .onChange(of: moodLogs.count) { _, _ in
                refreshMomentumCard()
            }
            .onChange(of: habitLogs.count) { _, _ in
                refreshMomentumCard()
            }
            .onChange(of: readingCurrentStreak) { _, _ in
                refreshMomentumCard()
            }
            .onChange(of: readingLoggedToday) { _, _ in
                refreshMomentumCard()
            }
            .onChange(of: selectedZodiacSign) { _, _ in
                if selectedHoroscopeTab == .picker {
                    previewHoroscope = nil
                    horoscopeError = nil
                }
            }
            .onReceive(stepHealth.$todaySteps) { _ in
                refreshMomentumCard()
            }
            .onReceive(waterHealth.$todayWaterFlOz) { _ in
                refreshMomentumCard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshForNewDay()
            }
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                ZStack {
                    OnboardingOverlay(anchors: anchors)
                        .environmentObject(onboarding)
                }
                .task(id: anchors.count) {
                    if anchors.count > 0 {
                        onboarding.start(page: OnboardingPages.dashboard)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "Dashboard", font: .title.bold())
            Spacer()

            HStack(spacing: 10) {
                NavigationLink {
                    HealthPageView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("healthfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showToolbox = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("pausefill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                }
                .onboardingTarget("toolboxIcon")
                .buttonStyle(.plain)
            }
        }
    }

    private var horoscopeCard: some View {
        DashboardHoroscopeCard(
            selectedTab: $selectedHoroscopeTab,
            selectedSign: $selectedZodiacSign,
            zodiacSigns: zodiacSigns,
            dailyHoroscope: currentDailyHoroscope,
            previewHoroscope: previewHoroscope,
            isLoading: isFetchingHoroscope,
            errorText: horoscopeError,
            onFetch: fetchDailyHoroscope,
            onClearPreview: clearPreviewHoroscope
        )
    }
}

private struct DashboardMoonPhaseCard: View {
    let data: MoonPhaseData

    private var zodiacAssetName: String {
        switch data.signName.lowercased() {
        case "aries": return "ariesfill"
        case "taurus": return "taurusfill"
        case "gemini": return "geminifill"
        case "cancer": return "cancerfill"
        case "leo": return "leofill"
        case "virgo": return "virgofill"
        case "libra": return "librafill"
        case "scorpio": return "scorpiofill"
        case "sagittarius": return "sagittariusfill"
        case "capricorn": return "capricornfill"
        case "aquarius": return "aquariusfill"
        case "pisces": return "piscesfill"
        default: return "ariesfill"
        }
    }

    private var phaseSymbolName: String {
        switch data.phaseName.lowercased() {
        case "new moon":
            return "moonphase.new.moon"
        case "waxing crescent":
            return "moonphase.waxing.crescent"
        case "first quarter":
            return "moonphase.first.quarter"
        case "waxing gibbous":
            return "moonphase.waxing.gibbous"
        case "full moon":
            return "moonphase.full.moon"
        case "waning gibbous":
            return "moonphase.waning.gibbous"
        case "last quarter":
            return "moonphase.last.quarter"
        case "waning crescent":
            return "moonphase.waning.crescent"
        default:
            return "moonphase.full.moon"
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    GradientTitle(text: "Moon Phase", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: phaseSymbolName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)

                            Text(data.phaseName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            Image(zodiacAssetName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.white)
                                .opacity(1)

                            Text(data.signName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(data.detailLine)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct DashboardHoroscopeCard: View {
    @Binding var selectedTab: DashboardView.HoroscopeCardTab
    @Binding var selectedSign: String
    let zodiacSigns: [String]
    let dailyHoroscope: DailyHoroscope?
    let previewHoroscope: DailyHoroscope?
    let isLoading: Bool
    let errorText: String?
    let onFetch: () -> Void
    let onClearPreview: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("planetfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Daily Astrology", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                horoscopeTabs

                if selectedTab == DashboardView.HoroscopeCardTab.daily {
                    dailyTabContent
                } else {
                    exploreTabContent
                }
            }
        }
    }

    private var horoscopeTabs: some View {
        HStack(spacing: 10) {
            ForEach(DashboardView.HoroscopeCardTab.allCases) { tab in
                horoscopeTabButton(for: tab)
            }
        }
    }

    private func horoscopeTabButton(for tab: DashboardView.HoroscopeCardTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.28) : LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dailyTabContent: some View {
        if let horoscope = dailyHoroscope {
            horoscopeDisplay(horoscope)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose your zodiac sign once to lock in today’s horoscope.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                pickerField
                fetchButton(title: "Get Daily Horoscope")

                if let errorText {
                    errorTextView(errorText)
                }
            }
        }
    }

    @ViewBuilder
    private var exploreTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            pickerField
            fetchButton(title: "Preview Horoscope")

            if let horoscope = previewHoroscope {
                horoscopeDisplay(horoscope)

                Button {
                    onClearPreview()
                } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if let errorText {
                errorTextView(errorText)
            }
        }
    }

    private var pickerField: some View {
        Menu {
            ForEach(zodiacSigns, id: \.self) { sign in
                Button(sign) {
                    selectedSign = sign
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(selectedSign.isEmpty ? "Select Zodiac Sign" : selectedSign)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image("chevrondownfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
                    .opacity(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }

    private func fetchButton(title: String) -> some View {
        Button {
            onFetch()
        } label: {
            HStack {
                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .background(LGradients.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selectedSign.isEmpty || isLoading)
    }

    private func horoscopeDisplay(_ horoscope: DailyHoroscope) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(horoscope.sign)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(horoscope.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorTextView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.red.opacity(0.9))
    }
}

private struct DashboardTarotCard: View {
    let tip: DailyTarotTip?
    let onDraw: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("crystalballfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Daily Tarot", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                if let tip {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tip.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        if !tip.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("KEYWORDS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                FlexibleKeywordWrap(keywords: tip.keywords)
                            }
                        }

                        Text(tip.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pull one locked daily tarot tip for today.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        Button {
                            onDraw()
                        } label: {
                            Text("Get Daily Tip")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(LGradients.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FlexibleKeywordWrap: View {
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedKeywords, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { keyword in
                        ZStack {
                            Text(keyword)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LGradients.blue)
                                .offset(x: 0.6, y: 0)

                            Text(keyword)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LGradients.blue)
                                .offset(x: -0.6, y: 0)

                            Text(keyword)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LGradients.blue)
                                .offset(x: 0, y: 0.6)

                            Text(keyword)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LGradients.blue)
                                .offset(x: 0, y: -0.6)

                            Text(keyword)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LGradients.blue, lineWidth: 1)
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunkedKeywords: [[String]] {
        stride(from: 0, to: keywords.count, by: 3).map {
            Array(keywords[$0..<min($0 + 3, keywords.count)])
        }
    }
}

private struct ConsistencyAreaScore: Identifiable {
    let id = UUID()
    let title: String
    let activeDays: Int
}

private struct ConsistencyStreakItem {
    let title: String
    let streakDays: Int
}

private struct DashboardConsistencyCard: View {
    let mostConsistent: ConsistencyAreaScore?
    let needsAttention: ConsistencyAreaScore?
    let strongestStreak: ConsistencyStreakItem?
    let leastActiveThisWeek: ConsistencyAreaScore?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("balancefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Consistency Check", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                HStack(spacing: 10) {
                    consistencyBubble(
                        label: "MOST CONSISTENT",
                        title: mostConsistent?.title ?? "Not enough data",
                        value: mostConsistent.map { "\($0.activeDays) / 7 days" } ?? ""
                    )

                    consistencyBubble(
                        label: "NEEDS ATTENTION",
                        title: needsAttention?.title ?? "Not enough data",
                        value: needsAttention.map { "\($0.activeDays) / 7 days" } ?? ""
                    )
                }

                VStack(spacing: 10) {
                    detailRow(
                        label: "STRONGEST STREAK",
                        value: strongestStreak.map { "\($0.title) — \($0.streakDays) day\($0.streakDays == 1 ? "" : "s")" } ?? "Not enough data"
                    )

                    detailRow(
                        label: "LEAST ACTIVE THIS WEEK",
                        value: leastActiveThisWeek.map { "\($0.title) — \($0.activeDays) / 7 days" } ?? "Not enough data"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func consistencyBubble(label: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

private struct WellnessInsightItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct DailyMomentumItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let isActive: Bool
}

private struct DailyMomentumCard: View {
    let activatedCount: Int
    let totalCount: Int
    let items: [DailyMomentumItem]

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(activatedCount) / Double(totalCount)
    }

    private var footerText: String {
        switch activatedCount {
        case 0:
            return "A fresh start. Touch one system to begin your momentum."
        case totalCount:
            return "All systems activated today. Your momentum is glowing."
        default:
            return "\(totalCount - activatedCount) more \((totalCount - activatedCount) == 1 ? "system" : "systems") to activate today."
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("boltsparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Daily Momentum", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(activatedCount) / \(totalCount)")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)

                    Text("systems activated today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                GlassProgressBar(progress: progress, height: 10)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(items) { item in
                        momentumBubble(item)
                    }
                }

                Text(footerText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func momentumBubble(_ item: DailyMomentumItem) -> some View {
        VStack(spacing: 8) {
            Image(item.systemImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(.white)
                .opacity(1)

            Text(item.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            item.isActive
            ? AnyShapeStyle(LGradients.blue)
            : AnyShapeStyle(Color.white.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
        .shadow(
            color: item.isActive ? LColors.accent.opacity(0.20) : .clear,
            radius: 8,
            y: 4
        )
    }
}

private struct WellnessWallCard: View {
    let items: [WellnessInsightItem]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("mindfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Wellness Wall", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                Text("Patterns between mood, journaling, habits, water, and movement.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not enough data yet")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Log more mood, journal, habit, water, and step data to unlock wellness relationship insights.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            insightRow(item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func insightRow(_ item: WellnessInsightItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(item.detail)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
