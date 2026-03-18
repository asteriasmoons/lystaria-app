//
//  HealthMetricsHealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import Foundation
import HealthKit
import Combine

final class HealthMetricsHealthKitManager: ObservableObject {
    static let shared = HealthMetricsHealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - HealthKit Availability

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Types

    private var oxygenType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
    }

    private var systolicType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
    }

    private var diastolicType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
    }

    private var heartRateType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .heartRate)
    }

    private var temperatureType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
    }

    private var weightType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    private var bloodPressureCorrelationType: HKCorrelationType? {
        HKCorrelationType.correlationType(forIdentifier: .bloodPressure)
    }

    // MARK: - Permissions

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthMetricsHealthKitError.healthDataUnavailable
        }

        guard
            let oxygenType,
            let systolicType,
            let diastolicType,
            let heartRateType,
            let temperatureType,
            let weightType
        else {
            throw HealthMetricsHealthKitError.requiredTypeUnavailable
        }

        let shareTypes: Set<HKSampleType> = [
            oxygenType,
            systolicType,
            diastolicType,
            heartRateType,
            temperatureType,
            weightType
        ]

        let readTypes: Set<HKObjectType> = [
            oxygenType,
            systolicType,
            diastolicType,
            heartRateType,
            temperatureType,
            weightType
        ]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Save Entry

    func saveHealthMetricEntry(_ entry: HealthMetricEntry) async throws {
        guard isHealthDataAvailable else {
            throw HealthMetricsHealthKitError.healthDataUnavailable
        }

        guard
            let oxygenType,
            let systolicType,
            let diastolicType,
            let heartRateType,
            let temperatureType,
            let weightType,
            let bloodPressureCorrelationType
        else {
            throw HealthMetricsHealthKitError.requiredTypeUnavailable
        }

        let date = entry.date
        var objectsToSave: [HKObject] = []

        // Blood Oxygen
        // App stores as whole number (e.g. 98), HealthKit expects fraction (0.98)
        if entry.bloodOxygen > 0 {
            let oxygenFraction = entry.bloodOxygen / 100.0
            let sample = HKQuantitySample(
                type: oxygenType,
                quantity: HKQuantity(unit: .percent(), doubleValue: oxygenFraction),
                start: date,
                end: date
            )
            objectsToSave.append(sample)
        }

        // Blood Pressure — HealthKit requires both values wrapped in a correlation
        if entry.systolic > 0 && entry.diastolic > 0 {
            let systolicSample = HKQuantitySample(
                type: systolicType,
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: Double(entry.systolic)),
                start: date,
                end: date
            )
            let diastolicSample = HKQuantitySample(
                type: diastolicType,
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: Double(entry.diastolic)),
                start: date,
                end: date
            )
            let correlation = HKCorrelation(
                type: bloodPressureCorrelationType,
                start: date,
                end: date,
                objects: [systolicSample, diastolicSample]
            )
            objectsToSave.append(correlation)
        }

        // Heart Rate
        if entry.bpm > 0 {
            let sample = HKQuantitySample(
                type: heartRateType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(entry.bpm)),
                start: date,
                end: date
            )
            objectsToSave.append(sample)
        }

        // Body Temperature
        if entry.bodyTemperature > 0 {
            let sample = HKQuantitySample(
                type: temperatureType,
                quantity: HKQuantity(unit: .degreeFahrenheit(), doubleValue: entry.bodyTemperature),
                start: date,
                end: date
            )
            objectsToSave.append(sample)
        }

        // Weight
        if entry.weight > 0 {
            let sample = HKQuantitySample(
                type: weightType,
                quantity: HKQuantity(unit: .pound(), doubleValue: entry.weight),
                start: date,
                end: date
            )
            objectsToSave.append(sample)
        }

        guard !objectsToSave.isEmpty else { return }
        try await save(objectsToSave)
    }

    // MARK: - Helpers

    private func save(_ objects: [HKObject]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(objects) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard success else {
                    continuation.resume(throwing: HealthMetricsHealthKitError.saveFailed)
                    return
                }

                continuation.resume()
            }
        }
    }
}

// MARK: - Errors

enum HealthMetricsHealthKitError: LocalizedError {
    case healthDataUnavailable
    case requiredTypeUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .requiredTypeUnavailable:
            return "One or more required HealthKit data types are unavailable."
        case .saveFailed:
            return "Failed to save health metrics to Apple Health."
        }
    }
}
