//
//  ExerciseLogWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
enum ExerciseLogWriter {
    static func createEntry(
        date: Date,
        exerciseName: String,
        reps: Int,
        durationMinutes: Int,
        modelContext: ModelContext
    ) throws -> ExerciseLogEntry {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)

        let entry = ExerciseLogEntry(
            date: date,
            exerciseName: trimmedName,
            reps: reps,
            durationMinutes: durationMinutes
        )

        modelContext.insert(entry)
        try modelContext.save()

        _ = try? SelfCarePointsManager.awardExerciseLog(
            in: modelContext,
            exerciseEntryId: entry.id.uuidString,
            title: trimmedName.isEmpty ? "Exercise Log" : trimmedName,
            createdAt: entry.createdAt
        )

        try? modelContext.save()

        return entry
    }
}
