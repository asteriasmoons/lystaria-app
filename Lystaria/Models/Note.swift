//
//  Note.swift
//  Lystaria
//
//  Created by Asteria Moon on 4/2/26.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()

    // Main content
    var content: String = ""
    var colorHex: String = "#F8E58C"

    // Markers
    var isPinned: Bool = false
    var isFavorite: Bool = false

    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        content: String = "",
        colorHex: String = "#F8E58C",
        isPinned: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.colorHex = colorHex
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Call this whenever content changes
    func touch() {
        updatedAt = Date()
    }

    // Cleaned content (for safety checks)
    var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Prevent saving empty notes if you want
    var isEmpty: Bool {
        trimmedContent.isEmpty
    }

    // Used for sticky note preview cards
    var previewText: String {
        trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
    }
}
