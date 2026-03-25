//
//  MedicationPageView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/24/26.
//

import SwiftUI
import SwiftData

struct MedicationPageView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Medication.updatedAt, order: .reverse)
    private var medications: [Medication]

    @Query private var reminders: [LystariaReminder]

    @State private var showAddMedicationPopup = false
    @State private var newMedicationName = ""
    @State private var newMedicationDosage = ""
    @State private var newMedicationCurrentAmount = ""
    @State private var newMedicationSupplyAmount = ""
    @State private var newMedicationRefillDate = Date()
    @State private var includeRefillDate = false
    @State private var selectedMedication: Medication? = nil
    @State private var showEditMedicationPopup = false
    @State private var editMedicationName = ""
    @State private var editMedicationDosage = ""
    @State private var editMedicationCurrentAmount = ""
    @State private var editMedicationSupplyAmount = ""
    @State private var editMedicationRefillDate = Date()
    @State private var editIncludeRefillDate = false
    @State private var showDeleteMedicationConfirm = false
    @State private var showMedicationDetailsPopup = false
    @State private var showMedicationHistoryPopup = false

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                header

                VStack(alignment: .leading, spacing: 18) {
                    overviewCard

                    if medications.isEmpty {
                        emptyState
                    } else {
                        ForEach(medications) { med in
                            medicationCard(med)
                        }
                    }

                    Color.clear
                        .frame(height: 120)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }

            if showAddMedicationPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddMedicationPopup = false
                        }
                    }

                addMedicationPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }

            if showEditMedicationPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showEditMedicationPopup = false
                        }
                    }

                editMedicationPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(11)
            }

            if showMedicationDetailsPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMedicationDetailsPopup = false
                        }
                    }

                medicationDetailsPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(12)
            }

            if showMedicationHistoryPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMedicationHistoryPopup = false
                        }
                    }

                medicationHistoryPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(13)
            }

            deleteMedicationConfirm
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Medications", font: .title2.bold())
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showAddMedicationPopup = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 6)
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image("handpill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Overview", size: 24)

                    Spacer()
                }

                HStack(spacing: 14) {
                    statBubble(
                        title: "Meds",
                        value: medications.count
                    )

                    statBubble(
                        title: "Reminders",
                        value: linkedReminderCount
                    )
                }
            }
        }
    }

    private func statBubble(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Medication Card

    private func medicationCard(_ med: Medication) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image("heartsum")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)

                            Text(med.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 8) {
                            if !med.dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                cardInfoPill(
                                    text: med.dosage,
                                    fill: Color(red: 0.03, green: 0.86, blue: 0.99).opacity(0.14)
                                )
                            }

                            if let refill = med.refillDate {
                                cardInfoPill(
                                    text: "Refill \(refill.formatted(date: .abbreviated, time: .omitted))",
                                    fill: Color(red: 0.49, green: 0.10, blue: 0.97).opacity(0.16)
                                )
                            } else {
                                cardInfoPill(
                                    text: "No refill date",
                                    fill: Color.white.opacity(0.08)
                                )
                            }
                        }
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 5)
                            .frame(width: 48, height: 48)

                        Circle()
                            .trim(from: 0, to: progress(for: med))
                            .stroke(
                                LGradients.blue,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 48, height: 48)

                        Text("\(med.currentAmount)/\(med.supplyAmount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        openDetailsPopup(for: med)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("dotsfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        openEditPopup(for: med)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("pencilcircle")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedMedication = med
                        showDeleteMedicationConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image("trashfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)

                            Text("Delete")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func progress(for med: Medication) -> CGFloat {
        guard med.supplyAmount > 0 else { return 0 }
        let raw = CGFloat(med.currentAmount) / CGFloat(med.supplyAmount)
        return min(max(raw, 0), 1)
    }

    private func cardInfoPill(text: String, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("No medications yet")
                    .foregroundStyle(.white)
                    .font(.headline)

                Text("Add your medications to start tracking doses and refills.")
                    .foregroundStyle(LColors.textSecondary)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private var addMedicationPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showAddMedicationPopup = false
                }
            },
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Add Medication", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    popupField(title: "Medication Name", text: $newMedicationName, keyboard: .default)
                    popupField(title: "Dosing", text: $newMedicationDosage, keyboard: .default)
                    popupField(title: "Current Amount", text: $newMedicationCurrentAmount, keyboard: .numberPad)
                    popupField(title: "Supply Amount", text: $newMedicationSupplyAmount, keyboard: .numberPad)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $includeRefillDate) {
                            Text("Include Refill Date")
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(LColors.accent)

                        if includeRefillDate {
                            DatePicker(
                                "Refill Date",
                                selection: $newMedicationRefillDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Cancel", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddMedicationPopup = false
                        }
                    }

                    LButton(title: "Save", style: .gradient) {
                        saveMedication()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private func popupField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            TextField("", text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
    }

    private func saveMedication() {
        let trimmedName = newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = newMedicationDosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentAmount = Int(newMedicationCurrentAmount) ?? 0
        let supplyAmount = Int(newMedicationSupplyAmount) ?? 0

        guard !trimmedName.isEmpty else { return }

        let medication = Medication(
            name: trimmedName,
            dosage: trimmedDosage,
            currentAmount: currentAmount,
            supplyAmount: supplyAmount,
            refillDate: includeRefillDate ? newMedicationRefillDate : nil
        )

        modelContext.insert(medication)

        newMedicationName = ""
        newMedicationDosage = ""
        newMedicationCurrentAmount = ""
        newMedicationSupplyAmount = ""
        newMedicationRefillDate = Date()
        includeRefillDate = false

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showAddMedicationPopup = false
        }
    }

    private var editMedicationPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showEditMedicationPopup = false
                    showDeleteMedicationConfirm = false
                }
            },
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Edit Medication", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    popupField(title: "Medication Name", text: $editMedicationName, keyboard: .default)
                    popupField(title: "Dosing", text: $editMedicationDosage, keyboard: .default)
                    popupField(title: "Current Amount", text: $editMedicationCurrentAmount, keyboard: .numberPad)
                    popupField(title: "Supply Amount", text: $editMedicationSupplyAmount, keyboard: .numberPad)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $editIncludeRefillDate) {
                            Text("Include Refill Date")
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(LColors.accent)

                        if editIncludeRefillDate {
                            DatePicker(
                                "Refill Date",
                                selection: $editMedicationRefillDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Close", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showEditMedicationPopup = false
                        }
                    }

                    LButton(title: "Save", style: .gradient) {
                        updateMedication()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private func openDetailsPopup(for medication: Medication) {
        selectedMedication = medication
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showMedicationDetailsPopup = true
        }
    }

    private func openEditPopup(for medication: Medication) {
        selectedMedication = medication
        editMedicationName = medication.name
        editMedicationDosage = medication.dosage
        editMedicationCurrentAmount = String(medication.currentAmount)
        editMedicationSupplyAmount = String(medication.supplyAmount)

        if let refillDate = medication.refillDate {
            editIncludeRefillDate = true
            editMedicationRefillDate = refillDate
        } else {
            editIncludeRefillDate = false
            editMedicationRefillDate = Date()
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showEditMedicationPopup = true
        }
    }

    private func updateMedication() {
        guard let medication = selectedMedication else { return }

        let trimmedName = editMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = editMedicationDosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentAmount = Int(editMedicationCurrentAmount) ?? 0
        let supplyAmount = Int(editMedicationSupplyAmount) ?? 0

        guard !trimmedName.isEmpty else { return }

        medication.name = trimmedName
        medication.dosage = trimmedDosage
        medication.currentAmount = currentAmount
        medication.supplyAmount = supplyAmount
        medication.refillDate = editIncludeRefillDate ? editMedicationRefillDate : nil
        medication.updatedAt = Date()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showEditMedicationPopup = false
            showDeleteMedicationConfirm = false
        }
    }

    private func deleteSelectedMedication() {
        guard let medication = selectedMedication else { return }
        modelContext.delete(medication)
        selectedMedication = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showEditMedicationPopup = false
            showMedicationDetailsPopup = false
            showMedicationHistoryPopup = false
            showDeleteMedicationConfirm = false
        }
    }

    private var medicationDetailsPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showMedicationDetailsPopup = false
                }
            },
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Medication Details", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    if let medication = selectedMedication {
                        detailRow(icon: "pilldrop", title: "Medication", value: medication.name)
                        detailRow(icon: "medicon", title: "Dosing", value: medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set" : medication.dosage)
                        detailRow(icon: "hashtag", title: "Current Amount", value: "\(medication.currentAmount)")
                        detailRow(icon: "hashtag", title: "Supply Amount", value: "\(medication.supplyAmount)")
                        detailRow(icon: "handpill", title: "Refill Date", value: medication.refillDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "Not set")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Close", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMedicationDetailsPopup = false
                        }
                    }

                    LButton(title: "History", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMedicationHistoryPopup = true
                        }
                    }

                    LButton(title: "Edit", style: .gradient) {
                        showMedicationDetailsPopup = false
                        if let medication = selectedMedication {
                            openEditPopup(for: medication)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private var medicationHistoryPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showMedicationHistoryPopup = false
                }
            },
            width: 560,
            heightRatio: 0.70,
            header: {
                GradientTitle(text: "Medication History", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    if let medication = selectedMedication {
                        let entries = (medication.historyEntries ?? []).sorted { $0.createdAt > $1.createdAt }

                        if entries.isEmpty {
                            GlassCard {
                                Text("No history yet")
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            ForEach(entries) { entry in
                                historyRow(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Close", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMedicationHistoryPopup = false
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LColors.textSecondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    private func historyRow(_ entry: MedicationHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image("fillcal")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.type.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LColors.textSecondary)

                if !entry.amountText.isEmpty {
                    Text(entry.amountText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                }

                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    private var linkedReminderCount: Int {
        reminders.filter {
            $0.linkedKind == .medication
        }.count
    }

    private var deleteMedicationConfirm: some View {
        Color.clear
            .lystariaAlertConfirm(
                isPresented: $showDeleteMedicationConfirm,
                title: "Delete Medication",
                message: "Are you sure you want to delete this medication?",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    deleteSelectedMedication()
                }
            )
    }
}
