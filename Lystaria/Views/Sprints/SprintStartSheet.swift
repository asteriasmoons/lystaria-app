//
//  SprintStartSheet.swift
//  Lystaria
//

import SwiftUI

struct SprintStartSheet: View {
    let userId: String
    let displayName: String
    var onClose: (() -> Void)?
    var onStarted: ((Sprint) -> Void)?

    @State private var selectedDuration: Int = 25
    @State private var startPageText: String = ""
    @State private var isStarting = false
    @State private var errorMessage: String? = nil

    private let durations = [5, 10, 15, 20, 25, 30, 45, 60]
    private var closeAction: () -> Void { onClose ?? {} }
    private var canStart: Bool { !startPageText.isEmpty && !isStarting }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 580,
            heightRatio: 0.62,
            header: {
                HStack {
                    GradientTitle(text: "Start a Sprint", font: .title2.bold())
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("DURATION")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(durations, id: \.self) { duration in
                            Button {
                                selectedDuration = duration
                            } label: {
                                Text("\(duration)m")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(selectedDuration == duration ? .white : LColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedDuration == duration ? LColors.accent : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedDuration == duration ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR START PAGE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaNumberField(placeholder: "e.g. 42", text: $startPageText)
                        .numericKeyboardIfAvailable()
                }

                Text("A 30 second join window opens before the sprint begins. Others can join during this time.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await start() } } label: {
                    Group {
                        if isStarting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start Sprint")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canStart ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canStart ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
            }
        )
    }

    private func start() async {
        guard canStart, let page = Int(startPageText) else { return }
        isStarting = true
        errorMessage = nil

        let body = StartSprintBody(
            userId: userId,
            displayName: displayName,
            durationMinutes: selectedDuration,
            startPage: page
        )

        do {
            let sprint = try await SprintService.shared.startSprint(body: body)
            onStarted?(sprint)
        } catch {
            errorMessage = "Failed to start sprint. There may already be one active."
        }

        isStarting = false
    }
}
