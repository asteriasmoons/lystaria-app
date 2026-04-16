// NotificationManager.swift
// Lystaria
//
// Handles all local notification scheduling for reminders and calendar events.
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
// 5. When the user taps a notification body, `pendingDeepLink` is set to
//    `.reminders`, which the root view observes to switch to the Reminders tab.
//    Done and Snooze action taps are broadcast via `lystariaNotificationAction`.
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
// Category "REMINDER" — used for reminder notifications only:
//   - "DONE"   → marks the reminder as acknowledged
//   - "SNOOZE" → reschedules for 10 minutes later
//
// Calendar notifications use no category (no action buttons needed).

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

// MARK: - Deep Link

/// Destinations that a notification tap can open.
enum NotificationDeepLink: Equatable {
    case reminders
}

// MARK: - NotificationManager

@MainActor
final class NotificationManager: NSObject, Combine.ObservableObject {

    static let shared = NotificationManager()

    override init() {
        super.init()
        #if os(iOS)
        // Ensure foreground notifications are shown even if setup() hasn't been called yet.
        UNUserNotificationCenter.current().delegate = self
        #endif
    }

    /// Category identifier for reminder notifications (Done / Snooze actions).
    static let reminderCategoryID = "REMINDER"

    /// Action identifiers.
    static let doneActionID  = "DONE"
    static let snoozeActionID = "SNOOZE"

    /// Whether we have notification permission.
    @Combine.Published var isAuthorized = false

    /// Set by a notification body tap. Observe this in the root view to drive tab navigation.
    @Combine.Published var pendingDeepLink: NotificationDeepLink? = nil

    /// Reference to the model container (set from LystariaApp on launch).
    var modelContainer: ModelContainer?

    /// Effective timezone identifier loaded from UserSettings.
    /// Defaults to device timezone if settings not available.
    @Combine.Published var effectiveTimezoneID: String = TimeZone.current.identifier

    /// Prevents rapid duplicate reschedules (setup + foreground + saves).
    private var isReschedulingCalendar  = false
    private var lastCalendarRescheduleAt: Date?
    private var isReschedulingReminders = false
    private var lastReminderRescheduleAt: Date?
    private var hasCompletedSetup = false

    /// Debounce window for reschedule guards (seconds).
    private let rescheduleDebounceInterval: TimeInterval = 5

    // ─────────────────────────────────────────────
    // MARK: - Timezone
    // ─────────────────────────────────────────────

    func refreshEffectiveTimezone(from container: ModelContainer?) {
        let defaults = UserDefaults.standard
        let useSystem = defaults.object(forKey: "lystaria.useSystemTimezone") as? Bool ?? true
        let chosen    = defaults.string(forKey: "lystaria.timezoneIdentifier") ?? TimeZone.current.identifier
        effectiveTimezoneID = useSystem ? TimeZone.current.identifier : chosen
    }

    /// Calendar configured with the effective timezone.
    var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: effectiveTimezoneID) ?? .current
        return cal
    }

    // ─────────────────────────────────────────────
    // MARK: - Setup
    // ─────────────────────────────────────────────

    /// Call once at app launch. Registers categories, requests permission,
    /// sets the delegate, and schedules an initial calendar reschedule.
    func setup() {
        guard !hasCompletedSetup else { return }
        hasCompletedSetup = true

        let center = UNUserNotificationCenter.current()

        // Register reminder actions (Done / Snooze).
        // Calendar notifications intentionally use no category.
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

        center.delegate = self

        refreshAuthorizationStatus()
        refreshEffectiveTimezone(from: modelContainer)

        // Observe app foreground to refresh scheduling windows.
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let container = self.modelContainer else { return }
                self.refreshEffectiveTimezone(from: container)
                self.rescheduleAllCalendarEvents(from: container)
            }
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let container = self.modelContainer else { return }
                self.refreshAuthorizationStatus()
                self.refreshEffectiveTimezone(from: container)
                self.rescheduleAllCalendarEvents(from: container)
            }
        }
        #endif

        // Initial calendar reschedule if the container is already available.
        // Reminders are NOT rescheduled here on launch — their recurring recomputation
        // can be expensive and should be triggered explicitly.
        if let container = modelContainer {
            rescheduleAllCalendarEvents(from: container)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Permission
    // ─────────────────────────────────────────────

    func requestPermissionIfNeeded() {
        if isAuthorized { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            if settings.authorizationStatus == .authorized {
                Task { @MainActor in self.isAuthorized = true }
                return
            }
            Task { [weak self] in
                let granted = await self?.requestPermission() ?? false
                if !granted { print("⚠️ Notifications permission not granted.") }
            }
        }
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }

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
    /// Cancels any existing notifications first, then creates new ones.
    func scheduleReminder(_ reminder: LystariaReminder) {
        cancelReminder(reminder)

        guard reminder.status == .scheduled else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body  = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.badge = nil

        let idString = String(describing: reminder.persistentModelID)
        content.userInfo = ["reminderID": idString]

        let baseID   = notificationBaseID(for: reminder)
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
    ///
    /// IMPORTANT: We compute the IDs directly instead of fetching pending requests first.
    /// The fetch-then-remove pattern is async — by the time the fetch callback fires and
    /// removes the old IDs, the new `add(request:)` call may have already been submitted,
    /// causing iOS to delete the freshly scheduled notification. That was the root cause
    /// of intermittent missing notifications.
    ///
    /// iOS silently ignores remove calls for identifiers that don't exist, so this is safe.
    func cancelReminder(_ reminder: LystariaReminder) {
        let baseID = notificationBaseID(for: reminder)
        let center = UNUserNotificationCenter.current()

        // Build the full set of IDs this reminder could have produced.
        // Covers: base, .0–.9 (multiple timesOfDay), .day0–.day6 (weekly days),
        // .day0.t0–.day6.t3 (weekly multi-time), and .snooze.* (handled by prefix scan below).
        var ids: [String] = [baseID]

        // Multiple timesOfDay suffixes
        for i in 0..<20 {
            ids.append("\(baseID).\(i)")
        }

        // Weekly day suffixes (with and without time index)
        for d in 0..<7 {
            ids.append("\(baseID).day\(d)")
            for t in 0..<20 {
                ids.append("\(baseID).day\(d).t\(t)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        print("🔕 Cancelled notifications for: \(baseID)")

        // Snooze IDs use a timestamp suffix so we can't predict them —
        // do a single async fetch just for those, which is safe because
        // snooze requests are never immediately followed by a new schedule.
        center.getPendingNotificationRequests { requests in
            let snoozeIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(baseID + ".snooze.") }
            if !snoozeIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: snoozeIDs)
                print("🔕 Cancelled \(snoozeIDs.count) snooze notification(s) for: \(baseID)")
            }
        }
    }

    /// Cancels ALL Lystaria reminder notifications (e.g. on logout).
    func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let lystariaIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("lystaria.reminder.") }
            center.removePendingNotificationRequests(withIdentifiers: lystariaIDs)
            print("🔕 Cancelled all \(lystariaIDs.count) Lystaria reminder notifications")
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Reschedule All Reminders
    // ─────────────────────────────────────────────

    func rescheduleAll(from container: ModelContainer) {
        refreshEffectiveTimezone(from: container)

        if isReschedulingReminders {
            print("⏭ Skipping reminder reschedule (already running)")
            return
        }
        if let last = lastReminderRescheduleAt,
           Date().timeIntervalSince(last) < rescheduleDebounceInterval {
            print("⏭ Skipping reminder reschedule (debounced)")
            return
        }

        isReschedulingReminders  = true
        lastReminderRescheduleAt = Date()

        Task { @MainActor in
            defer { self.isReschedulingReminders = false }

            let context    = container.mainContext
            let descriptor = FetchDescriptor<LystariaReminder>(
                predicate: #Predicate<LystariaReminder> { $0.statusRaw == "scheduled" }
            )

            do {
                let reminders = try context.fetch(descriptor)

                let center  = UNUserNotificationCenter.current()
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

    func rescheduleAllCalendarEvents(from container: ModelContainer) {
        Task { @MainActor in
            self.refreshEffectiveTimezone(from: container)

            if isReschedulingCalendar {
                print("⏭ Skipping calendar reschedule (already running)")
                return
            }
            if let last = lastCalendarRescheduleAt,
               Date().timeIntervalSince(last) < rescheduleDebounceInterval {
                print("⏭ Skipping calendar reschedule (debounced)")
                return
            }
            isReschedulingCalendar    = true
            lastCalendarRescheduleAt  = Date()
            defer { isReschedulingCalendar = false }

            let context    = container.mainContext
            let descriptor = FetchDescriptor<CalendarEvent>()
            do {
                let allEvents = try context.fetch(descriptor)

                // Purge all existing calendar notifications before rebuilding.
                let center  = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let oldCalendarIDs = pending
                    .map(\.identifier)
                    .filter { $0.hasPrefix("lystaria.calendar.") }

                if !oldCalendarIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: oldCalendarIDs)
                    print("🧹 Purged \(oldCalendarIDs.count) legacy calendar pending notification(s)")
                }

                let delivered = await center.deliveredNotifications()
                let deliveredIDs = delivered
                    .map { $0.request.identifier }
                    .filter { $0.hasPrefix("lystaria.calendar.") }
                if !deliveredIDs.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
                    print("🧹 Purged \(deliveredIDs.count) legacy calendar delivered notification(s)")
                }

                let recurringEvents: [(CalendarEvent, RecurrenceRule)] = allEvents.compactMap { event in
                    guard let rule = event.recurrence else { return nil }
                    return (event, rule)
                }

                print("📅 Rescheduling calendar events: \(recurringEvents.count) recurring")

                for (event, rule) in recurringEvents {
                    let id = event.reminderServerId ?? UUID().uuidString
                    if event.reminderServerId == nil {
                        event.reminderServerId = id
                        event.updatedAt  = Date()
                        event.needsSync  = true
                    }
                    let body = event.allDay
                        ? "All-day event"
                        : (event.location?.isEmpty == false
                            ? "Event: \(event.title) • \(event.location!)"
                            : "Event: \(event.title)")
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

    func rescheduleAllCalendarEventsIfPossible() {
        if let container = modelContainer {
            rescheduleAllCalendarEvents(from: container)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Snooze
    // ─────────────────────────────────────────────

    func snoozeReminder(_ reminder: LystariaReminder, minutes: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body  = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID

        let idString = String(describing: reminder.persistentModelID)
        content.userInfo = ["reminderID": idString]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let snoozeID = "\(notificationBaseID(for: reminder)).snooze.\(Date().timeIntervalSince1970)"
        let request  = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)

        let preview = (reminder.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Snooze scheduling error: \(error)")
            } else {
                print("💤 Snoozed for \(minutes) min: \(preview)")
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Calendar Events: Cancel
    // ─────────────────────────────────────────────

    /// Cancels pending and delivered notifications for a calendar event.
    func cancelAllCalendarNotifications(id: String) {
        let center     = UNUserNotificationCenter.current()
        let idsToRemove = [
            "lystaria.calendar." + id,        // one-shot
            "lystaria.calendar." + id + ".0"  // recurring next occurrence
        ]
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
    }

    // ─────────────────────────────────────────────
    // MARK: - Calendar Events: Schedule
    // ─────────────────────────────────────────────

    /// Schedules the next occurrence of a recurring calendar event.
    func scheduleRecurringCalendarEvent(
        id: String,
        title: String,
        body: String,
        startDate: Date,
        allDay: Bool,
        recurrence: RecurrenceRule,
        exceptions: [String]
    ) {
        cancelAllCalendarNotifications(id: id)

        let now              = Date()
        let rollingWindowDays = 60
        let fiveYearsOut     = tzCalendar.date(byAdding: .year, value: 5, to: now) ?? now
        let horizonByRolling = tzCalendar.date(byAdding: .day, value: rollingWindowDays, to: now) ?? now
        let exceptionSet     = Set(exceptions)

        let occurrences: [Date]
        if let end = recurrence.end, end.kind == .count {
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
            let horizon: Date
            if let end = recurrence.end, end.kind == .until {
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

        let upcoming = occurrences.filter { $0 >= now }.sorted()
        guard let fireDate = upcoming.first else {
            print("⚠️ No upcoming calendar occurrences to schedule for id=\(id)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = [
            "calendarEventID": id,
            "kind": "calendar"
        ]

        var comps = tzCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar  = tzCalendar
        comps.timeZone  = tzCalendar.timeZone
        comps.second    = comps.second ?? 0
        let trigger     = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = "lystaria.calendar." + id + ".0"
        let request    = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Calendar recurring scheduling error: \(error)")
            } else {
                print("🔔 Scheduled next calendar occurrence for id=\(id) at \(fireDate)")
            }
        }
    }

    /// Schedules a single one-shot calendar event notification at an exact date.
    func scheduleCalendarEvent(id: String, title: String, body: String, fireDate: Date) {
        cancelAllCalendarNotifications(id: id)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = [
            "calendarEventID": id,
            "kind": "calendar"
        ]

        var comps = tzCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar = tzCalendar
        comps.timeZone = tzCalendar.timeZone
        comps.second   = comps.second ?? 0
        let trigger    = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = "lystaria.calendar." + id
        let request    = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ Calendar single scheduling error: \(error)") }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Occurrence Computation
    // ─────────────────────────────────────────────

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
            guard fire >= from, fire <= untilHorizon else { return }
            guard !isExceptionDate(fire, cal: cal, exceptions: exceptions) else { return }
            results.append(fire)
        }

        var cursor = max(startDate, from)

        switch rule.freq {
        case .daily:
            while cursor <= untilHorizon {
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: cursor) ?? cursor
                appendIfValid(fire)
                cursor = cal.date(byAdding: .day, value: rule.interval, to: cursor) ?? cursor
            }

        case .weekly:
            let weekdays = rule.byWeekday?.sorted() ?? [cal.component(.weekday, from: startDate) - 1]
            while cursor <= untilHorizon {
                guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: cursor) else { break }
                let weekStart = weekInterval.start
                for wd in weekdays {
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
                let day  = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                appendIfValid(fire)
                cursor = cal.date(byAdding: .month, value: rule.interval, to: cursor) ?? cursor
            }

        case .yearly:
            let startMonth = cal.component(.month, from: startDate)
            let startDay   = cal.component(.day,   from: startDate)
            while cursor <= untilHorizon {
                var comps  = cal.dateComponents([.year], from: cursor)
                comps.month = startMonth
                comps.day   = startDay
                let day  = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                appendIfValid(fire)
                cursor = cal.date(byAdding: .year, value: rule.interval, to: cursor) ?? cursor
            }
        }

        return results
    }

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
        let maxIterations = max(5000, count * 10)
        var iterations    = 0
        var cursor        = startDate

        func appendIfValid(_ fire: Date) {
            guard fire <= untilHorizon else { return }
            guard !isExceptionDate(fire, cal: cal, exceptions: exceptions) else { return }
            results.append(fire)
        }

        switch rule.freq {
        case .daily:
            while results.count < count, cursor <= untilHorizon, iterations < maxIterations {
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: cursor) ?? cursor
                appendIfValid(fire)
                cursor = cal.date(byAdding: .day, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }

        case .weekly:
            let weekdays = rule.byWeekday?.sorted() ?? [cal.component(.weekday, from: startDate) - 1]
            while results.count < count, cursor <= untilHorizon, iterations < maxIterations {
                guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: cursor) else { break }
                let weekStart = weekInterval.start
                for wd in weekdays {
                    guard results.count < count else { break }
                    let normalizedWD = (1...7).contains(wd) ? wd - 1 : wd
                    if let day = cal.date(byAdding: .day, value: normalizedWD, to: weekStart) {
                        let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                        if fire >= startDate { appendIfValid(fire) }
                    }
                }
                cursor = cal.date(byAdding: .weekOfYear, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }
            results.sort()
            if results.count > count { results = Array(results.prefix(count)) }

        case .monthly:
            let startDay = cal.component(.day, from: startDate)
            while results.count < count, cursor <= untilHorizon, iterations < maxIterations {
                var comps = cal.dateComponents([.year, .month], from: cursor)
                if let monthDate = cal.date(from: comps),
                   let range = cal.range(of: .day, in: .month, for: monthDate) {
                    comps.day = min(startDay, range.count)
                } else {
                    comps.day = startDay
                }
                let day  = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                if fire >= startDate { appendIfValid(fire) }
                cursor = cal.date(byAdding: .month, value: rule.interval, to: cursor) ?? cursor
                iterations += 1
            }

        case .yearly:
            let startMonth = cal.component(.month, from: startDate)
            let startDay   = cal.component(.day,   from: startDate)
            while results.count < count, cursor <= untilHorizon, iterations < maxIterations {
                var comps  = cal.dateComponents([.year], from: cursor)
                comps.month = startMonth
                comps.day   = startDay
                let day  = cal.date(from: comps) ?? cursor
                let fire = cal.date(bySettingHour: baseHour, minute: baseMinute, second: 0, of: day) ?? day
                if fire >= startDate { appendIfValid(fire) }
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
        let comps = cal.dateComponents([.hour, .minute], from: startDate)
        return allDay ? (9, 0) : (comps.hour ?? 9, comps.minute ?? 0)
    }

    private func isExceptionDate(_ date: Date, cal: Calendar, exceptions: Set<String>) -> Bool {
        let y   = cal.component(.year,  from: date)
        let m   = cal.component(.month, from: date)
        let d   = cal.component(.day,   from: date)
        let key = String(format: "%04d-%02d-%02d", y, m, d)
        return exceptions.contains(key)
    }

    // ═══════════════════════════════════════════════
    // MARK: - Private: Schedule by Type
    // ═══════════════════════════════════════════════

    private func scheduleNextRecurringReminder(
        reminder: LystariaReminder,
        schedule: ReminderSchedule,
        content: UNMutableNotificationContent,
        baseID: String
    ) {
        let now = Date()
        // For interval reminders, nextRunAt is already the window-clamped next fire time
        // set by acknowledgeOneDueHabitReminder. Use it directly instead of recomputing
        // via nextRun, which has no window awareness.
        // For non-interval kinds, nextRun recomputes correctly from schedule.
        let fireDate: Date
        if schedule.kind == .interval {
            fireDate = reminder.nextRunAt > now ? reminder.nextRunAt : ReminderCompute.nextRun(after: now, reminder: reminder)
        } else {
            fireDate = ReminderCompute.nextRun(after: now, reminder: reminder)
        }

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: reminder.timezone) ?? .current

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        comps.calendar = cal
        comps.timeZone = cal.timeZone
        comps.second   = comps.second ?? 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: baseID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ scheduleNextRecurringReminder error: \(error)")
            } else {
                print("🔔 Scheduled next recurring reminder: \(baseID) at \(fireDate) (\(cal.timeZone.identifier))")
            }
        }
    }

    private func scheduleOnce(reminder: LystariaReminder, content: UNMutableNotificationContent, baseID: String) {
        let now   = Date()
        let delta = reminder.nextRunAt.timeIntervalSince(now)

        if delta < -90 {
            let preview = (reminder.details ?? reminder.title).trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)
            print("⏭ Skipping past one-time reminder (\(Int(-delta))s ago): \(preview)")
            return
        }

        if delta <= 3 {
            let fireIn  = max(delta, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            print("🔔 scheduleOnce: using interval trigger (\(fireIn)s from now)")
            addRequest(id: baseID, content: content, trigger: trigger)
        } else {
            var comps = tzCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.nextRunAt)
            comps.calendar = tzCalendar
            comps.timeZone = tzCalendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            print("🔔 scheduleOnce: calendar trigger for \(comps.hour ?? 0):\(comps.minute ?? 0):\(comps.second ?? 0)")
            addRequest(id: baseID, content: content, trigger: trigger)
        }
    }

    // ═══════════════════════════════════════════════
    // MARK: - Private Helpers
    // ═══════════════════════════════════════════════

    private func notificationBaseID(for reminder: LystariaReminder) -> String {
        let stable = String(describing: reminder.persistentModelID)
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

    private func allTimes(from schedule: ReminderSchedule) -> [String] {
        if let times = schedule.timesOfDay, !times.isEmpty { return times }
        if let single = schedule.timeOfDay, !single.isEmpty { return [single] }
        return ["09:00"]
    }

    private func parseTime(_ str: String) -> (Int, Int) {
        let raw = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return (9, 0) }

        // 1) H:mm / HH:mm (24-hour)
        let parts = raw.split(separator: ":")
        if parts.count == 2,
           let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let m = Int(parts[1].trimmingCharacters(in: .whitespaces)),
           (0...23).contains(h), (0...59).contains(m) {
            return (h, m)
        }

        // 2) 12-hour AM/PM formats
        let candidates = ["h:mm a", "h:mma", "hh:mm a", "hh:mma", "h a", "ha", "hh a", "hha"]
        for fmt in candidates {
            let df = DateFormatter()
            df.locale     = .current
            df.dateFormat = fmt
            if let parsed = df.date(from: raw.uppercased()) {
                let c = Calendar.current.dateComponents([.hour, .minute], from: parsed)
                return (c.hour ?? 9, c.minute ?? 0)
            }
        }

        // 3) Strip AM/PM and retry
        let stripped = raw
            .replacingOccurrences(of: "AM", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "PM", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts2 = stripped.split(separator: ":")
        if parts2.count == 2,
           let h = Int(parts2[0]), let m = Int(parts2[1]),
           (0...23).contains(h), (0...59).contains(m) {
            return (h, m)
        }

        return (9, 0)
    }

    // ─────────────────────────────────────────────
    // MARK: - Debug
    // ─────────────────────────────────────────────

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
                    var cal   = Calendar.current
                    cal.timeZone = comps.timeZone ?? .current
                    fireDesc = cal.date(from: comps).map { "\($0) (repeats=\(calTrig.repeats))" }
                        ?? "comps=\(comps) repeats=\(calTrig.repeats)"
                } else if let interval = req.trigger as? UNTimeIntervalNotificationTrigger {
                    fireDesc = "interval=\(interval.timeInterval)s repeats=\(interval.repeats)"
                }
                print("\n— 🔔 \(req.identifier)")
                print("   • title: \(req.content.title)")
                print("   • body: \(req.content.body.prefix(80))")
                print("   • trigger: \(fireDesc)")
            }
            print("\n==============================\n")
        }
    }

    func printAllPendingLystariaNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let lystaria = requests.filter { $0.identifier.hasPrefix("lystaria.") }
            print("═══ Pending Lystaria Notifications: \(lystaria.count) ═══")
            for req in lystaria {
                var triggerDesc = "unknown"
                if let cal = req.trigger as? UNCalendarNotificationTrigger {
                    triggerDesc = "calendar: \(cal.dateComponents), repeats: \(cal.repeats)"
                } else if let interval = req.trigger as? UNTimeIntervalNotificationTrigger {
                    triggerDesc = "interval: \(interval.timeInterval)s, repeats: \(interval.repeats)"
                }
                print("  📌 \(req.identifier)")
                print("     body: \(req.content.body.prefix(50))")
                print("     trigger: \(triggerDesc)")
            }
            print("═══════════════════════════════════════════════════")
        }
    }

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
        if let by = recurrence.byWeekday { print("• byWeekday: \(by)") }
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
        if let last  = occurrences.last  { print("• last: \(last)") }
        print("Upcoming (>= now): \(upcoming.count)")
        for (i, d) in upcoming.prefix(12).enumerated() { print("  \(i + 1). \(d)") }
        if upcoming.count > 12 { print("  … \(upcoming.count - 12) more") }
        print("====================================\n")
    }

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
}

// ═══════════════════════════════════════════════════
// MARK: - UNUserNotificationCenterDelegate
// ═══════════════════════════════════════════════════

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Show notifications as banners even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id   = notification.request.identifier
        let body = notification.request.content.body.prefix(40)
        print("📬 willPresent fired for: \(id) — \(body)")
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Called when the user taps a notification body or one of its action buttons.
    ///
    /// - Tapping the body (UNNotificationDefaultActionIdentifier) sets `pendingDeepLink = .reminders`
    ///   so the root view can switch to the Reminders tab.
    /// - Done / Snooze actions are broadcast via `lystariaNotificationAction` as before.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let notifID  = response.notification.request.identifier

        print("📬 didReceive: id=\(notifID) action=\(actionID)")

        if actionID == UNNotificationDefaultActionIdentifier {
            print("📬👆 Body tapped — setting pendingDeepLink = .reminders")
            Task { @MainActor in
                print("📬🔀 MainActor: assigning pendingDeepLink = .reminders")
                NotificationManager.shared.pendingDeepLink = .reminders
            }
        } else {
            print("📬🎬 Action button tapped: \(actionID)")
            let info: [String: Any] = ["actionID": actionID, "userInfo": userInfo]
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .lystariaNotificationAction,
                    object: nil,
                    userInfo: info
                )
            }
        }

        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let lystariaNotificationAction = Notification.Name("lystariaNotificationAction")
}
