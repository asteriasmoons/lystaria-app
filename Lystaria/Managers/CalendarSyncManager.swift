//
//  CalendarSyncManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/11/26.
//

import Foundation
import EventKit
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class CalendarSyncManager {
    let eventStore = EKEventStore()

    var hasFullAccess = false
    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var calendars: [EKCalendar] = []
    var isRequestingAccess = false
    var isSyncing = false
    var errorMessage: String?
    var syncStatusMessage: String?
    var lastSyncDate: Date?

    init() {
        refreshAuthorizationStatus()
        if authorizationStatus == .fullAccess {
            loadCalendars()
        }
    }

    func refreshAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status
        hasFullAccess = (status == .fullAccess)
    }

    func requestAccess() async {
        isRequestingAccess = true
        errorMessage = nil

        defer {
            isRequestingAccess = false
        }

        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            refreshAuthorizationStatus()

            if granted {
                loadCalendars()
            } else {
                errorMessage = "Calendar access was not granted."
            }
        } catch {
            refreshAuthorizationStatus()
            errorMessage = error.localizedDescription
        }
    }

    func loadCalendars() {
        refreshAuthorizationStatus()

        guard hasFullAccess else {
            calendars = []
            return
        }

        calendars = eventStore.calendars(for: .event)
            .filter { calendar in
                calendar.allowsContentModifications
            }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    func syncEvents(
        appEvents: [CalendarEvent],
        modelContext: ModelContext,
        selectedCalendarIdentifier: String
    ) async {
        errorMessage = nil
        syncStatusMessage = nil

        guard hasFullAccess else {
            errorMessage = "Calendar access is not connected."
            return
        }

        guard !selectedCalendarIdentifier.isEmpty else {
            errorMessage = "Select a calendar before syncing."
            return
        }

        loadCalendars()

        guard let targetCalendar = calendar(withIdentifier: selectedCalendarIdentifier) else {
            errorMessage = "The selected calendar could not be found."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let exportedCount = try exportAppEvents(appEvents, to: targetCalendar)
            let importedCount = importCalendarEvents(from: targetCalendar, into: appEvents, modelContext: modelContext)

            try modelContext.save()

            lastSyncDate = Date()
            syncStatusMessage = "Synced \(exportedCount) app event\(exportedCount == 1 ? "" : "s") and imported \(importedCount) calendar event\(importedCount == 1 ? "" : "s")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calendar(withIdentifier identifier: String) -> EKCalendar? {
        if let cached = calendars.first(where: { $0.calendarIdentifier == identifier }) {
            return cached
        }

        return eventStore.calendar(withIdentifier: identifier)
    }

    private func exportAppEvents(_ appEvents: [CalendarEvent], to targetCalendar: EKCalendar) throws -> Int {
        var exportedCount = 0
        let now = Date()

        for appEvent in appEvents {
            let ekEvent: EKEvent

            if let identifier = appEvent.appleCalendarItemIdentifier,
               let existing = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent {
                ekEvent = existing
            } else {
                ekEvent = EKEvent(eventStore: eventStore)
            }

            ekEvent.calendar = targetCalendar
            ekEvent.title = trimmedTitle(from: appEvent.title)
            ekEvent.startDate = appEvent.startDate
            ekEvent.isAllDay = appEvent.allDay
            ekEvent.endDate = resolvedEndDate(for: appEvent)
            ekEvent.notes = appEvent.eventDescription
            ekEvent.location = appEvent.location
            ekEvent.url = resolvedURL(from: appEvent.meetingUrl)

            if let timeZoneId = appEvent.timeZoneId,
               let timeZone = TimeZone(identifier: timeZoneId) {
                ekEvent.timeZone = timeZone
            } else {
                ekEvent.timeZone = nil
            }

            ekEvent.recurrenceRules = recurrenceRules(for: appEvent)

            try eventStore.save(ekEvent, span: .thisEvent, commit: false)

            appEvent.appleCalendarItemIdentifier = ekEvent.calendarItemIdentifier
            appEvent.appleCalendarIdentifier = targetCalendar.calendarIdentifier
            appEvent.lastSyncedAt = now
            appEvent.needsSync = false
            appEvent.updatedAt = now

            exportedCount += 1
        }

        if exportedCount > 0 {
            try eventStore.commit()
        }

        return exportedCount
    }

    private func importCalendarEvents(
        from targetCalendar: EKCalendar,
        into appEvents: [CalendarEvent],
        modelContext: ModelContext
    ) -> Int {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: 2, to: now) ?? now

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: [targetCalendar]
        )

        let externalEvents = eventStore.events(matching: predicate)
        var importedCount = 0
        var seenRecurringSeriesKeys = Set<String>()

        for ekEvent in externalEvents {
            if let recurringSeriesKey = recurringSeriesImportKey(for: ekEvent, in: targetCalendar) {
                if seenRecurringSeriesKeys.contains(recurringSeriesKey) {
                    continue
                }
                seenRecurringSeriesKeys.insert(recurringSeriesKey)
            }

            if let existing = appEvents.first(where: { $0.appleCalendarItemIdentifier == ekEvent.calendarItemIdentifier }) {
                updateAppEvent(existing, from: ekEvent, in: targetCalendar, syncedAt: now)
                continue
            }

            if let looseMatch = appEvents.first(where: {
                $0.appleCalendarIdentifier == targetCalendar.calendarIdentifier &&
                $0.title == trimmedTitle(from: ekEvent.title) &&
                abs($0.startDate.timeIntervalSince(ekEvent.startDate)) < 60
            }) {
                updateAppEvent(looseMatch, from: ekEvent, in: targetCalendar, syncedAt: now)
                continue
            }

            let newEvent = CalendarEvent(
                title: trimmedTitle(from: ekEvent.title),
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                allDay: ekEvent.isAllDay,
                eventDescription: ekEvent.notes,
                color: nil,
                meetingUrl: ekEvent.url?.absoluteString,
                location: ekEvent.location,
                recurrenceRRule: rruleString(from: ekEvent),
                timeZoneId: ekEvent.timeZone?.identifier,
                recurrence: recurrence(from: ekEvent),
                recurrenceExceptions: []
            )

            newEvent.appleCalendarItemIdentifier = ekEvent.calendarItemIdentifier
            newEvent.appleCalendarIdentifier = targetCalendar.calendarIdentifier
            newEvent.lastSyncedAt = now
            newEvent.needsSync = false
            newEvent.updatedAt = now

            modelContext.insert(newEvent)
            importedCount += 1
        }

        return importedCount
    }

    private func updateAppEvent(
        _ appEvent: CalendarEvent,
        from ekEvent: EKEvent,
        in targetCalendar: EKCalendar,
        syncedAt: Date
    ) {
        appEvent.title = trimmedTitle(from: ekEvent.title)
        appEvent.startDate = ekEvent.startDate
        appEvent.endDate = ekEvent.endDate
        appEvent.allDay = ekEvent.isAllDay
        appEvent.eventDescription = ekEvent.notes
        appEvent.location = ekEvent.location
        appEvent.meetingUrl = ekEvent.url?.absoluteString
        appEvent.timeZoneId = ekEvent.timeZone?.identifier
        appEvent.recurrence = recurrence(from: ekEvent)
        appEvent.recurrenceRRule = rruleString(from: ekEvent)
        appEvent.appleCalendarItemIdentifier = ekEvent.calendarItemIdentifier
        appEvent.appleCalendarIdentifier = targetCalendar.calendarIdentifier
        appEvent.lastSyncedAt = syncedAt
        appEvent.needsSync = false
        appEvent.updatedAt = syncedAt
    }

    private func resolvedEndDate(for appEvent: CalendarEvent) -> Date {
        if let endDate = appEvent.endDate {
            return endDate
        }

        if appEvent.allDay {
            return Calendar.current.date(byAdding: .day, value: 1, to: appEvent.startDate) ?? appEvent.startDate
        }

        return Calendar.current.date(byAdding: .hour, value: 1, to: appEvent.startDate) ?? appEvent.startDate
    }

    private func trimmedTitle(from rawTitle: String?) -> String {
        let trimmed = (rawTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Event" : trimmed
    }

    private func resolvedURL(from rawURL: String?) -> URL? {
        guard let rawURL,
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return URL(string: rawURL)
    }

    private func recurringSeriesImportKey(for ekEvent: EKEvent, in targetCalendar: EKCalendar) -> String? {
        guard let recurrence = recurrence(from: ekEvent) else { return nil }

        let title = trimmedTitle(from: ekEvent.title)
        let rule = rruleString(from: ekEvent) ?? "NO-RRULE"
        let timeSignature = recurringTimeSignature(for: ekEvent, recurrence: recurrence)
        let duration = Int((ekEvent.endDate ?? ekEvent.startDate).timeIntervalSince(ekEvent.startDate))
        let location = ekEvent.location ?? ""
        let meetingURL = ekEvent.url?.absoluteString ?? ""

        return [
            targetCalendar.calendarIdentifier,
            title,
            rule,
            timeSignature,
            String(duration),
            location,
            meetingURL
        ].joined(separator: "|")
    }

    private func recurringTimeSignature(for ekEvent: EKEvent, recurrence: RecurrenceRule) -> String {
        let calendar = Calendar.current

        if ekEvent.isAllDay {
            switch recurrence.freq {
            case .daily:
                return "allDay-daily"
            case .weekly:
                let weekday = calendar.component(.weekday, from: ekEvent.startDate)
                return "allDay-weekly-\(weekday)"
            case .monthly:
                let day = calendar.component(.day, from: ekEvent.startDate)
                return "allDay-monthly-\(day)"
            case .yearly:
                let components = calendar.dateComponents([.month, .day], from: ekEvent.startDate)
                return "allDay-yearly-\(components.month ?? 0)-\(components.day ?? 0)"
            }
        }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: ekEvent.startDate)
        let hour = timeComponents.hour ?? 0
        let minute = timeComponents.minute ?? 0

        switch recurrence.freq {
        case .daily:
            return "timed-daily-\(hour)-\(minute)"
        case .weekly:
            let weekday = calendar.component(.weekday, from: ekEvent.startDate)
            return "timed-weekly-\(weekday)-\(hour)-\(minute)"
        case .monthly:
            let day = calendar.component(.day, from: ekEvent.startDate)
            return "timed-monthly-\(day)-\(hour)-\(minute)"
        case .yearly:
            let components = calendar.dateComponents([.month, .day], from: ekEvent.startDate)
            return "timed-yearly-\(components.month ?? 0)-\(components.day ?? 0)-\(hour)-\(minute)"
        }
    }

    private func recurrenceRules(for appEvent: CalendarEvent) -> [EKRecurrenceRule]? {
        guard let recurrence = effectiveRecurrence(for: appEvent) else { return nil }
        guard let frequency = ekFrequency(for: recurrence.freq) else { return nil }

        let end: EKRecurrenceEnd?
        switch recurrence.end?.kind {
        case .until:
            if let until = recurrence.end?.until {
                end = EKRecurrenceEnd(end: until)
            } else {
                end = nil
            }
        case .count:
            if let count = recurrence.end?.count {
                end = EKRecurrenceEnd(occurrenceCount: count)
            } else {
                end = nil
            }
        default:
            end = nil
        }

        let daysOfWeek: [EKRecurrenceDayOfWeek]?
        if recurrence.freq == .weekly, let byWeekday = recurrence.byWeekday, !byWeekday.isEmpty {
            daysOfWeek = byWeekday.compactMap { day in
                guard let weekday = ekWeekday(fromZeroBased: day) else { return nil }
                return EKRecurrenceDayOfWeek(weekday)
            }
        } else {
            daysOfWeek = nil
        }

        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(recurrence.interval, 1),
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )

        return [rule]
    }

    private func effectiveRecurrence(for appEvent: CalendarEvent) -> RecurrenceRule? {
        if let recurrence = appEvent.recurrence {
            return recurrence
        }

        guard let rrule = appEvent.recurrenceRRule else { return nil }
        return recurrence(fromRRule: rrule)
    }

    private func recurrence(fromRRule rrule: String) -> RecurrenceRule? {
        let raw = rrule
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !raw.isEmpty else { return nil }

        let body = raw.hasPrefix("RRULE:") ? String(raw.dropFirst(6)) : raw
        let parts = body.split(separator: ";")

        var values: [String: String] = [:]
        for part in parts {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            values[pair[0]] = pair[1]
        }

        guard let freqValue = values["FREQ"] else { return nil }

        let freq: RecurrenceFrequency
        switch freqValue {
        case "DAILY":
            freq = .daily
        case "WEEKLY":
            freq = .weekly
        case "MONTHLY":
            freq = .monthly
        case "YEARLY":
            freq = .yearly
        default:
            return nil
        }

        let interval = max(Int(values["INTERVAL"] ?? "1") ?? 1, 1)

        let byWeekday: [Int]?
        if let byDayString = values["BYDAY"], !byDayString.isEmpty {
            let parsedDays = byDayString
                .split(separator: ",")
                .compactMap { weekdayCode in
                    zeroBasedWeekday(fromRRuleToken: String(weekdayCode))
                }
            byWeekday = parsedDays.isEmpty ? nil : parsedDays
        } else {
            byWeekday = nil
        }

        let end: RecurrenceEnd?
        if let countString = values["COUNT"], let count = Int(countString), count > 0 {
            end = RecurrenceEnd(kind: .count, until: nil, count: count)
        } else if let untilString = values["UNTIL"], let until = date(fromRRuleUntil: untilString) {
            end = RecurrenceEnd(kind: .until, until: until, count: nil)
        } else {
            end = .never
        }

        return RecurrenceRule(
            freq: freq,
            interval: interval,
            byWeekday: byWeekday,
            end: end
        )
    }

    private func rruleString(from ekEvent: EKEvent) -> String? {
        guard let rule = ekEvent.recurrenceRules?.first else { return nil }

        var components: [String] = []

        switch rule.frequency {
        case .daily:
            components.append("FREQ=DAILY")
        case .weekly:
            components.append("FREQ=WEEKLY")
        case .monthly:
            components.append("FREQ=MONTHLY")
        case .yearly:
            components.append("FREQ=YEARLY")
        @unknown default:
            return nil
        }

        if rule.interval > 1 {
            components.append("INTERVAL=\(rule.interval)")
        }

        if let days = rule.daysOfTheWeek, !days.isEmpty {
            let mapped = days.compactMap { rruleWeekdayToken(from: $0.dayOfTheWeek.rawValue) }
            if !mapped.isEmpty {
                components.append("BYDAY=\(mapped.joined(separator: ","))")
            }
        }

        if let recurrenceEnd = rule.recurrenceEnd {
            if recurrenceEnd.occurrenceCount > 0 {
                components.append("COUNT=\(recurrenceEnd.occurrenceCount)")
            } else if let endDate = recurrenceEnd.endDate {
                components.append("UNTIL=\(rruleUntilString(from: endDate))")
            }
        }

        guard !components.isEmpty else { return nil }
        return "RRULE:" + components.joined(separator: ";")
    }

    private func date(fromRRuleUntil value: String) -> Date? {
        let utcFormatter = ISO8601DateFormatter()
        utcFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        if let date = utcFormatter.date(from: value) {
            return date
        }

        let basicUTCFormatter = DateFormatter()
        basicUTCFormatter.locale = Locale(identifier: "en_US_POSIX")
        basicUTCFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        basicUTCFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

        if let date = basicUTCFormatter.date(from: value) {
            return date
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyyMMdd"

        return dateOnlyFormatter.date(from: value)
    }

    private func rruleUntilString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private func zeroBasedWeekday(fromRRuleToken token: String) -> Int? {
        switch token.uppercased() {
        case "SU": return 0
        case "MO": return 1
        case "TU": return 2
        case "WE": return 3
        case "TH": return 4
        case "FR": return 5
        case "SA": return 6
        default: return nil
        }
    }

    private func rruleWeekdayToken(from weekday: Int) -> String? {
        switch weekday {
        case 1: return "SU"
        case 2: return "MO"
        case 3: return "TU"
        case 4: return "WE"
        case 5: return "TH"
        case 6: return "FR"
        case 7: return "SA"
        default: return nil
        }
    }

    private func recurrence(from ekEvent: EKEvent) -> RecurrenceRule? {
        guard let ekRule = ekEvent.recurrenceRules?.first else { return nil }

        let freq: RecurrenceFrequency
        switch ekRule.frequency {
        case .daily:
            freq = .daily
        case .weekly:
            freq = .weekly
        case .monthly:
            freq = .monthly
        case .yearly:
            freq = .yearly
        @unknown default:
            return nil
        }

        let byWeekday: [Int]?
        if freq == .weekly, let days = ekRule.daysOfTheWeek, !days.isEmpty {
            byWeekday = days.compactMap { zeroBasedWeekday(from: $0.dayOfTheWeek.rawValue) }
        } else {
            byWeekday = nil
        }

        let end: RecurrenceEnd?
        if let recurrenceEnd = ekRule.recurrenceEnd {
            if recurrenceEnd.occurrenceCount > 0 {
                end = RecurrenceEnd(kind: .count, until: nil, count: recurrenceEnd.occurrenceCount)
            } else if let endDate = recurrenceEnd.endDate {
                end = RecurrenceEnd(kind: .until, until: endDate, count: nil)
            } else {
                end = .never
            }
        } else {
            end = .never
        }

        return RecurrenceRule(
            freq: freq,
            interval: max(ekRule.interval, 1),
            byWeekday: byWeekday,
            end: end
        )
    }

    private func ekFrequency(for frequency: RecurrenceFrequency) -> EKRecurrenceFrequency? {
        switch frequency {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }

    private func ekWeekday(fromZeroBased day: Int) -> EKWeekday? {
        switch day {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return nil
        }
    }

    private func zeroBasedWeekday(from eventKitWeekday: Int) -> Int? {
        switch eventKitWeekday {
        case 1: return 0
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5
        case 7: return 6
        default: return nil
        }
    }

    var statusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not Connected"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Access Denied"
        case .writeOnly:
            return "Write-Only Access"
        case .fullAccess:
            return isSyncing ? "Syncing…" : "Connected"
        @unknown default:
            return "Unknown"
        }
    }
}
