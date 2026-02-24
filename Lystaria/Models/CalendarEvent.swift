// CalendarEvent.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB Event schema

import Foundation
import SwiftData

// MARK: - Recurrence Types

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
}

enum RecurrenceEndKind: String, Codable {
    case never = "never"
    case until = "until"
    case count = "count"
}

/// Codable struct stored as JSON in SwiftData
struct RecurrenceEnd: Codable, Equatable, Sendable {
    var kind: RecurrenceEndKind
    var until: Date?
    var count: Int?
    
    static let never = RecurrenceEnd(kind: .never)
}

/// Codable struct stored as JSON in SwiftData
struct RecurrenceRule: Codable, Equatable, Sendable {
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
struct LocationCoords: Codable, Equatable, Sendable {
    var lat: Double
    var lng: Double
}

// MARK: - CalendarEvent Model

@Model
final class CalendarEvent {
    // MARK: - Sync metadata
    var serverId: String?
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var appleCalendarItemIdentifier: String? = nil
    var appleCalendarIdentifier: String? = nil
    
    // MARK: - Fields
    var title: String
    var eventDescription: String?    // 'description' is reserved in Swift
    var startDate: Date
    var endDate: Date?
    var allDay: Bool
    var color: String?
    var meetingUrl: String?
    var location: String?
    var locationPlaceId: String?
    
    // Store coords as JSON via Codable
    var locationCoords: LocationCoords?
    
    var googleEventId: String?
    var googleCalendarId: String?
    
    // Link to a reminder (by serverId)
    var reminderServerId: String?
    
    // RRULE string for recurrence support (no exception dates)
    var recurrenceRRule: String?

    // Time zone identifier used for displaying/scheduling this event
    var timeZoneId: String?

    // Recurrence (stored as JSON via Codable)
    var recurrence: RecurrenceRule?
    
    // NOTE: legacy field; not used by the RRULE-only recurrence approach
    var recurrenceExceptions: [String] = []     // ISO date keys like "2026-01-25"
    
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Computed
    var isRecurring: Bool {
        recurrence != nil
    }
    
    var displayColor: String {
        color ?? "#6C63FF"  // default purple
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
        serverId: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.allDay = allDay
        self.eventDescription = eventDescription
        self.color = color
        self.meetingUrl = meetingUrl
        self.location = location
        self.locationPlaceId = nil
        self.locationCoords = nil
        self.googleEventId = nil
        self.googleCalendarId = nil
        self.reminderServerId = nil
        self.recurrenceRRule = recurrenceRRule
        self.timeZoneId = timeZoneId
        self.recurrence = recurrence
        self.recurrenceExceptions = recurrenceExceptions
        self.serverId = serverId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
