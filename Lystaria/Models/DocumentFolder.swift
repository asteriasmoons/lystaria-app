//
//  DocumentFolder.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/10/26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class DocumentFolder {
    var uuid: UUID = UUID()

    var title: String = ""
    var iconName: String = "system:folder.fill"
    var colorHex: String = "#6055F7"

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    // MARK: - Relationships

    var book: DocumentBook? = nil

    @Relationship(deleteRule: .nullify, inverse: \DocumentEntry.folder)
    var entries: [DocumentEntry]? = nil

    init(
        title: String = "",
        iconName: String = "system:folder.fill",
        colorHex: String = "#6055F7"
    ) {
        self.uuid = UUID()

        self.title = title
        self.iconName = iconName
        self.colorHex = colorHex

        self.createdAt = Date()
        self.updatedAt = Date()
        self.deletedAt = nil

        self.book = nil
        self.entries = nil
    }
}
