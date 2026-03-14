//
//  DailyIntentionWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import Foundation
import SwiftData

@MainActor
enum DailyIntentionWriter {
    static func todayKey(for date: Date = Date()) -> String {
        let cal = Calendar.autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let normalized = cal.date(from: comps) ?? date

        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: normalized)
    }

    static func todayDate(for date: Date = Date()) -> Date {
        let cal = Calendar.autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return cal.date(from: comps) ?? date
    }

    static func storageKey(for date: Date = Date()) -> String {
        "dailyIntentionText.\(todayKey(for: date))"
    }

    static func setTodayIntention(
        _ text: String,
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let key = todayKey()
        let date = todayDate()

        let descriptor = FetchDescriptor<DailyIntention>(
            predicate: #Predicate<DailyIntention> { $0.dateKey == key }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.text = trimmed
            existing.updatedAt = Date()
        } else {
            let record = DailyIntention(date: date, text: trimmed)
            modelContext.insert(record)
        }

        try modelContext.save()
        defaults.set(trimmed, forKey: storageKey(for: date))
    }
}
