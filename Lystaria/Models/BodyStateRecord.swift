//
//  BodyStateRecord.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class BodyStateRecord {
    var id: UUID = UUID()

    // Sync-safe timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var timestamp: Date = Date()

    // Stored output of the classifier
    var bodyScore: Double = 0
    var nervousSystemScore: Double = 0

    var bodyLabel: String = ""
    var nervousSystemLabel: String = ""

    // Source values used to compute the state
    var latestHRV: Double = 0
    var baselineHRV: Double = 0
    var latestHeartRate: Double = 0
    var restingHeartRate: Double = 0

    // Flags so 0 doesn’t ambiguously mean “missing”
    var hasLatestHRV: Bool = false
    var hasBaselineHRV: Bool = false
    var hasLatestHeartRate: Bool = false
    var hasRestingHeartRate: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        timestamp: Date = Date(),
        bodyScore: Double = 0,
        nervousSystemScore: Double = 0,
        bodyLabel: String = "",
        nervousSystemLabel: String = "",
        latestHRV: Double = 0,
        baselineHRV: Double = 0,
        latestHeartRate: Double = 0,
        restingHeartRate: Double = 0,
        hasLatestHRV: Bool = false,
        hasBaselineHRV: Bool = false,
        hasLatestHeartRate: Bool = false,
        hasRestingHeartRate: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.timestamp = timestamp
        self.bodyScore = bodyScore
        self.nervousSystemScore = nervousSystemScore
        self.bodyLabel = bodyLabel
        self.nervousSystemLabel = nervousSystemLabel
        self.latestHRV = latestHRV
        self.baselineHRV = baselineHRV
        self.latestHeartRate = latestHeartRate
        self.restingHeartRate = restingHeartRate
        self.hasLatestHRV = hasLatestHRV
        self.hasBaselineHRV = hasBaselineHRV
        self.hasLatestHeartRate = hasLatestHeartRate
        self.hasRestingHeartRate = hasRestingHeartRate
    }
}
