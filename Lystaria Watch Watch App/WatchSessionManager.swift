//
//  WatchSessionManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import Foundation
import Combine
import WatchConnectivity
import Supabase

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private enum Keys {
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
    }

    private let session = WCSession.default

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - iPhone -> Watch

    func sendCurrentSupabaseSessionToWatch() async {
        guard session.activationState == .activated else { return }

        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif

        do {
            let currentSession = try await SupabaseManager.shared.auth.session
            let context: [String: Any] = [
                Keys.accessToken: currentSession.accessToken,
                Keys.refreshToken: currentSession.refreshToken
            ]

            try session.updateApplicationContext(context)
        } catch {
            print("Failed to send Supabase session to watch: \(error)")
        }
    }

    // MARK: - Watch <- iPhone

    private func restoreSupabaseSession(from applicationContext: [String: Any]) async {
        guard
            let accessToken = applicationContext[Keys.accessToken] as? String,
            let refreshToken = applicationContext[Keys.refreshToken] as? String
        else {
            return
        }

        do {
            _ = try await SupabaseManager.shared.auth.setSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            print("Supabase session restored on watch.")
        } catch {
            print("Failed to restore Supabase session on watch: \(error)")
        }
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

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            await WatchSessionManager.shared.sendCurrentSupabaseSessionToWatch()
        }
    }
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        Task { @MainActor in
            await WatchSessionManager.shared.restoreSupabaseSession(from: applicationContext)
        }
    }
}
