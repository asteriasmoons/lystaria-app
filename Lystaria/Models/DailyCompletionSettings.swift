//
//  DailyCompletionSettings.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class DailyCompletionSettings {
    // MARK: - Identity
    /// Keep one row per user/profile for the completion arc settings.
    var key: String = "default"

    // MARK: - Goals used by the completion arc
    var waterGoalFlOz: Double = 80
    var stepGoal: Double = 5000

    // MARK: - Arc display
    var bubbleCount: Int = 12

    // MARK: - What counts toward completion
    var includeWater: Bool = true
    var includeSteps: Bool = true
    var includeMood: Bool = true
    var includeJournal: Bool = true

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        key: String = "default",
        waterGoalFlOz: Double = 80,
        stepGoal: Double = 5000,
        bubbleCount: Int = 12,
        includeWater: Bool = true,
        includeSteps: Bool = true,
        includeMood: Bool = true,
        includeJournal: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.waterGoalFlOz = waterGoalFlOz
        self.stepGoal = stepGoal
        self.bubbleCount = bubbleCount
        self.includeWater = includeWater
        self.includeSteps = includeSteps
        self.includeMood = includeMood
        self.includeJournal = includeJournal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touchUpdated() {
        updatedAt = Date()
    }

    static let defaultKey = "default"
}
