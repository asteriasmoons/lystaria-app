//
//  LogReadingSessionIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/31/26.
//

import AppIntents
import SwiftData

struct LogReadingSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Reading Session"
    static var description = IntentDescription("Log a reading session in Lystaria.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(title: "Start Page")
    var startPage: Int?

    @Parameter(title: "End Page")
    var endPage: Int?

    @Parameter(
        title: "Duration (minutes)",
        requestValueDialog: IntentDialog("How many minutes did you read?")
    )
    var minutesRead: Int

    @Parameter(
        title: "Date & Time",
        requestValueDialog: IntentDialog("What date and time should this reading session use?")
    )
    var sessionDate: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Log reading session") {
            \.$book
            \.$startPage
            \.$endPage
            \.$minutesRead
            \.$sessionDate
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard minutesRead > 0 else {
            throw $minutesRead.needsValueError("Enter a duration greater than zero.")
        }

        if let startPage, let endPage, endPage < startPage {
            return .result(dialog: IntentDialog("End page must be greater than or equal to start page."))
        }

        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)

            let descriptor = FetchDescriptor<Book>()
            let books = try context.fetch(descriptor)

            guard let realBook = books.first(where: {
                String(describing: $0.persistentModelID) == book.id
            }) else {
                throw NSError(domain: "BookNotFound", code: 1)
            }

            let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "local-user"

            try ReadingSessionWriter.saveSession(
                book: realBook,
                startPage: startPage,
                endPage: endPage,
                minutesRead: minutesRead,
                sessionDate: sessionDate,
                currentUserId: currentUserId,
                modelContext: context
            )
        }

        return .result(dialog: IntentDialog("Reading session logged."))
    }
}
