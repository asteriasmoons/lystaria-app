//
//  WatchHomeView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI

// =======================================================
// MARK: - WATCH HOME ROOT
// =======================================================

struct WatchHomeView: View {

    var body: some View {

        NavigationStack {

            ZStack {
                WatchLystariaBackground()

                TabView {

                    // PAGE 1
                    WatchHomePageView(items: [
                        WatchHomeItem(title: "Mood", icon: "heartcircle", destination: .mood),
                        WatchHomeItem(title: "Books", icon: "openbook", destination: .books),
                        WatchHomeItem(title: "Journal", icon: "pagesfill", destination: .journal)
                    ])

                    // PAGE 2
                    WatchHomePageView(items: [
                        WatchHomeItem(title: "Calendar", icon: "calfill", destination: .calendar),
                        WatchHomeItem(title: "Reminder", icon: "bellfill", destination: .reminder),
                        WatchHomeItem(title: "Habits", icon: "circlesparkle", destination: .habits),
                        WatchHomeItem(title: "Checklists", icon: "wavycheck", destination: .checklists)
                    ])

                    // PAGE 3
                    WatchHomePageView(items: [
                        WatchHomeItem(title: "Health", icon: "hearthealth", destination: .health),
                        WatchHomeItem(title: "Profile", icon: "wavyuser", destination: .profile),
                        WatchHomeItem.empty
                    ])

                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
    }
}


// =======================================================
// MARK: - HOME PAGE GRID
// =======================================================

struct WatchHomePageView: View {

    let items: [WatchHomeItem]

    var body: some View {

        VStack(spacing: 14) {
            let rows = stride(from: 0, to: items.count, by: 2).map {
                Array(items[$0..<min($0 + 2, items.count)])
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.title) { item in
                        WatchHomeIconButton(item: item)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}


// =======================================================
// MARK: - HOME ITEM MODEL
// =======================================================

struct WatchHomeItem {

    let title: String
    let icon: String
    let destination: WatchHomeDestination

    static let empty = WatchHomeItem(
        title: "",
        icon: "",
        destination: .empty
    )
}


// =======================================================
// MARK: - DESTINATIONS
// =======================================================

enum WatchHomeDestination {

    case mood
    case books
    case journal
    case calendar
    case reminder
    case habits
    case checklists
    case health
    case profile
    case empty
}


// =======================================================
// MARK: - ICON BUTTON
// =======================================================

struct WatchHomeIconButton: View {

    let item: WatchHomeItem

    var body: some View {

        if item.destination == .empty {

            Circle()
                .fill(.clear)
                .frame(width: 64, height: 64)

        } else {

            NavigationLink {
                destinationView(for: item.destination)
            } label: {

                VStack(spacing: 4) {

                    ZStack {

                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        // CUSTOM ASSET ICON
                        Image(item.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(.white)
                    }

                    Text(item.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                }
            }
            .buttonStyle(.plain)
        }
    }


    @ViewBuilder
    private func destinationView(for destination: WatchHomeDestination) -> some View {

        switch destination {

        case .mood:
            WatchMoodMainView()

        case .books:
            WatchBooksMainView()

        case .journal:
            WatchJournalMainView()

        case .calendar:
            WatchCalendarView()

        case .reminder:
            WatchRemindersView()

        case .habits:
            WatchHabitsView()

        case .checklists:
            WatchChecklistsView()
            
        case .health:
            WatchHealthMainView()

        case .profile:
            WatchProfileView()

        case .empty:
            EmptyView()
        }
    }
}


// =======================================================
// MARK: - PLACEHOLDER PAGE
// =======================================================

struct WatchPlaceholderView: View {

    let title: String

    var body: some View {

        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 10) {

                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)

                Text(title)
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle(title)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}


// =======================================================
// MARK: - PREVIEW
// =======================================================

#Preview {
    WatchHomeView()
}
