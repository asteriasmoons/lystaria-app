//
//  AuthManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/6/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var session: Session?

    private init() {}

    func signUp(email: String, password: String) async throws {
        let response = try await SupabaseManager.shared.client.auth.signUp(
            email: email,
            password: password
        )
        session = response.session
    }

    func signIn(email: String, password: String) async throws {
        let sessionResponse = try await SupabaseManager.shared.client.auth.signIn(
            email: email,
            password: password
        )
        session = sessionResponse
    }

    func signOut() async throws {
        try await SupabaseManager.shared.client.auth.signOut()
        session = nil
    }

    func loadSession() async {
        do {
            session = try await SupabaseManager.shared.client.auth.session
        } catch {
            session = nil
        }
    }
}
