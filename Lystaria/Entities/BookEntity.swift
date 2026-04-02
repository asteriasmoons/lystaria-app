//
//  BookEntity.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/31/26.
//

import AppIntents
import SwiftData

struct BookEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    static var defaultQuery = BookEntityQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(book: Book) {
        self.id = String(describing: book.persistentModelID)
        self.title = book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Book" : book.title
    }
}

struct BookEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BookEntity] {
        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<Book>()
            let books = try context.fetch(descriptor)

            return books
                .filter {
                    $0.deletedAt == nil &&
                    identifiers.contains(String(describing: $0.persistentModelID))
                }
                .map { BookEntity(book: $0) }
        }
    }

    func suggestedEntities() async throws -> [BookEntity] {
        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let books = try context.fetch(descriptor)

            return books
                .filter { $0.deletedAt == nil }
                .map { BookEntity(book: $0) }
        }
    }
}
