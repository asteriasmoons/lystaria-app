//
//  DailyReadingProgress.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class DailyReadingProgress {
    var userId: String = ""
    var date: Date = Date()
    var pagesRead: Int = 0
    var minutesRead: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        userId: String = "",
        date: Date = Date(),
        pagesRead: Int = 0,
        minutesRead: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.date = Calendar.current.startOfDay(for: date)
        self.pagesRead = max(pagesRead, 0)
        self.minutesRead = max(minutesRead, 0)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
