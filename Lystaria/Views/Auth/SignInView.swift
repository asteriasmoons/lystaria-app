//
//  SignInView.swift
//  Lystaria
//

import SwiftUI
import SwiftData
import GoogleSignIn
import FirebaseCore

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var authUsers: [AuthUser]

    @State private var isSigningIn = false
    @State private var errorText: String?
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isEmailLoading = false

    var body: some View {
        ZStack {
            LystariaBackground()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)
                .padding(.horizontal, LSpacing.pageHorizontal)

                Spacer()

                GradientTitle(text: "Sign In", font: .system(size: 28, weight: .bold))

                Text("Log in to sync your data across devices.")
                    .font(.system(size: 14))
                    .foregroundStyle(LColors.textSecondary)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LSpacing.pageHorizontal)
                }

                Button {
                    signInWithGoogle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isSigningIn ? "Signing In..." : "Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSigningIn ? AnyShapeStyle(Color.gray.opacity(0.35)) : AnyShapeStyle(LGradients.blue))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .disabled(isSigningIn)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                    }

                    VStack(spacing: 10) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
#if os(iOS)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
#endif
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                        if isSignUp {
                            TextField("Display Name", text: $displayName)
                                .textContentType(.name)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }

                        Button {
                            Task { await submitEmailAuth() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                if isEmailLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account with Email" : "Sign In with Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                (email.isEmpty || password.isEmpty || isEmailLoading || isSigningIn)
                                ? AnyShapeStyle(Color.gray.opacity(0.35))
                                : AnyShapeStyle(LGradients.blue)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(email.isEmpty || password.isEmpty || isEmailLoading || isSigningIn)

                        Button {
                            isSignUp.toggle()
                            errorText = nil
                        } label: {
                            Text(isSignUp
                                 ? "Already have an account? Sign In"
                                 : "Don’t have an account? Sign Up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)

                Spacer()
            }
            .padding(.bottom, 30)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func signInWithGoogle() {
        errorText = nil
        isSigningIn = true

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isSigningIn = false
            errorText = "Firebase clientID not found. Make sure GoogleService-Info.plist is included in the target."
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        #if os(macOS)
        // macOS path: present with an NSWindow (add slight delay to ensure window is key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
            print("[GID macOS] Resolved window: \(String(describing: win))")
            guard let window = win else {
                isSigningIn = false
                errorText = "No active window to present Google Sign-In."
                print("[GID macOS] No active window found; aborting sign-in")
                return
            }

            print("[GID macOS] Calling signIn(withPresenting:) ...")
            GIDSignIn.sharedInstance.signIn(withPresenting: window) { (result: GIDSignInResult?, error: Error?) in
                print("[GID macOS] Completion called. result=\(result != nil), error=\(String(describing: error))")
                handleSignInResult(result: result, error: error)
            }
        }
        #else
        // iOS path: present with a UIViewController
        guard let presenter = topMostViewController() else {
            isSigningIn = false
            errorText = "Unable to find a presenter to start Google Sign-In."
            return
        }

        Task {
            do {
                let user = try await AuthService.shared.signInWithGoogle(presenting: presenter)

                let matchingExisting: AuthUser? = self.authUsers.first { candidate in
                    let matchesServerId = candidate.serverId == user.serverId
                    let matchesEmail = (user.email != nil) && (candidate.email == user.email)
                    return matchesServerId || matchesEmail
                }

                if let existing = matchingExisting {
                    existing.email = user.email
                    existing.displayName = user.displayName
                    existing.googleUserId = existing.googleUserId
                    existing.authProvider = .google
                    existing.serverId = user.serverId
                } else {
                    let newUser = AuthUser(
                        email: user.email,
                        displayName: user.displayName,
                        authProvider: .google,
                        appleUserId: nil,
                        googleUserId: nil,
                        serverId: user.serverId
                    )
                    self.modelContext.insert(newUser)
                }

                self.isSigningIn = false
                self.dismiss()
            } catch {
                self.isSigningIn = false
                self.errorText = error.localizedDescription
            }
        }
        #endif
    }

    private func submitEmailAuth() async {
        isEmailLoading = true
        errorText = nil

        do {
            let user: AuthUser
            if isSignUp {
                user = try await AuthService.shared.signUpWithEmail(
                    email: email,
                    password: password,
                    name: displayName.isEmpty ? nil : displayName
                )
            } else {
                user = try await AuthService.shared.loginWithEmail(email: email, password: password)
            }

            let matchingExisting: AuthUser? = self.authUsers.first { candidate in
                let matchesServerId = candidate.serverId == user.serverId
                let matchesEmail = (user.email != nil) && (candidate.email == user.email)
                return matchesServerId || matchesEmail
            }

            if let existing = matchingExisting {
                existing.email = user.email
                existing.displayName = user.displayName
                existing.authProvider = .email
                existing.serverId = user.serverId
            } else {
                let newUser = AuthUser(
                    email: user.email,
                    displayName: user.displayName,
                    authProvider: .email,
                    appleUserId: nil,
                    googleUserId: nil,
                    serverId: user.serverId
                )
                self.modelContext.insert(newUser)
            }

            appState.setSignedIn(user)
            isEmailLoading = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            isEmailLoading = false
        }
    }

    private func handleSignInResult(result: GIDSignInResult?, error: Error?) {
        DispatchQueue.main.async {
            self.isSigningIn = false

            if let error = error {
                self.errorText = error.localizedDescription
                return
            }

            guard let signInResult = result else {
                self.errorText = "Google sign-in returned no result."
                return
            }

            let googleUser = signInResult.user

            let email = googleUser.profile?.email
            let name = googleUser.profile?.name
            let googleId = googleUser.userID

            // Upsert local AuthUser
            let matchingExisting: AuthUser? = self.authUsers.first { candidate in
                let matchesGoogle = (googleId != nil) && (candidate.googleUserId == googleId)
                let matchesEmail = (email != nil) && (candidate.email == email)
                return matchesGoogle || matchesEmail
            }

            if let existing = matchingExisting {
                existing.email = email
                existing.displayName = name
                existing.googleUserId = googleId
                existing.authProvider = .google
            } else {
                let newUser = AuthUser(
                    email: email,
                    displayName: name,
                    authProvider: .google,
                    appleUserId: nil,
                    googleUserId: googleId,
                    serverId: nil
                )
                self.modelContext.insert(newUser)
            }

            print("✅ Google signed in:", email ?? "(no email)")
            self.dismiss()
        }
    }
}

#if os(iOS)
private func topMostViewController(from root: UIViewController? = nil) -> UIViewController? {
    let rootVC: UIViewController? = {
        if let root { return root }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }()
    if let nav = rootVC as? UINavigationController {
        return topMostViewController(from: nav.visibleViewController)
    }
    if let tab = rootVC as? UITabBarController {
        return topMostViewController(from: tab.selectedViewController)
    }
    if let presented = rootVC?.presentedViewController {
        return topMostViewController(from: presented)
    }
    return rootVC
}
#endif
