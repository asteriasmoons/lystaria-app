// ReminderHistoryEntry.swift
// Lystaria
//
// Persistent log of every reminder completion and skip.
// CloudKit-safe: all fields have defaults, no relationships.

import Foundation
import SwiftData

enum ReminderHistoryEventKind: String, Codable, CaseIterable, Sendable {
    case completed = "completed"
    case skipped   = "skipped"
}

@Model
final class ReminderHistoryEntry {
    var reminderPersistentId: String = ""
    var reminderTitle: String = ""
    var reminderDetails: String? = nil
    var reminderScheduleKindRaw: String = "once"
    var reminderTypeRaw: String = "regular"
    var linkedKindRaw: String? = nil

    var occurredAt: Date = Date()
    var kindRaw: String = ReminderHistoryEventKind.completed.rawValue

    // Stable key: "<kindRaw>-<reminderTitle>-<occurredAt rounded to second>"
    // Does NOT use persistentModelID since that is not stable across launches.
    var dedupeKey: String = ""

    var createdAt: Date = Date()

    var kind: ReminderHistoryEventKind {
        get { ReminderHistoryEventKind(rawValue: kindRaw) ?? .completed }
        set { kindRaw = newValue.rawValue }
    }

    static func makeDedupe(kind: ReminderHistoryEventKind, title: String, occurredAt: Date) -> String {
        let ts = Int64(occurredAt.timeIntervalSince1970.rounded())
        return "\(kind.rawValue)-\(title)-\(ts)"
    }

    init(
        reminderPersistentId: String,
        reminderTitle: String,
        reminderDetails: String?,
        reminderScheduleKindRaw: String,
        reminderTypeRaw: String,
        linkedKindRaw: String?,
        occurredAt: Date,
        kind: ReminderHistoryEventKind
    ) {
        self.reminderPersistentId = reminderPersistentId
        self.reminderTitle = reminderTitle
        self.reminderDetails = reminderDetails
        self.reminderScheduleKindRaw = reminderScheduleKindRaw
        self.reminderTypeRaw = reminderTypeRaw
        self.linkedKindRaw = linkedKindRaw
        self.occurredAt = occurredAt
        self.kindRaw = kind.rawValue
        self.dedupeKey = ReminderHistoryEntry.makeDedupe(kind: kind, title: reminderTitle, occurredAt: occurredAt)
        self.createdAt = Date()
    }
}
