//
// UserSettings.swift
// Lystaria
//

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

    // Reading tab default status filter.
    // Stores BookStatus.rawValue, or "" for "All" (nil filter).
    var readingDefaultStatusFilter: String = ""

    // Apple Calendar sync — stores the EKCalendar.calendarIdentifier the user
    // chose to sync with. Empty string means no calendar selected.
    var calendarSyncSelectedIdentifier: String = ""

    // Sleep goal in hours.
    var sleepGoalHours: Double = 8

    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Optional future sync flag
    var needsSync: Bool = false

    init(
        serverId: String? = nil,
        useSystemTimezone: Bool = true,
        timezoneIdentifier: String = TimeZone.current.identifier,
        readingDefaultStatusFilter: String = "",
        needsSync: Bool = false
    ) {
        self.serverId = serverId
        self.useSystemTimezone = useSystemTimezone
        self.timezoneIdentifier = timezoneIdentifier
        self.readingDefaultStatusFilter = readingDefaultStatusFilter
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }

    // Computed convenience
    var effectiveTimezoneIdentifier: String {
        useSystemTimezone ? TimeZone.current.identifier : timezoneIdentifier
    }

    // Computed convenience for reading filter
    var readingDefaultStatus: BookStatus? {
        get { BookStatus(rawValue: readingDefaultStatusFilter) }
        set { readingDefaultStatusFilter = newValue?.rawValue ?? "" }
    }
}
