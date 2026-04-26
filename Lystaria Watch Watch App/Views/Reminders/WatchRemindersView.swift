//
//  WatchRemindersView.swift
//  Lystaria
//

import SwiftUI
import SwiftData

// =======================================================
// MARK: - MAIN REMINDERS VIEW
// =======================================================

struct WatchRemindersView: View {

    @Query(sort: \LystariaReminder.nextRunAt, order: .forward)
    private var allReminders: [LystariaReminder]

    private var now: Date { Date() }

    private var scheduled: [LystariaReminder] {
        allReminders.filter {
            $0.status == .scheduled && $0.linkedKind == nil
        }
    }

    private var overdue: [LystariaReminder] {
        scheduled.filter { $0.nextRunAt < now }
    }

    private var upcoming: [LystariaReminder] {
        scheduled.filter { $0.nextRunAt >= now }
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            if scheduled.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No reminders")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        if !overdue.isEmpty {
                            sectionLabel("OVERDUE")
                            ForEach(overdue, id: \.persistentModelID) { reminder in
                                NavigationLink {
                                    WatchReminderDetailView(reminder: reminder)
                                } label: {
                                    ReminderRow(reminder: reminder, isOverdue: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !upcoming.isEmpty {
                            sectionLabel("UPCOMING")
                            ForEach(upcoming, id: \.persistentModelID) { reminder in
                                NavigationLink {
                                    WatchReminderDetailView(reminder: reminder)
                                } label: {
                                    ReminderRow(reminder: reminder, isOverdue: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.leading, 2)
    }
}

// =======================================================
// MARK: - REMINDER ROW
// =======================================================

private struct ReminderRow: View {
    let reminder: LystariaReminder
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isOverdue
                        ? LinearGradient(colors: [
                            Color(red: 125/255, green: 25/255, blue: 247/255),
                            Color(red: 3/255, green: 219/255, blue: 252/255)
                          ], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.15)
                          ], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(timeLabel(for: reminder.nextRunAt))
                    .font(.system(size: 10))
                    .foregroundStyle(isOverdue
                        ? Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.9)
                        : Color.white.opacity(0.45))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(isOverdue ? 0.1 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isOverdue ? 0.15 : 0.08), lineWidth: 1)
        )
    }

    private func timeLabel(for date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            return df.string(from: date)
        } else if cal.isDateInTomorrow(date) {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            return "Tomorrow · \(df.string(from: date))"
        } else if date < now {
            let mins = Int(now.timeIntervalSince(date) / 60)
            if mins < 60 { return "\(mins)m overdue" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h overdue" }
            return "\(hrs / 24)d overdue"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d · h:mm a"
            return df.string(from: date)
        }
    }
}

// =======================================================
// MARK: - DETAIL VIEW (paged)
// =======================================================

struct WatchReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let reminder: LystariaReminder

    @State private var isDone = false

    private var hasDetails: Bool {
        guard let d = reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !d.isEmpty
    }

    var body: some View {
        TabView {
            // Page 1 — title + description
            descriptionPage

            // Page 2 — time info + mark done
            actionPage
        }
        .tabViewStyle(.page)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Page 1: Description

    private var descriptionPage: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(spacing: 10) {
                    // Gradient title pill
                    Text(reminder.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    if hasDetails {
                        Text(reminder.details!)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No description")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                            .italic()
                    }

                    // Swipe hint
                    HStack(spacing: 4) {
                        Text("Swipe for actions")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.25))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Page 2: Actions

    private var actionPage: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 12) {
                // Schedule badge
                VStack(spacing: 3) {
                    Text(scheduleLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)

                    Text(formattedNextRun)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))

                // Mark done / confirmed
                if isDone {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 3/255, green: 219/255, blue: 252/255))
                            .font(.system(size: 16))
                        Text("Done!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Button {
                        markDone()
                    } label: {
                        Text("Mark Done")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 125/255, green: 25/255,  blue: 247/255),
                                        Color(red: 3/255,   green: 219/255, blue: 252/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Labels

    private var scheduleLabel: String {
        guard let schedule = reminder.schedule else { return "ONCE" }
        return schedule.kind.label.uppercased()
    }

    private var formattedNextRun: String {
        let cal = Calendar.current
        let df = DateFormatter()
        if cal.isDateInToday(reminder.nextRunAt) {
            df.dateStyle = .none
            df.timeStyle = .short
            return "Today · \(df.string(from: reminder.nextRunAt))"
        } else if cal.isDateInTomorrow(reminder.nextRunAt) {
            df.dateStyle = .none
            df.timeStyle = .short
            return "Tomorrow · \(df.string(from: reminder.nextRunAt))"
        }
        df.dateFormat = "MMM d · h:mm a"
        return df.string(from: reminder.nextRunAt)
    }

    // MARK: - Mark Done

    private func markDone() {
        let now = Date()
        reminder.acknowledgedAt = now
        reminder.lastCompletedAt = now
        reminder.updatedAt = now

        // Append to the completion timestamp array so iOS doneTodayCount picks it up.
        let existing = decodeTimestamps(reminder)
        let todayOnly = existing.filter { Calendar.current.isDateInToday($0) }
        reminder.completionTimestampsStorage = encodeTimestamps(todayOnly + [now])

        if reminder.isRecurring {
            if let next = nextOccurrence(after: now, for: reminder) {
                reminder.nextRunAt = next
                reminder.acknowledgedAt = nil
            } else {
                reminder.status = .sent
            }
        } else {
            reminder.status = .sent
        }

        try? modelContext.save()
        isDone = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            dismiss()
        }
    }

    // MARK: - Timestamp helpers

    private func decodeTimestamps(_ reminder: LystariaReminder) -> [Date] {
        guard let data = reminder.completionTimestampsStorage.data(using: .utf8),
              let intervals = try? JSONDecoder().decode([Double].self, from: data)
        else { return [] }
        return intervals.map { Date(timeIntervalSince1970: $0) }
    }

    private func encodeTimestamps(_ dates: [Date]) -> String {
        let intervals = dates.map(\.timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(intervals),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }

    // MARK: - Next Occurrence

    private func nextOccurrence(after date: Date, for reminder: LystariaReminder) -> Date? {
        guard reminder.schedule != nil, reminder.isRecurring else { return nil }
        return ReminderCompute.nextRun(after: date, reminder: reminder)
    }
}
