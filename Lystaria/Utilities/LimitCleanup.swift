//
//  LimitCleanup.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/25/26.
//

import Foundation
import SwiftData

@MainActor
enum LimitCleanup {
    static func pruneFreeTierHistory(in context: ModelContext, limits: LimitManager? = nil) throws {
        let limits = limits ?? .shared
        guard !limits.hasPremiumAccess else { return }

        try pruneHealthMetrics(in: context, limits: limits)
        try pruneExerciseLogs(in: context, limits: limits)
        try pruneMoodLogs(in: context, limits: limits)

        try context.save()
    }

    private static func pruneHealthMetrics(in context: ModelContext, limits: LimitManager) throws {
        guard let cutoff = limits.cutoffDate(for: .healthHistory) else { return }

        let descriptor = FetchDescriptor<HealthMetricEntry>()
        let entries = try context.fetch(descriptor)

        for entry in entries where entry.createdAt < cutoff {
            context.delete(entry)
        }
    }

    private static func pruneExerciseLogs(in context: ModelContext, limits: LimitManager) throws {
        guard let cutoff = limits.cutoffDate(for: .healthHistory) else { return }

        let descriptor = FetchDescriptor<ExerciseLogEntry>()
        let entries = try context.fetch(descriptor)

        for entry in entries where entry.createdAt < cutoff {
            context.delete(entry)
        }
    }

    private static func pruneMoodLogs(in context: ModelContext, limits: LimitManager) throws {
        guard let cutoff = limits.cutoffDate(for: .moodHistory) else { return }

        let descriptor = FetchDescriptor<MoodLog>()
        let entries = try context.fetch(descriptor)

        for entry in entries where entry.createdAt < cutoff {
            context.delete(entry)
        }
    }
}
