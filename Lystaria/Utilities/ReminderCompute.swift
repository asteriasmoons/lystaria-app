//
//  ReminderCompute.swift
//  Lystaria
//

import Foundation

enum ReminderCompute {
    static var tzCalendar: Calendar {
        var cal = Calendar.current
        #if os(iOS)
        let tzID = NotificationManager.shared.effectiveTimezoneID
        cal.timeZone = TimeZone(identifier: tzID) ?? .current
        #endif
        return cal
    }

    static func hourMinute(from date: Date) -> (Int, Int) {
        let cal = tzCalendar
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    static func parseHHMM(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let hh = Int(parts[0]),
              let mm = Int(parts[1]),
              (0 ... 23).contains(hh),
              (0 ... 59).contains(mm) else { return nil }
        return (hh, mm)
    }

    static func merge(day: Date, hour: Int, minute: Int) -> Date {
        var c = tzCalendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return tzCalendar.date(from: c) ?? day
    }

    static func merge(day: Date, hour: Int, minute: Int, in timeZone: TimeZone) -> Date {
        var cal = tzCalendar
        cal.timeZone = timeZone
        var c = cal.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return cal.date(from: c) ?? day
    }

    static func firstRun(
        kind: ReminderScheduleKind,
        startDay: Date,
        timesOfDay: [String],
        daysOfWeek: [Int]?,
        intervalMinutes: Int?,
        recurrenceInterval: Int?,
        dayOfMonth: Int?,
        anchorMonth: Int?,
        anchorDay: Int?,
        intervalWindowStart: String? = nil,
        intervalWindowEnd: String? = nil
    ) -> Date {
        let cal = tzCalendar
        let now = Date()

        if kind == .interval, let iv = intervalMinutes {
            let startBase = cal.date(bySetting: .second, value: 0, of: startDay) ?? startDay
            let candidate: Date
            if startBase >= now {
                candidate = startBase
            } else {
                let elapsed = now.timeIntervalSince(startBase)
                let intervalSeconds = TimeInterval(iv * 60)
                let stepCount = Int(ceil(elapsed / intervalSeconds))
                candidate = startBase.addingTimeInterval(TimeInterval(stepCount) * intervalSeconds)
            }

            if let ws = intervalWindowStart, let we = intervalWindowEnd,
               !ws.isEmpty, !we.isEmpty {
                return nextRunInterval(
                    after: candidate,
                    intervalMinutes: iv,
                    windowStart: ws,
                    windowEnd: we
                )
            }

            return candidate
        }

        let parsedTimes: [(h: Int, m: Int)] = timesOfDay
            .compactMap { parseHHMM($0) }
            .sorted { a, b in (a.0, a.1) < (b.0, b.1) }

        let times = parsedTimes.isEmpty ? [(hourMinute(from: now).0, hourMinute(from: now).1)] : parsedTimes

        let repeatEvery = max(1, recurrenceInterval ?? 1)
        let normalizedStart = cal.startOfDay(for: startDay)
        var day = normalizedStart
        var iterations = 0

        while true {
            iterations += 1
            if iterations > 365 {
                let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
                return merge(day: tomorrow, hour: times.first!.h, minute: times.first!.m)
            }

            if kind == .daily {
                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                if deltaDays % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if kind == .monthly {
                let wantedDay = min(dayOfMonth ?? cal.component(.day, from: normalizedStart), 31)
                let dayComponent = cal.component(.day, from: day)
                if dayComponent != wantedDay {
                    let year = cal.component(.year, from: day)
                    let month = cal.component(.month, from: day)
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = min(wantedDay, cal.range(of: .day, in: .month, for: day)?.count ?? wantedDay)
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let startMonthIndex = (cal.component(.year, from: normalizedStart) * 12) + cal.component(.month, from: normalizedStart)
                let currentMonthIndex = (cal.component(.year, from: day) * 12) + cal.component(.month, from: day)
                let monthDelta = currentMonthIndex - startMonthIndex
                if monthDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if kind == .yearly {
                let wantedMonth = anchorMonth ?? cal.component(.month, from: normalizedStart)
                let fallbackDay = anchorDay ?? cal.component(.day, from: normalizedStart)
                let maxDay = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: cal.component(.year, from: day), month: wantedMonth, day: 1)) ?? day)?.count ?? 31
                let wantedDay = min(fallbackDay, maxDay)

                let monthComponent = cal.component(.month, from: day)
                let dayComponent = cal.component(.day, from: day)
                if monthComponent != wantedMonth || dayComponent != wantedDay {
                    var comps = DateComponents()
                    comps.year = cal.component(.year, from: day)
                    comps.month = wantedMonth
                    comps.day = wantedDay
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let yearDelta = cal.component(.year, from: day) - cal.component(.year, from: normalizedStart)
                if yearDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if kind == .weekly, let days = daysOfWeek, !days.isEmpty {
                let wanted = Set(days)
                let weekdayIndex = cal.component(.weekday, from: day) - 1
                if !wanted.contains(weekdayIndex) {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            var best: Date? = nil
            for (hh, mm) in times {
                let candidate = merge(day: day, hour: hh, minute: mm)
                let secondsBehind = now.timeIntervalSince(candidate)
                if secondsBehind <= 90 {
                    if best == nil || candidate < best! { best = candidate }
                }
            }

            if let best { return best }

            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
    }

    static func nextRun(
        after now: Date,
        reminder: LystariaReminder,
        intervalWindowStart: String? = nil,
        intervalWindowEnd: String? = nil
    ) -> Date {
        guard let schedule = reminder.schedule else { return reminder.nextRunAt }
        let cal = tzCalendar

        if schedule.kind == .interval, let iv = schedule.intervalMinutes {
            let anchor = cal.date(bySetting: .second, value: 0, of: reminder.nextRunAt) ?? reminder.nextRunAt
            let stepped = cal.date(byAdding: .minute, value: iv, to: anchor) ?? anchor

            if let intervalWindowStart,
               let intervalWindowEnd,
               !intervalWindowStart.isEmpty,
               !intervalWindowEnd.isEmpty {
                return nextRunInterval(
                    after: stepped,
                    intervalMinutes: iv,
                    windowStart: intervalWindowStart,
                    windowEnd: intervalWindowEnd
                )
            }

            return stepped
        }

        let timeStrings = (schedule.timesOfDay?.isEmpty == false)
            ? (schedule.timesOfDay ?? [])
            : (schedule.timeOfDay != nil ? [schedule.timeOfDay!] : [])

        let parsedTimes: [(h: Int, m: Int)] = timeStrings
            .compactMap { parseHHMM($0) }
            .sorted { a, b in (a.0, a.1) < (b.0, b.1) }

        let times = parsedTimes.isEmpty
            ? [(hourMinute(from: reminder.nextRunAt).0, hourMinute(from: reminder.nextRunAt).1)]
            : parsedTimes

        let startSearchDay = cal.startOfDay(for: now)
        let repeatEvery = max(1, schedule.interval ?? 1)
        let normalizedStart = cal.startOfDay(for: reminder.nextRunAt)

        var day = startSearchDay
        var iterations = 0

        while true {
            iterations += 1
            if iterations > 1500 {
                let fallbackDay = cal.date(byAdding: .day, value: 1, to: startSearchDay) ?? startSearchDay
                let first = times.first!
                return merge(day: fallbackDay, hour: first.h, minute: first.m)
            }

            if schedule.kind == .daily {
                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                if deltaDays % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .weekly {
                let wanted = Set(schedule.daysOfWeek ?? [])
                if !wanted.isEmpty {
                    let weekdayIndex = cal.component(.weekday, from: day) - 1
                    if !wanted.contains(weekdayIndex) {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                        continue
                    }
                }

                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                let weekDelta = max(0, deltaDays / 7)
                if weekDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .monthly {
                let wantedDay = min(schedule.dayOfMonth ?? cal.component(.day, from: normalizedStart), 31)
                let dayComponent = cal.component(.day, from: day)
                if dayComponent != wantedDay {
                    let year = cal.component(.year, from: day)
                    let month = cal.component(.month, from: day)
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = min(wantedDay, cal.range(of: .day, in: .month, for: day)?.count ?? wantedDay)
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let startMonthIndex = (cal.component(.year, from: normalizedStart) * 12) + cal.component(.month, from: normalizedStart)
                let currentMonthIndex = (cal.component(.year, from: day) * 12) + cal.component(.month, from: day)
                let monthDelta = currentMonthIndex - startMonthIndex
                if monthDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .yearly {
                let wantedMonth = schedule.anchorMonth ?? cal.component(.month, from: normalizedStart)
                let fallbackDay = schedule.anchorDay ?? cal.component(.day, from: normalizedStart)
                let maxDay = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: cal.component(.year, from: day), month: wantedMonth, day: 1)) ?? day)?.count ?? 31
                let wantedDay = min(fallbackDay, maxDay)

                let monthComponent = cal.component(.month, from: day)
                let dayComponent = cal.component(.day, from: day)
                if monthComponent != wantedMonth || dayComponent != wantedDay {
                    var comps = DateComponents()
                    comps.year = cal.component(.year, from: day)
                    comps.month = wantedMonth
                    comps.day = wantedDay
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let yearDelta = cal.component(.year, from: day) - cal.component(.year, from: normalizedStart)
                if yearDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            for (hh, mm) in times {
                let candidate = merge(day: day, hour: hh, minute: mm)
                let secondsBehind = now.timeIntervalSince(candidate)
                if secondsBehind <= 90 {
                    return candidate
                }
            }

            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
    }

    static func nextRunInterval(
        after now: Date,
        intervalMinutes: Int,
        windowStart: String,
        windowEnd: String
    ) -> Date {
        let cal = tzCalendar
        let candidate = cal.date(bySetting: .second, value: 0, of: now) ?? now

        guard
            let (wsH, wsM) = parseHHMM(windowStart),
            let (weH, weM) = parseHHMM(windowEnd)
        else {
            return candidate
        }

        let dayStart = cal.startOfDay(for: candidate)
        let startDate = merge(day: dayStart, hour: wsH, minute: wsM)
        let endDate = merge(day: dayStart, hour: weH, minute: weM)

        if candidate >= startDate && candidate <= endDate {
            return candidate
        }

        if candidate < startDate {
            return startDate
        }

        let tomorrow = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return merge(day: tomorrow, hour: wsH, minute: wsM)
    }
}
