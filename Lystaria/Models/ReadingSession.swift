//
//  ReadingSession.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/20/26.
//

import Foundation
import SwiftData

@Model
final class ReadingSession {
    var startPage: Int? = nil
    var endPage: Int? = nil
    var minutesRead: Int = 0
    var sessionDate: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationship
    var book: Book? = nil

    var pagesRead: Int {
        guard let startPage, let endPage else { return 0 }
        return max(endPage - startPage, 0)
    }

    init(
        book: Book? = nil,
        startPage: Int? = nil,
        endPage: Int? = nil,
        minutesRead: Int = 0,
        sessionDate: Date = Date()
    ) {
        self.book = book
        self.startPage = startPage
        self.endPage = endPage
        self.minutesRead = max(minutesRead, 0)
        self.sessionDate = sessionDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
