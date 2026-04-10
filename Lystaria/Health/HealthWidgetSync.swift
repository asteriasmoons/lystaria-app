//
//  HealthWidgetSync.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/22/26.
//

import Foundation
import WidgetKit

enum HealthWidgetSync {

    // MARK: - App Group

    static let appGroupID = "group.com.asteriasmoons.LystariaDev"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let stepsToday = "healthWidget.stepsToday"
        static let stepGoal   = "healthWidget.stepGoal"
        static let waterToday = "healthWidget.waterToday"
        static let waterGoal  = "healthWidget.waterGoal"
    }

    // MARK: - Main Sync

    static func sync(
        stepsToday: Double,
        stepGoal: Double,
        waterToday: Double,
        waterGoal: Double
    ) {
        guard let defaults else {
            print("❌ HealthWidgetSync: UserDefaults suite nil for \(appGroupID)")
            return
        }

        defaults.set(stepsToday, forKey: Keys.stepsToday)
        defaults.set(stepGoal,   forKey: Keys.stepGoal)
        defaults.set(waterToday, forKey: Keys.waterToday)
        defaults.set(waterGoal,  forKey: Keys.waterGoal)
        defaults.synchronize()

        print("✅ HealthWidgetSync.sync — steps: \(stepsToday)/\(stepGoal)  water: \(waterToday)/\(waterGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Convenience

    static func syncSteps(
        stepsToday: Double,
        stepGoal: Double
    ) {
        guard let defaults else {
            print("❌ HealthWidgetSync: UserDefaults suite nil for \(appGroupID)")
            return
        }

        defaults.set(stepsToday, forKey: Keys.stepsToday)
        defaults.set(stepGoal,   forKey: Keys.stepGoal)
        defaults.synchronize()

        print("✅ HealthWidgetSync.syncSteps — steps: \(stepsToday)/\(stepGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func syncWater(
        waterToday: Double,
        waterGoal: Double
    ) {
        guard let defaults else {
            print("❌ HealthWidgetSync: UserDefaults suite nil for \(appGroupID)")
            return
        }

        defaults.set(waterToday, forKey: Keys.waterToday)
        defaults.set(waterGoal,  forKey: Keys.waterGoal)
        defaults.synchronize()

        print("✅ HealthWidgetSync.syncWater — water: \(waterToday)/\(waterGoal)")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
