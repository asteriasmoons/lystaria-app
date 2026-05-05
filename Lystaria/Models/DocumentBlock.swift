//
//  DocumentBlock.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import Foundation
import SwiftData

enum DocumentBlockType: String, Codable, CaseIterable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case blockquote
    case callout
    case divider
    case code
    case image
    case toggle
    case bulletedList
    case numberedList
}

@Model
final class DocumentBlock {
    var id: UUID = UUID()

    var typeRaw: String = DocumentBlockType.paragraph.rawValue
    var text: String = ""
    var sortOrder: Int = 0

    var parentBlockID: UUID? = nil
    var listGroupID: UUID? = nil
    var isExpanded: Bool = true
    var indentLevel: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var calloutEmoji: String = ""
    var languageHint: String = ""

    var imageData: Data? = nil

    var entry: DocumentEntry?

    var inlineStyles: [DocumentInlineStyle]? = nil

    init(
        type: DocumentBlockType = .paragraph,
        text: String = "",
        sortOrder: Int = 0,
        parentBlockID: UUID? = nil,
        listGroupID: UUID? = nil,
        isExpanded: Bool = true,
        indentLevel: Int = 0,
        calloutEmoji: String = "",
        languageHint: String = "",
        imageData: Data? = nil
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
        self.imageData = imageData
    }

    var type: DocumentBlockType {
        get { DocumentBlockType(rawValue: typeRaw) ?? .paragraph }
        set { typeRaw = newValue.rawValue }
    }

    var isListBlock: Bool {
        switch type {
        case .bulletedList, .numberedList: return true
        default: return false
        }
    }

    private var imageParts: [String] {
        let parts = languageHint.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return [
            parts.count > 0 ? parts[0] : "",
            parts.count > 1 ? parts[1] : "",
            parts.count > 2 ? parts[2] : ""
        ]
    }

    private func setImagePart(_ index: Int, value: String) {
        var parts = imageParts
        parts[index] = value
        languageHint = parts.joined(separator: "|")
    }

    var imageAlignment: ImageBlockAlignment {
        get { ImageBlockAlignment(rawValue: imageParts[0]) ?? .left }
        set { setImagePart(0, value: newValue.rawValue) }
    }

    var imageSize: ImageBlockSize {
        get { ImageBlockSize(rawValue: imageParts[1]) ?? .medium }
        set { setImagePart(1, value: newValue.rawValue) }
    }

    var imageDisplayMode: ImageBlockDisplayMode {
        get { ImageBlockDisplayMode(rawValue: imageParts[2]) ?? .fit }
        set { setImagePart(2, value: newValue.rawValue) }
    }

    var isToggleBlock: Bool {
        type == .toggle
    }

    var sortedInlineStyles: [DocumentInlineStyle] {
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
