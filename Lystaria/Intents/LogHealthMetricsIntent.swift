//
//  LogHealthMetricsIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import AppIntents
import SwiftData

struct LogHealthMetricsIntent: AppIntent {
    static var title: LocalizedStringResource = "Health Metrics"
    static var description = IntentDescription("Log health metrics in Lystaria and save them to Apple Health.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Blood Oxygen (%)")
    var bloodOxygen: Double?

    @Parameter(title: "Systolic")
    var systolic: Int?

    @Parameter(title: "Diastolic")
    var diastolic: Int?

    @Parameter(title: "BPM")
    var bpm: Int?

    @Parameter(title: "Body Temperature (°F)")
    var bodyTemperature: Double?

    @Parameter(title: "Weight (lb)")
    var weight: Double?

    @Parameter(
        title: "Date & Time",
        requestValueDialog: IntentDialog("What date and time should these health metrics use?")
    )
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Log health metrics") {
            \.$bloodOxygen
            \.$systolic
            \.$diastolic
            \.$bpm
            \.$bodyTemperature
            \.$weight
            \.$date
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let finalBloodOxygen = bloodOxygen ?? 0
        let finalSystolic = systolic ?? 0
        let finalDiastolic = diastolic ?? 0
        let finalBpm = bpm ?? 0
        let finalBodyTemperature = bodyTemperature ?? 0
        let finalWeight = weight ?? 0
        let finalDate = date

        let hasAtLeastOneMetric =
            finalBloodOxygen > 0 ||
            finalSystolic > 0 ||
            finalDiastolic > 0 ||
            finalBpm > 0 ||
            finalBodyTemperature > 0 ||
            finalWeight > 0

        guard hasAtLeastOneMetric else {
            return .result(dialog: IntentDialog("Enter at least one health metric."))
        }

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            _ = try HealthMetricsWriter.createEntry(
                date: finalDate,
                bloodOxygen: finalBloodOxygen,
                systolic: finalSystolic,
                diastolic: finalDiastolic,
                bpm: finalBpm,
                bodyTemperature: finalBodyTemperature,
                weight: finalWeight,
                modelContext: context
            )
        }

        let healthKitEntry = HealthMetricEntry(
            date: finalDate,
            bloodOxygen: finalBloodOxygen,
            systolic: finalSystolic,
            diastolic: finalDiastolic,
            bpm: finalBpm,
            bodyTemperature: finalBodyTemperature,
            weight: finalWeight
        )

        let healthKitManager = await MainActor.run { HealthMetricsHealthKitManager.shared }

        do {
            try await healthKitManager.saveHealthMetricEntry(healthKitEntry)
        } catch {
            print("HealthKit save error:", error)
        }

        return .result(dialog: IntentDialog("Health metrics logged."))
    }
}
