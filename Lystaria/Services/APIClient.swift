//
//  APIClient.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/26/26.
//

import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Request failed (\(statusCode)): \(message)"
            }
            return "Request failed (\(statusCode))."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// If your API returns a consistent error shape, this helps extract messages.
// Example: { "message": "Invalid credentials" }
private struct APIErrorPayload: Decodable {
    let message: String?
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()

    // Change this in one place if you ever move it.
    private let baseURL = URL(string: "http://localhost:5050/api/app")!

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()

        // Optional: configure date decoding if your API uses ISO-8601 strings.
        // jsonDecoder.dateDecodingStrategy = .iso8601
        // jsonEncoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Request API

    func send<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        accessToken: String? = nil,
        headers: [String: String] = [:],
        expecting: T.Type = T.self
    ) async throws -> T {
        let request = try makeRequest(
            method: method,
            path: path,
            query: query,
            body: body,
            accessToken: accessToken,
            headers: headers
        )

        do {
            let (data, response) = try await session.data(for: request)
            let http = try requireHTTPResponse(response)

            // 204 No Content: allow decoding to EmptyResponse if you want.
            if http.statusCode == 204, T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            guard (200...299).contains(http.statusCode) else {
                throw APIError.httpError(statusCode: http.statusCode, message: extractServerMessage(from: data))
            }

            do {
                return try jsonDecoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }

    // Convenience for endpoints that return no JSON body (204 or empty).
    func send(
        _ method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        accessToken: String? = nil,
        headers: [String: String] = [:]
    ) async throws {
        let request = try makeRequest(
            method: method,
            path: path,
            query: query,
            body: body,
            accessToken: accessToken,
            headers: headers
        )

        do {
            let (data, response) = try await session.data(for: request)
            let http = try requireHTTPResponse(response)

            guard (200...299).contains(http.statusCode) else {
                throw APIError.httpError(statusCode: http.statusCode, message: extractServerMessage(from: data))
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Request Construction

    private func makeRequest(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem],
        body: Encodable?,
        accessToken: String?,
        headers: [String: String]
    ) throws -> URLRequest {
        // Ensure leading slash behavior is consistent
        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        var components = URLComponents(url: baseURL.appendingPathComponent(cleanedPath), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.encodingError(error)
            }
        }

        return request
    }

    private func requireHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return http
    }

    private func extractServerMessage(from data: Data) -> String? {
        if let payload = try? jsonDecoder.decode(APIErrorPayload.self, from: data) {
            return payload.message
        }
        // If the API sometimes returns plain text errors, you can attempt:
        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }
        return nil
    }
}

// MARK: - Helpers

enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

// Useful for endpoints that intentionally return no JSON body.
struct EmptyResponse: Decodable {
    init() {}
}

// Wraps any Encodable so we can store it as "Encodable" and still encode it.
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeFunc = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
