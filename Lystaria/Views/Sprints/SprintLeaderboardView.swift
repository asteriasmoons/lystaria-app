// SprintLeaderboardView.swift
// Lystaria

import SwiftUI

struct SprintLeaderboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var entries: [SprintLeaderboardEntry] = []
    @State private var isLoading = false

    private var userId: String { appState.currentAppleUserId ?? "" }

    var body: some View {
        ZStack {
            LystariaBackground()
            VStack(spacing: 0) {
                header
                Rectangle().fill(LColors.glassBorder).frame(height: 1)
                content
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(false)
        .onAppear { Task { await load() } }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "All-Time Leaderboard", font: .title2.bold())
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.8).tint(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 10) {
                if entries.isEmpty && !isLoading {
                    GlassCard {
                        Text("No sprints completed yet. Be the first!")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry: entry, rank: index + 1)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .padding(.bottom, 100)
        }
    }

    private func leaderboardRow(entry: SprintLeaderboardEntry, rank: Int) -> some View {
        let isMe = entry.userId == userId

        return GlassCard {
            HStack(spacing: 12) {
                rankIcon(for: rank - 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isMe ? LColors.accent : LColors.textPrimary)
                        if isMe {
                            Text("you")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(LColors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(entry.sprintsParticipated) sprint\(entry.sprintsParticipated == 1 ? "" : "s") · \(entry.totalPagesRead) pages read")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.totalPoints)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                    Text("pts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func rankIcon(for index: Int) -> some View {
        switch index {
        case 0:
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
        case 1:
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.75, green: 0.75, blue: 0.75))
        case 2:
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.2))
        default:
            Image(systemName: "book.closed.fill")
                .font(.system(size: 20))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    private func load() async {
        isLoading = true
        entries = (try? await SprintService.shared.getAllTimeLeaderboard()) ?? []
        isLoading = false
    }
}
