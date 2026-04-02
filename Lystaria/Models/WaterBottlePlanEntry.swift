//
//  WaterBottlePlanEntry.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class WaterBottlePlanEntry {
    var key: String = ""
    var date: Date = Date()

    var plannedBottles: Int = 0
    var extraBottles: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        key: String,
        date: Date = Date(),
        plannedBottles: Int = 0,
        extraBottles: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.date = date
        self.plannedBottles = max(0, plannedBottles)
        self.extraBottles = max(0, extraBottles)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touchUpdated() {
        updatedAt = Date()
    }

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}
