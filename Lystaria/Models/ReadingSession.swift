//
//  ReadingSession.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class ReadingSession {
    var startPage: Int? = nil
    var endPage: Int? = nil
    var minutesRead: Int = 0
    var pagesRead: Int = 0
    var isTimerSession: Bool = false
    var sessionDate: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationship
    var book: Book? = nil

    init(
        book: Book? = nil,
        startPage: Int? = nil,
        endPage: Int? = nil,
        minutesRead: Int = 0,
        pagesRead: Int = 0,
        sessionDate: Date = Date()
    ) {
        self.book = book
        self.startPage = startPage
        self.endPage = endPage
        self.minutesRead = max(minutesRead, 0)

        // If pagesRead is explicitly provided, use it.
        // Otherwise calculate it from start/end pages.
        if pagesRead > 0 {
            self.pagesRead = pagesRead
        } else if let startPage, let endPage {
            self.pagesRead = max(endPage - startPage, 0)
        } else {
            self.pagesRead = 0
        }

        self.sessionDate = sessionDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
