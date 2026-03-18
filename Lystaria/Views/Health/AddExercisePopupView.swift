//
//  AddExercisePopupView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct AddExercisePopupView: View {
    @Environment(\.modelContext) private var modelContext

    var onClose: () -> Void

    /// Parent sets this to true to trigger a save
    @Binding var saveTrigger: Bool
    /// Parent reads these to control the footer button
    @Binding var isSaving: Bool
    @Binding var isValid: Bool

    @State private var exerciseName: String = ""
    @State private var reps: String = ""
    @State private var duration: String = ""
    @State private var date: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            inputField("Exercise Name", text: $exerciseName, keyboard: .default)
            inputField("Reps", text: $reps, keyboard: .numberPad)
            inputField("Duration (minutes)", text: $duration, keyboard: .numberPad)

            DatePicker(
                "Date & Time",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(LColors.accent)
        }
        .onChange(of: duration) { _, _ in
            isValid = (Int(duration) ?? 0) > 0
        }
        .onChange(of: saveTrigger) { _, newValue in
            if newValue { save() }
        }
    }

    private func save() {
        guard !isSaving, isValid else {
            saveTrigger = false
            return
        }
        isSaving = true

        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationValue = Int(duration) ?? 0

        let entry = ExerciseLogEntry(
            date: date,
            exerciseName: trimmedName,
            reps: Int(reps) ?? 0,
            durationMinutes: durationValue
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
                try await ExerciseHealthKitManager.shared.saveExerciseLogEntry(entry)
            } catch {
                print("Exercise HealthKit save error:", error)
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
                .textInputAutocapitalization(.words)
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
