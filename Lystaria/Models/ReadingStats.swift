// ReadingStats.swift
// Lystaria
// SwiftData model — mirrors a MongoDB ReadingStats schema

import Foundation
import SwiftData

@Model
final class ReadingStats {
    // MARK: - Sync metadata
    var serverId: String?           // MongoDB _id
    var lastSyncedAt: Date?
    var needsSync: Bool = true      // true = has local changes to push

    // MARK: - Fields
    var userId: String              // scope per user
    var streakDays: Int
    var lastCheckInDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        userId: String,
        streakDays: Int = 0,
        lastCheckInDate: Date? = nil,
        serverId: String? = nil
    ) {
        self.userId = userId
        self.streakDays = max(streakDays, 0)
        self.lastCheckInDate = lastCheckInDate
        self.serverId = serverId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
