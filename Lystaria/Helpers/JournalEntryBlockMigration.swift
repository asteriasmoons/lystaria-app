//
//  JournalEntryBlockMigration.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData
import UIKit

enum JournalEntryBlockMigration {
    static func migrateIfNeeded(entry: JournalEntry) {
        guard (entry.blocks ?? []).isEmpty else { return }

        let attributed = entry.bodyAttributedText
        guard attributed.length > 0 else {
            let plain = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                let block = JournalBlock(type: .paragraph, text: plain, sortOrder: 0)
                block.entry = entry
                block.touch()
                if entry.blocks == nil {
                    entry.blocks = []
                }
                entry.blocks?.append(block)
            } else {
                entry.ensureStarterBlock()
            }
            return
        }

        let nsString = attributed.string as NSString
        var blockIndex = 0

        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, subRange, _, _ in
            guard subRange.location < attributed.length else { return }

            let paragraphText = nsString.substring(with: subRange)
            let trimmedText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)

            let isDivider = (attributed.attribute(
                NSAttributedString.Key("lystariaDivider"),
                at: subRange.location,
                effectiveRange: nil
            ) as? Bool) == true

            let isBlockquote = (attributed.attribute(
                NSAttributedString.Key("lystariaBlockquote"),
                at: subRange.location,
                effectiveRange: nil
            ) as? Bool) == true

            if isDivider {
                let block = JournalBlock(type: .divider, text: "", sortOrder: blockIndex)
                block.entry = entry
                block.touch()
                if entry.blocks == nil {
                    entry.blocks = []
                }
                entry.blocks?.append(block)
                blockIndex += 1
                return
            }

            guard !trimmedText.isEmpty else { return }

            let styleProbeIndex = min(subRange.location, max(0, attributed.length - 1))
            let blockType = detectBlockType(
                for: attributed,
                paragraphRange: subRange,
                trimmedText: trimmedText,
                isBlockquote: isBlockquote,
                styleProbeIndex: styleProbeIndex
            )

            let trimmedRange = trimmedCharacterRange(in: paragraphText as NSString)
            let sourceTextRange = NSRange(location: subRange.location + trimmedRange.location, length: trimmedRange.length)

            let block = JournalBlock(
                type: blockType,
                text: trimmedText,
                sortOrder: blockIndex,
                calloutEmoji: "",
                languageHint: ""
            )
            block.entry = entry
            block.touch()
            if entry.blocks == nil {
                entry.blocks = []
            }
            entry.blocks?.append(block)

            migrateInlineStyles(
                from: attributed,
                sourceRange: sourceTextRange,
                into: block
            )

            blockIndex += 1
        }

        if (entry.blocks ?? []).isEmpty {
            entry.ensureStarterBlock()
        }

        entry.normalizeBlockSortOrders()
    }

    private static func detectBlockType(
        for attributed: NSAttributedString,
        paragraphRange: NSRange,
        trimmedText: String,
        isBlockquote: Bool,
        styleProbeIndex: Int
    ) -> JournalBlockType {
        if isBlockquote {
            return .blockquote
        }

        let font = attributed.attribute(.font, at: styleProbeIndex, effectiveRange: nil) as? UIFont
        let pointSize = font?.pointSize ?? UIFont.systemFontSize
        let symbolicTraits = font?.fontDescriptor.symbolicTraits ?? []
        let isBold = symbolicTraits.contains(.traitBold)

        if isBold && pointSize >= 24 {
            return .heading1
        }

        if isBold && pointSize >= 18 {
            return .heading2
        }

        let lower = trimmedText.lowercased()
        if lower.hasPrefix("note:") || lower.hasPrefix("tip:") || lower.hasPrefix("remember:") {
            return .callout
        }

        return .paragraph
    }

    private static func trimmedCharacterRange(in text: NSString) -> NSRange {
        let raw = text as String
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return NSRange(location: 0, length: 0) }

        let startOffset = raw.distance(from: raw.startIndex, to: raw.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? raw.startIndex)
        let endIndex = raw.lastIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? raw.startIndex
        let endOffset = raw.distance(from: raw.startIndex, to: endIndex)

        return NSRange(location: startOffset, length: max(0, endOffset - startOffset + 1))
    }

    private static func migrateInlineStyles(
        from attributed: NSAttributedString,
        sourceRange: NSRange,
        into block: JournalBlock
    ) {
        guard sourceRange.length > 0 else { return }
        guard block.type != .divider, block.type != .code else { return }

        attributed.enumerateAttributes(in: sourceRange, options: []) { attributes, range, _ in
            let localRange = NSRange(location: range.location - sourceRange.location, length: range.length)
            guard localRange.location >= 0, localRange.length > 0 else { return }

            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits

                if traits.contains(.traitBold) {
                    appendInlineStyle(.bold, range: localRange, urlString: "", to: block)
                }

                if traits.contains(.traitItalic) {
                    appendInlineStyle(.italic, range: localRange, urlString: "", to: block)
                }
            }

            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                appendInlineStyle(.underline, range: localRange, urlString: "", to: block)
            }

            if let url = attributes[.link] as? URL {
                appendInlineStyle(.link, range: localRange, urlString: url.absoluteString, to: block)
            } else if let urlString = attributes[.link] as? String, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendInlineStyle(.link, range: localRange, urlString: urlString, to: block)
            }
        }
    }

    private static func appendInlineStyle(
        _ type: JournalInlineStyleType,
        range: NSRange,
        urlString: String,
        to block: JournalBlock
    ) {
        guard range.length > 0 else { return }

        let alreadyExists = (block.inlineStyles ?? []).contains {
            $0.type == type && $0.rangeLocation == range.location && $0.rangeLength == range.length && $0.urlString == urlString
        }
        guard !alreadyExists else { return }

        let style = JournalInlineStyle(
            type: type,
            rangeLocation: range.location,
            rangeLength: range.length,
            urlString: urlString
        )
        style.block = block
        style.touch()
        if block.inlineStyles == nil {
            block.inlineStyles = []
        }
        block.inlineStyles?.append(style)
    }

    static func migrateEntriesIfNeeded(_ entries: [JournalEntry], modelContext: ModelContext) {
        var changed = false

        for entry in entries {
            let before = (entry.blocks ?? []).count
            migrateIfNeeded(entry: entry)
            if (entry.blocks ?? []).count != before || !(entry.blocks ?? []).isEmpty {
                changed = true
            }
        }

        if changed {
            try? modelContext.save()
        }
    }
}
