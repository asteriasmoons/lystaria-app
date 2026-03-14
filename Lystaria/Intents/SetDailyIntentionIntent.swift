//
//  SetDailyIntentionIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import AppIntents
import SwiftData

struct SetDailyIntentionIntent: AppIntent {
    static var title: LocalizedStringResource = "Daily Intention"
    static var description = IntentDescription("Set today’s daily intention in Lystaria.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Intention",
        inputOptions: String.IntentInputOptions(multiline: true),
        requestValueDialog: IntentDialog("What would you like your daily intention to be?")
    )
    var intention: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set daily intention") {
            \.$intention
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw $intention.needsValueError("Enter an intention for today.")
        }

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            try DailyIntentionWriter.setTodayIntention(
                trimmed,
                modelContext: context
            )
        }

        return .result(dialog: IntentDialog("Daily intention saved."))
    }
}
