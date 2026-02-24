// Reminder.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB Reminder schema

import Foundation
import SwiftData

// MARK: - Enums

enum ReminderStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case sent = "sent"
    case paused = "paused"
    case deleted = "deleted"
}

enum ReminderScheduleKind: String, Codable, CaseIterable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case interval = "interval"
    
    var label: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .interval: return "Interval"
        }
    }
}

// MARK: - Schedule (Codable struct stored as JSON)

struct ReminderSchedule: Codable, Equatable, Sendable {
    var kind: ReminderScheduleKind
    
    // For daily/weekly/monthly/yearly
    var timeOfDay: String?          // "HH:mm" 24-hour
    var timesOfDay: [String]?       // multiple times
    var interval: Int?              // every X days/weeks/months/years
    
    // Weekly only
    var daysOfWeek: [Int]?          // 0-6 (Sun-Sat)
    
    // Monthly only
    var dayOfMonth: Int?            // 1-31
    
    // Yearly only
    var anchorMonth: Int?           // 1-12
    var anchorDay: Int?             // 1-31
    
    // Interval only
    var intervalMinutes: Int?
    
    static let once = ReminderSchedule(kind: .once)
}

// MARK: - Reminder Model

@Model
final class LystariaReminder {
    // MARK: - Sync metadata (Supabase)
    var serverId: String?          // Supabase row id
    var userId: String?            // auth.uid() owner
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var deletedAt: Date?           // soft delete for sync
    
    // MARK: - Fields
    var title: String
    var details: String?
    var statusRaw: String
    var nextRunAt: Date
    var acknowledgedAt: Date?
    var pendingNextRunAt: Date?
    
    var runDayKey: String?          // "2026-02-05"
    var sentTimesOfDay: [String]
    
    // Schedule stored as JSON via Codable
    var schedule: ReminderSchedule?
    
    var timezone: String
    var lastRunAt: Date?
    
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync helpers
    func markDirty() {
        self.updatedAt = Date()
        self.needsSync = true
    }

    // MARK: - Optional Link (used for Habits, etc.)
    var linkedKindRaw: String?     // e.g. "habit"
    var linkedHabitId: UUID?       // Habit.id

    enum LinkedKind: String, Codable {
        case habit = "habit"
    }

    var linkedKind: LinkedKind? {
        get { linkedKindRaw.flatMap { LinkedKind(rawValue: $0) } }
        set { linkedKindRaw = newValue?.rawValue }
    }
    
    // MARK: - Computed
    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }
    
    var isRecurring: Bool {
        guard let schedule else { return false }
        return schedule.kind != .once
    }
    
    init(
        title: String,
        details: String? = nil,
        status: ReminderStatus = .scheduled,
        nextRunAt: Date,
        schedule: ReminderSchedule? = nil,
        timezone: String = TimeZone.current.identifier,
        serverId: String? = nil,
        linkedKind: LinkedKind? = nil,
        linkedHabitId: UUID? = nil
    ) {
        self.title = title
        self.details = details
        self.statusRaw = status.rawValue
        self.nextRunAt = nextRunAt
        self.acknowledgedAt = nil
        self.pendingNextRunAt = nil
        self.runDayKey = nil
        self.sentTimesOfDay = []
        self.schedule = schedule
        self.timezone = timezone
        self.lastRunAt = nil
        self.serverId = serverId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.linkedKind = linkedKind
        self.linkedHabitId = linkedHabitId
        self.needsSync = true
    }
}
