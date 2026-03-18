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

    var onClose: () -> Void

    /// Parent sets this to true to trigger a save
    @Binding var saveTrigger: Bool
    /// Parent reads these to control the footer button
    @Binding var isSaving: Bool
    @Binding var isValid: Bool

    @State private var bloodOxygen: String = ""
    @State private var systolic: String = ""
    @State private var diastolic: String = ""
    @State private var bpm: String = ""
    @State private var bodyTemperature: String = ""
    @State private var weight: String = ""
    @State private var date: Date = Date()

    var body: some View {
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
        .onChange(of: saveTrigger) { _, newValue in
            if newValue { save() }
        }
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
        guard !isSaving, isValid else {
            saveTrigger = false
            return
        }
        isSaving = true

        let entry = HealthMetricEntry(
            date: date,
            bloodOxygen: Double(bloodOxygen) ?? 0,
            systolic: Int(systolic) ?? 0,
            diastolic: Int(diastolic) ?? 0,
            bpm: Int(bpm) ?? 0,
            bodyTemperature: Double(bodyTemperature) ?? 0,
            weight: Double(weight) ?? 0
        )

        modelContext.insert(entry)

        do {
            try modelContext.save()
        } catch {
            print("SwiftData save error:", error)
            isSaving = false
            saveTrigger = false
            return
        }

        Task {
            do {
                try await HealthMetricsHealthKitManager.shared.saveHealthMetricEntry(entry)
            } catch {
                print("HealthKit save error:", error)
            }
            isSaving = false
            saveTrigger = false
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
