//
//  WellnessWallAIInsight.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class WellnessWallAIInsight {
    var id: UUID = UUID()
    var dayStart: Date = Date()

    var journal: String?
    var water: String?
    var steps: String?
    var habits: String?

    var snapshotHash: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        dayStart: Date,
        journal: String?,
        water: String?,
        steps: String?,
        habits: String?,
        snapshotHash: String
    ) {
        self.id = UUID()
        self.dayStart = dayStart
        self.journal = journal
        self.water = water
        self.steps = steps
        self.habits = habits
        self.snapshotHash = snapshotHash
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
