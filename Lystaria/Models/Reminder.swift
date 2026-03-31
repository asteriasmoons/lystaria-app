// Reminder.swift
// Lystaria
//
// 

import Foundation
import SwiftData

// MARK: - Enums

enum ReminderStatus: String, CaseIterable {
    case scheduled = "scheduled"
    case sent = "sent"
    case paused = "paused"
    case deleted = "deleted"
}

enum ReminderScheduleKind: String, CaseIterable {
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

enum ReminderType: String, CaseIterable {
    case regular = "regular"
    case routine = "routine"
}

// MARK: - Schedule (Codable struct stored as JSON)

struct ReminderSchedule: Equatable, Sendable {
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

extension ReminderStatus: nonisolated Codable {}
extension ReminderScheduleKind: nonisolated Codable {}
extension ReminderType: nonisolated Codable {}
extension ReminderSchedule: nonisolated Codable {}

// MARK: - Reminder Model

@Model
final class RoutineChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var reminder: LystariaReminder?

    init(
        id: UUID = UUID(),
        title: String = "",
        sortOrder: Int = 0,
        reminder: LystariaReminder? = nil
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.reminder = reminder
    }
}

@Model
final class ReminderMedicationLink {
    var id: UUID = UUID()
    var reminder: LystariaReminder?
    var medicationId: UUID?
    var quantity: Int = 1
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        reminder: LystariaReminder? = nil,
        medicationId: UUID? = nil,
        quantity: Int = 1,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.reminder = reminder
        self.medicationId = medicationId
        self.quantity = max(1, quantity)
        self.sortOrder = sortOrder
    }
}

@Model
final class LystariaReminder {
    // MARK: - Fields
    var title: String = ""
    var details: String?
    var statusRaw: String = ReminderStatus.scheduled.rawValue
    var nextRunAt: Date = Date()
    var acknowledgedAt: Date?
    var pendingNextRunAt: Date?
    
    var runDayKey: String?          // "2026-02-05"
    var sentTimesOfDayStorage: String = "[]"
    
    // CloudKit-safe scalar storage for schedule JSON
    var scheduleStorage: String?
    
    var timezone: String = TimeZone.current.identifier
    var reminderTypeRaw: String = ReminderType.regular.rawValue
    var routineOccurrenceKey: String = ""
    var checkedRoutineItemIDsStorage: String = "[]"

    @Relationship(deleteRule: .cascade, inverse: \RoutineChecklistItem.reminder)
    var routineChecklistItems: [RoutineChecklistItem]?
    @Relationship(deleteRule: .cascade, inverse: \ReminderMedicationLink.reminder)
    var medicationLinks: [ReminderMedicationLink]?
    
    var lastRunAt: Date?
    
    var checklistStorage: String = "[]"

    var checklistItems: [String] {
        get {
            guard let data = checklistStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                checklistStorage = encoded
            } else {
                checklistStorage = "[]"
            }
        }
    }

    var reminderType: ReminderType {
        get { ReminderType(rawValue: reminderTypeRaw) ?? .regular }
        set { reminderTypeRaw = newValue.rawValue }
    }

    var checkedRoutineItemIDs: [UUID] {
        get {
            guard let data = checkedRoutineItemIDsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([UUID].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                checkedRoutineItemIDsStorage = encoded
            } else {
                checkedRoutineItemIDsStorage = "[]"
            }
        }
    }

    var sortedRoutineChecklistItems: [RoutineChecklistItem] {
        (routineChecklistItems ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
    var sortedMedicationLinks: [ReminderMedicationLink] {
        (medicationLinks ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                let lhsID = lhs.medicationId?.uuidString ?? ""
                let rhsID = rhs.medicationId?.uuidString ?? ""
                return lhsID.localizedCaseInsensitiveCompare(rhsID) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var completedRoutineItemCount: Int {
        let validIDs = Set((routineChecklistItems ?? []).map(\.id))
        return checkedRoutineItemIDs.filter { validIDs.contains($0) }.count
    }

    var totalRoutineItemCount: Int {
        (routineChecklistItems ?? []).count
    }

    var isRoutineChecklistComplete: Bool {
        reminderType == .routine && totalRoutineItemCount > 0 && completedRoutineItemCount >= totalRoutineItemCount
    }

    func isRoutineItemChecked(_ item: RoutineChecklistItem) -> Bool {
        checkedRoutineItemIDs.contains(item.id)
    }

    func setRoutineItemChecked(_ checked: Bool, for item: RoutineChecklistItem) {
        var ids = checkedRoutineItemIDs
        if checked {
            if !ids.contains(item.id) {
                ids.append(item.id)
            }
        } else {
            ids.removeAll { $0 == item.id }
        }
        checkedRoutineItemIDs = ids
        updatedAt = Date()
    }

    func resetRoutineChecklist(for occurrenceKey: String) {
        routineOccurrenceKey = occurrenceKey
        checkedRoutineItemIDs = []
        updatedAt = Date()
    }
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Kanban
    var kanbanColumn: KanbanColumn?
    var kanbanSortOrder: Int = 0
    var isKanbanDone: Bool = false

    // MARK: - Optional Link (used for Habits, etc.)
    var linkedKindRaw: String?     // e.g. "habit"
    var linkedHabitId: UUID?       // Habit.id
    var linkedMedicationId: UUID?  // Medication.id
    var linkedMedicationQuantity: Int = 1

    enum LinkedKind: String, Codable {
        case habit = "habit"
        case medication = "medication"
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

    var sentTimesOfDay: [String] {
        get {
            guard let data = sentTimesOfDayStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                sentTimesOfDayStorage = encoded
            } else {
                sentTimesOfDayStorage = "[]"
            }
        }
    }

    var schedule: ReminderSchedule? {
        get {
            guard let scheduleStorage,
                  let data = scheduleStorage.data(using: .utf8)
            else {
                return nil
            }
            return try? JSONDecoder().decode(ReminderSchedule.self, from: data)
        }
        set {
            guard let newValue else {
                scheduleStorage = nil
                return
            }
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                scheduleStorage = encoded
            } else {
                scheduleStorage = nil
            }
        }
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
        reminderType: ReminderType = .regular,
        linkedKind: LinkedKind? = nil,
        linkedHabitId: UUID? = nil,
        linkedMedicationId: UUID? = nil,
        linkedMedicationQuantity: Int = 1
    ) {
        self.title = title
        self.details = details
        self.statusRaw = status.rawValue
        self.nextRunAt = nextRunAt
        self.acknowledgedAt = nil
        self.pendingNextRunAt = nil
        self.runDayKey = nil
        self.sentTimesOfDayStorage = "[]"
        self.scheduleStorage = nil
        self.timezone = timezone
        self.reminderType = reminderType
        self.routineOccurrenceKey = ""
        self.checkedRoutineItemIDsStorage = "[]"
        self.routineChecklistItems = nil
        self.medicationLinks = nil
        self.lastRunAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.linkedKind = linkedKind
        self.linkedHabitId = linkedHabitId
        self.linkedMedicationId = linkedMedicationId
        self.linkedMedicationQuantity = max(1, linkedMedicationQuantity)
        self.sentTimesOfDay = []
        self.checkedRoutineItemIDs = []
        self.schedule = schedule
    }
}
