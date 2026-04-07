// ReadingPointsEntry.swift
// Lystaria

import Foundation
import SwiftData

@Model
final class ReadingPointsEntry {
    var userId: String = ""
    var bookId: String = ""
    var bookTitle: String = ""
    var minutesRead: Int = 0
    var pointsEarned: Int = 0
    var date: Date = Date()
    var createdAt: Date = Date()

    init(
        userId: String,
        bookId: String,
        bookTitle: String,
        minutesRead: Int,
        pointsEarned: Int,
        date: Date = Date()
    ) {
        self.userId = userId
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.minutesRead = minutesRead
        self.pointsEarned = pointsEarned
        self.date = date
        self.createdAt = Date()
    }
}
