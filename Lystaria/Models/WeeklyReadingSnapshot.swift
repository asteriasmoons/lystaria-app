//
//  WeeklyReadingSnapshot.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class WeeklyReadingSnapshot {
    var userId: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var totalProgress: Int = 0
    var goalTarget: Int = 0
    var metGoal: Bool = false
    var goalMetricRaw: String = ReadingGoalMetric.pages.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var goalMetric: ReadingGoalMetric {
        get { ReadingGoalMetric(rawValue: goalMetricRaw) ?? .pages }
        set { goalMetricRaw = newValue.rawValue }
    }

    init(
        userId: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        totalProgress: Int = 0,
        goalTarget: Int = 0,
        metGoal: Bool = false,
        goalMetric: ReadingGoalMetric = .pages,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = Calendar.current.startOfDay(for: endDate)
        self.totalProgress = max(totalProgress, 0)
        self.goalTarget = max(goalTarget, 0)
        self.metGoal = metGoal
        self.goalMetricRaw = goalMetric.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
