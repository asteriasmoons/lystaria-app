// JournalEntry.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB JournalEntry schema

import Foundation
import UIKit
import SwiftData

@Model
final class JournalEntry {
    // MARK: - Sync metadata (Supabase)
    var serverId: String?          // Supabase row id
    var userId: String?            // auth.uid() owner
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var deletedAt: Date?           // soft delete for sync

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

    // MARK: - Sync helpers
    func markDirty() {
        self.updatedAt = Date()
        self.needsSync = true
    }

    // MARK: - Rich text helpers
    //
    // Uses NSKeyedArchiver with requiringSecureCoding: FALSE so that all
    // attributes are preserved — bold/italic font traits, custom keys like
    // lystariaBlockquote, paragraph styles, links, underlines, everything.
    // requiringSecureCoding: true silently drops anything it can't verify.

    var bodyAttributedText: NSAttributedString {
        get {
            if let bodyData, !bodyData.isEmpty {
                // Must use manual unarchiver with requiresSecureCoding = false.
                // The convenience unarchivedObject(ofClass:from:) always enforces
                // secure coding, silently stripping custom attributes and font traits.
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
            self.markDirty()
        }
    }

    init(
        title: String = "",
        bodyAttributedText: NSAttributedString = NSAttributedString(string: ""),
        tags: [String] = [],
        book: JournalBook? = nil,
        serverId: String? = nil,
        userId: String? = nil,
        needsSync: Bool = true,
        lastSyncedAt: Date? = nil,
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
        self.serverId = serverId
        self.userId = userId
        self.needsSync = needsSync
        self.lastSyncedAt = lastSyncedAt
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
}
