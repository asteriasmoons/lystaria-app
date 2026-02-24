// ContentView.swift
// Lystaria

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    // DEV MODE:
    // Set this to `true` while testing the welcome flow.
    // Resets the welcome flag on every fresh app launch so the flow always shows.
    // Change it back to `false` when you're done testing.
    private let alwaysShowWelcomeForDev = true
    @Query private var authUsers: [AuthUser]

    var body: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeFlowView()
                    .preferredColorScheme(.dark)
            } else if authUsers.isEmpty {
                SignInView()
                    .preferredColorScheme(.dark)
            } else {
                MainTabView()
                    .preferredColorScheme(.dark)
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
        ], inMemory: true)
}
