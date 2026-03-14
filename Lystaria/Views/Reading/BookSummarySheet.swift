//
//  BookSummarySheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import SwiftUI
import UIKit

struct BookSummarySheet: View {
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var author: String = ""

    @State private var isLoading = false
    @State private var generatedTitle: String = ""
    @State private var generatedAuthor: String = ""
    @State private var generatedSummary: String = ""
    @State private var errorMessage: String = ""
    @State private var didCopy = false
    @State private var copyIconPressed = false

    private var titleTrimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasResult: Bool {
        !generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 20) {
                GradientTitle(text: "Book Summary", font: .system(size: 22, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaTextField(placeholder: "Book title", text: $title)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("AUTHOR (OPTIONAL)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaTextField(placeholder: "Author name", text: $author)
                }

                ScrollView {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if didCopy {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)

                                    Text("Copied to clipboard!")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if isLoading {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.white)

                                    Text("Generating summary...")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            } else if !errorMessage.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ERROR")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else if hasResult {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 12) {
                                        if !generatedTitle.isEmpty {
                                            Text(generatedTitle)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(LColors.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }

                                        Button {
                                            UIPasteboard.general.string = generatedSummary

                                            let generator = UINotificationFeedbackGenerator()
                                            generator.prepare()
                                            generator.notificationOccurred(.success)

                                            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                                                copyIconPressed = true
                                            }

                                            didCopy = true

                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                                withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                                                    copyIconPressed = false
                                                }
                                            }

                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                didCopy = false
                                            }
                                        } label: {
                                            Image("copyfill")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                                .foregroundStyle(.white)
                                                .padding(8)
                                                .background(Color.white.opacity(0.06))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .scaleEffect(copyIconPressed ? 1.12 : 1.0)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if !generatedAuthor.isEmpty {
                                        Text(generatedAuthor)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    Text(generatedSummary)
                                        .font(.system(size: 14))
                                        .foregroundStyle(LColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("Enter a title and optionally an author, then tap Generate.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(LColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.25), value: didCopy)
                    }
                }
                .frame(maxHeight: 260)

                Button {
                    Task { await generateSummary() }
                } label: {
                    Text(isLoading ? "Generating..." : "Generate")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            titleTrimmed.isEmpty || isLoading
                            ? AnyShapeStyle(Color.gray.opacity(0.3))
                            : AnyShapeStyle(LGradients.blue)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(titleTrimmed.isEmpty || isLoading)

                Button {
                    close()
                } label: {
                    Text("Close")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                ZStack {
                    LGradients.blue
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    GradientOverlayBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
            )
            .padding(.horizontal, 28)
            .onTapGesture { }  // absorb taps so they don't fall through to the dim layer
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @MainActor
    private func generateSummary() async {
        errorMessage = ""
        didCopy = false
        copyIconPressed = false
        generatedTitle = ""
        generatedAuthor = ""
        generatedSummary = ""
        isLoading = true

        do {
            let result = try await BookSummaryService.shared.generateSummary(
                title: title,
                author: author
            )

            generatedTitle = result.title ?? titleTrimmed
            generatedAuthor = result.author ?? author.trimmingCharacters(in: .whitespacesAndNewlines)
            generatedSummary = result.summary ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
