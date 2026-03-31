//
//  MoodHistoryView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import Foundation

struct WatchMoodHistoryView: View {
    @State private var moodLogs: [MoodLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init() {}

    private var groupedLogs: [(date: Date, logs: [MoodLog])] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: moodLogs) { log in
            calendar.startOfDay(for: logDate(log))
        }

        return grouped
            .map { (date: $0.key, logs: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func logDate(_ log: MoodLog) -> Date {
        log.createdAt
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Text("Unable to Load")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(errorMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)
                } else if groupedLogs.isEmpty {
                    Text("No Mood Logs Yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedLogs, id: \.date) { group in
                                NavigationLink {
                                    WatchMoodHistoryDayView(
                                        date: group.date,
                                        logs: group.logs
                                    )
                                } label: {
                                    HStack {
                                        Text(formattedDate(group.date))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)

                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.white.opacity(0.18))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("History")
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadMoodLogs()
        }
    }

    private func loadMoodLogs() async {
        isLoading = true
        errorMessage = nil

        do {
            moodLogs = try await MoodLogService.shared.fetchMoodLogs()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let monthDay = formatter.string(from: date)
        let day = Calendar.current.component(.day, from: date)
        let year = Calendar.current.component(.year, from: date)
        return "\(monthDay)\(ordinalSuffix(for: day)) \(year)"
    }

    private func ordinalSuffix(for day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

struct WatchMoodHistoryDayView: View {
    let date: Date
    let logs: [MoodLog]

    private var allMoods: [String] {
        Array(Set(logs.flatMap(\.moods))).sorted()
    }

    private var allActivities: [String] {
        Array(Set(logs.flatMap(\.activities))).sorted()
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            TabView {
                WatchMoodHistoryBubblePageView(
                    title: "Moods Logged",
                    items: allMoods
                )

                WatchMoodHistoryBubblePageView(
                    title: "Activities Logged",
                    items: allActivities
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .navigationTitle(formattedDate(date))
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let monthDay = formatter.string(from: date)
        let day = Calendar.current.component(.day, from: date)
        let year = Calendar.current.component(.year, from: date)
        return "\(monthDay)\(ordinalSuffix(for: day)) \(year)"
    }

    private func ordinalSuffix(for day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

struct WatchMoodHistoryBubblePageView: View {
    let title: String
    let items: [String]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 4)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        Text(item.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.18))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 4)
    }
}


#Preview {
    NavigationStack {
        WatchMoodHistoryView()
    }
}
