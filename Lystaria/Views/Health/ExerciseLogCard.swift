//
//  ExerciseLogCard.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct ExerciseLogCard: View {
    let entries: [ExerciseLogEntry]
    var onTap: () -> Void

    var body: some View {
        GlassCard {
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        GradientTitle(text: "Exercise Log", size: 20)

                        Spacer(minLength: 0)

                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 44, height: 44)

                            Image("exercisefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if latestDayEntries.isEmpty {
                            metricRow("Exercise", value: "—")
                            metricRow("Reps", value: "—")
                            metricRow("Duration", value: "—")
                        } else {
                            ForEach(Array(latestDayEntries.enumerated()), id: \.element.id) { index, entry in
                                exerciseSection(entry: entry, index: index)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Latest Day Entries

    private var latestDayEntries: [ExerciseLogEntry] {
        guard let latestDate = entries.map(\.date).max() else { return [] }
        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestDate)

        return entries
            .filter { calendar.isDate($0.date, inSameDayAs: latestDay) }
            .sorted { $0.date < $1.date }
    }

    private func exerciseSection(entry: ExerciseLogEntry, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if index > 0 {
                Divider()
                    .overlay(LColors.glassBorder)
                    .padding(.vertical, 2)
            }

            metricRow("Exercise", value: HealthFormatting.exerciseName(entry.exerciseName))
            metricRow("Reps", value: HealthFormatting.reps(entry.reps))
            metricRow("Duration", value: HealthFormatting.duration(entry.durationMinutes))
        }
    }

    // MARK: - Row

    private func metricRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LColors.textSecondary)

            Spacer()

            VStack(alignment: .trailing) {
                Text(value)
                    .foregroundStyle(.white)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }
            .frame(width: 120, alignment: .trailing)
        }
    }
}
