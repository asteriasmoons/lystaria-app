//
//  AppState.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/26/26.
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {

    enum SessionStatus {
        case checking
        case signedOut
        case signedIn(AuthUser)
    }

    @Published private(set) var status: SessionStatus = .checking

    private var bootstrapTask: Task<Void, Never>?
    private var hasBootstrapped = false

    func bootstrap(force: Bool = false) {
        if hasBootstrapped && !force { return }

        bootstrapTask?.cancel()
        status = .checking
        hasBootstrapped = true

        bootstrapTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                let user = try await AuthService.shared.fetchMeWithAutoRefresh()
                guard !Task.isCancelled else { return }
                self.status = .signedIn(user)
            } catch {
                guard !Task.isCancelled else { return }
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
        bootstrapTask?.cancel()
        AuthService.shared.signOutLocal()
        hasBootstrapped = true
        status = .signedOut
    }
}
