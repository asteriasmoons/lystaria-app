//
//  BookRecommendationsSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/7/26.
//

import SwiftUI
import UIKit

struct BookRecommendationsSheet: View {
    @Binding var isPresented: Bool

    @State private var genre: String = ""

    private let presetGenres: [String] = [
        "Fantasy",
        "Romance",
        "Horror",
        "Thriller",
        "Mystery",
        "Science Fiction",
        "Historical Fiction",
        "Young Adult",
        "Contemporary",
        "Dark Academia",
        "Paranormal",
        "Dystopian"
    ]

    @State private var isLoading = false
    @State private var recommendations: [BookRecommendationItem] = []
    @State private var errorMessage: String = ""

    @State private var didCopy = false
    @State private var copiedRecommendationID: String?
    @State private var copyIconPressedID: String?

    private var genreTrimmed: String {
        genre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasResults: Bool {
        !recommendations.isEmpty
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
                GradientTitle(text: "Book Recommendations", font: .system(size: 22, weight: .bold))

                VStack(alignment: .leading, spacing: 10) {
                    Text("GENRE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    genrePills
                }

                ScrollView {
                    VStack(spacing: 16) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if isLoading {
                            GlassCard {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.white)

                                    Text("Generating recommendations...")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            }
                        } else if !errorMessage.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ERROR")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if hasResults {
                            ForEach(recommendations) { rec in
                                recommendationCard(rec)
                            }
                        } else {
                            GlassCard {
                                Text("Choose a genre, then tap Generate to get book recommendations.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(LColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)

                Button {
                    Task { await generateRecommendations() }
                } label: {
                    Text(isLoading ? "Generating..." : "Generate")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            genreTrimmed.isEmpty || isLoading
                            ? AnyShapeStyle(Color.gray.opacity(0.3))
                            : AnyShapeStyle(LGradients.blue)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(genreTrimmed.isEmpty || isLoading)

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

    private var genrePills: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chunkedGenres, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        genrePill(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunkedGenres: [[String]] {
        stride(from: 0, to: presetGenres.count, by: 3).map { start in
            Array(presetGenres[start..<min(start + 3, presetGenres.count)])
        }
    }

    @ViewBuilder
    private func genrePill(_ item: String) -> some View {
        let isSelected = genre == item

        Button {
            genre = item
        } label: {
            Text(item)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? AnyShapeStyle(LGradients.blue)
                    : AnyShapeStyle(Color.white.opacity(0.08))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.white.opacity(0.18) : LColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func recommendationCard(_ rec: BookRecommendationItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text(rec.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string = """
                        \(rec.title)
                        \(rec.author)

                        \(rec.summary)
                        """

                        let generator = UINotificationFeedbackGenerator()
                        generator.prepare()
                        generator.notificationOccurred(.success)

                        copiedRecommendationID = rec.id

                        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                            copyIconPressedID = rec.id
                        }

                        didCopy = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                                if copyIconPressedID == rec.id {
                                    copyIconPressedID = nil
                                }
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            didCopy = false
                            if copiedRecommendationID == rec.id {
                                copiedRecommendationID = nil
                            }
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
                            .scaleEffect(copyIconPressedID == rec.id ? 1.12 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                if !rec.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(rec.author)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                Text(rec.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(LColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func generateRecommendations() async {
        errorMessage = ""
        recommendations = []
        didCopy = false
        copiedRecommendationID = nil
        copyIconPressedID = nil
        isLoading = true

        do {
            recommendations = try await BookRecommendationsService.shared.generateRecommendations(
                genre: genre
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
