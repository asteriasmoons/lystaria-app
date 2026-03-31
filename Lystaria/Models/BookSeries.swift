//
//  BookSeries.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class BookSeries {

    // MARK: - Identity
    var title: String = ""
    var summary: String = ""

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationship
    var books: [Book]? = nil

    // MARK: - Init
    init(
        title: String,
        summary: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.books = nil
    }
}
