//
//  LogMoodIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import AppIntents
import SwiftData

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description = IntentDescription("Create a new mood log in Lystaria.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Mood")
    var moods: [MoodIntentValue]

    @Parameter(title: "Activities")
    var activities: [MoodActivityIntentValue]

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$moods) with \(\.$activities) and \(\.$note)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !moods.isEmpty else {
            throw $moods.needsValueError("Choose at least one mood.")
        }

        let moodStrings = moods.map(\.rawValue)
        let activityStrings = activities.map(\.rawValue)

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)

            try MoodLogWriter.saveMoodLog(
                moods: moodStrings,
                activities: activityStrings,
                note: note,
                modelContext: context
            )
        }

        let moodNames = moods.map {
            String(localized: MoodIntentValue.caseDisplayRepresentations[$0]?.title ?? LocalizedStringResource(stringLiteral: $0.rawValue.capitalized))
        }

        return .result(
            dialog: IntentDialog("Logged mood: \(moodNames.joined(separator: ", ")).")
        )
    }
}
