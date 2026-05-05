//
//  DocumentEntry.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import Foundation
import SwiftData

@Model
final class DocumentEntry {
    var deletedAt: Date?

    // MARK: - Relationship
    var book: DocumentBook?
    var blocks: [DocumentBlock]? = nil

    // MARK: - Fields
    var title: String = ""
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

    init(
        title: String = "",
        tags: [String] = [],
        book: DocumentBook? = nil,
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.tagsStorage = "[]"
        self.book = book
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }

    var sortedBlocks: [DocumentBlock] {
        (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    func ensureStarterBlock() {
        if blocks == nil { blocks = [] }
        if blocks?.isEmpty != false {
            let block = DocumentBlock(type: .paragraph, text: "", sortOrder: 0)
            block.entry = self
            blocks?.append(block)
        }
    }

    func normalizeBlockSortOrders() {
        let all = (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
        var ordered: [DocumentBlock] = []
        var visited = Set<UUID>()

        func append(_ block: DocumentBlock) {
            guard !visited.contains(block.id) else { return }
            visited.insert(block.id)
            ordered.append(block)
            let children = all.filter { $0.parentBlockID == block.id }
            for child in children { append(child) }
        }

        for block in all where block.parentBlockID == nil { append(block) }
        for block in all where !visited.contains(block.id) {
            block.parentBlockID = nil
            append(block)
        }

        for (index, block) in ordered.enumerated() {
            block.sortOrder = index
            block.touch()
        }
    }

    // Plain-text preview for page cards
    var blockPreviewText: String {
        let pieces = sortedBlocks.compactMap { block -> String? in
            switch block.type {
            case .divider:
                return nil
            case .blockquote:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .callout:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .code:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .toggle:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "▸ \(t)"
            case .bulletedList:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "• \(t)"
            case .numberedList:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .paragraph, .heading1, .heading2, .heading3, .heading4:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .image:
                return block.imageData != nil ? "🖼️" : nil
            }
        }
        let joined = pieces.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(joined.prefix(300))
    }
}
