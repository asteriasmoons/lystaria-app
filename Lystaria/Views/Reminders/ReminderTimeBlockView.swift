// ReminderTimeBlockView.swift
// Lystaria

import SwiftData
import SwiftUI

struct ReminderTimeBlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var limits = LimitManager.shared

    @Query var allReminders: [LystariaReminder]
    let onMarkDone: (LystariaReminder) -> Void


    @State private var selectedDate: Date = .init()
    @State private var editingReminder: LystariaReminder? = nil
    @State private var detailReminder: LystariaReminder? = nil
    @State private var showingDetailPopup = false
    /// Optimistic local tracking: IDs marked done this session so the circle
    /// flips immediately without waiting for SwiftData to propagate.
    @State private var locallyDoneIDs: Set<PersistentIdentifier> = []
    @State private var toastMessage: String? = nil

    private var tzCalendar: Calendar {
        ReminderCompute.tzCalendar
    }

    private var headerTitle: String {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEEE, MMMM d")
        return df.string(from: selectedDate)
    }

    private var visibleHours: [Int] {
        Array(5 ... 23)
    }

    // MARK: - Done state

    /// Whether to show the "Done" status badge.
    /// For recurring reminders: only show Done if completed today AND nextRunAt has moved past today
    /// (meaning no more occurrences today). If nextRunAt is still today, an upcoming slot exists.
    /// For non-recurring (once): done if completed or acknowledged today.
    private func reminderShowsDoneBadge(_ reminder: LystariaReminder) -> Bool {
        if reminder.isRecurring {
            if let completedAt = reminder.lastCompletedAt, Calendar.current.isDateInToday(completedAt) {
                return !Calendar.current.isDateInToday(reminder.nextRunAt)
            }
            return false
        } else {
            if let completedAt = reminder.lastCompletedAt, Calendar.current.isDateInToday(completedAt) { return true }
            if let ack = reminder.acknowledgedAt, Calendar.current.isDateInToday(ack) { return true }
            return false
        }
    }

    /// Whether the circle button should appear filled — only for non-recurring (once) reminders.
    private func reminderCircleIsFilled(_ reminder: LystariaReminder) -> Bool {
        if reminder.isRecurring { return false }
        if locallyDoneIDs.contains(reminder.persistentModelID) { return true }
        if let completedAt = reminder.lastCompletedAt, Calendar.current.isDateInToday(completedAt) { return true }
        if let ack = reminder.acknowledgedAt, Calendar.current.isDateInToday(ack) { return true }
        return false
    }

    /// Used for overdue/dueNow/upcoming logic — a reminder is "done" if its badge shows done.
    private func reminderIsDone(_ reminder: LystariaReminder) -> Bool {
        reminderShowsDoneBadge(reminder)
    }

    // MARK: - Slot resolution

    private var allowedReminderIds: Set<PersistentIdentifier> {
        guard !limits.hasPremiumAccess else { return Set() }
        return Set(
            allReminders
                .filter { $0.status != .deleted }
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(limits.limit(for: .remindersTotal) ?? Int.max)
                .map { $0.persistentModelID }
        )
    }

    private func remindersForHour(_ hour: Int) -> [(LystariaReminder, Date)] {
        let cal = tzCalendar
        let dayAnchor = cal.startOfDay(for: selectedDate)
        var result: [(LystariaReminder, Date)] = []

        for reminder in allReminders {
            guard reminder.status != .deleted else { continue }
            guard let schedule = reminder.schedule else { continue }

            switch schedule.kind {
            case .once:
                guard cal.isDate(reminder.nextRunAt, inSameDayAs: selectedDate) else { continue }
                let h = cal.component(.hour, from: reminder.nextRunAt)
                if h == hour { result.append((reminder, reminder.nextRunAt)) }

            case .interval:
                if reminder.linkedKind == .habit,
                   let habitId = reminder.linkedHabitId {
                    let descriptor = FetchDescriptor<Habit>()
                    let habits = (try? modelContext.fetch(descriptor)) ?? []
                    if let habit = habits.first(where: { $0.id == habitId }),
                       let (startH, startM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
                       let (endH, endM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd) {
                        let intervalMinutes: Int
                        if habit.reminderKind == .everyXHours {
                            intervalMinutes = max(1, habit.reminderIntervalHours) * 60
                        } else if habit.reminderKind == .everyXMinutes {
                            intervalMinutes = max(1, habit.reminderIntervalMinutes)
                        } else {
                            intervalMinutes = 0
                        }

                        if intervalMinutes > 0 {
                            let dayStart = cal.startOfDay(for: selectedDate)
                            let startDate = cal.date(bySettingHour: startH, minute: startM, second: 0, of: dayStart) ?? dayStart
                            let endDate = cal.date(bySettingHour: endH, minute: endM, second: 0, of: dayStart) ?? dayStart

                            if endDate >= startDate {
                                var slot = startDate
                                while slot <= endDate {
                                    let slotHour = cal.component(.hour, from: slot)
                                    if slotHour == hour {
                                        result.append((reminder, slot))
                                    }
                                    guard let nextSlot = cal.date(byAdding: .minute, value: intervalMinutes, to: slot) else { break }
                                    slot = nextSlot
                                }
                                continue
                            }
                        }
                    }
                }

                guard cal.isDate(reminder.nextRunAt, inSameDayAs: selectedDate) else { continue }
                let h = cal.component(.hour, from: reminder.nextRunAt)
                if h == hour { result.append((reminder, reminder.nextRunAt)) }

            case .daily, .weekly, .monthly, .yearly:
                let firesOnDay = cal.isDate(reminder.nextRunAt, inSameDayAs: selectedDate)
                    || isCompletedOn(reminder, date: selectedDate)
                guard firesOnDay else { continue }

                let times: [String]
                if let tod = schedule.timesOfDay, !tod.isEmpty {
                    times = tod
                } else if let tod = schedule.timeOfDay {
                    times = [tod]
                } else {
                    let h = cal.component(.hour, from: reminder.nextRunAt)
                    if h == hour { result.append((reminder, reminder.nextRunAt)) }
                    continue
                }

                for timeStr in times {
                    guard let (hh, mm) = ReminderCompute.parseHHMM(timeStr) else { continue }
                    if hh == hour {
                        let fireDate = cal.date(bySettingHour: hh, minute: mm, second: 0, of: dayAnchor) ?? dayAnchor
                        result.append((reminder, fireDate))
                    }
                }
            }
        }

        return result.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0.title < $1.0.title
        }
    }

    private func recordedCompletionDates(for reminder: LystariaReminder) -> [Date] {
        let raw = reminder.completionTimestampsStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "[]", let data = raw.data(using: .utf8) else { return [] }

        if let values = try? JSONDecoder().decode([Double].self, from: data) {
            return values.map { Date(timeIntervalSince1970: $0) }
        }

        if let values = try? JSONDecoder().decode([TimeInterval].self, from: data) {
            return values.map { Date(timeIntervalSince1970: $0) }
        }

        if let values = try? JSONDecoder().decode([String].self, from: data) {
            return values.compactMap { value in
                if let interval = TimeInterval(value) {
                    return Date(timeIntervalSince1970: interval)
                }
                return ISO8601DateFormatter().date(from: value)
            }
        }

        return []
    }

    private func isCompletedOccurrence(_ reminder: LystariaReminder, fireDate: Date) -> Bool {
        let cal = tzCalendar
        let fireHour = cal.component(.hour, from: fireDate)
        let fireMinute = cal.component(.minute, from: fireDate)

        if let completedAt = reminder.lastCompletedAt,
           cal.isDate(completedAt, inSameDayAs: fireDate)
        {
            let completedHour = cal.component(.hour, from: completedAt)
            let completedMinute = cal.component(.minute, from: completedAt)
            if completedHour == fireHour && completedMinute == fireMinute {
                return true
            }
        }

        if let ack = reminder.acknowledgedAt,
           cal.isDate(ack, inSameDayAs: fireDate)
        {
            let ackHour = cal.component(.hour, from: ack)
            let ackMinute = cal.component(.minute, from: ack)
            if ackHour == fireHour && ackMinute == fireMinute {
                return true
            }
        }

        return recordedCompletionDates(for: reminder).contains { recorded in
            cal.isDate(recorded, inSameDayAs: fireDate)
                && cal.component(.hour, from: recorded) == fireHour
                && cal.component(.minute, from: recorded) == fireMinute
        }
    }

    private func isCompletedOn(_ reminder: LystariaReminder, date: Date) -> Bool {
        if let completedAt = reminder.lastCompletedAt,
           tzCalendar.isDate(completedAt, inSameDayAs: date)
        {
            return true
        }
        if let ack = reminder.acknowledgedAt,
           tzCalendar.isDate(ack, inSameDayAs: date)
        {
            return true
        }
        return recordedCompletionDates(for: reminder).contains { tzCalendar.isDate($0, inSameDayAs: date) }
    }

    private func isOverdue(_ reminder: LystariaReminder, fireDate _: Date) -> Bool {
        if reminderIsDone(reminder) { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return reminder.nextRunAt < startOfToday
    }

    private func isDueNow(_ reminder: LystariaReminder, fireDate: Date, now: Date) -> Bool {
        if reminderIsDone(reminder) { return false }
        if isOverdue(reminder, fireDate: fireDate) { return false }
        guard tzCalendar.isDateInToday(selectedDate) else { return false }
        // For recurring reminders: only due now if nextRunAt matches this fire slot's time
        if reminder.isRecurring {
            let cal = tzCalendar
            let nextHour = cal.component(.hour, from: reminder.nextRunAt)
            let nextMin = cal.component(.minute, from: reminder.nextRunAt)
            let fireHour = cal.component(.hour, from: fireDate)
            let fireMin = cal.component(.minute, from: fireDate)
            // Only show Due Now if nextRunAt points at this specific slot and it has passed
            guard nextHour == fireHour, nextMin == fireMin else { return false }
            return fireDate <= now && cal.isDate(reminder.nextRunAt, inSameDayAs: now)
        }
        return fireDate <= now
    }

    private func isUpcoming(_ reminder: LystariaReminder, fireDate: Date, now: Date) -> Bool {
        if reminderIsDone(reminder) { return false }
        if isOverdue(reminder, fireDate: fireDate) { return false }
        guard tzCalendar.isDateInToday(selectedDate) else { return false }
        // Upcoming: fire time is still in the future
        return fireDate > now
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LystariaBackground()
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        LazyVStack(spacing: 0) {
                            ForEach(visibleHours, id: \.self) { hour in
                                hourRow(hour)
                                    .id(hour)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 300)
                    }
                }
                .onAppear {
                    let currentHour = tzCalendar.component(.hour, from: Date())
                    let targetHour = visibleHours.contains(currentHour) ? currentHour : visibleHours.first ?? 5
                    proxy.scrollTo(targetHour, anchor: .top)
                }
            }
            toastOverlay
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastMessage)
        .fullScreenCover(item: $editingReminder) { r in
            EditReminderSheet(onClose: { editingReminder = nil }, reminder: r)
                .preferredColorScheme(.dark)
        }
        .overlay {
            if showingDetailPopup, let r = detailReminder {
                timeBlockDetailPopup(reminder: r)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Button { prevDay() } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    GradientTitle(text: headerTitle, font: .system(size: 20, weight: .bold))
                        .onTapGesture { dismiss() }

                    Button { nextDay() } label: {
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                Button { selectedDate = Date() } label: {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LColors.accent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .opacity(tzCalendar.isDateInToday(selectedDate) ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: tzCalendar.isDateInToday(selectedDate))
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 16)

            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    // MARK: - Hour row

    private func hourRow(_ hour: Int) -> some View {
        let slots = remindersForHour(hour)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let isCurrentHour = tzCalendar.isDateInToday(selectedDate)
                        && tzCalendar.component(.hour, from: context.date) == hour
                    VStack(spacing: 2) {
                        Text(hourLabel(hour))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isCurrentHour ? LColors.accent : LColors.textPrimary)
                        Text(hourPeriod(hour))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isCurrentHour ? LColors.accent.opacity(0.7) : LColors.textSecondary)
                    }
                }
                .frame(width: 52)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if slots.isEmpty {
                        Text("No reminders")
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(slots, id: \.0.persistentModelID) { reminder, fireDate in
                            reminderSlotCard(reminder: reminder, fireDate: fireDate)
                                .premiumLocked(!limits.hasPremiumAccess && !allowedReminderIds.contains(reminder.persistentModelID))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 8)

            Rectangle()
                .fill(LColors.glassBorder.opacity(0.4))
                .frame(height: 1)
                .padding(.leading, 66 + LSpacing.pageHorizontal)
        }
    }

    // MARK: - Reminder slot card

    private func reminderSlotCard(reminder: LystariaReminder, fireDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let badgeDone = isCompletedOccurrence(reminder, fireDate: fireDate) || reminderShowsDoneBadge(reminder)
            let circleFilled = reminderCircleIsFilled(reminder)
            let overdue = isOverdue(reminder, fireDate: fireDate)
            let dueNow = !overdue && isDueNow(reminder, fireDate: fireDate, now: now)
            let upcoming = !overdue && !dueNow && isUpcoming(reminder, fireDate: fireDate, now: now)
            let reminderColor = Color(ly_hex: reminder.color)
            let accentColor: Color = overdue ? LColors.danger : (dueNow ? LColors.accent : (upcoming ? LColors.textSecondary : reminderColor))

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(reminderColor)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        let kindLabel = reminder.schedule?.kind.label ?? "Once"
                        Text(kindLabel.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))

                        if badgeDone {
                            TimeBlockStatusBadge(label: "Done", style: .upcoming)
                        } else if overdue {
                            TimeBlockStatusBadge(label: "Overdue", style: .overdue)
                        } else if dueNow {
                            TimeBlockStatusBadge(label: "Due Now", style: .dueNow)
                        } else if upcoming {
                            TimeBlockStatusBadge(label: "Upcoming", style: .upcoming)
                        }
                    }

                    Text(reminder.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)

                    if let details = reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !details.isEmpty
                    {
                        Text(details)
                            .font(.system(size: 12))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(2)
                    }

                    Text(formatTime(fireDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.9))
                }
                .padding(.leading, 10)

                Spacer()

                VStack(spacing: 8) {
                    let id = reminder.persistentModelID
                    Button {
                        print("[TimeBlock] Circle tapped for: \(reminder.title)")
                        print("[TimeBlock] isRecurring: \(reminder.isRecurring)")
                        print("[TimeBlock] badgeDone: \(badgeDone)")
                        print("[TimeBlock] circleFilled: \(circleFilled)")
                        if let live = modelContext.model(for: id) as? LystariaReminder {
                            print("[TimeBlock] Got live model: \(live.title)")
                            if !live.isRecurring {
                                locallyDoneIDs.insert(id)
                            }
                            onMarkDone(live)
                            // For recurring reminders, clear immediately so circle doesn't stay filled
                            if live.isRecurring {
                                locallyDoneIDs.remove(id)
                            }
                            showToast("\(live.title) marked complete")
                        }
                    } label: {
                        Image(systemName: circleFilled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(circleFilled ? LColors.success : LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(circleFilled)


                    Button { editingReminder = reminder } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(LColors.textPrimary.opacity(0.75))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
            }
            .padding(12)
            .background(LColors.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    detailReminder = reminder
                    showingDetailPopup = true
                }
            }
        }
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

    // MARK: - Helpers

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

    private func timeBlockDetailPopup(reminder: LystariaReminder) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let badgeDone = reminderShowsDoneBadge(reminder)
            let fireDate = reminder.nextRunAt
            let overdue = isOverdue(reminder, fireDate: fireDate)
            let dueNow = !overdue && isDueNow(reminder, fireDate: fireDate, now: now)
            let upcoming = !overdue && !dueNow && isUpcoming(reminder, fireDate: fireDate, now: now)

            let displayTime: String = {
                let df = DateFormatter()
                df.locale = .current
                df.setLocalizedDateFormatFromTemplate("EEE, MMM d 'at' h:mm a")
                return df.string(from: fireDate)
            }()

            LystariaOverlayPopup(
                onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showingDetailPopup = false
                        detailReminder = nil
                    }
                },
                width: 520,
                heightRatio: 0.45,
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

                    // Badges: schedule kind + status
                    HStack(spacing: 6) {
                        let kindLabel = reminder.schedule?.kind.label ?? "Once"
                        Text(kindLabel.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))

                        if badgeDone {
                            TimeBlockStatusBadge(label: "Done", style: .upcoming)
                        } else if overdue {
                            TimeBlockStatusBadge(label: "Overdue", style: .overdue)
                        } else if dueNow {
                            TimeBlockStatusBadge(label: "Due Now", style: .dueNow)
                        } else if upcoming {
                            TimeBlockStatusBadge(label: "Upcoming", style: .upcoming)
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
                    if let details = reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !details.isEmpty
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
                    let hasChecklist = reminder.reminderType == .routine
                        ? !routineItems.isEmpty
                        : !regularItems.isEmpty

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

                        Text(displayTime)
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

    // MARK: - Helpers

    private func prevDay() {
        selectedDate = tzCalendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextDay() {
        selectedDate = tzCalendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12"
        case 13 ... 23: "\(hour - 12)"
        default: "\(hour)"
        }
    }

    private func hourPeriod(_ hour: Int) -> String {
        hour < 12 ? "AM" : "PM"
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("h:mm a")
        return df.string(from: date)
    }


    // MARK: - Time Block Status Badge (smaller, matches schedule kind badge size)

    private struct TimeBlockStatusBadge: View {
        let label: String
        let style: ReminderStatusBadgeStyle

        var body: some View {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(border, lineWidth: 1))
        }

        private var background: Color {
            switch style {
            case .overdue: LColors.danger.opacity(0.17)
            case .dueNow: LColors.accent.opacity(0.18)
            case .upcoming: Color.white.opacity(0.09)
            }
        }

        private var foreground: Color {
            switch style {
            case .overdue: LColors.danger
            case .dueNow: LColors.accent
            case .upcoming: LColors.textPrimary
            }
        }

        private var border: Color {
            switch style {
            case .overdue: LColors.danger.opacity(0.45)
            case .dueNow: LColors.accent.opacity(0.44)
            case .upcoming: LColors.glassBorder
            }
        }
    }
}
