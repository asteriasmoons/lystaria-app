//
//  JournalEntryIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/13/26.
//

import AppIntents
import SwiftData

struct AddJournalEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Journal Entry"
    static var description = IntentDescription("Create a new journal entry in Lystaria.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: JournalBookEntity

    @Parameter(title: "Title")
    var titleText: String

    @Parameter(title: "Tags")
    var tagsText: String?

    @Parameter(
        title: "Content",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add journal entry") {
            \.$book
            \.$titleText
            \.$tagsText
            \.$content
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {

        try await MainActor.run {

            let context = ModelContext(LystariaApp.sharedModelContainer)

            let descriptor = FetchDescriptor<JournalBook>()

            let books = try context.fetch(descriptor)

            guard let realBook = books.first(where: {
                String(describing: $0.persistentModelID) == book.id
            }) else {
                throw NSError(domain: "JournalBookNotFound", code: 1)
            }

            let parsedTags = (tagsText ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            try JournalEntryWriter.saveEntry(
                title: titleText,
                content: content,
                tags: parsedTags,
                book: realBook,
                modelContext: context
            )
        }

        return .result(dialog: IntentDialog("Journal entry saved."))
    }
}
