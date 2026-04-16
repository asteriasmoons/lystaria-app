//
//  SharedEventDTO.swift
//  Lystaria
//

import Foundation

// MARK: - Shared Event DTOs

struct SharedEventDTO: Codable, Identifiable {
    let id: String
    let localEventId: String
    let ownerUserId: String
    let ownerDisplayName: String

    let title: String
    let startDate: String
    let endDate: String?
    let allDay: Bool

    let eventDescription: String?
    let color: String?
    let meetingUrl: String?
    let location: String?
    let recurrenceRRule: String?
    let timeZoneId: String?
    let calendarId: String?
    let serverId: String?

    let isSharedEvent: Bool
    let isJoinable: Bool
    let shareMode: String
    let requiresApprovalToJoin: Bool
    let allowGuestsToInvite: Bool
    let allowGuestsToEdit: Bool

    let joinCode: String
    let attendeeCount: Int

    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case localEventId
        case ownerUserId
        case ownerDisplayName
        case title
        case startDate
        case endDate
        case allDay
        case eventDescription
        case color
        case meetingUrl
        case location
        case recurrenceRRule
        case timeZoneId
        case calendarId
        case serverId
        case isSharedEvent
        case isJoinable
        case shareMode
        case requiresApprovalToJoin
        case allowGuestsToInvite
        case allowGuestsToEdit
        case joinCode
        case attendeeCount
        case createdAt
        case updatedAt
    }
}

struct SharedEventAttendeeDTO: Codable, Identifiable {
    let id: String
    let eventId: String
    let eventLocalId: String
    let userId: String
    let displayName: String
    let status: String
    let isHost: Bool
    let invitedAt: String
    let joinedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case eventId
        case eventLocalId
        case userId
        case displayName
        case status
        case isHost
        case invitedAt
        case joinedAt
        case createdAt
        case updatedAt
    }
}

// MARK: - Response DTOs

struct SharedEventResponseDTO: Codable {
    let success: Bool
    let event: SharedEventDTO
    let attendees: [SharedEventAttendeeDTO]
    let currentUserAttendee: SharedEventAttendeeDTO?
}

struct SharedEventAttendeesResponseDTO: Codable {
    let success: Bool
    let attendees: [SharedEventAttendeeDTO]
}

struct SharedEventErrorResponseDTO: Codable {
    let success: Bool?
    let error: String?
}

// MARK: - Request DTOs

struct CreateSharedEventRequestDTO: Codable {
    let ownerUserId: String
    let ownerDisplayName: String
    let localEventId: String
    let title: String
    let startDate: String
    let endDate: String?
    let allDay: Bool
    let eventDescription: String?
    let color: String?
    let meetingUrl: String?
    let location: String?
    let recurrenceRRule: String?
    let timeZoneId: String?
    let calendarId: String?
    let serverId: String?
    let isJoinable: Bool
    let shareMode: String
    let requiresApprovalToJoin: Bool
    let allowGuestsToInvite: Bool
    let allowGuestsToEdit: Bool
}

struct JoinSharedEventByCodeRequestDTO: Codable {
    let joinCode: String
    let userId: String
    let displayName: String
}

struct InviteSharedEventAttendeeRequestDTO: Codable {
    let actorUserId: String
    let inviteeUserId: String
    let inviteeDisplayName: String
}

struct AcceptSharedEventInviteRequestDTO: Codable {
    let userId: String
    let displayName: String
}

struct LeaveSharedEventRequestDTO: Codable {
    let userId: String
}

struct UpdateSharedEventRequestDTO: Codable {
    let actorUserId: String
    let title: String?
    let startDate: String?
    let endDate: String?
    let allDay: Bool?
    let eventDescription: String?
    let color: String?
    let meetingUrl: String?
    let location: String?
    let recurrenceRRule: String?
    let timeZoneId: String?
    let calendarId: String?
    let serverId: String?
    let isJoinable: Bool?
    let shareMode: String?
    let requiresApprovalToJoin: Bool?
    let allowGuestsToInvite: Bool?
    let allowGuestsToEdit: Bool?
}
