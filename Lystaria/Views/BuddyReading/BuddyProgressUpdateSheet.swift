//
//  BuddyProgressUpdateSheet.swift
//  Lystaria
//

import SwiftUI

struct BuddyProgressUpdateSheet: View {
    let userId: String
    let displayName: String
    let groupId: String
    var onClose: (() -> Void)?
    var onSend: ((BuddyMessage) -> Void)?

    @State private var chapterText: String = ""
    @State private var pageText: String = ""
    @State private var noteText: String = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var canSend: Bool {
        (!chapterText.isEmpty || !pageText.isEmpty) && !isSending
    }

    private var progressText: String {
        var parts: [String] = []
        if let chapter = Int(chapterText), chapter > 0 {
            parts.append("chapter \(chapter)")
        }
        if let page = Int(pageText), page > 0 {
            parts.append("page \(page)")
        }
        let base = "I'm on \(parts.joined(separator: ", "))"
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? base : "\(base) — \(note)"
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 580,
            heightRatio: 0.58,
            header: {
                HStack {
                    GradientTitle(text: "Progress Update", font: .title2.bold())
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
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHAPTER")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        LystariaNumberField(placeholder: "5", text: $chapterText)
                            .numericKeyboardIfAvailable()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("PAGE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        LystariaNumberField(placeholder: "120", text: $pageText)
                            .numericKeyboardIfAvailable()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ADD A NOTE (OPTIONAL)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaTextField(placeholder: "Can't believe that plot twist!", text: $noteText)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await send() } } label: {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Share Progress")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSend ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canSend ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        )
    }

    private func send() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil

        let chapter = Int(chapterText)
        let page = Int(pageText)

        let body = SendMessageBody(
            senderUserId: userId,
            senderDisplayName: displayName,
            type: "progress_update",
            text: progressText,
            progressChapter: chapter,
            progressPage: page
        )

        do {
            let message = try await BuddyService.shared.sendMessage(groupId: groupId, body: body)
            onSend?(message)
        } catch {
            errorMessage = "Failed to send update. Please try again."
        }

        isSending = false
    }
}
