//
//  Lystaria_WatchApp.swift
//  Lystaria Watch Watch App
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import SwiftData

@main
struct Lystaria_Watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    MoodLog.self,
                    JournalBook.self,
                    JournalEntry.self
                ])
                .onAppear {
                    WatchSessionManager.shared.activate()
                }
        }
    }
}
