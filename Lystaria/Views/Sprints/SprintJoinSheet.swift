//
//  SprintJoinSheet.swift
//  Lystaria
//

import SwiftUI

struct SprintJoinSheet: View {
    let sprint: Sprint
    let userId: String
    let displayName: String
    var onClose: (() -> Void)?
    var onJoined: ((Sprint) -> Void)?

    @State private var startPageText: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String? = nil

    private var closeAction: () -> Void { onClose ?? {} }
    private var canJoin: Bool { !startPageText.isEmpty && !isJoining }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 520,
            heightRatio: 0.48,
            header: {
                HStack {
                    GradientTitle(text: "Join Sprint", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(LColors.accent)
                    Text("\(sprint.durationMinutes) minute sprint · \(sprint.participants.count) participant\(sprint.participants.count == 1 ? "" : "s") joined")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR START PAGE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaNumberField(placeholder: "What page are you on?", text: $startPageText)
                        .numericKeyboardIfAvailable()
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await join() } } label: {
                    Group {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join Sprint")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canJoin ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canJoin ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canJoin)
            }
        )
    }

    private func join() async {
        guard canJoin, let page = Int(startPageText) else { return }
        isJoining = true
        errorMessage = nil

        let body = JoinSprintBody(userId: userId, displayName: displayName, startPage: page)

        do {
            let updated = try await SprintService.shared.joinSprint(sprintId: sprint.id, body: body)
            onJoined?(updated)
        } catch {
            errorMessage = "Failed to join. The sprint may have ended."
        }

        isJoining = false
    }
}
