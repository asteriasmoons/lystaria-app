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
    // MARK: - Today Helpers

    // MARK: - Data Queries

    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var journalEntries: [JournalEntry]

    @Query(sort: \MoodLog.createdAt, order: .reverse)
    private var moodLogs: [MoodLog]


    @Query(sort: \HabitLog.dayStart, order: .reverse)
    private var habitLogs: [HabitLog]

    @StateObject private var stepHealth = HealthKitManager.shared
    @StateObject private var waterHealth = WaterHealthKitManager.shared
    @StateObject private var onboarding = OnboardingManager()
    @AppStorage("waterGoalFlOz") private var waterGoal: Double = 80
    @AppStorage("stepGoal") private var stepGoal: Double = 5000

    @State private var showToolbox = false

    @AppStorage("dashboardTarotDayKey") private var tarotDayKey: String = ""
    @AppStorage("dashboardTarotId") private var tarotStoredId: String = ""
    @AppStorage("dashboardTarotTitle") private var tarotStoredTitle: String = ""
    @AppStorage("dashboardTarotKeywords") private var tarotStoredKeywords: String = ""
    @AppStorage("dashboardTarotMessage") private var tarotStoredMessage: String = ""

    @State private var selectedZodiacSign: String = ""
    @State private var isFetchingHoroscope = false
    @State private var horoscopeError: String? = nil

    @AppStorage("dashboardHoroscopeDayKey") private var horoscopeDayKey: String = ""
    @AppStorage("dashboardHoroscopeSign") private var horoscopeStoredSign: String = ""
    @AppStorage("dashboardHoroscopeMessage") private var horoscopeStoredMessage: String = ""

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

    private var currentDailyHoroscope: DailyHoroscope? {
        guard horoscopeDayKey == todayKey,
              !horoscopeStoredSign.isEmpty,
              !horoscopeStoredMessage.isEmpty else {
            return nil
        }

        return DailyHoroscope(
            sign: horoscopeStoredSign,
            message: horoscopeStoredMessage
        )
    }

    private func fetchDailyHoroscope() {
        guard !selectedZodiacSign.isEmpty else { return }

        if horoscopeDayKey == todayKey,
           horoscopeStoredSign.caseInsensitiveCompare(selectedZodiacSign) == .orderedSame,
           !horoscopeStoredMessage.isEmpty {
            return
        }

        isFetchingHoroscope = true
        horoscopeError = nil

        Task {
            do {
                let horoscope = try await HoroscopeService.shared.fetchHoroscope(for: selectedZodiacSign)

                await MainActor.run {
                    horoscopeDayKey = todayKey
                    horoscopeStoredSign = horoscope.sign
                    horoscopeStoredMessage = horoscope.message
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

    private var currentDailyTarotTip: DailyTarotTip? {
        guard tarotDayKey == todayKey,
              !tarotStoredTitle.isEmpty,
              !tarotStoredMessage.isEmpty else {
            return nil
        }

        let keywords = tarotStoredKeywords
            .split(separator: "|")
            .map { String($0) }
            .filter { !$0.isEmpty }

        return DailyTarotTip(
            id: tarotStoredId.isEmpty ? todayKey : tarotStoredId,
            title: tarotStoredTitle,
            keywords: keywords,
            message: tarotStoredMessage
        )
    }

    private func drawDailyTarotTip() {
        guard currentDailyTarotTip == nil, !localDailyTarotTips.isEmpty else { return }
        guard let tip = localDailyTarotTips.randomElement() else { return }

        tarotDayKey = todayKey
        tarotStoredId = tip.id
        tarotStoredTitle = tip.title
        tarotStoredKeywords = tip.keywords.joined(separator: "|")
        tarotStoredMessage = tip.message
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


    private var activatedCount: Int {
        [
            journaledToday,
            moodLoggedToday,
            habitCompletedToday,
            waterLoggedToday,
            stepsLoggedToday
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

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)

                        DailyMomentumCard(
                            activatedCount: activatedCount,
                            totalCount: 5,
                            items: [
                                .init(title: "Journal", systemImage: "notesfill", isActive: journaledToday),
                                .init(title: "Mood", systemImage: "facefill", isActive: moodLoggedToday),
                                .init(title: "Habits", systemImage: "goalsparkle", isActive: habitCompletedToday),
                                .init(title: "Water", systemImage: "dropfill", isActive: waterLoggedToday),
                                .init(title: "Steps", systemImage: "shoefill", isActive: stepsLoggedToday)
                            ]
                        )

                        DashboardTarotCard(
                            tip: currentDailyTarotTip,
                            onDraw: drawDailyTarotTip
                        )

                        DashboardHoroscopeCard(
                            selectedSign: $selectedZodiacSign,
                            zodiacSigns: zodiacSigns,
                            horoscope: currentDailyHoroscope,
                            isLoading: isFetchingHoroscope,
                            errorText: horoscopeError,
                            onFetch: fetchDailyHoroscope
                        )

                        WellnessWallCard(items: wellnessInsights)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showToolbox) {
                ToolboxView()
            }
            .onAppear {
                Task {
                    await stepHealth.fetchTodaySteps()
                    await waterHealth.fetchTodayWater()
                }
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

private struct DashboardHoroscopeCard: View {
    @Binding var selectedSign: String
    let zodiacSigns: [String]
    let horoscope: DailyHoroscope?
    let isLoading: Bool
    let errorText: String?
    let onFetch: () -> Void

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

                    GradientTitle(text: "Daily Astrology", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                if let horoscope {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(horoscope.sign)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        Text(horoscope.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
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

                        Button {
                            onFetch()
                        } label: {
                            HStack {
                                Spacer()

                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Get Horoscope")
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

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.9))
                        }
                    }
                }
            }
        }
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
