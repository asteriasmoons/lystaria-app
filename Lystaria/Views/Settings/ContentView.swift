// ContentView.swift
// Lystaria

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    // WELCOME DEV MODE:
    // Set this to `true` while testing the welcome flow.
    // Resets the welcome flag on every fresh app launch so the flow always shows.
    // Change it back to `false` when you're done testing.
    private let alwaysShowWelcomeForDev = false

    var body: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeFlowView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            } else if case .signedOut = appState.status {
                SignInView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            } else if case .signedIn = appState.status {
                MainTabView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            } else {
                LystariaBackground().ignoresSafeArea()
            }
        }
        .onAppear {
            if alwaysShowWelcomeForDev {
                hasSeenWelcome = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            AuthUser.self, Book.self, CalendarEvent.self,
            Habit.self, HabitLog.self, MoodLog.self,
            JournalEntry.self, LystariaReminder.self,
            UserSettings.self, Checklist.self, ChecklistItem.self,
            KanbanBoard.self,
            KanbanColumn.self,
        ], inMemory: true)
}
