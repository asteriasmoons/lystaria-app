//
//  DashboardConsistencyAnalyzer.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import Foundation

enum DashboardConsistencyAnalyzer {
    static func makeResult(
        calendar: Calendar = .autoupdatingCurrent,
        journalEntries: [JournalEntry],
        moodLogs: [MoodLog],
        habitLogs: [HabitLog],
        readingLastCheckInTimestamp: Double,
        todayWaterProvider: @escaping (Date, Date) -> Double?,
        todayStepsProvider: @escaping (Date, Date) -> Double?,
        journalStreakDays: Int? = nil,
        habitStreakDays: Int? = nil,
        readingStreakDays: Int? = nil
    ) -> DashboardConsistencyResult {
        let last7Days = last7DayStarts(calendar: calendar)

        let journalDays = Set(journalEntries.map { calendar.startOfDay(for: $0.createdAt) })
        let moodDays = Set(moodLogs.map { calendar.startOfDay(for: $0.createdAt) })
        let habitDays = Set(
            habitLogs
                .filter { $0.count > 0 }
                .map { calendar.startOfDay(for: $0.dayStart) }
        )

        let readingDays: Set<Date> = {
            guard readingLastCheckInTimestamp > 0 else { return [] }
            let date = Date(timeIntervalSince1970: readingLastCheckInTimestamp)
            return [calendar.startOfDay(for: date)]
        }()

        let waterActiveDays = Set(
            last7Days.filter { day in
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
                let total = todayWaterProvider(day, nextDay) ?? 0
                return total > 0
            }
        )

        let stepActiveDays = Set(
            last7Days.filter { day in
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
                let total = todayStepsProvider(day, nextDay) ?? 0
                return total > 0
            }
        )

        let scores: [DashboardAreaScore] = [
            DashboardAreaScore(
                title: "Journaling",
                activeDays: activeDayCount(in: last7Days, matching: journalDays)
            ),
            DashboardAreaScore(
                title: "Mood",
                activeDays: activeDayCount(in: last7Days, matching: moodDays)
            ),
            DashboardAreaScore(
                title: "Habits",
                activeDays: activeDayCount(in: last7Days, matching: habitDays)
            ),
            DashboardAreaScore(
                title: "Water Tracking",
                activeDays: activeDayCount(in: last7Days, matching: waterActiveDays)
            ),
            DashboardAreaScore(
                title: "Steps",
                activeDays: activeDayCount(in: last7Days, matching: stepActiveDays)
            ),
            DashboardAreaScore(
                title: "Reading",
                activeDays: activeDayCount(in: last7Days, matching: readingDays)
            )
        ]

        let mostConsistent = scores.max { lhs, rhs in
            if lhs.activeDays == rhs.activeDays {
                return lhs.title > rhs.title
            }
            return lhs.activeDays < rhs.activeDays
        }

        let needsAttention = scores.min { lhs, rhs in
            if lhs.activeDays == rhs.activeDays {
                return lhs.title > rhs.title
            }
            return lhs.activeDays < rhs.activeDays
        }

        let leastActiveThisWeek = needsAttention

        let strongestStreak = makeStrongestStreak(
            journalStreakDays: journalStreakDays,
            habitStreakDays: habitStreakDays,
            readingStreakDays: readingStreakDays
        )

        return DashboardConsistencyResult(
            mostConsistent: mostConsistent,
            needsAttention: needsAttention,
            strongestStreak: strongestStreak,
            leastActiveThisWeek: leastActiveThisWeek
        )
    }

    private static func last7DayStarts(calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: Date())

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        .map { calendar.startOfDay(for: $0) }
        .sorted()
    }

    private static func activeDayCount(in days: [Date], matching activeDays: Set<Date>) -> Int {
        days.reduce(0) { partial, day in
            partial + (activeDays.contains(day) ? 1 : 0)
        }
    }

    private static func makeStrongestStreak(
        journalStreakDays: Int?,
        habitStreakDays: Int?,
        readingStreakDays: Int?
    ) -> DashboardStreakResult? {
        let streaks: [DashboardStreakResult] = [
            journalStreakDays.map { DashboardStreakResult(title: "Journaling", streakDays: $0) },
            habitStreakDays.map { DashboardStreakResult(title: "Habits", streakDays: $0) },
            readingStreakDays.map { DashboardStreakResult(title: "Reading", streakDays: $0) }
        ]
        .compactMap { $0 }
        .filter { $0.streakDays > 0 }

        return streaks.max { lhs, rhs in
            if lhs.streakDays == rhs.streakDays {
                return lhs.title > rhs.title
            }
            return lhs.streakDays < rhs.streakDays
        }
    }
}
