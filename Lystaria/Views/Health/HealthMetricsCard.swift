//
//  HealthMetricsCard.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI

struct HealthMetricsCard: View {
    let latestEntry: HealthMetricEntry?
    var onTap: () -> Void
    var onAdd: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    GradientTitle(text: "Health Metrics", size: 20)

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

                            Image("heartplus")
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
                        if latestEntry == nil {
                            Text("Log your health metrics to see them here every day. Refreshes automatically at midnight every night. Tap card to view your history.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            metricRow("Blood Oxygen", value: bloodOxygenText)
                            metricRow("Blood Pressure", value: bloodPressureText)
                            metricRow("Body Temperature", value: temperatureText)
                            metricRow("Weight", value: weightText)
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

    // MARK: - Formatting

    private var bloodOxygenText: String {
        guard let entry = latestEntry else { return "—" }
        return HealthFormatting.bloodOxygen(entry.bloodOxygen)
    }

    private var bloodPressureText: String {
        guard let entry = latestEntry else { return "—" }
        return HealthFormatting.bloodPressure(systolic: entry.systolic, diastolic: entry.diastolic)
    }

    private var temperatureText: String {
        guard let entry = latestEntry else { return "—" }
        return HealthFormatting.temperature(entry.bodyTemperature)
    }

    private var weightText: String {
        guard let entry = latestEntry else { return "—" }
        return HealthFormatting.weight(entry.weight)
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
