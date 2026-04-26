//
//  CalendarEventResolver.swift
//  Lystaria
//

import Foundation
import SwiftUI

// =======================================================
// MARK: - CalendarCompute
// =======================================================

enum CalendarCompute {
    static var displayTimeZone: TimeZone {
        #if os(iOS)
        return TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
        #else
        return .current
        #endif
    }

    static var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    static func merge(day: Date, time: Date) -> Date {
        let cal = tzCalendar
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute; c.second = 0
        return cal.date(from: c) ?? day
    }

    static func setTimeKeepingDay(day: Date, hour: Int, minute: Int) -> Date {
        var c = tzCalendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour; c.minute = minute; c.second = 0
        return tzCalendar.date(from: c) ?? day
    }

    static func reminderDate(from eventStart: Date, minutesBefore: Int) -> Date {
        eventStart.addingTimeInterval(-TimeInterval(minutesBefore) * 60)
    }
}

// =======================================================
// MARK: - ParsedRRule
// =======================================================

struct ParsedRRule {
    enum Freq: String {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    let freq: Freq
    let interval: Int
    let byDay: [String]?
    let byMonthDay: [Int]?
    let byMonth: [Int]?
    let bySetPos: Int?
    let count: Int?
    let until: Date?

    static func parse(_ rrule: String) -> ParsedRRule? {
        let raw = rrule.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = raw.hasPrefix("RRULE:") ? String(raw.dropFirst("RRULE:".count)) : raw
        let parts = body.split(separator: ";").map { String($0) }

        var freq: Freq?
        var interval: Int = 1
        var byDay: [String]? = nil
        var byMonthDay: [Int]? = nil
        var byMonth: [Int]? = nil
        var bySetPos: Int? = nil
        var count: Int? = nil
        var until: Date? = nil

        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1).map { String($0) }
            guard kv.count == 2 else { continue }
            let key = kv[0].uppercased()
            let val = kv[1]

            switch key {
            case "FREQ":      freq = Freq(rawValue: val.uppercased())
            case "INTERVAL":  interval = max(1, Int(val) ?? 1)
            case "BYDAY":
                let days = val.split(separator: ",").map { String($0).uppercased() }
                byDay = days.isEmpty ? nil : days
            case "BYMONTHDAY":
                let days = val.split(separator: ",").compactMap { Int($0) }
                byMonthDay = days.isEmpty ? nil : days
            case "BYMONTH":
                let months = val.split(separator: ",").compactMap { Int($0) }
                byMonth = months.isEmpty ? nil : months
            case "BYSETPOS": bySetPos = Int(val)
            case "COUNT":    count = Int(val)
            case "UNTIL":    until = Self.parseUntil(val)
            default:         continue
            }
        }

        guard let f = freq else { return nil }
        return ParsedRRule(freq: f, interval: interval, byDay: byDay, byMonthDay: byMonthDay,
                           byMonth: byMonth, bySetPos: bySetPos, count: count, until: until)
    }

    private static func parseUntil(_ val: String) -> Date? {
        let v = val.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.count == 8 {
            let y = Int(v.prefix(4))
            let m = Int(v.dropFirst(4).prefix(2))
            let d = Int(v.dropFirst(6).prefix(2))
            if let y, let m, let d {
                var comps = DateComponents()
                comps.year = y; comps.month = m; comps.day = d
                comps.hour = 23; comps.minute = 59; comps.second = 59
                return CalendarCompute.tzCalendar.date(from: comps)
            }
        }
        let dfZ: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return df
        }()
        if let d = dfZ.date(from: v) { return d }
        let dfLocal: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = CalendarCompute.displayTimeZone
            df.dateFormat = "yyyyMMdd'T'HHmmss"
            return df
        }()
        return dfLocal.date(from: v)
    }
}

// =======================================================
// MARK: - weekdayCode helper
// =======================================================

func weekdayCode(from weekday: Int) -> String {
    switch weekday {
    case 1: return "SU"
    case 2: return "MO"
    case 3: return "TU"
    case 4: return "WE"
    case 5: return "TH"
    case 6: return "FR"
    case 7: return "SA"
    default: return "MO"
    }
}

// =======================================================
// MARK: - ResolvedCalendarOccurrence
// =======================================================

struct ResolvedCalendarOccurrence: Identifiable, Hashable {
    let id: String
    let sourceEventId: String
    let originalOccurrenceDate: Date?
    let startDate: Date
    let endDate: Date?
    let allDay: Bool
    let title: String
    let color: String?
    let eventDescription: String?
    let location: String?
    let meetingUrl: String?
    let calendarId: String?
    let isException: Bool
    let isCancelled: Bool
}

// =======================================================
// MARK: - CalendarEventResolver
// =======================================================

enum CalendarEventResolver {
    static func occurrences(on day: Date, from events: [CalendarEvent], timeZone: TimeZone? = nil) -> [ResolvedCalendarOccurrence] {
        let tz = timeZone ?? CalendarCompute.displayTimeZone
        var cal = Calendar.current
        cal.timeZone = tz

        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let isSplitSeries: (CalendarEvent) -> Bool = { e in
            e.isRecurrenceException && e.exceptionKind == .split && !e.isCancelledOccurrence
        }

        let masters = events.filter { !$0.isRecurrenceException || isSplitSeries($0) }
        let exceptions = events.filter { $0.isRecurrenceException && !isSplitSeries($0) }
        let exceptionsByParent = Dictionary(grouping: exceptions) { $0.parentSeriesLocalId ?? "" }

        var resolved: [ResolvedCalendarOccurrence] = []

        for master in masters {
            let masterExceptions = exceptionsByParent[master.localEventId] ?? []

            if master.recurrenceRRule == nil {
                if occursInRange(start: master.startDate, end: master.endDate, dayStart: dayStart, dayEnd: dayEnd, calendar: cal) {
                    resolved.append(makeOccurrence(from: master, startDate: master.startDate, endDate: master.endDate,
                                                   originalOccurrenceDate: nil, isException: false, isCancelled: false))
                }
                continue
            }

            guard let rrule = master.recurrenceRRule,
                  let parsed = ParsedRRule.parse(rrule) else { continue }

            if hasSplitBlocking(masterExceptions: masterExceptions, on: dayStart, calendar: cal) { continue }
            guard recurringMaster(master, occursOn: dayStart, parsed: parsed, calendar: cal) else { continue }

            let occurrenceStart = occurrenceDate(for: dayStart, matching: master.startDate, calendar: cal, allDay: master.allDay)
            let occurrenceEnd: Date? = {
                guard let end = master.endDate else { return nil }
                return occurrenceStart.addingTimeInterval(end.timeIntervalSince(master.startDate))
            }()

            let matchingExceptions = masterExceptions.filter {
                guard let original = $0.originalOccurrenceDate else { return false }
                return cal.isDate(original, inSameDayAs: dayStart)
            }

            if let cancelled = matchingExceptions.first(where: { $0.isCancelledOccurrence }) {
                resolved.append(makeOccurrence(from: cancelled, startDate: occurrenceStart, endDate: occurrenceEnd,
                                               originalOccurrenceDate: cancelled.originalOccurrenceDate, isException: true, isCancelled: true))
                continue
            }

            if let replacement = matchingExceptions.first(where: { !$0.isCancelledOccurrence }) {
                if occursInRange(start: replacement.startDate, end: replacement.endDate, dayStart: dayStart, dayEnd: dayEnd, calendar: cal) {
                    resolved.append(makeOccurrence(from: replacement, startDate: replacement.startDate, endDate: replacement.endDate,
                                                   originalOccurrenceDate: replacement.originalOccurrenceDate, isException: true, isCancelled: false))
                }
                continue
            }

            resolved.append(makeOccurrence(from: master, startDate: occurrenceStart, endDate: occurrenceEnd,
                                           originalOccurrenceDate: occurrenceStart, isException: false, isCancelled: false))
        }

        return resolved
            .filter { !$0.isCancelled }
            .sorted { lhs, rhs in
                lhs.startDate == rhs.startDate
                    ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                    : lhs.startDate < rhs.startDate
            }
    }

    private static func makeOccurrence(from event: CalendarEvent, startDate: Date, endDate: Date?,
                                       originalOccurrenceDate: Date?, isException: Bool, isCancelled: Bool) -> ResolvedCalendarOccurrence {
        let originalKey: String = {
            guard let d = originalOccurrenceDate else { return "base" }
            return ISO8601DateFormatter().string(from: d)
        }()
        return ResolvedCalendarOccurrence(
            id: "\(event.localEventId)|\(originalKey)|\(isException ? "exception" : "base")",
            sourceEventId: event.localEventId,
            originalOccurrenceDate: originalOccurrenceDate,
            startDate: startDate, endDate: endDate, allDay: event.allDay,
            title: event.title, color: event.color, eventDescription: event.eventDescription,
            location: event.location, meetingUrl: event.meetingUrl, calendarId: event.calendarId,
            isException: isException, isCancelled: isCancelled
        )
    }

    private static func occursInRange(start: Date, end: Date?, dayStart: Date, dayEnd: Date, calendar: Calendar) -> Bool {
        if calendar.isDate(start, inSameDayAs: dayStart) { return true }
        if let end { return start < dayEnd && end > dayStart }
        return false
    }

    private static func hasSplitBlocking(masterExceptions: [CalendarEvent], on day: Date, calendar: Calendar) -> Bool {
        masterExceptions.contains { exception in
            guard exception.exceptionKind == .split,
                  exception.isCancelledOccurrence,
                  let splitFrom = exception.splitEffectiveFrom ?? exception.originalOccurrenceDate else { return false }
            return day >= calendar.startOfDay(for: splitFrom)
        }
    }

    private static func occurrenceDate(for occurrenceDay: Date, matching sourceStart: Date, calendar: Calendar, allDay: Bool) -> Date {
        if allDay { return calendar.startOfDay(for: occurrenceDay) }
        let time = calendar.dateComponents([.hour, .minute, .second], from: sourceStart)
        var day = calendar.dateComponents([.year, .month, .day], from: occurrenceDay)
        day.hour = time.hour; day.minute = time.minute; day.second = time.second
        return calendar.date(from: day) ?? occurrenceDay
    }

    private static func recurringMaster(_ event: CalendarEvent, occursOn day: Date, parsed: ParsedRRule, calendar: Calendar) -> Bool {
        let seriesStartDay = calendar.startOfDay(for: event.startDate)
        let targetDay = calendar.startOfDay(for: day)

        if targetDay < seriesStartDay { return false }
        if let until = parsed.until, targetDay > calendar.startOfDay(for: until) { return false }

        let dayOffset = calendar.dateComponents([.day], from: seriesStartDay, to: targetDay).day ?? 0
        let interval = max(1, parsed.interval)

        switch parsed.freq {
        case .daily:
            return dayOffset % interval == 0

        case .weekly:
            let weekOffset = dayOffset / 7
            guard weekOffset % interval == 0 else { return false }
            let weekdayCodeForTarget = weekdayCode(from: calendar.component(.weekday, from: targetDay))
            let byDay = parsed.byDay ?? [weekdayCode(from: calendar.component(.weekday, from: event.startDate))]
            return byDay.contains(weekdayCodeForTarget)

        case .monthly:
            let monthDelta = monthsBetween(seriesStartDay, targetDay, calendar: calendar)
            guard monthDelta >= 0, monthDelta % interval == 0 else { return false }
            if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                return byMonthDay.contains(calendar.component(.day, from: targetDay))
            }
            if let byDay = parsed.byDay?.first, let bySetPos = parsed.bySetPos {
                return matchesNthWeekday(targetDay, weekdayCode: byDay, setPos: bySetPos, calendar: calendar)
            }
            return calendar.component(.day, from: targetDay) == calendar.component(.day, from: event.startDate)

        case .yearly:
            let yearDelta = calendar.component(.year, from: targetDay) - calendar.component(.year, from: seriesStartDay)
            guard yearDelta >= 0, yearDelta % interval == 0 else { return false }
            let targetMonth = calendar.component(.month, from: targetDay)
            let fallbackMonth = calendar.component(.month, from: event.startDate)
            let allowedMonths = (parsed.byMonth?.isEmpty == false) ? parsed.byMonth! : [fallbackMonth]
            guard allowedMonths.contains(targetMonth) else { return false }
            if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                return byMonthDay.contains(calendar.component(.day, from: targetDay))
            }
            if let byDay = parsed.byDay?.first, let bySetPos = parsed.bySetPos {
                return matchesNthWeekday(targetDay, weekdayCode: byDay, setPos: bySetPos, calendar: calendar)
            }
            return targetMonth == fallbackMonth
                && calendar.component(.day, from: targetDay) == calendar.component(.day, from: event.startDate)
        }
    }

    private static func monthsBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        let s = calendar.dateComponents([.year, .month], from: start)
        let e = calendar.dateComponents([.year, .month], from: end)
        return ((e.year ?? 0) - (s.year ?? 0)) * 12 + ((e.month ?? 1) - (s.month ?? 1))
    }

    private static func matchesNthWeekday(_ date: Date, weekdayCode: String, setPos: Int, calendar: Calendar) -> Bool {
        let weekdayMap: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
        guard let targetWeekday = weekdayMap[weekdayCode.uppercased()],
              calendar.component(.weekday, from: date) == targetWeekday else { return false }
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return false }
        var matches: [Date] = []
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            if calendar.component(.weekday, from: cursor) == targetWeekday,
               calendar.isDate(cursor, equalTo: date, toGranularity: .month) {
                matches.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? monthInterval.end
        }
        guard !matches.isEmpty else { return false }
        let index = setPos > 0 ? setPos - 1 : matches.count + setPos
        return matches.indices.contains(index) && calendar.isDate(matches[index], inSameDayAs: date)
    }
}
