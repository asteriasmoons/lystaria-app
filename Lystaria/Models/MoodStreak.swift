//
//  MoodStreak.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/21/26.
//

import Foundation
import SwiftData

@Model
final class MoodStreak {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core Streak Data

    /// Current streak count (days in a row)
    var currentStreak: Int = 0

    /// Best streak achieved (longest run of consecutive days)
    var bestStreak: Int = 0

    /// Last day a mood was logged (used to calculate streak)
    var lastLogDate: Date? = nil

    // MARK: - History (for future / analytics if needed)

    /// Stores all days that contributed to streak history
    /// (kept simple + CloudKit-safe)
    var streakDates: [Date] = []

    // MARK: - Init

    init(
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastLogDate: Date? = nil,
        streakDates: [Date] = []
    ) {
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastLogDate = lastLogDate
        self.streakDates = streakDates
    }
}
