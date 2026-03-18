//
//  ExerciseDetailPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct ExerciseDetailPopupView: View {
    let entry: ExerciseLogEntry

    var body: some View {
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
