// MoodLogService
//
// Created by Asteria Moon

import Foundation
import SwiftData

final class MoodLogService {
    static let shared = MoodLogService()

    private init() {}

    func fetchMoodLogs(in modelContext: ModelContext) throws -> [MoodLog] {
        let descriptor = FetchDescriptor<MoodLog>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\MoodLog.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchMoodLogs() async throws -> [MoodLog] {
        throw MoodLogServiceError.modelContextRequired
    }

    func saveMoodLog(_ log: MoodLog) async throws {
        log.touchUpdated()
    }

    func saveMoodLog(_ log: MoodLog, in modelContext: ModelContext?) async throws {
        await MainActor.run {
            log.touchUpdated()

            if let modelContext {
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save local mood log: \(error)")
                }
            }
        }
    }

    func deleteMoodLog(_ log: MoodLog, in modelContext: ModelContext?) async throws {
        await MainActor.run {
            log.deletedAt = Date()
            log.touchUpdated()

            if let modelContext {
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to soft-delete local mood log: \(error)")
                }
            }
        }
    }
}

enum MoodLogServiceError: LocalizedError {
    case modelContextRequired

    var errorDescription: String? {
        switch self {
        case .modelContextRequired:
            return "A ModelContext is required for local mood log operations."
        }
    }
}
