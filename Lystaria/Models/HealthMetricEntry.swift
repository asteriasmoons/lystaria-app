//
//  HealthMetricEntry.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import Foundation
import SwiftData

@Model
final class HealthMetricEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var createdAt: Date = Date()

    // Health Metrics
    var bloodOxygen: Double = 0
    var systolic: Int = 0
    var diastolic: Int = 0
    var bpm: Int = 0
    var bodyTemperature: Double = 0
    var weight: Double = 0

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        createdAt: Date = Date(),
        bloodOxygen: Double = 0,
        systolic: Int = 0,
        diastolic: Int = 0,
        bpm: Int = 0,
        bodyTemperature: Double = 0,
        weight: Double = 0
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.bloodOxygen = bloodOxygen
        self.systolic = systolic
        self.diastolic = diastolic
        self.bpm = bpm
        self.bodyTemperature = bodyTemperature
        self.weight = weight
    }
}
