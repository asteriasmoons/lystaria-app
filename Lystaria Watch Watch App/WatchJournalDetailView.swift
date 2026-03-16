//
//  WatchJournalDetailView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import SwiftUI

struct WatchJournalDetailView: View {
    let entry: JournalEntry

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formattedDate(entry.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .overlay(
                            Text(entry.body)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12),
                            alignment: .topLeading
                        )
                        .frame(minHeight: 120, alignment: .top)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Entry")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        return formatter.string(from: date)
    }
}
