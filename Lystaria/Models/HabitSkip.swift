//
//  HabitSkip.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/20/26.
//

import Foundation
import SwiftData

@Model
final class HabitSkip {
    var id: UUID = UUID()

    /// The habit this skip belongs to
    var habit: Habit?

    /// We store dayStart so comparisons with logs are consistent
    var dayStart: Date = Date()

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(habit: Habit?, dayStart: Date) {
        self.id = UUID()
        self.habit = habit
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
