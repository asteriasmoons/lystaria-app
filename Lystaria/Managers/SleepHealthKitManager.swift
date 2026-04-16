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

    /// Goal in hours — default 8.
    var sleepGoalHours: Double = 8 {
        didSet { recompute() }
    }

    private var isAuthorized = false

    private init() {}

    // MARK: - Auth

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable(), !isAuthorized else { return }
        isAuthorized = true
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            await fetchLastNightSleep()
        } catch {
            print("SleepHealthKitManager auth error:", error)
        }
    }

    // MARK: - Fetch

    func fetchLastNightSleep() async {
        // Look at the window from yesterday noon → now so we always capture
        // a full night regardless of when the user wakes up.
        let end   = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -20, to: end) ?? end

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

                // Sum only stages that count as actual sleep (not in-bed).
                let totalSeconds = sleepSamples
                    .filter { sample in
                        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                        switch value {
                        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                            return true
                        default:
                            return false
                        }
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

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
