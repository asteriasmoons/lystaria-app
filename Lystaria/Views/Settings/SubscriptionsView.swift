//
// SubscriptionsView.swift
// Lystaria
//
// Created by Asteria Moon
//

import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subscription.nextDueDate, order: .forward) private var subscriptions: [Subscription]

    @State private var showAddSheet = false
    @State private var editingSubscription: Subscription? = nil

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        GradientTitle(text: "Subscriptions", size: 28)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image("xmark")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(LColors.textSecondary)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // MARK: - Content
                ScrollView {
                    VStack(spacing: LSpacing.sectionGap) {
                        if subscriptions.isEmpty {
                            emptyState
                        } else {
                            summaryCard
                            subscriptionList
                        }
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 100)
                }
            }

            // MARK: - FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LGradients.blue)
                                .frame(width: 54, height: 54)
                                .shadow(color: LColors.gradientPurple.opacity(0.45), radius: 12, y: 6)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showAddSheet) {
            SubscriptionFormView(subscription: nil) { sub in
                createReminder(for: sub)
            }
        }
        .sheet(item: $editingSubscription) { sub in
            SubscriptionFormView(subscription: sub) { updated in
                updateReminder(for: updated)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("pigbankfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                    Text("MONTHLY OVERVIEW")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(1.2)
                }

                Rectangle().fill(LColors.glassBorder).frame(height: 1)

                HStack(spacing: 0) {
                    summaryItem(label: "Monthly", value: formattedCost(monthlyCost))
                    Divider().background(LColors.glassBorder).frame(height: 36)
                    summaryItem(label: "Yearly", value: formattedCost(yearlyCost))
                    Divider().background(LColors.glassBorder).frame(height: 36)
                    summaryItem(label: "Total", value: "\(subscriptions.count)")
                }
            }
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subscription List

    private var subscriptionList: some View {
        VStack(alignment: .leading, spacing: LSpacing.sectionGap) {
            ForEach(SubscriptionKind.allCases, id: \.self) { kind in
                let group = subscriptions.filter { $0.subscriptionKind == kind }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: kind.label, icon: kind == .online ? "coinsfill" : kind == .membership ? "walletfill" : "handmoney", isAsset: true)

                        VStack(spacing: 10) {
                            ForEach(group, id: \.persistentModelID) { sub in
                                SubscriptionCard(subscription: sub) {
                                    editingSubscription = sub
                                } onDelete: {
                                    deleteSubscription(sub)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image("coinsfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(LColors.textSecondary)

                VStack(spacing: 6) {
                    Text("No subscriptions yet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                    Text("Tap + to add your first subscription.\nA reminder will be created automatically.")
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Cost Calculations

    private var monthlyCost: Double {
        subscriptions.reduce(0.0) { total, sub in
            switch sub.billingCycle {
            case .weekly:  return total + (sub.cost * 52.0 / 12.0)
            case .monthly: return total + sub.cost
            case .yearly:  return total + (sub.cost / 12.0)
            }
        }
    }

    private var yearlyCost: Double {
        subscriptions.reduce(0.0) { total, sub in
            switch sub.billingCycle {
            case .weekly:  return total + (sub.cost * 52.0)
            case .monthly: return total + (sub.cost * 12.0)
            case .yearly:  return total + sub.cost
            }
        }
    }

    private func formattedCost(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
    }

    private func reminderDetails(for sub: Subscription) -> String? {
        let desc = sub.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost = sub.cost > 0 ? formattedCost(sub.cost) : ""
        let parts = [desc, cost].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Reminder Creation

    private func createReminder(for sub: Subscription) {
        modelContext.insert(sub)

        let cal = Calendar.current
        let timeComponents = cal.dateComponents([.hour, .minute], from: sub.reminderTime)
        var dueDateComponents = cal.dateComponents([.year, .month, .day], from: sub.nextDueDate)
        dueDateComponents.hour = timeComponents.hour
        dueDateComponents.minute = timeComponents.minute
        let fireDate = cal.date(from: dueDateComponents) ?? sub.nextDueDate

        var schedule = ReminderSchedule(kind: sub.billingCycle.scheduleKind)
        let hh = String(format: "%02d", timeComponents.hour ?? 9)
        let mm = String(format: "%02d", timeComponents.minute ?? 0)
        schedule.timeOfDay = "\(hh):\(mm)"

        switch sub.billingCycle {
        case .weekly:
            schedule.daysOfWeek = [cal.component(.weekday, from: sub.nextDueDate) - 1]
        case .monthly:
            schedule.dayOfMonth = cal.component(.day, from: sub.nextDueDate)
        case .yearly:
            schedule.anchorMonth = cal.component(.month, from: sub.nextDueDate)
            schedule.anchorDay   = cal.component(.day,   from: sub.nextDueDate)
        }

        let reminder = LystariaReminder(
            title: sub.name,
            details: reminderDetails(for: sub),
            status: .scheduled,
            nextRunAt: fireDate,
            schedule: schedule,
            timezone: TimeZone.current.identifier,
            linkedKind: .subscription,
            linkedSubscriptionId: sub.id
        )
        modelContext.insert(reminder)

        sub.linkedReminderNotificationID = reminder.notificationID
        sub.updatedAt = Date()

        try? modelContext.save()
        NotificationManager.shared.scheduleReminder(reminder)
    }

    private func updateReminder(for sub: Subscription) {
        sub.updatedAt = Date()

        // Find the linked reminder by notificationID and update it
        let nid = sub.linkedReminderNotificationID
        if !nid.isEmpty {
            let descriptor = FetchDescriptor<LystariaReminder>()
            if let reminders = try? modelContext.fetch(descriptor),
               let reminder = reminders.first(where: { $0.notificationID == nid }) {

                let cal = Calendar.current
                let timeComponents = cal.dateComponents([.hour, .minute], from: sub.reminderTime)
                var dueDateComponents = cal.dateComponents([.year, .month, .day], from: sub.nextDueDate)
                dueDateComponents.hour = timeComponents.hour
                dueDateComponents.minute = timeComponents.minute
                let fireDate = cal.date(from: dueDateComponents) ?? sub.nextDueDate

                reminder.title = sub.name
                reminder.details = reminderDetails(for: sub)
                reminder.nextRunAt = fireDate
                reminder.updatedAt = Date()

                var schedule = ReminderSchedule(kind: sub.billingCycle.scheduleKind)
                let hh = String(format: "%02d", timeComponents.hour ?? 9)
                let mm = String(format: "%02d", timeComponents.minute ?? 0)
                schedule.timeOfDay = "\(hh):\(mm)"

                switch sub.billingCycle {
                case .weekly:
                    schedule.daysOfWeek = [cal.component(.weekday, from: sub.nextDueDate) - 1]
                case .monthly:
                    schedule.dayOfMonth = cal.component(.day, from: sub.nextDueDate)
                case .yearly:
                    schedule.anchorMonth = cal.component(.month, from: sub.nextDueDate)
                    schedule.anchorDay   = cal.component(.day,   from: sub.nextDueDate)
                }
                reminder.schedule = schedule

                NotificationManager.shared.cancelReminder(reminder)
                NotificationManager.shared.scheduleReminder(reminder)
            }
        }

        try? modelContext.save()
    }

    private func deleteSubscription(_ sub: Subscription) {
        let nid = sub.linkedReminderNotificationID
        if !nid.isEmpty {
            let descriptor = FetchDescriptor<LystariaReminder>()
            if let reminders = try? modelContext.fetch(descriptor),
               let reminder = reminders.first(where: { $0.notificationID == nid }) {
                NotificationManager.shared.cancelReminder(reminder)
                modelContext.delete(reminder)
            }
        }
        modelContext.delete(sub)
        try? modelContext.save()
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let subscription: Subscription
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(subscription.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)

                    if !subscription.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(subscription.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.4)
                    }

                    HStack(spacing: 8) {
                        cycleBadge
                        Text(dueDateLabel)
                            .font(.caption)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(formattedCost)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)

                    Menu {
                        Button("Edit") { onEdit() }
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cycleBadge: some View {
        Text(subscription.billingCycle.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .tracking(0.4)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(LColors.gradientPurple.opacity(0.28))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LColors.gradientPurple.opacity(0.45), lineWidth: 1))
    }

    private var dueDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Due \(formatter.string(from: subscription.nextDueDate))"
    }

    private var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: subscription.cost)) ?? "$\(String(format: "%.2f", subscription.cost))"
    }
}

// MARK: - Subscription Form

struct SubscriptionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?
    let onSave: (Subscription) -> Void

    @State private var name: String = ""
    @State private var costText: String = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var subscriptionKind: SubscriptionKind = .app
    @State private var nextDueDate: Date = Date()
    @State private var reminderTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var category: String = ""
    @State private var descriptionText: String = ""
    @State private var notes: String = ""

    private var isEditing: Bool { subscription != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        GradientTitle(text: isEditing ? "Edit Subscription" : "New Subscription", size: 24)
                        Spacer()
                        Button { dismiss() } label: {
                            Image("xmark")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(LColors.textSecondary)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Rectangle().fill(LColors.glassBorder).frame(height: 1)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LSpacing.sectionGap) {
                        basicSection
                        billingSection
                        scheduleSection
                        detailsSection
                        saveButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear { populateIfEditing() }
    }

    // MARK: - Basic Section

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Basic Info", icon: "walletfill", isAsset: true)

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    formField(label: "NAME") {
                        TextField("e.g. Netflix", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    divider

                    formField(label: "DESCRIPTION") {
                        TextField("What is this subscription for?", text: $descriptionText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(2...4)
                    }

                    divider

                    formField(label: "COST") {
                        TextField("0.00", text: $costText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .keyboardType(.decimalPad)
                    }

                    divider

                    formField(label: "CATEGORY") {
                        TextField("e.g. Entertainment", text: $category)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Billing Section

    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Billing", icon: "cardfill", isAsset: true)

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    formField(label: "BILLING CYCLE") {
                        Picker("", selection: $billingCycle) {
                            ForEach(BillingCycle.allCases, id: \.self) { cycle in
                                Text(cycle.label).tag(cycle)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    divider

                    formField(label: "TYPE") {
                        Picker("", selection: $subscriptionKind) {
                            ForEach(SubscriptionKind.allCases, id: \.self) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Schedule", icon: "alarmfill", isAsset: true)

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    formField(label: "NEXT DUE DATE") {
                        DatePicker("", selection: $nextDueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(LColors.accent)
                    }

                    divider

                    formField(label: "REMINDER TIME") {
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(LColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Notes", icon: "notesfill", isAsset: true)

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    formField(label: "NOTES") {
                        TextField("Optional notes…", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(3...6)
                    }
                }
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(isEditing ? "Save Changes" : "Add Subscription")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? LGradients.blue : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var divider: some View {
        Rectangle().fill(LColors.glassBorder).frame(height: 1)
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.6)
            content()
        }
    }

    private func populateIfEditing() {
        guard let sub = subscription else { return }
        name             = sub.name
        costText         = sub.cost > 0 ? String(format: "%.2f", sub.cost) : ""
        billingCycle     = sub.billingCycle
        subscriptionKind = sub.subscriptionKind
        nextDueDate      = sub.nextDueDate
        reminderTime     = sub.reminderTime
        category         = sub.category
        descriptionText  = sub.descriptionText
        notes            = sub.notes
    }

    private func save() {
        let cost = Double(costText.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        if let sub = subscription {
            sub.name             = name.trimmingCharacters(in: .whitespacesAndNewlines)
            sub.cost             = cost
            sub.billingCycle     = billingCycle
            sub.subscriptionKind = subscriptionKind
            sub.nextDueDate      = nextDueDate
            sub.reminderTime     = reminderTime
            sub.category         = category.trimmingCharacters(in: .whitespacesAndNewlines)
            sub.descriptionText  = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            sub.notes            = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(sub)
        } else {
            let sub = Subscription(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                cost: cost,
                billingCycle: billingCycle,
                subscriptionKind: subscriptionKind,
                nextDueDate: nextDueDate,
                reminderTime: reminderTime,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSave(sub)
        }
        dismiss()
    }
}

#Preview {
    SubscriptionsView()
        .preferredColorScheme(.dark)
}
