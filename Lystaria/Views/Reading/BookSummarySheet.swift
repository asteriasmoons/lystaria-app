//
//  BookSummarySheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import SwiftUI
import UIKit

struct BookSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        GradientTitle(text: "Book Summary", font: .title2.bold())
                        Spacer()

                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

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

                    Button {
                        Task {
                            await generateSummary()
                        }
                    } label: {
                        Text(isLoading ? "Generating..." : "Generate")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                titleTrimmed.isEmpty || isLoading
                                ? AnyShapeStyle(Color.gray.opacity(0.3))
                                : AnyShapeStyle(LGradients.blue)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                            .shadow(
                                color: titleTrimmed.isEmpty || isLoading
                                ? .clear
                                : Color.black.opacity(0.18),
                                radius: 12,
                                y: 6
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(titleTrimmed.isEmpty || isLoading)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 40)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
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

#Preview {
    BookSummarySheet()
        .preferredColorScheme(.dark)
}
