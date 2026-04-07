//
// CalendarOverviewSheet.swift
// Lystaria
//

import SwiftUI

struct CalendarOverviewSheet: View {
    let allEvents: [CalendarEvent]

    @Environment(\.dismiss) private var dismiss

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    // MARK: - Computed stats

    private var stats: OverviewStats {
        let now = Date()
        let cal = tzCalendar

        // Today
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now

        // This week
        let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        let weekStart = weekInterval.start
        let weekEnd = weekInterval.end

        // This month
        let monthInterval = cal.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        // This year
        let yearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        let yearEnd = cal.date(byAdding: .year, value: 1, to: yearStart) ?? now

        let nonException = allEvents.filter { !$0.isRecurrenceException || !$0.isCancelledOccurrence }

        func eventsInRange(start: Date, end: Date) -> [CalendarEvent] {
            nonException.filter { event in
                let s = event.startDate
                let e = event.endDate ?? s
                return s < end && e > start || cal.isDate(s, inSameDayAs: start)
            }
        }

        func completedInRange(start: Date, end: Date) -> Int {
            // "Completed" = reminder was acknowledged (acknowledgedAt set) within range,
            // or event has passed (its start is before now) within the range.
            let events = eventsInRange(start: start, end: end)
            return events.filter { $0.startDate < now }.count
        }

        // Custom events = non-recurring, manually created (no rrule)
        let customAll = nonException.filter { $0.recurrenceRRule == nil && !($0.isRecurringSeriesMaster) }
        let customCompleted = customAll.filter { $0.startDate < now }.count

        return OverviewStats(
            eventsToday: eventsInRange(start: todayStart, end: todayEnd).count,
            completedToday: completedInRange(start: todayStart, end: todayEnd),
            eventsThisWeek: eventsInRange(start: weekStart, end: weekEnd).count,
            completedThisWeek: completedInRange(start: weekStart, end: weekEnd),
            eventsThisMonth: eventsInRange(start: monthStart, end: monthEnd).count,
            completedThisMonth: completedInRange(start: monthStart, end: monthEnd),
            eventsThisYear: eventsInRange(start: yearStart, end: yearEnd).count,
            completedThisYear: completedInRange(start: yearStart, end: yearEnd),
            customEvents: customAll.count,
            customCompleted: customCompleted
        )
    }

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    HStack {
                        HStack(spacing: 10) {
                            Image("calfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.white)

                            GradientTitle(text: "Calendar Overview", font: .title2.bold())
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    // Overview card
                    VStack(spacing: 0) {
                        overviewRow(label: "Events Today",      value: stats.eventsToday,       isFirst: true)
                        overviewRow(label: "Completed Today",   value: stats.completedToday)
                        Divider().background(LColors.glassBorder).padding(.horizontal, 4)
                        overviewRow(label: "This Week",         value: stats.eventsThisWeek)
                        overviewRow(label: "Weekly Completed",  value: stats.completedThisWeek)
                        Divider().background(LColors.glassBorder).padding(.horizontal, 4)
                        overviewRow(label: "This Month",        value: stats.eventsThisMonth)
                        overviewRow(label: "Monthly Completed", value: stats.completedThisMonth)
                        Divider().background(LColors.glassBorder).padding(.horizontal, 4)
                        overviewRow(label: "This Year",         value: stats.eventsThisYear)
                        overviewRow(label: "Yearly Completed",  value: stats.completedThisYear)
                        Divider().background(LColors.glassBorder).padding(.horizontal, 4)
                        overviewRow(label: "Custom Events",     value: stats.customEvents)
                        overviewRow(label: "Custom Completed",  value: stats.customCompleted,   isLast: true)
                    }
                    .background(LColors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func overviewRow(label: String, value: Int, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Text("\(value)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LColors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(LColors.accent.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Stats model

private struct OverviewStats {
    let eventsToday: Int
    let completedToday: Int
    let eventsThisWeek: Int
    let completedThisWeek: Int
    let eventsThisMonth: Int
    let completedThisMonth: Int
    let eventsThisYear: Int
    let completedThisYear: Int
    let customEvents: Int
    let customCompleted: Int
}
