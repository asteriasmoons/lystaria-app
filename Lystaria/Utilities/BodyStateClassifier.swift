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

    // MARK: - Public entry point

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
                bodyScore: 0.5,
                nervousSystemScore: 0.5,
                bodyLabel: "Elevated",
                nervousSystemLabel: "Elevated",
                latestHRV: latestHRV,
                baselineHRV: baselineHRV,
                latestHeartRate: latestHeartRate,
                restingHeartRate: restingHeartRate,
                updatedAt: now
            )
        }

        // --- HRV ratio: today's average vs personal 30-day baseline ---
        // Clamped to 0.3–1.6 so extreme outliers don't dominate the score.
        // A ratio of 1.0 means today matches your normal baseline exactly.
        let rawRatio = latestHRV / baselineHRV
        let hrvRatio = clamp(rawRatio, min: 0.3, max: 1.6)

        // Normalise the ratio into a 0–1 HRV score.
        // ratio 0.3 → 0.0, ratio 1.0 → 0.58, ratio 1.6 → 1.0
        let hrvScore = (hrvRatio - 0.3) / (1.6 - 0.3)

        // --- Heart rate elevation: how far above resting right now ---
        // Only penalises when current HR exceeds resting; if unavailable, neutral (0).
        let hrPenalty: Double = {
            guard let latestHeartRate, let restingHeartRate, restingHeartRate > 0 else { return 0 }
            let delta = latestHeartRate - restingHeartRate
            // Normalise: +40 bpm above resting = full penalty of 1.0
            return clamp(delta / 40.0, min: 0, max: 1)
        }()

        // --- Composite scores ---
        // Body State weights HRV more, uses a gentle HR penalty.
        // Nervous System weights HRV slightly less and is more sensitive to HR elevation.
        let bodyRaw    = (hrvScore * 0.80) - (hrPenalty * 0.20)
        let nervousRaw = (hrvScore * 0.70) - (hrPenalty * 0.30)

        let bodyScore          = clamp(bodyRaw,    min: 0, max: 1)
        let nervousSystemScore = clamp(nervousRaw, min: 0, max: 1)

        return BodyStateSnapshot(
            bodyScore: bodyScore,
            nervousSystemScore: nervousSystemScore,
            bodyLabel: label(for: bodyScore),
            nervousSystemLabel: label(for: nervousSystemScore),
            latestHRV: latestHRV,
            baselineHRV: baselineHRV,
            latestHeartRate: latestHeartRate,
            restingHeartRate: restingHeartRate,
            updatedAt: now
        )
    }

    // MARK: - Shared label thresholds
    //
    // Thresholds are intentionally more generous than the previous system.
    // A ratio at baseline (1.0) produces an hrvScore of ~0.58, which lands
    // in Mellow — meaning "normal" reads as normal, not stressed.
    //
    //  < 0.20 → Rest Needed
    //  < 0.38 → Stressed
    //  < 0.55 → Elevated
    //  < 0.75 → Mellow
    //  ≥ 0.75 → Excellent

    private static func label(for score: Double) -> String {
        switch score {
        case ..<0.20: return "Rest Needed"
        case ..<0.38: return "Activated"
        case ..<0.55: return "Elevated"
        case ..<0.75: return "Mellow"
        default:      return "Excellent"
        }
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
