//
//  DailyCompletionArcHelper.swift
//  Lystaria
//

import Foundation
import SwiftData

struct DailyCompletionArcData {
    let percentage: Double          // 0...1
    let bubbleFillStates: [Double]  // 0...1 per bubble

    let waterProgress: Double
    let stepsProgress: Double
    let moodComplete: Bool
    let journalComplete: Bool
}

enum DailyCompletionArcHelper {

    // MARK: - Public Builder

    static func build(
        modelContext: ModelContext,
        waterToday: Double,
        stepsToday: Double
    ) -> DailyCompletionArcData {

        let calendar = Calendar.current
        let today = Date()
        let settings = fetchSettings(from: modelContext)

        // MARK: - Water

        let waterProgress = settings.includeWater && settings.waterGoalFlOz > 0
            ? min(waterToday / settings.waterGoalFlOz, 1.0)
            : 0

        // MARK: - Steps

        let stepsProgress = settings.includeSteps && settings.stepGoal > 0
            ? min(stepsToday / settings.stepGoal, 1.0)
            : 0

        // MARK: - Mood

        let moodDescriptor = FetchDescriptor<MoodLog>()
        let moodLogs = (try? modelContext.fetch(moodDescriptor)) ?? []

        let moodComplete = settings.includeMood && moodLogs.contains {
            $0.deletedAt == nil &&
            calendar.isDate($0.createdAt, inSameDayAs: today)
        }

        // MARK: - Journal

        let journalDescriptor = FetchDescriptor<JournalEntry>()
        let journalEntries = (try? modelContext.fetch(journalDescriptor)) ?? []

        let journalComplete = settings.includeJournal && journalEntries.contains {
            $0.deletedAt == nil &&
            calendar.isDate($0.createdAt, inSameDayAs: today)
        }

        // MARK: - Convert to numeric

        let moodValue = moodComplete ? 1.0 : 0.0
        let journalValue = journalComplete ? 1.0 : 0.0

        // MARK: - Final Percentage

        let components: [Double] = [
            settings.includeWater ? waterProgress : -1,
            settings.includeSteps ? stepsProgress : -1,
            settings.includeMood ? moodValue : -1,
            settings.includeJournal ? journalValue : -1
        ].filter { $0 >= 0 }

        let percentage = components.isEmpty
            ? 0
            : components.reduce(0, +) / Double(components.count)

        // MARK: - Bubble Fill States

        let bubbleFillStates = buildBubbleStates(
            percentage: percentage,
            count: settings.bubbleCount
        )

        return DailyCompletionArcData(
            percentage: percentage,
            bubbleFillStates: bubbleFillStates,
            waterProgress: waterProgress,
            stepsProgress: stepsProgress,
            moodComplete: moodComplete,
            journalComplete: journalComplete
        )
    }

    private static func fetchSettings(from modelContext: ModelContext) -> DailyCompletionSettings {
        let defaultKey = DailyCompletionSettings.defaultKey
        let descriptor = FetchDescriptor<DailyCompletionSettings>(
            predicate: #Predicate<DailyCompletionSettings> { settings in
                settings.key == defaultKey
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let settings = DailyCompletionSettings(key: DailyCompletionSettings.defaultKey)
        modelContext.insert(settings)
        try? modelContext.save()
        return settings
    }

    // MARK: - Bubble Logic

    private static func buildBubbleStates(
        percentage: Double,
        count: Int
    ) -> [Double] {

        guard count > 0 else { return [] }

        let total = percentage * Double(count)

        return (0..<count).map { index in
            let value = total - Double(index)
            return min(max(value, 0), 1)
        }
    }
}
