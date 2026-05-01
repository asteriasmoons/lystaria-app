// RemindersView.swift
// Lystaria

import SwiftData
import SwiftUI
import UIKit

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Query private var authUsers: [AuthUser]
    @Query private var habits: [Habit]
    @Query private var events: [CalendarEvent]
    @Query private var medications: [Medication]
    @Query(sort: \LystariaReminder.nextRunAt) private var allReminders: [LystariaReminder]

    @State private var showNewReminder = false
    @State private var filter = "all"
    @State private var visibleCount: Int = 5
    @State private var showKanban = false
    @State private var showTimeBlock = false

    /// Onboarding
    @StateObject private var onboarding = OnboardingManager()

    /// Editing
    @State private var editingReminder: LystariaReminder? = nil

    /// Detail popup
    @State private var detailReminder: LystariaReminder? = nil
    @State private var showingDetailPopup = false

    /// Completion toast
    @State private var toastMessage: String? = nil

    private let filterOptions = ["all", "once", "daily", "weekly", "monthly", "yearly", "interval"]

    private var greeting: String {
        let name = (authUsers.first?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Your Reminders" }
        return "\(name)’s Reminders"
    }

    private var filtered: [LystariaReminder] {
        let active = allReminders.filter { $0.status != .deleted }
        if filter == "all" { return active }
        return active.filter { r in
            let kind = r.schedule?.kind.rawValue ?? "once"
            return kind == filter
        }
    }

    private var visibleReminders: [LystariaReminder] {
        Array(filtered.prefix(visibleCount))
    }

    /// Returns the number of fire times this reminder has scheduled on `date`,
    /// based on its schedule kind and timesOfDay list.
    /// For once / interval reminders, returns 1 if nextRunAt falls on that date, else 0.
    private func fireTimesToday(_ reminder: LystariaReminder, on date: Date = Date()) -> Int {
        let cal = ReminderCompute.tzCalendar
        guard let schedule = reminder.schedule, reminder.status != .deleted else { return 0 }

        switch schedule.kind {
        case .once:
            return cal.isDate(reminder.nextRunAt, inSameDayAs: date) ? 1 : 0

        case .interval:
            guard cal.isDate(reminder.nextRunAt, inSameDayAs: date) || isCompletedToday(reminder) else { return 0 }

            guard reminder.linkedKind == .habit,
                  let habitId = reminder.linkedHabitId,
                  let habit = habits.first(where: { $0.id == habitId }) else {
                return 1
            }

            let intervalMinutes: Int
            if habit.reminderKind == .everyXHours {
                intervalMinutes = max(1, habit.reminderIntervalHours) * 60
            } else if habit.reminderKind == .everyXMinutes {
                intervalMinutes = max(1, habit.reminderIntervalMinutes)
            } else {
                return 1
            }

            guard let (startH, startM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
                  let (endH, endM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd) else {
                return 1
            }

            let startTotalMinutes = startH * 60 + startM
            let endTotalMinutes = endH * 60 + endM
            guard endTotalMinutes >= startTotalMinutes else { return 1 }

            return max(1, ((endTotalMinutes - startTotalMinutes) / intervalMinutes) + 1)

        case .daily, .weekly, .monthly, .yearly:
            // Only count if nextRunAt is today OR the reminder was completed today
            // (meaning it fired today and nextRunAt has since advanced).
            let firesOrFiredToday = cal.isDate(reminder.nextRunAt, inSameDayAs: date) || isCompletedToday(reminder)
            guard firesOrFiredToday else { return 0 }

            let times = (schedule.timesOfDay?.isEmpty == false)
                ? (schedule.timesOfDay ?? [])
                : (schedule.timeOfDay != nil ? [schedule.timeOfDay!] : [])
            return times.isEmpty ? 0 : times.count
        }
    }

    // MARK: - Overview Counts

    private var totalRemindersCount: Int {
        allReminders.count
    }

    private var upcomingTodayCount: Int {
        let cal = ReminderCompute.tzCalendar
        let now = Date()
        let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!

        return allReminders
            .filter { $0.status != .deleted }
            .filter { $0.nextRunAt >= now && $0.nextRunAt < endOfDay }
            .reduce(0) { sum, reminder in
                guard let schedule = reminder.schedule else { return sum + 1 }

                if schedule.kind == .interval {
                    guard reminder.linkedKind == .habit,
                          let habitId = reminder.linkedHabitId,
                          let habit = habits.first(where: { $0.id == habitId }) else {
                        return sum + 1
                    }

                    let intervalMinutes: Int
                    if habit.reminderKind == .everyXHours {
                        intervalMinutes = max(1, habit.reminderIntervalHours) * 60
                    } else if habit.reminderKind == .everyXMinutes {
                        intervalMinutes = max(1, habit.reminderIntervalMinutes)
                    } else {
                        return sum + 1
                    }

                    guard let (startH, startM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
                          let (endH, endM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd) else {
                        return sum + 1
                    }

                    let nextHH = cal.component(.hour, from: reminder.nextRunAt)
                    let nextMM = cal.component(.minute, from: reminder.nextRunAt)
                    let nextTotalMinutes = nextHH * 60 + nextMM
                    let startTotalMinutes = startH * 60 + startM
                    let endTotalMinutes = endH * 60 + endM

                    guard endTotalMinutes >= startTotalMinutes else { return sum + 1 }
                    guard nextTotalMinutes >= startTotalMinutes && nextTotalMinutes <= endTotalMinutes else {
                        return sum
                    }

                    let remaining = ((endTotalMinutes - nextTotalMinutes) / intervalMinutes) + 1
                    return sum + max(1, remaining)
                }

                if schedule.kind == .once {
                    return sum + 1
                }

                let times = (schedule.timesOfDay?.isEmpty == false)
                    ? (schedule.timesOfDay ?? [])
                    : (schedule.timeOfDay != nil ? [schedule.timeOfDay!] : [])
                if times.isEmpty { return sum + 1 }

                let nextHH = cal.component(.hour, from: reminder.nextRunAt)
                let nextMM = cal.component(.minute, from: reminder.nextRunAt)
                let remaining = times.compactMap { ReminderCompute.parseHHMM($0) }
                    .count(where: { $0.0 > nextHH || ($0.0 == nextHH && $0.1 >= nextMM) })

                return sum + max(1, remaining)
            }
    }

    private var totalTodayCount: Int {
        allReminders
            .filter { $0.status != .deleted }
            .reduce(0) { $0 + fireTimesToday($1) }
    }

    private var doneTodayCount: Int {
        let cal = Calendar.current
        return allReminders
            .filter { $0.status != .deleted }
            .reduce(0) { sum, reminder in
                // Primary: timestamp array populated by incrementCompletionsToday
                let timestamps = decodeCompletionTimestamps(reminder)
                let todayCount = timestamps.filter { cal.isDateInToday($0) }.count
                if todayCount > 0 { return sum + todayCount }

                // Fallback: completed before new tracking existed.
                // Only count if lastCompletedAt is today AND nextRunAt is also today
                // (or reminder is one-time and was just completed).
                // This prevents overdue-from-yesterday completions from counting.
                guard let completedAt = reminder.lastCompletedAt,
                      cal.isDateInToday(completedAt) else { return sum }

                // For recurring reminders: nextRunAt has advanced past today's occurrence.
                // We can't recover the original occurrence date, so skip the fallback
                // for recurring reminders entirely — the new timestamp system handles
                // these going forward.
                if reminder.isRecurring { return sum }

                // One-time reminders: safe to count via lastCompletedAt
                return sum + 1
            }
    }

    private func isCompletedToday(_ reminder: LystariaReminder) -> Bool {
        guard let completedAt = reminder.lastCompletedAt else { return false }
        return Calendar.current.isDateInToday(completedAt)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                mainContent
                toastOverlay

                if showingDetailPopup, let r = detailReminder {
                    detailPopup(reminder: r)
                        .zIndex(100)
                }

                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let decision = limits.canCreate(.remindersTotal, currentCount: allReminders.count)
                            guard decision.allowed else { return }
                            showNewReminder = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LGradients.blue)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: LColors.accent.opacity(0.4), radius: 12, y: 4)
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
                .zIndex(50)
                .ignoresSafeArea(edges: .bottom)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastMessage)
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                ZStack {
                    OnboardingOverlay(anchors: anchors)
                        .environmentObject(onboarding)
                }
                .task(id: anchors.count) {
                    if anchors.count > 0 {
                        onboarding.start(page: OnboardingPages.reminders)
                    }
                }
            }
            .fullScreenCover(isPresented: $showNewReminder) {
                NewReminderSheet(onClose: {
                    showNewReminder = false
                })
                .preferredColorScheme(.dark)
            }
            .fullScreenCover(item: $editingReminder) { r in
                EditReminderSheet(
                    onClose: { editingReminder = nil },
                    reminder: r,
                )
                .preferredColorScheme(.dark)
            }
            .navigationDestination(isPresented: $showKanban) {
                KanbanView()
                    .preferredColorScheme(.dark)
            }
            .navigationDestination(isPresented: $showTimeBlock) {
                ReminderTimeBlockView(onMarkDone: { reminder in
                                markDoneFromTimeBlock(reminder)
                            })
                            .preferredColorScheme(.dark)
                        }
            .onReceive(NotificationCenter.default.publisher(for: .lystariaNotificationAction)) { note in
                guard let info = note.userInfo,
                      let actionID = info["actionID"] as? String,
                      actionID == NotificationManager.doneActionID,
                      let userInfo = info["userInfo"] as? [String: Any] else { return }

                let reminderID = userInfo["reminderID"] as? String

                let match = allReminders
                    .filter { r in
                        guard let rid = reminderID else { return false }
                        return String(describing: r.persistentModelID) == rid || String(describing: r.id) == rid
                    }
                    .first

                if let reminder = match {
                    markDone(reminder)
                } else {
                    print("[RemindersView] Could not resolve reminder action for reminderID=\(reminderID ?? "nil")")
                }
            }
            .onChange(of: filter) { _, _ in
                visibleCount = 5
            }
            .onChange(of: showNewReminder) { _, newValue in
                if newValue == false {
                    visibleCount = 5
                }
            }
            .onAppear {
                visibleCount = 5
                showKanban = false
            }
        }
    }

    private var mainContent: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    filtersSection
                    overviewSection
                    remindersSection
                    Spacer(minLength: 96)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
                .frame(width: proxy.size.width, alignment: .topLeading)
            }
            .clipped()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: greeting, font: .title.bold())
                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showTimeBlock = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .frame(width: 34, height: 34)

                            Image("fillalarm")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("clockIcon")

                    Button {
                        showKanban = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .frame(width: 34, height: 34)

                            Image("blocksfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("boardIcon")
                }
            }
            .padding(.top, 24)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 12)
        }
    }

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { opt in
                    let on = filter == opt
                    Button { filter = opt } label: {
                        Text(opt.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? .white : LColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(on ? LColors.accent : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var encouragingOverviewText: String {
        if doneTodayCount > 0 {
            return "You've completed \(doneTodayCount) reminder\(doneTodayCount == 1 ? "" : "s") today. Keep going."
        }
        if totalTodayCount > 0 {
            return "You have \(totalTodayCount) reminder\(totalTodayCount == 1 ? "" : "s") scheduled for today."
        }
        return "You're all caught up for now."
    }

    private var overviewSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image("bellfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Overview", font: .title3.bold())

                    Spacer()
                }

                Text(encouragingOverviewText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.top, -2)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8,
                ) {
                    OverviewStatCard(value: upcomingTodayCount, label: "Upcoming Today")
                    OverviewStatCard(value: doneTodayCount, label: "Done Today")
                    OverviewStatCard(value: totalTodayCount, label: "Total Today")
                    OverviewStatCard(value: totalRemindersCount, label: "Total Reminders")
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(spacing: 14) {
            if filtered.isEmpty {
                GlassCard {
                    Text("No reminders yet.")
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            } else {
                ForEach(Array(visibleReminders.enumerated()), id: \.element.persistentModelID) { index, reminder in
                    let id = reminder.persistentModelID
                    ReminderCard(
                        reminder: reminder,
                        linkedHabit: reminder.linkedKind == .habit
                            ? habits.first(where: { $0.id == reminder.linkedHabitId })
                            : nil,
                        onDone: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                markDone(live)
                            }
                        },
                        onSnooze: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                snooze(live, minutes: $0)
                            }
                        },
                        onEdit: { editingReminder = reminder },
                        onDelete: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                delete(live)
                            }
                        },
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                detailReminder = reminder
                                showingDetailPopup = true
                            }
                        },
                    )
                    .premiumLocked(!limits.hasPremiumAccess && index >= (limits.limit(for: .remindersTotal) ?? Int.max))
                }

                if filtered.count > (limits.limit(for: .remindersTotal) ?? 0) {
                    HStack {
                        Text("Showing \(min(visibleCount, filtered.count)) of \(filtered.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                    }
                    .padding(.top, 2)

                    if visibleCount < filtered.count {
                        LoadMoreButton {
                            visibleCount += 5
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = toastMessage {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LColors.success)
                    Text(msg)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(LColors.accentGradient)
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#7d19f7").opacity(0.5), radius: 16, y: 4)
                .padding(.bottom, 110)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(99)
        }
    }

    private func logHabitProgressFromReminder(_ reminder: LystariaReminder, in modelContext: ModelContext) {
        guard reminder.linkedKind == .habit,
              let habitId = reminder.linkedHabitId else { return }

        let descriptor = FetchDescriptor<Habit>()
        guard let habit = ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId }) else {
            return
        }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        // For interval-based habits the real daily target is derived from the window ÷ interval,
        // NOT from habit.timesPerDay (which stores the base value and may be stale / 1).
        let cap: Int
        let kind = habit.reminderKind
        if kind == .everyXHours || kind == .everyXMinutes {
            let intervalMins: Int
            if kind == .everyXHours {
                intervalMins = max(1, habit.reminderIntervalHours) * 60
            } else {
                intervalMins = max(1, habit.reminderIntervalMinutes)
            }
            if !habit.reminderIntervalWindowStart.isEmpty,
               !habit.reminderIntervalWindowEnd.isEmpty,
               let (wsH, wsM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
               let (weH, weM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd) {
                let windowMins = (weH * 60 + weM) - (wsH * 60 + wsM)
                cap = windowMins > 0 ? max(1, (windowMins / intervalMins) + 1) : max(1, habit.timesPerDay)
            } else {
                cap = max(1, habit.timesPerDay)
            }
        } else {
            cap = max(1, habit.timesPerDay)
        }

        if let existingSkip = (habit.skips ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
        }

        if let existingLog = (habit.logs ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
            if existingLog.count < cap {
                existingLog.count += 1
                habit.updatedAt = Date()

                _ = try? SelfCarePointsManager.awardHabitLog(
                    in: modelContext,
                    habitLogId: existingLog.id.uuidString,
                    title: habit.title,
                    loggedAt: Date()
                )
            }
        } else {
            let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
            modelContext.insert(newLog)

            if habit.logs == nil {
                habit.logs = [newLog]
            } else {
                habit.logs?.append(newLog)
            }

            habit.updatedAt = Date()

            _ = try? SelfCarePointsManager.awardHabitLog(
                in: modelContext,
                habitLogId: newLog.id.uuidString,
                title: habit.title,
                loggedAt: Date()
            )
        }
    }

    private func logMedicationIfLinked(_ reminder: LystariaReminder) {
        if reminder.reminderType == .routine {
            for link in reminder.sortedMedicationLinks {
                guard let medicationId = link.medicationId,
                      let medication = medications.first(where: { $0.id == medicationId })
                else {
                    continue
                }

                let quantity = max(1, link.effectiveQuantity())
                let previousAmount = medication.currentAmount

                if medication.currentAmount > 0 {
                    medication.currentAmount = max(0, medication.currentAmount - quantity)
                }

                medication.lastTakenAt = Date()
                medication.updatedAt = Date()

                let historyEntry = MedicationHistoryEntry(
                    type: .taken,
                    amountText: "\(previousAmount) → \(medication.currentAmount)",
                    details: "\(reminder.title) • Qty \(quantity)",
                    createdAt: Date(),
                    medication: medication,
                )
                modelContext.insert(historyEntry)
            }
            return
        }

        guard reminder.linkedKind == .medication,
              let mid = reminder.linkedMedicationId,
              let medication = medications.first(where: { $0.id == mid }) else { return }

        let quantity = max(1, reminder.linkedMedicationQuantity)
        let previousAmount = medication.currentAmount

        if medication.currentAmount > 0 {
            medication.currentAmount = max(0, medication.currentAmount - quantity)
        }

        medication.lastTakenAt = Date()
        medication.updatedAt = Date()

        let historyEntry = MedicationHistoryEntry(
            type: .taken,
            amountText: "\(previousAmount) → \(medication.currentAmount)",
            details: "\(reminder.title) • Qty \(quantity)",
            createdAt: Date(),
            medication: medication,
        )
        modelContext.insert(historyEntry)
    }

    private func awardPointsForReminderCompletion(_ reminder: LystariaReminder, occurrenceDate: Date) {
        let reminderId = "\(reminder.persistentModelID)"
        let occurrenceDayKey = SelfCarePointsManager.dayKey(from: occurrenceDate)
        let isEventReminder = events.contains { $0.reminderServerId == reminderId }

        if reminder.linkedKind == .habit {
            _ = try? SelfCarePointsManager.awardHabitReminderCompletion(
                in: modelContext,
                reminderId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        } else if isEventReminder {
            _ = try? SelfCarePointsManager.awardEventReminderCompletion(
                in: modelContext,
                eventId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        } else {
            _ = try? SelfCarePointsManager.awardReminderCompletion(
                in: modelContext,
                reminderId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        }
    }


    private func incrementCompletionsToday(_ reminder: LystariaReminder, occurrenceDate: Date) {
        let cal = Calendar.current
        var timestamps = decodeCompletionTimestamps(reminder)
        // Drop entries not from today
        timestamps = timestamps.filter { cal.isDateInToday($0) }
        // Only count this completion if the occurrence itself was scheduled for today
        guard cal.isDateInToday(occurrenceDate) else { return }
        timestamps.append(occurrenceDate)
        reminder.completionTimestampsStorage = encodeCompletionTimestamps(timestamps)
    }

    private func decodeCompletionTimestamps(_ reminder: LystariaReminder) -> [Date] {
        guard let data = reminder.completionTimestampsStorage.data(using: .utf8),
              let intervals = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return intervals.map { Date(timeIntervalSince1970: $0) }
    }

    private func encodeCompletionTimestamps(_ dates: [Date]) -> String {
        let intervals = dates.map(\.timeIntervalSince1970)
        let data = try? JSONEncoder().encode(intervals)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    // Anchored interval advancement: always advances from the previous completed occurrence,
    // staying aligned to the interval grid within the window.
    private func nextAnchoredIntervalRun(
        afterCompletedOccurrence completedOccurrenceDate: Date,
        now: Date,
        intervalMinutes: Int,
        windowStart: String,
        windowEnd: String
    ) -> Date {
        let cal = ReminderCompute.tzCalendar
        let safeInterval = max(1, intervalMinutes)

        guard let (startH, startM) = ReminderCompute.parseHHMM(windowStart),
              let (endH, endM) = ReminderCompute.parseHHMM(windowEnd) else {
            return ReminderCompute.nextRunInterval(
                after: completedOccurrenceDate,
                intervalMinutes: safeInterval,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        }

        let startTotal = startH * 60 + startM
        let endTotal = endH * 60 + endM
        guard endTotal >= startTotal else {
            return ReminderCompute.nextRunInterval(
                after: completedOccurrenceDate,
                intervalMinutes: safeInterval,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        }

        let threshold = max(now, completedOccurrenceDate)

        for dayOffset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: threshold)) else {
                continue
            }

            var cursor = startTotal
            while cursor <= endTotal {
                let hour = cursor / 60
                let minute = cursor % 60
                let candidate = ReminderCompute.merge(day: day, hour: hour, minute: minute, in: cal.timeZone)

                if candidate > threshold {
                    return candidate
                }

                cursor += safeInterval
            }
        }

        // Last-resort fallback should still stay anchored to the completed occurrence,
        // not the current clock time, so it does not create off-grid times.
        return ReminderCompute.nextRunInterval(
            after: completedOccurrenceDate,
            intervalMinutes: safeInterval,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
    }

    private func markDone(_ reminder: LystariaReminder) {
        print("[RemindersView] markDone id=\(reminder.id) title=\(reminder.title)")

        if reminder.reminderType == .routine,
           reminder.totalRoutineItemCount > 0,
           !reminder.isRoutineChecklistComplete
        {
            showToast("Complete all routine items first")
            return
        }

        // If this reminder is linked to a habit, count it as a habit log.
        logHabitProgressFromReminder(reminder, in: modelContext)
        logMedicationIfLinked(reminder)
        let completedOccurrenceDate = reminder.nextRunAt

        if reminder.isRecurring {
            let now = Date()
            // Skip past the just-completed occurrence so we truly advance to the NEXT one.
            // Use max(now, nextRunAt) so completing early still advances past the scheduled time.
            // AFTER:
            let base = max(now, reminder.nextRunAt)

            let intervalWindowStart: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                return habits.first(where: { $0.id == habitId })?.reminderIntervalWindowStart
            }()

            let intervalWindowEnd: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                return habits.first(where: { $0.id == habitId })?.reminderIntervalWindowEnd
            }()

            if reminder.schedule?.kind == .interval,
               let intervalMinutes = reminder.schedule?.intervalMinutes
            {
                let windowStart = (intervalWindowStart?.isEmpty == false) ? intervalWindowStart! : "00:00"
                let windowEnd = (intervalWindowEnd?.isEmpty == false) ? intervalWindowEnd! : "23:59"

                // Interval habit reminders must stay anchored to the configured window grid.
                // Example: 10 AM, 1 PM, 4 PM should advance from 1 PM to 4 PM,
                // not recalculate from the current clock time and create a 2 PM reminder.
                reminder.nextRunAt = nextAnchoredIntervalRun(
                    afterCompletedOccurrence: completedOccurrenceDate,
                    now: now,
                    intervalMinutes: max(1, intervalMinutes),
                    windowStart: windowStart,
                    windowEnd: windowEnd
                )
            } else {
                reminder.nextRunAt = ReminderCompute.nextRun(
                    after: base.addingTimeInterval(91),
                    reminder: reminder,
                    intervalWindowStart: intervalWindowStart,
                    intervalWindowEnd: intervalWindowEnd
                )
            }

            // Clear acknowledged state so the circle unchecks immediately on re-render.
            reminder.acknowledgedAt = nil

            if reminder.reminderType == .routine {
                reminder.resetRoutineChecklist(for: "\(reminder.nextRunAt.timeIntervalSince1970)")
            }

            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.updatedAt = Date()

            // Persist immediately — this triggers SwiftData to diff and re-render the card,
            // which is what actually unchecks the circle in the UI.
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)

            print("[RemindersView] markDone recurring -> nextRunAt=\(reminder.nextRunAt)")
            NotificationManager.shared.cancelReminder(reminder)
            NotificationManager.shared.scheduleReminder(reminder)

            let nextText = reminder.nextRunAt.formatted(date: .abbreviated, time: .shortened)
            showToast("\(reminder.title) done · Next: \(nextText)")
        } else {
            // One-time reminders stay checked for today.
            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.acknowledgedAt = Date()
            reminder.status = .sent

            reminder.updatedAt = Date()

            // Persist so the view reflects checked state and sync can pick it up.
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)

            print("[RemindersView] markDone once -> status=\(reminder.status.rawValue)")
            NotificationManager.shared.cancelReminder(reminder)

            showToast("\(reminder.title) marked complete")
        }
    }
    
    private func markDoneFromTimeBlock(_ reminder: LystariaReminder) {
        logHabitProgressFromReminder(reminder, in: modelContext)
        logMedicationIfLinked(reminder)
        let completedOccurrenceDate = reminder.nextRunAt

        if reminder.isRecurring {
            let now = Date()
            let base = max(now, reminder.nextRunAt)
            let intervalWindowStart: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                let descriptor = FetchDescriptor<Habit>()
                return ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId })?.reminderIntervalWindowStart
            }()

            let intervalWindowEnd: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                let descriptor = FetchDescriptor<Habit>()
                return ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId })?.reminderIntervalWindowEnd
            }()

            if reminder.schedule?.kind == .interval,
               let intervalMinutes = reminder.schedule?.intervalMinutes
            {
                let windowStart = (intervalWindowStart?.isEmpty == false) ? intervalWindowStart! : "00:00"
                let windowEnd = (intervalWindowEnd?.isEmpty == false) ? intervalWindowEnd! : "23:59"

                // Interval habit reminders must stay anchored to the configured window grid.
                // Example: 10 AM, 1 PM, 4 PM should advance from 1 PM to 4 PM,
                // not recalculate from the current clock time and create a 2 PM reminder.
                reminder.nextRunAt = nextAnchoredIntervalRun(
                    afterCompletedOccurrence: completedOccurrenceDate,
                    now: now,
                    intervalMinutes: max(1, intervalMinutes),
                    windowStart: windowStart,
                    windowEnd: windowEnd
                )
            } else {
                // Non-interval recurring reminders should behave like the normal Reminder card path:
                // completing early advances past the scheduled occurrence, and completing overdue advances
                // from now so the reminder does not stay behind in the past.
                reminder.nextRunAt = ReminderCompute.nextRun(
                    after: base.addingTimeInterval(91),
                    reminder: reminder,
                    intervalWindowStart: intervalWindowStart,
                    intervalWindowEnd: intervalWindowEnd
                )
            }
            reminder.acknowledgedAt = nil
            if reminder.reminderType == .routine {
                reminder.resetRoutineChecklist(for: "\(reminder.nextRunAt.timeIntervalSince1970)")
            }
            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.updatedAt = Date()
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)
            NotificationManager.shared.cancelReminder(reminder)
            NotificationManager.shared.scheduleReminder(reminder)
        } else {
            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.acknowledgedAt = Date()
            reminder.status = .sent
            reminder.updatedAt = Date()
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)
            NotificationManager.shared.cancelReminder(reminder)
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                toastMessage = nil
            }
        }
    }

    private func snooze(_ reminder: LystariaReminder, minutes: Int) {
        let cal = ReminderCompute.tzCalendar
        let snoozed = cal.date(byAdding: .minute, value: minutes, to: reminder.nextRunAt) ?? reminder.nextRunAt

        // For interval habit reminders, clamp the snoozed time back inside the window
        // so a snooze near the end of the window doesn't fire after it closes.
        if reminder.schedule?.kind == .interval,
           reminder.linkedKind == .habit,
           let habitId = reminder.linkedHabitId,
           let habit = habits.first(where: { $0.id == habitId }),
           let iv = reminder.schedule?.intervalMinutes,
           !habit.reminderIntervalWindowStart.isEmpty,
           !habit.reminderIntervalWindowEnd.isEmpty
        {
            reminder.nextRunAt = ReminderCompute.nextRunInterval(
                after: snoozed,
                intervalMinutes: iv,
                windowStart: habit.reminderIntervalWindowStart,
                windowEnd: habit.reminderIntervalWindowEnd
            )
        } else {
            reminder.nextRunAt = snoozed
        }

        reminder.updatedAt = Date()
        try? modelContext.save()
        NotificationManager.shared.snoozeReminder(reminder)
    }

    private func detailPopup(reminder: LystariaReminder) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let cal = ReminderCompute.tzCalendar
            let todayStart = cal.startOfDay(for: now)
            let dueDate = reminder.nextRunAt
            let completed: Bool = {
                if let c = reminder.lastCompletedAt, cal.isDate(c, inSameDayAs: dueDate) { return true }
                if !reminder.isRecurring, let a = reminder.acknowledgedAt, cal.isDate(a, inSameDayAs: dueDate) { return true }
                return false
            }()
            let overdue = dueDate < todayStart && !completed
            let dueNow = !overdue && !completed && dueDate >= todayStart && dueDate <= now
            let upcoming = !overdue && !completed && dueDate > now

            let schedLabel: String = {
                guard let s = reminder.schedule else { return "Once" }
                if (s.interval ?? 1) > 1, s.kind != .interval, s.kind != .once { return "Custom" }
                return s.kind.label
            }()
            let schedColor: Color = {
                if let s = reminder.schedule, (s.interval ?? 1) > 1, s.kind != .interval, s.kind != .once {
                    return Color(red: 201/255, green: 44/255, blue: 194/255)
                }
                switch reminder.schedule?.kind ?? .once {
                case .once:     return LColors.badgeOnce
                case .daily:    return LColors.badgeDaily
                case .weekly:   return LColors.badgeWeekly
                case .monthly:  return .yellow
                case .yearly:   return LColors.gradientPurple
                case .interval: return LColors.badgeInterval
                }
            }()
            let kindLabel: String = {
                switch reminder.linkedKindRaw?.lowercased() {
                case "habit":      return "Habit"
                case "event":      return "Event"
                case "medication": return "Medication"
                default:           return "General"
                }
            }()
            let kindColor: Color = {
                switch reminder.linkedKindRaw?.lowercased() {
                case "habit":      return Color(red: 0.14, green: 0.63, blue: 0.56).opacity(0.82)
                case "event":      return Color(red: 0.95, green: 0.56, blue: 0.20).opacity(0.82)
                case "medication": return Color(red: 0.86, green: 0.28, blue: 0.58).opacity(0.82)
                default:           return Color.white.opacity(0.9)
                }
            }()
            let displayTZ = TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
            let timeText: String = {
                let df = DateFormatter()
                df.timeZone = displayTZ
                df.locale = .current
                df.setLocalizedDateFormatFromTemplate("EEE, MMM d 'at' h:mm a")
                return df.string(from: dueDate)
            }()
            let scheduledTimes: [String] = {
                guard let s = reminder.schedule, s.kind != .interval else { return [] }
                let raw = (s.timesOfDay?.isEmpty == false) ? (s.timesOfDay ?? []) : (s.timeOfDay != nil ? [s.timeOfDay!] : [])
                let parsed = raw.compactMap { ReminderCompute.parseHHMM($0) }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
                guard !parsed.isEmpty else { return [] }
                let df = DateFormatter()
                df.timeZone = displayTZ
                df.locale = .current
                df.timeStyle = .short
                df.dateStyle = .none
                return parsed.map { t in df.string(from: ReminderCompute.merge(day: now, hour: t.0, minute: t.1, in: displayTZ)) }
            }()

            LystariaOverlayPopup(
                onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingDetailPopup = false
                        detailReminder = nil
                    }
                },
                width: min(UIScreen.main.bounds.width - 32, 520),
                heightRatio: 0.55,
            ) {
                HStack {
                    GradientTitle(text: "Reminder Details", size: 22)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showingDetailPopup = false
                            detailReminder = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            } content: {
                VStack(alignment: .leading, spacing: 16) {

                    // Badges row 1: schedule kind + linked kind + routine
                    HStack(spacing: 6) {
                        LBadge(text: schedLabel, color: schedColor)
                        LBadge(text: kindLabel, color: kindColor)
                        if reminder.reminderType == .routine {
                            LBadge(text: "Routine", color: Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.88))
                        }
                    }

                    // Badges row 2: status
                    if overdue || dueNow || upcoming {
                        HStack(spacing: 6) {
                            if overdue {
                                LBadge(text: "OVERDUE", color: Color.red.opacity(0.42))
                            } else if dueNow {
                                LBadge(text: "DUE NOW", color: LColors.accent.opacity(0.48))
                            } else if upcoming {
                                LBadge(text: "UPCOMING", color: Color.yellow.opacity(0.48))
                            }
                        }
                    }

                    // Time pills
                    if !scheduledTimes.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 64), spacing: 4)],
                            alignment: .leading,
                            spacing: 4,
                        ) {
                            ForEach(scheduledTimes, id: \.self) { t in
                                Text(t)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.14))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            }
                        }
                    }

                    // Title
                    HStack(alignment: .top, spacing: 10) {
                        Image("pencilwrite")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                        Text(reminder.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Description
                    if let details = reminder.details,
                       !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        HStack(alignment: .top, spacing: 10) {
                            Image("flipbook")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                                .padding(.top, 2)
                            Text(details)
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Checklist items
                    let routineItems = reminder.sortedRoutineChecklistItems
                    let regularItems = reminder.checklistItems
                    let hasChecklist = reminder.reminderType == .routine ? !routineItems.isEmpty : !regularItems.isEmpty
                    if hasChecklist {
                        HStack(alignment: .top, spacing: 10) {
                            Image("starlines")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 6) {
                                if reminder.reminderType == .routine {
                                    ForEach(routineItems) { item in
                                        HStack(spacing: 6) {
                                            Image(systemName: reminder.isRoutineItemChecked(item) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 12))
                                                .foregroundStyle(reminder.isRoutineItemChecked(item) ? LColors.success : LColors.textSecondary)
                                            Text(item.title)
                                                .font(.system(size: 13))
                                                .foregroundStyle(LColors.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                } else {
                                    ForEach(regularItems, id: \.self) { item in
                                        HStack(spacing: 6) {
                                            Image(systemName: "circle")
                                                .font(.system(size: 12))
                                                .foregroundStyle(LColors.textSecondary)
                                            Text(item)
                                                .font(.system(size: 13))
                                                .foregroundStyle(LColors.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Next run time
                    HStack(alignment: .center, spacing: 10) {
                        Image("fillalarm")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                        Text(timeText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } footer: {
                EmptyView()
            }
        }
    }

    private func delete(_ reminder: LystariaReminder) {
        print("[RemindersView] delete id=\(reminder.id) title=\(reminder.title)")
        reminder.status = .deleted
        reminder.updatedAt = Date()
        try? modelContext.save()
        print("[RemindersView] deleted status=\(reminder.status.rawValue)")
        NotificationManager.shared.cancelReminder(reminder)
    }
}

struct OverviewStatCard: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LColors.glassBorder, lineWidth: 1),
        )
    }
}

// MARK: - Reminder Card

struct ReminderCard: View {
    @Bindable var reminder: LystariaReminder
    var linkedHabit: Habit? = nil
    @State private var isChecklistExpanded = false
    @State private var showingDeleteConfirm = false
    @State private var showingReschedulePopup = false
    @State private var rescheduleDateTime = Date()
    @State private var showingSnoozePopup = false
    @State private var snoozeMinutesText = "10"
    let onDone: () -> Void
    let onSnooze: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    private var scheduleLabel: String {
        guard let schedule = reminder.schedule else { return "Once" }

        if (schedule.interval ?? 1) > 1,
           schedule.kind != .interval,
           schedule.kind != .once
        {
            return "Custom"
        }

        return schedule.kind.label
    }

    private var badgeColor: Color {
        if let schedule = reminder.schedule,
           (schedule.interval ?? 1) > 1,
           schedule.kind != .interval,
           schedule.kind != .once
        {
            return Color(red: 201 / 255, green: 44 / 255, blue: 194 / 255) // #c92cc2
        }

        switch reminder.schedule?.kind ?? .once {
        case .once: return LColors.badgeOnce
        case .daily: return LColors.badgeDaily
        case .weekly: return LColors.badgeWeekly
        case .monthly: return .yellow
        case .yearly: return LColors.gradientPurple
        case .interval: return LColors.badgeInterval
        }
    }

    private var showsRoutineTypeBadge: Bool {
        reminder.reminderType == .routine
    }

    private var routineTypeBadgeColor: Color {
        Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.88)
    }

    private var reminderKindLabel: String {
        switch reminder.linkedKindRaw?.lowercased() {
        case "habit":
            "Habit"
        case "event":
            "Event"
        case "medication":
            "Medication"
        default:
            "General"
        }
    }

    private var reminderKindBadgeColor: Color {
        switch reminder.linkedKindRaw?.lowercased() {
        case "habit":
            Color(red: 0.14, green: 0.63, blue: 0.56).opacity(0.82)
        case "event":
            Color(red: 0.95, green: 0.56, blue: 0.20).opacity(0.82)
        case "medication":
            Color(red: 0.86, green: 0.28, blue: 0.58).opacity(0.82)
        default:
            Color.white.opacity(0.9)
        }
    }

    private var isDone: Bool {
        guard !reminder.isRecurring else { return false }

        if let completedAt = reminder.lastCompletedAt,
           Calendar.current.isDateInToday(completedAt)
        {
            return true
        }

        if let ack = reminder.acknowledgedAt,
           Calendar.current.isDateInToday(ack)
        {
            return true
        }

        return false
    }

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private var timeText: String {
        let d = reminder.nextRunAt
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE, MMM d 'at' h:mm a")
        return df.string(from: d)
    }

    private var scheduledTimes: [String] {
        guard let schedule = reminder.schedule else { return [] }

        // Interval reminders: compute all exact fire times from the habit's window + interval.
        if schedule.kind == .interval {
            guard let iv = schedule.intervalMinutes, iv > 0,
                  let habit = linkedHabit,
                  !habit.reminderIntervalWindowStart.isEmpty,
                  !habit.reminderIntervalWindowEnd.isEmpty,
                  let (wsH, wsM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
                  let (weH, weM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd)
            else {
                // No window configured — fall back to the descriptive pill
                guard let iv = schedule.intervalMinutes, iv > 0 else { return [] }
                if iv >= 60 && iv % 60 == 0 {
                    return ["Every \(iv / 60)h"]
                } else if iv >= 60 {
                    return ["Every \(iv / 60)h \(iv % 60)m"]
                } else {
                    return ["Every \(iv)m"]
                }
            }

            let startTotal = wsH * 60 + wsM
            let endTotal   = weH * 60 + weM
            guard endTotal >= startTotal else { return [] }

            let df = DateFormatter()
            df.timeZone = displayTimeZone
            df.locale = .current
            df.timeStyle = .short
            df.dateStyle = .none

            let day = Date()
            var times: [String] = []
            var cursor = startTotal
            while cursor <= endTotal {
                let h = cursor / 60
                let m = cursor % 60
                let d = ReminderCompute.merge(day: day, hour: h, minute: m, in: displayTimeZone)
                times.append(df.string(from: d))
                cursor += iv
            }
            return times
        }

        let raw = (schedule.timesOfDay?.isEmpty == false)
            ? (schedule.timesOfDay ?? [])
            : (schedule.timeOfDay != nil ? [schedule.timeOfDay!] : [])

        // Normalize + sort by HH:MM
        let parsed: [(hh: Int, mm: Int, raw: String)] = raw.compactMap { s in
            guard let (hh, mm) = ReminderCompute.parseHHMM(s) else { return nil }
            return (hh: hh, mm: mm, raw: s)
        }
        .sorted { a, b in
            (a.hh, a.mm) < (b.hh, b.mm)
        }

        guard !parsed.isEmpty else { return [] }

        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none

        let day = Date()
        return parsed.map { t in
            let d = ReminderCompute.merge(day: day, hour: t.hh, minute: t.mm, in: displayTimeZone)
            return df.string(from: d)
        }
    }

    private var checklistItems: [String] {
        reminder.checklistItems
    }

    private func openReschedulePopup() {
        rescheduleDateTime = reminder.nextRunAt
        showingReschedulePopup = true
    }

    @ViewBuilder
    private func timePillsView() -> some View {
        if !scheduledTimes.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(stride(from: 0, to: scheduledTimes.count, by: 3)), id: \.self) { rowStart in
                    HStack(spacing: 3) {
                        ForEach(rowStart..<min(rowStart + 3, scheduledTimes.count), id: \.self) { i in
                            Text(scheduledTimes[i])
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checklistPreviewView() -> some View {
        let currentReminder = _reminder.wrappedValue

        if currentReminder.reminderType == .routine {
            if !currentReminder.sortedRoutineChecklistItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isChecklistExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)

                                Text(
                                    currentReminder.totalRoutineItemCount > 0
                                        ? "\(currentReminder.completedRoutineItemCount) of \(currentReminder.totalRoutineItemCount) Complete"
                                        : "Routine Items",
                                )
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                            }

                            Image(systemName: isChecklistExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(LColors.textSecondary.opacity(0.8))

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if isChecklistExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(currentReminder.sortedRoutineChecklistItems) { item in
                                Button {
                                    let currentlyChecked = currentReminder.isRoutineItemChecked(item)
                                    currentReminder.setRoutineItemChecked(!currentlyChecked, for: item)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: currentReminder.isRoutineItemChecked(item) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(
                                                currentReminder.isRoutineItemChecked(item)
                                                    ? LColors.success
                                                    : LColors.textSecondary,
                                            )

                                        Text(item.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(LColors.textSecondary)
                                            .lineLimit(1)

                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 2)
            }
        } else {
            if !checklistItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isChecklistExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)

                                Text("\(checklistItems.count) Checklist Item\(checklistItems.count == 1 ? "" : "s")")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }

                            Image(systemName: isChecklistExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(LColors.textSecondary.opacity(0.8))

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if isChecklistExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(checklistItems, id: \.self) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                                        .frame(width: 10, height: 10)

                                    Text(item)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var snoozePopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showingSnoozePopup = false
                }
            },
            width: 480,
            heightRatio: 0.60,
        ) {
            HStack {
                GradientTitle(text: "Snooze Reminder", font: .title2.bold())
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingSnoozePopup = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("How many minutes do you want to snooze?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                LystariaControlRow(label: "Minutes") {
                    TextField("10", text: $snoozeMinutesText)
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                        .foregroundStyle(LColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .onChange(of: snoozeMinutesText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { snoozeMinutesText = filtered }
                        }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([5, 10, 15, 20, 30, 60], id: \.self) { preset in
                            let label = preset < 60 ? "\(preset) min" : "1 hr"
                            Button {
                                snoozeMinutesText = "\(preset)"
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(snoozeMinutesText == "\(preset)" ? .white : LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(snoozeMinutesText == "\(preset)" ? LColors.accent : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(snoozeMinutesText == "\(preset)" ? LColors.accent : LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } footer: {
            GlassCard(padding: 14) {
                Button {
                    let minutes = max(1, Int(snoozeMinutesText.filter { $0.isNumber }) ?? 10)
                    onSnooze(minutes)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingSnoozePopup = false
                    }
                } label: {
                    Text("Snooze")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                }
                .buttonStyle(.plain)
                .disabled((Int(snoozeMinutesText.filter { $0.isNumber }) ?? 0) < 1)
            }
        }
    }

    private var reschedulePopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showingReschedulePopup = false
                }
            },
            width: 560,
            heightRatio: 0.82,
        ) {
            HStack {
                GradientTitle(text: "Reschedule Reminder", font: .title2.bold())
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingReschedulePopup = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        } content: {
            VStack(spacing: 16) {
                #if os(macOS)
                    LDateStepperRow(label: "Date", dateTime: $rescheduleDateTime)
                    LTimeEntryRow(label: "Time", dateTime: $rescheduleDateTime)
                #else
                    LystariaControlRow(label: "Date") {
                        DatePicker("", selection: $rescheduleDateTime, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(LColors.accent)
                    }

                    LystariaControlRow(label: "Time") {
                        DatePicker("", selection: $rescheduleDateTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(LColors.accent)
                    }
                #endif

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } footer: {
            GlassCard(padding: 14) {
                Button {
                    reminder.nextRunAt = rescheduleDateTime
                    reminder.completionTimestampsStorage = "[]"  // clear today's completions — occurrence moved
                    reminder.updatedAt = Date()
                    NotificationManager.shared.scheduleReminder(reminder)
                    #if DEBUG
                        NotificationManager.shared.printPendingNotifications()
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingReschedulePopup = false
                    }
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// --- STATUS BADGE HELPERS ---
    private func isDueNow(now: Date) -> Bool {
        // Due Now appears at the scheduled time and stays until completed.
        // If it's already marked done for today, it is not due.
        if isDone { return false }

        // Recurring reminders that were missed on a prior day should not stay
        // visually stuck on "DUE NOW" forever. If the nextRunAt is before today,
        // consider that occurrence missed and let the next reschedule take over.
        if reminder.isRecurring {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if reminder.nextRunAt < startOfToday {
                return false
            }
        }

        return now >= reminder.nextRunAt
    }

    private func isOverdue(now: Date) -> Bool {
        if isDone { return false }
        let startOfToday = Calendar.current.startOfDay(for: now)
        return reminder.nextRunAt < startOfToday
    }

    private func isUpcoming(now: Date) -> Bool {
        // Upcoming is within the next 24 hours (but not yet due), and not completed.
        if isDone { return false }
        if now >= reminder.nextRunAt { return false }
        return reminder.nextRunAt <= now.addingTimeInterval(24 * 60 * 60)
    }

    /// Transparent status badge colors
    private var upcomingBadgeColor: Color {
        Color.teal.opacity(0.42)
    }

    private var dueNowBadgeColor: Color {
        Color.yellow.opacity(0.48)
    }

    private var overdueBadgeColor: Color {
        Color.red.opacity(0.42)
    }

    var body: some View {
        // Recompute status badges periodically so they flip at the correct time.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let overdue = isOverdue(now: now)
            let dueNow = isDueNow(now: now)
            let upcoming = isUpcoming(now: now)

            ZStack {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                LBadge(text: scheduleLabel, color: badgeColor)
                                LBadge(text: reminderKindLabel, color: reminderKindBadgeColor)

                                if showsRoutineTypeBadge {
                                    LBadge(text: "Routine", color: routineTypeBadgeColor)
                                }

                                Spacer(minLength: 0)
                            }

                            if overdue || dueNow || upcoming {
                                HStack(spacing: 6) {
                                    if overdue {
                                        LBadge(text: "OVERDUE", color: overdueBadgeColor)
                                    } else if dueNow {
                                        LBadge(text: "DUE NOW", color: dueNowBadgeColor)
                                    } else if upcoming {
                                        LBadge(text: "UPCOMING", color: upcomingBadgeColor)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button { onDone() } label: {
                            Image(systemName: isDone ? "circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isDone ? LColors.success : LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    timePillsView()

                    HStack(alignment: .center, spacing: 8) { // 6 FOR LEFT AND ADJUST UP FOR RIGHT
                        Text(reminder.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let details = reminder.details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(details)
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(3)
                    }
                    checklistPreviewView()

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Text(timeText)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            LButton(title: "Snooze", icon: "clock.arrow.circlepath", style: .secondary) { showingSnoozePopup = true }
                            LButton(title: "Reschedule", icon: "calendar.badge.clock", style: .secondary) { openReschedulePopup() }
                        }

                        HStack(spacing: 10) {
                            LButton(title: "Edit", icon: "pencil", style: .secondary) { onEdit() }
                            GradientCapsuleButton(title: "Delete", icon: "trashfill") {
                                showingDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onTap()
                }
            }
            } // ZStack
            .lystariaAlertConfirm(
                isPresented: $showingDeleteConfirm,
                title: "Delete Reminder?",
                message: "This reminder will be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
            ) {
                onDelete()
            }
            .fullScreenCover(isPresented: $showingReschedulePopup) {
                ZStack {
                    Color.clear
                        .ignoresSafeArea()
                    reschedulePopup
                }
                .presentationBackground(.clear)
            }
            .fullScreenCover(isPresented: $showingSnoozePopup) {
                ZStack {
                    Color.clear
                        .ignoresSafeArea()
                    snoozePopup
                }
                .presentationBackground(.clear)
            }
        }
    }
}

// MARK: - New Reminder Sheet

struct NewReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Query private var medications: [Medication]
    let onClose: () -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var reminderType: ReminderType = .regular
    @State private var checklistEntries: [String] = [""]
    @State private var routineItemEntries: [String] = [""]
    @State private var reminderColor: String = "#7d19f7"
    @State private var onceDateTime = Date()

    @FocusState private var focusedChecklistIndex: Int?
    @FocusState private var detailsFocused: Bool

    @State private var scheduleKind: ReminderScheduleKind = .once
    @State private var startDay = Date()
    @State private var timesOfDay: [Date] = [Date()]
    @State private var selectedDays: Set<Int> = []
    @State private var intervalMinutes: Int = 60
    @State private var recurrenceInterval: Int = 1
    @State private var dayOfMonth: Int = Calendar.current.component(.day, from: Date())
    @State private var anchorMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var anchorDay: Int = Calendar.current.component(.day, from: Date())
    @State private var monthlyMode: ReminderScheduleForm.MonthlyMode = .sameDay
    @State private var yearlyMode: ReminderScheduleForm.YearlyMode = .sameDay
    @State private var selectedMedicationId: UUID? = nil
    @State private var linkedMedicationQuantity: Int = 1
    @State private var linkedMedicationQuantityOverrides: [Int: Int] = [:]
    @State private var routineMedicationRows: [(id: UUID, medicationId: UUID?, quantity: Int, quantityOverrides: [Int: Int])] = []

    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }
        if scheduleKind == .weekly { return !selectedDays.isEmpty }
        return true
    }

    private var titleTrimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        LystariaFullScreenForm(
            title: "New Reminder",
            onCancel: { onClose() },
            canSave: canSave,
            onSave: { save() },
        ) {
            formContent
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    detailsFocused = false
                    focusedChecklistIndex = nil
                }
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            LabeledGlassField(label: "REMINDER TYPE") {
                HStack(spacing: 8) {
                    ForEach([ReminderType.regular, .routine], id: \.self) { type in
                        let isSelected = reminderType == type
                        Button {
                            reminderType = type
                        } label: {
                            Text(type == .regular ? "Regular" : "Routine")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? LColors.accent : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? LColors.accent : LColors.glassBorder, lineWidth: 1),
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }

            LabeledGlassField(label: "TEXT") {
                TextField("Reminder title", text: $title)
                    .textFieldStyle(.plain)
                    .foregroundStyle(LColors.textPrimary)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                #endif
            }

            LabeledGlassField(label: "DETAILS") {
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(LColors.textPrimary)
                    .focused($detailsFocused)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                #endif
            }

            LabeledGlassField(label: "COLOR") {
                ReminderColorPicker(selectedColor: $reminderColor)
            }

            if reminderType == .regular {
                LabeledGlassField(label: "CHECKLIST ITEMS") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(spacing: 8) {
                            ForEach(Array(checklistEntries.indices), id: \.self) { idx in
                                TextField(
                                    idx == 0 ? "Checklist item" : "Another item",
                                    text: Binding(
                                        get: { checklistEntries[idx] },
                                        set: { checklistEntries[idx] = $0 },
                                    ),
                                )
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .focused($focusedChecklistIndex, equals: idx)
                                #if os(iOS) || os(visionOS)
                                    .textInputAutocapitalization(.sentences)
                                    .disableAutocorrection(false)
                                #endif
                                    .onSubmit {
                                        let trimmed = checklistEntries[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                        let isLast = idx == checklistEntries.count - 1

                                        if trimmed.isEmpty {
                                            if isLast, checklistEntries.count > 1 {
                                                checklistEntries.removeLast()
                                            }
                                            focusedChecklistIndex = nil
                                        } else if isLast {
                                            checklistEntries[idx] = trimmed
                                            checklistEntries.append("")
                                            focusedChecklistIndex = idx + 1
                                        } else {
                                            checklistEntries[idx] = trimmed
                                            focusedChecklistIndex = min(idx + 1, checklistEntries.count - 1)
                                        }
                                    }
                            }
                        }

                        Text("Type an item and press Return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            } else {
                LabeledGlassField(label: "ROUTINE ITEMS") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(spacing: 8) {
                            ForEach(Array(routineItemEntries.indices), id: \.self) { idx in
                                TextField(
                                    idx == 0 ? "Routine item" : "Another routine item",
                                    text: Binding(
                                        get: { routineItemEntries[idx] },
                                        set: { routineItemEntries[idx] = $0 },
                                    ),
                                )
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .focused($focusedChecklistIndex, equals: idx)
                                #if os(iOS) || os(visionOS)
                                    .textInputAutocapitalization(.sentences)
                                    .disableAutocorrection(false)
                                #endif
                                    .onSubmit {
                                        let trimmed = routineItemEntries[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                        let isLast = idx == routineItemEntries.count - 1

                                        if trimmed.isEmpty {
                                            if isLast, routineItemEntries.count > 1 {
                                                routineItemEntries.removeLast()
                                            }
                                            focusedChecklistIndex = nil
                                        } else if isLast {
                                            routineItemEntries[idx] = trimmed
                                            routineItemEntries.append("")
                                            focusedChecklistIndex = idx + 1
                                        } else {
                                            routineItemEntries[idx] = trimmed
                                            focusedChecklistIndex = min(idx + 1, routineItemEntries.count - 1)
                                        }
                                    }
                            }
                        }

                        Text("Type a routine item and press Return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            }

            if reminderType == .regular {
                LabeledGlassField(label: "LINK MEDICATION") {
                    VStack(alignment: .leading, spacing: 10) {
                        if medications.isEmpty {
                            Text("No medications available yet. Add medications from the Health page first.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        } else {
                            Picker(
                                "Medication",
                                selection: $selectedMedicationId,
                            ) {
                                Text("None")
                                    .tag(nil as UUID?)

                                ForEach(medications) { medication in
                                    Text(medication.name)
                                        .tag(Optional(medication.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(LColors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if selectedMedicationId != nil {
                                MedicationDoseScheduleGrid(
                                    defaultQuantity: $linkedMedicationQuantity,
                                    overrides: $linkedMedicationQuantityOverrides
                                )
                            }
                        }
                    }
                }
            } else {
                LabeledGlassField(label: "LINK MEDICATIONS") {
                    VStack(alignment: .leading, spacing: 10) {
                        if medications.isEmpty {
                            Text("No medications available yet. Add medications from the Health page first.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        } else {
                            ForEach(Array(routineMedicationRows.indices), id: \.self) { idx in
                                VStack(alignment: .leading, spacing: 8) {
                                    Picker(
                                        "Medication",
                                        selection: Binding(
                                            get: { routineMedicationRows[idx].medicationId },
                                            set: { routineMedicationRows[idx].medicationId = $0 },
                                        ),
                                    ) {
                                        Text("None")
                                            .tag(nil as UUID?)

                                        ForEach(medications) { medication in
                                            Text(medication.name)
                                                .tag(Optional(medication.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(LColors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 12) {
                                        Text("Subtract")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(LColors.textPrimary)

                                        Button {
                                            if routineMedicationRows[idx].quantity > 1 {
                                                routineMedicationRows[idx].quantity -= 1
                                            }
                                        } label: {
                                            Image(systemName: "minus")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(routineMedicationRows[idx].quantity <= 1 ? LColors.textSecondary.opacity(0.5) : .white)
                                                .frame(width: 32, height: 32)
                                                .background(routineMedicationRows[idx].quantity <= 1 ? Color.white.opacity(0.05) : LColors.accent.opacity(0.85))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(routineMedicationRows[idx].quantity <= 1)

                                        Text("\(routineMedicationRows[idx].quantity)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(LColors.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(LColors.glassBorder, lineWidth: 1),
                                            )

                                        Button {
                                            if routineMedicationRows[idx].quantity < 100 {
                                                routineMedicationRows[idx].quantity += 1
                                            }
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

                                        Button {
                                            routineMedicationRows.remove(at: idx)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 32, height: 32)
                                                .background(Color.red.opacity(0.75))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                            }

                            Button {
                                routineMedicationRows.append((id: UUID(), medicationId: nil, quantity: 1, quantityOverrides: [:]))
                            } label: {
                                Label("Add Medication", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(LColors.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ReminderScheduleForm(
                scheduleKind: $scheduleKind,
                startDay: $startDay,
                onceDateTime: $onceDateTime,
                timesOfDay: $timesOfDay,
                selectedDays: $selectedDays,
                recurrenceInterval: $recurrenceInterval,
                intervalMinutes: $intervalMinutes,
                monthlyMode: $monthlyMode,
                dayOfMonth: $dayOfMonth,
                yearlyMode: $yearlyMode,
                anchorMonth: $anchorMonth,
                anchorDay: $anchorDay,
            )
        }
        .modifier(ReminderFormKeyboardDismissModifier())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        #if os(macOS)
            NSApp.keyWindow?.endEditing(for: nil)
        #endif
        DispatchQueue.main.async {
            // Enforce reminder limit (5 total for free users)
            let descriptor = FetchDescriptor<LystariaReminder>()
            let existingReminders = (try? modelContext.fetch(descriptor)) ?? []
            let decision = limits.canCreate(.remindersTotal, currentCount: existingReminders.count(where: { $0.status != .deleted }))
            guard decision.allowed else { return }
            guard canSave else { return }

            print("[NewReminderSheet] Save tapped. title=\(titleTrimmed), kind=\(scheduleKind.rawValue))")
            let schedule: ReminderSchedule?
            let runAt: Date

            if scheduleKind == .once {
                schedule = .once
                runAt = onceDateTime
            } else {
                let timeStrings = timesOfDay
                    .map { d -> String in
                        let (hh, mm) = ReminderCompute.hourMinute(from: d)
                        return String(format: "%02d:%02d", hh, mm)
                    }
                    .sorted()

                let primary = timeStrings.first

                let resolvedDayOfMonth: Int? = {
                    guard scheduleKind == .monthly else { return nil }
                    if monthlyMode == .specificDay { return dayOfMonth }
                    return nil // sameDay = engine uses start day
                }()
                let resolvedAnchorMonth: Int? = {
                    guard scheduleKind == .yearly else { return nil }
                    if yearlyMode == .specificDate { return anchorMonth }
                    return nil
                }()
                let resolvedAnchorDay: Int? = {
                    guard scheduleKind == .yearly else { return nil }
                    if yearlyMode == .specificDate { return anchorDay }
                    return nil
                }()

                schedule = ReminderSchedule(
                    kind: scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: scheduleKind == .interval ? nil : recurrenceInterval,
                    daysOfWeek: scheduleKind == .weekly ? Array(selectedDays).sorted() : nil,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                    intervalMinutes: scheduleKind == .interval ? intervalMinutes : nil,
                )

                runAt = ReminderCompute.firstRun(
                    kind: scheduleKind,
                    startDay: startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: scheduleKind == .weekly ? Array(selectedDays) : nil,
                    intervalMinutes: scheduleKind == .interval ? intervalMinutes : nil,
                    recurrenceInterval: scheduleKind == .interval ? nil : recurrenceInterval,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                )
            }

            print("[NewReminderSheet] Computed first runAt=\(runAt), schedule=\(String(describing: schedule))")
            let newReminder = LystariaReminder(
                title: titleTrimmed,
                nextRunAt: runAt,
                schedule: schedule,
                reminderType: reminderType,
            )
            if reminderType == .regular {
                if let selectedMedicationId {
                    newReminder.linkedKind = .medication
                    newReminder.linkedMedicationId = selectedMedicationId
                    newReminder.linkedMedicationQuantity = max(1, linkedMedicationQuantity)
                    newReminder.linkedHabitId = nil
                    // Update overrides on the dedicated link object
                    let link = ReminderMedicationLink(
                        reminder: newReminder,
                        medicationId: selectedMedicationId,
                        quantity: max(1, linkedMedicationQuantity),
                        sortOrder: 0,
                        quantityOverrides: linkedMedicationQuantityOverrides
                    )
                    newReminder.medicationLinks = [link]
                } else {
                    newReminder.linkedKindRaw = nil
                    newReminder.linkedMedicationId = nil
                    newReminder.linkedMedicationQuantity = 1
                }
            } else {
                newReminder.linkedMedicationId = nil
                newReminder.linkedMedicationQuantity = 1
            }
            let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            newReminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
            modelContext.insert(newReminder)

            let checklistItems = checklistEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            newReminder.checklistItems = reminderType == .regular ? checklistItems : []

            let routineItems = routineItemEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if reminderType == .routine {
                newReminder.routineChecklistItems = routineItems.enumerated().map { idx, title in
                    RoutineChecklistItem(
                        title: title,
                        sortOrder: idx,
                        reminder: newReminder,
                    )
                }

                let validRows = routineMedicationRows.filter { $0.medicationId != nil }
                newReminder.medicationLinks = validRows.enumerated().map { idx, row in
                    ReminderMedicationLink(
                        reminder: newReminder,
                        medicationId: row.medicationId,
                        quantity: max(1, row.quantity),
                        sortOrder: idx,
                        quantityOverrides: row.quantityOverrides
                    )
                }
            } else {
                newReminder.routineChecklistItems = nil
                newReminder.medicationLinks = nil
            }

            newReminder.color = reminderColor
            NotificationManager.shared.scheduleReminder(newReminder)
            #if DEBUG
                NotificationManager.shared.printPendingNotifications()
            #endif
            print("[NewReminderSheet] Inserted reminder with nextRunAt=\(runAt)")
            onClose()
        }
    }
}

// MARK: - Edit Reminder Sheet

struct EditReminderSheet: View {
    let onClose: () -> Void
    @Query private var medications: [Medication]
    @Bindable var reminder: LystariaReminder

    @State private var title = ""
    @State private var details = ""
    @State private var reminderType: ReminderType = .regular
    @State private var checklistEntries: [String] = [""]
    @State private var routineItemEntries: [String] = [""]
    @State private var scheduleKind: ReminderScheduleKind = .once
    @State private var onceDateTime = Date()
    @State private var reminderColor: String = "#7d19f7"

    @FocusState private var detailsFocused: Bool
    @FocusState private var focusedChecklistIndex: Int?

    @State private var startDay = Date()
    @State private var timesOfDay: [Date] = [Date()]
    @State private var selectedDays: Set<Int> = []
    @State private var intervalMinutes: Int = 60
    @State private var recurrenceInterval: Int = 1
    @State private var dayOfMonth: Int = Calendar.current.component(.day, from: Date())
    @State private var anchorMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var anchorDay: Int = Calendar.current.component(.day, from: Date())
    @State private var monthlyMode: ReminderScheduleForm.MonthlyMode = .sameDay
    @State private var yearlyMode: ReminderScheduleForm.YearlyMode = .sameDay
    @State private var selectedMedicationId: UUID? = nil
    @State private var linkedMedicationQuantity: Int = 1
    @State private var linkedMedicationQuantityOverrides: [Int: Int] = [:]
    @State private var routineMedicationRows: [(id: UUID, medicationId: UUID?, quantity: Int, quantityOverrides: [Int: Int])] = []

    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }
        if scheduleKind == .weekly { return !selectedDays.isEmpty }
        return true
    }

    private var titleTrimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        LystariaFullScreenForm(
            title: "Edit Reminder",
            onCancel: { onClose() },
            canSave: canSave,
            onSave: { apply() },
        ) {
            formContent
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    detailsFocused = false
                    focusedChecklistIndex = nil
                }
            }
        }
        .onAppear { loadFromModel() }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            LabeledGlassField(label: "REMINDER TYPE") {
                HStack(spacing: 8) {
                    ForEach([ReminderType.regular, .routine], id: \.self) { type in
                        let isSelected = reminderType == type
                        Button {
                            reminderType = type
                        } label: {
                            Text(type == .regular ? "Regular" : "Routine")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? LColors.accent : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? LColors.accent : LColors.glassBorder, lineWidth: 1),
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }

            LabeledGlassField(label: "TEXT") {
                TextField("Reminder title", text: $title)
                    .textFieldStyle(.plain)
                    .foregroundStyle(LColors.textPrimary)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                #else
                    // macOS: these modifiers are unavailable; rely on default behavior
                #endif
            }

            LabeledGlassField(label: "DETAILS") {
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(LColors.textPrimary)
                    .focused($detailsFocused)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                #else
                    // macOS: unavailable
                #endif
            }

            LabeledGlassField(label: "COLOR") {
                ReminderColorPicker(selectedColor: $reminderColor)
            }

            if reminderType == .regular {
                LabeledGlassField(label: "CHECKLIST ITEMS") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(spacing: 8) {
                            ForEach(Array(checklistEntries.indices), id: \.self) { idx in
                                TextField(
                                    idx == 0 ? "Checklist item" : "Another item",
                                    text: Binding(
                                        get: { checklistEntries[idx] },
                                        set: { checklistEntries[idx] = $0 },
                                    ),
                                )
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .focused($focusedChecklistIndex, equals: idx)
                                #if os(iOS) || os(visionOS)
                                    .textInputAutocapitalization(.sentences)
                                    .disableAutocorrection(false)
                                #else
                                    // macOS: unavailable
                                #endif
                                .onSubmit {
                                    let trimmed = checklistEntries[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                    let isLast = idx == checklistEntries.count - 1

                                    if trimmed.isEmpty {
                                        if isLast, checklistEntries.count > 1 {
                                            checklistEntries.removeLast()
                                        }
                                        focusedChecklistIndex = nil
                                    } else if isLast {
                                        checklistEntries[idx] = trimmed
                                        checklistEntries.append("")
                                        focusedChecklistIndex = idx + 1
                                    } else {
                                        checklistEntries[idx] = trimmed
                                        focusedChecklistIndex = min(idx + 1, checklistEntries.count - 1)
                                    }
                                }
                            }
                        }

                        Text("Type an item and press Return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            } else {
                LabeledGlassField(label: "ROUTINE ITEMS") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(spacing: 8) {
                            ForEach(Array(routineItemEntries.indices), id: \.self) { idx in
                                TextField(
                                    idx == 0 ? "Routine item" : "Another routine item",
                                    text: Binding(
                                        get: { routineItemEntries[idx] },
                                        set: { routineItemEntries[idx] = $0 },
                                    ),
                                )
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                                .focused($focusedChecklistIndex, equals: idx)
                                #if os(iOS) || os(visionOS)
                                    .textInputAutocapitalization(.sentences)
                                    .disableAutocorrection(false)
                                #else
                                    // macOS: unavailable
                                #endif
                                .onSubmit {
                                    let trimmed = routineItemEntries[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                    let isLast = idx == routineItemEntries.count - 1

                                    if trimmed.isEmpty {
                                        if isLast, routineItemEntries.count > 1 {
                                            routineItemEntries.removeLast()
                                        }
                                        focusedChecklistIndex = nil
                                    } else if isLast {
                                        routineItemEntries[idx] = trimmed
                                        routineItemEntries.append("")
                                        focusedChecklistIndex = idx + 1
                                    } else {
                                        routineItemEntries[idx] = trimmed
                                        focusedChecklistIndex = min(idx + 1, routineItemEntries.count - 1)
                                    }
                                }
                            }
                        }

                        Text("Type a routine item and press Return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            }

            if reminderType == .regular {
                LabeledGlassField(label: "LINK MEDICATION") {
                    VStack(alignment: .leading, spacing: 10) {
                        if medications.isEmpty {
                            Text("No medications available yet. Add medications from the Health page first.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        } else {
                            Picker(
                                "Medication",
                                selection: $selectedMedicationId,
                            ) {
                                Text("None")
                                    .tag(nil as UUID?)

                                ForEach(medications) { medication in
                                    Text(medication.name)
                                        .tag(Optional(medication.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(LColors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if selectedMedicationId != nil {
                                MedicationDoseScheduleGrid(
                                    defaultQuantity: $linkedMedicationQuantity,
                                    overrides: $linkedMedicationQuantityOverrides
                                )
                            }
                        }
                    }
                }
            } else {
                LabeledGlassField(label: "LINK MEDICATIONS") {
                    VStack(alignment: .leading, spacing: 10) {
                        if medications.isEmpty {
                            Text("No medications available yet. Add medications from the Health page first.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        } else {
                            ForEach(Array(routineMedicationRows.indices), id: \.self) { idx in
                                VStack(alignment: .leading, spacing: 8) {
                                    Picker(
                                        "Medication",
                                        selection: Binding(
                                            get: { routineMedicationRows[idx].medicationId },
                                            set: { routineMedicationRows[idx].medicationId = $0 },
                                        ),
                                    ) {
                                        Text("None")
                                            .tag(nil as UUID?)

                                        ForEach(medications) { medication in
                                            Text(medication.name)
                                                .tag(Optional(medication.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(LColors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    MedicationDoseScheduleGrid(
                                        defaultQuantity: Binding(
                                            get: { routineMedicationRows[idx].quantity },
                                            set: { routineMedicationRows[idx].quantity = $0 }
                                        ),
                                        overrides: Binding(
                                            get: { routineMedicationRows[idx].quantityOverrides },
                                            set: { routineMedicationRows[idx].quantityOverrides = $0 }
                                        )
                                    )

                                    Button {
                                        routineMedicationRows.remove(at: idx)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1),
                                )
                            }

                            Button {
                                routineMedicationRows.append((id: UUID(), medicationId: nil, quantity: 1, quantityOverrides: [:]))
                            } label: {
                                Label("Add Medication", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(LColors.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ReminderScheduleForm(
                scheduleKind: $scheduleKind,
                startDay: $startDay,
                onceDateTime: $onceDateTime,
                timesOfDay: $timesOfDay,
                selectedDays: $selectedDays,
                recurrenceInterval: $recurrenceInterval,
                intervalMinutes: $intervalMinutes,
                monthlyMode: $monthlyMode,
                dayOfMonth: $dayOfMonth,
                yearlyMode: $yearlyMode,
                anchorMonth: $anchorMonth,
                anchorDay: $anchorDay,
            )
        }
        .modifier(ReminderFormKeyboardDismissModifier())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFromModel() {
        print("[EditReminderSheet] loadFromModel for id=\(reminder.id) title=\(reminder.title)")
        title = reminder.title
        details = reminder.details ?? ""
        reminderType = reminder.reminderType
        let storedChecklist = reminder.checklistItems
        checklistEntries = storedChecklist.isEmpty ? [""] : storedChecklist
        let storedRoutineItems = _reminder.wrappedValue.sortedRoutineChecklistItems.map(\.title)
        routineItemEntries = storedRoutineItems.isEmpty ? [""] : storedRoutineItems
        selectedMedicationId = reminder.linkedMedicationId
        linkedMedicationQuantity = max(1, reminder.linkedMedicationQuantity)
        // Restore per-day overrides for regular reminders from the stored link object
        if let regularLink = _reminder.wrappedValue.sortedMedicationLinks.first(where: { $0.medicationId == reminder.linkedMedicationId }) {
            linkedMedicationQuantityOverrides = regularLink.quantityOverrides
        } else {
            linkedMedicationQuantityOverrides = [:]
        }
        let storedMedicationLinks = _reminder.wrappedValue.sortedMedicationLinks
        routineMedicationRows = storedMedicationLinks.map { link in
            (
                id: link.id,
                medicationId: link.medicationId,
                quantity: max(1, link.quantity),
                quantityOverrides: link.quantityOverrides
            )
        }

        let kind = reminder.schedule?.kind ?? .once
        scheduleKind = kind
        print("[EditReminderSheet] Current kind=\(kind.rawValue), nextRunAt=\(reminder.nextRunAt)")

        if kind == .once {
            onceDateTime = reminder.nextRunAt
            print("[EditReminderSheet] Once: onceDateTime=\(onceDateTime)")
        } else {
            startDay = reminder.nextRunAt

            let schedule = reminder.schedule
            let storedTimes: [String] = {
                if let t = schedule?.timesOfDay, !t.isEmpty { return t }
                if let t = schedule?.timeOfDay, !t.isEmpty { return [t] }
                return []
            }()

            if !storedTimes.isEmpty {
                let parsed = storedTimes.compactMap { hhmm -> (h: Int, m: Int)? in
                    guard let (h, m) = ReminderCompute.parseHHMM(hhmm) else { return nil }
                    return (h: h, m: m)
                }
                .sorted { a, b in (a.h, a.m) < (b.h, b.m) }

                if !parsed.isEmpty {
                    timesOfDay = parsed.map { ReminderCompute.merge(day: Date(), hour: $0.h, minute: $0.m) }
                } else {
                    timesOfDay = [reminder.nextRunAt]
                }
            } else {
                timesOfDay = [reminder.nextRunAt]
            }

            if timesOfDay.isEmpty {
                timesOfDay = [reminder.nextRunAt]
            }

            selectedDays = Set(reminder.schedule?.daysOfWeek ?? [])
            recurrenceInterval = max(1, reminder.schedule?.interval ?? 1)
            intervalMinutes = reminder.schedule?.intervalMinutes ?? 60

            // Monthly: restore mode from stored dayOfMonth
            if let storedDay = reminder.schedule?.dayOfMonth {
                dayOfMonth = storedDay
                monthlyMode = .specificDay
            } else {
                dayOfMonth = Calendar.current.component(.day, from: reminder.nextRunAt)
                monthlyMode = .sameDay
            }

            // Yearly: restore mode from stored anchorMonth/anchorDay
            if let storedMonth = reminder.schedule?.anchorMonth,
               let storedDay = reminder.schedule?.anchorDay
            {
                anchorMonth = storedMonth
                anchorDay = storedDay
                yearlyMode = .specificDate
            } else {
                anchorMonth = Calendar.current.component(.month, from: reminder.nextRunAt)
                anchorDay = Calendar.current.component(.day, from: reminder.nextRunAt)
                yearlyMode = .sameDay
            }
            print("[EditReminderSheet] Recurring: startDay=\(startDay), timesOfDay=\(timesOfDay), days=\(selectedDays.sorted()), intervalMinutes=\(intervalMinutes)")
        }
        reminderColor = reminder.color
    }

    private func apply() {
        #if os(macOS)
            NSApp.keyWindow?.endEditing(for: nil)
        #endif
        DispatchQueue.main.async {
            guard canSave else { return }
            let currentReminder = _reminder.wrappedValue

            print("[EditReminderSheet] Apply tapped. title=\(titleTrimmed), kind=\(scheduleKind.rawValue))")
            currentReminder.title = titleTrimmed
            currentReminder.reminderType = reminderType

            let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            currentReminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed

            let checklistItems = checklistEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            currentReminder.checklistItems = reminderType == .regular ? checklistItems : []

            let routineItems = routineItemEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if reminderType == .routine {
                currentReminder.routineChecklistItems = routineItems.enumerated().map { idx, title in
                    RoutineChecklistItem(
                        title: title,
                        sortOrder: idx,
                        reminder: currentReminder,
                    )
                }

                let validRows = routineMedicationRows.filter { $0.medicationId != nil }
                currentReminder.medicationLinks = validRows.enumerated().map { idx, row in
                    ReminderMedicationLink(
                        reminder: currentReminder,
                        medicationId: row.medicationId,
                        quantity: max(1, row.quantity),
                        sortOrder: idx,
                        quantityOverrides: row.quantityOverrides
                    )
                }
            } else {
                currentReminder.routineChecklistItems = nil
                currentReminder.medicationLinks = nil
            }

            if reminderType == .regular {
                if let selectedMedicationId {
                    currentReminder.linkedKind = .medication
                    currentReminder.linkedMedicationId = selectedMedicationId
                    currentReminder.linkedMedicationQuantity = max(1, linkedMedicationQuantity)
                    currentReminder.linkedHabitId = nil
                    // Update overrides on the dedicated link object
                    let link = ReminderMedicationLink(
                        reminder: currentReminder,
                        medicationId: selectedMedicationId,
                        quantity: max(1, linkedMedicationQuantity),
                        sortOrder: 0,
                        quantityOverrides: linkedMedicationQuantityOverrides
                    )
                    currentReminder.medicationLinks = [link]
                } else {
                    currentReminder.linkedMedicationId = nil
                    currentReminder.linkedMedicationQuantity = 1

                    if currentReminder.linkedKind == .medication {
                        currentReminder.linkedKindRaw = nil
                        currentReminder.medicationLinks = nil
                    }

                    // Restore badge kind for previously broken reminders that still have a linked habit.
                    if currentReminder.linkedHabitId != nil {
                        currentReminder.linkedKind = .habit
                    }
                }
            } else {
                currentReminder.linkedMedicationId = nil
                currentReminder.linkedMedicationQuantity = 1

                if currentReminder.linkedKind == .medication {
                    currentReminder.linkedKindRaw = nil
                    currentReminder.medicationLinks = nil
                }

                // Restore badge kind for previously broken routine reminders that still have a linked habit.
                if currentReminder.linkedHabitId != nil {
                    currentReminder.linkedKind = .habit
                }
            }

            let schedule: ReminderSchedule?
            let runAt: Date

            if scheduleKind == .once {
                schedule = .once
                runAt = onceDateTime
            } else {
                let timeStrings = timesOfDay
                    .map { d -> String in
                        let (hh, mm) = ReminderCompute.hourMinute(from: d)
                        return String(format: "%02d:%02d", hh, mm)
                    }
                    .sorted()

                let primary = timeStrings.first

                let resolvedDayOfMonth: Int? = {
                    guard scheduleKind == .monthly else { return nil }
                    if monthlyMode == .specificDay { return dayOfMonth }
                    return nil // sameDay = engine uses start day
                }()
                let resolvedAnchorMonth: Int? = {
                    guard scheduleKind == .yearly else { return nil }
                    if yearlyMode == .specificDate { return anchorMonth }
                    return nil
                }()
                let resolvedAnchorDay: Int? = {
                    guard scheduleKind == .yearly else { return nil }
                    if yearlyMode == .specificDate { return anchorDay }
                    return nil
                }()

                schedule = ReminderSchedule(
                    kind: scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: scheduleKind == .interval ? nil : recurrenceInterval,
                    daysOfWeek: scheduleKind == .weekly ? Array(selectedDays).sorted() : nil,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                    intervalMinutes: scheduleKind == .interval ? intervalMinutes : nil,
                )

                runAt = ReminderCompute.firstRun(
                    kind: scheduleKind,
                    startDay: startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: scheduleKind == .weekly ? Array(selectedDays) : nil,
                    intervalMinutes: scheduleKind == .interval ? intervalMinutes : nil,
                    recurrenceInterval: scheduleKind == .interval ? nil : recurrenceInterval,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                )
            }

            print("[EditReminderSheet] Computed runAt=\(runAt), schedule=\(String(describing: schedule))")

            reminder.color = reminderColor
            reminder.schedule = schedule
            reminder.nextRunAt = runAt
            reminder.updatedAt = Date()

            print("[EditReminderSheet] Updated reminder id=\(reminder.id) nextRunAt=\(reminder.nextRunAt) updatedAt=\(String(describing: reminder.updatedAt))")

            NotificationManager.shared.scheduleReminder(reminder)
            #if DEBUG
                NotificationManager.shared.printPendingNotifications()
            #endif

            onClose()
        }
    }
}

private struct ReminderFormKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
    }
}


fileprivate func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

fileprivate func logHabitProgressFromReminder(_ reminder: LystariaReminder, in modelContext: ModelContext) {
    guard reminder.linkedKind == .habit,
          let habitId = reminder.linkedHabitId else { return }

    let descriptor = FetchDescriptor<Habit>()
    guard let habit = ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId }) else {
        return
    }

    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    let cap = max(1, habit.timesPerDay)

    if let existingSkip = (habit.skips ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
        modelContext.delete(existingSkip)
        habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
    }

    if let existingLog = (habit.logs ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
        if existingLog.count < cap {
            existingLog.count += 1
            habit.updatedAt = Date()

            _ = try? SelfCarePointsManager.awardHabitLog(
                in: modelContext,
                habitLogId: existingLog.id.uuidString,
                title: habit.title,
                loggedAt: Date()
            )
        }
    } else {
        let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
        modelContext.insert(newLog)

        if habit.logs == nil {
            habit.logs = [newLog]
        } else {
            habit.logs?.append(newLog)
        }

        habit.updatedAt = Date()

        _ = try? SelfCarePointsManager.awardHabitLog(
            in: modelContext,
            habitLogId: newLog.id.uuidString,
            title: habit.title,
            loggedAt: Date()
        )
    }
}

// MARK: - Shared Schedule Form

/// Drop-in schedule configuration UI used by both NewReminderSheet and EditReminderSheet.
/// Covers every schedule kind the engine supports with proper pickers instead of steppers.
struct ReminderScheduleForm: View {
    // MARK: Bindings

    @Binding var scheduleKind: ReminderScheduleKind
    @Binding var startDay: Date
    @Binding var onceDateTime: Date
    @Binding var timesOfDay: [Date] // recurring times
    @Binding var selectedDays: Set<Int> // weekly days (0=Sun … 6=Sat)
    @Binding var recurrenceInterval: Int // every N days/weeks/months/years
    @Binding var intervalMinutes: Int // for .interval kind
    @Binding var monthlyMode: MonthlyMode // .sameDay | .specificDay
    @Binding var dayOfMonth: Int // 1-31 for .specificDay
    @Binding var yearlyMode: YearlyMode // .sameDay | .specificDate
    @Binding var anchorMonth: Int
    @Binding var anchorDay: Int

    // MARK: Supporting types

    enum MonthlyMode: String, CaseIterable {
        case sameDay = "Same day as start"
        case specificDay = "Specific day"
    }

    enum YearlyMode: String, CaseIterable {
        case sameDay = "Same day as start"
        case specificDate = "Specific date"
    }

    // MARK: Private helpers

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private var monthSymbols: [String] {
        Calendar.current.monthSymbols
    }

    private var intervalUnit: String {
        let plural = recurrenceInterval != 1
        switch scheduleKind {
        case .daily: return plural ? "days" : "day"
        case .weekly: return plural ? "weeks" : "week"
        case .monthly: return plural ? "months" : "month"
        case .yearly: return plural ? "years" : "year"
        default: return ""
        }
    }

    private var maxAnchorDay: Int {
        var comps = DateComponents()
        comps.year = 2024
        comps.month = anchorMonth
        return Calendar.current.range(of: .day, in: .month,
                                      for: Calendar.current.date(from: comps) ?? Date())?.count ?? 31
    }

    private func intervalLabel(for minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(minutes) min"
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Kind picker ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("REPEAT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderScheduleKind.allCases, id: \.self) { kind in
                            let on = scheduleKind == kind
                            Button { scheduleKind = kind } label: {
                                Text(kind.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(on ? .white : LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(on ? LColors.accent : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── Schedule details card ────────────────────────────────────
            GlassCard(padding: 16) {
                VStack(spacing: 14) {
                    // ── Once ────────────────────────────────────────────
                    if scheduleKind == .once {
                        #if os(macOS)
                            LDateStepperRow(label: "Date & Time", dateTime: $onceDateTime)
                            LTimeEntryRow(label: "Time", dateTime: $onceDateTime)
                        #else
                            LystariaControlRow(label: "Date & Time") {
                                DatePicker("", selection: $onceDateTime,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                            }
                        #endif

                        // ── Interval ─────────────────────────────────────────
                    } else if scheduleKind == .interval {
                        LystariaControlRow(label: "Repeat every") {
                            Picker("", selection: $intervalMinutes) {
                                ForEach(Array(stride(from: 5, through: 1440, by: 5)), id: \.self) { minutes in
                                    Text(intervalLabel(for: minutes)).tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(LColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                        }

                        // ── Daily / Weekly / Monthly / Yearly ─────────────────
                    } else {
                        // Start day
                        #if os(macOS)
                            LDateStepperRow(label: "Start Day", dateTime: $startDay)
                        #else
                            LystariaControlRow(label: "Start Day") {
                                DatePicker("", selection: $startDay,
                                           in: Date()..., displayedComponents: [.date])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                            }
                        #endif

                        // Times of day
                        timeOfDaySection

                        // Every N
                        LystariaControlRow(label: nil) {
                            HStack(spacing: 12) {
                                Text("Every")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)

                                Button {
                                    if recurrenceInterval > 1 {
                                        recurrenceInterval -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(recurrenceInterval <= 1 ? LColors.textSecondary.opacity(0.5) : .white)
                                        .frame(width: 32, height: 32)
                                        .background(recurrenceInterval <= 1 ? Color.white.opacity(0.05) : LColors.accent.opacity(0.85))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(recurrenceInterval <= 1)

                                Text("\(recurrenceInterval)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(LColors.glassBorder, lineWidth: 1),
                                    )

                                Button {
                                    if recurrenceInterval < 30 {
                                        recurrenceInterval += 1
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(LColors.accent.opacity(0.85))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text(intervalUnit)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)

                                Spacer()
                            }
                        }

                        // ── Weekly: day picker ───────────────────────────
                        if scheduleKind == .weekly {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ON THESE DAYS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                HStack(spacing: 6) {
                                    ForEach(0 ..< 7, id: \.self) { d in
                                        let on = selectedDays.contains(d)
                                        Button {
                                            if on { selectedDays.remove(d) }
                                            else { selectedDays.insert(d) }
                                        } label: {
                                            Text(weekdays[d])
                                                .font(.system(size: 12, weight: .semibold))
                                                .frame(width: 38, height: 38)
                                                .background(on ? LColors.accent : Color.white.opacity(0.08))
                                                .foregroundStyle(on ? .white : LColors.textPrimary)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(on ? .clear : LColors.glassBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // ── Monthly: day mode ────────────────────────────
                        if scheduleKind == .monthly {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ON")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                // Mode selector
                                HStack(spacing: 8) {
                                    ForEach(MonthlyMode.allCases, id: \.self) { mode in
                                        let on = monthlyMode == mode
                                        Button { monthlyMode = mode } label: {
                                            Text(mode.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(on ? .white : LColors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(on ? LColors.accent : Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Specific day picker
                                if monthlyMode == .specificDay {
                                    LystariaControlRow(label: "Day of month") {
                                        Picker("", selection: $dayOfMonth) {
                                            ForEach(1 ... 31, id: \.self) { d in
                                                Text("\(ordinal(d))").tag(d)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(LColors.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // ── Yearly: date mode ────────────────────────────
                        if scheduleKind == .yearly {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ON")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                // Mode selector
                                HStack(spacing: 8) {
                                    ForEach(YearlyMode.allCases, id: \.self) { mode in
                                        let on = yearlyMode == mode
                                        Button { yearlyMode = mode } label: {
                                            Text(mode.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(on ? .white : LColors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(on ? LColors.accent : Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Specific month + day
                                if yearlyMode == .specificDate {
                                    LystariaControlRow(label: "Month") {
                                        Picker("", selection: $anchorMonth) {
                                            ForEach(1 ... 12, id: \.self) { m in
                                                Text(monthSymbols[m - 1]).tag(m)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(LColors.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                        .onChange(of: anchorMonth) { _, _ in
                                            anchorDay = min(anchorDay, maxAnchorDay)
                                        }
                                    }

                                    LystariaControlRow(label: "Day") {
                                        Picker("", selection: $anchorDay) {
                                            ForEach(1 ... maxAnchorDay, id: \.self) { d in
                                                Text("\(ordinal(d))").tag(d)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(LColors.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            recurrenceInterval = min(max(recurrenceInterval, 1), 30)
            dayOfMonth = min(max(dayOfMonth, 1), 31)
            anchorMonth = min(max(anchorMonth, 1), 12)
            anchorDay = min(max(anchorDay, 1), maxAnchorDay)
            intervalMinutes = normalizedIntervalMinutes(intervalMinutes)
        }
        .onChange(of: anchorMonth) { _, _ in
            anchorDay = min(max(anchorDay, 1), maxAnchorDay)
        }
        .onChange(of: intervalMinutes) { _, newValue in
            intervalMinutes = normalizedIntervalMinutes(newValue)
        }
    }

    // MARK: Time-of-day sub-section

    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
                #if os(macOS)
                    LTimeEntryRow(
                        label: idx == 0 ? "Time" : "Time \(idx + 1)",
                        dateTime: Binding(
                            get: { timesOfDay[idx] },
                            set: { timesOfDay[idx] = $0 },
                        ),
                    )
                #else
                    LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                        DatePicker("",
                                   selection: Binding(
                                       get: { timesOfDay[idx] },
                                       set: { timesOfDay[idx] = $0 },
                                   ),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(LColors.accent)
                    }
                #endif
            }

            HStack(spacing: 8) {
                Button {
                    timesOfDay.append(timesOfDay.last ?? Date())
                } label: {
                    Label("Add Time", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LColors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if timesOfDay.count > 1 {
                    Button {
                        timesOfDay.removeLast()
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.top, 2)
        }
    }

    // MARK: Ordinal helper

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    private func normalizedIntervalMinutes(_ value: Int) -> Int {
        let clamped = min(max(value, 5), 1440)
        let remainder = clamped % 5
        if remainder == 0 { return clamped }
        let rounded = clamped + (5 - remainder)
        return min(max(rounded, 5), 1440)
    }
}

// MARK: - UI Helpers

struct LabeledGlassField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            content
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LColors.glassBorder, lineWidth: 1),
                )
        }
    }
}

struct LystariaControlRow<Content: View>: View {
    let label: String?
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            if let label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)

                Spacer()
            }

            content
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1),
        )
    }
}

#if os(macOS)
    /// Date row without the grey DatePicker field
    struct LDateStepperRow: View {
        let label: String
        @Binding var dateTime: Date

        var body: some View {
            let formatted = dateTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())

            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                Spacer()

                Text(formatted)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))

                Stepper("") { bump(days: 1) } onDecrement: { bump(days: -1) }
                    .labelsHidden()
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
        }

        private func bump(days: Int) {
            let cal = Calendar.current
            let (h, m) = ReminderCompute.hourMinute(from: dateTime)
            var d = cal.date(byAdding: .day, value: days, to: dateTime) ?? dateTime
            d = ReminderCompute.merge(day: d, hour: h, minute: m)
            dateTime = d
        }
    }

    /// 12-hour typed time + steppers that NEVER change the date
    struct LTimeEntryRow: View {
        let label: String
        @Binding var dateTime: Date

        @FocusState private var focused: Bool
        @State private var text: String = ""

        private static let displayFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = .current
            df.timeStyle = .short
            df.dateStyle = .none
            return df
        }()

        private static let parseFormatters: [DateFormatter] = {
            func make(_ fmt: String) -> DateFormatter {
                let df = DateFormatter()
                df.locale = .current
                df.dateFormat = fmt
                return df
            }
            return [
                make("h:mm a"), make("h:mma"),
                make("hh:mm a"), make("hh:mma"),
                make("h a"), make("ha"),
            ]
        }()

        var body: some View {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                Spacer()

                TextField("4:35 PM", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 120)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                    .focused($focused)
                    .onSubmit { applyTypedTime() }
                    .onChange(of: text) { _, newValue in
                        let raw = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !raw.isEmpty else { return }
                        for df in Self.parseFormatters {
                            if let parsed = df.date(from: raw.uppercased()) {
                                let cal = Calendar.current
                                let c = cal.dateComponents([.hour, .minute], from: parsed)
                                let hh = c.hour ?? 0
                                let mm = c.minute ?? 0
                                dateTime = ReminderCompute.merge(day: dateTime, hour: hh, minute: mm)
                                break
                            }
                        }
                    }
                    .onChange(of: focused) { _, newValue in
                        if !newValue { applyTypedTime() }
                    }
                    .onChange(of: dateTime) { _, _ in
                        if !focused { syncFromDate() }
                    }
                    .onDisappear { applyTypedTime() }

                HStack(spacing: 8) {
                    Stepper("") { bump(minutes: 1) } onDecrement: { bump(minutes: -1) }
                        .labelsHidden()
                    Stepper("") { bump(minutes: 5) } onDecrement: { bump(minutes: -5) }
                        .labelsHidden()
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
        }

        private func syncFromDate() {
            text = Self.displayFormatter.string(from: dateTime)
        }

        private func applyTypedTime() {
            let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { syncFromDate(); return }

            for df in Self.parseFormatters {
                if let parsed = df.date(from: raw.uppercased()) {
                    let cal = Calendar.current
                    let c = cal.dateComponents([.hour, .minute], from: parsed)
                    let hh = c.hour ?? 0
                    let mm = c.minute ?? 0
                    dateTime = ReminderCompute.merge(day: dateTime, hour: hh, minute: mm)
                    syncFromDate()
                    return
                }
            }

            // invalid -> revert
            syncFromDate()
        }

        private func bump(minutes delta: Int) {
            let cal = Calendar.current
            let c = cal.dateComponents([.hour, .minute], from: dateTime)
            let baseHour = c.hour ?? 0
            let baseMin = c.minute ?? 0

            let total = (baseHour * 60 + baseMin + delta) % (24 * 60)
            let wrapped = total < 0 ? total + (24 * 60) : total

            let newHour = wrapped / 60
            let newMin = wrapped % 60

            dateTime = ReminderCompute.merge(day: dateTime, hour: newHour, minute: newMin)
            syncFromDate()
        }
    }
#endif

// MARK: - Reminder Checklist Store

private enum ReminderChecklistStore {
    private static let idPrefix = "lystaria.reminderChecklist.id."
    private static let fingerprintPrefix = "lystaria.reminderChecklist.fingerprint."
    private static let newDraftKey = "lystaria.reminderChecklist.newDraft"

    private static func idKey(for reminder: LystariaReminder) -> String {
        idPrefix + String(describing: reminder.id)
    }

    private static func fingerprint(for reminder: LystariaReminder) -> String {
        let schedule = reminder.schedule
        let kind = schedule?.kind.rawValue ?? "once"
        let timeOfDay = schedule?.timeOfDay ?? ""
        let timesOfDay = (schedule?.timesOfDay ?? []).joined(separator: ",")
        let daysOfWeek = (schedule?.daysOfWeek ?? []).map(String.init).joined(separator: ",")
        let dayOfMonth = schedule?.dayOfMonth.map(String.init) ?? ""
        let anchorMonth = schedule?.anchorMonth.map(String.init) ?? ""
        let anchorDay = schedule?.anchorDay.map(String.init) ?? ""
        let interval = schedule?.interval.map(String.init) ?? ""
        let intervalMinutes = schedule?.intervalMinutes.map(String.init) ?? ""

        return [
            reminder.title.trimmingCharacters(in: .whitespacesAndNewlines),
            reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            kind,
            timeOfDay,
            timesOfDay,
            daysOfWeek,
            dayOfMonth,
            anchorMonth,
            anchorDay,
            interval,
            intervalMinutes,
        ].joined(separator: "|")
    }

    private static func fingerprintKey(for reminder: LystariaReminder) -> String {
        fingerprintPrefix + fingerprint(for: reminder)
    }

    static func newDraftItems() -> [String] {
        let raw = UserDefaults.standard.array(forKey: newDraftKey) as? [String] ?? []
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func setNewDraftItems(_ items: [String]) {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            UserDefaults.standard.removeObject(forKey: newDraftKey)
        } else {
            UserDefaults.standard.set(cleaned, forKey: newDraftKey)
        }
    }

    static func clearNewDraftItems() {
        UserDefaults.standard.removeObject(forKey: newDraftKey)
    }

    static func items(for reminder: LystariaReminder) -> [String] {
        let idRaw = UserDefaults.standard.array(forKey: idKey(for: reminder)) as? [String]
        let fingerprintRaw = UserDefaults.standard.array(forKey: fingerprintKey(for: reminder)) as? [String]
        let raw = idRaw ?? fingerprintRaw ?? []

        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func setItems(_ items: [String], for reminder: LystariaReminder) {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let idStorageKey = idKey(for: reminder)
        let fingerprintStorageKey = fingerprintKey(for: reminder)

        if cleaned.isEmpty {
            UserDefaults.standard.removeObject(forKey: idStorageKey)
            UserDefaults.standard.removeObject(forKey: fingerprintStorageKey)
        } else {
            UserDefaults.standard.set(cleaned, forKey: idStorageKey)
            UserDefaults.standard.set(cleaned, forKey: fingerprintStorageKey)
        }
    }
}

// MARK: - Reminder Badge Helpers

/// Returns true if the reminder is considered completed for the given occurrence date.
private func isReminderCompleted(_ reminder: LystariaReminder, occurrenceDate: Date) -> Bool {
    let cal = ReminderCompute.tzCalendar

    if let completed = reminder.lastCompletedAt,
       cal.isDate(completed, inSameDayAs: occurrenceDate)
    {
        return true
    }

    if !reminder.isRecurring,
       let ack = reminder.acknowledgedAt,
       cal.isDate(ack, inSameDayAs: occurrenceDate)
    {
        return true
    }

    return false
}

/// Returns true when the reminder belongs to a previous calendar day and still is not completed.
private func isReminderOverdue(_ reminder: LystariaReminder, now: Date) -> Bool {
    let cal = ReminderCompute.tzCalendar
    let todayStart = cal.startOfDay(for: now)
    let dueDate = reminder.nextRunAt

    return dueDate < todayStart && !isReminderCompleted(reminder, occurrenceDate: dueDate)
}

/// Returns true when the reminder is due today right now and is not overdue/completed.
private func isReminderDueNow(_ reminder: LystariaReminder, now: Date) -> Bool {
    guard reminder.status == .scheduled else { return false }

    if let acknowledgedAt = reminder.acknowledgedAt,
       acknowledgedAt >= reminder.nextRunAt {
        return false
    }

    let cal = ReminderCompute.tzCalendar
    let todayStart = cal.startOfDay(for: now)
    let dueDate = reminder.nextRunAt

    return dueDate >= todayStart &&
        dueDate <= now &&
        !isReminderCompleted(reminder, occurrenceDate: dueDate) &&
        !isReminderOverdue(reminder, now: now)
}

/// Returns true when the reminder is still ahead today/in the future and not completed.
private func isReminderUpcoming(_ reminder: LystariaReminder, now: Date) -> Bool {
    guard reminder.status == .scheduled else { return false }

    if let acknowledgedAt = reminder.acknowledgedAt,
       acknowledgedAt >= reminder.nextRunAt {
        return false
    }

    let dueDate = reminder.nextRunAt
    return dueDate > now && !isReminderCompleted(reminder, occurrenceDate: dueDate)
}

enum ReminderStatusBadgeStyle {
    case overdue
    case dueNow
    case upcoming
}

struct ReminderStatusBadge: View {
    let label: String
    let style: ReminderStatusBadgeStyle
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(badgeBackground)
            .foregroundStyle(badgeForeground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(badgeBorder, lineWidth: 1),
            )
    }

    private var badgeBackground: Color {
        switch style {
        case .overdue:
            LColors.danger.opacity(0.17)
        case .dueNow:
            LColors.accent.opacity(0.18)
        case .upcoming:
            Color.white.opacity(0.09)
        }
    }

    private var badgeForeground: Color {
        switch style {
        case .overdue:
            LColors.danger
        case .dueNow:
            LColors.accent
        case .upcoming:
            LColors.textPrimary
        }
    }

    private var badgeBorder: Color {
        switch style {
        case .overdue:
            LColors.danger.opacity(0.45)
        case .dueNow:
            LColors.accent.opacity(0.44)
        case .upcoming:
            LColors.glassBorder
        }
    }
}

// MARK: - Reminder Color Picker

struct ReminderColorPicker: View {
    @Binding var selectedColor: String

    var body: some View {
        HStack(spacing: 14) {
            ColorPicker("", selection: Binding(
                get: { Color(ly_hex: selectedColor) },
                set: { selectedColor = $0.toHexString() }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 36, height: 36)

            Circle()
                .fill(Color(ly_hex: selectedColor))
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))

            Text("Tap to choose a color")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LColors.textSecondary)

            Spacer()
        }
    }
}
