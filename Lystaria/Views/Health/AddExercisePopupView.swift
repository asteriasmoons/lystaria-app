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
    @StateObject private var limits = LimitManager.shared

    var onClose: () -> Void

    @State private var isSaving = false
    @State private var isValid = false

    @State private var exerciseName: String = ""
    @State private var reps: String = ""
    @State private var duration: String = ""
    @State private var date: Date = Date()

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Add Exercise", size: 24)
            },
            content: {
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
                .onChange(of: duration) { _, _ in updateValidation() }
                .onChange(of: exerciseName) { _, _ in updateValidation() }
                .onChange(of: reps) { _, _ in updateValidation() }
                .onAppear {
                    updateValidation()
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

    private func save() {
        updateValidation()
        guard !isSaving, isValid else {
            return
        }
        isSaving = true

        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationValue = Int(duration) ?? 0
        let repsValue = Int(reps) ?? 0

        // Enforce daily exercise limit
        let descriptor = FetchDescriptor<ExerciseLogEntry>()
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        let todayCount = entries.filter { limits.isSameDay($0.createdAt, Date()) }.count

        let decision = limits.canCreate(.exercisesPerDay, currentCount: todayCount)
        guard decision.allowed else { return }

        let entry: ExerciseLogEntry

        do {
            entry = try ExerciseLogWriter.createEntry(
                date: date,
                exerciseName: trimmedName,
                reps: repsValue,
                durationMinutes: durationValue,
                modelContext: modelContext
            )
        } catch {
            print("SwiftData save error:", error)
            isSaving = false
            return
        }

        Task {
            do {
                try await ExerciseHealthKitManager.shared.saveExerciseLogEntry(entry)
            } catch {
                print("Exercise HealthKit save error:", error)
            }
            isSaving = false
            onClose()
        }
    }

    private func updateValidation() {
        let durationValid = (Int(duration) ?? 0) > 0
        let nameValid = !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isValid = durationValid && nameValid
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
