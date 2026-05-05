//
//  WellnessWallAIService.swift
//  Lystaria
//

import Foundation

final class WellnessWallAIService {
    static let shared = WellnessWallAIService()

    private init() {}

    func generateInsights(snapshot: WellnessWallAISnapshot) async throws -> WellnessWallAIResponse {
        let endpoint = "https://lystaria-api.fly.dev/api/wellness-wall"
        print("[WellnessWallAIService] Calling endpoint:", endpoint)

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(snapshot)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[WellnessWallAIService] Missing HTTP response")
            throw URLError(.badServerResponse)
        }

        print("[WellnessWallAIService] Status:", httpResponse.statusCode)

        if let responseString = String(data: data, encoding: .utf8) {
            print("[WellnessWallAIService] Raw response:", responseString)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        do {
            let decoded = try JSONDecoder().decode(WellnessWallAIResponse.self, from: data)
            print("[WellnessWallAIService] Decoded successfully")
            return decoded
        } catch {
            print("[WellnessWallAIService] Decoding failed:", error)
            throw error
        }
    }
}
