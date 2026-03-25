// RemindersView.swift
// Lystaria

import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var authUsers: [AuthUser]
    @Query private var habits: [Habit]
    @Query private var events: [CalendarEvent]
    @Query private var medications: [Medication]
    @Query(sort: \LystariaReminder.nextRunAt) private var allReminders: [LystariaReminder]

    @State private var showNewReminder = false
    @State private var filter = "all"
    @State private var visibleCount: Int = 5
    @State private var showKanban = false
    
    // Onboarding
    @StateObject private var onboarding = OnboardingManager()

    // Editing
    @State private var editingReminder: LystariaReminder? = nil

    // Completion toast
    @State private var toastMessage: String? = nil

    private let filterOptions = ["all","once","daily","weekly","monthly","yearly","interval"]

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

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                mainContent
                toastOverlay
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
                    reminder: r
                )
                .preferredColorScheme(.dark)
            }
            .navigationDestination(isPresented: $showKanban) {
                KanbanView()
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
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    filtersSection
                    remindersSection
                    Spacer(minLength: 96)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
                .frame(width: geo.size.width, alignment: .leading)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: greeting, font: .title.bold())
                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showNewReminder = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        StepCountView()
                            .preferredColorScheme(.dark)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("shoefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("stepsIcon")

                    NavigationLink {
                        WaterTrackingView()
                            .preferredColorScheme(.dark)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("glassfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("waterIcon")

                    Button {
                        showKanban = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
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
                ForEach(visibleReminders) { reminder in
                    let id = reminder.persistentModelID
                    ReminderCard(
                        reminder: reminder,
                        onDone: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                markDone(live)
                            }
                        },
                        onSnooze: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                snooze(live)
                            }
                        },
                        onEdit: { editingReminder = reminder },
                        onDelete: {
                            if let live = modelContext.model(for: id) as? LystariaReminder {
                                delete(live)
                            }
                        }
                    )
                }

                if filtered.count > 5 {
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
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .padding(.bottom, 110)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(99)
        }
    }

    private func logHabitIfLinked(_ reminder: LystariaReminder) {
        // Only habit-linked reminders should affect habit logs.
        guard reminder.linkedKind == .habit,
              let hid = reminder.linkedHabitId,
              let habit = habits.first(where: { $0.id == hid }) else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())
        let cap = max(1, habit.timesPerDay)

        if let existing = (habit.logs ?? []).first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) }) {
            if existing.count < cap {
                existing.count += 1
                existing.updatedAt = Date()
            }
        } else {
            let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
            modelContext.insert(newLog)
        }

        habit.updatedAt = Date()
    }

    private func logMedicationIfLinked(_ reminder: LystariaReminder) {
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
            medication: medication
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
                title: reminder.title
            )
        } else if isEventReminder {
            _ = try? SelfCarePointsManager.awardEventReminderCompletion(
                in: modelContext,
                eventId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title
            )
        } else {
            _ = try? SelfCarePointsManager.awardReminderCompletion(
                in: modelContext,
                reminderId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title
            )
        }
    }

    private func resetTodayHabitProgressIfNeeded(for reminder: LystariaReminder, now: Date) {
        guard reminder.linkedKind == .habit,
              let habitID = reminder.linkedHabitId,
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        let cal = Calendar.current
        let todaysLogs = (habit.logs ?? []).filter { log in
            cal.isDate(log.dayStart, inSameDayAs: now)
        }

        let todaysCount = todaysLogs.reduce(0) { $0 + $1.count }
        let completionTarget = max(1, habit.timesPerDay)
        let isCompletedForToday = todaysCount >= completionTarget

        // Only reset if:
        // 1) the habit is currently considered completed for today, AND
        // 2) after marking this reminder done, it advanced to another occurrence later TODAY.
        guard isCompletedForToday,
              cal.isDate(reminder.nextRunAt, inSameDayAs: now),
              reminder.nextRunAt > now else { return }

        for log in todaysLogs {
            modelContext.delete(log)
        }

        habit.logs = (habit.logs ?? []).filter { log in
            !cal.isDate(log.dayStart, inSameDayAs: now)
        }

        habit.updatedAt = now
    }

    private func markDone(_ reminder: LystariaReminder) {
        print("[RemindersView] markDone id=\(reminder.id) title=\(reminder.title)")

        // If this reminder is linked to a habit, count it as a habit log.
        logHabitIfLinked(reminder)
        logMedicationIfLinked(reminder)
        let completedOccurrenceDate = reminder.nextRunAt

        if reminder.isRecurring {
            let now = Date()
            // Skip past the just-completed occurrence so we truly advance to the NEXT one.
            reminder.nextRunAt = ReminderCompute.nextRun(after: now.addingTimeInterval(91), reminder: reminder)

            // Clear acknowledged state so the circle unchecks immediately on re-render.
            reminder.acknowledgedAt = nil

            reminder.updatedAt = Date()

            // If this is a habit-linked reminder and another same-day reminder is still due later,
            // fully reset today's habit progress so the next same-day occurrence starts fresh.
            resetTodayHabitProgressIfNeeded(for: reminder, now: now)

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

    private func snooze(_ reminder: LystariaReminder) {
        print("[RemindersView] snooze id=\(reminder.id) old nextRunAt=\(reminder.nextRunAt)")
        let cal = ReminderCompute.tzCalendar
        reminder.nextRunAt = cal.date(byAdding: .minute, value: 10, to: reminder.nextRunAt) ?? reminder.nextRunAt
        reminder.updatedAt = Date()
        try? modelContext.save()
        print("[RemindersView] snoozed new nextRunAt=\(reminder.nextRunAt)")
        NotificationManager.shared.snoozeReminder(reminder)
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

// MARK: - Reminder Card

struct ReminderCard: View {
    @Bindable var reminder: LystariaReminder
    @State private var isChecklistExpanded = false
    @State private var showingDeleteConfirm = false
    @State private var showingReschedulePopup = false
    @State private var rescheduleDateTime = Date()
    let onDone: () -> Void
    let onSnooze: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var scheduleLabel: String {
        guard let schedule = reminder.schedule else { return "Once" }
        
        if (schedule.interval ?? 1) > 1,
           schedule.kind != .interval,
           schedule.kind != .once {
            return "Custom"
        }
        
        return schedule.kind.label
    }
    
    private var badgeColor: Color {
        if let schedule = reminder.schedule,
           (schedule.interval ?? 1) > 1,
           schedule.kind != .interval,
           schedule.kind != .once {
            return Color(red: 201/255, green: 44/255, blue: 194/255) // #c92cc2
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
    
    private var isDone: Bool {
        guard let ack = reminder.acknowledgedAt else { return false }
        // Consider "done" if acknowledged today.
        return Calendar.current.isDateInToday(ack)
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
        let s = df.string(from: d)
        return s
    }
    
    private var scheduledTimes: [String] {
        guard let schedule = reminder.schedule else { return [] }
        // Interval reminders don't have fixed times-of-day pills.
        if schedule.kind == .interval { return [] }
        
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
            // Tiny pills that wrap nicely
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 3)], alignment: .leading, spacing: 3) {
                ForEach(scheduledTimes, id: \.self) { t in
                    Text(t)
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
    
    @ViewBuilder
    private func checklistPreviewView() -> some View {
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        
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
    
    @ViewBuilder
    private var reschedulePopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showingReschedulePopup = false
                }
            },
            width: 560,
            heightRatio: 0.82
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
    
    // --- STATUS BADGE HELPERS ---
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
    
    private func isUpcoming(now: Date) -> Bool {
        // Upcoming is within the next 24 hours (but not yet due), and not completed.
        if isDone { return false }
        if now >= reminder.nextRunAt { return false }
        return reminder.nextRunAt <= now.addingTimeInterval(24 * 60 * 60)
    }
    
    // Transparent status badge colors
    private var upcomingBadgeColor: Color { Color.teal.opacity(0.42) }
    private var dueNowBadgeColor: Color { Color.yellow.opacity(0.48) }
    
    var body: some View {
        // Recompute status badges periodically so they flip at the correct time.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let dueNow = isDueNow(now: now)
            let upcoming = isUpcoming(now: now)
            
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        LBadge(text: scheduleLabel, color: badgeColor)
                        
                        if dueNow {
                            LBadge(text: "DUE NOW", color: dueNowBadgeColor)
                        } else if upcoming {
                            LBadge(text: "UPCOMING", color: upcomingBadgeColor)
                        }
                        
                        Spacer()
                        
                        Button { onDone() } label: {
                            Image(systemName: isDone ? "circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isDone ? LColors.success : LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    timePillsView()
                    
                    Text(reminder.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                    
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
                            LButton(title: "Snooze", icon: "clock.arrow.circlepath", style: .secondary) { onSnooze() }
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
            .lystariaAlertConfirm(
                isPresented: $showingDeleteConfirm,
                title: "Delete Reminder?",
                message: "This reminder will be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive
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
        }
    }
}

// MARK: - New Reminder Sheet

struct NewReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var medications: [Medication]
    let onClose: () -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var checklistEntries: [String] = [""]
    @FocusState private var focusedChecklistIndex: Int?

    @State private var onceDateTime = Date()
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

    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }
        if scheduleKind == .weekly { return !selectedDays.isEmpty }
        return true
    }
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LystariaFullScreenForm(
            title: "New Reminder",
            onCancel: { onClose() },
            canSave: canSave,
            onSave: { save() }
        ) {
            formContent
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
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

            LabeledGlassField(label: "CHECKLIST ITEMS") {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(spacing: 8) {
                        ForEach(Array(checklistEntries.indices), id: \.self) { idx in
                            TextField(
                                idx == 0 ? "Checklist item" : "Another item",
                                text: Binding(
                                    get: { checklistEntries[idx] },
                                    set: { checklistEntries[idx] = $0 }
                                )
                            )
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
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
                                    if isLast && checklistEntries.count > 1 {
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

            LabeledGlassField(label: "LINK MEDICATION") {
                VStack(alignment: .leading, spacing: 10) {
                    if medications.isEmpty {
                        Text("No medications available yet. Add medications from the Health page first.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    } else {
                        Picker(
                            "Medication",
                            selection: $selectedMedicationId
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
                            LystariaControlRow(label: nil) {
                                HStack(spacing: 12) {
                                    Text("Subtract")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Button {
                                        if linkedMedicationQuantity > 1 {
                                            linkedMedicationQuantity -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(linkedMedicationQuantity <= 1 ? LColors.textSecondary.opacity(0.5) : .white)
                                            .frame(width: 32, height: 32)
                                            .background(linkedMedicationQuantity <= 1 ? Color.white.opacity(0.05) : LColors.accent.opacity(0.85))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(linkedMedicationQuantity <= 1)

                                    Text("\(linkedMedicationQuantity)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )

                                    Button {
                                        if linkedMedicationQuantity < 100 {
                                            linkedMedicationQuantity += 1
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

                                    Text("per completion")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Spacer()
                                }
                            }
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
                anchorDay: $anchorDay
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        #if os(macOS)
        NSApp.keyWindow?.endEditing(for: nil)
        #endif
        DispatchQueue.main.async {
            guard self.canSave else { return }

            print("[NewReminderSheet] Save tapped. title=\(self.titleTrimmed), kind=\(self.scheduleKind.rawValue))")
            let schedule: ReminderSchedule?
            let runAt: Date

            if self.scheduleKind == .once {
                schedule = .once
                runAt = self.onceDateTime
            } else {
                let timeStrings = self.timesOfDay
                    .map { d -> String in
                        let (hh, mm) = ReminderCompute.hourMinute(from: d)
                        return String(format: "%02d:%02d", hh, mm)
                    }
                    .sorted()

                let primary = timeStrings.first

                let resolvedDayOfMonth: Int? = {
                    guard self.scheduleKind == .monthly else { return nil }
                    if self.monthlyMode == .specificDay { return self.dayOfMonth }
                    return nil // sameDay = engine uses start day
                }()
                let resolvedAnchorMonth: Int? = {
                    guard self.scheduleKind == .yearly else { return nil }
                    if self.yearlyMode == .specificDate { return self.anchorMonth }
                    return nil
                }()
                let resolvedAnchorDay: Int? = {
                    guard self.scheduleKind == .yearly else { return nil }
                    if self.yearlyMode == .specificDate { return self.anchorDay }
                    return nil
                }()

                schedule = ReminderSchedule(
                    kind: self.scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: self.scheduleKind == .interval ? nil : self.recurrenceInterval,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays).sorted() : nil,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
                )

                runAt = ReminderCompute.firstRun(
                    kind: self.scheduleKind,
                    startDay: self.startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays) : nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil,
                    recurrenceInterval: self.scheduleKind == .interval ? nil : self.recurrenceInterval,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay
                )
            }

            print("[NewReminderSheet] Computed first runAt=\(runAt), schedule=\(String(describing: schedule))")
            let newReminder = LystariaReminder(
                title: self.titleTrimmed,
                nextRunAt: runAt,
                schedule: schedule
            )
            if let selectedMedicationId = self.selectedMedicationId {
                newReminder.linkedKind = .medication
                newReminder.linkedMedicationId = selectedMedicationId
                newReminder.linkedMedicationQuantity = max(1, self.linkedMedicationQuantity)
                newReminder.linkedHabitId = nil
            } else {
                newReminder.linkedKindRaw = nil
                newReminder.linkedMedicationId = nil
                newReminder.linkedMedicationQuantity = 1
            }
            let detailsTrimmed = self.details.trimmingCharacters(in: .whitespacesAndNewlines)
            newReminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
            self.modelContext.insert(newReminder)

            let checklistItems = self.checklistEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            newReminder.checklistItems = checklistItems

            NotificationManager.shared.scheduleReminder(newReminder)
        #if DEBUG
            NotificationManager.shared.printPendingNotifications()
        #endif
            print("[NewReminderSheet] Inserted reminder with nextRunAt=\(runAt)")
            self.onClose()
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
    @State private var checklistEntries: [String] = [""]
    @FocusState private var focusedChecklistIndex: Int?

    @State private var scheduleKind: ReminderScheduleKind = .once
    @State private var onceDateTime = Date()
    @FocusState private var detailsFocused: Bool

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

    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }
        if scheduleKind == .weekly { return !selectedDays.isEmpty }
        return true
    }
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LystariaFullScreenForm(
            title: "Edit Reminder",
            onCancel: { onClose() },
            canSave: canSave,
            onSave: { apply() }
        ) {
            formContent
        }
        .onAppear { loadFromModel() }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
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

            LabeledGlassField(label: "CHECKLIST ITEMS") {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(spacing: 8) {
                        ForEach(Array(checklistEntries.indices), id: \.self) { idx in
                            TextField(
                                idx == 0 ? "Checklist item" : "Another item",
                                text: Binding(
                                    get: { checklistEntries[idx] },
                                    set: { checklistEntries[idx] = $0 }
                                )
                            )
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
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
                                    if isLast && checklistEntries.count > 1 {
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

            LabeledGlassField(label: "LINK MEDICATION") {
                VStack(alignment: .leading, spacing: 10) {
                    if medications.isEmpty {
                        Text("No medications available yet. Add medications from the Health page first.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    } else {
                        Picker(
                            "Medication",
                            selection: $selectedMedicationId
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
                            LystariaControlRow(label: nil) {
                                HStack(spacing: 12) {
                                    Text("Subtract")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Button {
                                        if linkedMedicationQuantity > 1 {
                                            linkedMedicationQuantity -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(linkedMedicationQuantity <= 1 ? LColors.textSecondary.opacity(0.5) : .white)
                                            .frame(width: 32, height: 32)
                                            .background(linkedMedicationQuantity <= 1 ? Color.white.opacity(0.05) : LColors.accent.opacity(0.85))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(linkedMedicationQuantity <= 1)

                                    Text("\(linkedMedicationQuantity)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )

                                    Button {
                                        if linkedMedicationQuantity < 100 {
                                            linkedMedicationQuantity += 1
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

                                    Text("per completion")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Spacer()
                                }
                            }
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
                anchorDay: $anchorDay
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFromModel() {
        print("[EditReminderSheet] loadFromModel for id=\(reminder.id) title=\(reminder.title)")
        title = reminder.title
        details = reminder.details ?? ""
        let storedChecklist = reminder.checklistItems
        checklistEntries = storedChecklist.isEmpty ? [""] : storedChecklist
        selectedMedicationId = reminder.linkedMedicationId
        linkedMedicationQuantity = max(1, reminder.linkedMedicationQuantity)

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
                    self.timesOfDay = parsed.map { ReminderCompute.merge(day: Date(), hour: $0.h, minute: $0.m) }
                } else {
                    self.timesOfDay = [reminder.nextRunAt]
                }
            } else {
                self.timesOfDay = [reminder.nextRunAt]
            }

            if self.timesOfDay.isEmpty {
                self.timesOfDay = [reminder.nextRunAt]
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
               let storedDay = reminder.schedule?.anchorDay {
                anchorMonth = storedMonth
                anchorDay = storedDay
                yearlyMode = .specificDate
            } else {
                anchorMonth = Calendar.current.component(.month, from: reminder.nextRunAt)
                anchorDay = Calendar.current.component(.day, from: reminder.nextRunAt)
                yearlyMode = .sameDay
            }
            print("[EditReminderSheet] Recurring: startDay=\(startDay), timesOfDay=\(self.timesOfDay), days=\(selectedDays.sorted()), intervalMinutes=\(intervalMinutes)")
        }
    }

    private func apply() {
    #if os(macOS)
        NSApp.keyWindow?.endEditing(for: nil)
    #endif
        DispatchQueue.main.async {
            guard self.canSave else { return }

            print("[EditReminderSheet] Apply tapped. title=\(self.titleTrimmed), kind=\(self.scheduleKind.rawValue))")
            self.reminder.title = self.titleTrimmed

            let detailsTrimmed = self.details.trimmingCharacters(in: .whitespacesAndNewlines)
            self.reminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed

            let checklistItems = self.checklistEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            self.reminder.checklistItems = checklistItems

            if let selectedMedicationId = self.selectedMedicationId {
                self.reminder.linkedKind = .medication
                self.reminder.linkedMedicationId = selectedMedicationId
                self.reminder.linkedMedicationQuantity = max(1, self.linkedMedicationQuantity)
                self.reminder.linkedHabitId = nil
            } else {
                self.reminder.linkedKindRaw = nil
                self.reminder.linkedMedicationId = nil
                self.reminder.linkedMedicationQuantity = 1
            }

            let schedule: ReminderSchedule?
            let runAt: Date

            if self.scheduleKind == .once {
                schedule = .once
                runAt = self.onceDateTime
            } else {
                let timeStrings = self.timesOfDay
                    .map { d -> String in
                        let (hh, mm) = ReminderCompute.hourMinute(from: d)
                        return String(format: "%02d:%02d", hh, mm)
                    }
                    .sorted()

                let primary = timeStrings.first

                let resolvedDayOfMonth: Int? = {
                    guard self.scheduleKind == .monthly else { return nil }
                    if self.monthlyMode == .specificDay { return self.dayOfMonth }
                    return nil // sameDay = engine uses start day
                }()
                let resolvedAnchorMonth: Int? = {
                    guard self.scheduleKind == .yearly else { return nil }
                    if self.yearlyMode == .specificDate { return self.anchorMonth }
                    return nil
                }()
                let resolvedAnchorDay: Int? = {
                    guard self.scheduleKind == .yearly else { return nil }
                    if self.yearlyMode == .specificDate { return self.anchorDay }
                    return nil
                }()

                schedule = ReminderSchedule(
                    kind: self.scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: self.scheduleKind == .interval ? nil : self.recurrenceInterval,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays).sorted() : nil,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
                )

                runAt = ReminderCompute.firstRun(
                    kind: self.scheduleKind,
                    startDay: self.startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays) : nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil,
                    recurrenceInterval: self.scheduleKind == .interval ? nil : self.recurrenceInterval,
                    dayOfMonth: resolvedDayOfMonth,
                    anchorMonth: resolvedAnchorMonth,
                    anchorDay: resolvedAnchorDay
                )
            }

            print("[EditReminderSheet] Computed runAt=\(runAt), schedule=\(String(describing: schedule))")

            self.reminder.schedule = schedule
            self.reminder.nextRunAt = runAt
            self.reminder.updatedAt = Date()

            print("[EditReminderSheet] Updated reminder id=\(self.reminder.id) nextRunAt=\(self.reminder.nextRunAt) updatedAt=\(String(describing: self.reminder.updatedAt))")

            NotificationManager.shared.scheduleReminder(self.reminder)
        #if DEBUG
            NotificationManager.shared.printPendingNotifications()
        #endif

            self.onClose()
        }
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
    @Binding var timesOfDay: [Date]           // recurring times
    @Binding var selectedDays: Set<Int>       // weekly days (0=Sun … 6=Sat)
    @Binding var recurrenceInterval: Int      // every N days/weeks/months/years
    @Binding var intervalMinutes: Int         // for .interval kind
    @Binding var monthlyMode: MonthlyMode     // .sameDay | .specificDay
    @Binding var dayOfMonth: Int              // 1-31 for .specificDay
    @Binding var yearlyMode: YearlyMode       // .sameDay | .specificDate
    @Binding var anchorMonth: Int
    @Binding var anchorDay: Int

    // MARK: Supporting types
    enum MonthlyMode: String, CaseIterable {
        case sameDay    = "Same day as start"
        case specificDay = "Specific day"
    }

    enum YearlyMode: String, CaseIterable {
        case sameDay     = "Same day as start"
        case specificDate = "Specific date"
    }

    // MARK: Private helpers
    private let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    private var monthSymbols: [String] { Calendar.current.monthSymbols }

    private var intervalUnit: String {
        let plural = recurrenceInterval != 1
        switch scheduleKind {
        case .daily:   return plural ? "days"   : "day"
        case .weekly:  return plural ? "weeks"  : "week"
        case .monthly: return plural ? "months" : "month"
        case .yearly:  return plural ? "years"  : "year"
        default:       return ""
        }
    }

    private var maxAnchorDay: Int {
        var comps = DateComponents()
        comps.year  = 2024
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
                                            .stroke(LColors.glassBorder, lineWidth: 1)
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
                                    ForEach(0..<7, id: \.self) { d in
                                        let on = selectedDays.contains(d)
                                        Button {
                                            if on { selectedDays.remove(d) }
                                            else  { selectedDays.insert(d) }
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
                                            ForEach(1...31, id: \.self) { d in
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
                                            ForEach(1...12, id: \.self) { m in
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
                                            ForEach(1...maxAnchorDay, id: \.self) { d in
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
    @ViewBuilder
    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
#if os(macOS)
                LTimeEntryRow(
                    label: idx == 0 ? "Time" : "Time \(idx + 1)",
                    dateTime: Binding(
                        get: { timesOfDay[idx] },
                        set: { timesOfDay[idx] = $0 }
                    )
                )
#else
                LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                    DatePicker("",
                        selection: Binding(
                            get: { timesOfDay[idx] },
                            set: { timesOfDay[idx] = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
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
                        .stroke(LColors.glassBorder, lineWidth: 1)
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
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

#if os(macOS)
// Date row without the grey DatePicker field
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

// 12-hour typed time + steppers that NEVER change the date
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
            make("h a"), make("ha")
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
                .onChange(of: text) { oldValue, newValue in
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
                .onChange(of: focused) { oldValue, newValue in
                    if !newValue { applyTypedTime() }
                }
                .onChange(of: dateTime) { oldValue, newValue in
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
            intervalMinutes
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

// MARK: - ReminderCompute

enum ReminderCompute {
    static var tzCalendar: Calendar {
        var cal = Calendar.current
        let tzID = NotificationManager.shared.effectiveTimezoneID
        cal.timeZone = TimeZone(identifier: tzID) ?? .current
        return cal
    }

    static func hourMinute(from date: Date) -> (Int, Int) {
        let cal = tzCalendar
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    static func parseHHMM(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let hh = Int(parts[0]),
              let mm = Int(parts[1]),
              (0...23).contains(hh),
              (0...59).contains(mm) else { return nil }
        return (hh, mm)
    }

    static func merge(day: Date, hour: Int, minute: Int) -> Date {
        var c = tzCalendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return tzCalendar.date(from: c) ?? day
    }

    static func merge(day: Date, hour: Int, minute: Int, in timeZone: TimeZone) -> Date {
        var cal = tzCalendar
        cal.timeZone = timeZone
        var c = cal.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return cal.date(from: c) ?? day
    }

    static func firstRun(
        kind: ReminderScheduleKind,
        startDay: Date,
        timesOfDay: [String],
        daysOfWeek: [Int]?,
        intervalMinutes: Int?,
        recurrenceInterval: Int?,
        dayOfMonth: Int?,
        anchorMonth: Int?,
        anchorDay: Int?
    ) -> Date {
        let cal = tzCalendar
        let now = Date()

        if kind == .interval, let iv = intervalMinutes {
            let base = cal.date(bySetting: .second, value: 0, of: now) ?? now
            return cal.date(byAdding: .minute, value: iv, to: base) ?? base
        }

        // Parse times and sort
        let parsedTimes: [(h: Int, m: Int)] = timesOfDay
            .compactMap { parseHHMM($0) }
            .sorted { a, b in
                (a.0, a.1) < (b.0, b.1)
            }

        // Fallback if somehow empty
        let times = parsedTimes.isEmpty ? [(hourMinute(from: now).0, hourMinute(from: now).1)] : parsedTimes

        let repeatEvery = max(1, recurrenceInterval ?? 1)

        let normalizedStart = cal.startOfDay(for: startDay)
        var day = normalizedStart
        var iterations = 0

        // Find the earliest valid run from day forward
        while true {
            iterations += 1
            if iterations > 365 {
                // Safety cap: if no valid date found within a year, fall back to
                // tomorrow at the first available time to prevent an infinite loop.
                let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
                return merge(day: tomorrow, hour: times.first!.h, minute: times.first!.m)
            }

            if kind == .daily {
                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                if deltaDays % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if kind == .monthly {
                let wantedDay = min(dayOfMonth ?? cal.component(.day, from: normalizedStart), 31)
                let dayComponent = cal.component(.day, from: day)
                if dayComponent != wantedDay {
                    let year = cal.component(.year, from: day)
                    let month = cal.component(.month, from: day)
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = min(wantedDay, cal.range(of: .day, in: .month, for: day)?.count ?? wantedDay)
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let startMonthIndex = (cal.component(.year, from: normalizedStart) * 12) + cal.component(.month, from: normalizedStart)
                let currentMonthIndex = (cal.component(.year, from: day) * 12) + cal.component(.month, from: day)
                let monthDelta = currentMonthIndex - startMonthIndex
                if monthDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if kind == .yearly {
                let wantedMonth = anchorMonth ?? cal.component(.month, from: normalizedStart)
                let fallbackDay = anchorDay ?? cal.component(.day, from: normalizedStart)
                let maxDay = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: cal.component(.year, from: day), month: wantedMonth, day: 1)) ?? day)?.count ?? 31
                let wantedDay = min(fallbackDay, maxDay)

                let monthComponent = cal.component(.month, from: day)
                let dayComponent = cal.component(.day, from: day)
                if monthComponent != wantedMonth || dayComponent != wantedDay {
                    var comps = DateComponents()
                    comps.year = cal.component(.year, from: day)
                    comps.month = wantedMonth
                    comps.day = wantedDay
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let yearDelta = cal.component(.year, from: day) - cal.component(.year, from: normalizedStart)
                if yearDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            // Weekly restriction
            if kind == .weekly, let days = daysOfWeek, !days.isEmpty {
                let wanted = Set(days)
                let weekdayIndex = cal.component(.weekday, from: day) - 1
                if !wanted.contains(weekdayIndex) {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            // Try each time for this day
            var best: Date? = nil
            for (hh, mm) in times {
                let candidate = merge(day: day, hour: hh, minute: mm)

                // 90-second tolerance window like before
                let secondsBehind = now.timeIntervalSince(candidate)
                if secondsBehind <= 90 {
                    if best == nil || candidate < best! { best = candidate }
                }
            }

            if let best { return best }

            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
    }

    static func nextRun(after now: Date, reminder: LystariaReminder) -> Date {
        guard let schedule = reminder.schedule else { return reminder.nextRunAt }
        let cal = tzCalendar

        if schedule.kind == .interval, let iv = schedule.intervalMinutes {
            let base = cal.date(bySetting: .second, value: 0, of: now) ?? now
            return cal.date(byAdding: .minute, value: iv, to: base) ?? base
        }

        let timeStrings = (schedule.timesOfDay?.isEmpty == false)
            ? (schedule.timesOfDay ?? [])
            : (schedule.timeOfDay != nil ? [schedule.timeOfDay!] : [])

        let parsedTimes: [(h: Int, m: Int)] = timeStrings
            .compactMap { parseHHMM($0) }
            .sorted { a, b in
                (a.0, a.1) < (b.0, b.1)
            }

        let times = parsedTimes.isEmpty
            ? [(hourMinute(from: reminder.nextRunAt).0, hourMinute(from: reminder.nextRunAt).1)]
            : parsedTimes

        let startSearchDay = cal.startOfDay(for: now)
        let repeatEvery = max(1, schedule.interval ?? 1)
        let normalizedStart = cal.startOfDay(for: reminder.nextRunAt)

        var day = startSearchDay
        var iterations = 0

        while true {
            iterations += 1
            if iterations > 1500 {
                let fallbackDay = cal.date(byAdding: .day, value: 1, to: startSearchDay) ?? startSearchDay
                let first = times.first!
                return merge(day: fallbackDay, hour: first.h, minute: first.m)
            }

            if schedule.kind == .daily {
                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                if deltaDays % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .weekly {
                let wanted = Set(schedule.daysOfWeek ?? [])
                if !wanted.isEmpty {
                    let weekdayIndex = cal.component(.weekday, from: day) - 1
                    if !wanted.contains(weekdayIndex) {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                        continue
                    }
                }

                let deltaDays = cal.dateComponents([.day], from: normalizedStart, to: day).day ?? 0
                let weekDelta = max(0, deltaDays / 7)
                if weekDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .monthly {
                let wantedDay = min(schedule.dayOfMonth ?? cal.component(.day, from: normalizedStart), 31)
                let dayComponent = cal.component(.day, from: day)
                if dayComponent != wantedDay {
                    let year = cal.component(.year, from: day)
                    let month = cal.component(.month, from: day)
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = min(wantedDay, cal.range(of: .day, in: .month, for: day)?.count ?? wantedDay)
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let startMonthIndex = (cal.component(.year, from: normalizedStart) * 12) + cal.component(.month, from: normalizedStart)
                let currentMonthIndex = (cal.component(.year, from: day) * 12) + cal.component(.month, from: day)
                let monthDelta = currentMonthIndex - startMonthIndex
                if monthDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            if schedule.kind == .yearly {
                let wantedMonth = schedule.anchorMonth ?? cal.component(.month, from: normalizedStart)
                let fallbackDay = schedule.anchorDay ?? cal.component(.day, from: normalizedStart)
                let maxDay = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: cal.component(.year, from: day), month: wantedMonth, day: 1)) ?? day)?.count ?? 31
                let wantedDay = min(fallbackDay, maxDay)

                let monthComponent = cal.component(.month, from: day)
                let dayComponent = cal.component(.day, from: day)
                if monthComponent != wantedMonth || dayComponent != wantedDay {
                    var comps = DateComponents()
                    comps.year = cal.component(.year, from: day)
                    comps.month = wantedMonth
                    comps.day = wantedDay
                    let candidateDay = cal.startOfDay(for: cal.date(from: comps) ?? day)
                    if candidateDay < day {
                        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    } else {
                        day = candidateDay
                    }
                    continue
                }

                let yearDelta = cal.component(.year, from: day) - cal.component(.year, from: normalizedStart)
                if yearDelta % repeatEvery != 0 {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                    continue
                }
            }

            for (hh, mm) in times {
                let candidate = merge(day: day, hour: hh, minute: mm)
                let secondsBehind = now.timeIntervalSince(candidate)
                if secondsBehind <= 90 {
                    return candidate
                }
            }

            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
    }
}
