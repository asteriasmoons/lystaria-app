// LystariaApp.swift
// Lystaria

import SwiftUI
import SwiftData

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {}

@main
struct LystariaApp: App {

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AuthUser.self,
            Book.self,
            CalendarEvent.self,
            Habit.self,
            HabitSkip.self,
            HabitLog.self,
            MoodLog.self,
            BodyStateRecord.self,
            HealthMetricEntry.self,
            ExerciseLogEntry.self,
            ReadingStats.self,
            ReadingSession.self,
            ReadingGoal.self,
            BookmarkFolder.self,
            BookmarkItem.self,
            JournalEntry.self,
            JournalInlineStyle.self,
            JournalBlock.self,
            JournalBook.self,
            JournalPrompt.self,
            JournalPromptUsage.self,
            LystariaReminder.self,
            UserSettings.self,
            SelfCarePointEntry.self,
            SelfCarePointsProfile.self,
            Checklist.self,
            ChecklistItem.self,
            KanbanBoard.self,
            KanbanColumn.self,
            DailyIntention.self,
            DailyTarotRecord.self,
            DailyHoroscopeRecord.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let sharedModelContainer = LystariaApp.sharedModelContainer

    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(notificationManager)
                .onAppear {
                    WatchSessionManager.shared.activate()

                    appState.bootstrap(modelContext: sharedModelContainer.mainContext)
                    SharedBookmarkImportManager.importPendingBookmark(modelContext: sharedModelContainer.mainContext)
                    SharedFolderExportManager.exportFolders(modelContext: sharedModelContainer.mainContext)

                    setupNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: .lystariaNotificationAction)) { notification in
                    handleNotificationAction(notification)
                }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.refreshAuthorizationStatus()
                    SharedBookmarkImportManager.importPendingBookmark(modelContext: sharedModelContainer.mainContext)
                    SharedFolderExportManager.exportFolders(modelContext: sharedModelContainer.mainContext)

                    Task {
                        do {
                            try await AuthService.shared.validateStoredAppleSession()
                        } catch {
                            await MainActor.run {
                                appState.signOut()
                            }
                        }
                    }
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
    }

    // ─────────────────────────────────────────────
    // MARK: - Setup
    // ─────────────────────────────────────────────

    private func setupNotifications() {
        notificationManager.setup()
        notificationManager.modelContainer = sharedModelContainer

        Task {
            let granted = await notificationManager.requestPermission()
            print("🔔 Notification permission: \(granted ? "granted" : "denied")")

            if granted {
                notificationManager.rescheduleAll(from: sharedModelContainer)
            }
        }

        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            notificationManager.printPendingNotifications()
        }
        #endif
    }

    // ─────────────────────────────────────────────
    // MARK: - Handle Notification Actions
    // ─────────────────────────────────────────────

    private func handleNotificationAction(_ notification: Foundation.Notification) {
        guard let info = notification.userInfo,
              let actionID = info["actionID"] as? String,
              let originalUserInfo = info["userInfo"] as? [String: Any],
              let idHashString = originalUserInfo["reminderIDHash"] as? String
        else { return }

        let context = sharedModelContainer.mainContext

        let descriptor = FetchDescriptor<LystariaReminder>(
            predicate: #Predicate<LystariaReminder> { $0.statusRaw == "scheduled" }
        )

        guard let reminders = try? context.fetch(descriptor) else { return }
        guard let reminder = reminders.first(where: {
            $0.persistentModelID.hashValue.description == idHashString
        }) else {
            print("⚠️ Could not find reminder for hash: \(idHashString)")
            return
        }

        let message = [reminder.title, reminder.details].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: ": ")

        switch actionID {
        case NotificationManager.doneActionID:
            reminder.acknowledgedAt = Date()
            if !reminder.isRecurring {
                reminder.status = .sent
                notificationManager.cancelReminder(reminder)
            }
            reminder.updatedAt = Date()
            print("✅ Marked done: \(message.prefix(30))")

        case NotificationManager.snoozeActionID:
            notificationManager.snoozeReminder(reminder, minutes: 10)
            print("💤 Snoozed: \(message.prefix(30))")

        default:
            print("📱 Notification tapped: \(message.prefix(30))")
        }
    }
}
