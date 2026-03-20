//
//  BodyStateClassifier.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation

struct BodyStateSnapshot {
    let bodyScore: Double              // 0...1
    let nervousSystemScore: Double     // 0...1
    let bodyLabel: String
    let nervousSystemLabel: String
    let latestHRV: Double?
    let baselineHRV: Double?
    let latestHeartRate: Double?
    let restingHeartRate: Double?
    let updatedAt: Date
}

enum BodyStateClassifier {
    static func classify(
        latestHRV: Double?,
        baselineHRV: Double?,
        latestHeartRate: Double?,
        restingHeartRate: Double?
    ) -> BodyStateSnapshot {
        let now = Date()

        guard
            let latestHRV,
            let baselineHRV,
            baselineHRV > 0
        else {
            return BodyStateSnapshot(
                bodyScore: 0.35,
                nervousSystemScore: 0.35,
                bodyLabel: "Rest Needed",
                nervousSystemLabel: "Elevated",
                latestHRV: latestHRV,
                baselineHRV: baselineHRV,
                latestHeartRate: latestHeartRate,
                restingHeartRate: restingHeartRate,
                updatedAt: now
            )
        }

        let hrvRatio = latestHRV / baselineHRV
        let hrDelta: Double = {
            guard let latestHeartRate, let restingHeartRate else { return 0 }
            return latestHeartRate - restingHeartRate
        }()

        // Higher HRV is better. Higher HR over resting usually suggests more activation/strain.
        let bodyRaw =
            (hrvRatio * 0.75) -
            (max(0, hrDelta) / 100.0 * 0.25)

        let nervousRaw =
            (hrvRatio * 0.65) -
            (max(0, hrDelta) / 60.0 * 0.35)

        let bodyScore = clamp(bodyRaw, min: 0, max: 1)
        let nervousSystemScore = clamp(nervousRaw, min: 0, max: 1)

        return BodyStateSnapshot(
            bodyScore: bodyScore,
            nervousSystemScore: nervousSystemScore,
            bodyLabel: bodyLabel(for: bodyScore),
            nervousSystemLabel: nervousSystemLabel(for: nervousSystemScore),
            latestHRV: latestHRV,
            baselineHRV: baselineHRV,
            latestHeartRate: latestHeartRate,
            restingHeartRate: restingHeartRate,
            updatedAt: now
        )
    }

    private static func bodyLabel(for score: Double) -> String {
        switch score {
        case ..<0.25: return "Rest Needed"
        case ..<0.45: return "Stressed"
        case ..<0.65: return "Elevated"
        case ..<0.82: return "Mellow"
        default:      return "Excellent"
        }
    }

    private static func nervousSystemLabel(for score: Double) -> String {
        switch score {
        case ..<0.25: return "Rest Needed"
        case ..<0.45: return "Stressed"
        case ..<0.65: return "Elevated"
        case ..<0.82: return "Mellow"
        default:      return "Excellent"
        }
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
