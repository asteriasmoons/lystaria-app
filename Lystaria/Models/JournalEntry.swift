// JournalEntry.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB JournalEntry schema

import Foundation
import UIKit
import SwiftData

@Model
final class JournalEntry {
    var deletedAt: Date?

    // MARK: - Relationship
    var book: JournalBook?

    // MARK: - Fields
    var title: String = ""
    var body: String = ""
    var bodyData: Data?
    var tagsStorage: String = "[]"

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var tags: [String] {
        get {
            guard let data = tagsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                tagsStorage = encoded
            } else {
                tagsStorage = "[]"
            }
        }
    }

    var bodyAttributedText: NSAttributedString {
        get {
            if let bodyData, !bodyData.isEmpty {
                let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: bodyData)
                unarchiver?.requiresSecureCoding = false
                let attributed = unarchiver?.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
                unarchiver?.finishDecoding()
                if let attributed {
                    return attributed
                }
            }
            return NSAttributedString(string: body)
        }
        set {
            self.bodyData = try? NSKeyedArchiver.archivedData(
                withRootObject: newValue,
                requiringSecureCoding: false
            )
            self.body = newValue.string
            self.updatedAt = Date()
        }
    }

    init(
        title: String = "",
        bodyAttributedText: NSAttributedString = NSAttributedString(string: ""),
        tags: [String] = [],
        book: JournalBook? = nil,
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.body = bodyAttributedText.string
        self.bodyData = try? NSKeyedArchiver.archivedData(
            withRootObject: bodyAttributedText,
            requiringSecureCoding: false
        )
        self.tagsStorage = "[]"
        self.book = book
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
}
