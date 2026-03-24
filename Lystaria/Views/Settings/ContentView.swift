// ContentView.swift
// Lystaria

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Query(filter: #Predicate<JournalBook> { $0.deletedAt == nil }, sort: \JournalBook.createdAt, order: .reverse) private var journalBooks: [JournalBook]
    @State private var showMoodRoute = false
    @State private var pendingOpenMoodFromWidget = false
    @State private var showJournalBookRoute = false
    @State private var pendingJournalBookIDFromWidget: String? = nil
    @State private var selectedJournalBookForWidget: JournalBook? = nil
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

                        VStack {
                            NavigationLink(isActive: $showMoodRoute) {
                                MoodLoggerView()
                            } label: {
                                EmptyView()
                            }
                            .hidden()

                            NavigationLink(isActive: $showJournalBookRoute) {
                                if let selectedJournalBookForWidget {
                                    JournalBookDetailView(book: selectedJournalBookForWidget)
                                } else {
                                    EmptyView()
                                }
                            } label: {
                                EmptyView()
                            }
                            .hidden()
                        }
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
                openPendingMoodRoute()
            }

            if case .signedIn = appState.status, pendingJournalBookIDFromWidget != nil {
                openPendingJournalBookRoute()
            }
        }
        .onReceive(appState.$status) { newStatus in
            if case .signedIn = newStatus, pendingOpenMoodFromWidget {
                openPendingMoodRoute()
            }

            if case .signedIn = newStatus, pendingJournalBookIDFromWidget != nil {
                openPendingJournalBookRoute()
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
                openPendingMoodRoute()
            }
        case "journal-book":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let bookID = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  !bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            pendingJournalBookIDFromWidget = bookID

            if case .signedIn = appState.status {
                openPendingJournalBookRoute()
            }
        default:
            break
        }
    }

    private func openPendingMoodRoute() {
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

    private func openPendingJournalBookRoute() {
        guard let pendingBookID = pendingJournalBookIDFromWidget else { return }
        print("OPEN PENDING JOURNAL BOOK ROUTE:", pendingBookID)

        guard let matchedBook = journalBooks.first(where: {
            "\($0.persistentModelID)" == pendingBookID
        }) else {
            print("NO MATCHING JOURNAL BOOK FOUND FOR WIDGET ROUTE")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedJournalBookForWidget = matchedBook
            showJournalBookRoute = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("SETTING showJournalBookRoute = true")
                showJournalBookRoute = true
                pendingJournalBookIDFromWidget = nil
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
