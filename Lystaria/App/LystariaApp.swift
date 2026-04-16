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
        print("🔔🚀 AppDelegate didFinishLaunching — setting UNUserNotificationCenter delegate")
        UNUserNotificationCenter.current().delegate = NotificationManager.shared

        // Wipe any stale health widget values that were written before the
        // app group entitlement was fixed. A one-time migration flag prevents
        // this from running on every launch.
        let migrationKey = "healthWidget.staleDataCleared.v2"
        let appGroupID = "group.com.asteriasmoons.LystariaDev"
        if let suite = UserDefaults(suiteName: appGroupID),
           !suite.bool(forKey: migrationKey) {
            suite.removeObject(forKey: "healthWidget.stepsToday")
            suite.removeObject(forKey: "healthWidget.stepGoal")
            suite.removeObject(forKey: "healthWidget.waterToday")
            suite.removeObject(forKey: "healthWidget.waterGoal")
            suite.set(true, forKey: migrationKey)
            suite.synchronize()
            print("🧹 HealthWidget: cleared stale UserDefaults values")
        }

        return true
    }
}

@main
struct LystariaApp: App {

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AuthUser.self,
            Note.self,
            NotesTab.self,
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
            ReadingPointsEntry.self,
            BookmarkFolder.self,
            BookmarkItem.self,
            JournalEntry.self,
            JournalInlineStyle.self,
            JournalBlock.self,
            JournalBook.self,
            JournalPrompt.self,
            JournalPromptUsage.self,
            JournalStats.self,
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

                    // Re-fetch health data on launch to keep widget current.
                    Task {
                        await HealthKitManager.shared.fetchTodaySteps()
                        await WaterHealthKitManager.shared.fetchTodayWater()
                        HealthWidgetSync.sync(
                            stepsToday: HealthKitManager.shared.todaySteps,
                            stepGoal: HealthKitManager.shared.stepGoalForSync,
                            waterToday: WaterHealthKitManager.shared.todayWaterFlOz,
                            waterGoal: WaterHealthKitManager.shared.waterGoalForSync
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .lystariaNotificationAction)) { notification in
                    handleNotificationAction(notification)
                }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.refreshAuthorizationStatus()
                    SharedBookmarkImportManager.importPendingBookmark(modelContext: sharedModelContainer.mainContext)
                    SharedFolderExportManager.exportFolders(modelContext: sharedModelContainer.mainContext)
                    processRefills(modelContext: sharedModelContainer.mainContext)

                    // Re-fetch health data and push to widget whenever the app foregrounding.
                    Task {
                        await HealthKitManager.shared.fetchTodaySteps()
                        await WaterHealthKitManager.shared.fetchTodayWater()
                        HealthWidgetSync.sync(
                            stepsToday: HealthKitManager.shared.todaySteps,
                            stepGoal: HealthKitManager.shared.stepGoalForSync,
                            waterToday: WaterHealthKitManager.shared.todayWaterFlOz,
                            waterGoal: WaterHealthKitManager.shared.waterGoalForSync
                        )
                    }

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
    // MARK: - Refill Processor
    // ─────────────────────────────────────────────

    /// Runs on launch and foreground. For each medication that has a refill date
    /// that has passed today, sets currentAmount to supplyAmount and advances
    /// refillDate by daysSupply days (if daysSupply > 0). Guarded by a day key
    /// so it never double-processes within the same calendar day.
    private func processRefills(modelContext: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayKey = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: today)
        }()

        let descriptor = FetchDescriptor<Medication>()
        guard let medications = try? modelContext.fetch(descriptor) else { return }

        for medication in medications {
            guard medication.isActive,
                  let refillDate = medication.refillDate,
                  cal.startOfDay(for: refillDate) <= today,
                  medication.lastAutoRefillDayKey != todayKey
            else { continue }

            let previousAmount = medication.currentAmount
            medication.currentAmount = max(0, medication.supplyAmount)
            medication.lastAutoRefillDayKey = todayKey
            medication.updatedAt = Date()

            if medication.daysSupply > 0 {
                medication.refillDate = cal.date(
                    byAdding: .day,
                    value: medication.daysSupply,
                    to: cal.startOfDay(for: refillDate)
                )
            }

            let historyEntry = MedicationHistoryEntry(
                type: .refilled,
                amountText: "\(previousAmount) \u{2192} \(medication.currentAmount)",
                details: medication.daysSupply > 0
                    ? "Auto-refilled on refill date. Next refill in \(medication.daysSupply) days."
                    : "Auto-refilled on refill date.",
                createdAt: Date(),
                medication: medication
            )
            modelContext.insert(historyEntry)
        }

        try? modelContext.save()
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
