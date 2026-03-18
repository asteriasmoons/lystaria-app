//
//  HealthMetricDetailPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct HealthMetricDetailPopupView: View {
    let entry: HealthMetricEntry

    var body: some View {
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
