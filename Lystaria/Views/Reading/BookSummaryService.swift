//
//  BookSummaryService.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import Foundation

struct BookSummaryRequest: Encodable {
    let title: String
    let author: String?
}

struct BookSummaryResponse: Decodable {
    let source: String?
    let title: String?
    let author: String?
    let summary: String?
    let matchScore: Double?
    let error: String?
}

enum BookSummaryServiceError: LocalizedError {
    case invalidURL
    case emptyTitle
    case serverError(String)
    case invalidResponse
    case noSummaryFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The summary service URL is invalid."
        case .emptyTitle:
            return "Please enter a book title."
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "The server returned an invalid response."
        case .noSummaryFound:
            return "No summary was found for that book."
        }
    }
}

final class BookSummaryService {
    static let shared = BookSummaryService()

    private init() {}

    // Replace this with your deployed API URL when ready.
    // For simulator testing against your local machine, localhost works.
    // For a real device, localhost will NOT work.
    private let baseURL = "https://lystaria-api-production.up.railway.app"

    func generateSummary(title: String, author: String?) async throws -> BookSummaryResponse {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            throw BookSummaryServiceError.emptyTitle
        }

        guard let url = URL(string: "\(baseURL)/api/books/summary") else {
            throw BookSummaryServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = BookSummaryRequest(
            title: cleanTitle,
            author: (cleanAuthor?.isEmpty == true ? nil : cleanAuthor)
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BookSummaryServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(BookSummaryResponse.self, from: data)

        if (200...299).contains(http.statusCode) {
            if let summary = decoded.summary,
               !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return decoded
            } else {
                throw BookSummaryServiceError.noSummaryFound
            }
        } else {
            throw BookSummaryServiceError.serverError(
                decoded.error ?? "Failed to generate summary."
            )
        }
    }
}
