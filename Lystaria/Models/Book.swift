// Book.swift
// Lystaria
//
// SwiftData model — mirrors the MongoDB Book schema

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
    var rating: Int = 0             // 0–5
    var statusRaw: String = BookStatus.tbr.rawValue   // stored as raw string for SwiftData
    var totalPages: Int?
    var currentPage: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Computed
    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .tbr }
        set { statusRaw = newValue.rawValue }
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
        rating: Int = 0,
        status: BookStatus = .tbr,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.author = author
        self.shortSummary = shortSummary
        self.rating = min(max(rating, 0), 5)
        self.statusRaw = status.rawValue
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
