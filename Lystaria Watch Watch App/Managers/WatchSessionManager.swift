//
//  WatchSessionManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private let session = WCSession.default

    // Stored locally on Watch so it persists between launches
    @Published var waterGoal: Double = UserDefaults.standard.double(forKey: "watch.waterGoal") == 0
        ? 80
        : UserDefaults.standard.double(forKey: "watch.waterGoal")

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
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
        if let goal = applicationContext["waterGoal"] as? Double {
            Task { @MainActor in
                self.waterGoal = goal
                UserDefaults.standard.set(goal, forKey: "watch.waterGoal")
            }
        }
    }
}
