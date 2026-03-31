//
//  WatchBooksMainView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/29/26.
//

import SwiftUI

struct WatchBooksMainView: View {
    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 12) {
                Spacer()

                NavigationLink {
                    WatchReadingCheckInView()
                } label: {
                    WatchBooksActionCard(
                        icon: "wavycheck", // CHANGE to your real asset name if needed
                        title: "Check In"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchReadingGoalView()
                } label: {
                    WatchBooksActionCard(
                        icon: "targetsparkle", // CHANGE to your real asset name if needed
                        title: "Goal"
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Books")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Shared Action Card

private struct WatchBooksActionCard: View {
    let icon: String
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(height: 64)
    }
}
