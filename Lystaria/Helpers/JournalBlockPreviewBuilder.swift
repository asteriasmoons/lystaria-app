//
//  JournalBlockPreviewBuilder.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation

extension JournalEntry {
    var blockPreviewText: String {
        let pieces = sortedBlocks.compactMap { block -> String? in
            switch block.type {
            case .divider:
                return "- - -"

            case .blockquote:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "> \(trimmed)"

            case .callout:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let emoji = block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
                return emoji.isEmpty ? trimmed : "\(emoji) \(trimmed)"

            case .code:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return trimmed

            case .toggle:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "▸ \(trimmed)"

            case .bulletedList:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "• \(trimmed)"

            case .numberedList:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "1. \(trimmed)"

            case .paragraph, .heading1, .heading2, .heading3, .heading4:
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed

            case .image:
                return block.imageData != nil ? "🖼️ Photo" : nil
            }
        }

        let joined = pieces.joined(separator: "\n")
        let cleaned = joined
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "" }
        return String(cleaned.prefix(200))
    }
}
