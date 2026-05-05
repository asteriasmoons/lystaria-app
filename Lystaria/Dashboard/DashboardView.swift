//
//  DashboardView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/11/26.
//


import SwiftUI
import SwiftData
import Foundation

struct DailyLenormandTip: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let keywords: [String]
    let message: String
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var limits = LimitManager.shared

    // MARK: - Data Queries

    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var journalEntries: [JournalEntry]


    @Query(sort: \MoodLog.createdAt, order: .reverse)
    private var moodLogs: [MoodLog]

    @Query(sort: \ChecklistItem.updatedAt, order: .reverse)
    private var checklistItems: [ChecklistItem]

    @Query(sort: \LystariaReminder.updatedAt, order: .reverse)
    private var reminders: [LystariaReminder]

    @Query(sort: \CalendarEvent.updatedAt, order: .reverse)
    private var calendarEvents: [CalendarEvent]

    @Query(sort: \DailyIntention.updatedAt, order: .reverse)
    private var dailyIntentions: [DailyIntention]

    @Query(sort: \ExerciseLogEntry.createdAt, order: .reverse)
    private var exerciseLogs: [ExerciseLogEntry]

    @Query(sort: \HealthMetricEntry.createdAt, order: .reverse)
    private var healthMetricEntries: [HealthMetricEntry]


    @Query(sort: \HabitLog.dayStart, order: .reverse)
    private var habitLogs: [HabitLog]

    @Query(sort: \Habit.createdAt, order: .forward)
    private var habits: [Habit]


    @Query(sort: \ReadingStats.updatedAt, order: .reverse)
    private var readingStats: [ReadingStats]

    @Query(sort: \SelfCarePointsProfile.updatedAt, order: .reverse)
    private var selfCareProfiles: [SelfCarePointsProfile]

    @Query(sort: \DailyTarotRecord.updatedAt, order: .reverse)
    private var tarotRecords: [DailyTarotRecord]

    @Query(sort: \DailyLenormandRecord.updatedAt, order: .reverse)
    private var lenormandRecords: [DailyLenormandRecord]

    @Query(sort: \DailyHoroscopeRecord.updatedAt, order: .reverse)
    private var horoscopeRecords: [DailyHoroscopeRecord]


    @StateObject private var stepHealth = HealthKitManager.shared
    @StateObject private var waterHealth = WaterHealthKitManager.shared
    @StateObject private var onboarding = OnboardingManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("waterGoalFlOz") private var waterGoal: Double = 80
    @Query(
        filter: #Predicate<DailyCompletionSettings> { $0.key == "default" }
    ) private var completionSettingsResults: [DailyCompletionSettings]
    private var stepGoal: Double {
        completionSettingsResults.first?.stepGoal ?? 5000
    }
    @EnvironmentObject private var appState: AppState

    @State private var showToolbox = false
    @State private var showSelfCarePointsPage = false
    @State private var showMoonPhaseDetails = false
    @State private var momentumRefreshID = UUID()
    @State private var moonPhaseData = MoonPhaseCalculator.calculate(for: Date())
    @State private var dashboardDayRefreshID = UUID()
    @State private var consistencyRefreshID = UUID()
    @State private var dashboardSupportRefreshID = UUID()


    @State private var selectedZodiacSign: String = ""
    @State private var isFetchingHoroscope = false
    @State private var horoscopeError: String? = nil
    @State private var selectedHoroscopeTab: HoroscopeCardTab = .daily
    @State private var previewHoroscope: DailyHoroscope? = nil

    @State private var waterGoalMoodAverageValue: Double? = nil
    @State private var stepGoalMoodAverageValue: Double? = nil
    @State private var waterGoalMoodSummary: MoodDimensionSummary?
    @State private var stepGoalMoodSummary: MoodDimensionSummary?
    @State private var waterActiveDayStartsCache: Set<Date> = []
    @State private var stepActiveDayStartsCache: Set<Date> = []

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

    private var isSelfCareDashboardLocked: Bool {
        !limits.canAccess(.dashboardSelfCareCard)
    }

    private var isDailyBalanceLocked: Bool {
        !limits.canAccess(.dashboardDailyBalanceCard)
    }

    private var isDailyTarotLocked: Bool {
        !limits.canAccess(.dashboardDailyTarotCard)
    }

    private var isWellnessWallLocked: Bool {
        !limits.canAccess(.dashboardWellnessWallCard)
    }


    private var currentReadingStats: ReadingStats? {
        guard let currentUserId else { return nil }
        let matches = readingStats.filter { $0.userId == currentUserId }
        return matches.max(by: { $0.updatedAt < $1.updatedAt })
    }

    private var activeSelfCareUserId: String? {
        try? SelfCarePointsManager.resolveActiveUserId(in: modelContext)
    }

    private var currentSelfCareProfile: SelfCarePointsProfile? {
        guard let activeSelfCareUserId else { return nil }
        return selfCareProfiles.first { $0.userId == activeSelfCareUserId }
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

    private var currentDailyLenormandTip: DailyLenormandTip? {
        guard let record = lenormandRecords.first(where: { $0.dayKey == todayKey }) else {
            return nil
        }

        return DailyLenormandTip(
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

    private func drawDailyLenormandTip() {
        guard currentDailyLenormandTip == nil, !localDailyLenormandTips.isEmpty else { return }
        guard let tip = localDailyLenormandTips.randomElement() else { return }

        let record = DailyLenormandRecord(
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

    private func refreshConsistencyCard() {
        consistencyRefreshID = UUID()
    }

    private func refreshDashboardSupportCards() {
        dashboardSupportRefreshID = UUID()
    }

    private func refreshMoonPhaseData() {
        moonPhaseData = MoonPhaseCalculator.calculate(for: Date())
    }

    private func refreshForNewDay() {
        dashboardDayRefreshID = UUID()
        refreshConsistencyCard()
        refreshDashboardSupportCards()
        refreshMomentumHealthData()
        refreshMomentumCard()
        refreshMoonPhaseData()
    }


    // MARK: - System Activation Checks

    // NOTE:
    // These currently return false so the file compiles safely.
    // Replace the TODO sections with your real SwiftData / HealthKit queries.


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


    private var todayDailyIntention: DailyIntention? {
        dailyIntentions.first { $0.dateKey == todayKey }
    }

    private var hasDailyIntentionToday: Bool {
        guard let intention = todayDailyIntention else { return false }
        return !intention.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var exercisedToday: Bool {
        exerciseLogs.contains { isToday($0.date) }
    }

    private var loggedHealthMetricsToday: Bool {
        healthMetricEntries.contains { isToday($0.date) }
    }

    private var hasEventToday: Bool {
        calendarEvents.contains { eventOccursToday($0) }
    }

    private var dueTodayReminders: [LystariaReminder] {
        reminders.filter { reminder in
            reminder.status != .deleted && dashboardCalendar.isDate(reminder.nextRunAt, inSameDayAs: Date())
        }
    }

    private var hasReminderToday: Bool {
        !dueTodayReminders.isEmpty
    }

    private var completedChecklistItemsTodayCount: Int {
        checklistItems.filter { item in
            guard item.isCompleted, let completedAt = item.completedAt else { return false }
            return isToday(completedAt)
        }.count
    }

    private var checklistCompletionProgressToday: Double {
        let totalChecklistItemCount = checklistItems.count
        guard totalChecklistItemCount > 0 else { return 0 }
        return min(Double(completedChecklistItemsTodayCount) / Double(totalChecklistItemCount), 1.0)
    }

    private func reminderCompletedToday(_ reminder: LystariaReminder) -> Bool {
        if let lastRunAt = reminder.lastRunAt,
           dashboardCalendar.isDate(lastRunAt, inSameDayAs: Date()) {
            return true
        }

        if let acknowledgedAt = reminder.acknowledgedAt,
           dashboardCalendar.isDate(acknowledgedAt, inSameDayAs: Date()) {
            return true
        }

        return false
    }

    private var remindersRelevantToTodayCompletion: [LystariaReminder] {
        reminders.filter { reminder in
            reminder.status != .deleted &&
            dashboardCalendar.isDate(reminder.nextRunAt, inSameDayAs: Date())
        }
    }

    private var completedDueTodayRemindersCount: Int {
        remindersRelevantToTodayCompletion.filter { reminderCompletedToday($0) }.count
    }

    private var reminderCompletionProgressToday: Double {
        guard !remindersRelevantToTodayCompletion.isEmpty else { return 0 }
        return min(Double(completedDueTodayRemindersCount) / Double(remindersRelevantToTodayCompletion.count), 1.0)
    }

    private var stepProgressToday: Double {
        guard stepGoal > 0 else { return stepsLoggedToday ? 1.0 : 0.0 }
        return min(stepHealth.todaySteps / stepGoal, 1.0)
    }

    private var waterProgressToday: Double {
        guard waterGoal > 0 else { return waterLoggedToday ? 1.0 : 0.0 }
        return min(waterHealth.todayWaterFlOz / waterGoal, 1.0)
    }

    private func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func eventOccursToday(_ event: CalendarEvent) -> Bool {
        if dashboardCalendar.isDate(event.startDate, inSameDayAs: Date()) {
            return true
        }

        guard let endDate = event.endDate else { return false }

        return startOfToday >= dashboardCalendar.startOfDay(for: event.startDate)
            && startOfToday <= dashboardCalendar.startOfDay(for: endDate)
    }

    private var movementBalanceScore: Double {
        clampedPercent((stepProgressToday * 0.7) + ((exercisedToday ? 1.0 : 0.0) * 0.3))
    }

    private var reflectionBalanceScore: Double {
        let journalValue = journaledToday ? 1.0 : 0.0
        let moodValue = moodLoggedToday ? 1.0 : 0.0
        let intentionValue = hasDailyIntentionToday ? 1.0 : 0.0
        return clampedPercent((journalValue + moodValue + intentionValue) / 3.0)
    }

    private var careBalanceScore: Double {
        clampedPercent((waterProgressToday * 0.7) + ((loggedHealthMetricsToday ? 1.0 : 0.0) * 0.3))
    }

    private var planningBalanceScore: Double {
        let eventValue = hasEventToday ? 1.0 : 0.0
        let reminderValue = hasReminderToday ? 1.0 : 0.0
        let intentionValue = hasDailyIntentionToday ? 1.0 : 0.0
        return clampedPercent((eventValue + reminderValue + intentionValue) / 3.0)
    }

    private var completionBalanceScore: Double {
        let checklistValue = checklistCompletionProgressToday
        let habitValue = habitCompletionProgressToday
        let reminderValue = reminderCompletionProgressToday
        return clampedPercent((checklistValue + habitValue + reminderValue) / 3.0)
    }

    private var dailyBalanceItems: [DailyBalanceItem] {
        [
            DailyBalanceItem(
                title: "Movement",
                detail: "Steps + exercise",
                progress: movementBalanceScore
            ),
            DailyBalanceItem(
                title: "Reflection",
                detail: "Journal + mood + intention",
                progress: reflectionBalanceScore
            ),
            DailyBalanceItem(
                title: "Care",
                detail: "Water + health metrics",
                progress: careBalanceScore
            ),
            DailyBalanceItem(
                title: "Planning",
                detail: "Events + reminders + intention",
                progress: planningBalanceScore
            ),
            DailyBalanceItem(
                title: "Completion",
                detail: "Checklist + habits + reminders",
                progress: completionBalanceScore
            )
        ]
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

    private var dailyMomentumItems: [DailyMomentumItem] {
        [
            DailyMomentumItem(title: "Journal", systemImage: "notesfill", isActive: journaledToday),
            DailyMomentumItem(title: "Mood", systemImage: "facefill", isActive: moodLoggedToday),
            DailyMomentumItem(title: "Habits", systemImage: "goalsparkle", isActive: habitCompletedToday),
            DailyMomentumItem(title: "Water", systemImage: "dropfill", isActive: waterLoggedToday),
            DailyMomentumItem(title: "Steps", systemImage: "shoefill", isActive: stepsLoggedToday),
            DailyMomentumItem(title: "Reading", systemImage: "sparklebook", isActive: readingLoggedToday)
        ]
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

    private struct MoodDimensionSummary {
        let averageScore: Double
        let averageTone: Double
        let averageIntensity: Double
    }

    private var moodDayToneAverages: [Date: Double] {
        let grouped = Dictionary(grouping: moodLogs) {
            dashboardCalendar.startOfDay(for: $0.createdAt)
        }

        return grouped.reduce(into: [Date: Double]()) { partial, pair in
            let values = pair.value.map(\.valence)
            guard !values.isEmpty else { return }
            partial[pair.key] = values.reduce(0, +) / Double(values.count)
        }
    }

    private var moodDayIntensityAverages: [Date: Double] {
        let grouped = Dictionary(grouping: moodLogs) {
            dashboardCalendar.startOfDay(for: $0.createdAt)
        }

        return grouped.reduce(into: [Date: Double]()) { partial, pair in
            let values = pair.value.map(\.intensity)
            guard !values.isEmpty else { return }
            partial[pair.key] = values.reduce(0, +) / Double(values.count)
        }
    }

    private func moodSummary(on days: Set<Date>) -> MoodDimensionSummary? {
        let normalizedDays = Set(days.map { dashboardCalendar.startOfDay(for: $0) })
        let matchingScores = moodDayAverages
            .filter { normalizedDays.contains(dashboardCalendar.startOfDay(for: $0.key)) }
            .map(\.value)

        guard !matchingScores.isEmpty else { return nil }

        let matchingTones = moodDayToneAverages
            .filter { normalizedDays.contains(dashboardCalendar.startOfDay(for: $0.key)) }
            .map(\.value)

        let matchingIntensities = moodDayIntensityAverages
            .filter { normalizedDays.contains(dashboardCalendar.startOfDay(for: $0.key)) }
            .map(\.value)

        let averageScore = matchingScores.reduce(0, +) / Double(matchingScores.count)
        let averageTone = matchingTones.isEmpty ? 0 : matchingTones.reduce(0, +) / Double(matchingTones.count)
        let averageIntensity = matchingIntensities.isEmpty ? 0 : matchingIntensities.reduce(0, +) / Double(matchingIntensities.count)

        return MoodDimensionSummary(
            averageScore: averageScore,
            averageTone: averageTone,
            averageIntensity: averageIntensity
        )
    }

    private func toneLabel(for value: Double) -> String {
        switch value {
        case 0.35...:
            return "leans positive"
        case ...(-0.35):
            return "leans heavier"
        default:
            return "feels balanced"
        }
    }

    private func intensityLabel(for value: Double) -> String {
        switch value {
        case 0..<2:
            return "low intensity"
        case 2..<3.5:
            return "moderate intensity"
        default:
            return "high intensity"
        }
    }

    private func wellnessInsightDetail(prefix: String, summary: MoodDimensionSummary) -> String {
        "Your mood averages \(String(format: "%.1f", summary.averageScore)) / 5 on \(prefix), with emotional tone that \(toneLabel(for: summary.averageTone)) and \(intensityLabel(for: summary.averageIntensity))."
    }

    private var journalDayStarts: Set<Date> {
        Set(
            journalEntries
                .filter { $0.deletedAt == nil }
                .map { dashboardCalendar.startOfDay(for: $0.createdAt) }
        )
    }

    private var journaledToday: Bool {
        journalDayStarts.contains(dashboardCalendar.startOfDay(for: Date()))
    }

    // MARK: - Wellness Wall AI

    @Query(sort: \WellnessWallAIInsight.dayStart, order: .reverse) private var wellnessWallAIInsights: [WellnessWallAIInsight]

    @State private var aiWellnessInsights: [WellnessInsightItem]?
    @State private var isRefreshingWellnessAI = false

    private func habitResetMoment(for habit: Habit) -> Date? {
        habit.statsResetAt
    }

    private func habitTarget(for habit: Habit) -> Int {
        max(1, habit.timesPerDay)
    }

    private func includeHabitLogInCurrentStats(_ log: HabitLog, for habit: Habit) -> Bool {
        guard let resetMoment = habitResetMoment(for: habit) else { return true }

        let resetDay = dashboardCalendar.startOfDay(for: resetMoment)
        let logDay = dashboardCalendar.startOfDay(for: log.dayStart)

        if logDay > resetDay { return true }
        if logDay < resetDay { return false }
        return log.createdAt >= resetMoment
    }

    private func includeHabitSkipInCurrentStats(_ skip: HabitSkip, for habit: Habit) -> Bool {
        guard let resetMoment = habitResetMoment(for: habit) else { return true }

        let resetDay = dashboardCalendar.startOfDay(for: resetMoment)
        let skipDay = dashboardCalendar.startOfDay(for: skip.dayStart)

        if skipDay > resetDay { return true }
        if skipDay < resetDay { return false }
        return skip.createdAt >= resetMoment
    }

    private func habitCompletedDayStarts(for habit: Habit) -> Set<Date> {
        let target = habitTarget(for: habit)

        return Set((habit.logs ?? [])
            .filter { log in
                guard log.count >= target else { return false }
                return includeHabitLogInCurrentStats(log, for: habit)
            }
            .map { dashboardCalendar.startOfDay(for: $0.dayStart) })
    }

    private func habitSkippedDayStarts(for habit: Habit) -> Set<Date> {
        Set((habit.skips ?? [])
            .filter { skip in
                includeHabitSkipInCurrentStats(skip, for: habit)
            }
            .map { dashboardCalendar.startOfDay(for: $0.dayStart) })
    }

    private func isHabitCompletedDay(_ dayStart: Date, for habit: Habit) -> Bool {
        habitCompletedDayStarts(for: habit).contains(dashboardCalendar.startOfDay(for: dayStart))
    }

    private func isHabitSkippedDay(_ dayStart: Date, for habit: Habit) -> Bool {
        habitSkippedDayStarts(for: habit).contains(dashboardCalendar.startOfDay(for: dayStart))
    }

    private func habitDailyStreak(for habit: Habit) -> Int {
        var cursor = dashboardCalendar.startOfDay(for: Date())

        if !isHabitCompletedDay(cursor, for: habit) && !isHabitSkippedDay(cursor, for: habit) {
            cursor = dashboardCalendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0

        while true {
            if isHabitCompletedDay(cursor, for: habit) {
                streak += 1
            } else if isHabitSkippedDay(cursor, for: habit) {
                // skipped days protect the streak without incrementing it
            } else {
                break
            }

            guard let previous = dashboardCalendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private var habitDayStarts: Set<Date> {
        let activeHabits = habits.filter { !$0.isArchived }

        return Set(
            activeHabits.flatMap { habit in
                habitCompletedDayStarts(for: habit)
            }
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
        waterGoalMoodAverageValue
    }

    private var stepGoalMoodAverage: Double? {
        stepGoalMoodAverageValue
    }

    private var journalMoodSummary: MoodDimensionSummary? {
        moodSummary(on: journalDayStarts)
    }

    private var habitMoodSummary: MoodDimensionSummary? {
        moodSummary(on: habitDayStarts)
    }

    private var todaysJournalEntries: [JournalEntry] {
        journalEntries.filter {
            $0.deletedAt == nil && dashboardCalendar.isDate($0.createdAt, inSameDayAs: Date())
        }
    }

    private var todaysJournalTagCounts: [(tag: String, count: Int)] {
        let normalizedTags = todaysJournalEntries
            .flatMap { $0.tags }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }

        let counts = Dictionary(grouping: normalizedTags, by: { $0 })
            .map { (tag: $0.key, count: $0.value.count) }

        return counts.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.tag < rhs.tag
            }
            return lhs.count > rhs.count
        }
    }

    private var topJournalThemeText: String? {
        let topTags = todaysJournalTagCounts.prefix(3).map(\.tag)
        guard !topTags.isEmpty else { return nil }

        switch topTags.count {
        case 1:
            return topTags[0]
        case 2:
            return "\(topTags[0]) and \(topTags[1])"
        default:
            return "\(topTags[0]), \(topTags[1]), and \(topTags[2])"
        }
    }

    private var journalWellnessInsight: WellnessInsightItem? {
        let entryCount = todaysJournalEntries.count
        guard entryCount > 0 else { return nil }

        if let topJournalThemeText {
            return WellnessInsightItem(
                title: "Journal",
                detail: "You wrote \(entryCount) journal \(entryCount == 1 ? "entry" : "entries") today, with \(topJournalThemeText) showing up most. That points to the main theme your reflection circled around."
            )
        }

        return WellnessInsightItem(
            title: "Journal",
            detail: "You wrote \(entryCount) journal \(entryCount == 1 ? "entry" : "entries") today, but no tags were attached, so the reflection theme is still open."
        )
    }

    private var waterWellnessInsight: WellnessInsightItem? {
        let current = waterHealth.todayWaterFlOz
        let goal = max(waterGoal, 1)
        let progress = min(max(current / goal, 0), 1)
        let currentText = String(format: "%.0f", current)
        let goalText = String(format: "%.0f", goal)

        let interpretation: String
        switch progress {
        case 1...:
            interpretation = "hydration reached your goal today."
        case 0.80..<1:
            interpretation = "hydration is close to your full goal."
        case 0.50..<0.80:
            interpretation = "hydration is steady but still behind your full goal."
        case 0.01..<0.50:
            interpretation = "hydration is running behind today."
        default:
            interpretation = "hydration has not been logged yet today."
        }

        return WellnessInsightItem(
            title: "Water",
            detail: "You’re at \(currentText) / \(goalText) oz today, so \(interpretation)"
        )
    }

    private var stepsWellnessInsight: WellnessInsightItem? {
        let current = Int(stepHealth.todaySteps.rounded())
        let goal = max(stepGoal, 1)
        let progress = min(max(Double(current) / Double(goal), 0), 1)
        let currentText = current.formatted()
        let goalText = goal.formatted()

        let interpretation: String
        switch progress {
        case 1...:
            interpretation = "movement reached your goal today."
        case 0.75..<1:
            interpretation = "movement is close to your full goal."
        case 0.40..<0.75:
            interpretation = "movement is steady and present."
        case 0.01..<0.40:
            interpretation = "movement is lighter today."
        default:
            interpretation = "movement has not been logged yet today."
        }

        return WellnessInsightItem(
            title: "Steps",
            detail: "You’ve logged \(currentText) / \(goalText) steps today, so \(interpretation)"
        )
    }

    private var habitCompletionCountsToday: (completed: Int, target: Int) {
        let activeHabits = habits.filter { !$0.isArchived }
        guard !activeHabits.isEmpty else { return (0, 0) }

        let target = activeHabits.reduce(0) { partial, habit in
            partial + max(1, habit.timesPerDay)
        }

        let completed = activeHabits.reduce(0) { partial, habit in
            let habitTarget = max(1, habit.timesPerDay)
            let todayCount = (habit.logs ?? [])
                .filter { dashboardCalendar.isDate($0.dayStart, inSameDayAs: Date()) }
                .reduce(0) { $0 + $1.count }

            return partial + min(todayCount, habitTarget)
        }

        return (completed, target)
    }

    private var habitsWellnessInsight: WellnessInsightItem? {
        let counts = habitCompletionCountsToday
        guard counts.target > 0 else { return nil }

        let progress = min(max(Double(counts.completed) / Double(counts.target), 0), 1)

        let interpretation: String
        switch progress {
        case 1...:
            interpretation = "your routines fully held together."
        case 0.80..<1:
            interpretation = "your routines mostly held together with a little room left."
        case 0.50..<0.80:
            interpretation = "your routines partially held but still have some unfinished pieces."
        case 0.01..<0.50:
            interpretation = "your routines started, but they are slipping today."
        default:
            interpretation = "your routines have not started yet today."
        }

        return WellnessInsightItem(
            title: "Habits",
            detail: "You completed \(counts.completed) / \(counts.target) habit actions today, so \(interpretation)"
        )
    }

    private var wellnessInsights: [WellnessInsightItem] {
        [
            journalWellnessInsight,
            waterWellnessInsight,
            stepsWellnessInsight,
            habitsWellnessInsight
        ]
        .compactMap { $0 }
    }

    private var displayedWellnessInsights: [WellnessInsightItem] {
        aiWellnessInsights ?? wellnessInsights
    }

    private var wellnessWallAISnapshot: WellnessWallAISnapshot {
        let journalTags = todaysJournalTagCounts.prefix(3).map(\.tag)

        let currentWater = waterHealth.todayWaterFlOz
        let resolvedWaterGoal = max(waterGoal, 1)
        let waterProgress = min(max(currentWater / resolvedWaterGoal, 0), 1)

        let currentSteps = Int(stepHealth.todaySteps.rounded())
        let resolvedStepGoal = max(stepGoal, 1)
        let stepProgress = min(max(Double(currentSteps) / Double(resolvedStepGoal), 0), 1)

        let habitCounts = habitCompletionCountsToday
        let habitProgress: Double
        if habitCounts.target > 0 {
            habitProgress = min(max(Double(habitCounts.completed) / Double(habitCounts.target), 0), 1)
        } else {
            habitProgress = 0
        }

        return WellnessWallAISnapshot(
            journal: WellnessWallAISnapshot.JournalSnapshot(
                entryCount: todaysJournalEntries.count,
                topTags: Array(journalTags)
            ),
            water: WellnessWallAISnapshot.WaterSnapshot(
                currentOz: currentWater,
                goalOz: resolvedWaterGoal,
                progress: waterProgress
            ),
            steps: WellnessWallAISnapshot.StepsSnapshot(
                currentSteps: currentSteps,
                goalSteps: Int(resolvedStepGoal),
                progress: stepProgress
            ),
            habits: WellnessWallAISnapshot.HabitsSnapshot(
                completedActions: habitCounts.completed,
                targetActions: habitCounts.target,
                progress: habitProgress
            )
        )
    }

    private var todaySavedWellnessWallAIInsight: WellnessWallAIInsight? {
        let today = dashboardCalendar.startOfDay(for: Date())

        return wellnessWallAIInsights.first { insight in
            dashboardCalendar.isDate(insight.dayStart, inSameDayAs: today)
        }
    }

    private var currentWellnessWallRefreshSlotStart: Date {
        let now = Date()
        let startOfDay = dashboardCalendar.startOfDay(for: now)
        let hour = dashboardCalendar.component(.hour, from: now)

        let slotHour: Int
        switch hour {
        case 0..<8:
            slotHour = 0
        case 8..<12:
            slotHour = 8
        case 12..<16:
            slotHour = 12
        case 16..<20:
            slotHour = 16
        default:
            slotHour = 20
        }

        return dashboardCalendar.date(byAdding: .hour, value: slotHour, to: startOfDay) ?? startOfDay
    }

    private func wellnessItems(from insight: WellnessWallAIInsight) -> [WellnessInsightItem] {
        [
            insight.journal.map { WellnessInsightItem(title: "Journal", detail: $0) },
            insight.water.map { WellnessInsightItem(title: "Water", detail: $0) },
            insight.steps.map { WellnessInsightItem(title: "Steps", detail: $0) },
            insight.habits.map { WellnessInsightItem(title: "Habits", detail: $0) }
        ]
        .compactMap { $0 }
    }

    private func wellnessItems(from response: WellnessWallAIResponse) -> [WellnessInsightItem] {
        [
            response.journal.map { WellnessInsightItem(title: "Journal", detail: $0) },
            response.water.map { WellnessInsightItem(title: "Water", detail: $0) },
            response.steps.map { WellnessInsightItem(title: "Steps", detail: $0) },
            response.habits.map { WellnessInsightItem(title: "Habits", detail: $0) }
        ]
        .compactMap { $0 }
    }

    @MainActor
    private func refreshWellnessWallAI() async {
        guard !isWellnessWallLocked else {
            aiWellnessInsights = nil
            return
        }

        guard !isRefreshingWellnessAI else { return }

        let snapshot = wellnessWallAISnapshot
        let snapshotHash = WellnessWallSnapshotHasher.hash(snapshot)
        let currentSlotStart = currentWellnessWallRefreshSlotStart
        let forceRefreshKey = "forceWellnessWallAIRefreshOnce"

        if UserDefaults.standard.bool(forKey: forceRefreshKey) == false {
            UserDefaults.standard.set(true, forKey: forceRefreshKey)

            if let savedInsight = todaySavedWellnessWallAIInsight {
                modelContext.delete(savedInsight)
                try? modelContext.save()
                aiWellnessInsights = nil
            }
        } else if let savedInsight = todaySavedWellnessWallAIInsight {
            aiWellnessInsights = wellnessItems(from: savedInsight)

            if savedInsight.updatedAt >= currentSlotStart {
                return
            }
        }

        isRefreshingWellnessAI = true
        defer { isRefreshingWellnessAI = false }

        do {
            let response = try await WellnessWallAIService.shared.generateInsights(snapshot: snapshot)
            let items = wellnessItems(from: response)

            guard !items.isEmpty else {
                aiWellnessInsights = nil
                return
            }

            let today = dashboardCalendar.startOfDay(for: Date())

            if let existingInsight = todaySavedWellnessWallAIInsight {
                existingInsight.journal = response.journal
                existingInsight.water = response.water
                existingInsight.steps = response.steps
                existingInsight.habits = response.habits
                existingInsight.snapshotHash = snapshotHash
                existingInsight.updatedAt = Date()
            } else {
                let insight = WellnessWallAIInsight(
                    dayStart: today,
                    journal: response.journal,
                    water: response.water,
                    steps: response.steps,
                    habits: response.habits,
                    snapshotHash: snapshotHash
                )
                modelContext.insert(insight)
            }

            try? modelContext.save()
            aiWellnessInsights = items
        } catch {
            if let savedInsight = todaySavedWellnessWallAIInsight {
                aiWellnessInsights = wellnessItems(from: savedInsight)
            } else {
                aiWellnessInsights = nil
            }
        }
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
        let normalizedActiveDays = Set(activeDays.map { dashboardCalendar.startOfDay(for: $0) })

        return last7DayStarts.reduce(0) { partial, day in
            let normalizedDay = dashboardCalendar.startOfDay(for: day)
            return partial + (normalizedActiveDays.contains(normalizedDay) ? 1 : 0)
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

        let normalizedLastCheckIn = dashboardCalendar.startOfDay(for: lastCheckInDate)
        let inferredStreakDays = max(stats.streakDays, 1)

        let inferredDates = (0..<inferredStreakDays).compactMap { offset in
            dashboardCalendar.date(byAdding: .day, value: -offset, to: normalizedLastCheckIn)
                .map { dashboardCalendar.startOfDay(for: $0) }
        }

        return Set(inferredDates)
    }

    private var waterActiveDayStarts: Set<Date> {
        waterActiveDayStartsCache
    }

    private var stepActiveDayStarts: Set<Date> {
        stepActiveDayStartsCache
    }
    private func refreshHealthDerivedStats() async {
        let moodDays = Array(moodDayAverages.keys).sorted()

        var hydratedMoodDays: Set<Date> = []
        var activeStepMoodDays: Set<Date> = []
        var hydratedLast7Days: Set<Date> = []
        var activeStepLast7Days: Set<Date> = []

        for day in moodDays {
            guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { continue }

            let waterTotal = await waterHealth.totalWaterFlOz(from: day, to: nextDay)
            if waterTotal >= waterGoal {
                hydratedMoodDays.insert(day)
            }

            let stepTotal = await stepHealth.totalSteps(from: day, to: nextDay)
            if stepTotal >= stepGoal {
                activeStepMoodDays.insert(day)
            }
        }

        for day in last7DayStarts {
            guard let nextDay = dashboardCalendar.date(byAdding: .day, value: 1, to: day) else { continue }

            let waterTotal = await waterHealth.totalWaterFlOz(from: day, to: nextDay)
            if waterTotal > 0 {
                hydratedLast7Days.insert(day)
            }

            let stepTotal = await stepHealth.totalSteps(from: day, to: nextDay)
            if stepTotal > 0 {
                activeStepLast7Days.insert(day)
            }
        }

        await MainActor.run {
            waterGoalMoodAverageValue = averageMood(on: hydratedMoodDays)
            stepGoalMoodAverageValue = averageMood(on: activeStepMoodDays)
            waterGoalMoodSummary = moodSummary(on: hydratedMoodDays)
            stepGoalMoodSummary = moodSummary(on: activeStepMoodDays)
            waterActiveDayStartsCache = hydratedLast7Days
            stepActiveDayStartsCache = activeStepLast7Days
            refreshConsistencyCard()
        }
    }

    private func currentStreak(from activeDays: Set<Date>) -> Int {
        let today = dashboardCalendar.startOfDay(for: Date())
        let yesterday = dashboardCalendar.date(byAdding: .day, value: -1, to: today).map {
            dashboardCalendar.startOfDay(for: $0)
        }

        let normalizedActiveDays = Set(activeDays.map { dashboardCalendar.startOfDay(for: $0) })

        let startingDay: Date
        if normalizedActiveDays.contains(today) {
            startingDay = today
        } else if let yesterday, normalizedActiveDays.contains(yesterday) {
            // Preserve an active streak through the current day until the user has had a chance
            // to log today's activity. This prevents dashboard streak cards from resetting to 0
            // every morning before the user checks in.
            startingDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startingDay

        while normalizedActiveDays.contains(cursor) {
            streak += 1
            guard let previous = dashboardCalendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = dashboardCalendar.startOfDay(for: previous)
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
        let activeHabits = habits.filter { !$0.isArchived }
        guard !activeHabits.isEmpty else { return 0 }
        return activeHabits.map { habitDailyStreak(for: $0) }.max() ?? 0
    }

    private var waterCurrentStreak: Int {
        currentStreak(from: waterActiveDayStarts)
    }

    private var stepCurrentStreak: Int {
        currentStreak(from: stepActiveDayStarts)
    }


    private var readingCurrentStreak: Int {
        currentStreak(from: readingDayStarts)
    }

    private var healthDayStarts: Set<Date> {
        Set(healthMetricEntries.map { dashboardCalendar.startOfDay(for: $0.date) })
    }

    private var exerciseDayStarts: Set<Date> {
        Set(exerciseLogs.map { dashboardCalendar.startOfDay(for: $0.date) })
    }

    private var healthCurrentStreak: Int {
        currentStreak(from: healthDayStarts)
    }

    private var exerciseCurrentStreak: Int {
        currentStreak(from: exerciseDayStarts)
    }

    private var activeStreakItems: [ActiveStreakItem] {
        [
            ActiveStreakItem(label: "Journal", value: journalCurrentStreak),
            ActiveStreakItem(label: "Mood", value: moodCurrentStreak),
            ActiveStreakItem(label: "Habits", value: habitCurrentStreak),
            ActiveStreakItem(label: "Reading", value: readingCurrentStreak),
            ActiveStreakItem(label: "Health", value: healthCurrentStreak),
            ActiveStreakItem(label: "Exercise", value: exerciseCurrentStreak)
        ]
    }

    private var selfCareCurrentPoints: Int {
        currentSelfCareProfile?.currentPoints ?? 0
    }

    private var selfCareLevel: Int {
        currentSelfCareProfile?.level ?? SelfCarePointsManager.level(for: selfCareCurrentPoints)
    }

    private var selfCareLevelProgress: Double {
        let progress = SelfCarePointsManager.progressInCurrentLevel(for: selfCareCurrentPoints)
        let threshold = max(SelfCarePointsManager.pointsPerLevel, 1)
        let computed = Double(progress) / Double(threshold)
        // If exactly on a level boundary (progress == 0) and level > 0,
        // show the ring as full rather than empty.
        if computed == 0 && selfCareLevel > 0 {
            return 1.0
        }
        return min(max(computed, 0), 1)
    }

    private var consistencyAreaScores: [ConsistencyAreaScore] {
        [
            ConsistencyAreaScore(
                title: "Journaling",
                activeDays: activeDayCount(in: journalDayStarts),
                currentStreak: journalCurrentStreak
            ),
            ConsistencyAreaScore(
                title: "Mood",
                activeDays: activeDayCount(in: moodDayStarts),
                currentStreak: moodCurrentStreak
            ),
            ConsistencyAreaScore(
                title: "Habits",
                activeDays: activeDayCount(in: habitDayStarts),
                currentStreak: habitCurrentStreak
            ),
            ConsistencyAreaScore(
                title: "Water Tracking",
                activeDays: activeDayCount(in: waterActiveDayStarts),
                currentStreak: waterCurrentStreak
            ),
            ConsistencyAreaScore(
                title: "Steps",
                activeDays: activeDayCount(in: stepActiveDayStarts),
                currentStreak: stepCurrentStreak
            ),
            ConsistencyAreaScore(
                title: "Reading",
                activeDays: activeDayCount(in: readingDayStarts),
                currentStreak: readingCurrentStreak
            )
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
        let incompleteAreas = consistencyAreaScores.filter { $0.activeDays < last7DayStarts.count }

        guard !incompleteAreas.isEmpty else {
            return nil
        }

        return incompleteAreas.min { lhs, rhs in
            if lhs.activeDays == rhs.activeDays {
                return lhs.title < rhs.title
            }
            return lhs.activeDays < rhs.activeDays
        }
    }
    
    private var needsAttentionArea: ConsistencyAreaScore? {
        let sorted = consistencyAreaScores.sorted { lhs, rhs in
            let lhsNeedsAttention = lhs.currentStreak == 0
            let rhsNeedsAttention = rhs.currentStreak == 0

            if lhsNeedsAttention != rhsNeedsAttention {
                return lhsNeedsAttention && !rhsNeedsAttention
            }

            if lhs.activeDays != rhs.activeDays {
                return lhs.activeDays < rhs.activeDays
            }

            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak < rhs.currentStreak
            }

            return lhs.title < rhs.title
        }

        guard let first = sorted.first else { return nil }

        if let leastActiveArea,
           first.title == leastActiveArea.title,
           let second = sorted.dropFirst().first {
            return second
        }

        return first
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

    // MARK: - Dashboard Content Subviews
    private var dashboardContent: some View {
        VStack(spacing: 16) {
            header

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)

            moonPhaseSection
            momentumSection
            selfCareSection
            activeStreaksSection
            dailyBalanceSection
            tarotSection
            lenormandSection
            horoscopeSection
            consistencySection
            wellnessSection
        }
    }

    private var moonPhaseSection: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showMoonPhaseDetails = true
            }
        } label: {
            DashboardMoonPhaseCard(data: moonPhaseData)
        }
        .buttonStyle(.plain)
    }


    private var momentumSection: some View {
        DailyMomentumCard(
            activatedCount: activatedCount,
            totalCount: 6,
            items: dailyMomentumItems
        )
        .id(momentumRefreshID)
    }

    private var selfCareSection: some View {
        premiumBlockedCard(isSelfCareDashboardLocked) {
            DashboardSelfCareCard(
                points: selfCareCurrentPoints,
                level: selfCareLevel,
                progress: selfCareLevelProgress
            )
            .id(dashboardSupportRefreshID)
        }
    }

    private var activeStreaksSection: some View {
        ActiveStreaksCard(items: activeStreakItems)
            .id(dashboardSupportRefreshID)
    }

    private var dailyBalanceSection: some View {
        premiumBlockedCard(isDailyBalanceLocked) {
            DailyBalanceCard(items: dailyBalanceItems)
        }
    }

    private var tarotSection: some View {
        premiumBlockedCard(isDailyTarotLocked) {
            DashboardTarotCard(
                tip: currentDailyTarotTip,
                onDraw: drawDailyTarotTip
            )
        }
    }

    private var lenormandSection: some View {
        DashboardLenormandCard(
            tip: currentDailyLenormandTip,
            onDraw: drawDailyLenormandTip
        )
    }

    private var horoscopeSection: some View {
        horoscopeCard
    }

    private var consistencySection: some View {
        DashboardConsistencyCard(
            mostConsistent: mostConsistentArea,
            needsAttention: needsAttentionArea,
            strongestStreak: strongestStreakItem,
            leastActiveThisWeek: leastActiveArea
        )
        .id(consistencyRefreshID)
    }

    private var wellnessSection: some View {
        premiumBlockedCard(isWellnessWallLocked) {
            WellnessWallCard(items: displayedWellnessInsights)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func premiumBlockedCard<Content: View>(
        _ locked: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .blur(radius: locked ? 12 : 0)
                .allowsHitTesting(!locked)

            if locked {
                // subtle dark overlay
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.25))

                // clean premium banner (top right)
                HStack(spacing: 6) {
                    Image("lockfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.white)

                    Text("Premium only")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .padding(10)
            }
        }
    }

    private var habitCompletionProgressToday: Double {
        let activeHabits = habits

        guard !activeHabits.isEmpty else {
            return habitCompletedToday ? 1.0 : 0.0
        }

        let totalTarget = activeHabits.reduce(0) { $0 + max(1, $1.timesPerDay) }
        guard totalTarget > 0 else { return habitCompletedToday ? 1.0 : 0.0 }

        let todayProgress = activeHabits.reduce(0) { partial, habit in
            let todayCount = (habit.logs ?? [])
                .filter { dashboardCalendar.isDate($0.dayStart, inSameDayAs: Date()) }
                .reduce(0) { $0 + $1.count }

            return partial + min(todayCount, max(1, habit.timesPerDay))
        }

        return min(Double(todayProgress) / Double(totalTarget), 1.0)
    }

    private var dashboardScrollContent: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                dashboardContent
                    .frame(width: max(proxy.size.width - (LSpacing.pageHorizontal * 2), 0), alignment: .topLeading)
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
            }
            .clipped()
        }
    }

    private var dashboardRootView: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                dashboardScrollContent
            }
            .navigationDestination(isPresented: $showToolbox) {
                ToolboxView()
            }
            .navigationDestination(isPresented: $showSelfCarePointsPage) {
                SelfCarePointsView()
            }
        }
    }

    var body: some View {
        dashboardRootViewWithLifecycle
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
            .overlay {
                if showMoonPhaseDetails, let detail = currentMoonPhaseDetail {
                    moonPhaseDetailsPopup(detail)
                        .zIndex(100)
                }
            }
    }

    private var dashboardRootViewWithLifecycle: some View {
        dashboardRootViewWithObservers
            .onAppear {
                refreshForNewDay()
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshForNewDay()
                    Task { await refreshHealthDerivedStats() }
                    Task { await refreshWellnessWallAI() }
                }
            }
            .onReceive(stepHealth.$todaySteps) { _ in
                refreshMomentumCard()
                refreshConsistencyCard()
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onReceive(waterHealth.$todayWaterFlOz) { _ in
                refreshMomentumCard()
                refreshConsistencyCard()
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshForNewDay()
                aiWellnessInsights = nil
                Task { await refreshWellnessWallAI() }
            }
    }

    private var dashboardRootViewWithObservers: some View {
        dashboardRootView
            .toolbarBackground(.hidden, for: .navigationBar)
            .onChange(of: journalEntries.count) { _, _ in
                refreshMomentumCard()
                refreshConsistencyCard()
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onChange(of: moodLogs.count) { _, _ in
                refreshMomentumCard()
                refreshConsistencyCard()
                Task { await refreshHealthDerivedStats() }
            }
            .onChange(of: habitLogs.count) { _, _ in
                refreshMomentumCard()
                refreshConsistencyCard()
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onChange(of: readingCurrentStreak) { _, _ in
                refreshMomentumCard()
                refreshConsistencyCard()
            }
            .onChange(of: readingLoggedToday) { _, _ in
                refreshMomentumCard()
                refreshConsistencyCard()
            }
            .onChange(of: waterGoal) { _, _ in
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onChange(of: stepGoal) { _, _ in
                Task { await refreshHealthDerivedStats() }
                Task { await refreshWellnessWallAI() }
            }
            .onChange(of: selectedZodiacSign) { _, _ in
                if selectedHoroscopeTab == .picker {
                    previewHoroscope = nil
                    horoscopeError = nil
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
                .onboardingTarget("healthIcon")

                Button {
                    showSelfCarePointsPage = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("bowheart")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .onboardingTarget("loveIcon")

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


    private var currentMoonPhaseDetail: MoonPhaseDetail? {
        MoonPhaseDetailData.detail(for: moonPhaseData.phaseName)
    }

    private var moonPhasePopupSymbolName: String {
        switch moonPhaseData.phaseName.lowercased() {
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

    @ViewBuilder
    private func moonPhaseDetailsPopup(_ detail: MoonPhaseDetail) -> some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showMoonPhaseDetails = false
                }
            },
            width: 560,
            heightRatio: 0.76
        ) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: moonPhasePopupSymbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)

                GradientTitle(text: detail.phaseName, font: .system(size: 24, weight: .bold))
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showMoonPhaseDetails = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                moonPhaseDetailSection(title: "Vibe") {
                    Text(detail.vibe)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                moonPhaseDetailSection(title: "Description") {
                    Text(detail.description)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                moonPhaseDetailSection(title: "Rituals") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detail.rituals, id: \.self) { ritual in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(LColors.textSecondary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)

                                Text(ritual)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                moonPhaseDetailSection(title: "Best For") {
                    MoonBestForKeywordList(keywords: detail.bestFor)
                }
            }
        } footer: {
            HStack {
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showMoonPhaseDetails = false
                    }
                } label: {
                    Text("Close")
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

    @ViewBuilder
    private func moonPhaseDetailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GradientTitle(text: title, size: 20)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct DashboardLenormandCard: View {
    let tip: DailyLenormandTip?
    let onDraw: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("wandfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Daily Lenormand", font: .system(size: 20, weight: .bold))
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
                        Text("Draw your daily Lenormand insight for today.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        Button {
                            onDraw()
                        } label: {
                            Text("Draw Lenormand")
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
                        Text(keyword)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LGradients.blue)
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

private struct MoonBestForKeywordList: View {
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LGradients.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(LGradients.blue, lineWidth: 1)
                    )
            }
        }
    }
}

private struct ConsistencyAreaScore: Identifiable {
    let id = UUID()
    let title: String
    let activeDays: Int
    let currentStreak: Int
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
                    Image("flamefill")
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
                        value: leastActiveThisWeek.map { "\($0.title) — \($0.activeDays) / 7 days" } ?? "All areas active — 7 / 7 days"
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


private struct DailyBalanceItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let progress: Double
}

private struct ActiveStreakItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
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
                    Image("playwavy")
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

private struct ActiveStreaksCard: View {
    let items: [ActiveStreakItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("boltfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Active Streaks", font: .system(size: 18, weight: .bold))
                    Spacer()
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items) { item in
                        streakCapsule(item)
                    }
                }
            }
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func streakCapsule(_ item: ActiveStreakItem) -> some View {
        HStack(spacing: 10) {
            Text(item.label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Text("\(item.value)")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

private struct DashboardSelfCareCard: View {
    let points: Int
    let level: Int
    let progress: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image("balloonheart")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .opacity(1)

                    GradientTitle(text: "Self Care", font: .system(size: 18, weight: .bold))
                    Spacer()
                }

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(points)")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text("pts")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)
                        }

                        Text("Keep showing up for yourself")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 8)
                            .frame(width: 68, height: 68)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LGradients.blue,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 68, height: 68)

                        Text("\(level)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DailyBalanceCard: View {
    let items: [DailyBalanceItem]

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

                    GradientTitle(text: "Daily Balance", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                Text("See how today is distributed across movement, reflection, care, planning, and completion.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                VStack(spacing: 12) {
                    ForEach(items) { item in
                        balanceRow(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func balanceRow(_ item: DailyBalanceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int((item.progress * 100).rounded()))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(item.detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            GlassProgressBar(progress: item.progress, height: 10, gradient: LGradients.blue)
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
