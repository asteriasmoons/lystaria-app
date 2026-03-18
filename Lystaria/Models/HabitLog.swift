// HabitLog.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB HabitLog schema

import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID = UUID()

    /// The habit this log belongs to
    var habit: Habit?

    /// We store dayStart so “today” comparisons are reliable
    var dayStart: Date = Date()

    /// How many times the habit was logged on that day
    var count: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(habit: Habit?, dayStart: Date, count: Int = 1) {
        self.id = UUID()
        self.habit = habit
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.count = max(0, count)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
