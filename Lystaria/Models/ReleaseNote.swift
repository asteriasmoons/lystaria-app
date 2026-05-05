//
//  ReleaseNote.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/3/26.
//

import Foundation
import SwiftData

@Model
final class ReleaseNote {
    var id: String = UUID().uuidString
    var version: String = ""
    var dateText: String = ""
    var title: String = ""
    var items: [String] = []
    var createdAt: Date = Date()
    var isPublished: Bool = false
    var sortOrder: Int = 0
    var hasBeenSeen: Bool = false
    var seenAt: Date?

    init(
        id: String = UUID().uuidString,
        version: String = "",
        dateText: String = "",
        title: String = "",
        items: [String] = [],
        createdAt: Date = Date(),
        isPublished: Bool = false,
        sortOrder: Int = 0,
        hasBeenSeen: Bool = false,
        seenAt: Date? = nil
    ) {
        self.id = id
        self.version = version
        self.dateText = dateText
        self.title = title
        self.items = items
        self.createdAt = createdAt
        self.isPublished = isPublished
        self.sortOrder = sortOrder
        self.hasBeenSeen = hasBeenSeen
        self.seenAt = seenAt
    }
}
