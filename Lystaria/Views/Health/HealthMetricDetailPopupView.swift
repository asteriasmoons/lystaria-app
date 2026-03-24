//
//  HealthMetricDetailPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct HealthMetricDetailPopupView: View {
    let entry: HealthMetricEntry
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 520,
            heightRatio: 0.55,
            header: {
                GradientTitle(text: "Health Entry", size: 24)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    metricRow("Blood Oxygen", value: bloodOxygenText)
                    metricRow("Blood Pressure", value: bloodPressureText)
                    metricRow("BPM", value: bpmText)
                    metricRow("Body Temperature", value: temperatureText)
                    metricRow("Weight", value: weightText)

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
            title: "Delete health entry?",
            message: "This will permanently delete this health entry. Choose a button.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            onDelete()
        }
    }

    // MARK: - Formatting

    private var bloodOxygenText: String {
        HealthFormatting.bloodOxygen(entry.bloodOxygen)
    }

    private var bloodPressureText: String {
        HealthFormatting.bloodPressure(systolic: entry.systolic, diastolic: entry.diastolic)
    }

    private var bpmText: String {
        HealthFormatting.bpm(entry.bpm)
    }

    private var temperatureText: String {
        HealthFormatting.temperature(entry.bodyTemperature)
    }

    private var weightText: String {
        HealthFormatting.weight(entry.weight)
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
