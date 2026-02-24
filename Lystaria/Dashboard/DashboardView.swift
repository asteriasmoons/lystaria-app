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

    @Query(sort: \CalendarEvent.startDate, order: .reverse)
    private var calendarEvents: [CalendarEvent]

    @Query(sort: \HabitLog.dayStart, order: .reverse)
    private var habitLogs: [HabitLog]

    @StateObject private var stepHealth = HealthKitManager.shared
    @StateObject private var waterHealth = WaterHealthKitManager.shared
    @AppStorage("waterGoalFlOz") private var waterGoal: Double = 80
    @AppStorage("stepGoal") private var stepGoal: Double = 5000

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

    private var hasEventToday: Bool {
        calendarEvents.contains { event in
            let eventStart = event.startDate
            let eventEnd = event.endDate ?? event.startDate

            if event.allDay {
                return eventStart < startOfTomorrow && eventEnd >= startOfToday
            }

            return eventStart < startOfTomorrow && eventEnd >= startOfToday
        }
    }

    private var activatedCount: Int {
        [
            journaledToday,
            moodLoggedToday,
            habitCompletedToday,
            waterLoggedToday,
            stepsLoggedToday,
            hasEventToday
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

                        DailyMomentumCard(
                            activatedCount: activatedCount,
                            totalCount: 6,
                            items: [
                                .init(title: "Journal", systemImage: "notesfill", isActive: journaledToday),
                                .init(title: "Mood", systemImage: "facefill", isActive: moodLoggedToday),
                                .init(title: "Habits", systemImage: "goalsparkle", isActive: habitCompletedToday),
                                .init(title: "Water", systemImage: "dropfill", isActive: waterLoggedToday),
                                .init(title: "Steps", systemImage: "shoefill", isActive: stepsLoggedToday),
                                .init(title: "Events", systemImage: "fillcal", isActive: hasEventToday)
                            ]
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
            .task {
                await stepHealth.fetchTodaySteps()
                await waterHealth.fetchTodayWater()
            }
        }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "Dashboard", font: .title.bold())
            Spacer()
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
