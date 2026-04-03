//
//  BookRecommendationsService.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import Foundation

struct BookRecommendationRequest: Encodable {
    let genre: String
}

struct BookRecommendationItem: Decodable, Identifiable, Hashable {
    let title: String
    let author: String
    let summary: String

    var id: String {
        "\(title)|\(author)"
    }
}

struct BookRecommendationsResponse: Decodable {
    let recs: [BookRecommendationItem]?
    let error: String?
}

enum BookRecommendationsServiceError: LocalizedError {
    case invalidURL
    case emptyGenre
    case serverError(String)
    case invalidResponse
    case noRecommendationsFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The recommendations service URL is invalid."
        case .emptyGenre:
            return "Please enter a genre."
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "The server returned an invalid response."
        case .noRecommendationsFound:
            return "No recommendations were found for that genre."
        }
    }
}

final class BookRecommendationsService {
    static let shared = BookRecommendationsService()

    private init() {}

    // Replace with your deployed server URL later.
    private let baseURL = "https://lystaria-api.fly.dev"

    func generateRecommendations(genre: String) async throws -> [BookRecommendationItem] {
        let cleanGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanGenre.isEmpty else {
            throw BookRecommendationsServiceError.emptyGenre
        }

        guard let url = URL(string: "\(baseURL)/api/books/recs") else {
            throw BookRecommendationsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BookRecommendationRequest(genre: cleanGenre))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BookRecommendationsServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(BookRecommendationsResponse.self, from: data)

        if (200...299).contains(http.statusCode) {
            let recs = decoded.recs ?? []
            if recs.isEmpty {
                throw BookRecommendationsServiceError.noRecommendationsFound
            }
            return recs
        } else {
            throw BookRecommendationsServiceError.serverError(
                decoded.error ?? "Failed to fetch recommendations."
            )
        }
    }
}
