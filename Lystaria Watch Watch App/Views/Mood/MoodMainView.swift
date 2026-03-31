//
//  MoodMainView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI

struct WatchMoodMainView: View {
    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 12) {
                Spacer()

                NavigationLink {
                    MoodSelectionView()
                } label: {
                    WatchMoodMainButton(
                        title: "Log Mood",
                        iconName: "wavyplus"
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    NavigationLink {
                        WatchMoodHistoryView()
                    } label: {
                        WatchMoodSecondaryButton(
                            title: "History",
                            iconName: "clockfill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WatchPlaceholderView(title: "Insights")
                    } label: {
                        WatchMoodSecondaryButton(
                            title: "Insights",
                            iconName: "barcircle"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Mood")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct WatchMoodMainButton: View {
    let title: String
    let iconName: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
            }
            .frame(height: 86)
        }
    }
}

struct WatchMoodSecondaryButton: View {
    let title: String
    let iconName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            VStack(spacing: 5) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .frame(height: 70)
    }
}

#Preview {
    NavigationStack {
        WatchMoodMainView()
    }
}
