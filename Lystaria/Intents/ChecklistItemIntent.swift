//
//  ChecklistItemIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import AppIntents
import SwiftData

struct AddChecklistItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Checklist Item"
    static var description = IntentDescription("Quickly add a new checklist item in Lystaria.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Item",
        inputOptions: String.IntentInputOptions(multiline: false),
        requestValueDialog: IntentDialog("What checklist item would you like to add?")
    )
    var itemText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add checklist item") {
            \.$itemText
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = itemText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw $itemText.needsValueError("Enter a checklist item.")
        }

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            try ChecklistItemWriter.addItem(
                text: trimmed,
                modelContext: context
            )
        }

        return .result(dialog: IntentDialog("Checklist item added."))
    }
}
