// ReminderHistoryDayView.swift
// Lystaria

import SwiftUI
import SwiftData

struct ReminderHistoryDayView: View {
    let initialDay: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var allHistory: [ReminderHistoryEntry]

    @State private var selectedDay: Date
    @State private var displayedMonth: Date

    private let cal = Calendar.current

    init(day: Date) {
        self.initialDay = day
        let start = Calendar.current.startOfDay(for: day)
        _selectedDay = State(initialValue: start)
        let comps = Calendar.current.dateComponents([.year, .month], from: day)
        _displayedMonth = State(initialValue: Calendar.current.date(from: comps) ?? day)

        // Record the earliest navigable month the first time this view is ever opened.
        let key = "reminderHistoryStartMonth"
        if UserDefaults.standard.object(forKey: key) == nil {
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            UserDefaults.standard.set(monthStart, forKey: key)
        }
    }

    // MARK: - Calendar helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    private func startOfMonth(for date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private var historyStartMonth: Date {
        UserDefaults.standard.object(forKey: "reminderHistoryStartMonth") as? Date
            ?? startOfMonth(for: Date())
    }

    private var canGoBack: Bool {
        startOfMonth(for: displayedMonth) > historyStartMonth
    }

    private var canGoForward: Bool {
        startOfMonth(for: displayedMonth) < startOfMonth(for: Date())
    }

    private func changeMonth(by value: Int) {
        if let next = cal.date(byAdding: .month, value: value, to: displayedMonth) {
            let nextStart = startOfMonth(for: next)
            if nextStart >= historyStartMonth && nextStart <= startOfMonth(for: Date()) {
                displayedMonth = next
            }
        }
    }

    private struct CalDayItem: Identifiable {
        let id: String
        let dayNumber: Int?
        let date: Date?
        let hasCompleted: Bool
        let hasSkipped: Bool
        let isToday: Bool
    }

    private var daysInDisplayedMonth: [CalDayItem] {
        let start = startOfMonth(for: displayedMonth)
        let range = cal.range(of: .day, in: .month, for: start) ?? 1..<2
        let firstWeekday = cal.component(.weekday, from: start)
        let leadingEmpty = max(0, firstWeekday - 1)

        var items: [CalDayItem] = []

        for i in 0..<leadingEmpty {
            items.append(CalDayItem(id: "empty-\(i)", dayNumber: nil, date: nil,
                                    hasCompleted: false, hasSkipped: false, isToday: false))
        }

        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: start) else { continue }
            let dStart = cal.startOfDay(for: date)
            let dEnd = cal.date(byAdding: .day, value: 1, to: dStart) ?? dStart
            let hasC = allHistory.contains { $0.kindRaw == "completed" && $0.occurredAt >= dStart && $0.occurredAt < dEnd }
            let hasS = allHistory.contains { $0.kindRaw == "skipped"   && $0.occurredAt >= dStart && $0.occurredAt < dEnd }
            items.append(CalDayItem(
                id: "day-\(day)", dayNumber: day, date: date,
                hasCompleted: hasC, hasSkipped: hasS,
                isToday: cal.isDateInToday(date)
            ))
        }

        while items.count % 7 != 0 {
            let i = items.count
            items.append(CalDayItem(id: "trail-\(i)", dayNumber: nil, date: nil,
                                    hasCompleted: false, hasSkipped: false, isToday: false))
        }

        return items
    }

    // MARK: - Entries for selected day

    private var dayStart: Date { cal.startOfDay(for: selectedDay) }
    private var dayEnd:   Date { cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart }

    private var completedEntries: [ReminderHistoryEntry] {
        allHistory
            .filter { $0.kindRaw == "completed" && $0.occurredAt >= dayStart && $0.occurredAt < dayEnd }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private var skippedEntries: [ReminderHistoryEntry] {
        allHistory
            .filter { $0.kindRaw == "skipped" && $0.occurredAt >= dayStart && $0.occurredAt < dayEnd }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LystariaBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        historyCalendarCard

                        if completedEntries.isEmpty && skippedEntries.isEmpty {
                            emptyState
                        } else {
                            if !completedEntries.isEmpty {
                                sectionHeader("Completed", icon: "checkmark.circle.fill", color: LColors.success)
                                VStack(spacing: 12) {
                                    ForEach(completedEntries) { entry in
                                        HistoryEntryCard(entry: entry)
                                    }
                                }
                            }

                            if !skippedEntries.isEmpty {
                                sectionHeader("Skipped", icon: "slash.circle.fill",
                                              color: Color(red: 0.36, green: 0.28, blue: 0.90))
                                VStack(spacing: 12) {
                                    ForEach(skippedEntries) { entry in
                                        HistoryEntryCard(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                    .frame(width: max(0, proxy.size.width - 36), alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                GradientTitle(text: "Reminder History", font: .system(size: 28, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    private var historyCalendarCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(monthTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    HStack(spacing: 8) {
                        Button { changeMonth(by: -1) } label: {
                            ZStack {
                                Circle()
                                    .fill(canGoBack ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                                    .overlay(Circle().stroke(LColors.glassBorder.opacity(canGoBack ? 1 : 0.4), lineWidth: 1))
                                    .frame(width: 30, height: 30)
                                Image("chevleft")
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(canGoBack ? .white : Color.white.opacity(0.3))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canGoBack)

                        Button { changeMonth(by: 1) } label: {
                            ZStack {
                                Circle()
                                    .fill(canGoForward ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                                    .overlay(Circle().stroke(LColors.glassBorder.opacity(canGoForward ? 1 : 0.4), lineWidth: 1))
                                    .frame(width: 30, height: 30)
                                Image("chevright")
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(canGoForward ? .white : Color.white.opacity(0.3))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canGoForward)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(daysInDisplayedMonth) { item in
                        if let day = item.dayNumber, let itemDate = item.date {
                            let isSelected = cal.isDate(itemDate, inSameDayAs: selectedDay)
                            let isFuture = itemDate > cal.startOfDay(for: Date())

                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if item.hasCompleted && item.hasSkipped {
                                            ZStack {
                                                LGradients.blue
                                                GradientOverlayBackground().clipShape(Circle())
                                            }
                                            .clipShape(Circle())
                                        } else if item.hasCompleted {
                                            Circle().fill(LColors.success.opacity(0.55))
                                        } else if item.hasSkipped {
                                            Circle().fill(Color(red: 0.36, green: 0.28, blue: 0.90).opacity(0.55))
                                        }
                                    }
                                    .overlay(
                                        Circle().stroke(
                                            isSelected ? Color.white : (item.isToday ? Color.white.opacity(0.55) : LColors.glassBorder),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                    )

                                Text("\(day)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isFuture ? Color.white.opacity(0.25) : .white)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isFuture else { return }
                                selectedDay = cal.startOfDay(for: itemDate)
                                let comps = cal.dateComponents([.year, .month], from: itemDate)
                                if let m = cal.date(from: comps) { displayedMonth = m }
                            }
                        } else {
                            Color.clear.frame(width: 30, height: 30).frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    legendDot(color: LColors.success, label: "Completed")
                    legendDot(color: Color(red: 0.36, green: 0.28, blue: 0.90), label: "Skipped")
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.7)).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No reminder activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                Text("Completed and skipped reminders for this day will appear here.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Entry Card

private struct HistoryEntryCard: View {
    let entry: ReminderHistoryEntry

    private static let skipColor = Color(red: 0.36, green: 0.28, blue: 0.90)

    private var isSkipped: Bool { entry.kindRaw == "skipped" }

    private var typeLabel: String {
        if let raw = entry.linkedKindRaw {
            switch raw.lowercased() {
            case "habit":      return "Habit"
            case "medication": return "Medication"
            case "event":      return "Event"
            default: break
            }
        }
        switch entry.reminderTypeRaw {
        case "routine": return "Routine"
        default:
            switch entry.reminderScheduleKindRaw {
            case "once": return "One-Time"
            default:     return "Recurring"
            }
        }
    }

    private var scheduleLabel: String {
        ReminderScheduleKind(rawValue: entry.reminderScheduleKindRaw)?.label ?? "Once"
    }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.reminderTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(2)
                        if let details = entry.reminderDetails,
                           !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(details)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                                .lineLimit(3)
                        }
                    }
                    Spacer()
                    Text(entry.occurredAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                HStack(spacing: 8) {
                    badge(typeLabel)
                    badge(scheduleLabel)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusIcon: some View {
        let color = isSkipped ? Self.skipColor : LColors.accent
        let icon  = isSkipped ? "slash.circle" : "checkmark"
        return ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: 36, height: 36)
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1))
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }
}
