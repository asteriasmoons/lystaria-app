//
//  JournalPromptService.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import Foundation
import SwiftData

struct JournalPromptResponse: Decodable {
    let prompt: String
    let remaining: Int
    let dateKey: String
}

private struct GroqChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
}

private struct GroqChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

final class JournalPromptService {

    static let shared = JournalPromptService()

    private init() {}

    func generatePrompt(userId: String, modelContext: ModelContext) async throws -> JournalPromptResponse {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "JournalPromptService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing GROQ_API_KEY in Info.plist or build configuration."]
            )
        }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let todayDateKey = formatter.string(from: Date())

        let descriptor = FetchDescriptor<JournalPromptUsage>(
            predicate: #Predicate { usage in
                usage.userId == userId && usage.dateKey == todayDateKey
            }
        )

        let usageRecord: JournalPromptUsage
        if let existing = try modelContext.fetch(descriptor).first {
            usageRecord = existing
        } else {
            let newRecord = JournalPromptUsage(userId: userId, dateKey: todayDateKey)
            modelContext.insert(newRecord)
            usageRecord = newRecord
        }

        guard usageRecord.usedCount < 3 else {
            throw NSError(
                domain: "JournalPromptService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "You’ve already used your 3 journal prompts for today."]
            )
        }

        let systemPrompt = "You create one emotionally intelligent, thoughtful journal prompt at a time. Return only the prompt text itself. Do not add numbering, quotation marks, titles, or extra commentary. The prompt should feel reflective, warm, and clear."

        let userPrompt = "Generate one original journal prompt for a personal journaling app user. Make it introspective, emotionally meaningful, and suitable for general self-reflection."

        let payload = GroqChatRequest(
            model: "llama-3.3-70b-versatile",
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.9,
            max_tokens: 120
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalPromptService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let decoded = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        let prompt = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let prompt, !prompt.isEmpty else {
            throw NSError(
                domain: "JournalPromptService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Groq returned an empty prompt."]
            )
        }

        usageRecord.usedCount += 1
        usageRecord.updatedAt = Date()
        try modelContext.save()

        return JournalPromptResponse(
            prompt: prompt,
            remaining: max(0, 3 - usageRecord.usedCount),
            dateKey: todayDateKey
        )
    }
}
