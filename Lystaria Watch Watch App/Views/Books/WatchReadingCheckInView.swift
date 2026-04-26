//
//  WatchReadingCheckInView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/29/26.
//

import SwiftUI
import SwiftData

struct WatchReadingCheckInView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ReadingStats.updatedAt, order: .reverse)
    private var allStats: [ReadingStats]

    private var stats: ReadingStats? { allStats.first }

    private var streak: Int     { stats?.streakDays ?? 0 }
    private var bestStreak: Int { stats?.bestStreakDays ?? 0 }

    private var hasCheckedInToday: Bool {
        guard let last = stats?.lastCheckInDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    @State private var selectedPage = 0

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            TabView(selection: $selectedPage) {
                streakPage.tag(0)
                checkInPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .navigationTitle("Check In")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Pages

    private var streakPage: some View {
        VStack(spacing: 12) {
            Spacer()
            WatchReadingStreakCard(
                streak: streak,
                bestStreak: bestStreak,
                hasCheckedInToday: hasCheckedInToday
            )
            Spacer()
        }
        .padding(.horizontal, 10)
    }

    private var checkInPage: some View {
        VStack(spacing: 12) {
            Spacer()

            Button {
                guard !hasCheckedInToday else { return }
                checkIn()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 125/255, green: 25/255, blue: 247/255),
                                    Color(red: 3/255, green: 219/255, blue: 252/255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    Text(hasCheckedInToday ? "Checked In ✓" : "Check In")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(height: 58)
            }
            .buttonStyle(.plain)
            .disabled(hasCheckedInToday)
            .opacity(hasCheckedInToday ? 0.7 : 1)

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Logic

    private func checkIn() {
        let now = Date()
        let cal = Calendar.current

        if let existing = allStats.first {
            let wasYesterday: Bool
            if let last = existing.lastCheckInDate,
               let yesterday = cal.date(byAdding: .day, value: -1, to: now),
               cal.isDate(last, inSameDayAs: yesterday) {
                wasYesterday = true
            } else {
                wasYesterday = false
            }
            let newStreak = wasYesterday ? existing.streakDays + 1 : 1
            existing.streakDays = newStreak
            existing.bestStreakDays = max(existing.bestStreakDays, newStreak)
            existing.lastCheckInDate = now
            existing.updatedAt = now
        } else {
            let record = ReadingStats(
                userId: "",
                streakDays: 1,
                bestStreakDays: 1,
                lastCheckInDate: now
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }
}

// MARK: - Streak Card

private struct WatchReadingStreakCard: View {
    let streak: Int
    let bestStreak: Int
    let hasCheckedInToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image("boltfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)

                    Text("Reading Streak")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    WatchReadingStreakBubble(title: "Current", value: "\(streak)")
                    WatchReadingStreakBubble(title: "Best",    value: "\(bestStreak)")
                }

                Text(hasCheckedInToday ? "Checked in today ✓" : "Ready for today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Streak Bubble

private struct WatchReadingStreakBubble: View {
    let title: String
    let value: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
    }
}
