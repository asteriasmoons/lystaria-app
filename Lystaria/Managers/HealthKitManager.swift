//
//  HealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import HealthKit
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

final class HealthKitManager: ObservableObject {
    
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var stepObserverQuery: HKObserverQuery?
    
    @Published var todaySteps: Double = 0
    
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
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [stepType]
            )
            
            await fetchTodaySteps()
            startObservingSteps()
        } catch {
            print("HealthKit auth error:", error)
        }
    }
    
    func fetchTodaySteps() async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: Date())

        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, error in
            guard let self else { return }
            guard error == nil else {
                print("HealthKit steps query error:", error!)
                return
            }

            let todayStats = results?.statistics(for: startOfDay)
            let steps = todayStats?.sumQuantity()?.doubleValue(for: .count()) ?? 0

            DispatchQueue.main.async {
                self.todaySteps = steps
            }
        }

        healthStore.execute(query)
    }

    private func startObservingSteps() {
        guard stepObserverQuery == nil else { return }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            if let error {
                print("HealthKit step observer error:", error)
            }

            Task {
                await self?.fetchTodaySteps()
            }
        }

        stepObserverQuery = query
        healthStore.execute(query)
    }
    
    func totalSteps(from startDate: Date, to endDate: Date) -> Double? {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        var resultValue: Double?
        let semaphore = DispatchSemaphore(value: 0)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if error == nil {
                resultValue = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            }
            semaphore.signal()
        }

        healthStore.execute(query)
        semaphore.wait()
        return resultValue
    }

    @objc private func handleDayChange() {
        Task {
            await fetchTodaySteps()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
