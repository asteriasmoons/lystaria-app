//
//  AuthService.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/26/26.
//

import Foundation
import AuthenticationServices
import GoogleSignIn
import Supabase
import Auth
#if os(iOS)
import UIKit
#endif

final class AuthService {
    static let shared = AuthService()

    private let client = APIClient.shared

    // MARK: - Local sign out
    @MainActor
    func signOutLocal() {
        KeychainHelper.clearAll()
        GIDSignIn.sharedInstance.signOut()
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
        }
    }

    // MARK: - Email Auth

    func loginWithEmail(email: String, password: String) async throws -> AuthUser {
        let session = try await SupabaseManager.shared.client.auth.signIn(
            email: email,
            password: password
        )

        return AuthUser(
            email: session.user.email ?? email,
            displayName: nil,
            authProvider: .email,
            appleUserId: nil,
            serverId: session.user.id.uuidString
        )
    }

    func signUpWithEmail(email: String, password: String, name: String?) async throws -> AuthUser {
        let response = try await SupabaseManager.shared.client.auth.signUp(
            email: email,
            password: password
        )

        return AuthUser(
            email: response.user.email ?? email,
            displayName: name,
            authProvider: .email,
            appleUserId: nil,
            serverId: response.user.id.uuidString
        )
    }

    #if os(iOS)
    @MainActor
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AuthUser {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        return try await signInWithGoogleUser(result.user)
    }
    #endif

    private func signInWithGoogleUser(_ googleUser: GIDGoogleUser) async throws -> AuthUser {
        guard let idToken = googleUser.idToken?.tokenString else {
            throw APIError.httpError(statusCode: 400, message: "Missing Google ID token.")
        }

        let accessToken = googleUser.accessToken.tokenString

        let session = try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )

        return AuthUser(
            email: session.user.email ?? googleUser.profile?.email ?? "",
            displayName: googleUser.profile?.name,
            authProvider: .google,
            appleUserId: nil,
            serverId: session.user.id.uuidString
        )
    }

    // MARK: - Sign in with Apple (API exchange)

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthUser {
        guard
            let identityTokenData = credential.identityToken,
            let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw APIError.httpError(statusCode: 400, message: "Missing Apple identity token.")
        }

        guard
            let authCodeData = credential.authorizationCode,
            let authorizationCode = String(data: authCodeData, encoding: .utf8)
        else {
            throw APIError.httpError(statusCode: 400, message: "Missing Apple authorization code.")
        }

        let fullNameString: String? = {
            guard let fullName = credential.fullName else { return nil }
            let formatter = PersonNameComponentsFormatter()
            let s = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }()

        let response: AuthTokenResponse = try await client.send(
            .POST,
            path: "auth/apple",
            body: AuthAppleSignInRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullNameString,
                email: credential.email
            ),
            expecting: AuthTokenResponse.self
        )

        storeTokens(from: response)

        return AuthUser(
            email: response.user.email,
            displayName: response.user.name,
            authProvider: .apple,
            appleUserId: credential.user,       // <-- Apple stable user identifier
            serverId: response.user.id
        )
    }

    // MARK: - Session

    func fetchMeWithAutoRefresh() async throws -> AuthUser {
        // First try Supabase session
        if let session = try? await SupabaseManager.shared.client.auth.session {
            return AuthUser(
                email: session.user.email ?? "",
                displayName: nil,
                authProvider: .email,
                appleUserId: nil,
                serverId: session.user.id.uuidString
            )
        }

        // Then check if Google has a previously signed-in user and exchange it for a Supabase session
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return try await signInWithGoogleUser(user)
        }

        throw APIError.httpError(statusCode: 401, message: "No active session.")
    }

    private func fetchMe() async throws -> AuthUser {
        let session = try await SupabaseManager.shared.client.auth.session

        return AuthUser(
            email: session.user.email ?? "",
            displayName: nil,
            authProvider: .email,
            appleUserId: nil,
            serverId: session.user.id.uuidString
        )
    }

    private func refreshSession() async throws -> String {
        guard let refresh = KeychainHelper.read(.refreshToken) else {
            throw APIError.httpError(statusCode: 401, message: "No refresh token.")
        }

        let response: AuthTokenResponse = try await client.send(
            .POST,
            path: "auth/refresh",
            body: AuthRefreshRequest(refreshToken: refresh),
            expecting: AuthTokenResponse.self
        )

        storeTokens(from: response)
        return response.accessToken
    }

    // MARK: - Helpers

    private func storeTokens(from response: AuthTokenResponse) {
        _ = KeychainHelper.save(response.accessToken, for: .accessToken)
        _ = KeychainHelper.save(response.refreshToken, for: .refreshToken)
    }
}
