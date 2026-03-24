//
//  ReadingGoal.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/20/26.
//

import Foundation
import SwiftData

enum ReadingGoalPeriod: String, CaseIterable, Codable {
    case daily
    case weekly
    case monthly
    case yearly

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum ReadingGoalMetric: String, CaseIterable, Codable {
    case minutes
    case hours
    case pages
    case books

    var label: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        case .pages: return "Pages"
        case .books: return "Books"
        }
    }
}

@Model
final class ReadingGoal {
    var userId: String = ""
    var isActive: Bool = true
    var periodRaw: String = ReadingGoalPeriod.weekly.rawValue
    var metricRaw: String = ReadingGoalMetric.pages.rawValue
    var targetValue: Int = 0
    var progressValue: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        userId: String = "",
        isActive: Bool = true,
        period: ReadingGoalPeriod = .weekly,
        metric: ReadingGoalMetric = .pages,
        targetValue: Int = 0,
        progressValue: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.isActive = isActive
        self.periodRaw = period.rawValue
        self.metricRaw = metric.rawValue
        self.targetValue = targetValue
        self.progressValue = progressValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var period: ReadingGoalPeriod {
        get { ReadingGoalPeriod(rawValue: periodRaw) ?? .weekly }
        set { periodRaw = newValue.rawValue }
    }

    var metric: ReadingGoalMetric {
        get { ReadingGoalMetric(rawValue: metricRaw) ?? .pages }
        set { metricRaw = newValue.rawValue }
    }
}
