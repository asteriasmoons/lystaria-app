//
//  BookmarkItem.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

@Model
final class BookmarkItem {
    var title: String = ""
    var bookmarkDescription: String = ""
    var link: String = ""
    var tagsRaw: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship var folder: BookmarkFolder?

    init(
        title: String = "",
        bookmarkDescription: String = "",
        link: String = "",
        tagsRaw: String = "",
        notes: String = "",
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        folder: BookmarkFolder? = nil
    ) {
        self.title = title
        self.bookmarkDescription = bookmarkDescription
        self.link = link
        self.tagsRaw = tagsRaw
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folder = folder
    }

    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }

    var normalizedLink: String {
        link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var hostDisplay: String {
        guard
            let url = URL(string: normalizedWebURLString),
            let host = url.host,
            !host.isEmpty
        else {
            return ""
        }

        return host.replacingOccurrences(of: "www.", with: "")
    }

    var normalizedWebURLString: String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        } else {
            return "https://\(trimmed)"
        }
    }
}
