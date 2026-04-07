//
//  AppState.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/26/26.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class AppState: ObservableObject {
    
    enum SessionStatus {
        case checking
        case signedOut
        case signedIn(AuthUser)
    }
    
    @Published private(set) var status: SessionStatus = .checking
    @Published var isPopupPresented: Bool = false
    
    var currentUser: AuthUser? {
        if case .signedIn(let user) = status {
            return user
        }
        return nil
    }

    var currentAppleUserId: String? {
        currentUser?.appleUserId
    }
    
    private var bootstrapTask: Task<Void, Never>?
    private var hasBootstrapped = false
    
    func bootstrap(modelContext: ModelContext, force: Bool = false) {
        if hasBootstrapped && !force { return }

        bootstrapTask?.cancel()
        status = .checking
        hasBootstrapped = true

        bootstrapTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                try await AuthService.shared.validateStoredAppleSession()
                let user = try await AuthService.shared.fetchMeWithAutoRefresh(modelContext: modelContext)
                guard !Task.isCancelled else { return }
                self.status = .signedIn(user)
            } catch {
                guard !Task.isCancelled else { return }
                print("[AppState] bootstrap failed:", error)
                self.status = .signedOut
            }
        }
    }

    func setSignedIn(_ user: AuthUser) {
        bootstrapTask?.cancel()
        hasBootstrapped = true
        status = .signedIn(user)
    }

    func signOut() {
        print("[AppState] signOut() called")
        bootstrapTask?.cancel()
        AuthService.shared.signOutLocal()
        hasBootstrapped = true
        status = .signedOut
        print("[AppState] status is now .signedOut")
    }
}
