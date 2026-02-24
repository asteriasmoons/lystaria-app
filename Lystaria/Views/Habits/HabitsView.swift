// HabitsView.swift
// Lystaria

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    @State private var showNewHabit = false
    @State private var editingHabit: Habit? = nil

    private var activeHabits: [Habit] { habits.filter { !$0.isArchived } }
    private var archivedHabits: [Habit] { habits.filter { $0.isArchived } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LystariaBackground()

            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    // Header
                    HStack {
                        GradientTitle(text: "Habits", size: 26)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    if habits.isEmpty {
                        GlassCard {
                            EmptyState(
                                icon: "flame.slash",
                                message: "No habits yet.\nStart building better routines.",
                                actionLabel: "Create Habit"
                            ) { showNewHabit = true }
                        }
                        .padding(.horizontal, LSpacing.pageHorizontal)
                    } else {
                        Section {
                            ForEach(activeHabits, id: \.persistentModelID) { habit in
                                HabitCard(habit: habit, onEdit: { editingHabit = habit })
                                    .padding(.horizontal, LSpacing.pageHorizontal)
                            }
                        } header: {
                            if !activeHabits.isEmpty {
                                HabitStreakSummaryCard(habits: activeHabits)
                                    .padding(.horizontal, LSpacing.pageHorizontal)
                                    .padding(.bottom, 4)
                                    .background(Color.clear)
                            }
                        }

                        // Archived
                        if !archivedHabits.isEmpty {
                            Text("ARCHIVED")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, LSpacing.pageHorizontal)
                                .padding(.top, 8)

                            ForEach(archivedHabits, id: \.persistentModelID) { habit in
                                HabitCard(habit: habit, onEdit: { editingHabit = habit })
                                    .padding(.horizontal, LSpacing.pageHorizontal)
                                    .opacity(0.6)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            // FAB
            FloatingActionButton { showNewHabit = true }
                .padding(.trailing, 24)
                .padding(.bottom, 90)
        }
        .sheet(isPresented: $showNewHabit) {
            NewHabitSheet()
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
        .sheet(
            isPresented: Binding(
                get: { editingHabit != nil },
                set: { if !$0 { editingHabit = nil } }
            )
        ) {
            if let h = editingHabit {
                EditHabitSheet(habit: h)
                    .presentationDetents([.large])
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Habit Summary Card

private struct HabitStreakSummaryCard: View {
    let habits: [Habit]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image("flamefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                    GradientTitle(text: "Habit Stats", size: 20)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(habits, id: \.persistentModelID) { habit in
                        HabitSummaryRow(habit: habit)

                        if habit.persistentModelID != habits.last?.persistentModelID {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
    }
}

private struct HabitSummaryRow: View {
    let habit: Habit

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var target: Int {
        max(1, habit.timesPerDay)
    }

    private var completedDayStarts: Set<Date> {
        Set(habit.logs
            .filter { $0.count >= target }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private func isCompletedDay(_ dayStart: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private var daysCompletedStreak: Int {
        let cal = Calendar.current
        var cursor = todayStart
        if !isCompletedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while isCompletedDay(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func weekStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
        ?? Calendar.current.startOfDay(for: date)
    }

    private func weekMet(weekStarting start: Date) -> Bool {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: start) else { return false }

        var days = Set<Date>()
        for log in habit.logs {
            let d = Calendar.current.startOfDay(for: log.dayStart)
            if interval.contains(d), log.count >= target {
                days.insert(d)
            }
        }

        return days.count >= max(1, habit.daysPerWeek)
    }

    private var weeksCompletedStreak: Int {
        let cal = Calendar.current
        var cursor = weekStart(for: Date())

        if !weekMet(weekStarting: cursor) {
            cursor = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while weekMet(weekStarting: cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return streak
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(habit.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                summaryPill(label: "DAYS", value: "\(daysCompletedStreak)")
                summaryPill(label: "WEEKS", value: "\(weeksCompletedStreak)")
            }
        }
    }

    @ViewBuilder
    private func summaryPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Habit Card

struct HabitCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LystariaReminder.nextRunAt)
    private var allReminders: [LystariaReminder]
    let habit: Habit
    let onEdit: () -> Void

    @State private var showDeleteConfirm = false

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todaysLog: HabitLog? {
        habit.logs.first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) })
    }

    private var todaysCount: Int {
        todaysLog?.count ?? 0
    }

    private var target: Int {
        max(1, habit.timesPerDay)
    }

    private var dotIndices: [Int] {
        Array(0..<target)
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(todaysCount) / Double(target), 1.0)
    }

    // MARK: - Streaks

    private var completedDayStarts: Set<Date> {
        // A day counts as completed only if it reaches the daily target.
        Set(habit.logs
            .filter { $0.count >= target }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private func isCompletedDay(_ dayStart: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private var daysCompletedStreak: Int {
        // If today isn't complete yet, streak counts up to yesterday.
        let cal = Calendar.current
        var cursor = todayStart
        if !isCompletedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while isCompletedDay(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func weekStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
        ?? Calendar.current.startOfDay(for: date)
    }

    private func weekMet(weekStarting start: Date) -> Bool {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: start) else { return false }

        // Count distinct completed days within that week.
        var days = Set<Date>()
        for log in habit.logs {
            let d = Calendar.current.startOfDay(for: log.dayStart)
            if interval.contains(d), log.count >= target {
                days.insert(d)
            }
        }

        return days.count >= max(1, habit.daysPerWeek)
    }

    private var weeksCompletedStreak: Int {
        // If the current week isn't met yet, count up to last week.
        let cal = Calendar.current
        var cursor = weekStart(for: Date())

        if !weekMet(weekStarting: cursor) {
            cursor = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while weekMet(weekStarting: cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return streak
    }
    private var linkedHabitReminders: [LystariaReminder] {
        allReminders.filter { r in
            r.linkedKind == .habit
            && r.linkedHabitId == habit.id
            && r.status != .deleted
        }
    }

    private var reminderTimePills: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let times: [String] = linkedHabitReminders.compactMap { r in
            let raw: String?

            // Prefer explicit timeOfDay; fall back to the first time in timesOfDay if present.
            if let t = r.schedule?.timeOfDay, !t.isEmpty {
                raw = t
            } else if let arr = r.schedule?.timesOfDay, let first = arr.first, !first.isEmpty {
                raw = first
            } else {
                raw = nil
            }

            guard let hhmm = raw,
                  let (hh, mm) = ReminderCompute.parseHHMM(hhmm) else { return nil }

            let date = ReminderCompute.merge(day: Date(), hour: hh, minute: mm)
            return formatter.string(from: date)
        }

        // Keep stable order and remove duplicates.
        var seen = Set<String>()
        return times.filter { seen.insert($0).inserted }
    }

    private var nextReminderRunAt: Date? {
        let now = Date()
        return linkedHabitReminders
            .map { $0.nextRunAt }
            .filter { $0 >= now }
            .sorted()
            .first
    }

    private var nextReminderLabel: String {
        guard let d = nextReminderRunAt else { return "—" }
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: d)
    }

    @ViewBuilder
    private func timePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(LColors.glassBorder, lineWidth: 1)
            )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {

                // Top content
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(habit.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)

                    if let details = habit.details,
                       !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }

                    // Badges
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            LBadge(text: "\(habit.daysPerWeek)/7", color: LColors.accent)
                            LBadge(text: "\(habit.timesPerDay)x/day", color: LColors.warning)

                            if habit.isArchived {
                                LBadge(text: "ARCHIVED", color: LColors.textSecondary)
                            }

                            if progress >= 1.0 {
                                LBadge(text: "DONE", color: LColors.success)
                            }
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Completion dots + scheduled times
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(dotIndices, id: \.self) { i in
                                Image(systemName: i < todaysCount ? "circle.fill" : "circle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(
                                        i < todaysCount
                                        ? (progress >= 1.0 ? LColors.success : LColors.accent)
                                        : LColors.textSecondary
                                    )
                                    .opacity(i < todaysCount ? 1.0 : 0.55)
                            }
                        }

                        if habit.reminderEnabled, !reminderTimePills.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(reminderTimePills, id: \.self) { t in
                                        timePill(t)
                                    }
                                }
                            }
                        }
                    }

                    // Next scheduled time
                    if habit.reminderEnabled {
                        Text("Next: \(nextReminderLabel)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Progress
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(todaysCount) / \(target) today")
                                .font(.system(size: 13))
                                .foregroundStyle(LColors.textSecondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)
                        }

                        GlassProgressBar(
                            progress: progress,
                            gradient: progress >= 1.0
                                ? LinearGradient(colors: [LColors.success], startPoint: .leading, endPoint: .trailing)
                                : LGradients.blue
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Bottom actions (left-aligned 2-row layout)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        LButton(title: "Log", icon: "plus", style: .gradient) {
                            quickLog()
                        }

                        LButton(title: "Edit", icon: "pencil", style: .secondary) {
                            onEdit()
                        }

                        LButton(title: "Clear", icon: "arrow.counterclockwise", style: .secondary) {
                            resetTodayHabitProgress()
                        }
                    }

                    HStack(spacing: 10) {
                        LButton(title: habit.isArchived ? "Unarchive" : "Archive", style: .secondary) {
                            habit.isArchived.toggle()
                            habit.updatedAt = Date()
                        }

                        LButton(title: "Delete", icon: "trash", style: .secondary) {
                            showDeleteConfirm = true
                        }

                        Spacer()
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .imageScale(.small)
                .padding(.top, 4)
            }
        }
        .alert("Delete habit?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteHabit()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this habit, its logs, and any linked reminders.")
        }
    }

    private func resetTodayHabitProgress() {
        let cal = Calendar.current

        // Grab today's logs first.
        let todaysLogs = habit.logs.filter { log in
            cal.isDate(log.dayStart, inSameDayAs: todayStart)
        }

        // 1) Delete from SwiftData.
        for log in todaysLogs {
            modelContext.delete(log)
        }

        // 2) ALSO remove them from the in-memory relationship immediately so
        //    the card recomputes progress / dots / streak effects right away.
        habit.logs.removeAll { log in
            cal.isDate(log.dayStart, inSameDayAs: todayStart)
        }

        habit.updatedAt = Date()
    }

    private func acknowledgeOneDueHabitReminder() {
        guard habit.reminderEnabled else { return }

        let now = Date()
        let grace: TimeInterval = 15 * 60 // allow early/late logging window

        // Find the soonest-due (or just-fired) linked reminder that hasn't been acknowledged for its current occurrence.
        let candidates = linkedHabitReminders
            .filter { r in
                r.status == .scheduled
                && r.nextRunAt <= now.addingTimeInterval(grace)
                && (r.acknowledgedAt == nil || r.acknowledgedAt! < r.nextRunAt)
            }
            .sorted { $0.nextRunAt < $1.nextRunAt }

        guard let r = candidates.first else { return }

        // We are about to advance `nextRunAt` to the next occurrence.
        // IMPORTANT: we do NOT want the reminder to stay visually “done” on the Reminders page
        // for the *next* occurrence, so we clear `acknowledgedAt` after advancing.
        r.updatedAt = now

        let scheduleKind: ReminderScheduleKind
        switch habit.reminderKind {
        case .weekly:
            scheduleKind = .weekly
        default:
            scheduleKind = .daily
        }

        let selectedDays = habit.reminderKind == .weekly ? habit.reminderDaysOfWeek : nil

        // Prefer the reminder's own stored time string.
        let timeStr: String? = {
            if let t = r.schedule?.timeOfDay, !t.isEmpty { return t }
            if let arr = r.schedule?.timesOfDay, let first = arr.first, !first.isEmpty { return first }
            return nil
        }()

        guard let hhmm = timeStr else {
            // If we can't determine a time, fall back to rescheduling with the existing nextRunAt.
            NotificationManager.shared.cancelReminder(r)
            NotificationManager.shared.scheduleReminder(r)
            return
        }

        let next = ReminderCompute.firstRun(
            kind: scheduleKind,
            startDay: now.addingTimeInterval(1),
            timesOfDay: [hhmm],
            daysOfWeek: selectedDays,
            intervalMinutes: nil
        )

        r.nextRunAt = next
        r.acknowledgedAt = nil

        // If there is ANOTHER linked habit reminder still coming later today,
        // clear today's progress so the card/progress bar resets for that next
        // same-day occurrence.
        let hasAnotherReminderLaterToday = linkedHabitReminders.contains { other in
            guard other.persistentModelID != r.persistentModelID else { return false }
            return other.status == .scheduled
                && Calendar.current.isDate(other.nextRunAt, inSameDayAs: now)
                && other.nextRunAt > now
        }

        if hasAnotherReminderLaterToday {
            resetTodayHabitProgress()
        }

        NotificationManager.shared.cancelReminder(r)
        NotificationManager.shared.scheduleReminder(r)
    }

    private func acknowledgeDueHabitRemindersIfAny() {
        // Call once per log tap; if the habit has multiple daily times, each tap can advance one linked reminder.
        acknowledgeOneDueHabitReminder()
    }

    private func quickLog() {
        // Cap logs at timesPerDay so progress stays meaningful.
        let cap = max(1, habit.timesPerDay)

        if let existing = todaysLog {
            if existing.count < cap {
                existing.count += 1
                habit.updatedAt = Date()

                // If this log corresponds to a linked reminder time, acknowledge/advance it.
                acknowledgeDueHabitRemindersIfAny()
            }
            return
        }

        let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
        modelContext.insert(newLog)
        habit.updatedAt = Date()

        // If this first log corresponds to a linked reminder time, acknowledge/advance it.
        acknowledgeDueHabitRemindersIfAny()
    }

    private func deleteHabit() {
        // Cancel and delete any linked reminders for this habit
        for r in linkedHabitReminders {
            NotificationManager.shared.cancelReminder(r)
            modelContext.delete(r)
        }

        // Delete logs explicitly (safe even if relationship is already cascading)
        for log in habit.logs {
            modelContext.delete(log)
        }

        // Finally delete the habit itself
        modelContext.delete(habit)
    }
}

// MARK: - New Habit Sheet

struct NewHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var details = ""
    @State private var daysPerWeek = 7
    @State private var timesPerDay = 1
    
    // Reminder settings
    @State private var reminderEnabled = false
    @State private var reminderKind: HabitReminderKind = .daily
    @State private var reminderTimes: [Date] = [Date()]
    @State private var weeklyDays: Set<Int> = []
    @State private var reminderStartDate: Date = Date()
    
    private let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }
        if reminderEnabled, reminderKind == .weekly {
            return weeklyDays.count == daysPerWeek
        }
        return true
    }
    
    private func timeStr24(from date: Date) -> String {
        let (hh, mm) = ReminderCompute.hourMinute(from: date)
        return String(format: "%02d:%02d", hh, mm)
    }
    
    var body: some View {
        ZStack {
            LystariaBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        GradientTitle(text: "New Habit", size: 26)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        GlassTextField(placeholder: "Habit title", text: $title)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        GlassTextField(placeholder: "Optional description", text: $details)
                    }
                    
                    GlassCard(padding: 16) {
                        VStack(spacing: 14) {
                            Stepper("Days per week: \(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                                .foregroundStyle(LColors.textPrimary)
                                .disabled(reminderEnabled && reminderKind == .daily)
                                .opacity((reminderEnabled && reminderKind == .daily) ? 0.6 : 1.0)
                            
                            Stepper("Times per day: \(timesPerDay)", value: $timesPerDay, in: 1...20)
                                .foregroundStyle(LColors.textPrimary)
                                .onChange(of: timesPerDay) { _, newValue in
                                    // Keep time pickers in sync with the selected times/day.
                                    // Rule: if they pick N times/day, show N time pickers immediately.
                                    if reminderTimes.isEmpty { reminderTimes = [Date()] }

                                    if reminderTimes.count < newValue {
                                        while reminderTimes.count < newValue {
                                            reminderTimes.append(reminderTimes.last ?? Date())
                                        }
                                    } else if reminderTimes.count > newValue {
                                        reminderTimes = Array(reminderTimes.prefix(newValue))
                                    }

                                    // If reminders are enabled and Daily is selected, lock to 7 days.
                                    if reminderEnabled && reminderKind == .daily {
                                        daysPerWeek = 7
                                        weeklyDays = []
                                    }
                                }
                        }
                    }
                    
                    // Reminder
                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {

                            // Header row
                            HStack {
                                Text("REMINDER")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                Spacer()

                                Toggle("", isOn: $reminderEnabled)
                                    .labelsHidden()
                                    .tint(LColors.accent)
                                    .onChange(of: reminderEnabled) { _, newValue in
                                        guard newValue else { return }

                                        // Daily means every day.
                                        if reminderKind == .daily {
                                            daysPerWeek = 7
                                            weeklyDays = []
                                        }

                                        // Ensure we have exactly one time per `timesPerDay`.
                                        if reminderTimes.isEmpty { reminderTimes = [Date()] }
                                        if reminderTimes.count < timesPerDay {
                                            while reminderTimes.count < timesPerDay {
                                                reminderTimes.append(reminderTimes.last ?? Date())
                                            }
                                        } else if reminderTimes.count > timesPerDay {
                                            reminderTimes = Array(reminderTimes.prefix(timesPerDay))
                                        }
                                    }
                            }

                            if reminderEnabled {

                                // Start date (controls what day we consider the first occurrence)
                                LystariaControlRow(label: "Start") {
                                    DatePicker(
                                        "",
                                        selection: $reminderStartDate,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                                }

                                // Kind (Daily / Weekly)
                                HStack(spacing: 8) {
                                    ForEach([HabitReminderKind.daily, HabitReminderKind.weekly], id: \.self) { k in
                                        let on = reminderKind == k
                                        Button {
                                            reminderKind = k

                                            if k == .daily {
                                                daysPerWeek = 7
                                                weeklyDays = []
                                            }
                                        } label: {
                                            Text(k.label.uppercased())
                                                .font(.system(size: 12, weight: .semibold))
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

                                // Times (one per `timesPerDay`)
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(reminderTimes.indices), id: \.self) { idx in
                                        LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                                            DatePicker(
                                                "",
                                                selection: Binding(
                                                    get: { reminderTimes[idx] },
                                                    set: { reminderTimes[idx] = $0 }
                                                ),
                                                displayedComponents: .hourAndMinute
                                            )
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                            .tint(LColors.accent)
                                        }
                                    }
                                }

                                if reminderKind == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        let picked = weeklyDays.count

                                        Text("Pick exactly \(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s") (\(picked)/\(daysPerWeek))")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(picked == daysPerWeek ? LColors.textPrimary : LColors.textSecondary)

                                        HStack(spacing: 6) {
                                            ForEach(0..<7, id: \.self) { d in
                                                let on = weeklyDays.contains(d)
                                                let atCap = (!on && weeklyDays.count >= daysPerWeek)

                                                Button {
                                                    if on {
                                                        weeklyDays.remove(d)
                                                    } else {
                                                        guard weeklyDays.count < daysPerWeek else { return }
                                                        weeklyDays.insert(d)
                                                    }
                                                } label: {
                                                    Text(weekdays[d])
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .frame(width: 36, height: 36)
                                                        .background(on ? LColors.accent : Color.white.opacity(0.08))
                                                        .foregroundStyle(on ? .white : LColors.textPrimary)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().stroke(on ? .clear : LColors.glassBorder, lineWidth: 1))
                                                        .opacity(atCap ? 0.5 : 1.0)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(atCap)
                                            }
                                        }
                                    }
                                }

                            } else {
                                Text("Toggle on to get habit nudges.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }
                        
                        Button {
                            // If Daily + reminders enabled, force 7 days/week.
                            if reminderEnabled && reminderKind == .daily {
                                daysPerWeek = 7
                                weeklyDays = []
                            }
                            
                            let habit = Habit(
                                title: titleTrimmed,
                                details: details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : details,
                                daysPerWeek: daysPerWeek,
                                timesPerDay: timesPerDay,
                                reminderEnabled: reminderEnabled,
                                reminderKind: reminderEnabled ? reminderKind : .none,
                                reminderTimeOfDay: reminderEnabled ? timeStr24(from: reminderTimes.first ?? Date()) : nil,
                                reminderDaysOfWeek: reminderEnabled && reminderKind == .weekly ? Array(weeklyDays).sorted() : [],
                                reminderStartDate: reminderEnabled ? Calendar.current.startOfDay(for: reminderStartDate) : nil
                            )
                            modelContext.insert(habit)
                            
                            // Create linked reminders (one per time) that log the habit when completed.
                            if reminderEnabled {
                                let scheduleKind: ReminderScheduleKind = (reminderKind == .weekly) ? .weekly : .daily
                                let selectedDays = Array(weeklyDays).sorted()
                                
                                for (idx, t) in reminderTimes.enumerated() {
                                    let (hh, mm) = ReminderCompute.hourMinute(from: t)
                                    let timeStr = String(format: "%02d:%02d", hh, mm)
                                    
                                    let schedule = ReminderSchedule(
                                        kind: scheduleKind,
                                        timeOfDay: timeStr,
                                        timesOfDay: [timeStr],
                                        interval: nil,
                                        daysOfWeek: scheduleKind == .weekly ? selectedDays : nil,
                                        dayOfMonth: nil,
                                        anchorMonth: nil,
                                        anchorDay: nil,
                                        intervalMinutes: nil
                                    )
                                    
                                    let firstRun = ReminderCompute.firstRun(
                                        kind: scheduleKind,
                                        startDay: Calendar.current.startOfDay(for: reminderStartDate),
                                        timesOfDay: [timeStr],
                                        daysOfWeek: scheduleKind == .weekly ? selectedDays : nil,
                                        intervalMinutes: nil
                                    )
                                    
                                    let suffix = reminderTimes.count > 1 ? " (\(idx + 1)/\(reminderTimes.count))" : ""
                                    
                                    let r = LystariaReminder(
                                        title: habit.title + suffix,
                                        details: habit.details,
                                        nextRunAt: firstRun,
                                        schedule: schedule,
                                        timezone: TimeZone.current.identifier,
                                        serverId: nil,
                                        linkedKind: .habit,
                                        linkedHabitId: habit.id
                                    )
                                    modelContext.insert(r)
                                    NotificationManager.shared.scheduleReminder(r)
                                }
                            }
                            
                            dismiss()
                        } label: {
                            Text("Create Habit")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(!canSave ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                                .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                                .shadow(color: !canSave ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

// MARK: - Edit Habit Sheet

struct EditHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var habit: Habit

    @State private var title = ""
    @State private var details = ""
    @State private var daysPerWeek = 7
    @State private var timesPerDay = 1

    // Reminder settings
    @State private var reminderEnabled = false
    @State private var reminderKind: HabitReminderKind = .daily
    @State private var reminderTimes: [Date] = [Date()]
    @State private var weeklyDays: Set<Int> = []
    @State private var reminderStartDate: Date = Date()

    private let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    @Query(sort: \LystariaReminder.nextRunAt) private var allReminders: [LystariaReminder]

    init(habit: Habit) {
        self._habit = Bindable(wrappedValue: habit)
    }

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        if titleTrimmed.isEmpty { return false }

        if reminderEnabled {
            if reminderTimes.count != timesPerDay { return false }
            if reminderKind == .weekly {
                return weeklyDays.count == daysPerWeek
            }
        }

        return true
    }

    private func timeStr24(from date: Date) -> String {
        let (hh, mm) = ReminderCompute.hourMinute(from: date)
        return String(format: "%02d:%02d", hh, mm)
    }

    private var linkedReminders: [LystariaReminder] {
        allReminders.filter { r in
            r.linkedKind == .habit
            && r.linkedHabitId == habit.id
            && r.status != .deleted
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        GradientTitle(text: "Edit Habit", size: 26)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        GlassTextField(placeholder: "Habit title", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)
                        GlassTextField(placeholder: "Optional description", text: $details)
                    }

                    GlassCard(padding: 16) {
                        VStack(spacing: 14) {
                            Stepper("Days per week: \(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                                .foregroundStyle(LColors.textPrimary)
                                .disabled(reminderEnabled && reminderKind == .daily)
                                .opacity((reminderEnabled && reminderKind == .daily) ? 0.6 : 1.0)

                            Stepper("Times per day: \(timesPerDay)", value: $timesPerDay, in: 1...20)
                                .foregroundStyle(LColors.textPrimary)
                                .onChange(of: timesPerDay) { _, newValue in
                                    guard reminderEnabled else { return }
                                    if reminderTimes.isEmpty { reminderTimes = [Date()] }
                                    if reminderTimes.count < newValue {
                                        while reminderTimes.count < newValue {
                                            reminderTimes.append(reminderTimes.last ?? Date())
                                        }
                                    } else if reminderTimes.count > newValue {
                                        reminderTimes = Array(reminderTimes.prefix(newValue))
                                    }
                                }
                        }
                    }

                    // Reminder (matches NewHabitSheet)
                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {

                            // Header row
                            HStack {
                                Text("REMINDER")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                Spacer()

                                Toggle("", isOn: $reminderEnabled)
                                    .labelsHidden()
                                    .tint(LColors.accent)
                                    .onChange(of: reminderEnabled) { _, newValue in
                                        guard newValue else { return }

                                        if reminderKind == .daily {
                                            daysPerWeek = 7
                                            weeklyDays = []
                                        }

                                        if reminderTimes.isEmpty { reminderTimes = [Date()] }
                                        if reminderTimes.count < timesPerDay {
                                            while reminderTimes.count < timesPerDay {
                                                reminderTimes.append(reminderTimes.last ?? Date())
                                            }
                                        } else if reminderTimes.count > timesPerDay {
                                            reminderTimes = Array(reminderTimes.prefix(timesPerDay))
                                        }
                                    }
                            }

                            if reminderEnabled {

                                // Start date (controls what day we consider the first occurrence)
                                LystariaControlRow(label: "Start") {
                                    DatePicker(
                                        "",
                                        selection: $reminderStartDate,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                                }

                                // Kind (Daily / Weekly)
                                HStack(spacing: 8) {
                                    ForEach([HabitReminderKind.daily, HabitReminderKind.weekly], id: \.self) { k in
                                        let on = reminderKind == k
                                        Button {
                                            reminderKind = k

                                            if k == .daily {
                                                daysPerWeek = 7
                                                weeklyDays = []
                                            }
                                        } label: {
                                            Text(k.label.uppercased())
                                                .font(.system(size: 12, weight: .semibold))
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

                                // Times (one per `timesPerDay`)
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(reminderTimes.indices), id: \.self) { idx in
                                        LystariaControlRow(label: idx == 0 ? "Time" : "Time \(idx + 1)") {
                                            DatePicker(
                                                "",
                                                selection: Binding(
                                                    get: { reminderTimes[idx] },
                                                    set: { reminderTimes[idx] = $0 }
                                                ),
                                                displayedComponents: .hourAndMinute
                                            )
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                            .tint(LColors.accent)
                                        }
                                    }
                                }

                                if reminderKind == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        let picked = weeklyDays.count

                                        Text("Pick exactly \(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s") (\(picked)/\(daysPerWeek))")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(picked == daysPerWeek ? LColors.textPrimary : LColors.textSecondary)

                                        HStack(spacing: 6) {
                                            ForEach(0..<7, id: \.self) { d in
                                                let on = weeklyDays.contains(d)
                                                let atCap = (!on && weeklyDays.count >= daysPerWeek)

                                                Button {
                                                    if on {
                                                        weeklyDays.remove(d)
                                                    } else {
                                                        guard weeklyDays.count < daysPerWeek else { return }
                                                        weeklyDays.insert(d)
                                                    }
                                                } label: {
                                                    Text(weekdays[d])
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .frame(width: 36, height: 36)
                                                        .background(on ? LColors.accent : Color.white.opacity(0.08))
                                                        .foregroundStyle(on ? .white : LColors.textPrimary)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().stroke(on ? .clear : LColors.glassBorder, lineWidth: 1))
                                                        .opacity(atCap ? 0.5 : 1.0)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(atCap)
                                            }
                                        }
                                    }
                                }

                            } else {
                                Text("Toggle on to get habit nudges.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }

                    Button {
                        applyChanges()
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(!canSave ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                            .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                            .shadow(color: !canSave ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear { loadFromModel() }
    }

    private func loadFromModel() {
        title = habit.title
        details = habit.details ?? ""
        daysPerWeek = habit.daysPerWeek
        timesPerDay = habit.timesPerDay

        reminderEnabled = habit.reminderEnabled
        reminderKind = habit.reminderKind
        weeklyDays = Set(habit.reminderDaysOfWeek)
        reminderStartDate = habit.reminderStartDate ?? Date()

        // Seed time pickers from the stored first time.
        if reminderEnabled, let hhmm = habit.reminderTimeOfDay, let (hh, mm) = ReminderCompute.parseHHMM(hhmm) {
            let seeded = ReminderCompute.merge(day: Date(), hour: hh, minute: mm)
            reminderTimes = Array(repeating: seeded, count: max(1, timesPerDay))
        } else {
            reminderTimes = Array(repeating: Date(), count: max(1, timesPerDay))
        }

        // Daily lock
        if reminderEnabled, reminderKind == .daily {
            daysPerWeek = 7
            weeklyDays = []
        }

        // Ensure the times array matches timesPerDay.
        if reminderTimes.count < timesPerDay {
            while reminderTimes.count < timesPerDay { reminderTimes.append(reminderTimes.last ?? Date()) }
        } else if reminderTimes.count > timesPerDay {
            reminderTimes = Array(reminderTimes.prefix(timesPerDay))
        }
    }

    private func applyChanges() {
        // Normalize daily lock
        if reminderEnabled && reminderKind == .daily {
            daysPerWeek = 7
            weeklyDays = []
        }

        habit.title = titleTrimmed
        let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
        habit.daysPerWeek = daysPerWeek
        habit.timesPerDay = timesPerDay

        habit.reminderEnabled = reminderEnabled
        habit.reminderKind = reminderEnabled ? reminderKind : .none
        habit.reminderTimeOfDay = reminderEnabled ? timeStr24(from: reminderTimes.first ?? Date()) : nil
        habit.reminderDaysOfWeek = reminderEnabled && reminderKind == .weekly ? Array(weeklyDays).sorted() : []
        habit.reminderStartDate = reminderEnabled ? Calendar.current.startOfDay(for: reminderStartDate) : nil
        habit.updatedAt = Date()

        // Remove existing linked reminders.
        for r in linkedReminders {
            r.status = .deleted
            r.updatedAt = Date()
            NotificationManager.shared.cancelReminder(r)
        }

        // Recreate linked reminders to match current settings.
        if reminderEnabled {
            let scheduleKind: ReminderScheduleKind = (reminderKind == .weekly) ? .weekly : .daily
            let selectedDays = Array(weeklyDays).sorted()

            for (idx, t) in reminderTimes.enumerated() {
                let (hh, mm) = ReminderCompute.hourMinute(from: t)
                let timeStr = String(format: "%02d:%02d", hh, mm)

                let schedule = ReminderSchedule(
                    kind: scheduleKind,
                    timeOfDay: timeStr,
                    timesOfDay: [timeStr],
                    interval: nil,
                    daysOfWeek: scheduleKind == .weekly ? selectedDays : nil,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: nil
                )

                let firstRun = ReminderCompute.firstRun(
                    kind: scheduleKind,
                    startDay: Calendar.current.startOfDay(for: reminderStartDate),
                    timesOfDay: [timeStr],
                    daysOfWeek: scheduleKind == .weekly ? selectedDays : nil,
                    intervalMinutes: nil
                )

                let suffix = reminderTimes.count > 1 ? " (\(idx + 1)/\(reminderTimes.count))" : ""

                let rr = LystariaReminder(
                    title: habit.title + suffix,
                    details: habit.details,
                    nextRunAt: firstRun,
                    schedule: schedule,
                    timezone: TimeZone.current.identifier,
                    serverId: nil,
                    linkedKind: .habit,
                    linkedHabitId: habit.id
                )

                modelContext.insert(rr)
                NotificationManager.shared.scheduleReminder(rr)
            }
        }

        dismiss()
    }
}
