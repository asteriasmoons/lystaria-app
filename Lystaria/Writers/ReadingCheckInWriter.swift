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

        let descriptor = FetchDescriptor<ReadingStats>()
        let allRecords = (try? modelContext.fetch(descriptor)) ?? []

        let record: ReadingStats?
        if let exact = allRecords
            .filter({ $0.userId == currentUserId })
            .max(by: { $0.updatedAt < $1.updatedAt }) {
            record = exact
        } else {
            record = allRecords.max(by: { $0.updatedAt < $1.updatedAt })
        }

        guard let record,
              let lastCheckIn = record.lastCheckInDate else {
            return false
        }

        return Calendar.current.isDateInToday(lastCheckIn)
    }

    static func checkInToday(modelContext: ModelContext, userId: String) throws -> Bool {
        let currentUserId = userId

        let descriptor = FetchDescriptor<ReadingStats>()
        let allRecords = try modelContext.fetch(descriptor)
        let matches = allRecords.filter { $0.userId == currentUserId }
        let now = Date()

        let record: ReadingStats
        if let exact = matches.max(by: { $0.updatedAt < $1.updatedAt }) {
            record = exact

            if let lastCheckIn = record.lastCheckInDate,
               Calendar.current.isDateInToday(lastCheckIn) {
                return false
            }

            if matches.count > 1 {
                let mergedBestStreak = matches.map { max($0.bestStreakDays, $0.streakDays) }.max() ?? 0
                let mergedCurrentStreak = matches.map { $0.streakDays }.max() ?? 0
                record.bestStreakDays = max(record.bestStreakDays, mergedBestStreak)
                record.streakDays = max(record.streakDays, mergedCurrentStreak)

                for dupe in matches where dupe.persistentModelID != record.persistentModelID {
                    modelContext.delete(dupe)
                }
            }
        } else if let adopted = allRecords.max(by: { $0.updatedAt < $1.updatedAt }) {
            adopted.userId = currentUserId
            adopted.bestStreakDays = max(adopted.bestStreakDays, adopted.streakDays)
            adopted.updatedAt = now
            record = adopted
        } else {
            let newRecord = ReadingStats(userId: currentUserId, streakDays: 0, bestStreakDays: 0)
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
        record.bestStreakDays = max(record.bestStreakDays, newStreakDays)
        let allBest = allRecords.map { max($0.bestStreakDays, $0.streakDays) }.max() ?? 0
        record.bestStreakDays = max(record.bestStreakDays, allBest)
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
