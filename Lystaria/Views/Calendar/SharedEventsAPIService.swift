//
//  SharedEventsAPIService.swift
//  Lystaria
//

import Foundation

enum SharedEventsAPIError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case serverError(String)
    case decodingError
    case encodingError
    case httpError(Int, String)
    case missingData

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The shared events API base URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode the server response."
        case .encodingError:
            return "Failed to encode the request body."
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .missingData:
            return "The server response was missing expected data."
        }
    }
}

final class SharedEventsAPIService {
    static let shared = SharedEventsAPIService()

    private init() {}

    private let baseAPIURLString = "https://lystaria-api.fly.dev/api"

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
    }

    // MARK: - Public API

    func createSharedEvent(_ request: CreateSharedEventRequestDTO) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events",
            method: "POST",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func fetchSharedEventByJoinCode(
        joinCode: String,
        currentUserId: String? = nil
    ) async throws -> SharedEventResponseDTO {
        var queryItems: [URLQueryItem] = []
        if let currentUserId, !currentUserId.isEmpty {
            queryItems.append(URLQueryItem(name: "currentUserId", value: currentUserId))
        }

        return try await sendRequest(
            path: "/shared-events/join-code/\(joinCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? joinCode)",
            method: "GET",
            queryItems: queryItems.isEmpty ? nil : queryItems,
            responseType: SharedEventResponseDTO.self
        )
    }

    func joinSharedEventByCode(_ request: JoinSharedEventByCodeRequestDTO) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events/join-by-code",
            method: "POST",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func inviteAttendee(
        eventId: String,
        request: InviteSharedEventAttendeeRequestDTO
    ) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events/\(eventId)/invite",
            method: "POST",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func acceptInvite(
        eventId: String,
        request: AcceptSharedEventInviteRequestDTO
    ) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events/\(eventId)/accept",
            method: "POST",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func leaveSharedEvent(
        eventId: String,
        request: LeaveSharedEventRequestDTO
    ) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events/\(eventId)/leave",
            method: "POST",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func updateSharedEvent(
        eventId: String,
        request: UpdateSharedEventRequestDTO
    ) async throws -> SharedEventResponseDTO {
        try await sendRequest(
            path: "/shared-events/\(eventId)",
            method: "PATCH",
            body: request,
            responseType: SharedEventResponseDTO.self
        )
    }

    func fetchAttendees(eventId: String) async throws -> [SharedEventAttendeeDTO] {
        let response = try await sendRequest(
            path: "/shared-events/\(eventId)/attendees",
            method: "GET",
            responseType: SharedEventAttendeesResponseDTO.self
        )
        return response.attendees
    }

    // MARK: - Core Request Sender

    private func sendRequest<ResponseType: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        try await sendRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<String>.none,
            responseType: responseType
        )
    }

    private func sendRequest<RequestBody: Encodable, ResponseType: Decodable>(
        path: String,
        method: String,
        body: RequestBody,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        try await sendRequest(
            path: path,
            method: method,
            queryItems: nil,
            body: body,
            responseType: responseType
        )
    }

    private func sendRequest<RequestBody: Encodable, ResponseType: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: RequestBody?,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        guard var components = URLComponents(string: baseAPIURLString) else {
            throw SharedEventsAPIError.invalidBaseURL
        }

        let normalizedPath: String
        if path.hasPrefix("/") {
            normalizedPath = path
        } else {
            normalizedPath = "/" + path
        }

        if components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        components.path += normalizedPath

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw SharedEventsAPIError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            do {
                request.httpBody = try jsonEncoder.encode(body)
            } catch {
                throw SharedEventsAPIError.encodingError
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharedEventsAPIError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try jsonDecoder.decode(ResponseType.self, from: data)
            } catch {
                throw SharedEventsAPIError.decodingError
            }
        } else {
            if let decodedError = try? jsonDecoder.decode(SharedEventErrorResponseDTO.self, from: data),
               let message = decodedError.error,
               !message.isEmpty {
                throw SharedEventsAPIError.httpError(httpResponse.statusCode, message)
            }

            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                throw SharedEventsAPIError.httpError(httpResponse.statusCode, raw)
            }

            throw SharedEventsAPIError.httpError(httpResponse.statusCode, "Unknown server error")
        }
    }
}
