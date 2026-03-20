//
//  HealthMetricsWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
enum HealthMetricsWriter {
    static func createEntry(
        date: Date,
        bloodOxygen: Double,
        systolic: Int,
        diastolic: Int,
        bpm: Int,
        bodyTemperature: Double,
        weight: Double,
        modelContext: ModelContext
    ) throws -> HealthMetricEntry {
        let entry = HealthMetricEntry(
            date: date,
            bloodOxygen: bloodOxygen,
            systolic: systolic,
            diastolic: diastolic,
            bpm: bpm,
            bodyTemperature: bodyTemperature,
            weight: weight
        )

        modelContext.insert(entry)
        try modelContext.save()

        _ = try? SelfCarePointsManager.awardHealthLog(
            in: modelContext,
            healthEntryId: entry.id.uuidString,
            title: "Health Log",
            createdAt: entry.createdAt
        )

        try? modelContext.save()

        return entry
    }
}
