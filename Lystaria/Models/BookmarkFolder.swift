//
//  BookmarkFolder.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

@Model
final class BookmarkFolder {
    var name: String = ""
    var systemKey: String = ""   // use "inbox" for the default folder
    var iconName: String = "folder.fill"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \BookmarkItem.folder)
    var bookmarks: [BookmarkItem]? = []

    init(
        name: String = "",
        systemKey: String = "",
        iconName: String = "folder.fill",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.systemKey = systemKey
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isInbox: Bool {
        systemKey == "inbox"
    }
}
