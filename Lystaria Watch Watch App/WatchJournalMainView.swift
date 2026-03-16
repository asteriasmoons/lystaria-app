//
//  WatchJournalMainView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import SwiftUI

struct WatchJournalMainView: View {
    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 12) {
                Spacer()

                NavigationLink {
                    WatchNewJournalEntryView()
                } label: {
                    WatchJournalPrimaryButton(
                        title: "New Entry",
                        iconName: "writefill" // CHANGE to your real asset name if needed
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchJournalEntriesListView()
                } label: {
                    WatchJournalPrimaryButton(
                        title: "Entries",
                        iconName: "listfill" // CHANGE to your real asset name if needed
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Journal")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct WatchJournalPrimaryButton: View {
    let title: String
    let iconName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 62)
    }
}

struct WatchJournalEntryRow: View {
    let title: String
    let dateText: String

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .frame(height: 58)
            .overlay(
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(dateText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            )
    }
}

#Preview {
    NavigationStack {
        WatchJournalMainView()
    }
}
