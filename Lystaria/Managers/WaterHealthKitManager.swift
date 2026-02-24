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

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(
                toShare: [waterType],
                read: [waterType]
            )

            await fetchTodayWater()
        } catch {
            print("Water HealthKit auth error:", error)
        }
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

    func totalWaterFlOz(from startDate: Date, to endDate: Date) -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        var resultValue: Double?
        let semaphore = DispatchSemaphore(value: 0)

        let query = HKStatisticsQuery(
            quantityType: waterType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if error == nil {
                resultValue = result?.sumQuantity()?.doubleValue(for: .fluidOunceUS()) ?? 0
            }
            semaphore.signal()
        }

        healthStore.execute(query)
        semaphore.wait()
        return resultValue
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
