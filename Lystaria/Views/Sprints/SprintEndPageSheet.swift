//
//  SprintEndPageSheet.swift
//  Lystaria
//

import SwiftUI

struct SprintEndPageSheet: View {
    let sprint: Sprint
    let userId: String
    var onClose: (() -> Void)?
    var onSubmitted: ((Sprint) -> Void)?

    @State private var endPageText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil

    private var closeAction: () -> Void { onClose ?? {} }
    private var canSubmit: Bool { !endPageText.isEmpty && !isSubmitting }

    private var startPage: Int? {
        sprint.participants.first(where: { $0.userId == userId })?.startPage
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 520,
            heightRatio: 0.48,
            header: {
                HStack {
                    GradientTitle(text: "Enter End Page", font: .title2.bold())
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
                if let startPage {
                    Text("You started on page \(startPage). How far did you get?")
                        .font(.subheadline)
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("END PAGE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaNumberField(placeholder: "What page did you reach?", text: $endPageText)
                        .numericKeyboardIfAvailable()
                }

                if let start = startPage, let end = Int(endPageText), end > start {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LColors.accent)
                        Text("\(end - start) pages read · \(end - start) points")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await submit() } } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canSubmit ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        )
    }

    private func submit() async {
        guard canSubmit, let page = Int(endPageText) else { return }
        isSubmitting = true
        errorMessage = nil

        let body = SubmitEndPageBody(userId: userId, endPage: page)

        do {
            let updated = try await SprintService.shared.submitEndPage(sprintId: sprint.id, body: body)
            onSubmitted?(updated)
        } catch {
            errorMessage = "Failed to submit. Please try again."
        }

        isSubmitting = false
    }
}
