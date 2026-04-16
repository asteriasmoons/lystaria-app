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
    var onAdd: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    GradientTitle(text: "Exercise Log", size: 20)

                    Spacer(minLength: 0)

                    Button {
                        onAdd()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("wavyplus")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onTap()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("exercisefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onTap()
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        if latestDayEntries.isEmpty {
                            Text("Log your exercises to see them here every day. Refreshes automatically at midnight. Tap card to view your history.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(latestDayEntries.enumerated()), id: \.element.id) { index, entry in
                                exerciseSection(entry: entry, index: index)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Latest Day Entries

    private var latestDayEntries: [ExerciseLogEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return entries
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
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
