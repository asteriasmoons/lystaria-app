//
//  DocumentBook.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import Foundation
import SwiftData

@Model
final class DocumentBook {
    var deletedAt: Date?

    // MARK: - Fields
    var uuid: UUID = UUID()
    var title: String = ""
    var coverHex: String = "#6A5CFF"
    var pinOrder: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \DocumentEntry.book)
    var entries: [DocumentEntry]?

    @Relationship(deleteRule: .cascade, inverse: \DocumentFolder.book)
    var folders: [DocumentFolder]?

    init(
        title: String,
        coverHex: String = "#6A5CFF",
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.coverHex = coverHex
        self.pinOrder = 0
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.entries = nil
        self.folders = nil
    }
}
