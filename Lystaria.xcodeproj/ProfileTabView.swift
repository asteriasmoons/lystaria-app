import SwiftUI
import SwiftData
import GoogleSignIn

struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var authUsers: [AuthUser]

    @State private var isSyncing = false
    @State private var errorText: String? = nil

    private var currentUser: AuthUser? { authUsers.first }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if let user = currentUser {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(LColors.accent)
                                    Text("Signed in with Google")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                }

                                if let name = user.displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    labeledRow(label: "Name", value: name)
                                }

                                labeledRow(label: "Email", value: user.email ?? "(none)")

                                if let gid = user.googleUserId { labeledRow(label: "Google ID", value: gid) }
                                if let aid = user.appleUserId { labeledRow(label: "Apple ID", value: aid) }

                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Not signed in")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Sign in from the main view to sync across devices.")
                                        .font(.subheadline)
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                    }

                    if let errorText { errorBanner(errorText) }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            HStack(spacing: 10) {
                                LButton(title: isSyncing ? "Syncing..." : "Sync Now", icon: "arrow.triangle.2.circlepath", style: .gradient) {
                                    triggerSync()
                                }
                                .disabled(isSyncing)

                                LButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", style: .danger) {
                                    signOut()
                                }
                                .disabled(currentUser == nil)
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.vertical, 20)
            }
        }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "Profile", font: .system(size: 28, weight: .bold))
            Spacer()
        }
        .padding(.top, 8)
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(LColors.textPrimary)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LColors.danger)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.danger)
                Spacer()
            }
        }
    }

    private func triggerSync() {
        // Placeholder for your future sync wiring.
        // Simulate a short sync to show UI state.
        errorText = nil
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSyncing = false
        }
    }

    private func signOut() {
        errorText = nil
        // Google Sign-Out (safe on all platforms)
        GIDSignIn.sharedInstance.signOut()

        // Optionally clear local user record(s). If you want to keep the user
        // row for history, remove this block.
        if let user = currentUser {
            modelContext.delete(user)
        }
    }
}

#Preview {
    ProfileTabView().preferredColorScheme(.dark)
}
