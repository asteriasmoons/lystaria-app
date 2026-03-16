// RemindersView.swift
// Lystaria

import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var authUsers: [AuthUser]
    @Query private var habits: [Habit]
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // Header
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


                        // Filters
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

                        // List
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

                        Spacer(minLength: 96)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 96)
                }
                .frame(maxWidth: .infinity)
                .clipped()
                

                // ── Completion toast ──────────────────────────────
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
            .overlay {
                if showNewReminder {
                    NewReminderSheet(onClose: {
                        showNewReminder = false
                    })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }
            }
            .navigationDestination(isPresented: $showKanban) {
                KanbanView()
                    .preferredColorScheme(.dark)
            }
            // Use a boolean-driven sheet so we DO NOT depend on Identifiable behavior.
            .overlay {
                if let r = editingReminder {
                    EditReminderSheet(
                        onClose: {
                            editingReminder = nil
                        },
                        reminder: r
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(60)
                }
            }
            // Handle "Done ✓" tapped on the system notification banner
            .onReceive(NotificationCenter.default.publisher(for: .lystariaNotificationAction)) { note in
                guard let info = note.userInfo,
                      let actionID = info["actionID"] as? String,
                      actionID == NotificationManager.doneActionID,
                      let userInfo = info["userInfo"] as? [String: Any] else { return }

                // Resolve the reminder ONLY by stable ids.
                let reminderID = userInfo["reminderID"] as? String

                let match = allReminders.first { r in
                    if let rid = reminderID {
                        if let sid = r.serverId, sid == rid { return true }
                    }
                    return false
                }

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

    private func logHabitIfLinked(_ reminder: LystariaReminder) {
        // Only habit-linked reminders should affect habit logs.
        guard reminder.linkedKind == .habit,
              let hid = reminder.linkedHabitId,
              let habit = habits.first(where: { $0.id == hid }) else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())
        let cap = max(1, habit.timesPerDay)

        if let existing = habit.logs.first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) }) {
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


    private func resetTodayHabitProgressIfNeeded(for reminder: LystariaReminder, now: Date) {
        guard reminder.linkedKind == .habit,
              let habitID = reminder.linkedHabitId,
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        let cal = Calendar.current
        let todaysLogs = habit.logs.filter { log in
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

        habit.logs.removeAll { log in
            cal.isDate(log.dayStart, inSameDayAs: now)
        }

        habit.updatedAt = now
    }

    private func markDone(_ reminder: LystariaReminder) {
        print("[RemindersView] markDone id=\(reminder.id) title=\(reminder.title)")

        // If this reminder is linked to a habit, count it as a habit log.
        logHabitIfLinked(reminder)

        if reminder.isRecurring {
            let now = Date()
            // Skip past the just-completed occurrence so we truly advance to the NEXT one.
            reminder.nextRunAt = ReminderCompute.nextRun(after: now.addingTimeInterval(91), reminder: reminder)

            // Clear acknowledged state so the circle unchecks immediately on re-render.
            reminder.acknowledgedAt = nil

            // Mark dirty so Supabase sync picks up the new nextRunAt.
            reminder.markDirty()

            // If this is a habit-linked reminder and another same-day reminder is still due later,
            // fully reset today's habit progress so the next same-day occurrence starts fresh.
            resetTodayHabitProgressIfNeeded(for: reminder, now: now)

            // Persist immediately — this triggers SwiftData to diff and re-render the card,
            // which is what actually unchecks the circle in the UI.
            try? modelContext.save()

            print("[RemindersView] markDone recurring -> nextRunAt=\(reminder.nextRunAt)")
            NotificationManager.shared.cancelReminder(reminder)
            NotificationManager.shared.scheduleReminder(reminder)

            let nextText = reminder.nextRunAt.formatted(date: .abbreviated, time: .shortened)
            showToast("\(reminder.title) done · Next: \(nextText)")
        } else {
            // One-time reminders stay checked for today.
            reminder.acknowledgedAt = Date()
            reminder.status = .sent

            // Mark dirty so Supabase sync pushes the completed state.
            reminder.markDirty()

            // Persist so the view reflects checked state and sync can pick it up.
            try? modelContext.save()

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
        reminder.markDirty()
        try? modelContext.save()
        print("[RemindersView] snoozed new nextRunAt=\(reminder.nextRunAt)")
        NotificationManager.shared.snoozeReminder(reminder)
    }

    private func delete(_ reminder: LystariaReminder) {
        print("[RemindersView] delete id=\(reminder.id) title=\(reminder.title)")
        reminder.status = .deleted
        reminder.markDirty()
        try? modelContext.save()
        print("[RemindersView] deleted status=\(reminder.status.rawValue)")
        NotificationManager.shared.cancelReminder(reminder)
    }
}

// MARK: - Reminder Card

struct ReminderCard: View {
    @Bindable var reminder: LystariaReminder
    let onDone: () -> Void
    let onSnooze: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var scheduleLabel: String {
        guard let schedule = reminder.schedule else { return "Once" }

        if schedule.kind == .daily, (schedule.interval ?? 1) > 1 {
            return "Custom"
        }

        return schedule.kind.label
    }

    private var badgeColor: Color {
        if let schedule = reminder.schedule,
           schedule.kind == .daily,
           (schedule.interval ?? 1) > 1 {
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
                            Image(systemName: isDone ? "checkmark.circle.fill" : "checkmark.circle")
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

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Text(timeText)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 10) {
                        LButton(title: "Snooze", icon: "clock.arrow.circlepath", style: .secondary) { onSnooze() }
                        LButton(title: "Edit", icon: "pencil", style: .secondary) { onEdit() }
                        GradientCapsuleButton(title: "Delete", icon: "trashfill") { onDelete() }
                    }
                }
            }
        }
    }
}

// MARK: - New Reminder Sheet

struct NewReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    let onClose: () -> Void

    @State private var title = ""
    @State private var details = ""

    @State private var onceDateTime = Date()

    @State private var scheduleKind: ReminderScheduleKind = .once
    @State private var startDay = Date()
    @State private var timesOfDay: [Date] = [Date()]
    @State private var selectedDays: Set<Int> = []
    @State private var intervalMinutes: Int = 60

    private let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onClose()
                }
            },
            width: 560,
            heightRatio: 0.82
        ) {
            header
        } content: {
            content
        } footer: {
            footer
        }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "New Reminder", font: .title2.bold())
            Spacer()

            Button("Save") { save() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(titleTrimmed.isEmpty ? Color.gray.opacity(0.3) : LColors.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(titleTrimmed.isEmpty)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onClose()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var content: some View {
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
#if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
#endif
            }

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
                                    .overlay(
                                        Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            GlassCard(padding: 16) {
                VStack(spacing: 12) {
                    if scheduleKind == .once {
#if os(macOS)
                        LDateStepperRow(label: "Date", dateTime: $onceDateTime)
                        LTimeEntryRow(label: "Time", dateTime: $onceDateTime)
#else
                        LystariaControlRow(label: nil) {
                            DatePicker("", selection: $onceDateTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(LColors.accent)
                        }
#endif
                    } else {
#if os(macOS)
                        LDateStepperRow(label: "Start Day", dateTime: $startDay)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
                                LTimeEntryRow(label: idx == 0 ? "Time" : "Time \(idx + 1)", dateTime: Binding(
                                    get: { timesOfDay[idx] },
                                    set: { timesOfDay[idx] = $0 }
                                ))
                            }

                            timeButtons
                        }
#else
                        LystariaControlRow(label: "Start Day") {
                            DatePicker("", selection: $startDay, in: Date()..., displayedComponents: [.date])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(LColors.accent)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
                                LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                                    DatePicker(
                                        "",
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
                            }

                            timeButtons
                        }
#endif

                        if scheduleKind == .weekly {
                            HStack(spacing: 6) {
                                ForEach(0..<7, id: \.self) { d in
                                    let on = selectedDays.contains(d)
                                    Button {
                                        if on { selectedDays.remove(d) } else { selectedDays.insert(d) }
                                    } label: {
                                        Text(weekdays[d])
                                            .font(.system(size: 12, weight: .semibold))
                                            .frame(width: 36, height: 36)
                                            .background(on ? LColors.accent : Color.white.opacity(0.08))
                                            .foregroundStyle(on ? .white : LColors.textPrimary)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(on ? .clear : LColors.glassBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }

                        if scheduleKind == .interval {
                            LystariaControlRow(label: "Interval") {
                                Stepper(value: $intervalMinutes, in: 5...1440, step: 5) {
                                    Text("\(intervalMinutes) min")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        GlassCard(padding: 14) {
            Button { save() } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(titleTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
            }
            .buttonStyle(.plain)
            .disabled(titleTrimmed.isEmpty)
        }
    }

    private var timeButtons: some View {
        HStack(spacing: 10) {
            Button {
                timesOfDay.append(timesOfDay.last ?? Date())
            } label: {
                Text("Add Time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LColors.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                if timesOfDay.count > 1 {
                    timesOfDay.removeLast()
                }
            } label: {
                Text("Remove")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(timesOfDay.count <= 1)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func save() {
        #if os(macOS)
        NSApp.keyWindow?.endEditing(for: nil)
        #endif
        DispatchQueue.main.async {
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

                schedule = ReminderSchedule(
                    kind: self.scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: nil,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays).sorted() : nil,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
                )

                runAt = ReminderCompute.firstRun(
                    kind: self.scheduleKind,
                    startDay: self.startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays) : nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
                )
            }

            print("[NewReminderSheet] Computed first runAt=\(runAt), schedule=\(String(describing: schedule))")
            let newReminder = LystariaReminder(
                title: self.titleTrimmed,
                nextRunAt: runAt,
                schedule: schedule
            )
            let detailsTrimmed = self.details.trimmingCharacters(in: .whitespacesAndNewlines)
            newReminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
            self.modelContext.insert(newReminder)
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
    @Bindable var reminder: LystariaReminder

    @State private var title = ""
    @State private var details = ""

    @State private var scheduleKind: ReminderScheduleKind = .once
    @State private var onceDateTime = Date()

    @State private var startDay = Date()
    @State private var timesOfDay: [Date] = [Date()]
    @State private var selectedDays: Set<Int> = []
    @State private var intervalMinutes: Int = 60

    private let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onClose()
                }
            },
            width: 560,
            heightRatio: 0.82
        ) {
            header
        } content: {
            content
        } footer: {
            footer
        }
        .onAppear { loadFromModel() }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "Edit Reminder", font: .title2.bold())
            Spacer()

            Button("Save") { apply() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(titleTrimmed.isEmpty ? Color.gray.opacity(0.3) : LColors.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(titleTrimmed.isEmpty)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onClose()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var content: some View {
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
#if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
#else
                    // macOS: unavailable
#endif
            }

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
                                    .overlay(
                                        Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            GlassCard(padding: 16) {
                VStack(spacing: 12) {
                    if scheduleKind == .once {
#if os(macOS)
                        LDateStepperRow(label: "Date", dateTime: $onceDateTime)
                        LTimeEntryRow(label: "Time", dateTime: $onceDateTime)
#else
                        LystariaControlRow(label: "Date & Time") {
                            DatePicker("", selection: $onceDateTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(LColors.accent)
                        }
#endif
                    } else {
#if os(macOS)
                        LDateStepperRow(label: "Start Day", dateTime: $startDay)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
                                LTimeEntryRow(
                                    label: idx == 0 ? "Time" : "Time \(idx + 1)",
                                    dateTime: Binding(
                                        get: { timesOfDay[idx] },
                                        set: { timesOfDay[idx] = $0 }
                                    )
                                )
                            }

                            recurringTimeButtons
                        }
#else
                        LystariaControlRow(label: "Start Day") {
                            DatePicker("", selection: $startDay, displayedComponents: [.date])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(LColors.accent)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(timesOfDay.indices), id: \.self) { idx in
                                LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                                    DatePicker(
                                        "",
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
                            }

                            recurringTimeButtons
                        }
#endif

                        if scheduleKind == .weekly {
                            HStack(spacing: 6) {
                                ForEach(0..<7, id: \.self) { d in
                                    let on = selectedDays.contains(d)
                                    Button {
                                        if on {
                                            selectedDays.remove(d)
                                        } else {
                                            selectedDays.insert(d)
                                        }
                                    } label: {
                                        Text(weekdays[d])
                                            .font(.system(size: 12, weight: .semibold))
                                            .frame(width: 36, height: 36)
                                            .background(on ? LColors.accent : Color.white.opacity(0.08))
                                            .foregroundStyle(on ? .white : LColors.textPrimary)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().stroke(on ? .clear : LColors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }

                        if scheduleKind == .interval {
                            LystariaControlRow(label: "Interval") {
                                Stepper(value: $intervalMinutes, in: 5...1440, step: 5) {
                                    Text("\(intervalMinutes) min")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        GlassCard(padding: 14) {
            Button { apply() } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        titleTrimmed.isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(LGradients.blue)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
            }
            .buttonStyle(.plain)
            .disabled(titleTrimmed.isEmpty)
        }
    }

    private var recurringTimeButtons: some View {
        HStack(spacing: 10) {
            Button {
                timesOfDay.append(timesOfDay.last ?? Date())
            } label: {
                Text("Add Time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LColors.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                if timesOfDay.count > 1 {
                    timesOfDay.removeLast()
                }
            } label: {
                Text("Remove")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(timesOfDay.count <= 1)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func loadFromModel() {
        print("[EditReminderSheet] loadFromModel for id=\(reminder.id) title=\(reminder.title)")
        title = reminder.title
        details = reminder.details ?? ""

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
            intervalMinutes = reminder.schedule?.intervalMinutes ?? 60
            print("[EditReminderSheet] Recurring: startDay=\(startDay), timesOfDay=\(self.timesOfDay), days=\(selectedDays.sorted()), intervalMinutes=\(intervalMinutes)")
        }
    }

    private func apply() {
#if os(macOS)
        NSApp.keyWindow?.endEditing(for: nil)
#endif
        DispatchQueue.main.async {
            print("[EditReminderSheet] Apply tapped. title=\(self.titleTrimmed), kind=\(self.scheduleKind.rawValue))")
            self.reminder.title = self.titleTrimmed

            let detailsTrimmed = self.details.trimmingCharacters(in: .whitespacesAndNewlines)
            self.reminder.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed

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

                schedule = ReminderSchedule(
                    kind: self.scheduleKind,
                    timeOfDay: primary,
                    timesOfDay: timeStrings,
                    interval: nil,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays).sorted() : nil,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
                )

                runAt = ReminderCompute.firstRun(
                    kind: self.scheduleKind,
                    startDay: self.startDay,
                    timesOfDay: timeStrings,
                    daysOfWeek: self.scheduleKind == .weekly ? Array(self.selectedDays) : nil,
                    intervalMinutes: self.scheduleKind == .interval ? self.intervalMinutes : nil
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
        intervalMinutes: Int?
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

        // Normalize candidate day
        var day = cal.startOfDay(for: startDay)
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

        // Interval
        if schedule.kind == .interval, let iv = schedule.intervalMinutes {
            let base = cal.date(bySetting: .second, value: 0, of: now) ?? now
            return cal.date(byAdding: .minute, value: iv, to: base) ?? base
        }

        // Determine available times
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

        let calDay = tzCalendar.startOfDay(for: now)

        // Try to find the next time TODAY first
        var candidate: Date? = nil
        for (hh, mm) in times {
            let d = merge(day: calDay, hour: hh, minute: mm)
            let secondsBehind = now.timeIntervalSince(d)
            if secondsBehind <= 90 {
                candidate = d
                break
            }
        }

        // If none today, start from tomorrow at the first time
        var baseDay = calDay
        if candidate == nil {
            baseDay = cal.date(byAdding: .day, value: 1, to: calDay) ?? calDay
            let first = times.first!
            candidate = merge(day: baseDay, hour: first.h, minute: first.m)
        }

        var nextCandidate = candidate!

        switch schedule.kind {
        case .daily:
            return nextCandidate

        case .weekly:
            let wanted = Set(schedule.daysOfWeek ?? [])
            if wanted.isEmpty { return nextCandidate }

            var weeklyIterations = 0
            while !wanted.contains(cal.component(.weekday, from: nextCandidate) - 1) {
                weeklyIterations += 1
                if weeklyIterations > 14 {
                    // Safety cap: daysOfWeek contains no valid weekday values.
                    // Fall back to 1 day from now to avoid an infinite loop.
                    break
                }
                let nextDay = cal.date(byAdding: .day, value: 1, to: tzCalendar.startOfDay(for: nextCandidate)) ?? nextCandidate
                let first = times.first!
                nextCandidate = merge(day: nextDay, hour: first.h, minute: first.m)
            }
            return nextCandidate

        case .monthly:
            var next = nextCandidate
            if next <= now { next = cal.date(byAdding: .month, value: 1, to: next) ?? next }
            return next

        case .yearly:
            var next = nextCandidate
            if next <= now { next = cal.date(byAdding: .year, value: 1, to: next) ?? next }
            return next

        case .once:
            return reminder.nextRunAt

        case .interval:
            return nextCandidate
        }
    }
}
