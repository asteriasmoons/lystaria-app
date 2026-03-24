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

    private func isScopedToSelectedCalendar(
        _ appEvent: CalendarEvent,
        targetCalendar: EKCalendar
    ) -> Bool {
        // STRICT: if it's already linked, it MUST match
        if let linkedIdentifier = appEvent.appleCalendarIdentifier,
           !linkedIdentifier.isEmpty {
            return linkedIdentifier == targetCalendar.calendarIdentifier
        }

        // ONLY allow brand new events to export
        return appEvent.syncState == .newLocal
    }

    private func appEventFingerprint(_ appEvent: CalendarEvent) -> String {
        let title = appEvent.title
        let start = appEvent.startDate.ISO8601Format()
        let end = appEvent.endDate?.ISO8601Format() ?? "nil"
        let allDay = appEvent.allDay ? "1" : "0"
        let eventDescription = appEvent.eventDescription ?? ""
        let location = appEvent.location ?? ""
        let meetingUrl = appEvent.meetingUrl ?? ""
        let timeZoneId = appEvent.timeZoneId ?? ""
        let recurrenceRRule = appEvent.recurrenceRRule ?? ""
        let calendarId = appEvent.calendarId ?? ""
        let isRecurringSeriesMaster = appEvent.isRecurringSeriesMaster ? "1" : "0"
        let isRecurrenceException = appEvent.isRecurrenceException ? "1" : "0"
        let isCancelledOccurrence = appEvent.isCancelledOccurrence ? "1" : "0"
        let parentSeriesLocalId = appEvent.parentSeriesLocalId ?? ""
        let splitFromSeriesLocalId = appEvent.splitFromSeriesLocalId ?? ""
        let originalOccurrenceDate = appEvent.originalOccurrenceDate?.ISO8601Format() ?? "nil"
        let splitEffectiveFrom = appEvent.splitEffectiveFrom?.ISO8601Format() ?? "nil"
        let exceptionKindRaw = appEvent.exceptionKindRaw ?? ""

        let parts: [String] = [
            title,
            start,
            end,
            allDay,
            eventDescription,
            location,
            meetingUrl,
            timeZoneId,
            recurrenceRRule,
            calendarId,
            isRecurringSeriesMaster,
            isRecurrenceException,
            isCancelledOccurrence,
            parentSeriesLocalId,
            splitFromSeriesLocalId,
            originalOccurrenceDate,
            splitEffectiveFrom,
            exceptionKindRaw
        ]

        return parts.joined(separator: "|")
    }

    private func externalEventFingerprint(_ ekEvent: EKEvent, in targetCalendar: EKCalendar) -> String {
        [
            trimmedTitle(from: ekEvent.title),
            ekEvent.startDate.ISO8601Format(),
            (ekEvent.endDate ?? ekEvent.startDate).ISO8601Format(),
            ekEvent.isAllDay ? "1" : "0",
            ekEvent.notes ?? "",
            ekEvent.location ?? "",
            ekEvent.url?.absoluteString ?? "",
            ekEvent.timeZone?.identifier ?? "",
            rruleString(from: ekEvent) ?? "",
            targetCalendar.calendarIdentifier
        ].joined(separator: "|")
    }

    private func shouldTreatAsConflict(_ appEvent: CalendarEvent, externalHash: String) -> Bool {
        let hasLocalChanges = appEvent.syncState == .modifiedLocal || appEvent.syncState == .newLocal || appEvent.needsSync
        guard hasLocalChanges else { return false }

        guard let lastExternalHash = appEvent.lastExternalHash else {
            return false
        }

        return lastExternalHash != externalHash
    }

    private func isExceptionScopedToSelectedCalendar(
        _ exceptionEvent: CalendarEvent,
        appEventsByLocalId: [String: CalendarEvent],
        targetCalendar: EKCalendar
    ) -> Bool {
        if let linkedIdentifier = exceptionEvent.appleCalendarIdentifier,
           !linkedIdentifier.isEmpty {
            return linkedIdentifier == targetCalendar.calendarIdentifier
        }

        if let parentId = exceptionEvent.parentSeriesLocalId,
           let parent = appEventsByLocalId[parentId],
           let linkedIdentifier = parent.appleCalendarIdentifier,
           !linkedIdentifier.isEmpty {
            return linkedIdentifier == targetCalendar.calendarIdentifier
        }

        return exceptionEvent.syncState == .newLocal
        
    }

    private func applyAppEvent(_ appEvent: CalendarEvent, to ekEvent: EKEvent, in targetCalendar: EKCalendar) {
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
    }

    private func markAppEventSyncedAfterExport(
        _ appEvent: CalendarEvent,
        ekEvent: EKEvent,
        in targetCalendar: EKCalendar,
        syncedAt: Date
    ) {
        appEvent.appleCalendarItemIdentifier = ekEvent.calendarItemIdentifier
        appEvent.appleCalendarIdentifier = targetCalendar.calendarIdentifier
        appEvent.lastSyncedAt = syncedAt
        appEvent.externalLastModifiedAt = syncedAt
        appEvent.needsSync = false
        appEvent.syncState = .synced
        appEvent.lastExternalHash = externalEventFingerprint(ekEvent, in: targetCalendar)
        appEvent.lastSyncedHash = appEventFingerprint(appEvent)
        appEvent.updatedAt = syncedAt
    }

    private func markExceptionMarkerSyncedAfterExport(
        _ appEvent: CalendarEvent,
        in targetCalendar: EKCalendar,
        syncedAt: Date
    ) {
        appEvent.appleCalendarIdentifier = targetCalendar.calendarIdentifier
        appEvent.lastSyncedAt = syncedAt
        appEvent.externalLastModifiedAt = syncedAt
        appEvent.needsSync = false
        appEvent.syncState = .synced
        appEvent.lastExternalHash = nil
        appEvent.lastSyncedHash = appEventFingerprint(appEvent)
        appEvent.updatedAt = syncedAt
    }

    private func exportStandaloneAppEvent(
        _ appEvent: CalendarEvent,
        to targetCalendar: EKCalendar,
        syncedAt: Date
    ) throws -> Bool {
        let ekEvent: EKEvent

        if let identifier = appEvent.appleCalendarItemIdentifier,
           let existing = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent {
            ekEvent = existing
        } else {
            ekEvent = EKEvent(eventStore: eventStore)
        }

        applyAppEvent(appEvent, to: ekEvent, in: targetCalendar)
        try eventStore.save(ekEvent, span: .thisEvent, commit: false)
        markAppEventSyncedAfterExport(appEvent, ekEvent: ekEvent, in: targetCalendar, syncedAt: syncedAt)
        return true
    }


    private func occurrenceEvent(
        for parentEKEvent: EKEvent,
        on occurrenceDate: Date,
        in targetCalendar: EKCalendar
    ) -> EKEvent? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: occurrenceDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let predicate = eventStore.predicateForEvents(
            withStart: dayStart,
            end: dayEnd,
            calendars: [targetCalendar]
        )

        let candidates = eventStore.events(matching: predicate)

        if let exact = candidates.first(where: {
            $0.calendarItemIdentifier == parentEKEvent.calendarItemIdentifier &&
            abs($0.startDate.timeIntervalSince(occurrenceDate)) < 120
        }) {
            return exact
        }

        return candidates.first(where: {
            trimmedTitle(from: $0.title) == trimmedTitle(from: parentEKEvent.title) &&
            abs($0.startDate.timeIntervalSince(occurrenceDate)) < 120
        })
    }

    private func exportExceptionEvent(
        _ exceptionEvent: CalendarEvent,
        parentAppEvent: CalendarEvent?,
        to targetCalendar: EKCalendar,
        syncedAt: Date
    ) throws -> Bool {
        if exceptionEvent.exceptionKind == .split && !exceptionEvent.isCancelledOccurrence {
            return try exportStandaloneAppEvent(exceptionEvent, to: targetCalendar, syncedAt: syncedAt)
        }

        guard let parentAppEvent,
              let parentIdentifier = parentAppEvent.appleCalendarItemIdentifier,
              let parentEKEvent = eventStore.calendarItem(withIdentifier: parentIdentifier) as? EKEvent,
              let originalOccurrenceDate = exceptionEvent.originalOccurrenceDate,
              let occurrenceEKEvent = occurrenceEvent(for: parentEKEvent, on: originalOccurrenceDate, in: targetCalendar) else {
            return false
        }

        if exceptionEvent.isCancelledOccurrence {
            let span: EKSpan = (exceptionEvent.exceptionKind == .split) ? .futureEvents : .thisEvent
            try eventStore.remove(occurrenceEKEvent, span: span, commit: false)
            markExceptionMarkerSyncedAfterExport(exceptionEvent, in: targetCalendar, syncedAt: syncedAt)
            return true
        }

        applyAppEvent(exceptionEvent, to: occurrenceEKEvent, in: targetCalendar)
        try eventStore.save(occurrenceEKEvent, span: .thisEvent, commit: false)
        markAppEventSyncedAfterExport(exceptionEvent, ekEvent: occurrenceEKEvent, in: targetCalendar, syncedAt: syncedAt)
        return true
    }

    private func exportAppEvents(_ appEvents: [CalendarEvent], to targetCalendar: EKCalendar) throws -> Int {
        var exportedCount = 0
        let now = Date()
        let appEventsByLocalId = Dictionary(uniqueKeysWithValues: appEvents.map { ($0.localEventId, $0) })

        let pendingDeletes = appEvents.filter {
            $0.syncState == .pendingDeleteLocal &&
            $0.appleCalendarIdentifier == targetCalendar.calendarIdentifier
        }
        for appEvent in pendingDeletes {
            if let identifier = appEvent.appleCalendarItemIdentifier,
               let ekEvent = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent {
                try eventStore.remove(ekEvent, span: .futureEvents, commit: false)
            }
        }

        let exportable = appEvents.filter { appEvent in
            !appEvent.isRecurrenceException &&
            !appEvent.isCancelledOccurrence &&
            appEvent.syncState != .pendingDeleteLocal &&
            isScopedToSelectedCalendar(appEvent, targetCalendar: targetCalendar)
        }

        for appEvent in exportable {
            if try exportStandaloneAppEvent(appEvent, to: targetCalendar, syncedAt: now) {
                exportedCount += 1
            }
        }

        let exceptionEvents = appEvents.filter { exceptionEvent in
            exceptionEvent.isRecurrenceException &&
            exceptionEvent.syncState != .pendingDeleteLocal &&
            isExceptionScopedToSelectedCalendar(
                exceptionEvent,
                appEventsByLocalId: appEventsByLocalId,
                targetCalendar: targetCalendar
            )
        }

        for exceptionEvent in exceptionEvents {
            let parent = exceptionEvent.parentSeriesLocalId.flatMap { appEventsByLocalId[$0] }
            if try exportExceptionEvent(exceptionEvent, parentAppEvent: parent, to: targetCalendar, syncedAt: now) {
                exportedCount += 1
            }
        }

        if !pendingDeletes.isEmpty || exportedCount > 0 {
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
            newEvent.externalLastModifiedAt = now
            newEvent.needsSync = false
            newEvent.syncState = .synced
            newEvent.updatedAt = now
            // FIX 3: Mark imported recurring series masters correctly
            newEvent.isRecurringSeriesMaster = (ekEvent.recurrenceRules?.isEmpty == false)
            newEvent.lastExternalHash = externalEventFingerprint(ekEvent, in: targetCalendar)
            newEvent.lastSyncedHash = appEventFingerprint(newEvent)

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
        let externalHash = externalEventFingerprint(ekEvent, in: targetCalendar)

        if shouldTreatAsConflict(appEvent, externalHash: externalHash) {
            appEvent.syncState = .conflicted
            appEvent.externalLastModifiedAt = syncedAt
            return
        }

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
        appEvent.externalLastModifiedAt = syncedAt
        appEvent.needsSync = false
        appEvent.syncState = .synced
        appEvent.updatedAt = syncedAt
        appEvent.isRecurringSeriesMaster = (ekEvent.recurrenceRules?.isEmpty == false)
        appEvent.lastExternalHash = externalHash
        appEvent.lastSyncedHash = appEventFingerprint(appEvent)
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

        // FIX 4: Preserve monthly/yearly RRULE structure instead of dropping it
        let daysOfWeek: [EKRecurrenceDayOfWeek]?
        let daysOfTheMonth: [NSNumber]?
        let monthsOfTheYear: [NSNumber]?
        let setPositions: [NSNumber]?

        if let byWeekday = recurrence.byWeekday, !byWeekday.isEmpty {
            daysOfWeek = byWeekday.compactMap { day in
                guard let weekday = ekWeekday(fromZeroBased: day) else { return nil }
                return EKRecurrenceDayOfWeek(weekday)
            }
        } else {
            daysOfWeek = nil
        }

        // Pull richer structure from the RRULE string if available
        if let rrule = appEvent.recurrenceRRule, let parsed = ParsedRRule.parse(rrule) {
            daysOfTheMonth = parsed.byMonthDay.map { $0.map { NSNumber(value: $0) } }
            monthsOfTheYear = parsed.byMonth.map { $0.map { NSNumber(value: $0) } }
            setPositions = parsed.bySetPos.map { [NSNumber(value: $0)] }
        } else {
            daysOfTheMonth = nil
            monthsOfTheYear = nil
            setPositions = nil
        }

        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(recurrence.interval, 1),
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfTheMonth,
            monthsOfTheYear: monthsOfTheYear,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: setPositions,
            end: end
        )

        return [rule]
    }

    private func effectiveRecurrence(for appEvent: CalendarEvent) -> RecurrenceRule? {
        if let rrule = appEvent.recurrenceRRule,
           let parsed = recurrence(fromRRule: rrule) {
            return parsed
        }

        return appEvent.recurrence
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
                .compactMap { weekdayCode -> Int? in
                    let token = String(weekdayCode).suffix(2)
                    return zeroBasedWeekday(fromRRuleToken: String(token))
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
            let mapped = days.compactMap { day -> String? in
                guard let token = rruleWeekdayToken(from: day.dayOfTheWeek.rawValue) else { return nil }
                if day.weekNumber != 0 {
                    return "\(day.weekNumber)\(token)"
                }
                return token
            }
            if !mapped.isEmpty {
                components.append("BYDAY=\(mapped.joined(separator: ","))")
            }
        }

        if let daysOfTheMonth = rule.daysOfTheMonth, !daysOfTheMonth.isEmpty {
            let mapped = daysOfTheMonth.map { String($0.intValue) }
            components.append("BYMONTHDAY=\(mapped.joined(separator: ","))")
        }

        if let monthsOfTheYear = rule.monthsOfTheYear, !monthsOfTheYear.isEmpty {
            let mapped = monthsOfTheYear.map { String($0.intValue) }
            components.append("BYMONTH=\(mapped.joined(separator: ","))")
        }

        if let setPositions = rule.setPositions, !setPositions.isEmpty {
            let mapped = setPositions.map { String($0.intValue) }
            components.append("BYSETPOS=\(mapped.joined(separator: ","))")
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
