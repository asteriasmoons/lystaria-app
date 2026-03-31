// HabitsView.swift
// Lystaria

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    @State private var showNewHabit = false
    @State private var editingHabit: Habit? = nil
    @State private var historyHabit: Habit? = nil
    @State private var visibleHabitCount: Int = 4

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
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.top, 6)

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
                        let allowedIds = Set(
                            habits
                                .sorted { $0.createdAt < $1.createdAt }
                                .prefix(3)
                                .map { $0.persistentModelID }
                        )

                        Section {
                            let visibleHabits = Array(activeHabits.prefix(visibleHabitCount))
                            
                            ForEach(visibleHabits, id: \.persistentModelID) { habit in
                                HabitCard(
                                    habit: habit,
                                    onEdit: { editingHabit = habit },
                                    onShowHistory: { historyHabit = habit }
                                )
                                .padding(.horizontal, LSpacing.pageHorizontal)
                                .premiumLocked(!limits.hasPremiumAccess && !allowedIds.contains(habit.persistentModelID))
                            }

                            if activeHabits.count > visibleHabits.count {
                                HStack {
                                    Spacer()
                                    LoadMoreButton {
                                        visibleHabitCount += 4
                                    }
                                    Spacer()
                                }
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

                            let visibleArchived = Array(archivedHabits.prefix(visibleHabitCount))

                            ForEach(visibleArchived, id: \.persistentModelID) { habit in
                                HabitCard(
                                    habit: habit,
                                    onEdit: { editingHabit = habit },
                                    onShowHistory: { historyHabit = habit }
                                )
                                .padding(.horizontal, LSpacing.pageHorizontal)
                                .opacity(0.6)
                                .premiumLocked(!limits.hasPremiumAccess && !allowedIds.contains(habit.persistentModelID))
                            }

                            if archivedHabits.count > visibleArchived.count {
                                HStack {
                                    Spacer()
                                    LoadMoreButton {
                                        visibleHabitCount += 4
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, LSpacing.pageHorizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            // FAB
            FloatingActionButton {
                let decision = limits.canCreate(.habitsTotal, currentCount: habits.count)
                guard decision.allowed else { return }
                showNewHabit = true
            }
                .padding(.trailing, 24)
                .padding(.bottom, 90)
        }
        .overlay {
            if showNewHabit {
                NewHabitSheet(onClose: {
                    showNewHabit = false
                })
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(50)
            }
        }
        .overlay {
            if let h = editingHabit {
                EditHabitSheet(
                    habit: h,
                    onClose: {
                        editingHabit = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(60)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNewHabit)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: editingHabit != nil)
        .overlay {
            if let habit = historyHabit {
                HabitHistoryPopup(
                    habit: habit,
                    onClose: {
                        historyHabit = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(70)
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

    private var resetMoment: Date? {
        habit.statsResetAt
    }

    private var target: Int {
        max(1, habit.timesPerDay)
    }

    private func includeLogInCurrentStats(_ log: HabitLog) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let logDay = cal.startOfDay(for: log.dayStart)

        if logDay > resetDay { return true }
        if logDay < resetDay { return false }
        return log.createdAt >= resetMoment
    }

    private func includeSkipInCurrentStats(_ skip: HabitSkip) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let skipDay = cal.startOfDay(for: skip.dayStart)

        if skipDay > resetDay { return true }
        if skipDay < resetDay { return false }
        return skip.createdAt >= resetMoment
    }

    private var completedDayStarts: Set<Date> {
        Set((habit.logs ?? [])
            .filter { log in
                guard log.count >= target else { return false }
                return includeLogInCurrentStats(log)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private var skippedDayStarts: Set<Date> {
        Set((habit.skips ?? [])
            .filter { skip in
                includeSkipInCurrentStats(skip)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private func isCompletedDay(_ dayStart: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private func isSkippedDay(_ dayStart: Date) -> Bool {
        skippedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private var daysCompletedStreak: Int {
        let cal = Calendar.current
        var cursor = todayStart

        if !isCompletedDay(cursor) && !isSkippedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while true {
            if isCompletedDay(cursor) {
                streak += 1
            } else if isSkippedDay(cursor) {
                // skipped days do not increment the streak, but they also do not break it
            } else {
                break
            }

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

        var completedDays = Set<Date>()
        for log in (habit.logs ?? []) {
            let d = Calendar.current.startOfDay(for: log.dayStart)
            guard includeLogInCurrentStats(log) else { continue }
            if interval.contains(d), log.count >= target {
                completedDays.insert(d)
            }
        }

        var skippedDays = Set<Date>()
        for skip in (habit.skips ?? []) {
            let d = Calendar.current.startOfDay(for: skip.dayStart)
            guard includeSkipInCurrentStats(skip) else { continue }
            if interval.contains(d) {
                skippedDays.insert(d)
            }
        }

        return completedDays.union(skippedDays).count >= max(1, habit.daysPerWeek)
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
    let onShowHistory: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showResetStatsConfirm = false

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var resetMoment: Date? {
        habit.statsResetAt
    }

    private var todaysLog: HabitLog? {
        (habit.logs ?? []).first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) })
    }

    private var todaysSkip: HabitSkip? {
        (habit.skips ?? []).first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) })
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

    private func includeLogInCurrentStats(_ log: HabitLog) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let logDay = cal.startOfDay(for: log.dayStart)

        if logDay > resetDay { return true }
        if logDay < resetDay { return false }
        return log.createdAt >= resetMoment
    }

    private func includeSkipInCurrentStats(_ skip: HabitSkip) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let skipDay = cal.startOfDay(for: skip.dayStart)

        if skipDay > resetDay { return true }
        if skipDay < resetDay { return false }
        return skip.createdAt >= resetMoment
    }

    // MARK: - Streaks

    private var completedDayStarts: Set<Date> {
        Set((habit.logs ?? [])
            .filter { log in
                guard log.count >= target else { return false }
                return includeLogInCurrentStats(log)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private var skippedDayStarts: Set<Date> {
        Set((habit.skips ?? [])
            .filter { skip in
                includeSkipInCurrentStats(skip)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private func isCompletedDay(_ dayStart: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private func isSkippedDay(_ dayStart: Date) -> Bool {
        skippedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private var daysCompletedStreak: Int {
        let cal = Calendar.current
        var cursor = todayStart
        if !isCompletedDay(cursor) && !isSkippedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while true {
            if isCompletedDay(cursor) {
                streak += 1
            } else if isSkippedDay(cursor) {
                // skipped days do not increment the streak, but they also do not break it
            } else {
                break
            }

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

        var completedDays = Set<Date>()
        for log in (habit.logs ?? []) {
            let d = Calendar.current.startOfDay(for: log.dayStart)
            guard includeLogInCurrentStats(log) else { continue }
            if interval.contains(d), log.count >= target {
                completedDays.insert(d)
            }
        }

        var skippedDays = Set<Date>()
        for skip in (habit.skips ?? []) {
            let d = Calendar.current.startOfDay(for: skip.dayStart)
            guard includeSkipInCurrentStats(skip) else { continue }
            if interval.contains(d) {
                skippedDays.insert(d)
            }
        }

        return completedDays.union(skippedDays).count >= max(1, habit.daysPerWeek)
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

    private func resolvedNextRunAt(for reminder: LystariaReminder, now: Date) -> Date? {
        if reminder.nextRunAt >= now {
            return reminder.nextRunAt
        }

        guard reminder.status != .deleted else { return nil }
        return ReminderCompute.nextRun(after: now.addingTimeInterval(1), reminder: reminder)
    }

    private var nextReminderRunAt: Date? {
        let now = Date()
        return linkedHabitReminders
            .compactMap { resolvedNextRunAt(for: $0, now: now) }
            .filter { $0 >= now }
            .sorted()
            .first
    }

    private var nextReminderLabel: String {
        guard let d = nextReminderRunAt else { return "—" }

        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .short

        return df.string(from: d)
    }

    private var historyLogs: [HabitLog] {
        (habit.logs ?? []).sorted { a, b in
            Calendar.current.startOfDay(for: a.dayStart) > Calendar.current.startOfDay(for: b.dayStart)
        }
    }

    private var resetDateLabel: String? {
        guard let reset = habit.statsResetAt else { return nil }
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: reset)
    }

    private func historyDateLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
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
                            if todaysSkip != nil {
                                LBadge(text: "SKIPPED", color: LColors.textSecondary)
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
                                        ? AnyShapeStyle(LGradients.blue)
                                        : AnyShapeStyle(LColors.textSecondary)
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
                            gradient: LGradients.blue
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

                        LButton(title: todaysSkip == nil ? "Skip" : "Skipped", icon: "forward.fill", style: .secondary) {
                            toggleSkipToday()
                        }
                    }

                    HStack(spacing: 10) {
                        LButton(title: "Reset", icon: "arrow.clockwise", style: .secondary) {
                            showResetStatsConfirm = true
                        }

                        LButton(title: "History", icon: "clock.arrow.circlepath", style: .secondary) {
                            onShowHistory()
                        }

                        GradientCapsuleButton(title: "Delete", icon: "trashfill") {
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
        .alert("Reset stats?", isPresented: $showResetStatsConfirm) {
            Button("Reset", role: .destructive) {
                resetHabitStats()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will restart streaks and stats for this habit from today while keeping your past log history.")
        }
        
    }

    private func resetTodayHabitProgress() {
        let cal = Calendar.current

        // Grab today's logs first.
        let todaysLogs = (habit.logs ?? []).filter { log in
            cal.isDate(log.dayStart, inSameDayAs: todayStart)
        }

        // 1) Delete from SwiftData.
        for log in todaysLogs {
            modelContext.delete(log)
        }

        // 2) ALSO remove them from the in-memory relationship immediately so
        //    the card recomputes progress / dots / streak effects right away.
        habit.logs = (habit.logs ?? []).filter { log in
            !cal.isDate(log.dayStart, inSameDayAs: todayStart)
        }

        habit.updatedAt = Date()
    }

    private func resetHabitStats() {
        habit.statsResetAt = todayStart
        habit.updatedAt = Date()
    }

    private func toggleSkipToday() {
        if let existingSkip = todaysSkip {
            // Un-skip: remove the skip record; do NOT re-advance the reminder
            // since it was already advanced when the skip was first applied.
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
            habit.updatedAt = Date()
            return
        }

        // Cannot skip a day that already has progress logged.
        if let existingLog = todaysLog, existingLog.count > 0 {
            return
        }

        let skip = HabitSkip(habit: habit, dayStart: todayStart)
        modelContext.insert(skip)
        if habit.skips == nil {
            habit.skips = [skip]
        } else {
            habit.skips?.append(skip)
        }
        habit.updatedAt = Date()

        // Advance any due linked reminder to its next occurrence,
        // exactly the same way a completed log does.
        acknowledgeOneDueHabitReminder()
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
            intervalMinutes: nil,
            recurrenceInterval: 1,
            dayOfMonth: nil,
            anchorMonth: nil,
            anchorDay: nil
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

        if let existingSkip = todaysSkip {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
        }

        if let existing = todaysLog {
            if existing.count < cap {
                existing.count += 1
                habit.updatedAt = Date()

                _ = try? SelfCarePointsManager.awardHabitLog(
                    in: modelContext,
                    habitLogId: existing.id.uuidString,
                    title: habit.title,
                    loggedAt: Date()
                )

                // If this log corresponds to a linked reminder time, acknowledge/advance it.
                acknowledgeDueHabitRemindersIfAny()
            }
            return
        }

        let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
        modelContext.insert(newLog)
        habit.updatedAt = Date()

        _ = try? SelfCarePointsManager.awardHabitLog(
            in: modelContext,
            habitLogId: newLog.id.uuidString,
            title: habit.title,
            loggedAt: Date()
        )

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
        for log in (habit.logs ?? []) {
            modelContext.delete(log)
        }

        // Finally delete the habit itself
        modelContext.delete(habit)
    }
}

private struct HabitHistoryPopup: View {
    let habit: Habit
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var pendingDeleteLog: HabitLog? = nil
    @State private var pendingDeleteSkip: HabitSkip? = nil
    @State private var showDeleteDialog = false

    @State private var visibleHistoryCount: Int = 4

    private enum HistoryEntry: Identifiable {
        case log(HabitLog)
        case skip(HabitSkip)

        var id: PersistentIdentifier {
            switch self {
            case .log(let log):
                return log.persistentModelID
            case .skip(let skip):
                return skip.persistentModelID
            }
        }

        var date: Date {
            switch self {
            case .log(let log):
                return log.dayStart
            case .skip(let skip):
                return skip.dayStart
            }
        }

        var count: Int? {
            switch self {
            case .log(let log):
                return log.count
            case .skip:
                return nil
            }
        }

        var skipped: Bool {
            switch self {
            case .log:
                return false
            case .skip:
                return true
            }
        }
    }

    private var historyLogs: [HabitLog] {
        (habit.logs ?? []).sorted { a, b in
            Calendar.current.startOfDay(for: a.dayStart) > Calendar.current.startOfDay(for: b.dayStart)
        }
    }

    private var historySkips: [HabitSkip] {
        (habit.skips ?? []).sorted { a, b in
            Calendar.current.startOfDay(for: a.dayStart) > Calendar.current.startOfDay(for: b.dayStart)
        }
    }

    private var historyEntries: [HistoryEntry] {
        let entries: [HistoryEntry] =
            historyLogs.map { .log($0) }
            + historySkips.map { .skip($0) }

        return entries.sorted {
            Calendar.current.startOfDay(for: $0.date) > Calendar.current.startOfDay(for: $1.date)
        }
    }

    private var target: Int {
        max(1, habit.timesPerDay)
    }

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var resetMoment: Date? {
        habit.statsResetAt
    }

    private func includeLogInCurrentStats(_ log: HabitLog) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let logDay = cal.startOfDay(for: log.dayStart)

        if logDay > resetDay { return true }
        if logDay < resetDay { return false }
        return log.createdAt >= resetMoment
    }

    private func includeSkipInCurrentStats(_ skip: HabitSkip) -> Bool {
        guard let resetMoment else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: resetMoment)
        let skipDay = cal.startOfDay(for: skip.dayStart)

        if skipDay > resetDay { return true }
        if skipDay < resetDay { return false }
        return skip.createdAt >= resetMoment
    }

    private var completedDayStarts: Set<Date> {
        Set((habit.logs ?? [])
            .filter { log in
                guard log.count >= target else { return false }
                return includeLogInCurrentStats(log)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private var skippedDayStarts: Set<Date> {
        Set((habit.skips ?? [])
            .filter { skip in
                includeSkipInCurrentStats(skip)
            }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private func isCompletedDay(_ dayStart: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private func isSkippedDay(_ dayStart: Date) -> Bool {
        skippedDayStarts.contains(Calendar.current.startOfDay(for: dayStart))
    }

    private var currentDailyStreak: Int {
        let cal = Calendar.current
        var cursor = todayStart

        if !isCompletedDay(cursor) && !isSkippedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while true {
            if isCompletedDay(cursor) {
                streak += 1
            } else if isSkippedDay(cursor) {
                // skipped days protect the streak without incrementing it
            } else {
                break
            }

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

        var completedDays = Set<Date>()
        for log in (habit.logs ?? []) {
            let d = Calendar.current.startOfDay(for: log.dayStart)
            guard includeLogInCurrentStats(log) else { continue }
            if interval.contains(d), log.count >= target {
                completedDays.insert(d)
            }
        }

        var skippedDays = Set<Date>()
        for skip in (habit.skips ?? []) {
            let d = Calendar.current.startOfDay(for: skip.dayStart)
            guard includeSkipInCurrentStats(skip) else { continue }
            if interval.contains(d) {
                skippedDays.insert(d)
            }
        }

        return completedDays.union(skippedDays).count >= max(1, habit.daysPerWeek)
    }

    private var currentWeeklyStreak: Int {
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

    private var resetDateLabel: String? {
        guard let reset = habit.statsResetAt else { return nil }
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: reset)
    }

    private func historyDateLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                onClose()
            },
            width: 560,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Habit History", size: 24)
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(habit.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)

                    if let resetDateLabel {
                        GlassCard(padding: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT STATS RESET")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                Text(resetDateLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                        }
                    }

                    GlassCard(padding: 12) {
                        HStack(spacing: 10) {
                            GlassCard(padding: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DAILY STREAK")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.5)
                                    Text("\(currentDailyStreak) day\(currentDailyStreak == 1 ? "" : "s")")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                            }

                            GlassCard(padding: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("WEEKLY STREAK")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.5)
                                    Text("\(currentWeeklyStreak) week\(currentWeeklyStreak == 1 ? "" : "s")")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                            }
                        }
                    }

                    if historyEntries.isEmpty {
                        GlassCard {
                            Text("No habit history yet.")
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        }
                    } else {
                        let visibleEntries = Array(historyEntries.prefix(visibleHistoryCount))

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { _, entry in
                                GlassCard(padding: 12) {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(historyDateLabel(for: entry.date))
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(LColors.textPrimary)

                                            if entry.skipped {
                                                Text("Skipped this day")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(LColors.textSecondary)
                                            } else {
                                                let count = entry.count ?? 0
                                                Text("\(count) of \(target) times completed that day")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(LColors.textSecondary)
                                            }
                                        }

                                        Spacer()

                                        Text(
                                            entry.skipped
                                            ? "SKIPPED"
                                            : ((entry.count ?? 0) >= target ? "DONE" : ((entry.count ?? 0) > 0 ? "PARTIAL" : "NONE"))
                                        )
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            entry.skipped
                                            ? Color.white.opacity(0.10)
                                            : ((entry.count ?? 0) >= target
                                               ? LColors.success
                                               : Color.white.opacity(0.10))
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                    }
                                }
                                .onLongPressGesture {
                                    switch entry {
                                    case .log(let log):
                                        pendingDeleteSkip = nil
                                        pendingDeleteLog = log
                                    case .skip(let skip):
                                        pendingDeleteLog = nil
                                        pendingDeleteSkip = skip
                                    }
                                    showDeleteDialog = true
                                }
                            }

                            if historyEntries.count > visibleEntries.count {
                                HStack {
                                    Spacer()
                                    LoadMoreButton {
                                        visibleHistoryCount += 4
                                    }
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            },
            footer: {
                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
            }
        )
        .onAppear {
            visibleHistoryCount = 4
            pendingDeleteLog = nil
            pendingDeleteSkip = nil
        }
        .lystariaAlertConfirm(
            isPresented: $showDeleteDialog,
            title: "Delete history record?",
            message: "This will permanently delete this habit history record.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let log = pendingDeleteLog {
                modelContext.delete(log)
                habit.logs = (habit.logs ?? []).filter { $0.persistentModelID != log.persistentModelID }
                pendingDeleteLog = nil
            }

            if let skip = pendingDeleteSkip {
                modelContext.delete(skip)
                habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != skip.persistentModelID }
                pendingDeleteSkip = nil
            }
        }
    }
}

// MARK: - New Habit Sheet

struct NewHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    var onClose: (() -> Void)? = nil
    
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
    
    private var closeAction: () -> Void {
        onClose ?? {}
    }
    
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
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 720,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "New Habit", size: 26)
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
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
                                if reminderTimes.isEmpty { reminderTimes = [Date()] }
                                
                                if reminderTimes.count < newValue {
                                    while reminderTimes.count < newValue {
                                        reminderTimes.append(reminderTimes.last ?? Date())
                                    }
                                } else if reminderTimes.count > newValue {
                                    reminderTimes = Array(reminderTimes.prefix(newValue))
                                }
                                
                                if reminderEnabled && reminderKind == .daily {
                                    daysPerWeek = 7
                                    weeklyDays = []
                                }
                            }
                    }
                }
                
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
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
            },
            footer: {
                Button {
                    // Enforce habit limit (3 total for free users)
                    let descriptor = FetchDescriptor<Habit>()
                    let existing = (try? modelContext.fetch(descriptor)) ?? []
                    let decision = limits.canCreate(.habitsTotal, currentCount: existing.count)
                    guard decision.allowed else { return }
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
                                intervalMinutes: nil,
                                recurrenceInterval: 1,
                                dayOfMonth: nil,
                                anchorMonth: nil,
                                anchorDay: nil
                            )
                            
                            let suffix = reminderTimes.count > 1 ? " (\(idx + 1)/\(reminderTimes.count))" : ""
                            
                            let r = LystariaReminder(
                                title: habit.title + suffix,
                                details: habit.details,
                                nextRunAt: firstRun,
                                schedule: schedule,
                                timezone: TimeZone.current.identifier,
                                linkedKind: .habit,
                                linkedHabitId: habit.id
                            )
                            modelContext.insert(r)
                            NotificationManager.shared.scheduleReminder(r)
                        }
                    }
                    
                    closeAction()
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
        )
    }
}

// MARK: - Edit Habit Sheet

struct EditHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    var onClose: (() -> Void)? = nil

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

    init(habit: Habit, onClose: (() -> Void)? = nil) {
        self._habit = Bindable(wrappedValue: habit)
        self.onClose = onClose
    }

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    private var closeAction: () -> Void {
        onClose ?? {}
    }

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
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 720,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Edit Habit", size: 26)
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
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

                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
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
            },
            footer: {
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
        )
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
                    intervalMinutes: nil,
                    recurrenceInterval: 1,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil
                )

                let suffix = reminderTimes.count > 1 ? " (\(idx + 1)/\(reminderTimes.count))" : ""

                let rr = LystariaReminder(
                    title: habit.title + suffix,
                    details: habit.details,
                    nextRunAt: firstRun,
                    schedule: schedule,
                    timezone: TimeZone.current.identifier,
                    linkedKind: .habit,
                    linkedHabitId: habit.id
                )

                modelContext.insert(rr)
                NotificationManager.shared.scheduleReminder(rr)
            }
        }

        closeAction()
    }
}
