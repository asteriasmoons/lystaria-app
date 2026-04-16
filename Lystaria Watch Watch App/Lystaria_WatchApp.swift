//
//  Lystaria_WatchApp.swift
//  Lystaria Watch Watch App
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import SwiftData
import WidgetKit

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

                    // On every launch, reload the widget with whatever data
                    // is already stored in the shared plist file. This ensures
                    // the complication shows data even after the watch app restarts.
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
