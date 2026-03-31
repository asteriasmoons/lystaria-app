//
// Book.swift
// Lystaria
//

import Foundation
import SwiftData

enum BookStatus: String, Codable, CaseIterable {
    case tbr = "tbr"
    case reading = "reading"
    case finished = "finished"
    case paused = "paused"
    case dnf = "dnf"

    var label: String {
        switch self {
        case .tbr: return "To Be Read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        case .paused: return "Paused"
        case .dnf: return "Did Not Finish"
        }
    }
}

@Model
final class Book {
    // MARK: - Local metadata
    var deletedAt: Date?

    // MARK: - Fields
    var title: String = ""
    var author: String = ""
    var shortSummary: String = ""
    var tagsRaw: String = ""
    var rating: Int = 0
    var statusRaw: String = BookStatus.tbr.rawValue
    var totalPages: Int?
    var currentPage: Int?
    var seriesIndex: Int? = nil
    var seriesLabel: String = ""
    var startedAt: Date? = nil
    var finishedAt: Date? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Optional for later if you want cover uploads
    var coverImageData: Data?

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession]? = nil

    @Relationship(deleteRule: .cascade, inverse: \BookNote.book)
    var notes: [BookNote]? = nil

    @Relationship(deleteRule: .nullify, inverse: \BookSeries.books)
    var series: BookSeries? = nil

    // MARK: - Computed
    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .tbr }
        set { statusRaw = newValue.rawValue }
    }

    var tags: [String] {
        tagsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var progressPercent: Double {
        guard let total = totalPages, total > 0,
              let current = currentPage else { return 0 }
        return min(Double(current) / Double(total), 1.0)
    }

    init(
        title: String,
        author: String = "",
        shortSummary: String = "",
        tagsRaw: String = "",
        rating: Int = 0,
        status: BookStatus = .tbr,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        seriesIndex: Int? = nil,
        seriesLabel: String = "",
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        deletedAt: Date? = nil,
        coverImageData: Data? = nil
    ) {
        self.title = title
        self.author = author
        self.shortSummary = shortSummary
        self.tagsRaw = tagsRaw
        self.rating = min(max(rating, 0), 5)
        self.statusRaw = status.rawValue
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.seriesIndex = seriesIndex
        self.seriesLabel = seriesLabel
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.deletedAt = deletedAt
        self.coverImageData = coverImageData
        self.sessions = nil
        self.notes = nil
        self.series = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
