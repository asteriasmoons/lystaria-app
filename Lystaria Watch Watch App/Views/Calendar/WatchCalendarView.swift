//
//  WatchCalendarView.swift
//  Lystaria Watch Watch App
//

import SwiftUI
import SwiftData

// =======================================================
// MARK: - MAIN CALENDAR VIEW
// =======================================================

struct WatchCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<CalendarEvent> { !$0.isCancelledOccurrence },
        sort: \CalendarEvent.startDate
    )
    private var allEvents: [CalendarEvent]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let visibleDays: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }()

    private func events(for day: Date) -> [ResolvedCalendarOccurrence] {
        CalendarEventResolver.occurrences(on: day, from: allEvents)
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 0) {
                // Date strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(visibleDays, id: \.self) { day in
                                DayChip(
                                    date: day,
                                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                                    hasEvents: !events(for: day).isEmpty
                                )
                                .id(day)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = day
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        proxy.scrollTo(selectedDate, anchor: .center)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.1))

                let dayEvents = events(for: selectedDate)

                if dayEvents.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("No events")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(dayEvents) { occ in
                                NavigationLink {
                                    if let sourceEvent = allEvents.first(where: { $0.localEventId == occ.sourceEventId }) {
                                        WatchEventDetailView(event: sourceEvent)
                                    }
                                } label: {
                                    OccurrenceRow(occurrence: occ)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle(dayTitle(for: selectedDate))
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func dayTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// =======================================================
// MARK: - DAY CHIP
// =======================================================

private struct DayChip: View {
    let date: Date
    let isSelected: Bool
    let hasEvents: Bool

    private var dayNum: String {
        let df = DateFormatter(); df.dateFormat = "d"
        return df.string(from: date)
    }

    private var dayName: String {
        let df = DateFormatter(); df.dateFormat = "EEE"
        return df.string(from: date).uppercased()
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.45))

            ZStack {
                Circle()
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [
                                Color(red: 125/255, green: 25/255,  blue: 247/255),
                                Color(red: 3/255,   green: 219/255, blue: 252/255)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(isToday ? Color.white.opacity(0.18) : Color.clear)
                    )
                    .frame(width: 28, height: 28)

                Text(dayNum)
                    .font(.system(size: 13, weight: isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(.white)
            }

            Circle()
                .fill(hasEvents ? Color(red: 3/255, green: 219/255, blue: 252/255) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(width: 32)
    }
}

// =======================================================
// MARK: - OCCURRENCE ROW
// =======================================================

private struct OccurrenceRow: View {
    let occurrence: ResolvedCalendarOccurrence

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: occurrence.color ?? "#6C63FF"))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(occurrence.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if occurrence.allDay {
                    Text("All day")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }

                if let location = occurrence.location,
                   !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(location)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var timeLabel: String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        let start = df.string(from: occurrence.startDate)
        if let end = occurrence.endDate {
            return "\(start) - \(df.string(from: end))"
        }
        return start
    }
}

// =======================================================
// MARK: - EVENT DETAIL VIEW (paged)
// =======================================================

struct WatchEventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEvent

    @State private var showDeleteConfirm = false

    private var hasDescription: Bool {
        guard let d = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !d.isEmpty
    }

    var body: some View {
        TabView {
            // Page 1 — title + description
            descriptionPage

            // Page 2 — details + delete
            detailsPage
        }
        .tabViewStyle(.page)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(event)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Page 1: Description

    private var descriptionPage: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(spacing: 10) {
                    // Color bar + title
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: event.displayColor))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)

                        Text(event.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if hasDescription {
                        Text(event.eventDescription!)
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
                        Text("Swipe for details")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.25))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Page 2: Details + Delete

    private var detailsPage: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(spacing: 8) {
                    // Date
                    detailCard(icon: "calendar", label: "DATE", value: dateLabel)

                    // Time
                    if !event.allDay {
                        detailCard(icon: "clock", label: "TIME", value: timeLabel)
                    } else {
                        detailCard(icon: "clock", label: "TIME", value: "All Day")
                    }

                    // Frequency
                    if event.isRecurring {
                        detailCard(icon: "arrow.clockwise", label: "FREQUENCY", value: recurrenceLabel)
                    }

                    // Calendar
                    if let cal = event.calendar, !cal.name.isEmpty {
                        detailCard(icon: "calendar.badge.checkmark", label: "CALENDAR", value: cal.name)
                    }

                    // Location
                    if let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
                        detailCard(icon: "mappin", label: "LOCATION", value: loc)
                    }

                    // Delete
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Delete Event")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func detailCard(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.8)

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Formatters

    private var dateLabel: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: event.startDate)
    }

    private var timeLabel: String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        let start = df.string(from: event.startDate)
        if let end = event.endDate {
            return "\(start) – \(df.string(from: end))"
        }
        return start
    }

    private var recurrenceLabel: String {
        if let rrule = event.recurrenceRRule,
           let parsed = ParsedRRule.parse(rrule) {
            let interval = max(1, parsed.interval)
            switch parsed.freq {
            case .daily:   return interval == 1 ? "Daily" : "Every \(interval) days"
            case .weekly:  return interval == 1 ? "Weekly" : "Every \(interval) weeks"
            case .monthly: return interval == 1 ? "Monthly" : "Every \(interval) months"
            case .yearly:  return interval == 1 ? "Yearly" : "Every \(interval) years"
            }
        }
        guard let rule = event.recurrence else { return "Repeating" }
        let interval = max(1, rule.interval)
        switch rule.freq {
        case .daily:   return interval == 1 ? "Daily" : "Every \(interval) days"
        case .weekly:  return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case .monthly: return interval == 1 ? "Monthly" : "Every \(interval) months"
        case .yearly:  return interval == 1 ? "Yearly" : "Every \(interval) years"
        }
    }
}

// =======================================================
// MARK: - DETAIL ROW (kept for any future use)
// =======================================================

private struct DetailRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 14)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
