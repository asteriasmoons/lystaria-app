// UserSettings.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB UserSettings schema

import Foundation
import SwiftData

@Model
final class UserSettings {
    // Optional server sync id later (MongoDB settings doc id)
    var serverId: String?

    // If true: always use the device timezone (TimeZone.current.identifier)
    // If false: use timezoneIdentifier below.
    var useSystemTimezone: Bool = true

    // IANA timezone id like "America/Chicago"
    // Only used when useSystemTimezone == false
    var timezoneIdentifier: String = TimeZone.current.identifier

    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Optional future sync flag
    var needsSync: Bool = false

    init(
        serverId: String? = nil,
        useSystemTimezone: Bool = true,
        timezoneIdentifier: String = TimeZone.current.identifier,
        needsSync: Bool = false
    ) {
        self.serverId = serverId
        self.useSystemTimezone = useSystemTimezone
        self.timezoneIdentifier = timezoneIdentifier
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }

    // Computed convenience
    var effectiveTimezoneIdentifier: String {
        useSystemTimezone ? TimeZone.current.identifier : timezoneIdentifier
    }
}
