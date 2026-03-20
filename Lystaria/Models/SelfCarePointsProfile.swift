//
//  SelfCarePointsProfile.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class SelfCarePointsProfile {
    var id: UUID = UUID()

    /// Matches your app's resolved active user id.
    var userId: String = ""

    /// Points currently available if you ever want redemption later.
    var currentPoints: Int = 0

    /// Total points earned across all time.
    var lifetimePoints: Int = 0

    /// Total points spent/redeemed across all time.
    var spentPoints: Int = 0

    /// Current level derived from lifetime points.
    var level: Int = 1

    /// Last time any points were earned.
    var lastEarnedAt: Date? = nil
    var lastWeeklyResetAt: Date? = nil
    var currentWeekStartDayKey: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        userId: String = "",
        currentPoints: Int = 0,
        lifetimePoints: Int = 0,
        spentPoints: Int = 0,
        level: Int = 1,
        lastEarnedAt: Date? = nil,
        lastWeeklyResetAt: Date? = nil,
        currentWeekStartDayKey: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.currentPoints = max(0, currentPoints)
        self.lifetimePoints = max(0, lifetimePoints)
        self.spentPoints = max(0, spentPoints)
        self.level = max(1, level)
        self.lastEarnedAt = lastEarnedAt
        self.lastWeeklyResetAt = lastWeeklyResetAt
        self.currentWeekStartDayKey = currentWeekStartDayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
