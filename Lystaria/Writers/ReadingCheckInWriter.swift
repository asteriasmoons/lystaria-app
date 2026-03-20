//
//  ReadingCheckinWriter.swift
//  Lystaria
//

import Foundation
import SwiftData

@MainActor
enum ReadingCheckInWriter {
    static let currentUserIdKey = "currentUserId"

    static func alreadyCheckedInToday(modelContext: ModelContext, userId: String) -> Bool {
        let currentUserId = userId

        var descriptor = FetchDescriptor<ReadingStats>(
            predicate: #Predicate<ReadingStats> { record in
                record.userId == currentUserId
            }
        )
        descriptor.fetchLimit = 1

        guard let record = try? modelContext.fetch(descriptor).first,
              let lastCheckIn = record.lastCheckInDate else {
            return false
        }

        return Calendar.current.isDateInToday(lastCheckIn)
    }

    static func checkInToday(modelContext: ModelContext, userId: String) throws -> Bool {
        let currentUserId = userId

        var descriptor = FetchDescriptor<ReadingStats>(
            predicate: #Predicate<ReadingStats> { record in
                record.userId == currentUserId
            }
        )
        descriptor.fetchLimit = 50

        let matches = try modelContext.fetch(descriptor)
        let now = Date()

        let record: ReadingStats
        if let best = matches.max(by: { $0.streakDays < $1.streakDays }) {
            record = best

            if let lastCheckIn = record.lastCheckInDate,
               Calendar.current.isDateInToday(lastCheckIn) {
                return false
            }

            if matches.count > 1 {
                for dupe in matches where dupe.persistentModelID != best.persistentModelID {
                    modelContext.delete(dupe)
                }
            }
        } else {
            let newRecord = ReadingStats(userId: currentUserId, streakDays: 0)
            modelContext.insert(newRecord)
            record = newRecord
        }

        let newStreakDays: Int
        if let lastCheckIn = record.lastCheckInDate,
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now),
           Calendar.current.isDate(lastCheckIn, inSameDayAs: yesterday) {
            newStreakDays = record.streakDays + 1
        } else {
            newStreakDays = 1
        }

        record.streakDays = newStreakDays
        record.lastCheckInDate = now
        record.updatedAt = now

        try modelContext.save()
        _ = try? SelfCarePointsManager.awardReadingCheckIn(
            in: modelContext,
            date: now
        )
        return true
    }
}
