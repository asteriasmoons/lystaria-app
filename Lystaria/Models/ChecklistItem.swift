// ChecklistItem.swift
// Lystaria
//
// SwiftData model — Checklist with nested items

import Foundation
import SwiftData

// MARK: - Checklist (a named group of items)

@Model
final class Checklist {
    // MARK: - Sync metadata
    var serverId: String?
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    
    // MARK: - Fields
    var name: String
    var color: String?
    var sortOrder: Int
    
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Relationship
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist)
    var items: [ChecklistItem] = []
    
    // MARK: - Computed
    var completedCount: Int {
        items.filter(\.isCompleted).count
    }
    
    var totalCount: Int {
        items.count
    }
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    init(
        name: String,
        color: String? = nil,
        sortOrder: Int = 0,
        serverId: String? = nil
    ) {
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.serverId = serverId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - ChecklistItem (individual task within a checklist)

@Model
final class ChecklistItem {
    // MARK: - Sync metadata
    var serverId: String?
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    
    // MARK: - Fields
    var text: String
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Relationship
    var checklist: Checklist?
    
    init(
        text: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        checklist: Checklist? = nil,
        serverId: String? = nil
    ) {
        self.text = text
        self.isCompleted = isCompleted
        self.completedAt = nil
        self.sortOrder = sortOrder
        self.checklist = checklist
        self.serverId = serverId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
        updatedAt = Date()
        needsSync = true
    }
}
