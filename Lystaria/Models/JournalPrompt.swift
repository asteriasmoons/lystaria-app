//
//  JournalPrompt.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/16/26.
//

import Foundation
import SwiftData

@Model
final class JournalPrompt {
    var deletedAt: Date?

    // MARK: - Relationship
    var book: JournalBook?

    // MARK: - Fields
    var text: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        text: String,
        book: JournalBook? = nil,
        deletedAt: Date? = nil
    ) {
        self.text = text
        self.book = book
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
