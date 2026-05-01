//
//  AddHealthMetricsPopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct AddHealthMetricsPopupView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared

    var onClose: () -> Void

    @State private var isSaving = false
    @State private var isValid = false

    @State private var bloodOxygen: String = ""
    @State private var systolic: String = ""
    @State private var diastolic: String = ""
    @State private var bpm: String = ""
    @State private var bodyTemperature: String = ""
    @State private var weight: String = ""
    @State private var date: Date = Date()

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Add Metrics", size: 24)
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    inputField("Blood Oxygen (%)", text: $bloodOxygen, keyboard: .numberPad)
                    inputField("Systolic", text: $systolic, keyboard: .numberPad)
                    inputField("Diastolic", text: $diastolic, keyboard: .numberPad)
                    inputField("BPM", text: $bpm, keyboard: .numberPad)
                    inputField("Body Temperature (°F)", text: $bodyTemperature, keyboard: .decimalPad)
                    inputField("Weight (lb)", text: $weight, keyboard: .decimalPad)

                    DatePicker(
                        "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(LColors.accent)
                }
                .onChange(of: bloodOxygen) { _, _ in updateValidity() }
                .onChange(of: systolic) { _, _ in updateValidity() }
                .onChange(of: diastolic) { _, _ in updateValidity() }
                .onChange(of: bpm) { _, _ in updateValidity() }
                .onChange(of: bodyTemperature) { _, _ in updateValidity() }
                .onChange(of: weight) { _, _ in updateValidity() }
                .onAppear {
                    updateValidity()
                }
            },
            footer: {
                HStack {
                    Spacer()

                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Saving..." : "Save")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LGradients.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .opacity(isValid ? 1.0 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || !isValid)
                }
            }
        )
    }

    private func updateValidity() {
        isValid =
            (Double(bloodOxygen) ?? 0) > 0 ||
            (Int(systolic) ?? 0) > 0 ||
            (Int(diastolic) ?? 0) > 0 ||
            (Int(bpm) ?? 0) > 0 ||
            (Double(bodyTemperature) ?? 0) > 0 ||
            (Double(weight) ?? 0) > 0
    }

    private func save() {
        updateValidity()
        guard !isSaving, isValid else {
            return
        }
        isSaving = true

        // Enforce daily health metrics limit
        let descriptor = FetchDescriptor<HealthMetricEntry>()
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        let todayCount = entries.filter { limits.isSameDay($0.createdAt, Date()) }.count

        let decision = limits.canCreate(.healthMetricsPerDay, currentCount: todayCount)
        guard decision.allowed else {
            isSaving = false
            return
        }

        let entry: HealthMetricEntry

        do {
            entry = try HealthMetricsWriter.createEntry(
                date: date,
                bloodOxygen: Double(bloodOxygen) ?? 0,
                systolic: Int(systolic) ?? 0,
                diastolic: Int(diastolic) ?? 0,
                bpm: Int(bpm) ?? 0,
                bodyTemperature: Double(bodyTemperature) ?? 0,
                weight: Double(weight) ?? 0,
                modelContext: modelContext
            )
        } catch {
            print("SwiftData save error:", error)
            isSaving = false
            return
        }

        Task {
            do {
                try await HealthMetricsHealthKitManager.shared.saveHealthMetricEntry(entry)
            } catch {
                print("HealthKit save error:", error)
            }
            isSaving = false
            onClose()
        }
    }

    private func inputField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LColors.textSecondary)

            TextField("", text: text)
                .keyboardType(keyboard)
                .submitLabel(.done)
                .padding(10)
                .background(LColors.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .foregroundStyle(LColors.textPrimary)
        }
    }
}
