// MedicationDoseScheduleGrid.swift
// Lystaria

import SwiftUI

/// Day-bubble grid for per-weekday dose overrides.
///
/// Shows 7 bubbles (Sun–Sat). Tapping a bubble toggles it selected.
/// Selected bubbles reveal a small quantity text field beneath them.
/// Unselected days fall back to `defaultQuantity` at completion time.
///
/// Calendar.weekday convention: 1 = Sunday, 2 = Monday, … 7 = Saturday.
struct MedicationDoseScheduleGrid: View {

    @Binding var defaultQuantity: Int
    /// Keys are Calendar.weekday integers (1–7). Only days with a custom
    /// dose appear here; absent days use defaultQuantity.
    @Binding var overrides: [Int: Int]

    // Local text buffer so the user can type freely without Int coercion on each keystroke.
    @State private var fieldText: [Int: String] = [:]

    private let days: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Default qty row
            HStack(spacing: 10) {
                Text("Default")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                Spacer()

                Button {
                    if defaultQuantity > 1 { defaultQuantity -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(defaultQuantity <= 1 ? LColors.textSecondary.opacity(0.4) : .white)
                        .frame(width: 28, height: 28)
                        .background(defaultQuantity <= 1 ? Color.white.opacity(0.05) : LColors.accent.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(defaultQuantity <= 1)

                Text("\(defaultQuantity)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(minWidth: 28)
                    .multilineTextAlignment(.center)

                Button {
                    if defaultQuantity < 99 { defaultQuantity += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(LColors.accent.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))

            // Day override grid
            HStack(spacing: 6) {
                ForEach(days, id: \.weekday) { day in
                    dayColumn(day)
                }
            }

            if !overrides.isEmpty {
                Text("Days without a custom value use the default above.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
        .onAppear { syncFieldTextFromOverrides() }
        .onChange(of: overrides) { syncFieldTextFromOverrides() }
    }

    @ViewBuilder
    private func dayColumn(_ day: (label: String, weekday: Int)) -> some View {
        let isSelected = overrides[day.weekday] != nil
        VStack(spacing: 6) {
            // Bubble
            Button {
                toggleDay(day.weekday)
            } label: {
                Text(day.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? .white : LColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? LColors.accent : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Quantity field — visible only when selected
            if isSelected {
                TextField("", text: Binding(
                    get: { fieldText[day.weekday] ?? "\(overrides[day.weekday] ?? defaultQuantity)" },
                    set: { newVal in
                        fieldText[day.weekday] = newVal
                        if let parsed = Int(newVal.trimmingCharacters(in: .whitespacesAndNewlines)),
                           parsed > 0 {
                            overrides[day.weekday] = parsed
                        }
                    }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
            } else {
                // Placeholder to keep column height stable
                Color.clear.frame(height: 30)
            }
        }
    }

    private func toggleDay(_ weekday: Int) {
        if overrides[weekday] != nil {
            overrides.removeValue(forKey: weekday)
            fieldText.removeValue(forKey: weekday)
        } else {
            overrides[weekday] = defaultQuantity
            fieldText[weekday] = "\(defaultQuantity)"
        }
    }

    private func syncFieldTextFromOverrides() {
        for (weekday, qty) in overrides {
            if fieldText[weekday] == nil {
                fieldText[weekday] = "\(qty)"
            }
        }
        // Remove stale entries
        for weekday in fieldText.keys where overrides[weekday] == nil {
            fieldText.removeValue(forKey: weekday)
        }
    }
}
