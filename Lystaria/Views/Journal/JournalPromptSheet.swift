//
//  JournalPromptSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import SwiftUI
import Supabase

struct JournalPromptSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String = ""
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showCopiedBanner = false

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {

                GradientTitle(
                    text: "Journal Prompt",
                    font: .system(size: 24, weight: .bold)
                )

                if loading {

                    ProgressView()
                        .progressViewStyle(.circular)

                } else if let errorMessage {

                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)

                } else if !prompt.isEmpty {

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center) {
                                Text("Prompt")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = prompt
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showCopiedBanner = true
                                    }
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            showCopiedBanner = false
                                        }
                                    }
                                } label: {
                                    Image("copyfill")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(prompt)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        .padding(16)
                    }

                }

                Button {
                    Task {
                        await generatePrompt()
                    }
                } label: {
                    Text("Generate Prompt")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LColors.textSecondary)

            }
            .padding(24)

            // Copied to Clipboard banner
            if showCopiedBanner {
                VStack {
                    Spacer()
                    Text("Copied to Clipboard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func generatePrompt() async {

        do {

            loading = true
            errorMessage = nil

            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            let response = try await JournalPromptService.shared.generatePrompt(
                userId: userId
            )

            await MainActor.run {
                prompt = response.prompt
                loading = false
            }

        } catch {

            await MainActor.run {
                loading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
