// CalendarEvent.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB Event schema

import Foundation
import SwiftData

// MARK: - Recurrence Types

enum RecurrenceFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
}

enum RecurrenceEndKind: String {
    case never = "never"
    case until = "until"
    case count = "count"
}

enum CalendarEventSyncState: String {
    case synced = "synced"
    case newLocal = "new_local"
    case modifiedLocal = "modified_local"
    case modifiedExternal = "modified_external"
    case conflicted = "conflicted"
    case pendingDeleteLocal = "pending_delete_local"
    case pendingDeleteExternal = "pending_delete_external"
}

enum RecurrenceExceptionKind: String {
    case edited = "edited"
    case moved = "moved"
    case cancelled = "cancelled"
    case split = "split"
}

enum CalendarEventShareMode: String, CaseIterable {
    case personal = "personal"
    case inviteOnly = "invite_only"
    case shared = "shared"
}

enum CalendarEventParticipationStatus: String, CaseIterable {
    case owner = "owner"
    case invited = "invited"
    case joined = "joined"
    case declined = "declined"
    case left = "left"
}

/// Codable struct stored as JSON in SwiftData
struct RecurrenceEnd: Equatable, Sendable {
    var kind: RecurrenceEndKind
    var until: Date?
    var count: Int?
    
    static let never = RecurrenceEnd(kind: .never)
}

/// Codable struct stored as JSON in SwiftData
struct RecurrenceRule: Equatable, Sendable {
    var freq: RecurrenceFrequency
    var interval: Int                // every X units (>= 1)
    var byWeekday: [Int]?            // weekly only: 0..6 (Sun..Sat)
    var end: RecurrenceEnd?
    
    init(freq: RecurrenceFrequency, interval: Int = 1, byWeekday: [Int]? = nil, end: RecurrenceEnd? = nil) {
        self.freq = freq
        self.interval = max(interval, 1)
        self.byWeekday = byWeekday
        self.end = end
    }
}

/// Codable struct for location coordinates
struct LocationCoords: Equatable, Sendable {
    var lat: Double
    var lng: Double
}

extension RecurrenceFrequency: nonisolated Codable {}
extension RecurrenceEndKind: nonisolated Codable {}
extension RecurrenceEnd: nonisolated Codable {}
extension RecurrenceRule: nonisolated Codable {}
extension LocationCoords: nonisolated Codable {}
extension CalendarEventSyncState: nonisolated Codable {}
extension RecurrenceExceptionKind: nonisolated Codable {}
extension CalendarEventShareMode: nonisolated Codable {}
extension CalendarEventParticipationStatus: nonisolated Codable {}

// MARK: - CalendarEvent Model

@Model
final class CalendarEvent {
    // MARK: - Sync metadata
    var localEventId: String = UUID().uuidString
    var notificationID: String = UUID().uuidString
    var serverId: String?
    var lastSyncedAt: Date?
    var externalLastModifiedAt: Date?
    var needsSync: Bool = true
    var syncStateRaw: String = CalendarEventSyncState.newLocal.rawValue
    var lastSyncedHash: String?
    var lastExternalHash: String?
    var appleCalendarItemIdentifier: String? = nil
    var appleCalendarIdentifier: String? = nil
    
    // MARK: - Fields
    var title: String = ""
    var eventDescription: String?    // 'description' is reserved in Swift
    var startDate: Date = Date()
    var endDate: Date?
    var allDay: Bool = false
    var color: String?
    var meetingUrl: String?
    var location: String?
    var locationPlaceId: String?
    
    // Store coords as JSON string
    var locationCoordsStorage: String?
    
    var googleEventId: String?
    var googleCalendarId: String?
    
    // Link to a reminder (by serverId)
    var reminderServerId: String?
    var calendarId: String?
    @Relationship var calendar: EventCalendar?
    
    // RRULE string for recurrence support (no exception dates)
    var recurrenceRRule: String?

    // Time zone identifier used for displaying/scheduling this event
    var timeZoneId: String?

    // Recurrence stored as JSON string
    var recurrenceStorage: String?

    // Legacy recurrence exceptions stored as JSON string
    var recurrenceExceptionsStorage: String = "[]"
    
    // MARK: - Recurrence role / exception support
    var isRecurringSeriesMaster: Bool = false
    var isRecurrenceException: Bool = false
    var isCancelledOccurrence: Bool = false
    var parentSeriesLocalId: String?
    var splitFromSeriesLocalId: String?
    var originalOccurrenceDate: Date?
    var splitEffectiveFrom: Date?
    var exceptionKindRaw: String?
    
    // MARK: - Sharing / join support
    var isSharedEvent: Bool = false
    var isJoinable: Bool = false
    var joinCode: String = ""
    var shareModeRaw: String = CalendarEventShareMode.personal.rawValue
    var participationStatusRaw: String = CalendarEventParticipationStatus.owner.rawValue
    var ownerUserId: String?
    var ownerDisplayName: String?
    var shareToken: String?
    var shareURL: String?
    var requiresApprovalToJoin: Bool = false
    var allowGuestsToInvite: Bool = false
    var allowGuestsToEdit: Bool = false
    var maxAttendees: Int?
    var attendeeCount: Int = 0
    var joinDeadline: Date?
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Computed
    var syncState: CalendarEventSyncState {
        get { CalendarEventSyncState(rawValue: syncStateRaw) ?? .newLocal }
        set { syncStateRaw = newValue.rawValue }
    }

    var exceptionKind: RecurrenceExceptionKind? {
        get { exceptionKindRaw.flatMap { RecurrenceExceptionKind(rawValue: $0) } }
        set { exceptionKindRaw = newValue?.rawValue }
    }
    
    var isRecurring: Bool {
        recurrence != nil
    }
    
    var displayColor: String {
        color ?? "#6C63FF"  // default purple
    }
    
    var locationCoords: LocationCoords? {
        get {
            guard let locationCoordsStorage,
                  let data = locationCoordsStorage.data(using: .utf8)
            else { return nil }
            return try? JSONDecoder().decode(LocationCoords.self, from: data)
        }
        set {
            guard let newValue else {
                locationCoordsStorage = nil
                return
            }
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                locationCoordsStorage = encoded
            }
        }
    }
    
    var recurrence: RecurrenceRule? {
        get {
            guard let recurrenceStorage,
                  let data = recurrenceStorage.data(using: .utf8)
            else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
        }
        set {
            guard let newValue else {
                recurrenceStorage = nil
                return
            }
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                recurrenceStorage = encoded
            }
        }
    }
    
    var recurrenceExceptions: [String] {
        get {
            guard let data = recurrenceExceptionsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                recurrenceExceptionsStorage = encoded
            } else {
                recurrenceExceptionsStorage = "[]"
            }
        }
    }
    
    var shareMode: CalendarEventShareMode {
        get { CalendarEventShareMode(rawValue: shareModeRaw) ?? .personal }
        set { shareModeRaw = newValue.rawValue }
    }

    var participationStatus: CalendarEventParticipationStatus {
        get { CalendarEventParticipationStatus(rawValue: participationStatusRaw) ?? .owner }
        set { participationStatusRaw = newValue.rawValue }
    }

    init(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        allDay: Bool = false,
        eventDescription: String? = nil,
        color: String? = nil,
        meetingUrl: String? = nil,
        location: String? = nil,
        recurrenceRRule: String? = nil,
        timeZoneId: String? = nil,
        recurrence: RecurrenceRule? = nil,
        recurrenceExceptions: [String] = [],
        calendarId: String? = nil,
        serverId: String? = nil,
        localEventId: String = UUID().uuidString,
        notificationID: String = UUID().uuidString,
        syncState: CalendarEventSyncState = .newLocal,
        isRecurringSeriesMaster: Bool = false,
        isRecurrenceException: Bool = false,
        isCancelledOccurrence: Bool = false,
        parentSeriesLocalId: String? = nil,
        splitFromSeriesLocalId: String? = nil,
        originalOccurrenceDate: Date? = nil,
        splitEffectiveFrom: Date? = nil,
        exceptionKind: RecurrenceExceptionKind? = nil,
        isSharedEvent: Bool = false,
        isJoinable: Bool = false,
        shareMode: CalendarEventShareMode = .personal,
        participationStatus: CalendarEventParticipationStatus = .owner,
        ownerUserId: String? = nil,
        ownerDisplayName: String? = nil,
        joinCode: String = "",
        shareToken: String? = nil,
        shareURL: String? = nil,
        requiresApprovalToJoin: Bool = false,
        allowGuestsToInvite: Bool = false,
        allowGuestsToEdit: Bool = false,
        maxAttendees: Int? = nil,
        attendeeCount: Int = 0,
        joinDeadline: Date? = nil
    ) {
        self.localEventId = localEventId
        self.notificationID = notificationID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.allDay = allDay
        self.eventDescription = eventDescription
        self.color = color
        self.meetingUrl = meetingUrl
        self.location = location
        self.locationPlaceId = nil
        self.locationCoordsStorage = nil
        self.googleEventId = nil
        self.googleCalendarId = nil
        self.reminderServerId = nil
        self.calendarId = calendarId
        self.calendar = nil
        self.recurrenceRRule = recurrenceRRule
        self.timeZoneId = timeZoneId
        self.recurrenceStorage = nil
        self.recurrenceExceptionsStorage = "[]"
        self.serverId = serverId
        self.lastSyncedAt = nil
        self.externalLastModifiedAt = nil
        self.needsSync = true
        self.syncStateRaw = syncState.rawValue
        self.lastSyncedHash = nil
        self.lastExternalHash = nil
        self.appleCalendarItemIdentifier = nil
        self.appleCalendarIdentifier = nil
        self.isRecurringSeriesMaster = isRecurringSeriesMaster
        self.isRecurrenceException = isRecurrenceException
        self.isCancelledOccurrence = isCancelledOccurrence
        self.parentSeriesLocalId = parentSeriesLocalId
        self.splitFromSeriesLocalId = splitFromSeriesLocalId
        self.originalOccurrenceDate = originalOccurrenceDate
        self.splitEffectiveFrom = splitEffectiveFrom
        self.exceptionKindRaw = exceptionKind?.rawValue
        self.isSharedEvent = isSharedEvent
        self.isJoinable = isJoinable
        self.shareModeRaw = shareMode.rawValue
        self.participationStatusRaw = participationStatus.rawValue
        self.ownerUserId = ownerUserId
        self.ownerDisplayName = ownerDisplayName
        self.joinCode = joinCode
        self.shareToken = shareToken
        self.shareURL = shareURL
        self.requiresApprovalToJoin = requiresApprovalToJoin
        self.allowGuestsToInvite = allowGuestsToInvite
        self.allowGuestsToEdit = allowGuestsToEdit
        self.maxAttendees = maxAttendees
        self.attendeeCount = attendeeCount
        self.joinDeadline = joinDeadline
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recurrence = recurrence
        self.recurrenceExceptions = recurrenceExceptions
    }
}
