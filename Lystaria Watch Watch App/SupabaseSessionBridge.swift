//
//  SupabaseSessionBridge.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import Foundation

enum SupabaseSessionBridge {
    /// Call this after iPhone sign-in succeeds,
    /// and also after app launch if a session already exists.
    @MainActor
    static func syncSessionToWatch() async {
        await WatchSessionManager.shared.sendCurrentSupabaseSessionToWatch()
    }
}
