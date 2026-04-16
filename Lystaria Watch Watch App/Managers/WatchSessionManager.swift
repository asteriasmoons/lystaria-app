//
//  WatchSessionManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import Foundation
import Combine
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private let session = WCSession.default
    private static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    private static let fileName   = "watch_health_data.plist"

    // MARK: - Keys
    enum Keys {
        static let stepsToday          = "watch.stepsToday"
        static let stepGoal            = "watch.stepGoal"
        static let waterToday          = "watch.waterToday"
        static let waterGoal           = "watch.waterGoal"
        static let bodyScore           = "watch.bodyScore"
        static let bodyLabel           = "watch.bodyLabel"
        static let nervousSystemScore  = "watch.nervousSystemScore"
        static let nervousSystemLabel  = "watch.nervousSystemLabel"
        static let completionPct       = "watch.completionPct"
        static let sleepHours          = "watch.sleepHours"
        static let sleepScore          = "watch.sleepScore"
        static let sleepLabel          = "watch.sleepLabel"
    }

    @Published var waterGoal: Double = {
        WatchSessionManager.readAll()[Keys.waterGoal] as? Double ?? 80
    }()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Shared file read/write

    private static func containerURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func readAll() -> [String: Any] {
        guard let url = containerURL(),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else { return [:] }
        return dict
    }

    private static func write(_ data: [String: Any]) {
        guard let url = containerURL() else { return }
        (data as NSDictionary).write(to: url, atomically: true)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WCSession activation error: \(error)")
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {}
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            var current = WatchSessionManager.readAll()

            if let v = applicationContext["stepsToday"] as? Double {
                current[WatchSessionManager.Keys.stepsToday] = v
            }
            if let v = applicationContext["stepGoal"] as? Double {
                current[WatchSessionManager.Keys.stepGoal] = v
            }
            if let v = applicationContext["waterToday"] as? Double {
                current[WatchSessionManager.Keys.waterToday] = v
            }
            if let v = applicationContext["waterGoal"] as? Double {
                self.waterGoal = v
                current[WatchSessionManager.Keys.waterGoal] = v
            }
            if let v = applicationContext["bodyScore"] as? Double {
                current[WatchSessionManager.Keys.bodyScore] = v
            }
            if let v = applicationContext["bodyLabel"] as? String {
                current[WatchSessionManager.Keys.bodyLabel] = v
            }
            if let v = applicationContext["nervousSystemScore"] as? Double {
                current[WatchSessionManager.Keys.nervousSystemScore] = v
            }
            if let v = applicationContext["nervousSystemLabel"] as? String {
                current[WatchSessionManager.Keys.nervousSystemLabel] = v
            }
            if let v = applicationContext["completionPct"] as? Double {
                current[WatchSessionManager.Keys.completionPct] = v
            }
            if let v = applicationContext["sleepHours"] as? Double {
                current[WatchSessionManager.Keys.sleepHours] = v
            }
            if let v = applicationContext["sleepScore"] as? Double {
                current[WatchSessionManager.Keys.sleepScore] = v
            }
            if let v = applicationContext["sleepLabel"] as? String {
                current[WatchSessionManager.Keys.sleepLabel] = v
            }

            WatchSessionManager.write(current)
            print("✅ WatchSessionManager: wrote health data to shared container")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
