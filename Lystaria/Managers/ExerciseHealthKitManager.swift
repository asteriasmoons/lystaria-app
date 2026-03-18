//
//  ExerciseHealthKitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import Foundation
import HealthKit
import Combine

final class ExerciseHealthKitManager: ObservableObject {
    static let shared = ExerciseHealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - HealthKit Availability

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Types

    private var workoutType: HKWorkoutType {
        HKObjectType.workoutType()
    }

    // MARK: - Permissions

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw ExerciseHealthKitError.healthDataUnavailable
        }

        let shareTypes: Set<HKSampleType> = [workoutType]
        let readTypes: Set<HKObjectType> = [workoutType]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Save Entry

    func saveExerciseLogEntry(_ entry: ExerciseLogEntry) async throws {
        guard isHealthDataAvailable else {
            throw ExerciseHealthKitError.healthDataUnavailable
        }

        let startDate = entry.date
        let endDate = startDate.addingTimeInterval(TimeInterval(entry.durationMinutes * 60))

        let exerciseName = entry.exerciseName
        let reps = entry.reps

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: startDate) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                builder.addMetadata([
                    HKMetadataKeyWorkoutBrandName: "Lystaria",
                    "LystariaExerciseName": exerciseName,
                    "LystariaReps": "\(reps)"  // String — HealthKit metadata requires plist-safe types
                ]) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    builder.endCollection(withEnd: endDate) { success, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        builder.finishWorkout { workout, error in
                            if let error {
                                continuation.resume(throwing: error)
                                return
                            }

                            guard workout != nil else {
                                continuation.resume(throwing: ExerciseHealthKitError.saveFailed)
                                return
                            }

                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func save(_ workout: HKWorkout) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard success else {
                    continuation.resume(throwing: ExerciseHealthKitError.saveFailed)
                    return
                }

                continuation.resume()
            }
        }
    }
}

// MARK: - Errors

enum ExerciseHealthKitError: LocalizedError {
    case healthDataUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .saveFailed:
            return "Failed to save exercise log to Apple Health."
        }
    }
}
