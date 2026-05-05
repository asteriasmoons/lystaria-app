//
//  DocumentInlineStyle.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import Foundation
import SwiftData

enum DocumentInlineStyleType: String, Codable, CaseIterable {
    case bold
    case italic
    case underline
    case link
    case inlineCode
}

@Model
final class DocumentInlineStyle {
    var id: UUID = UUID()

    var typeRaw: String = DocumentInlineStyleType.bold.rawValue
    var rangeLocation: Int = 0
    var rangeLength: Int = 0
    var urlString: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(inverse: \DocumentBlock.inlineStyles)
    var block: DocumentBlock?

    init(
        type: DocumentInlineStyleType = .bold,
        rangeLocation: Int = 0,
        rangeLength: Int = 0,
        urlString: String = ""
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.urlString = urlString
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var type: DocumentInlineStyleType {
        get { DocumentInlineStyleType(rawValue: typeRaw) ?? .bold }
        set { typeRaw = newValue.rawValue }
    }

    var safeRange: NSRange {
        NSRange(location: max(0, rangeLocation), length: max(0, rangeLength))
    }

    func touch() {
        updatedAt = Date()
    }
}
