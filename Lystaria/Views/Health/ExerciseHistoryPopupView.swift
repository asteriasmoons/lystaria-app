//
//  ExerciseHistoryPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct ExerciseHistoryPopupView: View {
    let entries: [ExerciseLogEntry]
    var onSelect: (ExerciseLogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if entries.isEmpty {
                Text("No exercise entries yet.")
                    .foregroundStyle(LColors.textSecondary)
            } else {
                Text("Select a date")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)

                dateBubbleWrap(entries: entries)
            }
        }
    }

    // MARK: - Date Bubbles

    private func dateBubbleWrap(entries: [ExerciseLogEntry]) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let sorted = entries.sorted { $0.date > $1.date }

        return FlowWrap(spacing: 8, lineSpacing: 8) {
            ForEach(sorted) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    Text(formatter.string(from: entry.date))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(LColors.glassSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Flow Layout Helper

private struct FlowWrap<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: Content

    init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            content
        }
    }
}
