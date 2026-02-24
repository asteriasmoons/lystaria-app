// HabitLog.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB HabitLog schema

import Foundation
import SwiftData

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID

    /// The habit this log belongs to
    var habit: Habit?

    /// We store dayStart so “today” comparisons are reliable
    var dayStart: Date

    /// How many times the habit was logged on that day
    var count: Int

    var createdAt: Date
    var updatedAt: Date

    init(habit: Habit?, dayStart: Date, count: Int = 1) {
        self.id = UUID()
        self.habit = habit
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.count = max(0, count)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
