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

        // Compute score at creation time (stored, not derived later)
        self.score = MoodLog.computeScore(for: normalizedMoods)

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
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.moodsStorage = "[]"
        self.activitiesStorage = "[]"
        self.note = note
        self.deletedAt = deletedAt
        self.score = MoodLog.clampScore(score)

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

    /// Compute the average score based on the selected moods.
    static func computeScore(for moods: [String]) -> Double {
        let normalized = normalizeList(moods)
        let values = normalized.compactMap { moodScores[$0] }
        guard !values.isEmpty else { return 3.0 }
        let avg = values.reduce(0, +) / Double(values.count)
        return clampScore(avg)
    }

    /// Keep score in 1...5
    private static func clampScore(_ value: Double) -> Double {
        min(5.0, max(1.0, value))
    }

    /// Convenience: whether all moods/activities are from your allowed lists
    var isUsingOnlyAllowedValues: Bool {
        let moodSet = Set(MoodLog.moodValues)
        let activitySet = Set(MoodLog.moodActivities)
        return Set(moods).isSubset(of: moodSet) && Set(activities).isSubset(of: activitySet)
    }
}
