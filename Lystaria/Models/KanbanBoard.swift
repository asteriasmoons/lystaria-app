//
//  KanbanBoard.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - KanbanBoard

@Model
final class KanbanBoard {
    var id: UUID
    var name: String
    var colorHex: String        // e.g. "#03dbfc"
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \KanbanColumn.board)
    var columns: [KanbanColumn] = []

    init(name: String, colorHex: String = "#03dbfc", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - KanbanColumn

@Model
final class KanbanColumn {
    var id: UUID
    var name: String            // e.g. "To Do", "In Progress", "Done"
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var board: KanbanBoard?

    @Relationship(deleteRule: .nullify)
    var reminders: [LystariaReminder] = []

    init(name: String, colorHex: String = "#7d19f7", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var color: Color { Color(hex: colorHex) }
}
