// LystariaApp.swift
// Lystaria

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import Supabase
import Auth

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()
    }
}
#endif

@main
struct LystariaApp: App {

#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AuthUser.self,
            Book.self,
            CalendarEvent.self,
            Habit.self,
            HabitLog.self,
            MoodLog.self,
            JournalEntry.self,
            LystariaReminder.self,
            UserSettings.self,
            Checklist.self,
            ChecklistItem.self,
        ])

        // allowsSave + no migrationPlan = SwiftData handles lightweight
        // migrations (new optional columns) automatically without wiping data.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(notificationManager)
                .onAppear {
                    WatchSessionManager.shared.activate()

                    Task {
                        await SupabaseSessionBridge.syncSessionToWatch()
                    }

                    setupNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: .lystariaNotificationAction)) { notification in
                    handleNotificationAction(notification)
                }
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.refreshAuthorizationStatus()
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
            reminder.needsSync = true
            print("✅ Marked done: \(message.prefix(30))")

        case NotificationManager.snoozeActionID:
            notificationManager.snoozeReminder(reminder, minutes: 10)
            print("💤 Snoozed: \(message.prefix(30))")

        default:
            print("📱 Notification tapped: \(message.prefix(30))")
        }
    }

    private func restorePreviousGoogleSignInIfPossible() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    print("⚠️ Failed to restore Google sign-in: \(error.localizedDescription)")
                    return
                }
                guard let user = user else {
                    print("ℹ️ No previous Google sign-in found.")
                    return
                }

                Task { @MainActor in
                    let context = sharedModelContainer.mainContext

                    let email = user.profile?.email
                    let name = user.profile?.name
                    let googleId = user.userID

                    let descriptor = FetchDescriptor<AuthUser>()
                    let existing = try? context.fetch(descriptor).first { candidate in
                        let matchesGoogle = (googleId != nil) && (candidate.googleUserId == googleId)
                        let matchesEmail = (email != nil) && (candidate.email == email)
                        return matchesGoogle || matchesEmail
                    }

                    if let existing {
                        existing.email = email
                        existing.displayName = name
                        existing.googleUserId = googleId
                        existing.authProvider = .google
                    } else {
                        let newUser = AuthUser(
                            email: email,
                            displayName: name,
                            authProvider: .google,
                            appleUserId: nil,
                            googleUserId: googleId,
                            serverId: nil
                        )
                        context.insert(newUser)
                    }

                    print("✅ Restored Google sign-in:", email ?? "(no email)")
                }
            }
        } else {
            print("ℹ️ No previous Google sign-in to restore.")
        }
    }
}
