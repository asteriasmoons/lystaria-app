//
//  SelfCarePointEntry.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData

enum SelfCarePointSourceType: String, Codable, CaseIterable {
    case reminder = "reminder"
    case eventReminder = "eventReminder"
    case habitReminder = "habitReminder"
    case habitLog = "habitLog"
    case readingCheckIn = "readingCheckIn"
    case journalEntry = "journalEntry"
    case healthLog = "healthLog"
    case exerciseLog = "exerciseLog"
    case moodLog = "moodLog"
    case readingSession = "readingSession"
    case readingTimerSession = "readingTimerSession"

    var label: String {
        switch self {
        case .reminder: return "Reminder Complete"
        case .eventReminder: return "Event Reminder Complete"
        case .habitReminder: return "Habit Reminder Complete"
        case .habitLog: return "Habit Logged"
        case .readingCheckIn: return "Reading Check-In"
        case .journalEntry: return "Journal Entry"
        case .healthLog: return "Health Log"
        case .exerciseLog: return "Exercise Log"
        case .moodLog: return "Mood Log"
        case .readingSession: return "Reading Session"
        case .readingTimerSession: return "Reading Timer Session"
        }
    }
}

@Model
final class SelfCarePointEntry {
    var id: UUID = UUID()

    /// Matches the resolved active user id.
    var userId: String = ""

    /// Stored raw for SwiftData / CloudKit friendliness.
    var sourceTypeRaw: String = SelfCarePointSourceType.reminder.rawValue

    /// Optional identifier for the originating record.
    /// Example: reminder id, journal entry id, habit log id, etc.
    var sourceId: String?

    /// Required duplicate-protection key.
    /// This should represent the exact earnable occurrence.
    /// Example:
    /// - reminder:<reminderId>:2026-03-18
    /// - readingCheckIn:<userId>:2026-03-18
    /// - journalEntry:<entryId>
    var sourceKey: String = ""

    /// Useful for daily totals / grouping.
    /// Format: yyyy-MM-dd
    var dayKey: String = ""

    /// Positive points earned for this entry.
    var points: Int = 0

    /// Human-friendly title for display in UI.
    var title: String = ""

    /// Optional extra detail for UI if you want it later.
    var details: String?

    var createdAt: Date = Date()

    var sourceType: SelfCarePointSourceType {
        get { SelfCarePointSourceType(rawValue: sourceTypeRaw) ?? .reminder }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: String = "",
        sourceType: SelfCarePointSourceType = .reminder,
        sourceId: String? = nil,
        sourceKey: String = "",
        dayKey: String = "",
        points: Int = 0,
        title: String = "",
        details: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceId = sourceId
        self.sourceKey = sourceKey
        self.dayKey = dayKey
        self.points = max(0, points)
        self.title = title
        self.details = details
        self.createdAt = createdAt
    }
}
