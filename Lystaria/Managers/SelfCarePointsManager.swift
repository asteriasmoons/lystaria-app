//
//  SelfCarePointsManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData

enum SelfCarePointsError: Error {
    case noActiveUser
    case insufficientPoints
    case entryOwnershipMismatch
}

enum SelfCarePointsManager {
    // MARK: - Default Point Values

    static let reminderPoints = 10
    static let eventReminderPoints = 8
    static let habitReminderPoints = 10
    static let habitLogPoints = 10
    static let readingCheckInPoints = 10
    static let journalEntryPoints = 8
    static let healthLogPoints = 10
    static let exerciseLogPoints = 8
    static let moodLogPoints = 10

    // MARK: - Leveling

    /// Linear level curve for v1:
    /// 0...99 = Level 0
    /// 100...199 = Level 1
    /// 200...299 = Level 2
    static let pointsPerLevel = 100

    static func level(for lifetimePoints: Int) -> Int {
        max(0, max(0, lifetimePoints) / pointsPerLevel)
    }

    static func levelFloor(for level: Int) -> Int {
        max(0, level) * pointsPerLevel
    }

    static func nextLevelThreshold(for level: Int) -> Int {
        (max(0, level) + 1) * pointsPerLevel
    }

    static func progressInCurrentLevel(for lifetimePoints: Int) -> Int {
        let currentLevel = level(for: lifetimePoints)
        let floor = levelFloor(for: currentLevel)
        return max(0, lifetimePoints - floor)
    }

    static func pointsNeededToNextLevel(for lifetimePoints: Int) -> Int {
        let currentLevel = level(for: lifetimePoints)
        let nextThreshold = nextLevelThreshold(for: currentLevel)
        return max(0, nextThreshold - lifetimePoints)
    }

    // MARK: - User Resolution

    static func resolveActiveUserId(in modelContext: ModelContext) throws -> String {
        let descriptor = FetchDescriptor<AuthUser>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let users = try modelContext.fetch(descriptor)

        guard let user = users.first else {
            throw SelfCarePointsError.noActiveUser
        }

        if let serverId = user.serverId, !serverId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverId
        }

        if let appleUserId = user.appleUserId, !appleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appleUserId
        }

        if let googleUserId = user.googleUserId, !googleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return googleUserId
        }

        if let email = user.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return email.lowercased()
        }

        throw SelfCarePointsError.noActiveUser
    }

    // MARK: - Date Helpers

    static func dayKey(from date: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func startOfWeekSunday(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromSunday = weekday - 1
        return calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfDay) ?? startOfDay
    }

    static func weekStartDayKey(from date: Date = Date(), calendar: Calendar = .current) -> String {
        dayKey(from: startOfWeekSunday(from: date, calendar: calendar), calendar: calendar)
    }

    static func insertResetLog(
        in modelContext: ModelContext,
        userId: String,
        weekStartDayKey: String,
        resetAt: Date,
        pointsBeforeReset: Int,
        levelBeforeReset: Int
    ) {
        let resetLog = SelfCarePointsResetLog(
            userId: userId,
            weekStartDayKey: weekStartDayKey,
            resetAt: resetAt,
            pointsBeforeReset: pointsBeforeReset,
            levelBeforeReset: levelBeforeReset,
            createdAt: resetAt
        )
        modelContext.insert(resetLog)
    }

    @discardableResult
    static func applyWeeklyResetIfNeeded(
        in modelContext: ModelContext,
        profile: SelfCarePointsProfile,
        userId: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let currentWeekKey = weekStartDayKey(from: now, calendar: calendar)

        if profile.currentWeekStartDayKey.isEmpty {
            let hasLegacyWeeklyState = profile.currentPoints > 0 || profile.level > 0

            if hasLegacyWeeklyState {
                insertResetLog(
                    in: modelContext,
                    userId: userId,
                    weekStartDayKey: "legacy-pre-weekly-reset",
                    resetAt: now,
                    pointsBeforeReset: profile.currentPoints,
                    levelBeforeReset: profile.level
                )

                profile.currentPoints = 0
                profile.level = 0
                profile.lastWeeklyResetAt = now
                profile.currentWeekStartDayKey = currentWeekKey
                profile.updatedAt = now

                try modelContext.save()
                return true
            }

            profile.currentWeekStartDayKey = currentWeekKey
            profile.updatedAt = now
            try modelContext.save()
            return false
        }

        guard profile.currentWeekStartDayKey != currentWeekKey else {
            return false
        }

        insertResetLog(
            in: modelContext,
            userId: userId,
            weekStartDayKey: profile.currentWeekStartDayKey,
            resetAt: now,
            pointsBeforeReset: profile.currentPoints,
            levelBeforeReset: profile.level
        )

        profile.currentPoints = 0
        profile.level = 0
        profile.lastWeeklyResetAt = now
        profile.currentWeekStartDayKey = currentWeekKey
        profile.updatedAt = now

        try modelContext.save()
        return true
    }

    // MARK: - Profile Fetch / Create

    @discardableResult
    static func fetchOrCreateProfile(
        in modelContext: ModelContext,
        userId: String
    ) throws -> SelfCarePointsProfile {
        let descriptor = FetchDescriptor<SelfCarePointsProfile>(
            predicate: #Predicate { $0.userId == userId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            _ = try applyWeeklyResetIfNeeded(in: modelContext, profile: existing, userId: userId)

            let correctedLevel = level(for: existing.currentPoints)
            if existing.level != correctedLevel {
                existing.level = correctedLevel
                existing.updatedAt = Date()
                try modelContext.save()
            }
            return existing
        }

        let profile = SelfCarePointsProfile(
            userId: userId,
            currentWeekStartDayKey: weekStartDayKey()
        )
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }

    static func fetchProfile(
        in modelContext: ModelContext,
        userId: String
    ) throws -> SelfCarePointsProfile? {
        let descriptor = FetchDescriptor<SelfCarePointsProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        return try modelContext.fetch(descriptor).first
    }

    static func fetchProfileForActiveUser(
        in modelContext: ModelContext
    ) throws -> SelfCarePointsProfile {
        let userId = try resolveActiveUserId(in: modelContext)
        return try fetchOrCreateProfile(in: modelContext, userId: userId)
    }

    // MARK: - Entry Fetch Helpers

    static func hasEntry(
        in modelContext: ModelContext,
        userId: String,
        sourceKey: String
    ) throws -> Bool {
        let descriptor = FetchDescriptor<SelfCarePointEntry>(
            predicate: #Predicate {
                $0.userId == userId && $0.sourceKey == sourceKey
            }
        )

        return try !modelContext.fetch(descriptor).isEmpty
    }

    static func recentEntries(
        in modelContext: ModelContext,
        userId: String,
        limit: Int = 20
    ) throws -> [SelfCarePointEntry] {
        var descriptor = FetchDescriptor<SelfCarePointEntry>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(1, limit)
        return try modelContext.fetch(descriptor)
    }

    static func recentEntriesForActiveUser(
        in modelContext: ModelContext,
        limit: Int = 20
    ) throws -> [SelfCarePointEntry] {
        let userId = try resolveActiveUserId(in: modelContext)
        return try recentEntries(in: modelContext, userId: userId, limit: limit)
    }

    static func pointsEarnedToday(
        in modelContext: ModelContext,
        userId: String,
        calendar: Calendar = .current
    ) throws -> Int {
        let todayKey = dayKey(from: Date(), calendar: calendar)

        let descriptor = FetchDescriptor<SelfCarePointEntry>(
            predicate: #Predicate {
                $0.userId == userId && $0.dayKey == todayKey
            }
        )

        return try modelContext.fetch(descriptor).reduce(0) { $0 + max(0, $1.points) }
    }

    static func pointsEarnedTodayForActiveUser(
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> Int {
        let userId = try resolveActiveUserId(in: modelContext)
        return try pointsEarnedToday(in: modelContext, userId: userId, calendar: calendar)
    }

    @discardableResult
    static func deletePointEntryAndAdjustTotals(
        in modelContext: ModelContext,
        entry: SelfCarePointEntry,
        calendar: Calendar = .current
    ) throws -> Bool {
        let userId = try resolveActiveUserId(in: modelContext)
        guard entry.userId == userId else {
            throw SelfCarePointsError.entryOwnershipMismatch
        }

        let profile = try fetchOrCreateProfile(in: modelContext, userId: userId)
        _ = try applyWeeklyResetIfNeeded(in: modelContext, profile: profile, userId: userId, calendar: calendar)

        let safePoints = max(0, entry.points)
        let currentWeekKey = weekStartDayKey(calendar: calendar)
        let entryWeekKey = weekStartDayKey(from: entry.createdAt, calendar: calendar)

        profile.lifetimePoints = max(0, profile.lifetimePoints - safePoints)

        if entryWeekKey == currentWeekKey {
            profile.currentPoints = max(0, profile.currentPoints - safePoints)
        }

        profile.level = level(for: profile.currentPoints)
        profile.updatedAt = Date()

        modelContext.delete(entry)
        try modelContext.save()
        return true
    }

    @discardableResult
    static func createManualHistorySnapshot(
        in modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let userId = try resolveActiveUserId(in: modelContext)

        let profile: SelfCarePointsProfile
        if let existing = try fetchProfile(in: modelContext, userId: userId) {
            profile = existing
        } else {
            let newProfile = SelfCarePointsProfile(
                userId: userId,
                currentWeekStartDayKey: weekStartDayKey(from: now, calendar: calendar)
            )
            modelContext.insert(newProfile)
            try modelContext.save()
            profile = newProfile
        }

        let snapshotWeekKey: String
        if profile.currentWeekStartDayKey.isEmpty {
            snapshotWeekKey = "manual-unspecified-week"
        } else {
            snapshotWeekKey = "manual-\(profile.currentWeekStartDayKey)"
        }

        let snapshot = SelfCarePointsResetLog(
            userId: userId,
            weekStartDayKey: snapshotWeekKey,
            resetAt: now,
            pointsBeforeReset: profile.currentPoints,
            levelBeforeReset: level(for: profile.currentPoints),
            createdAt: now
        )
        modelContext.insert(snapshot)
        try modelContext.save()
        return true
    }

    // MARK: - Core Award Function

    @discardableResult
    static func awardPoints(
        in modelContext: ModelContext,
        sourceType: SelfCarePointSourceType,
        sourceId: String? = nil,
        sourceKey: String,
        points: Int,
        title: String,
        details: String? = nil,
        earnedAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let safePoints = max(0, points)
        guard safePoints > 0 else { return false }

        let userId = try resolveActiveUserId(in: modelContext)

        if try hasEntry(in: modelContext, userId: userId, sourceKey: sourceKey) {
            return false
        }

        let profile = try fetchOrCreateProfile(in: modelContext, userId: userId)
        _ = try applyWeeklyResetIfNeeded(in: modelContext, profile: profile, userId: userId, now: earnedAt, calendar: calendar)

        let entry = SelfCarePointEntry(
            userId: userId,
            sourceType: sourceType,
            sourceId: sourceId,
            sourceKey: sourceKey,
            dayKey: dayKey(from: earnedAt, calendar: calendar),
            points: safePoints,
            title: title,
            details: details,
            createdAt: earnedAt
        )

        modelContext.insert(entry)

        profile.currentPoints += safePoints
        profile.lifetimePoints += safePoints
        profile.level = level(for: profile.currentPoints)
        profile.lastEarnedAt = earnedAt
        profile.updatedAt = Date()

        try modelContext.save()
        return true
    }

    // MARK: - Spend Points

    static func spendPoints(
        in modelContext: ModelContext,
        amount: Int
    ) throws {
        let safeAmount = max(0, amount)
        guard safeAmount > 0 else { return }

        let profile = try fetchProfileForActiveUser(in: modelContext)

        guard profile.currentPoints >= safeAmount else {
            throw SelfCarePointsError.insufficientPoints
        }

        profile.currentPoints -= safeAmount
        profile.spentPoints += safeAmount
        profile.updatedAt = Date()

        try modelContext.save()
    }

    // MARK: - Convenience Award Methods

    @discardableResult
    static func awardReminderCompletion(
        in modelContext: ModelContext,
        reminderId: String,
        occurrenceDayKey: String,
        title: String
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .reminder,
            sourceId: reminderId,
            sourceKey: "reminder:\(reminderId):\(occurrenceDayKey)",
            points: reminderPoints,
            title: title
        )
    }

    @discardableResult
    static func awardEventReminderCompletion(
        in modelContext: ModelContext,
        eventId: String,
        occurrenceDayKey: String,
        title: String
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .eventReminder,
            sourceId: eventId,
            sourceKey: "eventReminder:\(eventId):\(occurrenceDayKey)",
            points: eventReminderPoints,
            title: title
        )
    }

    @discardableResult
    static func awardHabitReminderCompletion(
        in modelContext: ModelContext,
        reminderId: String,
        occurrenceDayKey: String,
        title: String
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .habitReminder,
            sourceId: reminderId,
            sourceKey: "habitReminder:\(reminderId):\(occurrenceDayKey)",
            points: habitReminderPoints,
            title: title
        )
    }

    @discardableResult
    static func awardHabitLog(
        in modelContext: ModelContext,
        habitLogId: String,
        title: String,
        loggedAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .habitLog,
            sourceId: habitLogId,
            sourceKey: "habitLog:\(habitLogId)",
            points: habitLogPoints,
            title: title,
            earnedAt: loggedAt,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardReadingCheckIn(
        in modelContext: ModelContext,
        date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let userId = try resolveActiveUserId(in: modelContext)
        let todayKey = dayKey(from: date, calendar: calendar)

        return try awardPoints(
            in: modelContext,
            sourceType: .readingCheckIn,
            sourceId: userId,
            sourceKey: "readingCheckIn:\(userId):\(todayKey)",
            points: readingCheckInPoints,
            title: "Reading Check-In",
            earnedAt: date,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardJournalEntry(
        in modelContext: ModelContext,
        journalEntryId: String,
        title: String = "Journal Entry",
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .journalEntry,
            sourceId: journalEntryId,
            sourceKey: "journalEntry:\(journalEntryId)",
            points: journalEntryPoints,
            title: title,
            earnedAt: createdAt,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardHealthLog(
        in modelContext: ModelContext,
        healthEntryId: String,
        title: String = "Health Log",
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .healthLog,
            sourceId: healthEntryId,
            sourceKey: "healthLog:\(healthEntryId)",
            points: healthLogPoints,
            title: title,
            earnedAt: createdAt,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardExerciseLog(
        in modelContext: ModelContext,
        exerciseEntryId: String,
        title: String = "Exercise Log",
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .exerciseLog,
            sourceId: exerciseEntryId,
            sourceKey: "exerciseLog:\(exerciseEntryId)",
            points: exerciseLogPoints,
            title: title,
            earnedAt: createdAt,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardMoodLog(
        in modelContext: ModelContext,
        moodLogId: String,
        title: String = "Mood Log",
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .moodLog,
            sourceId: moodLogId,
            sourceKey: "moodLog:\(moodLogId)",
            points: moodLogPoints,
            title: title,
            earnedAt: createdAt,
            calendar: calendar
        )
    }
}
