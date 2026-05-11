//
//  DocumentInlineProperty.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import Foundation
import SwiftData

enum DocumentInlinePropertyType: String, Codable, CaseIterable, Identifiable {
    case boolean = "Boolean"
    case multiSelect = "Multi Select"
    case select = "Select"
    case text = "Text"
    case number = "Number"
    case date = "Date"
    case checkbox = "Checkbox"
    case url = "URL"

    var id: String { rawValue }
}

@Model
final class DocumentInlineProperty {
    var id: UUID = UUID()

    var name: String = ""
    var typeRaw: String = DocumentInlinePropertyType.text.rawValue
    var valueStorage: String = ""
    var optionsStorage: String = ""
    var colorHex: String = ""

    var rangeLocation: Int = 0
    var rangeLength: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(inverse: \DocumentBlock.inlineProperties)
    var block: DocumentBlock?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: DocumentInlinePropertyType = .text,
        valueStorage: String = "",
        optionsStorage: String = "",
        colorHex: String = "",
        rangeLocation: Int = 0,
        rangeLength: Int = 0,
        block: DocumentBlock? = nil
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.valueStorage = valueStorage
        self.optionsStorage = optionsStorage
        self.colorHex = colorHex
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.createdAt = Date()
        self.updatedAt = Date()
        self.block = block
    }

    var type: DocumentInlinePropertyType {
        get { DocumentInlinePropertyType(rawValue: typeRaw) ?? .text }
        set {
            typeRaw = newValue.rawValue
            touch()
        }
    }

    var safeRange: NSRange {
        NSRange(location: max(0, rangeLocation), length: max(0, rangeLength))
    }

    func touch() {
        updatedAt = Date()
        block?.touch()
    }
}
