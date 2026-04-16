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
    private(set) var stepGoalForSync: Double = {
        // Seed from shared UserDefaults so the observer never overwrites
        // the widget with the hardcoded default before StepCountView appears.
        let stored = UserDefaults(suiteName: HealthWidgetSync.appGroupID)
            .flatMap { $0.object(forKey: "healthWidget.stepGoal") as? Double }
        return stored ?? 5000
    }()
    
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
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [stepType]
            )
            
            await fetchTodaySteps()
            enableStepBackgroundDelivery()
            startObservingSteps()
        } catch {
            print("HealthKit auth error:", error)
        }
    }
    
    /// Called by StepCountView whenever the goal changes so the observer
    /// can push the correct goal value to the widget without needing a view reference.
    func updateStepGoalForSync(_ goal: Double) {
        stepGoalForSync = goal
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
                HealthWidgetSync.syncSteps(
                    stepsToday: steps,
                    stepGoal: self.stepGoalForSync
                )
            }
        }

        healthStore.execute(query)
    }

    private func enableStepBackgroundDelivery() {
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error {
                print("HealthKit step background delivery error:", error)
            }
        }
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
    
    func totalSteps(from startDate: Date, to endDate: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?
                    .sumQuantity()?
                    .doubleValue(for: .count()) ?? 0

                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
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
