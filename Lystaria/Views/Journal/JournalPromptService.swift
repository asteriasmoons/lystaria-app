//
//  JournalPromptService.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import Foundation

struct JournalPromptResponse: Decodable {
    let prompt: String
    let remaining: Int
    let dateKey: String
}

final class JournalPromptService {

    static let shared = JournalPromptService()

    private init() {}

    func generatePrompt(userId: String) async throws -> JournalPromptResponse {

        guard let url = URL(string: "https://lystaria-api-production.up.railway.app/api/journal/prompt") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "PromptAPI", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: text
            ])
        }

        return try JSONDecoder().decode(JournalPromptResponse.self, from: data)
    }
}
