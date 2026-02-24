// CalendarTabView.swift
// Lystaria

import SwiftUI
import SwiftData
#if os(iOS)
import UserNotifications
#endif

/// Wrapper that carries the date + optional event into the sheet.
struct EventSheetConfig: Identifiable {
    let id = UUID()
    let selectedDate: Date
    let editingEvent: CalendarEvent?
}

struct CalendarTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]

    @State private var currentMonth = Date()
    @State private var sheetConfig: EventSheetConfig? = nil
    @State private var showingSettingsSheet = false
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()

    // FIX 1: Pre-compute event instances once per render into a State dict,
    // instead of calling eventsFor() inside @ViewBuilder (which touches
    // SwiftData faulted objects during the render pass → SIGABRT).
    @State private var eventsByDay: [String: [EventInstance]] = [:]

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }
    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    private var monthName: String {
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df.string(from: currentMonth)
    }

    private var daysInMonth: [Date] {
        let cal = tzCalendar
        guard let range = cal.range(of: .day, in: .month, for: currentMonth) else { return [] }
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        return range.compactMap { day in
            cal.date(from: DateComponents(year: comps.year, month: comps.month, day: day))
        }
    }

    struct EventInstance: Identifiable {
        let id: String
        let event: CalendarEvent
        let occurrenceStart: Date
        let occurrenceEnd: Date?
    }

    // FIX 2: Rebuild the day→events map off the render pass.
    // Called from .onChange and .onAppear so SwiftData objects are accessed
    // in a safe, non-rendering context.
    private func rebuildEventsByDay() {
        let days = daysInMonth
        var map: [String: [EventInstance]] = [:]
        for date in days {
            let key = isoDayString(tzCalendar.startOfDay(for: date))
            // Snapshot each event's recurrence value safely before any UI access
            map[key] = computeEventsFor(date)
        }
        eventsByDay = map
    }

    private func computeEventsFor(_ date: Date) -> [EventInstance] {
        let cal = tzCalendar
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        var results: [EventInstance] = []

        for e in allEvents {
            let rruleSnapshot = e.recurrenceRRule

            if let rrule = rruleSnapshot, let parsed = ParsedRRule.parse(rrule) {
                if let occ = occurrence(for: e, parsed: parsed, onDayStarting: dayStart) {
                    let start = occ.start
                    let end = occ.end ?? start
                    if start < dayEnd && end > dayStart {
                        let stableId = (e.serverId ?? String(describing: e.persistentModelID))
                        let id = stableId + "::" + isoDayString(dayStart)
                        results.append(EventInstance(id: id, event: e, occurrenceStart: start, occurrenceEnd: occ.end))
                    }
                }
                continue
            }

            let start = e.startDate
            let end = e.endDate ?? start
            if start < dayEnd && end > dayStart {
                let stableId = (e.serverId ?? String(describing: e.persistentModelID))
                results.append(EventInstance(id: stableId, event: e, occurrenceStart: start, occurrenceEnd: e.endDate))
            }
        }

        return results.sorted { $0.occurrenceStart < $1.occurrenceStart }
    }

    private func isoDayString(_ date: Date) -> String {
        let cal = tzCalendar
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 1970
        let m = c.month ?? 1
        let d = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }


    private func occurrence(for event: CalendarEvent, parsed: ParsedRRule, onDayStarting dayStart: Date) -> (start: Date, end: Date?)? {
        let cal = tzCalendar

        let baseStart = event.startDate
        let baseEnd = event.endDate
        let baseDay = cal.startOfDay(for: baseStart)

        if dayStart < baseDay { return nil }
        if let until = parsed.until, dayStart > cal.startOfDay(for: until) { return nil }

        // Build occurrence start on this day using the original start time.
        let timeParts = cal.dateComponents([.hour, .minute, .second], from: baseStart)
        let occStart: Date = {
            if event.allDay {
                return cal.startOfDay(for: dayStart)
            }
            var comps = cal.dateComponents([.year, .month, .day], from: dayStart)
            comps.hour = timeParts.hour
            comps.minute = timeParts.minute
            comps.second = timeParts.second ?? 0
            return cal.date(from: comps) ?? dayStart
        }()

        let duration: TimeInterval? = {
            guard let eEnd = baseEnd else { return nil }
            return eEnd.timeIntervalSince(baseStart)
        }()
        let occEnd: Date? = {
            guard let dur = duration else { return nil }
            return occStart.addingTimeInterval(dur)
        }()

        guard matches(parsed: parsed, baseStart: baseStart, dayStart: dayStart) else { return nil }

        // COUNT support (bounded iteration to avoid freezes)
        if let limit = parsed.count {
            if occurrenceIndex(parsed: parsed, baseStart: baseStart, targetDayStart: dayStart) >= limit {
                return nil
            }
        }

        return (occStart, occEnd)
    }

    private func matches(parsed: ParsedRRule, baseStart: Date, dayStart: Date) -> Bool {
        let cal = tzCalendar
        let baseDay = cal.startOfDay(for: baseStart)

        let interval = max(1, parsed.interval)

        switch parsed.freq {
        case .daily:
            let days = cal.dateComponents([.day], from: baseDay, to: dayStart).day ?? 0
            return days % interval == 0

        case .weekly:
            let weeks = cal.dateComponents([.weekOfYear], from: baseDay, to: dayStart).weekOfYear ?? 0
            if weeks % interval != 0 { return false }
            if let by = parsed.byDay, !by.isEmpty {
                let wd = cal.component(.weekday, from: dayStart)
                let code = weekdayCode(from: wd)
                return by.contains(code)
            }
            // Default: same weekday as the start date
            return cal.component(.weekday, from: dayStart) == cal.component(.weekday, from: baseDay)

        case .monthly:
            let months = cal.dateComponents([.month], from: baseDay, to: dayStart).month ?? 0
            if months % interval != 0 { return false }

            if let byMonthDay = parsed.byMonthDay {
                let day = cal.component(.day, from: dayStart)
                return byMonthDay.contains(day)
            }

            if let byDay = parsed.byDay, let pos = parsed.bySetPos {
                return byDay.contains { code in
                    matchesNthWeekdayInMonth(dayStart: dayStart, weekdayCode: code, setPos: pos)
                }
            }

            if let byDay = parsed.byDay, !byDay.isEmpty {
                let weekday = cal.component(.weekday, from: dayStart)
                let code = weekdayCode(from: weekday)
                return byDay.contains(code)
                    && cal.component(.day, from: dayStart) == cal.component(.day, from: baseDay)
            }

            return cal.component(.day, from: dayStart) == cal.component(.day, from: baseDay)

        case .yearly:
            let years = cal.dateComponents([.year], from: baseDay, to: dayStart).year ?? 0
            if years % interval != 0 { return false }

            if let byMonth = parsed.byMonth, let byDay = parsed.byDay, let pos = parsed.bySetPos {
                return byMonth.contains { month in
                    byDay.contains { code in
                        matchesNthWeekdayInYear(dayStart: dayStart, month: month, weekdayCode: code, setPos: pos)
                    }
                }
            }

            if let byMonth = parsed.byMonth {
                let month = cal.component(.month, from: dayStart)
                if !byMonth.contains(month) { return false }
            }

            if let byMonthDay = parsed.byMonthDay {
                let day = cal.component(.day, from: dayStart)
                return byMonthDay.contains(day)
            }

            if let byDay = parsed.byDay, !byDay.isEmpty {
                let weekday = cal.component(.weekday, from: dayStart)
                let code = weekdayCode(from: weekday)
                guard byDay.contains(code) else { return false }
            }

            return cal.component(.month, from: dayStart) == cal.component(.month, from: baseDay)
                && cal.component(.day, from: dayStart) == cal.component(.day, from: baseDay)
        }
    }

    private func matchesNthWeekdayInMonth(dayStart: Date, weekdayCode targetWeekdayCode: String, setPos: Int) -> Bool {
        let cal = tzCalendar
        let weekday = cal.component(.weekday, from: dayStart)
        guard weekdayCode(from: weekday) == targetWeekdayCode else { return false }
        guard setPos != 0 else { return false }
        guard let monthInterval = cal.dateInterval(of: .month, for: dayStart) else { return false }

        var matchingDays: [Date] = []
        var cursor = cal.startOfDay(for: monthInterval.start)
        let monthEnd = monthInterval.end

        while cursor < monthEnd {
            let cursorWeekday = cal.component(.weekday, from: cursor)
            if weekdayCode(from: cursorWeekday) == targetWeekdayCode {
                matchingDays.append(cursor)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        guard !matchingDays.isEmpty else { return false }

        let targetIndex: Int
        if setPos > 0 {
            targetIndex = setPos - 1
        } else {
            targetIndex = matchingDays.count + setPos
        }

        guard matchingDays.indices.contains(targetIndex) else { return false }
        return cal.isDate(matchingDays[targetIndex], inSameDayAs: dayStart)
    }

    private func matchesNthWeekdayInYear(dayStart: Date, month: Int, weekdayCode: String, setPos: Int) -> Bool {
        let cal = tzCalendar
        let dayMonth = cal.component(.month, from: dayStart)
        guard dayMonth == month else { return false }
        return matchesNthWeekdayInMonth(dayStart: dayStart, weekdayCode: weekdayCode, setPos: setPos)
    }


    private func occurrenceIndex(parsed: ParsedRRule, baseStart: Date, targetDayStart: Date) -> Int {
        // Returns 0 for the first occurrence day (base day), 1 for the next, etc.
        // For weekly with BYDAY, we count matched days. Bounded to prevent runaway work.
        let cal = tzCalendar
        let baseDay = cal.startOfDay(for: baseStart)
        if targetDayStart <= baseDay { return 0 }

        // Fast paths for simple cases
        if parsed.freq == .daily {
            let days = cal.dateComponents([.day], from: baseDay, to: targetDayStart).day ?? 0
            return max(0, days / max(1, parsed.interval))
        }

        // Bounded scan for complex patterns (weekly BYDAY)
        var idx = 0
        var cursor = baseDay
        let maxSteps = 5000
        var steps = 0

        while cursor < targetDayStart && steps < maxSteps {
            if matches(parsed: parsed, baseStart: baseStart, dayStart: cursor) {
                idx += 1
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
            steps += 1
        }

        // idx currently counts occurrences *after* base day if base day matched; normalize so base day is index 0
        // If the base day itself is an occurrence (it always should be), ensure that.
        return max(0, idx)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LystariaBackground()
                
                ScrollView {
                    VStack(spacing: 0) {
                        calendarHeader
                        
                        LazyVStack(spacing: 0) {
                            ForEach(daysInMonth, id: \.self) { date in
                                // FIX 4: Read from the pre-computed dict instead of
                                // calling eventsFor() (which hits SwiftData) inside body.
                                let key = isoDayString(tzCalendar.startOfDay(for: date))
                                dayRow(date, events: eventsByDay[key] ?? [])
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                    }
                }
                .scrollIndicators(.hidden)
            }
            // FIX 5: Build the map on appear and whenever allEvents or the month changes.
            .onAppear {
                rebuildEventsByDay()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onboarding.start(page: OnboardingPages.calendar)
                }
            }
            .onChange(of: allEvents) { _, _ in
                rebuildEventsByDay()
            }
            .onChange(of: currentMonth) { _, _ in
                rebuildEventsByDay()
            }
            .sheet(item: $sheetConfig, onDismiss: {
                // Ensure UI refreshes after add/edit.
                rebuildEventsByDay()
            }) { config in
                EventSheet(
                    selectedDate: config.selectedDate,
                    editingEvent: config.editingEvent
                )
                .preferredColorScheme(.dark)
            }
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                OnboardingOverlay(anchors: anchors)
                    .environmentObject(onboarding)
            }
        }
    }

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Button { prevMonth() } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white)
                            .opacity(1)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    GradientTitle(text: monthName, font: .system(size: 24, weight: .bold))
                    
                    Button { nextMonth() } label: {
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white)
                            .opacity(1)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                NavigationLink {
                    SettingsView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)
                        
                        Image("settingsfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .onboardingTarget("calendarSettingsIcon")
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Day Row

    // FIX 6: Accept pre-computed events as a parameter instead of re-computing here.
    private func dayRow(_ date: Date, events: [EventInstance]) -> some View {
        let today = tzCalendar.isDateInToday(date)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text("\(tzCalendar.component(.day, from: date))")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(today ? LColors.accent : LColors.textPrimary)

                    Text({ () -> String in
                        let df = DateFormatter()
                        df.timeZone = displayTimeZone
                        df.locale = .current
                        df.setLocalizedDateFormatFromTemplate("EEE")
                        return df.string(from: date).uppercased()
                    }())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                }
                .frame(width: 52)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if events.isEmpty {
                        HStack {
                            Text("No events")
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textSecondary.opacity(0.6))
                            Spacer()
                            Button {
                                sheetConfig = EventSheetConfig(selectedDate: date, editingEvent: nil)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LColors.accent)
                                    .frame(width: 28, height: 28)
                                    .background(LColors.accent.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(events) { instance in
                            eventCard(instance)
                        }

                        Button {
                            sheetConfig = EventSheetConfig(selectedDate: date, editingEvent: nil)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11))
                                Text("Add event").font(.system(size: 13))
                            }
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
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

    // MARK: - Event Card

    private func eventCard(_ instance: EventInstance) -> some View {
        let event = instance.event
        let eventColor = Color(ly_hex: event.displayColor)
        let hasReminder = (event.reminderServerId != nil)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if hasReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LColors.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if event.allDay {
                        Text("All day")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LColors.success.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)

                if let desc = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                if !event.allDay {
                    Text(formatEventTime(event, occurrenceStart: instance.occurrenceStart, occurrenceEnd: instance.occurrenceEnd))
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }

                // FIX 7: Snapshot recurrence before using in view expression.
                // The original `event.recurrence != nil` check inside a ViewBuilder
                // was one of the direct triggers of the faulted-object SIGABRT.
                let recurrenceSnapshot = event.recurrenceRRule
                let parsedRecurrence = recurrenceSnapshot.flatMap { ParsedRRule.parse($0) }
                if instance.occurrenceEnd != nil || recurrenceSnapshot != nil {
                    let hasRecurrence = recurrenceSnapshot != nil
                    if hasRecurrence {
                        HStack(spacing: 6) {
                            Text("Repeats")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())

                            if let parsedRecurrence, parsedRecurrence.freq == .weekly {
                                Text("\(max(1, parsedRecurrence.interval))/W")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(LColors.accent.opacity(0.16))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                if let loc = event.location, !loc.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin").font(.system(size: 10))
                        Text(loc)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(LColors.textSecondary)
                }
            }
            .padding(.leading, 10)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    sheetConfig = EventSheetConfig(selectedDate: instance.occurrenceStart, editingEvent: event)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(LColors.textPrimary.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    if let rid = event.reminderServerId {
                        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
                        deleteReminder(withServerId: rid)
                        event.reminderServerId = nil
                    }
                    modelContext.delete(event)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(LColors.danger.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(LColors.danger.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(LColors.glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
    }

    private func deleteReminder(withServerId id: String) {
        // FIX 8: Use a predicate instead of fetching all reminders.
        // The original fetched every single LystariaReminder on the main thread
        // during a SwiftUI delete action, which could deadlock the model context.
        let targetId = id
        let descriptor = FetchDescriptor<LystariaReminder>(
            predicate: #Predicate { $0.serverId == targetId }
        )
        if let match = try? modelContext.fetch(descriptor).first {
            modelContext.delete(match)
        }
    }

    private func formatEventTime(_ event: CalendarEvent, occurrenceStart: Date, occurrenceEnd: Date?) -> String {
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("h:mm a")
        let start = df.string(from: occurrenceStart)
        if let end = occurrenceEnd {
            return "\(start) – \(df.string(from: end))"
        }
        return start
    }

    private func prevMonth() {
        currentMonth = tzCalendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    private func nextMonth() {
        currentMonth = tzCalendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}

// MARK: - Event Sheet (New/Edit)

struct EventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let editingEvent: CalendarEvent?

    @State private var title = ""
    @State private var allDay = false

    @State private var startDay = Date()
    @State private var startTime = Date()
    @State private var endDay = Date()
    @State private var endTime = Date()

    @State private var location = ""
    @State private var eventDescription = ""
    @State private var eventColor = "#5b8def"
    @State private var eventColorUI: Color = Color(ly_hex: "#5b8def")

    @State private var reminderEnabled = false
    @State private var minutesBefore: Int = 0

    @State private var recurrenceEnabled: Bool = false
    @State private var recurrenceFreq: RecurrenceFrequency = .weekly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceWeekdays: Set<Int> = []

    private enum MonthlyRecurrenceMode: String, CaseIterable, Identifiable {
        case sameDay
        case specificMonthDays
        case nthWeekday
        var id: String { rawValue }
    }

    private enum YearlyRecurrenceMode: String, CaseIterable, Identifiable {
        case sameDate
        case specificMonthDay
        case nthWeekdayOfMonth
        var id: String { rawValue }
    }

    private enum RecurrenceOrdinal: Int, CaseIterable, Identifiable {
        case first = 1
        case second = 2
        case third = 3
        case fourth = 4
        case last = -1
        case secondLast = -2
        case thirdLast = -3

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .first: return "First"
            case .second: return "Second"
            case .third: return "Third"
            case .fourth: return "Fourth"
            case .last: return "Last"
            case .secondLast: return "Second to Last"
            case .thirdLast: return "Third to Last"
            }
        }
    }

    @State private var monthlyRecurrenceMode: MonthlyRecurrenceMode = .sameDay
    @State private var monthlySpecificDaysText: String = ""
    @State private var monthlyOrdinal: RecurrenceOrdinal = .first
    @State private var monthlyNthWeekday: Int = 2

    @State private var yearlyRecurrenceMode: YearlyRecurrenceMode = .sameDate
    @State private var yearlyMonth: Int = 1
    @State private var yearlyDay: Int = 1
    @State private var yearlyOrdinal: RecurrenceOrdinal = .first
    @State private var yearlyNthWeekday: Int = 2
    @State private var yearlyNthMonth: Int = 1

    private enum RecurrenceEndMode: String, CaseIterable, Identifiable {
        case never
        case afterCount
        case onDate
        var id: String { rawValue }
    }

    @State private var recurrenceEndMode: RecurrenceEndMode = .never
    @State private var recurrenceCount: Int = 10
    @State private var recurrenceUntilDay: Date = Date()

    private let colorOptions = ["#5b8def","#a855f7","#ec4899","#4caf50","#ff9800","#f44336","#00dbff"]

    private var weekdayOptions: [(Int, String)] {
        [(1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday"), (6, "Friday"), (7, "Saturday")]
    }

    private var monthOptions: [(Int, String)] {
        [(1, "January"), (2, "February"), (3, "March"), (4, "April"), (5, "May"), (6, "June"), (7, "July"), (8, "August"), (9, "September"), (10, "October"), (11, "November"), (12, "December")]
    }

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }
    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {

                    HStack {
                        GradientTitle(
                            text: editingEvent != nil ? "Edit Event" : "New Event",
                            font: .title2.bold()
                        )
                        Spacer()

                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

                    CalendarLabeledGlassField(label: "TITLE") {
                        TextField("Event title", text: $title)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                    }

                    GlassCard(padding: 16) {
                        VStack(spacing: 12) {
                            Toggle("All Day", isOn: $allDay)
                                .foregroundStyle(LColors.textPrimary)
                                .tint(LColors.accent)

                            if allDay {
                                #if os(macOS)
                                DateStepperRow(label: "Day", dateTime: $startDay)
                                #else
                                CalendarControlRow(label: "Day") {
                                    DatePicker("", selection: $startDay, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .tint(LColors.accent)
                                }
                                #endif
                            } else {
                                #if os(macOS)
                                DateStepperRow(label: "Start Day", dateTime: $startDay)
                                TimeEntryRow(label: "Start Time", dateTime: $startTime)
                                DateStepperRow(label: "End Day", dateTime: $endDay)
                                TimeEntryRow(label: "End Time", dateTime: $endTime)
                                #else
                                CalendarControlRow(label: "Start") {
                                    DatePicker("", selection: Binding(
                                        get: { CalendarCompute.merge(day: startDay, time: startTime) },
                                        set: { newValue in
                                            startDay = newValue
                                            startTime = newValue
                                        }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                                }

                                CalendarControlRow(label: "End") {
                                    DatePicker("", selection: Binding(
                                        get: { CalendarCompute.merge(day: endDay, time: endTime) },
                                        set: { newValue in
                                            endDay = newValue
                                            endTime = newValue
                                        }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(LColors.accent)
                                }
                                #endif
                            }
                        }
                    }

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Event Reminder", isOn: $reminderEnabled)
                                .foregroundStyle(LColors.textPrimary)
                                .tint(LColors.accent)

                            if reminderEnabled {
                                CalendarControlRow(label: "Remind") {
                                    Stepper(value: $minutesBefore, in: 0...240, step: 5) {
                                        Text(minutesBefore == 0 ? "At time" : "\(minutesBefore) min before")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(LColors.textPrimary)
                                    }
                                    .labelsHidden()
                                }
                            } else {
                                Text("Turn on to add this event into Reminders.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Repeat", isOn: $recurrenceEnabled)
                                .foregroundStyle(LColors.textPrimary)
                                .tint(LColors.accent)

                            if recurrenceEnabled {
                                CalendarControlRow(label: "Frequency") {
                                    Picker("", selection: $recurrenceFreq) {
                                        Text("Daily").tag(RecurrenceFrequency.daily)
                                        Text("Weekly").tag(RecurrenceFrequency.weekly)
                                        Text("Monthly").tag(RecurrenceFrequency.monthly)
                                        Text("Yearly").tag(RecurrenceFrequency.yearly)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }

                                if recurrenceFreq == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("WEEKLY INTERVAL")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.5)

                                        HStack(spacing: 10) {
                                            Button {
                                                recurrenceInterval = max(1, recurrenceInterval - 1)
                                            } label: {
                                                Image(systemName: "minus")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 34, height: 34)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)

                                            Text("Every \(recurrenceInterval) \(recurrenceInterval == 1 ? "week" : "weeks")")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(LColors.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                                )

                                            Button {
                                                recurrenceInterval = min(52, recurrenceInterval + 1)
                                            } label: {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 34, height: 34)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    CalendarControlRow(label: "Interval") {
                                        Stepper(value: $recurrenceInterval, in: 1...52, step: 1) {
                                            Text("Every \(recurrenceInterval) \(recurrenceInterval == 1 ? unitLabel(for: recurrenceFreq) : unitLabel(for: recurrenceFreq) + "s")")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(LColors.textPrimary)
                                        }
                                        .labelsHidden()
                                    }
                                }

                                if recurrenceFreq == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("DAYS")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.5)

                                        WeekdayPicker(selected: $recurrenceWeekdays)
                                    }
                                }

                                if recurrenceFreq == .monthly {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("MONTHLY PATTERN")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.5)

                                        CalendarControlRow(label: "Mode") {
                                            Picker("", selection: $monthlyRecurrenceMode) {
                                                Text("Same day each month").tag(MonthlyRecurrenceMode.sameDay)
                                                Text("Specific day(s) of month").tag(MonthlyRecurrenceMode.specificMonthDays)
                                                Text("Nth weekday of month").tag(MonthlyRecurrenceMode.nthWeekday)
                                            }
                                            .labelsHidden()
                                            .pickerStyle(.menu)
                                        }

                                        if monthlyRecurrenceMode == .specificMonthDays {
                                            CalendarLabeledGlassField(label: "MONTH DAYS") {
                                                TextField("Example: 1, 15, 28", text: $monthlySpecificDaysText)
                                                    .textFieldStyle(.plain)
                                                    .foregroundStyle(LColors.textPrimary)
                                            }
                                        }

                                        if monthlyRecurrenceMode == .nthWeekday {
                                            CalendarControlRow(label: "Ordinal") {
                                                Picker("", selection: $monthlyOrdinal) {
                                                    ForEach(RecurrenceOrdinal.allCases) { ordinal in
                                                        Text(ordinal.label).tag(ordinal)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }

                                            CalendarControlRow(label: "Weekday") {
                                                Picker("", selection: $monthlyNthWeekday) {
                                                    ForEach(weekdayOptions, id: \.0) { value, label in
                                                        Text(label).tag(value)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }
                                        }
                                    }
                                }

                                if recurrenceFreq == .yearly {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("YEARLY PATTERN")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.5)

                                        CalendarControlRow(label: "Mode") {
                                            Picker("", selection: $yearlyRecurrenceMode) {
                                                Text("Same date each year").tag(YearlyRecurrenceMode.sameDate)
                                                Text("Specific month and day").tag(YearlyRecurrenceMode.specificMonthDay)
                                                Text("Nth weekday of month").tag(YearlyRecurrenceMode.nthWeekdayOfMonth)
                                            }
                                            .labelsHidden()
                                            .pickerStyle(.menu)
                                        }

                                        if yearlyRecurrenceMode == .specificMonthDay {
                                            CalendarControlRow(label: "Month") {
                                                Picker("", selection: $yearlyMonth) {
                                                    ForEach(monthOptions, id: \.0) { value, label in
                                                        Text(label).tag(value)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }

                                            CalendarControlRow(label: "Day") {
                                                Stepper(value: $yearlyDay, in: 1...31, step: 1) {
                                                    Text("Day \(yearlyDay)")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(LColors.textPrimary)
                                                }
                                                .labelsHidden()
                                            }
                                        }

                                        if yearlyRecurrenceMode == .nthWeekdayOfMonth {
                                            CalendarControlRow(label: "Ordinal") {
                                                Picker("", selection: $yearlyOrdinal) {
                                                    ForEach(RecurrenceOrdinal.allCases) { ordinal in
                                                        Text(ordinal.label).tag(ordinal)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }

                                            CalendarControlRow(label: "Weekday") {
                                                Picker("", selection: $yearlyNthWeekday) {
                                                    ForEach(weekdayOptions, id: \.0) { value, label in
                                                        Text(label).tag(value)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }

                                            CalendarControlRow(label: "Month") {
                                                Picker("", selection: $yearlyNthMonth) {
                                                    ForEach(monthOptions, id: \.0) { value, label in
                                                        Text(label).tag(value)
                                                    }
                                                }
                                                .labelsHidden()
                                                .pickerStyle(.menu)
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("END")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.5)

                                    CalendarControlRow(label: "Ends") {
                                        Picker("", selection: $recurrenceEndMode) {
                                            Text("Never").tag(RecurrenceEndMode.never)
                                            Text("After").tag(RecurrenceEndMode.afterCount)
                                            Text("On date").tag(RecurrenceEndMode.onDate)
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }

                                    if recurrenceEndMode == .afterCount {
                                        CalendarControlRow(label: "Count") {
                                            Stepper(value: $recurrenceCount, in: 1...999, step: 1) {
                                                Text("\(recurrenceCount) times")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(LColors.textPrimary)
                                            }
                                            .labelsHidden()
                                        }
                                    }

                                    if recurrenceEndMode == .onDate {
                                        CalendarControlRow(label: "Until") {
                                            DatePicker("", selection: $recurrenceUntilDay, displayedComponents: .date)
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                .tint(LColors.accent)
                                        }
                                    }
                                }

                            } else {
                                Text("Turn on to make this a recurring event.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }

                    CalendarLabeledGlassField(label: "LOCATION") {
                        TextField("Add location (optional)", text: $location)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        GlassTextEditor(
                            placeholder: "Event details (optional)",
                            text: $eventDescription,
                            minHeight: 80
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("COLOR")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        ColorPicker("", selection: $eventColorUI, supportsOpacity: false)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: eventColorUI) { _, newColor in
                                eventColor = newColor.toHexString()
                            }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 120)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { loadInitialState() }
        .safeAreaInset(edge: .bottom) {
            GlassCard(padding: 14) {
                Button { save() } label: {
                    Text(editingEvent != nil ? "Save Changes" : "Save Event")
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
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.bottom, 10)
        }
    }

    private func loadInitialState() {
        if let e = editingEvent {
            title = e.title
            allDay = e.allDay
            location = e.location ?? ""
            eventDescription = e.eventDescription ?? ""
            eventColor = e.color ?? "#5b8def"
            eventColorUI = Color(ly_hex: eventColor)

            startDay = e.startDate
            startTime = e.startDate

            if let end = e.endDate {
                endDay = end
                endTime = end
            } else {
                let end = tzCalendar.date(byAdding: .hour, value: 1, to: e.startDate) ?? e.startDate
                endDay = end
                endTime = end
            }

            if let rid = e.reminderServerId, let r = findReminder(serverId: rid) {
                reminderEnabled = true
                // Compute minutes-before from the persisted reminder fire time.
                // (Positive means reminder fires before the event start.)
                let diffMinutes = Int((e.startDate.timeIntervalSince(r.nextRunAt) / 60.0).rounded())
                minutesBefore = max(0, min(240, diffMinutes))
            } else {
                reminderEnabled = false
                minutesBefore = 0
            }

            let rruleSnapshot = e.recurrenceRRule
            if let rrule = rruleSnapshot, let parsed = ParsedRRule.parse(rrule) {
                recurrenceEnabled = true
                switch parsed.freq {
                case .daily: recurrenceFreq = .daily
                case .weekly: recurrenceFreq = .weekly
                case .monthly: recurrenceFreq = .monthly
                case .yearly: recurrenceFreq = .yearly
                }
                recurrenceInterval = max(1, parsed.interval)

                let map: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]

                if parsed.freq == .weekly, let by = parsed.byDay {
                    recurrenceWeekdays = Set(by.compactMap { map[$0] })
                } else {
                    recurrenceWeekdays = []
                }

                if parsed.freq == .monthly {
                    if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                        monthlyRecurrenceMode = .specificMonthDays
                        monthlySpecificDaysText = byMonthDay.map(String.init).joined(separator: ", ")
                    } else if let byDay = parsed.byDay,
                              let pos = parsed.bySetPos,
                              let firstCode = byDay.first,
                              let weekday = map[firstCode],
                              let ordinal = RecurrenceOrdinal(rawValue: pos) {
                        monthlyRecurrenceMode = .nthWeekday
                        monthlyOrdinal = ordinal
                        monthlyNthWeekday = weekday
                        monthlySpecificDaysText = ""
                    } else {
                        monthlyRecurrenceMode = .sameDay
                        monthlySpecificDaysText = ""
                    }
                } else {
                    monthlyRecurrenceMode = .sameDay
                    monthlySpecificDaysText = ""
                }

                if parsed.freq == .yearly {
                    if let byMonth = parsed.byMonth,
                       let byDay = parsed.byDay,
                       let pos = parsed.bySetPos,
                       let month = byMonth.first,
                       let firstCode = byDay.first,
                       let weekday = map[firstCode],
                       let ordinal = RecurrenceOrdinal(rawValue: pos) {
                        yearlyRecurrenceMode = .nthWeekdayOfMonth
                        yearlyNthMonth = month
                        yearlyNthWeekday = weekday
                        yearlyOrdinal = ordinal
                        yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                        yearlyDay = tzCalendar.component(.day, from: e.startDate)
                    } else if let byMonth = parsed.byMonth, let byMonthDay = parsed.byMonthDay,
                              let month = byMonth.first, let day = byMonthDay.first {
                        yearlyRecurrenceMode = .specificMonthDay
                        yearlyMonth = month
                        yearlyDay = day
                        yearlyNthMonth = month
                        yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                    } else {
                        yearlyRecurrenceMode = .sameDate
                        yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                        yearlyDay = tzCalendar.component(.day, from: e.startDate)
                        yearlyNthMonth = yearlyMonth
                        yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                    }
                } else {
                    yearlyRecurrenceMode = .sameDate
                    yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                    yearlyDay = tzCalendar.component(.day, from: e.startDate)
                    yearlyNthMonth = yearlyMonth
                    yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                }

                if let c = parsed.count {
                    recurrenceEndMode = .afterCount
                    recurrenceCount = max(1, c)
                } else if let u = parsed.until {
                    recurrenceEndMode = .onDate
                    recurrenceUntilDay = u
                } else {
                    recurrenceEndMode = .never
                    recurrenceCount = 10
                    recurrenceUntilDay = e.startDate
                }
            } else {
                recurrenceEnabled = false
                recurrenceFreq = .weekly
                recurrenceInterval = 1
                recurrenceWeekdays = []
                monthlyRecurrenceMode = .sameDay
                monthlySpecificDaysText = ""
                monthlyOrdinal = .first
                monthlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                yearlyRecurrenceMode = .sameDate
                yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                yearlyDay = tzCalendar.component(.day, from: e.startDate)
                yearlyOrdinal = .first
                yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                yearlyNthMonth = yearlyMonth
                recurrenceEndMode = .never
                recurrenceCount = 10
                recurrenceUntilDay = e.startDate
            }

        } else {
            title = ""
            allDay = false
            location = ""
            eventDescription = ""
            eventColor = "#5b8def"
            eventColorUI = Color(ly_hex: eventColor)

            startDay = selectedDate
            startTime = selectedDate

            let end = tzCalendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
            endDay = end
            endTime = end

            reminderEnabled = false
            minutesBefore = 0

            recurrenceEnabled = false
            recurrenceFreq = .weekly
            recurrenceInterval = 1
            recurrenceWeekdays = []
            monthlyRecurrenceMode = .sameDay
            monthlySpecificDaysText = ""
            monthlyOrdinal = .first
            monthlyNthWeekday = tzCalendar.component(.weekday, from: selectedDate)
            yearlyRecurrenceMode = .sameDate
            yearlyMonth = tzCalendar.component(.month, from: selectedDate)
            yearlyDay = tzCalendar.component(.day, from: selectedDate)
            yearlyOrdinal = .first
            yearlyNthWeekday = tzCalendar.component(.weekday, from: selectedDate)
            yearlyNthMonth = yearlyMonth
            recurrenceEndMode = .never
            recurrenceCount = 10
            recurrenceUntilDay = selectedDate
        }
    }

    private func findReminder(serverId: String) -> LystariaReminder? {
        // FIX 10: Use predicate here too, consistent with deleteReminder fix.
        let targetId = serverId
        let descriptor = FetchDescriptor<LystariaReminder>(
            predicate: #Predicate { $0.serverId == targetId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func save() {
        // ── STEP 1: Capture ALL values from @State into plain Swift locals.
        // We do this BEFORE touching any SwiftData model object.
        // The SIGABRT was caused by reading SwiftData @PersistedProperty getters
        // (like .recurrence, .title, .allDay etc.) after or during a mutation —
        // the observation registrar faults mid-mutation. Solution: never read the
        // model back. Build everything from @State, write-only to the model.
        let cleanTitle      = titleTrimmed
        let cleanLocation   = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc       = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAllDay        = allDay
        let chosenColor     = eventColorUI.toHexString()
        let isReminderOn    = reminderEnabled
        let minsBefore      = minutesBefore

        let start = isAllDay
            ? tzCalendar.startOfDay(for: startDay)
            : CalendarCompute.merge(day: startDay, time: startTime)

        let end: Date? = {
            if isAllDay { return nil }
            let merged = CalendarCompute.merge(day: endDay, time: endTime)
            return merged <= start
                ? tzCalendar.date(byAdding: .hour, value: 1, to: start)
                : merged
        }()

        let resolvedRRule: String? = {
            guard recurrenceEnabled else { return nil }

            var components: [String] = []

            let freqStr: String = {
                switch recurrenceFreq {
                case .daily: return "DAILY"
                case .weekly: return "WEEKLY"
                case .monthly: return "MONTHLY"
                case .yearly: return "YEARLY"
                }
            }()
            components.append("FREQ=\(freqStr)")

            components.append("INTERVAL=\(max(1, recurrenceInterval))")

            if recurrenceFreq == .weekly {
                // Require at least one day; default to the start day weekday.
                var days = Array(recurrenceWeekdays)
                if days.isEmpty {
                    let wd = tzCalendar.component(.weekday, from: start)
                    days = [wd]
                }
                let codes = days.sorted().map { weekdayCode(from: $0) }
                components.append("BYDAY=\(codes.joined(separator: ","))")
            }

            if recurrenceFreq == .monthly {
                switch monthlyRecurrenceMode {
                case .sameDay:
                    break
                case .specificMonthDays:
                    let parsedDays = monthlySpecificDaysText
                        .split(separator: ",")
                        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        .filter { (1...31).contains($0) }
                    let uniqueDays = Array(Set(parsedDays)).sorted()
                    if !uniqueDays.isEmpty {
                        components.append("BYMONTHDAY=\(uniqueDays.map(String.init).joined(separator: ","))")
                    }
                case .nthWeekday:
                    components.append("BYDAY=\(weekdayCode(from: monthlyNthWeekday))")
                    components.append("BYSETPOS=\(monthlyOrdinal.rawValue)")
                }
            }

            if recurrenceFreq == .yearly {
                switch yearlyRecurrenceMode {
                case .sameDate:
                    break
                case .specificMonthDay:
                    let clampedDay = min(max(yearlyDay, 1), 31)
                    components.append("BYMONTH=\(yearlyMonth)")
                    components.append("BYMONTHDAY=\(clampedDay)")
                case .nthWeekdayOfMonth:
                    components.append("BYMONTH=\(yearlyNthMonth)")
                    components.append("BYDAY=\(weekdayCode(from: yearlyNthWeekday))")
                    components.append("BYSETPOS=\(yearlyOrdinal.rawValue)")
                }
            }

            switch recurrenceEndMode {
            case .never:
                break
            case .afterCount:
                components.append("COUNT=\(max(1, recurrenceCount))")
            case .onDate:
                // Use date-only UNTIL (YYYYMMDD) for portability.
                let day = tzCalendar.startOfDay(for: recurrenceUntilDay)
                let c = tzCalendar.dateComponents([.year, .month, .day], from: day)
                let y = c.year ?? 1970
                let m = c.month ?? 1
                let d = c.day ?? 1
                components.append(String(format: "UNTIL=%04d%02d%02d", y, m, d))
            }

            return components.joined(separator: ";")
        }()

        let resolvedRuleForNotifications: RecurrenceRule? = {
            guard let r = resolvedRRule, let parsed = ParsedRRule.parse(r) else { return nil }
            let freq: RecurrenceFrequency = {
                switch parsed.freq {
                case .daily: return .daily
                case .weekly: return .weekly
                case .monthly: return .monthly
                case .yearly: return .yearly
                }
            }()
            let byWeekday: [Int]? = {
                guard let by = parsed.byDay else { return nil }
                let map: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
                let arr = by.compactMap { map[$0] }.sorted()
                return arr.isEmpty ? nil : arr
            }()
            return RecurrenceRule(freq: freq, interval: max(1, parsed.interval), byWeekday: byWeekday)
        }()

        let resolvedRunAt: Date? = {
            guard isReminderOn else { return nil }
            if isAllDay {
                return CalendarCompute.setTimeKeepingDay(day: start, hour: 9, minute: 0)
            }
            return tzCalendar.date(byAdding: .minute, value: -minsBefore, to: start) ?? start
        }()

        // ── STEP 2: Read the ONE thing we need from the existing model object
        // before we mutate anything — the existing reminder server ID.
        let existingReminderId: String? = editingEvent?.reminderServerId

        // ── STEP 3: Write-only to the model. Zero reads after this point.
        let targetEvent: CalendarEvent
        if let e = editingEvent {
            e.title                = cleanTitle
            e.allDay               = isAllDay
            e.startDate            = start
            e.endDate              = end
            e.location             = cleanLocation.isEmpty ? nil : cleanLocation
            e.eventDescription     = cleanDesc.isEmpty ? nil : cleanDesc
            e.color                = chosenColor
            e.updatedAt            = Date()
            e.needsSync            = true
            e.recurrenceRRule      = resolvedRRule
            e.timeZoneId           = NotificationManager.shared.effectiveTimezoneID
            targetEvent = e
        } else {
            let e = CalendarEvent(
                title: cleanTitle,
                startDate: start,
                endDate: end,
                allDay: isAllDay,
                eventDescription: cleanDesc.isEmpty ? nil : cleanDesc,
                color: chosenColor,
                meetingUrl: nil,
                location: cleanLocation.isEmpty ? nil : cleanLocation,
                serverId: nil
            )
            modelContext.insert(e)
            e.recurrenceRRule = resolvedRRule
            e.timeZoneId = NotificationManager.shared.effectiveTimezoneID
            targetEvent = e
        }

        // ── STEP 4: Schedule notifications using only plain-Swift values.
        // applyReminderLink receives everything it needs as value types —
        // it only WRITES to targetEvent (reminderServerId), never reads it.
        applyReminderLink(
            event: targetEvent,
            existingReminderId: existingReminderId,
            title: cleanTitle,
            desc: cleanDesc.isEmpty ? nil : cleanDesc,
            location: cleanLocation.isEmpty ? nil : cleanLocation,
            startDate: start,
            isAllDay: isAllDay,
            resolvedRunAt: resolvedRunAt,
            resolvedRule: resolvedRuleForNotifications,
            resolvedRRule: resolvedRRule,
            resolvedExceptions: []
        )

        // ── STEP 5: Persist
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save event: \(error)")
        }

        dismiss()
    }

    private func isoDayString(_ date: Date) -> String {
        let day = tzCalendar.startOfDay(for: date)
        let c = tzCalendar.dateComponents([.year, .month, .day], from: day)
        let y = c.year ?? 1970
        let m = c.month ?? 1
        let d = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func unitLabel(for freq: RecurrenceFrequency) -> String {
        switch freq {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    // All string/date/rule params come from @State (plain Swift values).
    // The only thing we write to `event` is reminderServerId — never read.
    // existingReminderId is captured from the model BEFORE any mutations in save().
    private func applyReminderLink(
        event: CalendarEvent,
        existingReminderId: String?,
        title: String,
        desc: String?,
        location: String?,
        startDate: Date,
        isAllDay: Bool,
        resolvedRunAt: Date?,
        resolvedRule: RecurrenceRule?,
        resolvedRRule: String?,
        resolvedExceptions: [String]
    ) {
        // Build a ReminderSchedule that matches the event recurrence so RemindersView
        // can show the correct badge and "Done" can advance to the next occurrence.
        func hhmm(_ date: Date) -> String {
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }

        func weekdaysFromByDay(_ byDay: [String]?) -> [Int]? {
            guard let byDay, !byDay.isEmpty else { return nil }
            let map: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
            let vals = byDay.compactMap { map[$0.uppercased()] }
            return vals.isEmpty ? nil : Array(Set(vals)).sorted()
        }

        func reminderScheduleForEvent(
            runAt: Date,
            startDate: Date,
            resolvedRule: RecurrenceRule?,
            resolvedRRule: String?
        ) -> ReminderSchedule {
            let time = hhmm(runAt)

            // Prefer RRULE parsing (more complete: BYDAY, INTERVAL, COUNT/UNTIL)
            if let rr = resolvedRRule, let parsed = ParsedRRule.parse(rr) {
                let interval = max(1, parsed.interval)
                switch parsed.freq {
                case .daily:
                    return ReminderSchedule(kind: .daily, timeOfDay: time, interval: interval, daysOfWeek: nil)
                case .weekly:
                    let fallbackWd = CalendarCompute.tzCalendar.component(.weekday, from: startDate)
                    let days = weekdaysFromByDay(parsed.byDay) ?? [fallbackWd]
                    return ReminderSchedule(kind: .weekly, timeOfDay: time, interval: interval, daysOfWeek: days)
                case .monthly:
                    return ReminderSchedule(kind: .monthly, timeOfDay: time, interval: interval, daysOfWeek: nil)
                case .yearly:
                    return ReminderSchedule(kind: .yearly, timeOfDay: time, interval: interval, daysOfWeek: nil)
                }
            }

            // Fallback: map from the simplified RecurrenceRule used for notification scheduling
            if let rule = resolvedRule {
                let interval = max(1, rule.interval)
                switch rule.freq {
                case .daily:
                    return ReminderSchedule(kind: .daily, timeOfDay: time, interval: interval, daysOfWeek: nil)
                case .weekly:
                    let fallbackWd = CalendarCompute.tzCalendar.component(.weekday, from: startDate)
                    let days = (rule.byWeekday?.isEmpty == false) ? rule.byWeekday! : [fallbackWd]
                    return ReminderSchedule(kind: .weekly, timeOfDay: time, interval: interval, daysOfWeek: days)
                case .monthly:
                    return ReminderSchedule(kind: .monthly, timeOfDay: time, interval: interval, daysOfWeek: nil)
                case .yearly:
                    return ReminderSchedule(kind: .yearly, timeOfDay: time, interval: interval, daysOfWeek: nil)
                }
            }

            // One-time
            return .once
        }

        guard let runAt = resolvedRunAt else {
            // Reminder is disabled — cancel & delete if one existed
            if let rid = existingReminderId {
                NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
                if let r = findReminder(serverId: rid) {
                    modelContext.delete(r)
                }
                event.reminderServerId = nil
                event.updatedAt = Date()
                event.needsSync = true
            }
            return
        }

        // Determine or create the reminder server ID
        let rid: String = existingReminderId ?? {
            let new = UUID().uuidString
            event.reminderServerId = new  // only write, never read back
            return new
        }()
        if existingReminderId == nil {
            event.reminderServerId = rid
        }

        // Always cancel before re-scheduling so updates take effect.
        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)

        // Build body text purely from passed-in plain values
        let bodyText: String = {
            var parts: [String] = []
            if let loc = location, !loc.isEmpty { parts.append(loc) }
            if let d = desc, !d.isEmpty { parts.append(d) }
            let extra = parts.joined(separator: "\n")
            if isAllDay {
                return extra.isEmpty ? "All-day event" : "All-day event — \(extra)"
            }
            return extra.isEmpty ? title : extra
        }()

        // Upsert the LystariaReminder model
        let computedSchedule = reminderScheduleForEvent(
            runAt: runAt,
            startDate: startDate,
            resolvedRule: resolvedRule,
            resolvedRRule: resolvedRRule
        )

        if let r = findReminder(serverId: rid) {
            r.title = title
            r.details = desc
            r.nextRunAt = runAt
            r.status = .scheduled
            r.schedule = computedSchedule
            r.acknowledgedAt = nil
            r.timezone = NotificationManager.shared.effectiveTimezoneID
            r.linkedKindRaw = "event"
            r.serverId = rid
            r.markDirty()
        } else {
            let r = LystariaReminder(
                title: title,
                status: .scheduled,
                nextRunAt: runAt,
                schedule: computedSchedule,
                timezone: NotificationManager.shared.effectiveTimezoneID,
                serverId: rid
            )
            modelContext.insert(r)
            r.details = desc
            r.linkedKindRaw = "event"
            r.markDirty()
        }

        NotificationManager.shared.requestPermissionIfNeeded()
        debugDumpPendingNotifications(tag: "after requestPermission", filterId: rid)

        if let rule = resolvedRule {
            NotificationManager.shared.scheduleRecurringCalendarEvent(
                id: rid,
                title: title,
                body: bodyText,
                // Use the reminder fire time as the recurrence base so "X min before" actually fires at that time.
                startDate: runAt,
                allDay: false,
                recurrence: rule,
                exceptions: resolvedExceptions
            )
            debugDumpPendingNotifications(tag: "after schedule recurring", filterId: rid)
        } else {
            NotificationManager.shared.scheduleCalendarEvent(
                id: rid,
                title: title,
                body: bodyText,
                fireDate: runAt
            )
            debugDumpPendingNotifications(tag: "after schedule once", filterId: rid)
        }
    }

    private func buildReminderText(for event: CalendarEvent) -> String {
        let loc: String? = {
            guard let l = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !l.isEmpty else { return nil }
            return l
        }()
        let desc: String? = {
            guard let d = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else { return nil }
            return d
        }()

        switch (loc, desc) {
        case let (l?, d?): return "\(l)\n\(d)"
        case let (l?, nil): return l
        case let (nil, d?): return d
        default: return ""
        }
    }
}



    // MARK: - Notification Debug (prints in Xcode console)
    private func debugDumpPendingNotifications(tag: String, filterId: String? = nil) {
#if os(iOS)
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            print("\n🧪 [Calendar] Notification settings (\(tag)) → status=\(settings.authorizationStatus.rawValue)")
        }

        center.getPendingNotificationRequests { reqs in
            let filtered = filterId == nil ? reqs : reqs.filter { $0.identifier == filterId }
            print("🧪 [Calendar] Pending requests (\(tag)) count=\(reqs.count) filtered=\(filtered.count)")
            for r in filtered {
                let triggerDesc: String = {
                    guard let t = r.trigger else { return "(no trigger)" }
                    if let cal = t as? UNCalendarNotificationTrigger {
                        return "UNCalendarNotificationTrigger repeats=\(cal.repeats) comps=\(String(describing: cal.dateComponents))"
                    }
                    return String(describing: t)
                }()
                print("   • id=\(r.identifier) title=\(r.content.title) trigger=\(triggerDesc)")
            }
        }
#endif
    }

// MARK: - RRULE support (no exception dates)

struct ParsedRRule {
    enum Freq: String {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    let freq: Freq
    let interval: Int
    let byDay: [String]?
    let byMonthDay: [Int]?
    let byMonth: [Int]?
    let bySetPos: Int?
    let count: Int?
    let until: Date?

    static func parse(_ rrule: String) -> ParsedRRule? {
        // Accept either full "RRULE:FREQ=..." or just "FREQ=...".
        let raw = rrule.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = raw.hasPrefix("RRULE:") ? String(raw.dropFirst("RRULE:".count)) : raw
        let parts = body.split(separator: ";").map { String($0) }

        var freq: Freq?
        var interval: Int = 1
        var byDay: [String]? = nil
        var byMonthDay: [Int]? = nil
        var byMonth: [Int]? = nil
        var bySetPos: Int? = nil
        var count: Int? = nil
        var until: Date? = nil

        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1).map { String($0) }
            guard kv.count == 2 else { continue }
            let key = kv[0].uppercased()
            let val = kv[1]

            switch key {
            case "FREQ":
                freq = Freq(rawValue: val.uppercased())
            case "INTERVAL":
                interval = max(1, Int(val) ?? 1)
            case "BYDAY":
                let days = val.split(separator: ",").map { String($0).uppercased() }
                byDay = days.isEmpty ? nil : days
            case "BYMONTHDAY":
                let days = val.split(separator: ",").compactMap { Int($0) }
                byMonthDay = days.isEmpty ? nil : days
            case "BYMONTH":
                let months = val.split(separator: ",").compactMap { Int($0) }
                byMonth = months.isEmpty ? nil : months
            case "BYSETPOS":
                bySetPos = Int(val)
            case "COUNT":
                count = Int(val)
            case "UNTIL":
                // Common forms: YYYYMMDD or YYYYMMDD'T'HHMMSS'Z'
                until = Self.parseUntil(val)
            default:
                continue
            }
        }

        guard let f = freq else { return nil }
        return ParsedRRule(
            freq: f,
            interval: interval,
            byDay: byDay,
            byMonthDay: byMonthDay,
            byMonth: byMonth,
            bySetPos: bySetPos,
            count: count,
            until: until
        )
    }

    private static func parseUntil(_ val: String) -> Date? {
        let v = val.trimmingCharacters(in: .whitespacesAndNewlines)

        // If date-only: treat as end-of-day in the app timezone.
        if v.count == 8 {
            let y = Int(v.prefix(4))
            let m = Int(v.dropFirst(4).prefix(2))
            let d = Int(v.dropFirst(6).prefix(2))
            if let y, let m, let d {
                let cal = CalendarCompute.tzCalendar
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = d
                // End of day 23:59:59
                comps.hour = 23
                comps.minute = 59
                comps.second = 59
                return cal.date(from: comps)
            }
        }

        // Try UTC Zulu form: 20260304T000000Z
        let dfZ: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return df
        }()
        if let d = dfZ.date(from: v) { return d }

        // Try local time without Z: 20260304T000000
        let dfLocal: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = CalendarCompute.displayTimeZone
            df.dateFormat = "yyyyMMdd'T'HHmmss"
            return df
        }()
        return dfLocal.date(from: v)
    }
}

/// Convert Calendar weekday int (1=Sun..7=Sat) into an RFC-style RRULE BYDAY code.
func weekdayCode(from weekday: Int) -> String {
    switch weekday {
    case 1: return "SU"
    case 2: return "MO"
    case 3: return "TU"
    case 4: return "WE"
    case 5: return "TH"
    case 6: return "FR"
    case 7: return "SA"
    default: return "MO"
    }
}

extension Color {
    init(ly_hex hexString: String) {
        let raw = hexString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&int)
        let r, g, b: Double
        if raw.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        } else {
            r = 0.36; g = 0.55; b = 0.94 // fallback #5b8def
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        }
    }

    func toHexString() -> String {
        #if os(iOS)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02x%02x%02x", ri, gi, bi)
        #else
        return "#5b8def"
        #endif
    }
}

// MARK: - Shared small UI building blocks

struct CalendarLabeledGlassField<Content: View>: View {
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

struct CalendarControlRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)
            Spacer()
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
struct DateStepperRow: View {
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
        dateTime = cal.date(byAdding: .day, value: days, to: dateTime) ?? dateTime
    }
}

struct TimeEntryRow: View {
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

            TextField("4:30 PM", text: $text)
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
                .onAppear { syncFromDate() }
                .onSubmit { applyTypedTime() }
                .onChange(of: focused) { _, f in
                    if !f { applyTypedTime() }
                }
                .onChange(of: dateTime) { _, _ in
                    if !focused { syncFromDate() }
                }

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
                dateTime = CalendarCompute.setTimeKeepingDay(day: dateTime, hour: c.hour ?? 0, minute: c.minute ?? 0)
                syncFromDate()
                return
            }
        }
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

        dateTime = CalendarCompute.setTimeKeepingDay(day: dateTime, hour: newHour, minute: newMin)
        syncFromDate()
    }
}
#endif

enum CalendarCompute {
    static var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }
    static var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    static func merge(day: Date, time: Date) -> Date {
        let cal = tzCalendar
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = t.hour
        c.minute = t.minute
        c.second = 0
        return cal.date(from: c) ?? day
    }

    static func setTimeKeepingDay(day: Date, hour: Int, minute: Int) -> Date {
        var c = tzCalendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return tzCalendar.date(from: c) ?? day
    }
}

// MARK: - WeekdayPicker and ExceptionPills

struct WeekdayPicker: View {
    @Binding var selected: Set<Int>

    private let days: [(Int, String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.0) { wd, label in
                let isOn = selected.contains(wd)
                Button {
                    if isOn { selected.remove(wd) } else { selected.insert(wd) }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isOn ? .white : LColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isOn ? LColors.accent.opacity(0.35) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ExceptionPills: View {
    let items: [String]
    let onRemove: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(item)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
            }
        }
    }
}



