// NotificationManager.swift
// Lystaria
//
// Handles all local notification scheduling for reminders.
//
// HOW IT WORKS:
// ─────────────
// 1. When a reminder is created/edited, call `scheduleReminder(_:)`.
//    This creates one or more UNNotificationRequest objects and adds them
//    to UNUserNotificationCenter.
//
// 2. Each notification uses the reminder's persistentModelID as the base
//    identifier, so we can cancel/replace them later.
//
// 3. For recurring reminders (daily/weekly/monthly/yearly), we use
//    UNCalendarNotificationTrigger with `repeats: true`.
//    For interval reminders, we use UNTimeIntervalNotificationTrigger.
//    For one-time reminders, we use UNCalendarNotificationTrigger with
//    `repeats: false`.
//
// 4. When a reminder is deleted/paused/completed, call `cancelReminder(_:)`.
//
// 5. When the user taps a notification, the app receives the notification
//    response via UNUserNotificationCenterDelegate. We handle snooze and
//    done actions from the notification itself.
//
// NOTIFICATION IDENTIFIERS:
// ─────────────────────────
// Base ID = "lystaria.reminder.<persistentModelID-string>"
// For reminders with multiple times (timesOfDay), we append the index:
//   "lystaria.reminder.<id>.0", "lystaria.reminder.<id>.1", etc.
// For weekly reminders with multiple days, we append the day:
//   "lystaria.reminder.<id>.day0", "lystaria.reminder.<id>.day3", etc.
//
// NOTIFICATION CATEGORIES & ACTIONS:
// ──────────────────────────────────
// Category: "REMINDER"
// Actions:
//   - "DONE"   → marks the reminder as acknowledged
//   - "SNOOZE" → reschedules for 10 minutes later

import Foundation
import SwiftData
import Combine

#if os(iOS)
import UIKit
#endif

@preconcurrency import UserNotifications
#if os(macOS)
import AppKit
#endif

// MARK: - NotificationManager

@MainActor
final class NotificationManager: NSObject, Combine.ObservableObject {
    
    static let shared = NotificationManager()

    override init() {
        super.init()
        #if os(iOS)
        // Ensure foreground notifications are shown even if setup() hasn't been called yet
        UNUserNotificationCenter.current().delegate = self
        #endif
    }
    
    /// The category identifier for reminder notifications
    static let reminderCategoryID = "REMINDER"
    
    /// Action identifiers
    static let doneActionID = "DONE"
    static let snoozeActionID = "SNOOZE"
    
    /// Whether we have notification permission
    @Combine.Published var isAuthorized = false
    
    /// Reference to the model container (set from LystariaApp on launch)
    var modelContainer: ModelContainer?
    
    /// Effective timezone identifier loaded from UserSettings (SwiftData)
    /// Defaults to device timezone if settings not available.
    @Combine.Published var effectiveTimezoneID: String = TimeZone.current.identifier

    /// Prevents rapid duplicate reschedules (setup + foreground + saves)
    private var isReschedulingCalendar = false
    private var lastCalendarRescheduleAt: Date?
    private var isReschedulingReminders = false
    private var lastReminderRescheduleAt: Date?
    private var hasCompletedSetup = false

    /// Updates the effective timezone from a given ModelContainer by fetching UserSettings.
    func refreshEffectiveTimezone(from container: ModelContainer?) {
        let defaults = UserDefaults.standard
        let useSystem = defaults.object(forKey: "lystaria.useSystemTimezone") as? Bool ?? true
        let chosen = defaults.string(forKey: "lystaria.timezoneIdentifier") ?? TimeZone.current.identifier
        effectiveTimezoneID = useSystem ? TimeZone.current.identifier : chosen
    }

    /// Convenience: Calendar configured with the effective timezone
    var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: effectiveTimezoneID) ?? .current
        return cal
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Setup
    // ─────────────────────────────────────────────
    
    /// Call this once at app launch. It:
    /// 1. Registers notification categories (Done / Snooze actions)
    /// 2. Requests permission if not yet granted
    /// 3. Sets this object as the UNUserNotificationCenter delegate
    func setup() {
        guard !hasCompletedSetup else {
            return
        }
        hasCompletedSetup = true

        let center = UNUserNotificationCenter.current()
        
        // Register actions
        let doneAction = UNNotificationAction(
            identifier: Self.doneActionID,
            title: "Done ✓",
            options: [.destructive]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 10min",
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: Self.reminderCategoryID,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([reminderCategory])
        
        // Set delegate
        center.delegate = self
        
        // Check current authorization
        refreshAuthorizationStatus()

        // Load effective timezone from settings if container is already set
        refreshEffectiveTimezone(from: modelContainer)

        // Observe app foreground to refresh scheduling windows
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                self.refreshEffectiveTimezone(from: container)
                self.rescheduleAllCalendarEvents(from: container)
            }
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                self.refreshAuthorizationStatus()
                self.refreshEffectiveTimezone(from: container)
                self.rescheduleAllCalendarEvents(from: container)
            }
        }
        #endif

        // Initial reschedule if the container is already available.
        // Do NOT reschedule reminders here on launch, because recurring reminder
        // recomputation can block startup. Calendar events are still safe to refresh.
        if let container = modelContainer {
            rescheduleAllCalendarEvents(from: container)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Schedule a Reminder
    // ─────────────────────────────────────────────

    /// Convenience: only request permission if we're not already authorized.
    /// Safe to call from the main actor.
    func requestPermissionIfNeeded() {
        // If we already know we're authorized, nothing to do.
        if isAuthorized { return }
        // Refresh settings first, then request if still not authorized.
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            if settings.authorizationStatus == .authorized {
                Task { @MainActor in self.isAuthorized = true }
                return
            }
            Task { [weak self] in
                let granted = await self?.requestPermission() ?? false
                if !granted {
                    print("⚠️ Notifications permission not granted.")
                }
            }
        }
    }
    
    /// Request notification permission from the user.
    /// Call this when the user first creates a reminder, or from settings.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    /// Refresh the current authorization status (call on app foreground)
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Schedule a Reminder
    // ─────────────────────────────────────────────
    
    /// Schedules local notifications for a reminder.
    /// Cancels any existing notifications for this reminder first,
    /// then creates new ones based on the schedule type.
    ///
    /// - Parameter reminder: The LystariaReminder to schedule.
    func scheduleReminder(_ reminder: LystariaReminder) {
        // 1. Cancel existing notifications for this reminder
        cancelReminder(reminder)
        
        // 2. Don't schedule if not active
        guard reminder.status == .scheduled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.badge = nil  // iOS manages badge count
        
        // Stable identifier used by notification action handling.
        let idString = String(describing: reminder.persistentModelID)
        // Keep BOTH keys for one release cycle so old action handlers still work.
        content.userInfo = [
            "reminderID": idString,
            "reminderIDHash": reminder.persistentModelID.hashValue.description
        ]
        
        let baseID = notificationBaseID(for: reminder)
        let schedule = reminder.schedule ?? .once

        print("[NotificationManager] Rescheduling id=\(baseID) status=\(reminder.statusRaw) kind=\(schedule.kind.rawValue)")
        print("[NotificationManager] timezone=\(effectiveTimezoneID) nextRunAt=\(reminder.nextRunAt)")

        switch schedule.kind {
        case .once:
            scheduleOnce(reminder: reminder, content: content, baseID: baseID)

        case .daily, .weekly, .monthly, .yearly, .interval:
            scheduleNextRecurringReminder(reminder: reminder, schedule: schedule, content: content, baseID: baseID)
        }
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Cancel a Reminder
    // ─────────────────────────────────────────────
    
    /// Removes all pending notifications for a given reminder.
    func cancelReminder(_ reminder: LystariaReminder) {
        let baseID = notificationBaseID(for: reminder)
        let center = UNUserNotificationCenter.current()
        
        // Synchronously get all pending notifications and remove ALL that
        // start with our base ID — this covers .today, .bootstrap, .snooze,
        // .day0, etc. We also check for legacy hash-based IDs.
        let legacyBaseID = "lystaria.reminder.\(reminder.persistentModelID.hashValue)"
        
        center.getPendingNotificationRequests { requests in
            let matchingIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(baseID) || $0.hasPrefix(legacyBaseID) }
            
            if !matchingIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: matchingIDs)
                print("🔕 Cancelled \(matchingIDs.count) notification(s) for: \(baseID)")
            }
        }
    }
    
    /// Cancels ALL Lystaria reminder notifications.
    /// Useful for a "clear all" or logout scenario.
    func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let lystariaIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("lystaria.reminder.") }
            center.removePendingNotificationRequests(withIdentifiers: lystariaIDs)
            print("🔕 Cancelled all \(lystariaIDs.count) Lystaria notifications")
        }
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Reschedule All
    // ─────────────────────────────────────────────
    
    /// Reschedules notifications for ALL active reminders.
    /// Call this on app launch and after syncing with the server.
    func rescheduleAll(from container: ModelContainer) {
        refreshEffectiveTimezone(from: container)

        if isReschedulingReminders {
            print("⏭ Skipping reminder reschedule (already running)")
            return
        }
        if let last = lastReminderRescheduleAt, Date().timeIntervalSince(last) < 2 {
            print("⏭ Skipping reminder reschedule (debounced)")
            return
        }

        isReschedulingReminders = true
        lastReminderRescheduleAt = Date()

        Task { @MainActor in
            defer { self.isReschedulingReminders = false }

            let context = container.mainContext
            let descriptor = FetchDescriptor<LystariaReminder>(
                predicate: #Predicate<LystariaReminder> { $0.statusRaw == "scheduled" }
            )

            do {
                let reminders = try context.fetch(descriptor)

                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let orphanIDs = pending
                    .map(\.identifier)
                    .filter { $0.hasPrefix("lystaria.reminder.") }

                if !orphanIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: orphanIDs)
                    print("🧹 Purged \(orphanIDs.count) old reminder notification(s)")
                }

                print("📅 Rescheduling \(reminders.count) active reminders")
                for reminder in reminders {
                    scheduleReminder(reminder)
                }
            } catch {
                print("❌ Failed to fetch reminders for rescheduling: \(error)")
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Reschedule All Calendar Events
    // ─────────────────────────────────────────────

    /// Reschedules notifications for ALL recurring calendar events within the rolling window.
    /// Call on app launch and when app returns to foreground.
    func rescheduleAllCalendarEvents(from container: ModelContainer) {
        Task { @MainActor in
            self.refreshEffectiveTimezone(from: container)
            // Debounce + lock: this can be called multiple times on launch/foreground.
            if isReschedulingCalendar {
                print("⏭ Skipping calendar reschedule (already running)")
                return
            }
            if let last = lastCalendarRescheduleAt, Date().timeIntervalSince(last) < 2 {
                print("⏭ Skipping calendar reschedule (debounced)")
                return
            }
            isReschedulingCalendar = true
            lastCalendarRescheduleAt = Date()
            defer { isReschedulingCalendar = false }

            let context = container.mainContext
            let descriptor = FetchDescriptor<CalendarEvent>()
            do {
                let allEvents = try context.fetch(descriptor)

                // ── STEP 0: Purge any legacy calendar notifications ──
                // Old versions scheduled many future occurrences. Since we now only
                // schedule the next occurrence, we remove all existing calendar
                // notifications first so stale ones do not linger.
                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let oldCalendarIDs = pending
                    .map(\.identifier)
                    .filter { $0.hasPrefix("lystaria.calendar.") }

                if !oldCalendarIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: oldCalendarIDs)
                    print("🧹 Purged \(oldCalendarIDs.count) legacy calendar pending notification(s)")
                }

                // Also purge delivered calendar notifications so old ones don't linger in Notification Center
                let delivered = await center.deliveredNotifications()
                let deliveredIDs = delivered
                    .map { $0.request.identifier }
                    .filter { $0.hasPrefix("lystaria.calendar.") }
                if !deliveredIDs.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
                    print("🧹 Purged \(deliveredIDs.count) legacy calendar delivered notification(s)")
                }

                // Extract only events that actually have a recurrence rule
                let recurringEvents: [(CalendarEvent, RecurrenceRule)] = allEvents.compactMap { event in
                    guard let rule = event.recurrence else { return nil }
                    return (event, rule)
                }

                print("📅 Rescheduling calendar events: \(recurringEvents.count) recurring")

                for (event, rule) in recurringEvents {
                    let id = event.reminderServerId ?? UUID().uuidString
                    if event.reminderServerId == nil {
                        event.reminderServerId = id
                        event.updatedAt = Date()
                        event.needsSync = true
                    }
                    let body = event.allDay ? "All-day event" : (event.location?.isEmpty == false ? "Event: \(event.title) • \(event.location!)" : "Event: \(event.title)")
                    self.scheduleRecurringCalendarEvent(
                        id: id,
                        title: event.title,
                        body: body,
                        startDate: event.startDate,
                        allDay: event.allDay,
                        recurrence: rule,
                        exceptions: event.recurrenceExceptions
                    )
                }
            } catch {
                print("❌ Failed to fetch calendar events for rescheduling: \(error)")
            }
        }
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Snooze
    // ─────────────────────────────────────────────
    
    /// Schedules a one-shot notification X minutes from now.
    /// Used when the user taps "Snooze" on a notification.
    func snoozeReminder(_ reminder: LystariaReminder, minutes: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID

        // Stable identifier used by notification action handling.
        let idString = String(describing: reminder.persistentModelID)
        // Keep BOTH keys for one release cycle so old action handlers still work.
        content.userInfo = [
            "reminderID": idString,
            "reminderIDHash": reminder.persistentModelID.hashValue.description
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let snoozeID = "\(notificationBaseID(for: reminder)).snooze.\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)

        let previewForLog = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Snooze scheduling error: \(error)")
            } else {
                print("💤 Snoozed for \(minutes) min: \(previewForLog)")
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Calendar Events: Recurring (One-shot series)
    // ─────────────────────────────────────────────

    /// Cancel the pending/delivered notification(s) for a calendar event id.
    ///
    /// IMPORTANT: We now schedule only ONE notification per recurring event: `.0`
    /// and single one-shot events use the base id.
    /// Cancelling exact identifiers prevents race conditions that can create duplicates
    /// when rescheduling is called rapidly.
    func cancelAllCalendarNotifications(id: String) {
        let center = UNUserNotificationCenter.current()
        let idsToRemove = [
            "lystaria.calendar." + id,       // one-shot
            "lystaria.calendar." + id + ".0" // recurring next occurrence
        ]
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
    }

    /// Schedule recurring calendar event occurrences as a series of one-shot notifications.
    /// - Parameters:
    ///   - id: Stable id for the event (e.g., reminderServerId)
    ///   - title: Event title
    ///   - body: Body text (e.g., location/details)
    ///   - startDate: Event start date (used as anchor for time-of-day)
    ///   - allDay: If true, fires at 9:00 AM local time
    ///   - recurrence: Recurrence rule describing the pattern
    ///   - exceptions: ISO date keys (YYYY-MM-DD) to skip
    func scheduleRecurringCalendarEvent(
        id: String,
        title: String,
        body: String,
        startDate: Date,
        allDay: Bool,
        recurrence: RecurrenceRule,
        exceptions: [String]
    ) {
        // Cancel any existing scheduled occurrences for this event
        cancelAllCalendarNotifications(id: id)

        // We only schedule a rolling window for "never" and "until".
        // For "count", we generate exactly the first N occurrences from the series start,
        // then schedule only the upcoming ones.
        let now = Date()

        // Default rolling window for infinite recurrences
        let rollingWindowDays = 60

        // Compute a reasonable horizon (upper bound) to prevent long loops
        let fiveYearsOut = tzCalendar.date(byAdding: .year, value: 5, to: now) ?? now
        let horizonByRolling = tzCalendar.date(byAdding: .day, value: rollingWindowDays, to: now) ?? now

        let exceptionSet = Set(exceptions)

        // Compute occurrences depending on end condition
        let occurrences: [Date]
        if let end = recurrence.end, end.kind == .count {
            // Generate from START for COUNT semantics (robust + correct)
            let c = max(0, end.count ?? 0)
            occurrences = computeOccurrencesForCount(
                startDate: startDate,
                allDay: allDay,
                rule: recurrence,
                exceptions: exceptionSet,
                count: c,
                untilHorizon: fiveYearsOut
            )
        } else {
            // Rolling window generation (fast even if startDate is far in the past)
            let horizon: Date
            if let end = recurrence.end, end.kind == .until {
                // Clamp to until date (or rolling horizon if missing), but never beyond 5y
                let untilDate = end.until ?? horizonByRolling
                horizon = min(untilDate, fiveYearsOut)
            } else {
                horizon = horizonByRolling
            }

            occurrences = computeOccurrencesRolling(
                startDate: startDate,
                allDay: allDay,
                rule: recurrence,
                exceptions: exceptionSet,
                from: now,
                untilHorizon: horizon
            )
        }

        // Only schedule the NEXT future occurrence.
        // This keeps recurring calendar events at one pending notification each,
        // which avoids hitting iOS's pending notification cap.
        let upcoming = occurrences.filter { $0 >= now }.sorted()

        guard let fireDate = upcoming.first else {
            print("⚠️ No upcoming calendar occurrences to schedule for id=\(id)")
            return
        }

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = [
            "calendarEventID": id,
            "kind": "calendar"
        ]

        var comps = tzCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar = tzCalendar
        comps.timeZone = tzCalendar.timeZone
        comps.second = comps.second ?? 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = "lystaria.calendar." + id + ".0"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("❌ Calendar recurring scheduling error: \(error)")
            } else {
                print("🔔 Scheduled next calendar occurrence for id=\(id) at \(fireDate)")
            }
        }
    }

    /// Schedule a single one-shot calendar event notification at an exact date.
    func scheduleCalendarEvent(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        // Cancel any existing pending notifications for this calendar event id
        cancelAllCalendarNotifications(id: id)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = [
            "calendarEventID": id,
            "kind": "calendar"
        ]

        var comps = tzCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar = tzCalendar
        comps.timeZone = tzCalendar.timeZone
        comps.second = comps.second ?? 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = "lystaria.calendar." + id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ Calendar single scheduling error: \(error)") }
        }
    }

    /// Reschedule all calendar events convenience that calls reminders reschedule too.
    func rescheduleAllCalendarEventsIfPossible() {
        if let container = modelContainer {
            rescheduleAllCalendarEvents(from: container)
        }
    }

    /// Compute upcoming occurrence dates for a rolling window.
    /// This is optimized to start near `from` to avoid long loops when `startDate` is far in the past.
    private func computeOccurrencesRolling(
        startDate: Date,
        allDay: Bool,
        rule: RecurrenceRule,
        exceptions: Set<String>,
        from: Date,
        untilHorizon: Date
    ) -> [Date] {
        var results: [Date] = []
        let cal = tzCalendar

        let (baseHour, baseMinute) = baseTimeOfDay(cal: cal, startDate: startDate, allDay: allDay)

        func appendIfValid(_ fire: Date) {
            if fire < from { return }
            if fire > untilHorizon { return }
            if isExceptionDate(fire, cal: cal, exceptions: exceptions) { return }
            results.append(fire)
        }

        // Start cursor near `from`, but not before the series start.
        var cursor = max(startDate, from)

        switch rule.freq {
        case .daily:
            while cursor <= untilHorizon {
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: cursor) ?? cursor
                appendIfValid(fire)
                cursor = cal.date(byAdding: .day, value: rule.interval, to: cursor) ?? cursor
            }

        case .weekly:
            let weekdays = (rule.byWeekday?.sorted() ?? [cal.component(.weekday, from: startDate) - 1])
            while cursor <= untilHorizon {
                guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: cursor) else {
                    break
                }
                let weekStart = weekInterval.start

                for wd in weekdays {
                    // Normalize weekday index: RRULE may use 1–7 (Sun=1) but our math expects 0–6
                    let normalizedWD = (1...7).contains(wd) ? wd - 1 : wd
                    if let day = cal.date(byAdding: .day, value: normalizedWD, to: weekStart) {
                        let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                        appendIfValid(fire)
                    }
                }

                cursor = cal.date(byAdding: .weekOfYear, value: rule.interval, to: cursor) ?? cursor
            }
            results.sort()

        case .monthly:
            let startDay = cal.component(.day, from: startDate)
            while cursor <= untilHorizon {
                var comps = cal.dateComponents([.year, .month], from: cursor)
                if let monthDate = cal.date(from: comps),
                   let range = cal.range(of: .day, in: .month, for: monthDate) {
                    comps.day = min(startDay, range.count)
                } else {
                    comps.day = startDay
                }
                let day = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                appendIfValid(fire)
                cursor = cal.date(byAdding: .month, value: rule.interval, to: cursor) ?? cursor
            }

        case .yearly:
            let startMonth = cal.component(.month, from: startDate)
            let startDay = cal.component(.day, from: startDate)
            while cursor <= untilHorizon {
                var comps = cal.dateComponents([.year], from: cursor)
                comps.month = startMonth
                comps.day = startDay
                let day = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                appendIfValid(fire)
                cursor = cal.date(byAdding: .year, value: rule.interval, to: cursor) ?? cursor
            }
        }

        return results
    }

    /// Compute occurrence dates honoring COUNT semantics.
    /// Generates the first `count` occurrences from the series start, then the caller can filter upcoming.
    /// This avoids the "COUNT becomes empty" bug when generating only from `now`.
    private func computeOccurrencesForCount(
        startDate: Date,
        allDay: Bool,
        rule: RecurrenceRule,
        exceptions: Set<String>,
        count: Int,
        untilHorizon: Date
    ) -> [Date] {
        guard count > 0 else { return [] }

        var results: [Date] = []
        let cal = tzCalendar

        let (baseHour, baseMinute) = baseTimeOfDay(cal: cal, startDate: startDate, allDay: allDay)

        func appendIfValid(_ fire: Date) {
            if fire > untilHorizon { return }
            if isExceptionDate(fire, cal: cal, exceptions: exceptions) { return }
            results.append(fire)
        }

        // Safety cap to prevent freezing if something unexpected happens.
        // (Should never be hit in normal use.)
        let maxIterations = max(5000, count * 10)
        var iterations = 0

        var cursor = startDate

        switch rule.freq {
        case .daily:
            while results.count < count && cursor <= untilHorizon && iterations < maxIterations {
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: cursor) ?? cursor
                appendIfValid(fire)
                cursor = cal.date(byAdding: .day, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }

        case .weekly:
            let weekdays = (rule.byWeekday?.sorted() ?? [cal.component(.weekday, from: startDate) - 1])
            while results.count < count && cursor <= untilHorizon && iterations < maxIterations {
                guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: cursor) else {
                    break
                }
                let weekStart = weekInterval.start

                for wd in weekdays {
                    // Normalize weekday index: RRULE may use 1–7 (Sun=1) but our math expects 0–6
                    let normalizedWD = (1...7).contains(wd) ? wd - 1 : wd
                    if results.count >= count { break }
                    if let day = cal.date(byAdding: .day, value: normalizedWD, to: weekStart) {
                        let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                        // Only count occurrences on/after the series start
                        if fire >= startDate {
                            appendIfValid(fire)
                        }
                    }
                }

                cursor = cal.date(byAdding: .weekOfYear, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }
            results.sort()
            if results.count > count { results = Array(results.prefix(count)) }

        case .monthly:
            let startDay = cal.component(.day, from: startDate)
            while results.count < count && cursor <= untilHorizon && iterations < maxIterations {
                var comps = cal.dateComponents([.year, .month], from: cursor)
                if let monthDate = cal.date(from: comps),
                   let range = cal.range(of: .day, in: .month, for: monthDate) {
                    comps.day = min(startDay, range.count)
                } else {
                    comps.day = startDay
                }
                let day = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                if fire >= startDate {
                    appendIfValid(fire)
                }
                cursor = cal.date(byAdding: .month, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }

        case .yearly:
            let startMonth = cal.component(.month, from: startDate)
            let startDay = cal.component(.day, from: startDate)
            while results.count < count && cursor <= untilHorizon && iterations < maxIterations {
                var comps = cal.dateComponents([.year], from: cursor)
                comps.month = startMonth
                comps.day = startDay
                let day = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                if fire >= startDate {
                    appendIfValid(fire)
                }
                cursor = cal.date(byAdding: .year, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }
        }

        if iterations >= maxIterations {
            print("⚠️ computeOccurrencesForCount hit safety cap; results=\(results.count) count=\(count)")
        }

        return results
    }

    private func baseTimeOfDay(cal: Calendar, startDate: Date, allDay: Bool) -> (Int, Int) {
        let baseComponents = cal.dateComponents([.hour, .minute], from: startDate)
        let baseHour = allDay ? 9 : (baseComponents.hour ?? 9)
        let baseMinute = allDay ? 0 : (baseComponents.minute ?? 0)
        return (baseHour, baseMinute)
    }

    private func isExceptionDate(_ date: Date, cal: Calendar, exceptions: Set<String>) -> Bool {
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let key = String(format: "%04d-%02d-%02d", y, m, d)
        return exceptions.contains(key)
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Private: Schedule by Type
    // ═══════════════════════════════════════════════

    /// Schedule ONLY the next occurrence for any recurring reminder.
    /// This keeps habits/reminders aligned with the same next-occurrence-only
    /// strategy as recurring calendar events.
    private func scheduleNextRecurringReminder(
        reminder: LystariaReminder,
        schedule: ReminderSchedule,
        content: UNMutableNotificationContent,
        baseID: String
    ) {
        let now = Date()

        // Compute the next valid fire date from the reminder model.
        let fireDate = ReminderCompute.nextRun(after: now, reminder: reminder)

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: reminder.timezone) ?? .current

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar = cal
        comps.timeZone = cal.timeZone
        comps.second = comps.second ?? 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: baseID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error {
                print("❌ scheduleNextRecurringReminder error: \(error)")
            } else {
                print("🔔 Scheduled next recurring reminder: \(baseID) at \(fireDate) (\(cal.timeZone.identifier))")
            }
        }
    }

    // ── Once ──
    
    private func scheduleOnce(reminder: LystariaReminder, content: UNMutableNotificationContent, baseID: String) {
        let now = Date()
        let delta = reminder.nextRunAt.timeIntervalSince(now)
        
        if delta < -90 {
            // Genuinely in the past (more than 90 seconds ago) — skip
            let preview = (reminder.details ?? reminder.title).trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)
            print("⏭ Skipping past one-time reminder (\(Int(-delta))s ago): \(preview)")
            return
        }
        
        if delta <= 3 {
            // Within the next 3 seconds or slightly past — use a time-interval
            // trigger. Calendar triggers with seconds=0 can round into the past
            // and never fire.
            let fireIn = max(delta, 1) // at least 1 second from now
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            print("🔔 scheduleOnce: using interval trigger (\(fireIn)s from now)")
            addRequest(id: baseID, content: content, trigger: trigger)
        } else {
            // Comfortably in the future — use calendar trigger
            var comps = tzCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminder.nextRunAt
            )
            comps.calendar = tzCalendar
            comps.timeZone = tzCalendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            print("🔔 scheduleOnce: calendar trigger for \(comps.hour ?? 0):\(comps.minute ?? 0):\(comps.second ?? 0)")
            addRequest(id: baseID, content: content, trigger: trigger)
        }
    }
    
    // ── Daily ──
    // Fires every day at the specified time(s).
    // If `timesOfDay` has multiple entries (e.g. ["09:00", "21:00"]),
    // we create one notification per time.
    
    private func scheduleDaily(schedule: ReminderSchedule, content: UNMutableNotificationContent, baseID: String) {
        let times = allTimes(from: schedule)
        
        for (index, time) in times.enumerated() {
            let (hour, minute) = parseTime(time)
            var comps = DateComponents()
            comps.calendar = tzCalendar
            comps.timeZone = tzCalendar.timeZone
            comps.hour = hour
            comps.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = times.count == 1 ? baseID : "\(baseID).\(index)"
            print("🔔 scheduleDaily: \(id) at \(hour):\(String(format: "%02d", minute)) (\(tzCalendar.timeZone.identifier)), repeats=true")
            addRequest(id: id, content: content, trigger: trigger)
        }
    }
    
    // ── Weekly ──
    // Fires on specific days of the week at the specified time.
    // `daysOfWeek` uses 0=Sun, 1=Mon, ..., 6=Sat
    // iOS weekday uses 1=Sun, 2=Mon, ..., 7=Sat
    // So we add 1 to convert.
    
    private func scheduleWeekly(schedule: ReminderSchedule, content: UNMutableNotificationContent, baseID: String) {
        let days = schedule.daysOfWeek ?? [0] // default Sunday
        let times = allTimes(from: schedule)
        
        for day in days {
            for (tIndex, time) in times.enumerated() {
                let (hour, minute) = parseTime(time)
                var comps = DateComponents()
                comps.calendar = tzCalendar
                comps.timeZone = tzCalendar.timeZone
                comps.weekday = day + 1  // Convert 0-6 → 1-7
                comps.hour = hour
                comps.minute = minute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let id = times.count == 1
                    ? "\(baseID).day\(day)"
                    : "\(baseID).day\(day).t\(tIndex)"
                addRequest(id: id, content: content, trigger: trigger)
            }
        }
    }
    
    // ── Monthly ──
    // Fires on a specific day of the month at the specified time.
    
    private func scheduleMonthly(schedule: ReminderSchedule, content: UNMutableNotificationContent, baseID: String) {
        let dayOfMonth = schedule.dayOfMonth ?? 1
        let times = allTimes(from: schedule)
        
        for (index, time) in times.enumerated() {
            let (hour, minute) = parseTime(time)
            var comps = DateComponents()
            comps.calendar = tzCalendar
            comps.timeZone = tzCalendar.timeZone
            comps.day = dayOfMonth
            comps.hour = hour
            comps.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = times.count == 1 ? baseID : "\(baseID).\(index)"
            addRequest(id: id, content: content, trigger: trigger)
        }
    }
    
    // ── Yearly ──
    // Fires on a specific month + day at the specified time.
    
    private func scheduleYearly(schedule: ReminderSchedule, content: UNMutableNotificationContent, baseID: String) {
        let month = schedule.anchorMonth ?? 1
        let day = schedule.anchorDay ?? 1
        let times = allTimes(from: schedule)
        
        for (index, time) in times.enumerated() {
            let (hour, minute) = parseTime(time)
            var comps = DateComponents()
            comps.calendar = tzCalendar
            comps.timeZone = tzCalendar.timeZone
            comps.month = month
            comps.day = day
            comps.hour = hour
            comps.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = times.count == 1 ? baseID : "\(baseID).\(index)"
            addRequest(id: id, content: content, trigger: trigger)
        }
    }
    
    // ── Interval ──
    // Fires every N minutes, repeating.
    // iOS requires interval >= 60 seconds for repeating triggers.
    
    private func scheduleInterval(schedule: ReminderSchedule, content: UNMutableNotificationContent, baseID: String) {
        let minutes = schedule.intervalMinutes ?? 60
        let seconds = max(TimeInterval(minutes * 60), 60) // iOS minimum is 60s
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: true
        )
        addRequest(id: baseID, content: content, trigger: trigger)
    }

    // (addBootstrapIfNeeded removed — it caused duplicate notifications)
    
    // ═══════════════════════════════════════════════
    // MARK: - Private Helpers
    // ═══════════════════════════════════════════════
    
    /// Creates a unique base notification ID for a reminder
    private func notificationBaseID(for reminder: LystariaReminder) -> String {
        // IMPORTANT:
        // Do NOT use hashValue for identifiers. Swift hash values are not stable across launches,
        // which leads to "orphaned" notifications that never get cancelled (exactly what your logs show).
        //
        // Use the reminder's SwiftData persistent model identifier string.
        let stable = String(describing: reminder.persistentModelID)
        // Make it notification-safe (remove spaces and punctuation that can vary)
        let safe = stable
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "/", with: "-")
        return "lystaria.reminder.\(safe)"
    }
    
    /// Adds a UNNotificationRequest to the notification center
    private func addRequest(id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to schedule notification '\(id)': \(error)")
            } else {
                print("🔔 Scheduled: \(id)")
            }
        }
    }
    
    /// Returns all times to schedule for a given schedule.
    /// Prefers `timesOfDay` if set, falls back to `timeOfDay`, then "09:00".
    private func allTimes(from schedule: ReminderSchedule) -> [String] {
        if let times = schedule.timesOfDay, !times.isEmpty {
            return times
        }
        if let single = schedule.timeOfDay, !single.isEmpty {
            return [single]
        }
        return ["09:00"]
    }
    
    /// Parses a time string into (hour, minute).
    /// Supports BOTH 24h and 12h typed formats.
    /// Examples:
    /// - "09:00", "9:00"
    /// - "4:30 PM", "4:30PM"
    /// - "4 PM", "4PM"
    /// Returns (9, 0) on parse failure.
    private func parseTime(_ str: String) -> (Int, Int) {
        let raw = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return (9, 0) }

        // 1) Try numeric H:mm / HH:mm first (pure 24-hour)
        let parts = raw.split(separator: ":")
        if parts.count == 2 {
            let left = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let h = Int(left), let m = Int(right),
               (0...23).contains(h), (0...59).contains(m) {
                return (h, m)
            }
        }

        // 2) Try 12-hour formats (AM/PM)
        let candidates = [
            "h:mm a", "h:mma",
            "hh:mm a", "hh:mma",
            "h a", "ha",
            "hh a", "hha"
        ]

        for fmt in candidates {
            let df = DateFormatter()
            df.locale = .current
            df.dateFormat = fmt

            let normalized = raw.uppercased()

            if let parsed = df.date(from: normalized) {
                let c = Calendar.current.dateComponents([.hour, .minute], from: parsed)
                return (c.hour ?? 9, c.minute ?? 0)
            }
        }

        // 3) Last-ditch: strip AM/PM and retry as H:mm
        let stripped = raw
            .replacingOccurrences(of: "AM", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "PM", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts2 = stripped.split(separator: ":")
        if parts2.count == 2,
           let h = Int(parts2[0]),
           let m = Int(parts2[1]),
           (0...23).contains(h),
           (0...59).contains(m) {
            return (h, m)
        }

        return (9, 0)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Debug
    // ─────────────────────────────────────────────
    
    /// Prints all pending Lystaria notifications to the console.
    /// Useful for debugging.
    func printPendingNotifications() {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let calendarReqs = requests
                    .filter { $0.identifier.hasPrefix("lystaria.calendar.") }
                    .sorted { $0.identifier < $1.identifier }

                print("\n==============================")
                print("📆 Pending Lystaria Calendar Notifications: \(calendarReqs.count)")
                print("Timezone (effective): \(TimeZone.current.identifier)")
                print("Now: \(Date())")
                print("==============================")

                for req in calendarReqs {
                    var fireDesc = "(unknown)"

                    if let calTrig = req.trigger as? UNCalendarNotificationTrigger {
                        let comps = calTrig.dateComponents
                        var cal = Calendar.current
                        // Best-effort: triggers don’t reliably expose timezone
                        cal.timeZone = comps.timeZone ?? .current

                        if let fire = cal.date(from: comps) {
                            fireDesc = "\(fire) (repeats=\(calTrig.repeats)) comps=\(comps)"
                        } else {
                            fireDesc = "comps=\(comps) repeats=\(calTrig.repeats)"
                        }
                    } else if let interval = req.trigger as? UNTimeIntervalNotificationTrigger {
                        fireDesc = "interval=\(interval.timeInterval)s repeats=\(interval.repeats)"
                    }

                    let title = req.content.title
                    let body = req.content.body

                    print("\n— 🔔 \(req.identifier)")
                    print("   • title: \(title)")
                    print("   • body: \(body.prefix(80))")
                    print("   • trigger: \(fireDesc)")
                }

                print("\n==============================\n")
            }
        }

        /// Debug helper to print a scheduling plan summary for a recurring calendar event.
        private func debugLogCalendarPlan(
            id: String,
            title: String,
            startDate: Date,
            allDay: Bool,
            recurrence: RecurrenceRule,
            exceptionsCount: Int,
            occurrences: [Date],
            upcoming: [Date]
        ) {
            print("\n====================================")
            print("📆 CALENDAR SCHEDULE PLAN")
            print("• id: \(id)")
            print("• title: \(title)")
            print("• startDate(anchor): \(startDate)")
            print("• allDay: \(allDay)")
            print("• timezone(effective): \(effectiveTimezoneID)")
            print("• now: \(Date())")
            print("• exceptions: \(exceptionsCount)")
            print("• freq: \(recurrence.freq)")
            print("• interval: \(recurrence.interval)")
            if let by = recurrence.byWeekday {
                print("• byWeekday: \(by)")
            }
            if let end = recurrence.end {
                print("• end.kind: \(end.kind)")
                print("• end.count: \(end.count ?? -1)")
                print("• end.until: \(String(describing: end.until))")
            } else {
                print("• end: nil (infinite)")
            }
            print("------------------------------------")
            print("Generated occurrences: \(occurrences.count)")
            if let first = occurrences.first { print("• first: \(first)") }
            if let last = occurrences.last { print("• last: \(last)") }
            print("Upcoming (>= now): \(upcoming.count)")
            for (i, d) in upcoming.prefix(12).enumerated() {
                print("  \(i + 1). \(d)")
            }
            if upcoming.count > 12 {
                print("  … \(upcoming.count - 12) more")
            }
            print("====================================\n")
        }

        /// Debug helper to log a one-shot calendar schedule.
        private func debugLogCalendarOneShot(id: String, title: String, fireDate: Date) {
            print("\n====================================")
            print("📆 CALENDAR ONE-SHOT SCHEDULE")
            print("• id: \(id)")
            print("• title: \(title)")
            print("• fireDate: \(fireDate)")
            print("• timezone(effective): \(effectiveTimezoneID)")
            print("• now: \(Date())")
            print("====================================\n")
        }

        /// Prints all pending Lystaria notifications (calendar + reminders) to the console.
        func printAllPendingLystariaNotifications() {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let lystaria = requests.filter { $0.identifier.hasPrefix("lystaria.") }
                print("═══ Pending Lystaria Notifications: \(lystaria.count) ═══")
                for req in lystaria {
                    let trigger = req.trigger
                    var triggerDesc = "unknown"
                    if let cal = trigger as? UNCalendarNotificationTrigger {
                        triggerDesc = "calendar: \(cal.dateComponents), repeats: \(cal.repeats)"
                    } else if let interval = trigger as? UNTimeIntervalNotificationTrigger {
                        triggerDesc = "interval: \(interval.timeInterval)s, repeats: \(interval.repeats)"
                    }
                    print("  📌 \(req.identifier)")
                    print("     body: \(req.content.body.prefix(50))")
                    print("     trigger: \(triggerDesc)")
                }
                print("═══════════════════════════════════════════════════")
            }
        }
}

// ═══════════════════════════════════════════════════
// MARK: - UNUserNotificationCenterDelegate
// ═══════════════════════════════════════════════════
//
// This handles:
// 1. Showing notifications while the app is in the foreground
// 2. Processing "Done" and "Snooze" action taps
//

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Called when a notification arrives while the app is in the foreground.
    /// We show it as a banner by passing [.banner, .sound] to the completion handler.
    ///
    /// NOTE: Using the completion-handler version instead of the async version
    /// because the async variant has been unreliable on some iOS versions
    /// when the delegate is on @MainActor.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier
        let body = notification.request.content.body.prefix(40)
        print("📬 willPresent fired for: \(id) — \(body)")
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    /// Called when the user taps a notification or one of its action buttons.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let rawUserInfo = response.notification.request.content.userInfo
        
        print("📬 didReceive action: \(actionID)")
        
        let info: [String: Any] = [
            "actionID": actionID,
            "userInfo": rawUserInfo
        ]
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .lystariaNotificationAction,
                object: nil,
                userInfo: info
            )
        }
        
        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let lystariaNotificationAction = Notification.Name("lystariaNotificationAction")
}

