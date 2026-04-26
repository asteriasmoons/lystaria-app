//
//  SetDisplayNameSheet.swift
//  Lystaria
//

import SwiftUI
import SwiftData

struct SetDisplayNameSheet: View {
    let userId: String
    let isChanging: Bool // true = editing existing, false = first time setup
    var onClose: (() -> Void)?
    var onSaved: ((String) -> Void)?

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [AuthUser]

    @State private var nameText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var closeAction: () -> Void { onClose ?? {} }
    private var canSave: Bool {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30 && !isSaving
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { if isChanging { closeAction() } },
            width: 520,
            heightRatio: 0.48,
            header: {
                HStack {
                    GradientTitle(
                        text: isChanging ? "Change Display Name" : "Choose a Display Name",
                        font: .title2.bold()
                    )
                    Spacer()
                    if isChanging {
                        Button { closeAction() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            },
            content: {
                if !isChanging {
                    Text("This name will appear in the Sprint Room chat and on the leaderboard. You can change it later.")
                        .font(.subheadline)
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DISPLAY NAME")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaTextField(placeholder: "e.g. Asteria", text: $nameText)

                    HStack {
                        Spacer()
                        Text("\(nameText.count)/30")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(nameText.count > 30 ? Color.red : LColors.textSecondary)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await save() } } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(isChanging ? "Save" : "Let's Go")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canSave ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        )
        .onAppear {
            if isChanging, let existing = users.first(where: { $0.appleUserId == userId })?.displayName {
                nameText = existing
            }
        }
    }

    private func save() async {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return }
        isSaving = true
        errorMessage = nil

        // Save to backend
        do {
            try await UserProfileService.shared.setDisplayName(userId: userId, displayName: trimmed)
        } catch {
            errorMessage = "Failed to save. Please try again."
            isSaving = false
            return
        }

        // Save locally to SwiftData and update the live AppState user
        if let user = users.first(where: { $0.appleUserId == userId }) {
            user.displayName = trimmed
            try? modelContext.save()
        }
        appState.updateCurrentUserDisplayName(trimmed)

        isSaving = false
        onSaved?(trimmed)
    }
}
