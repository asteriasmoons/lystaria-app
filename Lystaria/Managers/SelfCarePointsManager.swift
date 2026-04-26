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
    static let readingSessionPoints = 10
    static let readingTimerSessionPoints = 12

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
        // Anchor to Monday so Sunday stays in the current week all day.
        // weekday: 1=Sun, 2=Mon, ... 7=Sat
        // Days back to Monday: Sun=6, Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
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
    
    // MARK: - Weekly Reset Scheduler

    private static var resetTimer: Timer?

    /// Call once at app launch (and on foreground) from LystariaApp.
    /// Schedules a precise snapshot at 11:58 PM Sunday and reset at 11:59 PM Sunday.
    @MainActor
    static func scheduleWeeklyResetTimer(modelContainer: ModelContainer) {
        resetTimer?.invalidate()

        let now = Date()
        let cal = Calendar.current

        // Find the next Sunday
        let weekday = cal.component(.weekday, from: now) // 1=Sun
        let daysUntilSunday = weekday == 1 ? 0 : (8 - weekday) // 0 if today is Sunday

        guard let thisSunday = cal.date(byAdding: .day, value: daysUntilSunday, to: cal.startOfDay(for: now)) else { return }

        // Snapshot fires at 23:58:00 Sunday
        var snapshotComps = cal.dateComponents([.year, .month, .day], from: thisSunday)
        snapshotComps.hour = 23
        snapshotComps.minute = 58
        snapshotComps.second = 0
        guard let snapshotFire = cal.date(from: snapshotComps) else { return }

        // Reset fires at 23:59:00 Sunday
        var resetComps = cal.dateComponents([.year, .month, .day], from: thisSunday)
        resetComps.hour = 23
        resetComps.minute = 59
        resetComps.second = 0
        guard let resetFire = cal.date(from: resetComps) else { return }

        // If both times are already past for today (e.g. it's Sunday 11:59 PM+), reschedule for next Sunday
        let snapshotTarget = snapshotFire > now ? snapshotFire :
            cal.date(byAdding: .day, value: 7, to: snapshotFire) ?? snapshotFire
        let resetTarget = resetFire > now ? resetFire :
            cal.date(byAdding: .day, value: 7, to: resetFire) ?? resetFire

        // Schedule snapshot
        let snapshotDelay = snapshotTarget.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(deadline: .now() + snapshotDelay) {
            Task { @MainActor in
                _ = try? SelfCarePointsManager.createManualHistorySnapshot(
                    in: modelContainer.mainContext
                )
                print("📸 Weekly snapshot saved at \(Date())")
            }
        }

        // Schedule reset
        let resetDelay = resetTarget.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(deadline: .now() + resetDelay) {
            Task { @MainActor in
                let context = modelContainer.mainContext
                guard let userId = try? SelfCarePointsManager.resolveActiveUserId(in: context),
                      let profile = try? SelfCarePointsManager.fetchProfile(in: context, userId: userId) else { return }

                let now = Date()
                let cal = Calendar.current
                let currentWeekKey = SelfCarePointsManager.weekStartDayKey(from: now, calendar: cal)

                SelfCarePointsManager.insertResetLog(
                    in: context,
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

                try? context.save()
                print("🔄 Weekly reset executed at \(Date())")

                // Reschedule for next week
                SelfCarePointsManager.scheduleWeeklyResetTimer(modelContainer: modelContainer)
            }
        }

        print("⏱ Weekly reset scheduled: snapshot at \(snapshotTarget), reset at \(resetTarget)")
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
    static func awardReadingSession(
        in modelContext: ModelContext,
        sessionId: String,
        title: String = "Reading Session",
        sessionDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .readingSession,
            sourceId: sessionId,
            sourceKey: "readingSession:\(sessionId)",
            points: readingSessionPoints,
            title: title,
            earnedAt: sessionDate,
            calendar: calendar
        )
    }

    @discardableResult
    static func awardReadingTimerSession(
        in modelContext: ModelContext,
        sessionId: String,
        title: String = "Reading Timer Session",
        sessionDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        try awardPoints(
            in: modelContext,
            sourceType: .readingTimerSession,
            sourceId: sessionId,
            sourceKey: "readingTimerSession:\(sessionId)",
            points: readingTimerSessionPoints,
            title: title,
            earnedAt: sessionDate,
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
