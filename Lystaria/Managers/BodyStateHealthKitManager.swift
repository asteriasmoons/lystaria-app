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
            let latestHRV = try await fetchLatestSampleValue(
                for: hrvType,
                unit: HKUnit.secondUnit(with: .milli)
            )

            let baselineHRV = try await fetchAverageValue(
                for: hrvType,
                unit: HKUnit.secondUnit(with: .milli),
                daysBack: 21
            )

            let latestHeartRate = try await fetchLatestSampleValue(
                for: heartRateType,
                unit: HKUnit.count().unitDivided(by: .minute())
            )

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

            let descriptor = FetchDescriptor<BodyStateRecord>()
            let existing = try modelContext.fetch(descriptor).first

            if let record = existing {
                record.updatedAt = Date()
                record.timestamp = snapshot.updatedAt

                record.bodyScore = snapshot.bodyScore
                record.nervousSystemScore = snapshot.nervousSystemScore

                record.bodyLabel = snapshot.bodyLabel
                record.nervousSystemLabel = snapshot.nervousSystemLabel

                record.latestHRV = snapshot.latestHRV ?? 0
                record.baselineHRV = snapshot.baselineHRV ?? 0
                record.latestHeartRate = snapshot.latestHeartRate ?? 0
                record.restingHeartRate = snapshot.restingHeartRate ?? 0

                record.hasLatestHRV = snapshot.latestHRV != nil
                record.hasBaselineHRV = snapshot.baselineHRV != nil
                record.hasLatestHeartRate = snapshot.latestHeartRate != nil
                record.hasRestingHeartRate = snapshot.restingHeartRate != nil
            } else {
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
            }

            try modelContext.save()
            lastRefreshDate = Date()
        } catch {
            print("BodyState refresh/store error:", error)
        }
    }

    // MARK: - Queries

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
