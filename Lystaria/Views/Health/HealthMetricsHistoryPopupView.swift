//
//  HealthMetricsHistoryPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct HealthMetricsHistoryPopupView: View {
    let entries: [HealthMetricEntry]
    let onSelect: (HealthMetricEntry) -> Void
    let onClose: () -> Void

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 520,
            heightRatio: 0.55,
            header: {
                GradientTitle(text: "Health Metrics History", size: 24)
            },
            content: {
                VStack(alignment: .leading, spacing: 12) {

                    if entries.isEmpty {
                        Text("No health metric entries yet.")
                            .foregroundStyle(LColors.textSecondary)
                    } else {
                        Text("Select a date")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)

                        dateBubbleWrap(entries: entries)
                    }
                }
            },
            footer: {
                HStack {
                    Spacer()

                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Close")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AnyShapeStyle(LGradients.blue))
                        .clipShape(Capsule())
                        .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    // MARK: - Date Bubbles

    private func dateBubbleWrap(entries: [HealthMetricEntry]) -> some View {
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
