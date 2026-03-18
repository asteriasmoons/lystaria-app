//
//  MoodLogWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation
import SwiftData

@MainActor
enum MoodLogWriter {
    static func saveMoodLog(
        moods: [String],
        activities: [String],
        note: String?,
        modelContext: ModelContext
    ) throws {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote: String?
        if let trimmedNote, !trimmedNote.isEmpty {
            finalNote = trimmedNote
        } else {
            finalNote = nil
        }

        let log = MoodLog(
            moods: moods,
            activities: activities,
            note: finalNote
        )

        log.touchUpdated()
        modelContext.insert(log)
        try modelContext.save()
    }
}
