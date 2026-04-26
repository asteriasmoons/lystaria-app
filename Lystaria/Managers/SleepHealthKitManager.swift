//
//  SleepHealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 4/16/26.
//

import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
final class SleepHealthKitManager: ObservableObject {
    static let shared = SleepHealthKitManager()

    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    /// Total asleep hours for the most recent sleep session (last 24 h window).
    @Published private(set) var lastNightHours: Double = 0

    /// 0…1 progress toward the goal.
    @Published private(set) var sleepScore: Double = 0

    /// Human-readable label.
    @Published private(set) var sleepLabel: String = "Unavailable"

    /// Goal in hours — set externally from DailyCompletionSettings.
    var sleepGoalHours: Double = 8 {
        didSet { recompute() }
    }

    private var isAuthorized = false

    private init() {}

    // MARK: - Auth

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !isAuthorized {
            isAuthorized = true
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            } catch {
                print("SleepHealthKitManager auth error:", error)
                return
            }
        }
        await fetchLastNightSleep()
    }

    // MARK: - Fetch

    func fetchLastNightSleep() async {
        // Search a 30-hour window so we catch any normal sleep schedule.
        let end   = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -30, to: end) ?? end

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort      = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let hours: Double = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let sleepSamples = (samples as? [HKCategorySample]) ?? []

                // Keep only actual sleep stages (not inBed).
                let asleepSamples = sleepSamples.filter { sample in
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                    switch value {
                    case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                        return true
                    default:
                        return false
                    }
                }.sorted { $0.endDate > $1.endDate }

                guard !asleepSamples.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                // Find the most recent contiguous sleep session.
                // A gap > 90 minutes between samples means a new/prior session.
                let gapThreshold: TimeInterval = 90 * 60
                var sessionEnd   = asleepSamples[0].endDate
                var sessionStart = asleepSamples[0].startDate
                var totalSeconds: TimeInterval = asleepSamples[0].endDate.timeIntervalSince(asleepSamples[0].startDate)

                for sample in asleepSamples.dropFirst() {
                    let gap = sessionStart.timeIntervalSince(sample.endDate)
                    if gap <= gapThreshold {
                        // Belongs to the same session — extend backwards.
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        sessionStart = min(sessionStart, sample.startDate)
                    } else {
                        // Gap is too large — this is a prior session, stop.
                        break
                    }
                    _ = sessionEnd // suppress unused warning
                }

                continuation.resume(returning: totalSeconds / 3600)
            }
            healthStore.execute(query)
        }

        lastNightHours = hours
        recompute()
    }

    // MARK: - Score + Label

    private func recompute() {
        guard sleepGoalHours > 0 else {
            sleepScore = 0
            sleepLabel = "Unavailable"
            return
        }

        let score = min(lastNightHours / sleepGoalHours, 1.0)
        sleepScore = score

        switch lastNightHours {
        case 0:
            sleepLabel = "No Data"
        case ..<5:
            sleepLabel = "Rest Needed"
        case ..<6:
            sleepLabel = "Low"
        case ..<7:
            sleepLabel = "Fair"
        case ..<8:
            sleepLabel = "Good"
        default:
            sleepLabel = "Excellent"
        }
    }
}
