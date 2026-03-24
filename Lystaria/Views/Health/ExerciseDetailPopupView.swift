//
//  ExerciseDetailPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct ExerciseDetailPopupView: View {
    let entry: ExerciseLogEntry
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 520,
            heightRatio: 0.50,
            header: {
                GradientTitle(text: "Exercise Entry", size: 24)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    metricRow("Exercise", value: exerciseNameText)
                    metricRow("Reps", value: repsText)
                    metricRow("Duration", value: durationText)

                    Divider()
                        .overlay(LColors.glassBorder)

                    Text(formattedDate)
                        .font(.footnote)
                        .foregroundStyle(LColors.textSecondary)
                }
            },
            footer: {
                HStack {
                    Spacer()

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image("trashfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)

                            Text("Delete")
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
        .lystariaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete exercise entry?",
            message: "This will permanently delete this exercise entry. Choose a button.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            onDelete()
        }
    }

    // MARK: - Formatting

    private var exerciseNameText: String {
        HealthFormatting.exerciseName(entry.exerciseName)
    }

    private var repsText: String {
        HealthFormatting.reps(entry.reps)
    }

    private var durationText: String {
        HealthFormatting.duration(entry.durationMinutes)
    }

    private var formattedDate: String {
        HealthFormatting.dateTime(entry.date)
    }

    // MARK: - Row

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(LColors.textSecondary)

            Spacer()

            Text(value)
                .foregroundStyle(LColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
    }
}
