//
//  BodyStateHealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation
import HealthKit
import SwiftData
import Combine

@MainActor
final class BodyStateHealthKitManager: ObservableObject {
    static let shared = BodyStateHealthKitManager()

    private let healthStore = HKHealthStore()

    @Published private(set) var lastRefreshDate: Date?

    private init() {}

    // MARK: - HealthKit Types

    private var hrvType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }

    private var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }

    private var restingHeartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            hrvType,
            heartRateType,
            restingHeartRateType
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Refresh + Sync One Record

    func refreshAndStore(in modelContext: ModelContext) async {
        do {
            // Today's HRV: average of all samples recorded since midnight.
            // This is far more stable than a single raw sample and mirrors
            // how Whoop/Garmin derive their daily HRV figure.
            let todayHRV = try await fetchTodayAverageHRV()

            // Fallback: if no HRV has been recorded today yet (e.g. early morning
            // before the watch has synced), use the most recent single sample
            // from the last 48 hours so the card isn't blank all day.
            let latestHRV: Double?
            if let todayHRV {
                latestHRV = todayHRV
            } else {
                latestHRV = try await fetchRecentSampleAverage(
                    for: hrvType,
                    unit: HKUnit.secondUnit(with: .milli),
                    hoursBack: 48
                )
            }

            // Baseline: personal 30-day average HRV.
            // 30 days gives a more stable personal baseline than 21.
            let baselineHRV = try await fetchAverageValue(
                for: hrvType,
                unit: HKUnit.secondUnit(with: .milli),
                daysBack: 30
            )

            // Heart rate: average of readings from the last 3 hours.
            // This avoids a single workout spike or stale reading skewing the score.
            let latestHeartRate = try await fetchRecentSampleAverage(
                for: heartRateType,
                unit: HKUnit.count().unitDivided(by: .minute()),
                hoursBack: 3
            )

            // Resting heart rate: most recent daily value Apple has computed.
            let restingHeartRate = try await fetchLatestSampleValue(
                for: restingHeartRateType,
                unit: HKUnit.count().unitDivided(by: .minute())
            )

            let snapshot = BodyStateClassifier.classify(
                latestHRV: latestHRV,
                baselineHRV: baselineHRV,
                latestHeartRate: latestHeartRate,
                restingHeartRate: restingHeartRate
            )

            print("""
            [BodyState] Refresh at \(Date())
              todayHRV:          \(todayHRV.map { String(format: "%.1f ms", $0) } ?? "nil (no samples today)")
              latestHRV (used):  \(latestHRV.map { String(format: "%.1f ms", $0) } ?? "nil")
              baselineHRV:       \(baselineHRV.map { String(format: "%.1f ms", $0) } ?? "nil")
              latestHeartRate:   \(latestHeartRate.map { String(format: "%.0f bpm", $0) } ?? "nil")
              restingHeartRate:  \(restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "nil")
              bodyScore:         \(String(format: "%.3f", snapshot.bodyScore)) → \(snapshot.bodyLabel)
              nervousScore:      \(String(format: "%.3f", snapshot.nervousSystemScore)) → \(snapshot.nervousSystemLabel)
            """)

            let descriptor = FetchDescriptor<BodyStateRecord>()
            let existing = try modelContext.fetch(descriptor)

            // Delete all existing records and re-insert so SwiftData
            // always fires the @Query change notification to the view.
            for record in existing {
                modelContext.delete(record)
            }

            let record = BodyStateRecord(
                createdAt: Date(),
                updatedAt: Date(),
                timestamp: snapshot.updatedAt,
                bodyScore: snapshot.bodyScore,
                nervousSystemScore: snapshot.nervousSystemScore,
                bodyLabel: snapshot.bodyLabel,
                nervousSystemLabel: snapshot.nervousSystemLabel,
                latestHRV: snapshot.latestHRV ?? 0,
                baselineHRV: snapshot.baselineHRV ?? 0,
                latestHeartRate: snapshot.latestHeartRate ?? 0,
                restingHeartRate: snapshot.restingHeartRate ?? 0,
                hasLatestHRV: snapshot.latestHRV != nil,
                hasBaselineHRV: snapshot.baselineHRV != nil,
                hasLatestHeartRate: snapshot.latestHeartRate != nil,
                hasRestingHeartRate: snapshot.restingHeartRate != nil
            )
            modelContext.insert(record)

            try modelContext.save()
            lastRefreshDate = Date()

            HealthWidgetSync.syncBodyState(
                bodyScore: snapshot.bodyScore,
                bodyLabel: snapshot.bodyLabel,
                nervousSystemScore: snapshot.nervousSystemScore,
                nervousSystemLabel: snapshot.nervousSystemLabel
            )
        } catch {
            print("BodyState refresh/store error:", error)
        }
    }

    // MARK: - Queries

    /// Average of all HRV samples recorded since midnight today.
    /// Samples below 15ms are excluded as they are almost always
    /// motion artifacts or poor sensor contact readings.
    private func fetchTodayAverageHRV() async throws -> Double? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: self.hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.secondUnit(with: .milli)
                let values = (samples as? [HKQuantitySample])?
                    .map { $0.quantity.doubleValue(for: unit) }
                    .filter { $0 >= 15.0 } ?? []

                guard !values.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let average = values.reduce(0, +) / Double(values.count)
                continuation.resume(returning: average)
            }
            self.healthStore.execute(query)
        }
    }

    /// Average of all samples of a given type within the last N hours.
    private func fetchRecentSampleAverage(
        for type: HKQuantityType,
        unit: HKUnit,
        hoursBack: Int
    ) async throws -> Double? {
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: end)!
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Most recent single sample — used only for resting heart rate which
    /// Apple computes once per day and doesn't need averaging.
    private func fetchLatestSampleValue(
        for type: HKQuantityType,
        unit: HKUnit
    ) async throws -> Double? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                let value = sample?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    /// Long-window average used for the personal baseline.
    private func fetchAverageValue(
        for type: HKQuantityType,
        unit: HKUnit,
        daysBack: Int
    ) async throws -> Double? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let average = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: average)
            }

            healthStore.execute(query)
        }
    }
}
