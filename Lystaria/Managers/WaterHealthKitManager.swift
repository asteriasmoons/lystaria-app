//
//  WaterHealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import Foundation
import HealthKit
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

final class WaterHealthKitManager: ObservableObject {
    static let shared = WaterHealthKitManager()

    private let healthStore = HKHealthStore()
    private let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
    private let appSourceKey = "com.lystaria.waterEntry"

    @Published var todayWaterFlOz: Double = 0
    private var waterGoalForSync: Double = {
        // Seed from shared UserDefaults so the observer never overwrites
        // the widget with the hardcoded default before WaterTrackingView appears.
        let stored = UserDefaults(suiteName: HealthWidgetSync.appGroupID)
            .flatMap { $0.object(forKey: "healthWidget.waterGoal") as? Double }
        return stored ?? 80
    }()
    private var waterObserverQuery: HKObserverQuery?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChange),
            name: .NSCalendarDayChanged,
            object: nil
        )

#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChange),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
#endif
    }

    private var isAuthorized = false

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !isAuthorized else { return }
        isAuthorized = true

        do {
            try await healthStore.requestAuthorization(
                toShare: [waterType],
                read: [waterType]
            )

            await fetchTodayWater()
            enableWaterBackgroundDelivery()
            startObservingWater()
        } catch {
            print("Water HealthKit auth error:", error)
        }
    }

    func updateWaterGoalForSync(_ goal: Double) {
        waterGoalForSync = goal
    }

    private func enableWaterBackgroundDelivery() {
        healthStore.enableBackgroundDelivery(for: waterType, frequency: .immediate) { _, error in
            if let error {
                print("HealthKit water background delivery error:", error)
            }
        }
    }

    private func startObservingWater() {
        guard waterObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: waterType, predicate: nil) { [weak self] _, _, error in
            if let error {
                print("HealthKit water observer error:", error)
            }
            Task { await self?.fetchTodayWater() }
        }

        waterObserverQuery = query
        healthStore.execute(query)
    }

    func fetchTodayWater() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: waterType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            DispatchQueue.main.async {
                let flOz = result?
                    .sumQuantity()?
                    .doubleValue(for: .fluidOunceUS()) ?? 0

                self.todayWaterFlOz = flOz
                HealthWidgetSync.syncWater(
                    waterToday: flOz,
                    waterGoal: self.waterGoalForSync
                )
            }
        }

        healthStore.execute(query)
    }

    func addWater(flOz: Double, date: Date = Date()) async {
        guard flOz > 0 else { return }

        let quantity = HKQuantity(unit: .fluidOunceUS(), doubleValue: flOz)

        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [appSourceKey: true]
        )

        do {
            try await healthStore.save(sample)
            await fetchTodayWater()
        } catch {
            print("Failed to save water sample:", error)
        }
    }

    func clearTodayWater() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: appSourceKey, operatorType: .equalTo, value: true as NSNumber)

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, metadataPredicate])

        let query = HKSampleQuery(
            sampleType: waterType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, error in
            guard let self else { return }

            if let error {
                print("Failed to fetch water samples:", error)
                return
            }

            guard let samples = samples else { return }

            self.healthStore.delete(samples) { success, deleteError in
                if let deleteError {
                    print("Failed to delete water samples:", deleteError)
                }

                Task {
                    await self.fetchTodayWater()
                }
            }
        }

        healthStore.execute(query)
    }

    func clearCustomAmount(flOz: Double) async {
        guard flOz > 0 else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let metadataPredicate = HKQuery.predicateForObjects(
            withMetadataKey: appSourceKey,
            operatorType: .equalTo,
            value: true as NSNumber
        )

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, metadataPredicate])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: waterType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self else { return }

            if let error {
                print("Failed to fetch water samples for clear custom:", error)
                return
            }

            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

            // Walk newest-first, collecting samples until we've covered the requested amount
            var remaining = flOz
            var toDelete: [HKSample] = []

            for sample in samples {
                guard remaining > 0 else { break }
                let sampleFlOz = sample.quantity.doubleValue(for: .fluidOunceUS())
                toDelete.append(sample)
                remaining -= sampleFlOz
            }

            self.healthStore.delete(toDelete) { _, deleteError in
                if let deleteError {
                    print("Failed to delete custom water samples:", deleteError)
                }
                Task { await self.fetchTodayWater() }
            }
        }

        healthStore.execute(query)
    }

    func totalWaterFlOz(from startDate: Date, to endDate: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?
                    .sumQuantity()?
                    .doubleValue(for: .fluidOunceUS()) ?? 0

                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    @objc private func handleDayChange() {
        Task {
            await fetchTodayWater()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
