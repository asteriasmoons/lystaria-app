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
    var folder: DocumentFolder?
    var blocks: [DocumentBlock]? = nil

    // MARK: - Fields
    var uuid: UUID = UUID()
    var title: String = ""
    var tagsStorage: String = "[]"
    var isNestedPage: Bool = false

    // MARK: - Background Appearance
    var backgroundModeRaw: String = DocumentEntryBackgroundMode.defaultLystaria.rawValue
    var backgroundColorHex: String = ""
    var backgroundGradientStartHex: String = ""
    var backgroundGradientEndHex: String = ""
    @Attribute(.externalStorage) var backgroundImageData: Data? = nil
    var backgroundImageOpacity: Double = 0.85
    var backgroundImageBlur: Double = 0.0
    var backgroundOverlayOpacity: Double = 0.35
    var textColorHex: String = ""

    // MARK: - Cover Image
    @Attribute(.externalStorage) var coverImageData: Data? = nil
    var coverImageVerticalOffset: Double = 0.0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var backgroundMode: DocumentEntryBackgroundMode {
        get { DocumentEntryBackgroundMode(rawValue: backgroundModeRaw) ?? .defaultLystaria }
        set {
            backgroundModeRaw = newValue.rawValue
            touch()
        }
    }

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
        folder: DocumentFolder? = nil,
        deletedAt: Date? = nil,
        isNestedPage: Bool = false
    ) {
        self.title = title
        self.tagsStorage = "[]"
        self.uuid = UUID()
        self.book = book
        self.folder = folder
        self.deletedAt = deletedAt
        self.isNestedPage = isNestedPage
        self.backgroundModeRaw = DocumentEntryBackgroundMode.defaultLystaria.rawValue
        self.backgroundColorHex = ""
        self.backgroundGradientStartHex = ""
        self.backgroundGradientEndHex = ""
        self.backgroundImageData = nil
        self.backgroundImageOpacity = 0.85
        self.backgroundImageBlur = 0.0
        self.backgroundOverlayOpacity = 0.35
        self.coverImageData = nil
        self.coverImageVerticalOffset = 0.0
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
            case .checklist:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let state = block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
                switch state {
                case "checked":
                    return "☑ \(t)"
                case "xmark":
                    return "☒ \(t)"
                default:
                    return "☐ \(t)"
                }
            case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .toggleHeading1, .toggleHeading2, .toggleHeading3,
                 .toggleHeading4, .toggleHeading5, .toggleHeading6:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "▸ \(t)"
            case .image:
                return block.imageData != nil ? "🖼️" : nil
            case .table:
                return nil
            case .page:
                return nil
            }
        }
        let joined = pieces.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(joined.prefix(300))
    }

    func touch() {
        updatedAt = Date()
    }
}

enum DocumentEntryBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case defaultLystaria
    case solidColor
    case gradient
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultLystaria:
            return "Default"
        case .solidColor:
            return "Color"
        case .gradient:
            return "Gradient"
        case .image:
            return "Image"
        }
    }
}
