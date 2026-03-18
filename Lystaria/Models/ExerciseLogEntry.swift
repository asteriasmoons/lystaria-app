//
//  ExerciseLogEntry.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import Foundation
import SwiftData

@Model
final class ExerciseLogEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var createdAt: Date = Date()

    // Exercise Info
    var exerciseName: String = ""
    var reps: Int = 0
    var durationMinutes: Int = 0

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        createdAt: Date = Date(),
        exerciseName: String = "",
        reps: Int = 0,
        durationMinutes: Int = 0
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.exerciseName = exerciseName
        self.reps = reps
        self.durationMinutes = durationMinutes
    }
}
