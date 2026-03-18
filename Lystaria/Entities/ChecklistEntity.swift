//
//  ChecklistEntity.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import AppIntents
import SwiftData
import Foundation

struct ChecklistEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Checklist"
    static var defaultQuery = ChecklistEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(checklist: Checklist) {
        let trimmed = checklist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty ? "Checklist" : trimmed

        self.name = displayName
        self.id = ChecklistEntity.makeStableID(for: checklist)
    }

    static func makeStableID(for checklist: Checklist) -> String {
        let timestamp = checklist.createdAt.timeIntervalSince1970
        let trimmed = checklist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? "Checklist" : trimmed
        return "\(timestamp)|\(checklist.sortOrder)|\(safeName)"
    }
}

struct ChecklistEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ChecklistEntity] {
        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<Checklist>(
                sortBy: [
                    SortDescriptor(\.sortOrder, order: .forward),
                    SortDescriptor(\.createdAt, order: .forward)
                ]
            )

            let all = try context.fetch(descriptor)

            return all
                .filter { identifiers.contains(ChecklistEntity.makeStableID(for: $0)) }
                .map { ChecklistEntity(checklist: $0) }
        }
    }

    func suggestedEntities() async throws -> [ChecklistEntity] {
        try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)
            let descriptor = FetchDescriptor<Checklist>(
                sortBy: [
                    SortDescriptor(\.sortOrder, order: .forward),
                    SortDescriptor(\.createdAt, order: .forward)
                ]
            )

            let all = try context.fetch(descriptor)
            return all.map { ChecklistEntity(checklist: $0) }
        }
    }
}
