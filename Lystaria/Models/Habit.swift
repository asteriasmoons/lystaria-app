// Habit.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB Habit schema


import Foundation
import SwiftData

enum HabitReminderKind: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"

    var label: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

@Model
final class Habit {
    var id: UUID = UUID()

    var title: String = ""
    var details: String?

    /// How many days per week the user wants to do this habit (e.g., 3)
    var daysPerWeek: Int = 1

    /// How many times per day the user wants to do this habit (e.g., 2)
    var timesPerDay: Int = 1

    // MARK: - Reminder Settings (powers Habit nudges via LystariaReminder)

    /// If false, no linked reminders should exist for this habit.
    var reminderEnabled: Bool = false

    /// Stored as raw string for SwiftData compatibility.
    var reminderKindRaw: String = HabitReminderKind.none.rawValue

    /// For daily/weekly reminders: one time of day in 24-hour "HH:mm".
    /// (We can expand to multiple times later.)
    var reminderTimeOfDay: String?

    /// Weekly only: selected days 0-6 (Sun-Sat). Must match `daysPerWeek` when weekly.
    var reminderDaysOfWeekStorage: String = "[]"

    /// Optional: first day this habit reminder becomes active. If nil, scheduling can treat it as "today".
    var reminderStartDate: Date?

    var reminderKind: HabitReminderKind {
        get { HabitReminderKind(rawValue: reminderKindRaw) ?? .none }
        set { reminderKindRaw = newValue.rawValue }
    }

    var reminderDaysOfWeek: [Int] {
        get {
            guard let data = reminderDaysOfWeekStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Int].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                reminderDaysOfWeekStorage = encoded
            } else {
                reminderDaysOfWeekStorage = "[]"
            }
        }
    }

    /// Used later for free-tier caps (e.g., only 2 active habits on free plan)
    var isArchived: Bool = false

    /// If set, streak and stats calculations should only count logs on/after this date.
    var statsResetAt: Date?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationship: one habit has many logs
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]?

    // Relationship: one habit has many skipped days
    @Relationship(deleteRule: .cascade, inverse: \HabitSkip.habit)
    var skips: [HabitSkip]?

    init(
        title: String,
        details: String? = nil,
        daysPerWeek: Int = 7,
        timesPerDay: Int = 1,
        reminderEnabled: Bool = false,
        reminderKind: HabitReminderKind = .none,
        reminderTimeOfDay: String? = nil,
        reminderDaysOfWeek: [Int] = [],
        reminderStartDate: Date? = nil,
        isArchived: Bool = false,
        statsResetAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.daysPerWeek = max(1, min(daysPerWeek, 7))
        self.timesPerDay = max(1, timesPerDay)

        // Compute reminder fields without touching `self` until all values are ready.
        let computedEnabled = reminderEnabled
        var computedKindRaw = reminderKind.rawValue
        var computedTime: String? = reminderTimeOfDay

        // Normalize days: keep only 0...6 unique, sorted.
        var computedDays = Array(Set(reminderDaysOfWeek.filter { (0...6).contains($0) })).sorted()

        // If reminders are disabled, force kind to none and clear time/days.
        if !computedEnabled {
            computedKindRaw = HabitReminderKind.none.rawValue
            computedTime = nil
            computedDays = []
        }

        // If weekly, cap selection to a max of 7 (UI will enforce exact count later).
        if computedEnabled, reminderKind == .weekly {
            computedDays = Array(computedDays.prefix(7))
        }

        self.reminderEnabled = computedEnabled
        self.reminderKindRaw = computedKindRaw
        self.reminderTimeOfDay = computedTime
        self.reminderDaysOfWeekStorage = "[]"
        self.reminderStartDate = reminderStartDate

        self.isArchived = isArchived
        self.statsResetAt = statsResetAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.logs = nil

        // Now safe to use computed property
        self.reminderDaysOfWeek = computedDays
    }
}
