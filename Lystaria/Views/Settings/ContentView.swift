// ContentView.swift
// Lystaria

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showMoodRoute = false
    @State private var pendingOpenMoodFromWidget = false
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
                NavigationStack {
                    ZStack {
                        MainTabView()
                            .environmentObject(appState)
                            .preferredColorScheme(.dark)

                        NavigationLink(isActive: $showMoodRoute) {
                            MoodLoggerView()
                        } label: {
                            EmptyView()
                        }
                        .hidden()
                    }
                }
            } else {
                LystariaBackground().ignoresSafeArea()
            }
        }
        .onAppear {
            if alwaysShowWelcomeForDev {
                hasSeenWelcome = false
            }

            if case .signedIn = appState.status, pendingOpenMoodFromWidget {
                openPendingWidgetRoute()
            }
        }
        .onReceive(appState.$status) { newStatus in
            if case .signedIn = newStatus, pendingOpenMoodFromWidget {
                openPendingWidgetRoute()
            }
        }
        .onOpenURL { url in
            print("DEEPLINK URL:", url)
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "lystaria" else { return }

        print("HANDLE DEEPLINK HOST:", url.host ?? "nil")
        switch url.host?.lowercased() {
        case "mood":
            pendingOpenMoodFromWidget = true

            if case .signedIn = appState.status {
                openPendingWidgetRoute()
            }
        default:
            break
        }
    }

    private func openPendingWidgetRoute() {
        guard pendingOpenMoodFromWidget else { return }
        print("OPEN PENDING MOOD ROUTE")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showMoodRoute = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("SETTING showMoodRoute = true")
                showMoodRoute = true
                pendingOpenMoodFromWidget = false
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
