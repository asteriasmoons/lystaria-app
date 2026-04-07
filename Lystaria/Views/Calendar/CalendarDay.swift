//
//  CalendarDay.swift
//  Lystaria
//
//  Adds CalendarCompute.reminderDate — the only thing CalendarDayView needs
//  that isn't already defined in CalendarTabView.swift.
//
//  NOTE: ParsedRRule, CalendarEventResolver, CalendarCompute and all shared
//  calendar types live in CalendarTabView.swift. Do NOT redefine them here.
//

import Foundation

// MARK: - CalendarCompute + reminderDate

extension CalendarCompute {
    /// Returns the date at which a reminder should fire given an event start
    /// time and a number of minutes before the event.
    static func reminderDate(from eventStart: Date, minutesBefore: Int) -> Date {
        eventStart.addingTimeInterval(-TimeInterval(minutesBefore) * 60)
    }
}
