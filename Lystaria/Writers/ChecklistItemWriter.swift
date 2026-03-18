//
// ChecklistItemWriter.swift
// Lystaria
//
// Created By Asteria Moon
//

import Foundation
import SwiftData

@MainActor
enum ChecklistItemWriter {
    static func addItem(
        text: String,
        checklistID: String?,
        modelContext: ModelContext
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Checklist>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        let existingChecklists = try modelContext.fetch(descriptor)

        let checklist: Checklist
        if let checklistID,
           let matched = existingChecklists.first(where: {
               ChecklistEntity.makeStableID(for: $0) == checklistID
           }) {
            checklist = matched
        } else if let first = existingChecklists.first {
            checklist = first
        } else {
            let created = Checklist(name: "Checklist 1", sortOrder: 0)
            created.updatedAt = Date()
            created.needsSync = true
            modelContext.insert(created)
            checklist = created
        }

        let existingItems = (checklist.items ?? [])
        let nextOrder = (existingItems.map(\.sortOrder).max() ?? -1) + 1
        let now = Date()

        let item = ChecklistItem(
            text: trimmed,
            isCompleted: false,
            sortOrder: nextOrder,
            checklist: checklist
        )

        item.text = trimmed
        item.isCompleted = false
        item.completedAt = nil
        item.sortOrder = nextOrder
        item.updatedAt = now
        item.needsSync = true
        item.checklist = checklist

        checklist.items = (checklist.items ?? []) + [item]
        checklist.updatedAt = now
        checklist.needsSync = true

        modelContext.insert(item)
        try modelContext.save()
    }
}
