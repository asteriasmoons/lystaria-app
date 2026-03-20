//
//  LogExerciseIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import AppIntents
import SwiftData

struct LogExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Exercise"
    static var description = IntentDescription("Log an exercise entry in Lystaria and save it to Apple Health.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Exercise Name",
        requestValueDialog: IntentDialog("What exercise would you like to log?")
    )
    var exerciseName: String

    @Parameter(
        title: "Reps",
        requestValueDialog: IntentDialog("How many reps did you do?")
    )
    var reps: Int

    @Parameter(
        title: "Duration (minutes)",
        requestValueDialog: IntentDialog("How many minutes did the exercise last?")
    )
    var durationMinutes: Int

    @Parameter(
        title: "Date & Time",
        requestValueDialog: IntentDialog("What date and time should this exercise use?")
    )
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Log exercise") {
            \.$exerciseName
            \.$reps
            \.$durationMinutes
            \.$date
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReps = reps
        let finalDuration = durationMinutes
        let finalDate = date

        guard !trimmedName.isEmpty else {
            throw $exerciseName.needsValueError("Enter an exercise name.")
        }

        guard finalDuration > 0 else {
            throw $durationMinutes.needsValueError("Enter a duration greater than zero.")
        }

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            _ = try ExerciseLogWriter.createEntry(
                date: finalDate,
                exerciseName: trimmedName,
                reps: finalReps,
                durationMinutes: finalDuration,
                modelContext: context
            )
        }

        let healthKitEntry = ExerciseLogEntry(
            date: finalDate,
            exerciseName: trimmedName,
            reps: finalReps,
            durationMinutes: finalDuration
        )

        let healthKitManager = await MainActor.run { ExerciseHealthKitManager.shared }

        do {
            try await healthKitManager.saveExerciseLogEntry(healthKitEntry)
        } catch {
            print("Exercise HealthKit save error:", error)
        }

        return .result(dialog: IntentDialog("Exercise logged."))
    }
}
