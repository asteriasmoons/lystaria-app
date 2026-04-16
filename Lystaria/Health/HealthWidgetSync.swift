//
//  HealthWidgetSync.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/22/26.
//

import Foundation
import WidgetKit
import WatchConnectivity

enum HealthWidgetSync {

    // MARK: - App Group
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys
    private enum Keys {
        static let stepsToday          = "healthWidget.stepsToday"
        static let stepGoal            = "healthWidget.stepGoal"
        static let waterToday          = "healthWidget.waterToday"
        static let waterGoal           = "healthWidget.waterGoal"
        static let bodyScore           = "healthWidget.bodyScore"
        static let bodyLabel           = "healthWidget.bodyLabel"
        static let nervousSystemScore  = "healthWidget.nervousSystemScore"
        static let nervousSystemLabel  = "healthWidget.nervousSystemLabel"
        static let completionPct       = "healthWidget.completionPct"
        static let sleepHours          = "healthWidget.sleepHours"
        static let sleepScore          = "healthWidget.sleepScore"
        static let sleepLabel          = "healthWidget.sleepLabel"
    }

    // MARK: - WatchConnectivity send
    private static func sendToWatch(_ context: [String: Any]) {
        #if os(iOS)
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        // Always add a timestamp so WatchConnectivity treats it as a new
        // context and delivers it even if all other values are unchanged.
        var ctx = context
        ctx["_ts"] = Date().timeIntervalSince1970
        try? WCSession.default.updateApplicationContext(ctx)
        #endif
    }

    // MARK: - Full context builder
    // Always sends all keys together so the watch plist is never partial.
    private static func sendFullContext(
        stepsToday: Double? = nil,
        stepGoal: Double? = nil,
        waterToday: Double? = nil,
        waterGoal: Double? = nil,
        bodyScore: Double? = nil,
        bodyLabel: String? = nil,
        nervousSystemScore: Double? = nil,
        nervousSystemLabel: String? = nil,
        completionPct: Double? = nil,
        sleepHours: Double? = nil,
        sleepScore: Double? = nil,
        sleepLabel: String? = nil
    ) {
        let d = defaults
        func dbl(_ key: String, _ override: Double?) -> Double {
            override ?? d?.double(forKey: key) ?? 0
        }
        func str(_ key: String, _ override: String?) -> String {
            override ?? d?.string(forKey: key) ?? ""
        }
        sendToWatch([
            "stepsToday":          dbl(Keys.stepsToday,         stepsToday),
            "stepGoal":            dbl(Keys.stepGoal,           stepGoal),
            "waterToday":          dbl(Keys.waterToday,         waterToday),
            "waterGoal":           dbl(Keys.waterGoal,          waterGoal),
            "bodyScore":           dbl(Keys.bodyScore,          bodyScore),
            "bodyLabel":           str(Keys.bodyLabel,          bodyLabel),
            "nervousSystemScore":  dbl(Keys.nervousSystemScore, nervousSystemScore),
            "nervousSystemLabel":  str(Keys.nervousSystemLabel, nervousSystemLabel),
            "completionPct":       dbl(Keys.completionPct,      completionPct),
            "sleepHours":          dbl(Keys.sleepHours,         sleepHours),
            "sleepScore":          dbl(Keys.sleepScore,         sleepScore),
            "sleepLabel":          str(Keys.sleepLabel,         sleepLabel)
        ])
    }

    // MARK: - Main Sync

    static func sync(
        stepsToday: Double,
        stepGoal: Double,
        waterToday: Double,
        waterGoal: Double
    ) {
        guard let d = defaults else { return }
        d.set(stepsToday, forKey: Keys.stepsToday)
        d.set(stepGoal,   forKey: Keys.stepGoal)
        d.set(waterToday, forKey: Keys.waterToday)
        d.set(waterGoal,  forKey: Keys.waterGoal)
        d.synchronize()
        sendFullContext(stepsToday: stepsToday, stepGoal: stepGoal,
                        waterToday: waterToday, waterGoal: waterGoal)
        print("✅ HealthWidgetSync.sync — steps: \(stepsToday)/\(stepGoal)  water: \(waterToday)/\(waterGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Body State Sync

    static func syncBodyState(
        bodyScore: Double,
        bodyLabel: String,
        nervousSystemScore: Double,
        nervousSystemLabel: String
    ) {
        guard let d = defaults else { return }
        d.set(bodyScore,          forKey: Keys.bodyScore)
        d.set(bodyLabel,          forKey: Keys.bodyLabel)
        d.set(nervousSystemScore, forKey: Keys.nervousSystemScore)
        d.set(nervousSystemLabel, forKey: Keys.nervousSystemLabel)
        d.synchronize()
        sendFullContext(bodyScore: bodyScore, bodyLabel: bodyLabel,
                        nervousSystemScore: nervousSystemScore, nervousSystemLabel: nervousSystemLabel)
        print("✅ HealthWidgetSync.syncBodyState — body: \(bodyLabel)(\(bodyScore))  nervous: \(nervousSystemLabel)(\(nervousSystemScore))")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Key accessors

    static var completionPctKey: String        { Keys.completionPct }
    static var sleepHoursKey: String           { Keys.sleepHours }
    static var sleepScoreKey: String           { Keys.sleepScore }
    static var sleepLabelKey: String           { Keys.sleepLabel }
    static var bodyScoreKey: String           { Keys.bodyScore }
    static var bodyLabelKey: String           { Keys.bodyLabel }
    static var nervousSystemScoreKey: String  { Keys.nervousSystemScore }
    static var nervousSystemLabelKey: String  { Keys.nervousSystemLabel }
    static var stepsTodayKey: String          { Keys.stepsToday }
    static var stepGoalKey: String            { Keys.stepGoal }
    static var waterTodayKey: String          { Keys.waterToday }
    static var waterGoalKey: String           { Keys.waterGoal }

    // MARK: - Convenience

    static func syncSleep(hours: Double, score: Double, label: String) {
        guard let d = defaults else { return }
        d.set(hours, forKey: Keys.sleepHours)
        d.set(score, forKey: Keys.sleepScore)
        d.set(label, forKey: Keys.sleepLabel)
        d.synchronize()
        sendFullContext(sleepHours: hours, sleepScore: score, sleepLabel: label)
        print("✅ HealthWidgetSync.syncSleep — \(label) (\(String(format: "%.1f", hours))h, score: \(score))")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func syncCompletionPct(_ pct: Double) {
        guard let d = defaults else { return }
        d.set(pct, forKey: Keys.completionPct)
        d.synchronize()
        sendFullContext(completionPct: pct)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func syncSteps(stepsToday: Double, stepGoal: Double) {
        guard let d = defaults else { return }
        d.set(stepsToday, forKey: Keys.stepsToday)
        d.set(stepGoal,   forKey: Keys.stepGoal)
        d.synchronize()
        sendFullContext(stepsToday: stepsToday, stepGoal: stepGoal)
        print("✅ HealthWidgetSync.syncSteps — steps: \(stepsToday)/\(stepGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func syncWater(waterToday: Double, waterGoal: Double) {
        guard let d = defaults else { return }
        d.set(waterToday, forKey: Keys.waterToday)
        d.set(waterGoal,  forKey: Keys.waterGoal)
        d.synchronize()
        sendFullContext(waterToday: waterToday, waterGoal: waterGoal)
        print("✅ HealthWidgetSync.syncWater — water: \(waterToday)/\(waterGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read helpers

    static func readDouble(for key: String, fallback: Double) -> Double {
        guard let d = defaults else { return fallback }
        if d.object(forKey: key) == nil { return fallback }
        return d.double(forKey: key)
    }

    static func readString(for key: String, fallback: String) -> String {
        defaults?.string(forKey: key) ?? fallback
    }
}
