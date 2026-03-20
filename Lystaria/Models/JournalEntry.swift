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

    var blocks: [JournalBlock]? = nil

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
    
    var sortedBlocks: [JournalBlock] {
        (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    func ensureStarterBlock() {
        if blocks == nil {
            blocks = []
        }

        if blocks?.isEmpty != false {
            let block = JournalBlock(type: .paragraph, text: "", sortOrder: 0)
            block.entry = self
            blocks?.append(block)
        }
    }

    func normalizeBlockSortOrders() {
        // Build a correctly ordered list that places each block's children
        // immediately after it, so visibleBlocks can walk sequentially and
        // correctly hide/show toggle children.
        let all = (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }

        var ordered: [JournalBlock] = []
        var visited = Set<UUID>()

        func append(_ block: JournalBlock) {
            guard !visited.contains(block.id) else { return }
            visited.insert(block.id)
            ordered.append(block)
            // Append direct children in their current sort order
            let children = all.filter { $0.parentBlockID == block.id }
            for child in children {
                append(child)
            }
        }

        // Start with root blocks (no parent)
        for block in all where block.parentBlockID == nil {
            append(block)
        }

        // Catch any orphaned blocks whose parent no longer exists
        for block in all where !visited.contains(block.id) {
            block.parentBlockID = nil
            append(block)
        }

        for (index, block) in ordered.enumerated() {
            block.sortOrder = index
            block.touch()
        }
    }
}
