// MoodLog.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB MoodLog schema

import Foundation
import SwiftData

@Model
final class MoodLog {
    // MARK: - Local metadata
    var deletedAt: Date?

    // MARK: - Mini-app mirrored fields
    /// 1+ moods selected (stored as strings to match TS union values exactly)
    var moodsStorage: String = "[]"

    /// 0+ activities selected
    var activitiesStorage: String = "[]"

    /// Optional note (mini-app max 1500, enforce in UI)
    var note: String?

    /// Stored computed average mood score (1–5) at creation time
    var score: Double = 3.0

    /// Stored emotional valence (-3 to +3) at creation time
    var valence: Double = 0.0

    /// Stored emotional intensity (1 to 5) at creation time
    var intensity: Double = 1.0

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var moods: [String] {
        get {
            guard let data = moodsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                moodsStorage = encoded
            } else {
                moodsStorage = "[]"
            }
        }
    }

    var activities: [String] {
        get {
            guard let data = activitiesStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                activitiesStorage = encoded
            } else {
                activitiesStorage = "[]"
            }
        }
    }

    // MARK: - Single source of truth (mirrors mini-app constants)

    static let moodValues: [String] = [
        "happy","content","inspired","productive","loved","grateful","optimistic","confident","motivated","proud",
        "energized","hopeful","playful","satisfied",
        "okay","neutral","reflective","distracted","confused","calm","thoughtful","mellow","settled",
        "indifferent","reserved","detached","apathetic","composed",
        "sad","irritated","disappointed","angry","insecure","overwhelmed","stressed","scared","lonely","discouraged",
        "drained","frustrated","restless","defeated"
    ]

    static let moodActivities: [String] = [
        "friends","family","community","dating",
        "hobby","creative","work","education","reading",
        "hygiene","fitness","health","self-care","mindfulness",
        "chores","errands","shopping","baking",
        "pets","nature",
        "journaling","spirituality","religion",
        "entertainment","social-media","tech"
    ]

    /// Mood score mapping (1–5 scale) — mirrors your mini-app MOOD_SCORES
    static let moodScores: [String: Double] = [
        "happy": 4.3,
        "content": 3.8,
        "inspired": 4.2,
        "productive": 4.1,
        "loved": 4.4,
        "grateful": 4.4,
        "optimistic": 4.0,
        "confident": 4.0,
        "motivated": 4.0,
        "proud": 4.1,
        "energized": 4.2,
        "hopeful": 4.0,
        "playful": 4.0,
        "satisfied": 3.8,

        "okay": 3.2,
        "neutral": 3.0,
        "reflective": 3.2,
        "distracted": 2.8,
        "confused": 2.7,
        "calm": 3.3,
        "thoughtful": 3.3,
        "mellow": 3.2,
        "settled": 3.3,
        "indifferent": 2.9,
        "reserved": 3.0,
        "detached": 2.8,
        "apathetic": 2.4,
        "composed": 3.3,

        "sad": 1.8,
        "irritated": 2.0,
        "disappointed": 1.9,
        "angry": 1.7,
        "insecure": 1.9,
        "overwhelmed": 1.6,
        "stressed": 1.7,
        "scared": 1.6,
        "lonely": 1.7,
        "discouraged": 1.8,
        "drained": 1.8,
        "frustrated": 1.9,
        "restless": 2.2,
        "defeated": 1.6
    ]
    
    private struct MoodDefinition {
        let valence: Double
        let intensity: Double
    }

    private static let moodDefinitions: [String: MoodDefinition] = [
        "happy": .init(valence: 3, intensity: 3),
        "loved": .init(valence: 3, intensity: 3),
        "grateful": .init(valence: 3, intensity: 2),
        "proud": .init(valence: 3, intensity: 3),

        "content": .init(valence: 2, intensity: 1),
        "inspired": .init(valence: 3, intensity: 4),
        "productive": .init(valence: 2, intensity: 3),
        "optimistic": .init(valence: 2, intensity: 2),
        "confident": .init(valence: 2, intensity: 3),
        "motivated": .init(valence: 2, intensity: 3),
        "energized": .init(valence: 3, intensity: 4),
        "hopeful": .init(valence: 2, intensity: 2),
        "playful": .init(valence: 2, intensity: 2),
        "satisfied": .init(valence: 2, intensity: 1),

        "okay": .init(valence: 0, intensity: 1),
        "neutral": .init(valence: 0, intensity: 1),
        "reflective": .init(valence: 0, intensity: 2),
        "calm": .init(valence: 1, intensity: 1),
        "thoughtful": .init(valence: 0, intensity: 2),
        "mellow": .init(valence: 1, intensity: 1),
        "settled": .init(valence: 1, intensity: 1),
        "reserved": .init(valence: 0, intensity: 1),
        "composed": .init(valence: 1, intensity: 2),

        "distracted": .init(valence: -1, intensity: 2),
        "confused": .init(valence: -1, intensity: 2),
        "indifferent": .init(valence: -1, intensity: 1),
        "detached": .init(valence: -1, intensity: 2),
        "apathetic": .init(valence: -2, intensity: 1),

        "sad": .init(valence: -2, intensity: 2),
        "irritated": .init(valence: -2, intensity: 3),
        "disappointed": .init(valence: -2, intensity: 2),
        "insecure": .init(valence: -2, intensity: 3),
        "lonely": .init(valence: -2, intensity: 2),
        "discouraged": .init(valence: -2, intensity: 2),
        "drained": .init(valence: -2, intensity: 2),
        "frustrated": .init(valence: -2, intensity: 3),
        "restless": .init(valence: -1, intensity: 3),

        "angry": .init(valence: -3, intensity: 4),
        "overwhelmed": .init(valence: -3, intensity: 5),
        "stressed": .init(valence: -2, intensity: 4),
        "scared": .init(valence: -3, intensity: 4),
        "defeated": .init(valence: -3, intensity: 3)
    ]

    // MARK: - Initializers

    /// Preferred init: you pass moods/activities/note; score is computed at creation time (mini-app behavior).
    init(
        moods: [String],
        activities: [String] = [],
        note: String? = nil,
        deletedAt: Date? = nil
    ) {
        let normalizedMoods = MoodLog.normalizeList(moods)
        let normalizedActivities = MoodLog.normalizeList(activities)

        self.moodsStorage = "[]"
        self.activitiesStorage = "[]"
        self.note = note
        self.deletedAt = deletedAt

        // Compute score + emotional metrics at creation time (stored, not derived later)
        let result = MoodLog.computeScoringResult(for: normalizedMoods)
        self.score = result.score
        self.valence = result.valence
        self.intensity = result.intensity

        // Timestamps
        self.createdAt = Date()
        self.updatedAt = Date()

        // Now safe to use computed properties
        self.moods = normalizedMoods
        self.activities = normalizedActivities
    }

    /// Alternate init if you ever need to import an already-computed score (e.g., from server sync).
    init(
        moods: [String],
        activities: [String] = [],
        note: String? = nil,
        score: Double,
        valence: Double = 0.0,
        intensity: Double = 1.0,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.moodsStorage = "[]"
        self.activitiesStorage = "[]"
        self.note = note
        self.deletedAt = deletedAt
        self.score = MoodLog.clampScore(score)
        self.valence = MoodLog.clampValence(valence)
        self.intensity = MoodLog.clampIntensity(intensity)

        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Now safe to use computed properties
        self.moods = MoodLog.normalizeList(moods)
        self.activities = MoodLog.normalizeList(activities)
    }

    // MARK: - Helpers (validation-ish + scoring)

    /// True if the log meets the mini-app rule: at least one mood is required.
    var hasAtLeastOneMood: Bool {
        !moods.isEmpty
    }

    /// Call this when you edit fields so the updated timestamp stays current.
    func touchUpdated() {
        updatedAt = Date()
    }

    /// Normalize arrays for safe local storage.
    private static func normalizeList(_ list: [String]) -> [String] {
        list
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// Compute score, valence, and intensity from the selected moods.
    struct ScoringResult {
        let score: Double
        let valence: Double
        let intensity: Double
    }

    static func computeScoringResult(for moods: [String]) -> ScoringResult {
        let normalized = normalizeList(moods)
        let defs = normalized.compactMap { moodDefinitions[$0] }
        let scoreValues = normalized.compactMap { moodScores[$0] }

        guard !defs.isEmpty else {
            return ScoringResult(score: 3.0, valence: 0.3, intensity: 1.0)
        }

        let avgScore: Double = {
            guard !scoreValues.isEmpty else { return 3.0 }
            return scoreValues.reduce(0.0, +) / Double(scoreValues.count)
        }()

        let avgIntensity = defs.reduce(0.0) { $0 + $1.intensity } / Double(defs.count)

        let totalWeightedValence = defs.reduce(0.0) { partial, def in
            partial + (def.valence * def.intensity)
        }
        let totalIntensityWeight = defs.reduce(0.0) { partial, def in
            partial + max(def.intensity, 1.0)
        }

        var emotionalTone = totalIntensityWeight > 0
            ? totalWeightedValence / totalIntensityWeight
            : 0.0

        if abs(emotionalTone) < 0.15 {
            if let strongestNonZero = defs
                .filter({ $0.valence != 0 })
                .max(by: { abs($0.valence * $0.intensity) < abs($1.valence * $1.intensity) }) {
                emotionalTone = strongestNonZero.valence > 0 ? 0.5 : -0.5
            } else {
                let fallbackTone = ((avgScore - 1.0) / 4.0) * 6.0 - 3.0
                emotionalTone = fallbackTone >= 0 ? max(fallbackTone, 0.3) : min(fallbackTone, -0.3)
            }
        }

        return ScoringResult(
            score: clampScore(avgScore),
            valence: clampValence(emotionalTone),
            intensity: clampIntensity(avgIntensity)
        )
    }

    /// Compute the UI score based on the selected moods.
    static func computeScore(for moods: [String]) -> Double {
        computeScoringResult(for: moods).score
    }

    /// Compute stored valence based on the selected moods.
    static func computeValence(for moods: [String]) -> Double {
        computeScoringResult(for: moods).valence
    }

    /// Compute stored intensity based on the selected moods.
    static func computeIntensity(for moods: [String]) -> Double {
        computeScoringResult(for: moods).intensity
    }

    /// Keep score in 1...5
    private static func clampScore(_ value: Double) -> Double {
        min(5.0, max(1.0, value))
    }

    /// Keep valence in -3...3
    private static func clampValence(_ value: Double) -> Double {
        min(3.0, max(-3.0, value))
    }

    /// Keep intensity in 1...5
    private static func clampIntensity(_ value: Double) -> Double {
        min(5.0, max(1.0, value))
    }

    /// Convenience: whether all moods/activities are from your allowed lists
    var isUsingOnlyAllowedValues: Bool {
        let moodSet = Set(MoodLog.moodValues)
        let activitySet = Set(MoodLog.moodActivities)
        return Set(moods).isSubset(of: moodSet) && Set(activities).isSubset(of: activitySet)
    }
}
