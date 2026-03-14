//
//  ReadingCheckinWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import Foundation
import SwiftData

@MainActor
enum ReadingCheckInWriter {
    static let streakDaysKey = "readingStreakDays"
    static let lastCheckInKey = "readingLastCheckIn"
    static let currentUserIdKey = "currentUserId"

    static func alreadyCheckedInToday(defaults: UserDefaults = .standard) -> Bool {
        let timestamp = defaults.double(forKey: lastCheckInKey)
        guard timestamp > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: timestamp))
    }

    static func checkInToday(modelContext: ModelContext, defaults: UserDefaults = .standard) throws -> Bool {
        if alreadyCheckedInToday(defaults: defaults) {
            return false
        }

        var currentUserId = defaults.string(forKey: currentUserIdKey) ?? "local-user"
        if currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentUserId == "local-user" {
            currentUserId = UUID().uuidString
            defaults.set(currentUserId, forKey: currentUserIdKey)
        }

        let newStreakDays = defaults.integer(forKey: streakDaysKey) + 1
        let now = Date()

        defaults.set(newStreakDays, forKey: streakDaysKey)
        defaults.set(now.timeIntervalSince1970, forKey: lastCheckInKey)

        var descriptor = FetchDescriptor<ReadingStats>(
            predicate: #Predicate<ReadingStats> { record in
                record.userId == currentUserId
            }
        )
        descriptor.fetchLimit = 50

        let matches = try modelContext.fetch(descriptor)

        let record: ReadingStats
        if let best = matches.max(by: { $0.streakDays < $1.streakDays }) {
            record = best

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

        record.streakDays = newStreakDays
        record.lastCheckInDate = now
        record.updatedAt = now
        record.needsSync = true

        try modelContext.save()
        return true
    }
}
