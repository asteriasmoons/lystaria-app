//
//  ReadingStats.swift
//  Lystaria
//  SwiftData model — mirrors a MongoDB ReadingStats schema
//

import Foundation
import SwiftData

@Model
final class ReadingStats {
    // MARK: - Fields
    var userId: String = ""
    var streakDays: Int = 0
    var bestStreakDays: Int = 0
    var lastCheckInDate: Date? = nil
    var checkInHistory: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        userId: String = "",
        streakDays: Int = 0,
        bestStreakDays: Int = 0,
        lastCheckInDate: Date? = nil,
        checkInHistory: [String] = []
    ) {
        self.userId = userId
        self.streakDays = max(streakDays, 0)
        self.bestStreakDays = max(bestStreakDays, 0)
        self.lastCheckInDate = lastCheckInDate
        self.checkInHistory = checkInHistory
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
