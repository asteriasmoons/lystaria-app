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
    @StateObject private var limits = LimitManager.shared
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()

    @Query(sort: \Medication.createdAt, order: .forward)
    private var medications: [Medication]

    @Query private var reminders: [LystariaReminder]

    @State private var showAddMedicationPopup = false
    @State private var newMedicationName = ""
    @State private var newMedicationCurrentAmount = ""
    @State private var newMedicationSupplyAmount = ""
    @State private var newMedicationDaysSupply = ""
    @State private var newMedicationRefillDate = Date()
    @State private var includeRefillDate = false
    @State private var selectedMedication: Medication? = nil
    @State private var showEditMedicationPopup = false
    @State private var editMedicationName = ""
    @State private var editMedicationCurrentAmount = ""
    @State private var editMedicationSupplyAmount = ""
    @State private var editMedicationDaysSupply = ""
    @State private var editMedicationRefillDate = Date()
    @State private var editIncludeRefillDate = false
    @State private var showDeleteMedicationConfirm = false
    @State private var showMedicationDetailsPopup = false
    @State private var showMedicationHistoryPopup = false
    @State private var selectedHistoryEntry: MedicationHistoryEntry? = nil
    @State private var showDeleteHistoryConfirm = false
    @State private var showInventoryAdjustPopup = false
    @State private var inventoryDecreaseAmount = 1
    @State private var inventoryIncreaseAmount = 1

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
                        ForEach(Array(medications.enumerated()), id: \.element.id) { index, med in
                            medicationCard(med)
                                .premiumLocked(index >= (limits.limit(for: .medicationCardsTotal) ?? Int.max) && !limits.hasPremiumAccess)
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

            if showInventoryAdjustPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showInventoryAdjustPopup = false
                        }
                    }

                inventoryAdjustPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(14)
            }

            deleteMedicationConfirm
            deleteHistoryConfirm
        }
        .onAppear {
            processRefills()
        }
        .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
            ZStack {
                OnboardingOverlay(anchors: anchors)
                    .environmentObject(onboarding)
            }
            .task(id: anchors.count) {
                if anchors.count > 0 {
                    onboarding.start(page: OnboardingPages.medicine)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Medications", font: .title2.bold())
                Spacer()

                NavigationLink {
                    SymptomLoggerView()
                        .preferredColorScheme(.dark)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("medicon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .onboardingTarget("starIcon")

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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 8) {
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
                            if med.daysSupply > 0 {
                                cardInfoPill(
                                    text: "\(med.daysSupply)d supply",
                                    fill: Color(red: 0.03, green: 0.86, blue: 0.99).opacity(0.14)
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
                        ZStack {
                            Circle()
                                .fill(LGradients.blue)
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("fulltrashfill")
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
                        inventoryDecreaseAmount = 1
                        inventoryIncreaseAmount = 1
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showInventoryAdjustPopup = true
                        }
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
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
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
                    popupField(title: "Current Amount", text: $newMedicationCurrentAmount, keyboard: .numberPad)
                    popupField(title: "Supply Amount", text: $newMedicationSupplyAmount, keyboard: .numberPad)
                    popupField(title: "Days Supply", text: $newMedicationDaysSupply, keyboard: .numberPad)

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
        let currentAmount = Int(newMedicationCurrentAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let supplyAmount = Int(newMedicationSupplyAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let daysSupply = Int(newMedicationDaysSupply.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        guard !trimmedName.isEmpty else { return }
        let decision = limits.canCreate(.medicationCardsTotal, currentCount: medications.count)
        guard decision.allowed else { return }

        let medication = Medication(
            name: trimmedName,
            currentAmount: currentAmount,
            supplyAmount: supplyAmount,
            daysSupply: daysSupply,
            refillDate: includeRefillDate ? newMedicationRefillDate : nil
        )

        modelContext.insert(medication)

        newMedicationName = ""
        newMedicationCurrentAmount = ""
        newMedicationSupplyAmount = ""
        newMedicationDaysSupply = ""
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
                    popupField(title: "Current Amount", text: $editMedicationCurrentAmount, keyboard: .numberPad)
                    popupField(title: "Supply Amount", text: $editMedicationSupplyAmount, keyboard: .numberPad)
                    popupField(title: "Days Supply", text: $editMedicationDaysSupply, keyboard: .numberPad)

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
        editMedicationCurrentAmount = String(medication.currentAmount)
        editMedicationSupplyAmount = String(medication.supplyAmount)
        editMedicationDaysSupply = medication.daysSupply > 0 ? String(medication.daysSupply) : ""

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
        let currentAmount = Int(editMedicationCurrentAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let supplyAmount = Int(editMedicationSupplyAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let daysSupply = Int(editMedicationDaysSupply.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        guard !trimmedName.isEmpty else { return }

        medication.name = trimmedName
        medication.currentAmount = currentAmount
        medication.supplyAmount = supplyAmount
        medication.daysSupply = daysSupply
        medication.refillDate = editIncludeRefillDate ? editMedicationRefillDate : nil
        medication.lastAutoRefillDayKey = ""
        medication.updatedAt = Date()

        try? modelContext.save()
        processRefills()

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
            showInventoryAdjustPopup = false
            showDeleteMedicationConfirm = false
            showDeleteHistoryConfirm = false
        }
        selectedHistoryEntry = nil
    }

    private func adjustSelectedMedicationInventory(by amount: Int) {
        guard let medication = selectedMedication else { return }

        let previousAmount = medication.currentAmount
        let newAmount = max(0, medication.currentAmount + amount)
        medication.currentAmount = newAmount
        medication.updatedAt = Date()

        let historyEntry = MedicationHistoryEntry(
            type: .edited,
            amountText: "\(previousAmount) → \(newAmount)",
            details: amount >= 0 ? "Manual inventory increase" : "Manual inventory decrease",
            createdAt: Date(),
            medication: medication
        )
        modelContext.insert(historyEntry)
        try? modelContext.save()
    }

    private func fillSelectedMedicationToSupply() {
        guard let medication = selectedMedication else { return }

        let previousAmount = medication.currentAmount
        medication.currentAmount = max(0, medication.supplyAmount)
        medication.updatedAt = Date()

        let historyEntry = MedicationHistoryEntry(
            type: .refilled,
            amountText: "\(previousAmount) → \(medication.currentAmount)",
            details: "Set inventory to full supply",
            createdAt: Date(),
            medication: medication
        )
        modelContext.insert(historyEntry)
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
                        detailRow(icon: "hashtag", title: "Current Amount", value: "\(medication.currentAmount)")
                        detailRow(icon: "hashtag", title: "Supply Amount", value: "\(medication.supplyAmount)")
                        detailRow(icon: "hashtag", title: "Days Supply", value: medication.daysSupply > 0 ? "\(medication.daysSupply) days" : "Not set")
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
        .onLongPressGesture {
            selectedHistoryEntry = entry
            showDeleteHistoryConfirm = true
        }
    }
    private func deleteSelectedHistoryEntry() {
        guard let entry = selectedHistoryEntry else { return }
        modelContext.delete(entry)
        selectedHistoryEntry = nil
        showDeleteHistoryConfirm = false
    }


    private var linkedReminderCount: Int {
        reminders.filter {
            $0.linkedKind == .medication
        }.count
    }

    private func processRefills() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayKey = fmt.string(from: today)

        for medication in medications {
            guard medication.isActive,
                  let refillDate = medication.refillDate,
                  cal.startOfDay(for: refillDate) <= today,
                  medication.lastAutoRefillDayKey != todayKey
            else { continue }

            let previousAmount = medication.currentAmount
            medication.currentAmount = max(0, medication.supplyAmount)
            medication.lastAutoRefillDayKey = todayKey
            medication.updatedAt = Date()

            if medication.daysSupply > 0 {
                medication.refillDate = cal.date(
                    byAdding: .day,
                    value: medication.daysSupply,
                    to: cal.startOfDay(for: refillDate)
                )
            }

            let historyEntry = MedicationHistoryEntry(
                type: .refilled,
                amountText: "\(previousAmount) \u{2192} \(medication.currentAmount)",
                details: medication.daysSupply > 0
                    ? "Auto-refilled on refill date. Next refill in \(medication.daysSupply) days."
                    : "Auto-refilled on refill date.",
                createdAt: Date(),
                medication: medication
            )
            modelContext.insert(historyEntry)
        }
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

    private var deleteHistoryConfirm: some View {
        Color.clear
            .lystariaAlertConfirm(
                isPresented: $showDeleteHistoryConfirm,
                title: "Delete History Record",
                message: "Are you sure you want to delete this medication history record?",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    deleteSelectedHistoryEntry()
                }
            )
    }

    private var inventoryAdjustPopup: some View {
        Group {
            if let medication = selectedMedication {
                InventoryAdjustPopup(
                    medication: medication,
                    decreaseAmount: $inventoryDecreaseAmount,
                    increaseAmount: $inventoryIncreaseAmount,
                    onDecrement: { adjustSelectedMedicationInventory(by: -1) },
                    onIncrement: { adjustSelectedMedicationInventory(by: 1) },
                    onApplyDecrease: { adjustSelectedMedicationInventory(by: -inventoryDecreaseAmount) },
                    onApplyIncrease: { adjustSelectedMedicationInventory(by: inventoryIncreaseAmount) },
                    onSetFull: { fillSelectedMedicationToSupply() },
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showInventoryAdjustPopup = false
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Inventory Adjust Popup

private struct InventoryAdjustPopup: View {
    let medication: Medication
    @Binding var decreaseAmount: Int
    @Binding var increaseAmount: Int
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    let onApplyDecrease: () -> Void
    let onApplyIncrease: () -> Void
    let onSetFull: () -> Void
    let onClose: () -> Void

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 560,
            heightRatio: 0.72,
            header: {
                GradientTitle(text: "Adjust Inventory", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {

                    inventoryInfoBubble(icon: "heartsum", title: "MEDICATION", value: medication.name)

                    inventoryInfoBubble(icon: "hashtag", title: "CURRENT INVENTORY", value: "\(medication.currentAmount)")

                    inventoryInfoBubble(icon: "handpill", title: "SUPPLY AMOUNT", value: "\(medication.supplyAmount)")

                    VStack(alignment: .leading, spacing: 14) {
                        Text("STEP AMOUNTS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LColors.textSecondary)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("INCREASE AMOUNT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)

                            HStack(spacing: 12) {
                                Button {
                                    if increaseAmount > 1 { increaseAmount -= 1 }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Text("+\(increaseAmount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))

                                Button {
                                    if increaseAmount < 100 { increaseAmount += 1 }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(LColors.accent.opacity(0.85))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("DECREASE AMOUNT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)

                            HStack(spacing: 12) {
                                Button {
                                    if decreaseAmount > 1 { decreaseAmount -= 1 }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Text("-\(decreaseAmount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))

                                Button {
                                    if decreaseAmount < 100 { decreaseAmount += 1 }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(LColors.accent.opacity(0.85))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                WrappingHStack(spacing: 12, lineSpacing: 12) {
                    Button { onDecrement() } label: {
                        Text("-1")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onIncrement() } label: {
                        Text("+1")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onSetFull() } label: {
                        Text("Set Full")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onApplyDecrease() } label: {
                        Text("Apply -\(decreaseAmount)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onApplyIncrease() } label: {
                        Text("Apply +\(increaseAmount)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onClose() } label: {
                        Text("Close")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private func inventoryInfoBubble(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LColors.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
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

private struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        WrappingLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

private struct WrappingLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [WrappingRow] {
        var rows: [WrappingRow] = []
        var currentItems: [WrappingItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = currentItems.isEmpty ? size.width : size.width + spacing

            if !currentItems.isEmpty && currentWidth + itemWidth > maxWidth {
                rows.append(WrappingRow(items: currentItems, height: currentHeight))
                currentItems = [WrappingItem(subview: subview, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(WrappingItem(subview: subview, size: size))
                currentWidth += itemWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(WrappingRow(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct WrappingItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct WrappingRow {
        let items: [WrappingItem]
        let height: CGFloat
    }
}
