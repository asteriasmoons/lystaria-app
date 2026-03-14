//
//  ChecklistItemWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import Foundation
import SwiftData

@MainActor
enum ChecklistItemWriter {
    static func addItem(
        text: String,
        modelContext: ModelContext
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Checklist>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let existingChecklists = try modelContext.fetch(descriptor)

        let checklist: Checklist
        if let first = existingChecklists.first {
            checklist = first
        } else {
            let created = Checklist(name: "My Checklist", sortOrder: 0)
            modelContext.insert(created)
            checklist = created
        }

        let nextOrder = (checklist.items.map(\.sortOrder).max() ?? -1) + 1

        let item = ChecklistItem(
            text: trimmed,
            isCompleted: false,
            sortOrder: nextOrder,
            checklist: checklist
        )

        item.updatedAt = Date()
        item.needsSync = true

        checklist.updatedAt = Date()
        checklist.needsSync = true

        modelContext.insert(item)
        try modelContext.save()
    }
}
