// MoodLogService
//
// Created by Asteria Moon

import Foundation
import Supabase
import SwiftData

final class MoodLogService {
    static let shared = MoodLogService()

    private let client = SupabaseManager.shared.client
    private let tableName = "mood_logs"

    private init() {}

    func fetchMoodLogs() async throws -> [MoodLog] {
        let userId = try currentUserId()

        let rows: [MoodLogSupabaseRow] = try await client
            .from(tableName)
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map { MoodLog.fromSupabaseRow($0) }
    }

    func saveMoodLog(_ log: MoodLog) async throws -> MoodLogSupabaseRow {
        let userId = try currentUserId()
        let payload = log.makeSupabaseUpsertRow(userId: userId)

        let rows: [MoodLogSupabaseRow] = try await client
            .from(tableName)
            .upsert(payload)
            .select()
            .execute()
            .value

        guard let savedRow = rows.first else {
            throw MoodLogServiceError.emptyResponse
        }

        return savedRow
    }

    func saveMoodLog(_ log: MoodLog, in modelContext: ModelContext?) async throws {
        let savedRow = try await saveMoodLog(log)

        await MainActor.run {
            log.markSynced(
                serverId: savedRow.id?.uuidString,
                syncedAt: Date()
            )

            log.updatedAt = savedRow.updatedAt

            if let modelContext {
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save local mood sync state: \(error)")
                }
            }
        }
    }

    func deleteMoodLog(serverId: String) async throws {
        try await client
            .from(tableName)
            .delete()
            .eq("id", value: serverId)
            .execute()
    }

    private func currentUserId() throws -> UUID {
        guard let user = SupabaseManager.shared.auth.currentUser else {
            throw MoodLogServiceError.notAuthenticated
        }

        return user.id
    }
}

enum MoodLogServiceError: LocalizedError {
    case notAuthenticated
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No authenticated user was found."
        case .emptyResponse:
            return "Supabase returned an empty response."
        }
    }
}
