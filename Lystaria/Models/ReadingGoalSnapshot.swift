//
//  ReadingGoalSnapshot.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class ReadingGoalSnapshot {
    var userId: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()

    /// Stored as Double so hours can be preserved as decimals.
    var totalProgress: Double = 0

    var goalTarget: Int = 0
    var metGoal: Bool = false

    var goalMetricRaw: String = ReadingGoalMetric.pages.rawValue
    var goalPeriodRaw: String = ReadingGoalPeriod.weekly.rawValue

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var goalMetric: ReadingGoalMetric {
        get { ReadingGoalMetric(rawValue: goalMetricRaw) ?? .pages }
        set { goalMetricRaw = newValue.rawValue }
    }

    var goalPeriod: ReadingGoalPeriod {
        get { ReadingGoalPeriod(rawValue: goalPeriodRaw) ?? .weekly }
        set { goalPeriodRaw = newValue.rawValue }
    }

    init(
        userId: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        totalProgress: Double = 0,
        goalTarget: Int = 0,
        metGoal: Bool = false,
        goalMetric: ReadingGoalMetric = .pages,
        goalPeriod: ReadingGoalPeriod = .weekly,
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
        self.goalPeriodRaw = goalPeriod.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
