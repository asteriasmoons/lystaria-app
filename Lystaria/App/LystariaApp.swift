// LystariaApp.swift
// Lystaria

import SwiftUI
import SwiftData

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set the notification delegate as early as possible — before SwiftUI
        // initialises any views — so didReceive fires correctly on cold-launch
        // taps where the app is woken by a notification.
        print("🔔🚀 AppDelegate didFinishLaunching — setting UNUserNotificationCenter delegate")
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }
}

@main
struct LystariaApp: App {

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AuthUser.self,
            DistractionBubble.self,
            CalendarEvent.self,
            Habit.self,
            HabitSkip.self,
            HabitLog.self,
            MoodLog.self,
            MoodStreak.self,
            BodyStateRecord.self,
            HealthMetricEntry.self,
            Medication.self,
            SymptomLog.self,
            ExerciseLogEntry.self,
            WaterBottlePlanEntry.self,
            DailyCompletionSettings.self,
            Book.self,
            BookSeries.self,
            BookNote.self,
            ReadingStats.self,
            ReadingSession.self,
            ReadingGoal.self,
            DailyReadingProgress.self,
            WeeklyReadingSnapshot.self,
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
            SelfCarePointsResetLog.self,
            SelfCarePointsProfile.self,
            Checklist.self,
            ChecklistItem.self,
            KanbanBoard.self,
            KanbanColumn.self,
            DailyIntention.self,
            DailyTarotRecord.self,
            DailyLenormandRecord.self,
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
                        // Silently validate on foreground — do NOT sign out on failure.
                        // A network blip or token timing issue should never log the user out.
                        try? await AuthService.shared.validateStoredAppleSession()
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
        // Set container BEFORE setup() so the initial calendar reschedule inside
        // setup() actually has a container to work with.
        notificationManager.modelContainer = sharedModelContainer
        notificationManager.setup()

        Task {
            // Check current status first — avoid prompting again if already decided.
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                // Already granted — reschedule immediately, no prompt needed.
                notificationManager.rescheduleAll(from: sharedModelContainer)
                print("🔔 Notifications already authorized — rescheduled")

            case .notDetermined:
                // First time — ask, then reschedule if granted.
                let granted = await notificationManager.requestPermission()
                print("🔔 Notification permission: \(granted ? "granted" : "denied")")
                if granted {
                    notificationManager.rescheduleAll(from: sharedModelContainer)
                }

            default:
                print("🔔 Notifications not authorized (status=\(settings.authorizationStatus.rawValue))")
            }
        }

        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            notificationManager.printAllPendingLystariaNotifications()
        }
        #endif
    }

    // ─────────────────────────────────────────────
    // MARK: - Handle Notification Actions
    // ─────────────────────────────────────────────

    private func handleNotificationAction(_ notification: Foundation.Notification) {
        guard let info = notification.userInfo,
              let actionID = info["actionID"] as? String,
              let originalUserInfo = info["userInfo"] as? [String: Any]
        else { return }

        let reminderID = originalUserInfo["reminderID"] as? String

        guard let reminderID else {
            print("⚠️ handleNotificationAction: no reminderID in userInfo")
            return
        }

        let context = sharedModelContainer.mainContext

        // Fetch all non-deleted reminders and match on stable persistent model ID string.
        let descriptor = FetchDescriptor<LystariaReminder>()
        guard let reminders = try? context.fetch(descriptor) else { return }
        guard let reminder = reminders.first(where: {
            String(describing: $0.persistentModelID) == reminderID
        }) else {
            print("⚠️ Could not find reminder for id: \(reminderID)")
            return
        }

        let message = [reminder.title, reminder.details]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ": ")

        switch actionID {
        case NotificationManager.doneActionID:
            reminder.acknowledgedAt = Date()
            if !reminder.isRecurring {
                reminder.status = .sent
                notificationManager.cancelReminder(reminder)
            } else {
                // Advance to next occurrence so it reschedules correctly.
                let next = ReminderCompute.nextRun(after: Date().addingTimeInterval(91), reminder: reminder)
                reminder.nextRunAt = next
                reminder.acknowledgedAt = nil
                notificationManager.cancelReminder(reminder)
                notificationManager.scheduleReminder(reminder)
            }
            reminder.updatedAt = Date()
            print("✅ Marked done: \(message.prefix(30))")

        case NotificationManager.snoozeActionID:
            notificationManager.snoozeReminder(reminder, minutes: 10)
            print("💤 Snoozed: \(message.prefix(30))")

        default:
            break
        }
    }
}
