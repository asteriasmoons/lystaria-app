//
//  EventAttendee.swift
//  Lystaria
//

import Foundation
import SwiftData

enum EventAttendeeStatus: String, CaseIterable {
    case invited = "invited"
    case joined = "joined"
    case declined = "declined"
    case maybe = "maybe"
    case left = "left"
}

extension EventAttendeeStatus: Codable {}

@Model
final class EventAttendee {
    var id: UUID = UUID()
    
    /// Links this attendee to a CalendarEvent (by localEventId)
    var eventLocalId: String = ""
    
    /// Unique identifier for the user (CloudKit user ID or your own ID system later)
    var userId: String = ""
    
    /// Display name for UI
    var displayName: String = ""
    
    /// Status stored as raw string
    var statusRaw: String = EventAttendeeStatus.invited.rawValue
    
    /// Whether this attendee is the host/owner
    var isHost: Bool = false
    
    var invitedAt: Date = Date()
    var joinedAt: Date?
    
    // MARK: - Computed
    
    var status: EventAttendeeStatus {
        get { EventAttendeeStatus(rawValue: statusRaw) ?? .invited }
        set { statusRaw = newValue.rawValue }
    }
    
    // MARK: - Init
    
    init(
        eventLocalId: String,
        userId: String,
        displayName: String,
        status: EventAttendeeStatus = .invited,
        isHost: Bool = false,
        invitedAt: Date = Date(),
        joinedAt: Date? = nil
    ) {
        self.eventLocalId = eventLocalId
        self.userId = userId
        self.displayName = displayName
        self.statusRaw = status.rawValue
        self.isHost = isHost
        self.invitedAt = invitedAt
        self.joinedAt = joinedAt
    }
}
