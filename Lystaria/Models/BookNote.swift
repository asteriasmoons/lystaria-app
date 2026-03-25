//
//  BookNote.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class BookNote {

    // MARK: - Relationships (CloudKit-safe: optional)
    var book: Book? = nil

    // MARK: - Core Fields
    var text: String = ""

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init
    init(
        book: Book? = nil,
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.book = book
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
