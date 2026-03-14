//
//  JournalBookEntity.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/13/26.
//

import AppIntents
import SwiftData

struct JournalBookEntity: AppEntity {

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journal Book")

    static var defaultQuery = JournalBookQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(book: JournalBook) {
        self.id = String(describing: book.persistentModelID)
        self.title = book.title
    }
}

struct JournalBookQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [JournalBookEntity] {
        return try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<JournalBook>()
            let books = try context.fetch(descriptor)

            return books
                .filter { identifiers.contains(String(describing: $0.persistentModelID)) }
                .map { JournalBookEntity(book: $0) }
        }
    }

    func suggestedEntities() async throws -> [JournalBookEntity] {
        return try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<JournalBook>(
                predicate: #Predicate { $0.deletedAt == nil }
            )
            let books = try context.fetch(descriptor)

            return books.map { JournalBookEntity(book: $0) }
        }
    }
}
