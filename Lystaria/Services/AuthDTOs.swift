//
//  AuthDTOs.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/26/26.
//

import Foundation

// These names are prefixed with Auth* so they will NOT collide with anything else in your app.

struct AuthMeDTO: Codable {
    let id: String
    let email: String?
    let name: String?
}

struct AuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthMeDTO
}

struct AuthRefreshRequest: Codable {
    let refreshToken: String
}

struct AuthEmailLoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthEmailSignupRequest: Codable {
    let email: String
    let password: String
    let name: String?
}

struct AuthAppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
    let email: String?
}
