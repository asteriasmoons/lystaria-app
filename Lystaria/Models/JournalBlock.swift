//
//  JournalBlock.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import SwiftData

enum JournalBlockType: String, Codable, CaseIterable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case blockquote
    case callout
    case divider
    case code

    // Lists & Toggles
    case toggle
    case bulletedList
    case numberedList
}

@Model
final class JournalBlock {
    var id: UUID = UUID()

    // CloudKit-safe defaults
    var typeRaw: String = JournalBlockType.paragraph.rawValue
    var text: String = ""
    var sortOrder: Int = 0

    // Structure for real lists & toggles
    var parentBlockID: UUID? = nil
    var listGroupID: UUID? = nil
    var isExpanded: Bool = true
    var indentLevel: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Optional metadata, but stored CloudKit-safe with defaults
    var calloutEmoji: String = ""
    var languageHint: String = ""

    var entry: JournalEntry?

    var inlineStyles: [JournalInlineStyle]? = nil

    init(
        type: JournalBlockType = .paragraph,
        text: String = "",
        sortOrder: Int = 0,
        parentBlockID: UUID? = nil,
        listGroupID: UUID? = nil,
        isExpanded: Bool = true,
        indentLevel: Int = 0,
        calloutEmoji: String = "",
        languageHint: String = ""
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.text = text
        self.sortOrder = sortOrder
        self.parentBlockID = parentBlockID
        self.listGroupID = listGroupID
        self.isExpanded = isExpanded
        self.indentLevel = indentLevel
        self.createdAt = Date()
        self.updatedAt = Date()
        self.calloutEmoji = calloutEmoji
        self.languageHint = languageHint
    }

    var type: JournalBlockType {
        get { JournalBlockType(rawValue: typeRaw) ?? .paragraph }
        set { typeRaw = newValue.rawValue }
    }

    var isListBlock: Bool {
        switch type {
        case .bulletedList, .numberedList:
            return true
        default:
            return false
        }
    }

    var isToggleBlock: Bool {
        type == .toggle
    }

    var sortedInlineStyles: [JournalInlineStyle] {
        (inlineStyles ?? []).sorted {
            if $0.rangeLocation == $1.rangeLocation {
                return $0.rangeLength < $1.rangeLength
            }
            return $0.rangeLocation < $1.rangeLocation
        }
    }

    func touch() {
        updatedAt = Date()
    }
}
