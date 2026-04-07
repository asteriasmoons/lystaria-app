//
//  CalendarDayView.swift
//  Lystaria
//

import SwiftUI
import SwiftData
import UIKit
#if os(iOS)
import UserNotifications
#endif

// MARK: - String helpers

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - CalendarDayView

struct CalendarDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\EventCalendar.sortOrder), SortDescriptor(\EventCalendar.name)]) private var calendars: [EventCalendar]
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]

    @State private var selectedDate: Date
    @State private var detailOverlayPayload: DayEventDetailOverlayPayload?
    @State private var pendingDeleteEvent: CalendarEvent? = nil
    @State private var pendingDeleteOccurrenceDate: Date? = nil
    @State private var showDeleteEventDialog = false
    @State private var showDeleteRecurringDialog = false
    @State private var sheetConfig: EventSheetConfig?

    var onBack: (() -> Void)? = nil

    init(selectedDate: Date = Date(), onBack: (() -> Void)? = nil) {
        _selectedDate = State(initialValue: selectedDate)
        self.onBack = onBack
    }

    private struct DayEventInstance: Identifiable {
        let id: String
        let event: CalendarEvent
        let occurrenceStart: Date
        let occurrenceEnd: Date?
    }

    private struct HourSlot: Identifiable {
        let id: Int
        let hour: Int
    }

    private struct DayEventDetailOverlayPayload: Identifiable {
        let id = UUID()
        let event: CalendarEvent
        let occurrenceStart: Date
        let occurrenceEnd: Date?
    }

    struct EventSheetConfig: Identifiable {
        let id = UUID()
        let selectedDate: Date
        let editingEvent: CalendarEvent?
    }

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    private var headerTitle: String {
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEEE, MMMM d")
        return df.string(from: selectedDate)
    }

    private var visibleHours: [HourSlot] {
        Array(5...23).map { HourSlot(id: $0, hour: $0) }
    }

    private var dayEvents: [DayEventInstance] {
        let dayAnchor = tzCalendar.startOfDay(for: selectedDate)

        print("[CalendarDayView] INPUT DATE:", selectedDate)
        print("[CalendarDayView] DAY ANCHOR:", dayAnchor)
        print("[CalendarDayView] TZ:", displayTimeZone.identifier)

        let resolved = CalendarEventResolver.occurrences(on: dayAnchor, from: allEvents, timeZone: displayTimeZone)

        print("[CalendarDayView] RESOLVED COUNT:", resolved.count)

        let eventById = Dictionary(allEvents.map { ($0.localEventId, $0) }, uniquingKeysWith: { _, last in last })

        print("[CalendarDayView] ALL EVENTS COUNT:", allEvents.count)
        for e in allEvents {
            print("  -> EVENT:", e.title, "| start:", e.startDate, "| rrule:", e.recurrenceRRule ?? "none")
        }

        return resolved.compactMap { occ in
            guard let event = eventById[occ.sourceEventId] else { return nil }
            return DayEventInstance(id: occ.id, event: event, occurrenceStart: occ.startDate, occurrenceEnd: occ.endDate)
        }
        .sorted { lhs, rhs in
            if lhs.event.allDay != rhs.event.allDay { return lhs.event.allDay && !rhs.event.allDay }
            return lhs.occurrenceStart < rhs.occurrenceStart
        }
    }

    private var allDayEvents: [DayEventInstance] { dayEvents.filter { $0.event.allDay } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LystariaBackground()
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        if !allDayEvents.isEmpty { allDaySection.padding(.top, 12) }
                        LazyVStack(spacing: 0) {
                            ForEach(visibleHours) { slot in hourRow(slot.hour) }
                        }
                        .padding(.top, 8).padding(.bottom, 120)
                    }
                }
                .scrollIndicators(.hidden)

                if let payload = detailOverlayPayload {
                    CalendarEventDetailOverlay(
                        event: payload.event, occurrenceStart: payload.occurrenceStart, occurrenceEnd: payload.occurrenceEnd,
                        onClose: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { detailOverlayPayload = nil } }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98))).zIndex(100)
                }
            }
            .overlay {
                if let config = sheetConfig {
                    EventSheet(onClose: { sheetConfig = nil }, selectedDate: config.selectedDate, editingEvent: config.editingEvent)
                        .preferredColorScheme(.dark)
                        .transition(.opacity.combined(with: .scale(scale: 0.96))).zIndex(70)
                }
            }
            .lystariaAlertConfirm(isPresented: $showDeleteEventDialog, title: "Delete event?", message: "This will permanently delete this event.", confirmTitle: "Delete", confirmRole: .destructive) {
                if let event = pendingDeleteEvent {
                    if let rid = event.reminderServerId {
                        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
                        deleteReminder(withServerId: rid)
                        event.reminderServerId = nil
                    }
                    modelContext.delete(event)
                    do {
                        try modelContext.save()
                        print("[CalendarDayView] DELETE SAVE SUCCESS")
                        pendingDeleteEvent = nil
                        pendingDeleteOccurrenceDate = nil
                    } catch {
                        print("[CalendarDayView] DELETE SAVE FAILED:", error)
                    }
                }
            }
            .confirmationDialog("Delete recurring event", isPresented: $showDeleteRecurringDialog, titleVisibility: .visible) {
                Button("This Event Only", role: .destructive) { inlineDeleteRecurring(scope: .thisEventOnly) }
                Button("This and Future", role: .destructive) { inlineDeleteRecurring(scope: .thisAndFuture) }
                Button("All Events", role: .destructive) { inlineDeleteRecurring(scope: .allEvents) }
                Button("Cancel", role: .cancel) { pendingDeleteEvent = nil; pendingDeleteOccurrenceDate = nil }
            } message: { Text("Choose how this recurring event should be deleted.") }
        }
    }

    // MARK: - Nested: EventSheet

    struct EventSheet: View {
        @Environment(\.modelContext) private var modelContext
        @StateObject private var limits = LimitManager.shared
        var onClose: (() -> Void)? = nil

        let selectedDate: Date
        let editingEvent: CalendarEvent?

        @State private var title = ""
        @State private var allDay = false
        @State private var startDay = Date()
        @State private var startTime = Date()
        @State private var endDay = Date()
        @State private var endTime = Date()
        @State private var location = ""
        @State private var meetingUrl = ""
        @State private var showLocationSearchSheet = false
        @State private var eventDescription = ""
        @State private var eventColor = "#5b8def"
        @State private var eventColorUI: Color = Color(ly_hex: "#5b8def")
        @Query(sort: [SortDescriptor(\EventCalendar.sortOrder), SortDescriptor(\EventCalendar.name)]) private var calendars: [EventCalendar]
        @State private var selectedCalendarId: String? = nil
        @State private var reminderEnabled = false
        @State private var minutesBefore: Int = 0
        @State private var recurrenceEnabled: Bool = false
        @State private var recurrenceFreq: RecurrenceFrequency = .weekly
        @State private var recurrenceInterval: Int = 1
        @State private var recurrenceWeekdays: Set<Int> = []

        private enum MonthlyRecurrenceMode: String, CaseIterable, Identifiable {
            case sameDay, specificMonthDays, nthWeekday
            var id: String { rawValue }
        }

        private enum YearlyRecurrenceMode: String, CaseIterable, Identifiable {
            case sameDate, specificMonthDay, nthWeekdayOfMonth
            var id: String { rawValue }
        }

        private enum RecurrenceOrdinal: Int, CaseIterable, Identifiable {
            case first = 1, second = 2, third = 3, fourth = 4
            case last = -1, secondLast = -2, thirdLast = -3
            var id: Int { rawValue }
            var label: String {
                switch self {
                case .first: return "First"; case .second: return "Second"
                case .third: return "Third"; case .fourth: return "Fourth"
                case .last: return "Last"; case .secondLast: return "Second to Last"
                case .thirdLast: return "Third to Last"
                }
            }
        }

        enum RecurringEditScope: String, Identifiable {
            case thisEventOnly, allEvents, thisAndFuture
            var id: String { rawValue }
            var title: String {
                switch self {
                case .thisEventOnly: return "This Event Only"
                case .allEvents: return "All Events"
                case .thisAndFuture: return "This and Future"
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
            case never, afterCount, onDate
            var id: String { rawValue }
        }

        @State private var recurrenceEndMode: RecurrenceEndMode = .never
        @State private var recurrenceCount: Int = 10
        @State private var recurrenceUntilDay: Date = Date()
        @State private var showRecurringEditScopeDialog = false
        @State private var showDeleteConfirm = false
        @State private var showRecurringDeleteScopeDialog = false

        private var weekdayOptions: [(Int, String)] {
            [(1,"Sunday"),(2,"Monday"),(3,"Tuesday"),(4,"Wednesday"),(5,"Thursday"),(6,"Friday"),(7,"Saturday")]
        }
        private var monthOptions: [(Int, String)] {
            [(1,"January"),(2,"February"),(3,"March"),(4,"April"),(5,"May"),(6,"June"),
             (7,"July"),(8,"August"),(9,"September"),(10,"October"),(11,"November"),(12,"December")]
        }

        private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
        private var closeAction: () -> Void { onClose ?? {} }

        private var isEditingRecurringSeries: Bool {
            guard let editingEvent else { return false }
            return !editingEvent.isRecurrenceException && (editingEvent.isRecurringSeriesMaster || editingEvent.recurrenceRRule != nil)
        }

        private var isEditingOccurrenceFromSeries: Bool {
            guard let editingEvent, isEditingRecurringSeries else { return false }
            return !tzCalendar.isDate(selectedDate, inSameDayAs: editingEvent.startDate)
        }

        private var canDeleteCurrentEvent: Bool { editingEvent != nil }

        private var occurrenceAnchorDate: Date {
            guard let editingEvent else { return selectedDate }
            return isEditingOccurrenceFromSeries ? selectedDate : editingEvent.startDate
        }

        private var displayTimeZone: TimeZone {
            TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
        }

        private var tzCalendar: Calendar {
            var cal = Calendar.current; cal.timeZone = displayTimeZone; return cal
        }

        var body: some View {
            ZStack(alignment: .top) {
                LystariaFullScreenForm(
                    title: editingEvent != nil ? "Edit Event" : "New Event",
                    onCancel: { closeAction() },
                    canSave: !titleTrimmed.isEmpty,
                    onSave: { handleSaveTapped() }
                ) {
                    formContent
                        .padding(.top, 64)
                }

                HStack {
                    Button {
                        closeAction()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        handleSaveTapped()
                    } label: {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(titleTrimmed.isEmpty ? LColors.textSecondary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                if titleTrimmed.isEmpty {
                                    Color.white.opacity(0.06)
                                } else {
                                    LGradients.blue
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: titleTrimmed.isEmpty ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(titleTrimmed.isEmpty)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 10)
                .zIndex(10)
            }
            .onAppear { loadInitialState() }
            .sheet(isPresented: $showLocationSearchSheet) {
                LocationSearchSheet { displayName, _, _ in location = displayName }
            }
            .confirmationDialog("Apply changes to recurring event", isPresented: $showRecurringEditScopeDialog, titleVisibility: .visible) {
                Button(RecurringEditScope.thisEventOnly.title) { save(editScope: .thisEventOnly) }
                Button(RecurringEditScope.allEvents.title) { save(editScope: .allEvents) }
                Button(RecurringEditScope.thisAndFuture.title) { save(editScope: .thisAndFuture) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Choose how these changes should apply to this recurring event.") }
            .lystariaAlertConfirm(isPresented: $showDeleteConfirm, title: "Delete event?", message: "This event will be removed.", confirmTitle: "Delete", confirmRole: .destructive) {
                performDelete(scope: .allEvents)
            }
            .confirmationDialog("Delete recurring event", isPresented: $showRecurringDeleteScopeDialog, titleVisibility: .visible) {
                Button(RecurringEditScope.thisEventOnly.title, role: .destructive) { performDelete(scope: .thisEventOnly) }
                Button(RecurringEditScope.allEvents.title, role: .destructive) { performDelete(scope: .allEvents) }
                Button(RecurringEditScope.thisAndFuture.title, role: .destructive) { performDelete(scope: .thisAndFuture) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Choose how this recurring event should be deleted.") }
        }

        private var formContent: some View {
            VStack(spacing: 16) {
                CalendarControlRow(label: "Calendar") {
                    Picker("", selection: $selectedCalendarId) {
                        Text("No Calendar").tag(nil as String?)
                        ForEach(calendars) { Text($0.name).tag(Optional($0.serverId)) }
                    }
                    .labelsHidden().pickerStyle(.menu)
                    .onChange(of: selectedCalendarId) { _, newValue in
                        if let id = newValue, let cal = calendars.first(where: { $0.serverId == id }) {
                            eventColor = cal.color; eventColorUI = Color(ly_hex: cal.color)
                        }
                    }
                }

                CalendarLabeledGlassField(label: "TITLE") {
                    TextField("Event title", text: $title).textFieldStyle(.plain).foregroundStyle(LColors.textPrimary)
                }

                GlassCard(padding: 16) {
                    VStack(spacing: 12) {
                        Toggle("All Day", isOn: $allDay).foregroundStyle(LColors.textPrimary).tint(LColors.accent)
                        if allDay {
                            CalendarControlRow(label: "Day") {
                                DatePicker("", selection: $startDay, displayedComponents: .date)
                                    .labelsHidden().datePickerStyle(.compact).tint(LColors.accent)
                            }
                        } else {
                            CalendarControlRow(label: "Start") {
                                DatePicker("", selection: Binding(
                                    get: { CalendarCompute.merge(day: startDay, time: startTime) },
                                    set: { startDay = $0; startTime = $0 }
                                ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden().datePickerStyle(.compact).tint(LColors.accent)
                            }
                            CalendarControlRow(label: "End") {
                                DatePicker("", selection: Binding(
                                    get: { CalendarCompute.merge(day: endDay, time: endTime) },
                                    set: { endDay = $0; endTime = $0 }
                                ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden().datePickerStyle(.compact).tint(LColors.accent)
                            }
                        }
                    }
                }

                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Event Reminder", isOn: $reminderEnabled).foregroundStyle(LColors.textPrimary).tint(LColors.accent)
                        if reminderEnabled {
                            CalendarControlRow(label: "Remind") {
                                Stepper(value: $minutesBefore, in: 0...240, step: 5) {
                                    Text(minutesBefore == 0 ? "At time" : "\(minutesBefore) min before")
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                                }.labelsHidden()
                            }
                        } else {
                            Text("Turn on to add this event into Reminders.").font(.system(size: 13)).foregroundStyle(LColors.textSecondary)
                        }
                    }
                }

                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Repeat", isOn: $recurrenceEnabled).foregroundStyle(LColors.textPrimary).tint(LColors.accent)
                        if recurrenceEnabled {
                            CalendarControlRow(label: "Frequency") {
                                Picker("", selection: $recurrenceFreq) {
                                    Text("Daily").tag(RecurrenceFrequency.daily)
                                    Text("Weekly").tag(RecurrenceFrequency.weekly)
                                    Text("Monthly").tag(RecurrenceFrequency.monthly)
                                    Text("Yearly").tag(RecurrenceFrequency.yearly)
                                }.labelsHidden().pickerStyle(.menu)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("INTERVAL").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                                HStack(spacing: 10) {
                                    Button { recurrenceInterval = max(1, recurrenceInterval - 1) } label: {
                                        Image(systemName: "minus").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 34, height: 34).background(Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                    }.buttonStyle(.plain)
                                    Text("Every \(recurrenceInterval) \(recurrenceInterval == 1 ? unitLabel(for: recurrenceFreq) : unitLabel(for: recurrenceFreq) + "s")")
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .center).padding(.horizontal, 12).padding(.vertical, 10)
                                        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
                                    Button { recurrenceInterval = min(365, recurrenceInterval + 1) } label: {
                                        Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 34, height: 34).background(Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }

                            if recurrenceFreq == .weekly {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DAYS").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                                    WeekdayPicker(selected: $recurrenceWeekdays)
                                }
                            }

                            if recurrenceFreq == .monthly {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("MONTHLY PATTERN").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                                    CalendarControlRow(label: "Mode") {
                                        Picker("", selection: $monthlyRecurrenceMode) {
                                            Text("Same day each month").tag(MonthlyRecurrenceMode.sameDay)
                                            Text("Specific day(s) of month").tag(MonthlyRecurrenceMode.specificMonthDays)
                                            Text("Nth weekday of month").tag(MonthlyRecurrenceMode.nthWeekday)
                                        }.labelsHidden().pickerStyle(.menu)
                                    }
                                    if monthlyRecurrenceMode == .specificMonthDays {
                                        CalendarLabeledGlassField(label: "MONTH DAYS") {
                                            TextField("Example: 1, 15, 28", text: $monthlySpecificDaysText).textFieldStyle(.plain).foregroundStyle(LColors.textPrimary)
                                        }
                                    }
                                    if monthlyRecurrenceMode == .nthWeekday {
                                        CalendarControlRow(label: "Ordinal") {
                                            Picker("", selection: $monthlyOrdinal) { ForEach(RecurrenceOrdinal.allCases) { Text($0.label).tag($0) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                        CalendarControlRow(label: "Weekday") {
                                            Picker("", selection: $monthlyNthWeekday) { ForEach(weekdayOptions, id: \.0) { v, l in Text(l).tag(v) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                    }
                                }
                            }

                            if recurrenceFreq == .yearly {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("YEARLY PATTERN").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                                    CalendarControlRow(label: "Mode") {
                                        Picker("", selection: $yearlyRecurrenceMode) {
                                            Text("Same date each year").tag(YearlyRecurrenceMode.sameDate)
                                            Text("Specific month and day").tag(YearlyRecurrenceMode.specificMonthDay)
                                            Text("Nth weekday of month").tag(YearlyRecurrenceMode.nthWeekdayOfMonth)
                                        }.labelsHidden().pickerStyle(.menu)
                                    }
                                    if yearlyRecurrenceMode == .specificMonthDay {
                                        CalendarControlRow(label: "Month") {
                                            Picker("", selection: $yearlyMonth) { ForEach(monthOptions, id: \.0) { v, l in Text(l).tag(v) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                        CalendarControlRow(label: "Day") {
                                            Stepper(value: $yearlyDay, in: 1...31) {
                                                Text("Day \(yearlyDay)").font(.system(size: 14, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                                            }.labelsHidden()
                                        }
                                    }
                                    if yearlyRecurrenceMode == .nthWeekdayOfMonth {
                                        CalendarControlRow(label: "Ordinal") {
                                            Picker("", selection: $yearlyOrdinal) { ForEach(RecurrenceOrdinal.allCases) { Text($0.label).tag($0) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                        CalendarControlRow(label: "Weekday") {
                                            Picker("", selection: $yearlyNthWeekday) { ForEach(weekdayOptions, id: \.0) { v, l in Text(l).tag(v) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                        CalendarControlRow(label: "Month") {
                                            Picker("", selection: $yearlyNthMonth) { ForEach(monthOptions, id: \.0) { v, l in Text(l).tag(v) } }.labelsHidden().pickerStyle(.menu)
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("END").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                                CalendarControlRow(label: "Ends") {
                                    Picker("", selection: $recurrenceEndMode) {
                                        Text("Never").tag(RecurrenceEndMode.never)
                                        Text("After").tag(RecurrenceEndMode.afterCount)
                                        Text("On date").tag(RecurrenceEndMode.onDate)
                                    }.labelsHidden().pickerStyle(.menu)
                                }
                                if recurrenceEndMode == .afterCount {
                                    CalendarControlRow(label: "Count") {
                                        Stepper(value: $recurrenceCount, in: 1...999) {
                                            Text("\(recurrenceCount) times").font(.system(size: 14, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                                        }.labelsHidden()
                                    }
                                }
                                if recurrenceEndMode == .onDate {
                                    CalendarControlRow(label: "Until") {
                                        DatePicker("", selection: $recurrenceUntilDay, displayedComponents: .date).labelsHidden().datePickerStyle(.compact).tint(LColors.accent)
                                    }
                                }
                            }
                        } else {
                            Text("Turn on to make this a recurring event.").font(.system(size: 13)).foregroundStyle(LColors.textSecondary)
                        }
                    }
                }

                CalendarLabeledGlassField(label: "LOCATION") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Add location (optional)", text: $location).textFieldStyle(.plain).foregroundStyle(LColors.textPrimary)
                        HStack(spacing: 10) {
                            Button { showLocationSearchSheet = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold))
                                    Text("Search Place").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 10)
                                .background(LGradients.blue).clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)

                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("LystariaUseCurrentLocation"), object: nil)
                                showLocationSearchSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill").font(.system(size: 12, weight: .semibold))
                                    Text("Current Location").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary).padding(.horizontal, 12).padding(.vertical, 10)
                                .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                CalendarLabeledGlassField(label: "LINK") {
                    TextField("Add link (optional)", text: $meetingUrl).textFieldStyle(.plain).foregroundStyle(LColors.textPrimary)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                    GlassTextEditor(placeholder: "Event details (optional)", text: $eventDescription, minHeight: 80)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR").font(.system(size: 13, weight: .semibold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
                    ColorPicker("", selection: $eventColorUI, supportsOpacity: false)
                        .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: eventColorUI) { _, newColor in eventColor = newColor.toHexString() }
                }

                if canDeleteCurrentEvent {
                    LButton(title: "Delete Event", icon: "trash", style: .danger) { handleDeleteTapped() }.padding(.top, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }

        private func loadInitialState() {
            if let e = editingEvent {
                title = e.title; allDay = e.allDay; location = e.location ?? ""; meetingUrl = e.meetingUrl ?? ""
                eventDescription = e.eventDescription ?? ""; eventColor = e.color ?? "#5b8def"
                eventColorUI = Color(ly_hex: eventColor); selectedCalendarId = e.calendarId
                let editingStart = occurrenceAnchorDate; startDay = editingStart; startTime = editingStart
                if let end = e.endDate {
                    let duration = end.timeIntervalSince(e.startDate)
                    let resolvedEnd = duration > 0 ? editingStart.addingTimeInterval(duration) : end
                    endDay = resolvedEnd; endTime = resolvedEnd
                } else {
                    let end = tzCalendar.date(byAdding: .hour, value: 1, to: editingStart) ?? editingStart
                    endDay = end; endTime = end
                }
                if let rid = e.reminderServerId, let r = findReminder(serverId: rid) {
                    reminderEnabled = true
                    minutesBefore = max(0, min(240, Int((e.startDate.timeIntervalSince(r.nextRunAt) / 60.0).rounded())))
                } else { reminderEnabled = false; minutesBefore = 0 }

                let rruleSnapshot = e.recurrenceRRule
                if let rrule = rruleSnapshot, let parsed = ParsedRRule.parse(rrule) {
                    recurrenceEnabled = true
                    switch parsed.freq { case .daily: recurrenceFreq = .daily; case .weekly: recurrenceFreq = .weekly; case .monthly: recurrenceFreq = .monthly; case .yearly: recurrenceFreq = .yearly }
                    recurrenceInterval = max(1, parsed.interval)
                    let map: [String: Int] = ["SU":1,"MO":2,"TU":3,"WE":4,"TH":5,"FR":6,"SA":7]
                    recurrenceWeekdays = (parsed.freq == .weekly ? (parsed.byDay?.compactMap { map[$0] } ?? []) : []).reduce(into: Set()) { $0.insert($1) }

                    if parsed.freq == .monthly {
                        if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                            monthlyRecurrenceMode = .specificMonthDays
                            monthlySpecificDaysText = byMonthDay.map(String.init).joined(separator: ", ")
                        } else if let byDay = parsed.byDay, let pos = parsed.bySetPos,
                                  let firstCode = byDay.first, let weekday = map[firstCode],
                                  let ordinal = RecurrenceOrdinal(rawValue: pos) {
                            monthlyRecurrenceMode = .nthWeekday; monthlyOrdinal = ordinal; monthlyNthWeekday = weekday; monthlySpecificDaysText = ""
                        } else { monthlyRecurrenceMode = .sameDay; monthlySpecificDaysText = "" }
                    } else { monthlyRecurrenceMode = .sameDay; monthlySpecificDaysText = "" }

                    if parsed.freq == .yearly {
                        if let byMonth = parsed.byMonth, let byDay = parsed.byDay, let pos = parsed.bySetPos,
                           let month = byMonth.first, let firstCode = byDay.first,
                           let weekday = map[firstCode], let ordinal = RecurrenceOrdinal(rawValue: pos) {
                            yearlyRecurrenceMode = .nthWeekdayOfMonth; yearlyNthMonth = month; yearlyNthWeekday = weekday; yearlyOrdinal = ordinal
                            yearlyMonth = tzCalendar.component(.month, from: e.startDate); yearlyDay = tzCalendar.component(.day, from: e.startDate)
                        } else if let byMonth = parsed.byMonth, let byMonthDay = parsed.byMonthDay,
                                  let month = byMonth.first, let day = byMonthDay.first {
                            yearlyRecurrenceMode = .specificMonthDay; yearlyMonth = month; yearlyDay = day; yearlyNthMonth = month
                            yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                        } else {
                            yearlyRecurrenceMode = .sameDate; yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                            yearlyDay = tzCalendar.component(.day, from: e.startDate); yearlyNthMonth = yearlyMonth
                            yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                        }
                    } else {
                        yearlyRecurrenceMode = .sameDate; yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                        yearlyDay = tzCalendar.component(.day, from: e.startDate); yearlyNthMonth = yearlyMonth
                        yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                    }

                    if let c = parsed.count { recurrenceEndMode = .afterCount; recurrenceCount = max(1, c) }
                    else if let u = parsed.until { recurrenceEndMode = .onDate; recurrenceUntilDay = u }
                    else { recurrenceEndMode = .never; recurrenceCount = 10; recurrenceUntilDay = e.startDate }
                } else {
                    recurrenceEnabled = false; recurrenceFreq = .weekly; recurrenceInterval = 1; recurrenceWeekdays = []
                    monthlyRecurrenceMode = .sameDay; monthlySpecificDaysText = ""; monthlyOrdinal = .first
                    monthlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate)
                    yearlyRecurrenceMode = .sameDate; yearlyMonth = tzCalendar.component(.month, from: e.startDate)
                    yearlyDay = tzCalendar.component(.day, from: e.startDate); yearlyOrdinal = .first
                    yearlyNthWeekday = tzCalendar.component(.weekday, from: e.startDate); yearlyNthMonth = yearlyMonth
                    recurrenceEndMode = .never; recurrenceCount = 10; recurrenceUntilDay = e.startDate
                }
            } else {
                title = ""; allDay = false; location = ""; meetingUrl = ""; eventDescription = ""
                eventColor = "#5b8def"; eventColorUI = Color(ly_hex: eventColor)
                selectedCalendarId = calendars.first(where: { $0.isDefault })?.serverId ?? calendars.first?.serverId
                startDay = selectedDate; startTime = selectedDate
                let defaultEnd = tzCalendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
                endDay = defaultEnd; endTime = defaultEnd; reminderEnabled = false; minutesBefore = 0
                recurrenceEnabled = false; recurrenceFreq = .weekly; recurrenceInterval = 1; recurrenceWeekdays = []
                monthlyRecurrenceMode = .sameDay; monthlySpecificDaysText = ""; monthlyOrdinal = .first
                monthlyNthWeekday = tzCalendar.component(.weekday, from: selectedDate)
                yearlyRecurrenceMode = .sameDate; yearlyMonth = tzCalendar.component(.month, from: selectedDate)
                yearlyDay = tzCalendar.component(.day, from: selectedDate); yearlyOrdinal = .first
                yearlyNthWeekday = tzCalendar.component(.weekday, from: selectedDate); yearlyNthMonth = yearlyMonth
                recurrenceEndMode = .never; recurrenceCount = 10; recurrenceUntilDay = selectedDate
            }
        }

        private func handleSaveTapped() {
            print("[EventSheet] HANDLE SAVE tapped")
            print("[EventSheet] isEditingRecurringSeries:", isEditingRecurringSeries)
            print("[EventSheet] isEditingOccurrenceFromSeries:", isEditingOccurrenceFromSeries)

            if isEditingRecurringSeries && isEditingOccurrenceFromSeries {
                print("[EventSheet] Showing recurring scope dialog (occurrence)")
                showRecurringEditScopeDialog = true
            } else if isEditingRecurringSeries {
                print("[EventSheet] Showing recurring scope dialog (series)")
                showRecurringEditScopeDialog = true
            } else {
                print("[EventSheet] Saving as non-recurring event")
                save(editScope: .allEvents)
            }
        }

        private func handleDeleteTapped() {
            guard let editingEvent else { return }
            if editingEvent.recurrenceRRule != nil || editingEvent.isRecurringSeriesMaster { showRecurringDeleteScopeDialog = true } else { showDeleteConfirm = true }
        }

        private func save(editScope: RecurringEditScope) {
            print("[EventSheet] SAVE called with scope:", editScope.rawValue)
            print("[EventSheet] editingEvent:", editingEvent?.title ?? "nil")

            let finalStart = allDay ? tzCalendar.startOfDay(for: startDay) : CalendarCompute.merge(day: startDay, time: startTime)
            let finalEnd: Date? = allDay ? nil : CalendarCompute.merge(day: endDay, time: endTime)
            let trimmedTitle = titleTrimmed; guard !trimmedTitle.isEmpty else { return }
            let selectedCalendar = calendars.first(where: { $0.serverId == selectedCalendarId })

            if let editingEvent {
                switch editScope {
                case .allEvents:
                    let normalizedRange = normalizedSeriesRangeForAllEvents(start: finalStart, end: finalEnd)
                    applyValues(to: editingEvent, start: normalizedRange.start, end: normalizedRange.end, selectedCalendar: selectedCalendar)
                    updateReminder(for: editingEvent, eventStart: normalizedRange.start)
                case .thisEventOnly:
                    let detached = makeDetachedOccurrence(from: editingEvent, occurrenceDate: occurrenceAnchorDate)
                    applyValues(to: detached, start: finalStart, end: finalEnd, selectedCalendar: selectedCalendar)
                    modelContext.insert(detached)

                    var exceptions = editingEvent.recurrenceExceptions
                    let df = ISO8601DateFormatter()
                    df.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
                    df.timeZone = displayTimeZone
                    let key = df.string(from: occurrenceAnchorDate)
                    if !exceptions.contains(key) {
                        exceptions.append(key)
                        editingEvent.recurrenceExceptions = exceptions.sorted()
                    }
                    editingEvent.needsSync = true
                    editingEvent.syncState = .modifiedLocal
                    editingEvent.updatedAt = Date()

                    updateReminder(for: detached, eventStart: finalStart)
                case .thisAndFuture:
                    splitSeriesAndCreateFuture(from: editingEvent, splitDate: occurrenceAnchorDate, newStart: finalStart, newEnd: finalEnd, selectedCalendar: selectedCalendar)
                }
            } else {
                let event = CalendarEvent(
                    title: trimmedTitle, startDate: finalStart, endDate: finalEnd, allDay: allDay,
                    eventDescription: eventDescription.nilIfBlank, color: eventColor,
                    meetingUrl: meetingUrl.nilIfBlank, location: location.nilIfBlank,
                    recurrenceRRule: buildRRule(), timeZoneId: displayTimeZone.identifier,
                    recurrence: nil, recurrenceExceptions: [], calendarId: selectedCalendarId,
                    serverId: nil, syncState: .newLocal, isRecurringSeriesMaster: recurrenceEnabled,
                    isRecurrenceException: false, isCancelledOccurrence: false,
                    parentSeriesLocalId: nil, splitFromSeriesLocalId: nil,
                    originalOccurrenceDate: nil, splitEffectiveFrom: nil, exceptionKind: nil
                )
                event.calendar = selectedCalendar; modelContext.insert(event); updateReminder(for: event, eventStart: finalStart)
            }
            do {
                try modelContext.save()
                print("[EventSheet] SAVE SUCCESS")
                closeAction()
            } catch {
                print("[EventSheet] SAVE FAILED:", error)
            }
        }

        private func applyValues(to event: CalendarEvent, start: Date, end: Date?, selectedCalendar: EventCalendar?) {
            event.title = titleTrimmed; event.startDate = start; event.endDate = end; event.allDay = allDay
            event.location = location.nilIfBlank; event.meetingUrl = meetingUrl.nilIfBlank
            event.eventDescription = eventDescription.nilIfBlank; event.color = eventColor
            event.calendarId = selectedCalendarId; event.calendar = selectedCalendar
            event.timeZoneId = displayTimeZone.identifier; event.recurrenceRRule = buildRRule()
            event.isRecurringSeriesMaster = recurrenceEnabled; event.updatedAt = Date()
            event.needsSync = true; event.syncState = .modifiedLocal
        }

        private func normalizedSeriesRangeForAllEvents(start: Date, end: Date?) -> (start: Date, end: Date?) {
            guard let editingEvent, isEditingRecurringSeries, isEditingOccurrenceFromSeries else {
                return (start, end)
            }

            if allDay {
                return (tzCalendar.startOfDay(for: editingEvent.startDate), nil)
            }

            let startComponents = tzCalendar.dateComponents([.hour, .minute, .second], from: start)
            let anchoredStart = tzCalendar.date(
                bySettingHour: startComponents.hour ?? 0,
                minute: startComponents.minute ?? 0,
                second: startComponents.second ?? 0,
                of: editingEvent.startDate
            ) ?? editingEvent.startDate

            let anchoredEnd: Date?
            if let end {
                let duration = max(0, end.timeIntervalSince(start))
                anchoredEnd = anchoredStart.addingTimeInterval(duration)
            } else {
                anchoredEnd = nil
            }

            return (anchoredStart, anchoredEnd)
        }

        private func performDelete(scope: RecurringEditScope) {
            print("[EventSheet] DELETE called with scope:", scope.rawValue)
            print("[EventSheet] deleting event:", editingEvent?.title ?? "nil")

            guard let event = editingEvent else { return }
            let occurrenceDate = occurrenceAnchorDate
            switch scope {
            case .thisEventOnly:
                let cancelException = CalendarEvent(
                    title: event.title, startDate: occurrenceDate, endDate: event.endDate,
                    allDay: event.allDay, eventDescription: event.eventDescription, color: event.color,
                    meetingUrl: event.meetingUrl, location: event.location, recurrenceRRule: nil,
                    timeZoneId: event.timeZoneId, recurrence: nil, recurrenceExceptions: [],
                    calendarId: event.calendarId, serverId: nil, syncState: .newLocal,
                    isRecurringSeriesMaster: false, isRecurrenceException: true, isCancelledOccurrence: true,
                    parentSeriesLocalId: event.localEventId, splitFromSeriesLocalId: nil,
                    originalOccurrenceDate: occurrenceDate, splitEffectiveFrom: nil, exceptionKind: .cancelled
                )
                cancelException.calendar = event.calendar; modelContext.insert(cancelException)
                var exceptions = event.recurrenceExceptions
                let df = ISO8601DateFormatter()
                df.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
                df.timeZone = displayTimeZone
                let key = df.string(from: occurrenceDate)
                if !exceptions.contains(key) { exceptions.append(key); event.recurrenceExceptions = exceptions.sorted() }
                event.needsSync = true; event.syncState = .modifiedLocal; event.updatedAt = Date()

            case .thisAndFuture:
                if let originalRule = event.recurrenceRRule {
                    let body = originalRule.hasPrefix("RRULE:") ? String(originalRule.dropFirst("RRULE:".count)) : originalRule
                    let previousDay = tzCalendar.date(byAdding: .day, value: -1, to: tzCalendar.startOfDay(for: occurrenceDate)) ?? occurrenceDate
                    let parts = body.split(separator: ";").map(String.init).filter { !$0.uppercased().hasPrefix("UNTIL=") && !$0.uppercased().hasPrefix("COUNT=") }
                    let c = tzCalendar.dateComponents([.year,.month,.day], from: previousDay)
                    let until = String(format: "UNTIL=%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
                    event.recurrenceRRule = (parts + [until]).joined(separator: ";")
                }
                event.needsSync = true; event.syncState = .modifiedLocal; event.updatedAt = Date()

            case .allEvents:
                if let rid = event.reminderServerId {
                    NotificationManager.shared.cancelAllCalendarNotifications(id: rid); deleteReminder(withServerId: rid); event.reminderServerId = nil
                }
                let masterLocalId = event.localEventId
                let childDescriptor = FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.parentSeriesLocalId == masterLocalId })
                if let children = try? modelContext.fetch(childDescriptor) { for child in children { modelContext.delete(child) } }
                modelContext.delete(event)
            }
            do {
                try modelContext.save()
                print("[EventSheet] DELETE SAVE SUCCESS")
                closeAction()
            } catch {
                print("[EventSheet] DELETE SAVE FAILED:", error)
            }
        }

        private func buildRRule() -> String? {
            guard recurrenceEnabled else { return nil }
            var parts: [String] = ["FREQ=\(recurrenceFreq.rawValue.uppercased())"]
            if recurrenceInterval > 1 { parts.append("INTERVAL=\(recurrenceInterval)") }
            switch recurrenceFreq {
            case .daily: break
            case .weekly:
                let map: [Int: String] = [1:"SU",2:"MO",3:"TU",4:"WE",5:"TH",6:"FR",7:"SA"]
                let sorted = recurrenceWeekdays.sorted()
                if !sorted.isEmpty { parts.append("BYDAY=\(sorted.compactMap { map[$0] }.joined(separator: ","))") }
            case .monthly:
                switch monthlyRecurrenceMode {
                case .sameDay: parts.append("BYMONTHDAY=\(tzCalendar.component(.day, from: startDay))")
                case .specificMonthDays:
                    let values = parseMonthDays(monthlySpecificDaysText)
                    if !values.isEmpty { parts.append("BYMONTHDAY=\(values.map(String.init).joined(separator: ","))") }
                case .nthWeekday:
                    if let byDay = weekdayCode(from: monthlyNthWeekday) { parts.append("BYDAY=\(byDay)"); parts.append("BYSETPOS=\(monthlyOrdinal.rawValue)") }
                }
            case .yearly:
                switch yearlyRecurrenceMode {
                case .sameDate:
                    parts.append("BYMONTH=\(tzCalendar.component(.month, from: startDay))")
                    parts.append("BYMONTHDAY=\(tzCalendar.component(.day, from: startDay))")
                case .specificMonthDay: parts.append("BYMONTH=\(yearlyMonth)"); parts.append("BYMONTHDAY=\(yearlyDay)")
                case .nthWeekdayOfMonth:
                    if let byDay = weekdayCode(from: yearlyNthWeekday) {
                        parts.append("BYMONTH=\(yearlyNthMonth)"); parts.append("BYDAY=\(byDay)"); parts.append("BYSETPOS=\(yearlyOrdinal.rawValue)")
                    }
                }
            }
            switch recurrenceEndMode {
            case .never: break
            case .afterCount: parts.append("COUNT=\(max(1, recurrenceCount))")
            case .onDate:
                let c = tzCalendar.dateComponents([.year,.month,.day], from: recurrenceUntilDay)
                parts.append(String(format: "UNTIL=%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1))
            }
            return parts.joined(separator: ";")
        }

        private func unitLabel(for frequency: RecurrenceFrequency) -> String {
            switch frequency { case .daily: return "day"; case .weekly: return "week"; case .monthly: return "month"; case .yearly: return "year" }
        }

        private func weekdayCode(from value: Int) -> String? { [1:"SU",2:"MO",3:"TU",4:"WE",5:"TH",6:"FR",7:"SA"][value] }

        private func parseMonthDays(_ text: String) -> [Int] {
            text.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { $0 >= 1 && $0 <= 31 }
        }

        private func findReminder(serverId: String) -> LystariaReminder? {
            guard let uuid = UUID(uuidString: serverId) else { return nil }
            return try? modelContext.fetch(FetchDescriptor<LystariaReminder>(predicate: #Predicate { $0.linkedHabitId == uuid })).first
        }

        // MARK: - Reminder management (uses .details — the correct field name)
        private func updateReminder(for event: CalendarEvent, eventStart: Date) {
            let fireDate = eventStart
            let reminderSchedule = buildReminderSchedule(for: event, fireDate: fireDate)

            if reminderEnabled {
                if let existingId = event.reminderServerId,
                   let existingReminder = findReminder(serverId: existingId) {
                    existingReminder.title = event.title
                    existingReminder.details = event.eventDescription
                    existingReminder.nextRunAt = fireDate
                    existingReminder.schedule = reminderSchedule
                    existingReminder.timezone = displayTimeZone.identifier
                    existingReminder.updatedAt = Date()
                } else {
                    let reminderId = UUID()
                    let reminder = LystariaReminder(
                        title: event.title,
                        details: event.eventDescription,
                        nextRunAt: fireDate,
                        schedule: reminderSchedule,
                        timezone: displayTimeZone.identifier,
                        reminderType: .regular
                    )
                    reminder.linkedHabitId = reminderId
                    modelContext.insert(reminder)
                    event.reminderServerId = reminderId.uuidString
                }
            } else if let existingId = event.reminderServerId {
                deleteReminder(withServerId: existingId)
                event.reminderServerId = nil
            }
        }
        
        private func buildReminderSchedule(for event: CalendarEvent, fireDate: Date) -> ReminderSchedule? {
            guard let rrule = event.recurrenceRRule,
                  let parsed = ParsedRRule.parse(rrule) else {
                return .once
            }

            let timeOfDay = reminderTimeString(from: fireDate)

            switch parsed.freq {
            case .daily:
                return ReminderSchedule(
                    kind: .daily,
                    timeOfDay: timeOfDay,
                    timesOfDay: nil,
                    interval: max(1, parsed.interval),
                    daysOfWeek: nil,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: nil
                )

            case .weekly:
                let weekdayMap: [String: Int] = [
                    "SU": 0, "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6
                ]

                let days: [Int]
                if let byDay = parsed.byDay, !byDay.isEmpty {
                    days = byDay.compactMap { weekdayMap[$0] }
                } else {
                    days = [swiftWeekdayToReminderWeekday(tzCalendar.component(.weekday, from: fireDate))]
                }

                return ReminderSchedule(
                    kind: .weekly,
                    timeOfDay: timeOfDay,
                    timesOfDay: nil,
                    interval: max(1, parsed.interval),
                    daysOfWeek: days,
                    dayOfMonth: nil,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: nil
                )

            case .monthly:
                let reminderDay = tzCalendar.component(.day, from: fireDate)

                return ReminderSchedule(
                    kind: .monthly,
                    timeOfDay: timeOfDay,
                    timesOfDay: nil,
                    interval: max(1, parsed.interval),
                    daysOfWeek: nil,
                    dayOfMonth: reminderDay,
                    anchorMonth: nil,
                    anchorDay: nil,
                    intervalMinutes: nil
                )

            case .yearly:
                let reminderMonth = tzCalendar.component(.month, from: fireDate)
                let reminderDay = tzCalendar.component(.day, from: fireDate)

                return ReminderSchedule(
                    kind: .yearly,
                    timeOfDay: timeOfDay,
                    timesOfDay: nil,
                    interval: max(1, parsed.interval),
                    daysOfWeek: nil,
                    dayOfMonth: nil,
                    anchorMonth: reminderMonth,
                    anchorDay: reminderDay,
                    intervalMinutes: nil
                )
            }
        }
        
        private func reminderTimeString(from date: Date) -> String {
            let components = tzCalendar.dateComponents([.hour, .minute], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            return String(format: "%02d:%02d", hour, minute)
        }

        private func swiftWeekdayToReminderWeekday(_ swiftWeekday: Int) -> Int {
            switch swiftWeekday {
            case 1: return 0 // Sunday
            case 2: return 1 // Monday
            case 3: return 2 // Tuesday
            case 4: return 3 // Wednesday
            case 5: return 4 // Thursday
            case 6: return 5 // Friday
            case 7: return 6 // Saturday
            default: return 0
            }
        }

        private func deleteReminder(withServerId id: String) {
            guard let targetUUID = UUID(uuidString: id) else { return }
            if let match = try? modelContext.fetch(FetchDescriptor<LystariaReminder>(predicate: #Predicate { $0.linkedHabitId == targetUUID })).first {
                modelContext.delete(match)
            }
        }

        private func makeDetachedOccurrence(from event: CalendarEvent, occurrenceDate: Date) -> CalendarEvent {
            let newEvent = CalendarEvent(
                title: event.title, startDate: occurrenceDate, endDate: event.endDate, allDay: event.allDay,
                eventDescription: event.eventDescription, color: event.color, meetingUrl: event.meetingUrl,
                location: event.location, recurrenceRRule: nil, timeZoneId: event.timeZoneId,
                recurrence: nil, recurrenceExceptions: [], calendarId: event.calendarId,
                serverId: nil, syncState: .newLocal, isRecurringSeriesMaster: false,
                isRecurrenceException: true, isCancelledOccurrence: false,
                parentSeriesLocalId: event.localEventId, splitFromSeriesLocalId: nil,
                originalOccurrenceDate: occurrenceDate, splitEffectiveFrom: nil,
                exceptionKind: .edited   // ← correct: .edited not .modified
            )
            newEvent.calendar = event.calendar
            return newEvent
        }

        private func splitSeriesAndCreateFuture(from event: CalendarEvent, splitDate: Date, newStart: Date, newEnd: Date?, selectedCalendar: EventCalendar?) {
            if let originalRule = event.recurrenceRRule {
                let body = originalRule.hasPrefix("RRULE:") ? String(originalRule.dropFirst("RRULE:".count)) : originalRule
                let previousDay = tzCalendar.date(byAdding: .day, value: -1, to: tzCalendar.startOfDay(for: splitDate)) ?? splitDate
                let parts = body.split(separator: ";").map(String.init).filter { !$0.uppercased().hasPrefix("UNTIL=") && !$0.uppercased().hasPrefix("COUNT=") }
                let c = tzCalendar.dateComponents([.year,.month,.day], from: previousDay)
                event.recurrenceRRule = (parts + [String(format: "UNTIL=%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)]).joined(separator: ";")
            }
            event.needsSync = true; event.syncState = .modifiedLocal; event.updatedAt = Date()
            let future = CalendarEvent(
                title: titleTrimmed, startDate: newStart, endDate: newEnd, allDay: allDay,
                eventDescription: eventDescription.nilIfBlank, color: eventColor,
                meetingUrl: meetingUrl.nilIfBlank, location: location.nilIfBlank,
                recurrenceRRule: buildRRule(), timeZoneId: displayTimeZone.identifier,
                recurrence: nil, recurrenceExceptions: [], calendarId: selectedCalendarId,
                serverId: nil, syncState: .newLocal, isRecurringSeriesMaster: recurrenceEnabled,
                isRecurrenceException: false, isCancelledOccurrence: false,
                parentSeriesLocalId: nil, splitFromSeriesLocalId: event.localEventId,
                originalOccurrenceDate: nil, splitEffectiveFrom: splitDate, exceptionKind: nil
            )
            future.calendar = selectedCalendar; modelContext.insert(future); updateReminder(for: future, eventStart: newStart)
        }
    } // end EventSheet
}

// MARK: - CalendarDayView UI extension

extension CalendarDayView {

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Button { prevDay() } label: {
                        Image("chevleft").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 14, height: 14).foregroundColor(.white).opacity(1)
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }.buttonStyle(.plain)

                    GradientTitle(text: headerTitle, font: .system(size: 24, weight: .bold))
                        .onTapGesture { onBack?() }

                    Button { nextDay() } label: {
                        Image("chevright").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 14, height: 14).foregroundColor(.white).opacity(1)
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Button { sheetConfig = EventSheetConfig(selectedDate: selectedDate, editingEvent: nil) } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1)).frame(width: 34, height: 34)
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    }
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, LSpacing.pageHorizontal).padding(.vertical, 16)
            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    private var allDaySection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text("All").font(.system(size: 18, weight: .bold)).foregroundStyle(LColors.accent)
                    Text("DAY").font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }.frame(width: 52).padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(allDayEvents) { instance in eventCard(instance) }
                    Button { sheetConfig = EventSheetConfig(selectedDate: selectedDate, editingEvent: nil) } label: {
                        HStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 11)); Text("Add event").font(.system(size: 13)) }
                            .foregroundStyle(LColors.textSecondary).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, LSpacing.pageHorizontal).padding(.vertical, 8)
            Rectangle().fill(LColors.glassBorder.opacity(0.4)).frame(height: 1).padding(.leading, 66 + LSpacing.pageHorizontal)
        }
    }

    private func hourRow(_ hour: Int) -> some View {
        let slotEvents = timedEvents(for: hour)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text(hourLabel(hour)).font(.system(size: 18, weight: .bold)).foregroundStyle(LColors.textPrimary)
                    Text(hourPeriod(hour)).font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }.frame(width: 52).padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    if slotEvents.isEmpty {
                        HStack {
                            Text("No events").font(.system(size: 14)).foregroundStyle(LColors.textSecondary.opacity(0.6))
                            Spacer()
                            Button { sheetConfig = EventSheetConfig(selectedDate: dateForHour(hour), editingEvent: nil) } label: {
                                Image(systemName: "plus").font(.system(size: 13)).foregroundStyle(LColors.accent)
                                    .frame(width: 28, height: 28).background(LColors.accent.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 12)
                    } else {
                        ForEach(slotEvents) { instance in eventCard(instance) }
                        Button { sheetConfig = EventSheetConfig(selectedDate: dateForHour(hour), editingEvent: nil) } label: {
                            HStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 11)); Text("Add event").font(.system(size: 13)) }
                                .foregroundStyle(LColors.textSecondary).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, LSpacing.pageHorizontal).padding(.vertical, 8)
            Rectangle().fill(LColors.glassBorder.opacity(0.4)).frame(height: 1).padding(.leading, 66 + LSpacing.pageHorizontal)
        }
    }

    private func eventCard(_ instance: DayEventInstance) -> some View {
        let event = instance.event
        let eventColor = Color(ly_hex: event.displayColor)
        let calendarName = event.calendar?.name ?? calendars.first(where: { $0.serverId == event.calendarId })?.name ?? ""

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(eventColor).frame(width: 4).padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if !calendarName.isEmpty {
                        Text(calendarName).font(.system(size: 11, weight: .bold)).foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.08)).clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    if event.reminderServerId != nil {
                        Image(systemName: "bell.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(LColors.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(LColors.accent.opacity(0.12)).clipShape(Capsule())
                    }
                    if event.allDay {
                        Text("All day").font(.system(size: 11, weight: .bold)).foregroundStyle(LColors.success)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(LColors.success.opacity(0.10)).clipShape(Capsule())
                    }
                }
                Text(event.title).font(.system(size: 14, weight: .bold)).foregroundStyle(LColors.textPrimary)
                if let desc = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                    Text(desc).font(.system(size: 12)).foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading).truncationMode(.tail).fixedSize(horizontal: false, vertical: true).lineLimit(4)
                }
                if !event.allDay {
                    Text(formatEventTime(event, occurrenceStart: instance.occurrenceStart, occurrenceEnd: instance.occurrenceEnd))
                        .font(.system(size: 12)).foregroundStyle(.white)
                }
                if event.recurrenceRRule != nil {
                    let parsedRecurrence = event.recurrenceRRule.flatMap { ParsedRRule.parse($0) }
                    HStack(spacing: 6) {
                        Text("Repeats").font(.system(size: 11, weight: .bold)).foregroundStyle(LColors.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.08)).clipShape(Capsule())
                        if let parsedRecurrence, parsedRecurrence.freq == .weekly {
                            Text("\(max(1, parsedRecurrence.interval))/W").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(LColors.accent.opacity(0.16)).clipShape(Capsule())
                                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                        }
                    }
                }
            }.padding(.leading, 10)
            Spacer()
            VStack(spacing: 8) {
                Button { sheetConfig = EventSheetConfig(selectedDate: instance.occurrenceStart, editingEvent: event) } label: {
                    Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(LColors.textPrimary.opacity(0.75))
                        .frame(width: 28, height: 28).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                }.buttonStyle(.plain)
                Button {
                    pendingDeleteEvent = event; pendingDeleteOccurrenceDate = instance.occurrenceStart
                    if event.recurrenceRRule != nil { showDeleteRecurringDialog = true } else { showDeleteEventDialog = true }
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(LColors.danger.opacity(0.75))
                        .frame(width: 28, height: 28).background(LColors.danger.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
        .padding(12).background(LColors.glassSurface).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            detailOverlayPayload = DayEventDetailOverlayPayload(event: event, occurrenceStart: instance.occurrenceStart, occurrenceEnd: instance.occurrenceEnd)
        }
    }

    private func timedEvents(for hour: Int) -> [DayEventInstance] {
        dayEvents.filter { !$0.event.allDay && tzCalendar.component(.hour, from: $0.occurrenceStart) == hour }
            .sorted { $0.occurrenceStart < $1.occurrenceStart }
    }

    private func dateForHour(_ hour: Int) -> Date {
        tzCalendar.date(byAdding: .hour, value: hour, to: tzCalendar.startOfDay(for: selectedDate)) ?? selectedDate
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour { case 0: return "12"; case 13...23: return "\(hour - 12)"; default: return "\(hour)" }
    }

    private func hourPeriod(_ hour: Int) -> String { hour < 12 ? "AM" : "PM" }
    private func prevDay() { selectedDate = tzCalendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate }
    private func nextDay() { selectedDate = tzCalendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate }

    private func formatEventTime(_ event: CalendarEvent, occurrenceStart: Date, occurrenceEnd: Date?) -> String {
        let df = DateFormatter(); df.timeZone = displayTimeZone; df.locale = .current
        df.setLocalizedDateFormatFromTemplate("h:mm a")
        let start = df.string(from: occurrenceStart)
        return occurrenceEnd.map { "\(start) – \(df.string(from: $0))" } ?? start
    }

    private func deleteReminder(withServerId id: String) {
        guard let targetUUID = UUID(uuidString: id) else { return }
        if let match = try? modelContext.fetch(FetchDescriptor<LystariaReminder>(predicate: #Predicate { $0.linkedHabitId == targetUUID })).first {
            modelContext.delete(match)
        }
    }

    private func inlineDeleteRecurring(scope: EventSheet.RecurringEditScope) {
        print("[CalendarDayView] INLINE DELETE called with scope:", scope.rawValue)
        print("[CalendarDayView] pendingDeleteEvent:", pendingDeleteEvent?.title ?? "nil")

        guard let event = pendingDeleteEvent else { return }
        let occurrenceDate = pendingDeleteOccurrenceDate ?? event.startDate
        switch scope {
        case .thisEventOnly:
            let cancelException = CalendarEvent(
                title: event.title, startDate: occurrenceDate, endDate: event.endDate, allDay: event.allDay,
                eventDescription: event.eventDescription, color: event.color, meetingUrl: event.meetingUrl,
                location: event.location, recurrenceRRule: nil, timeZoneId: event.timeZoneId,
                recurrence: nil, recurrenceExceptions: [], calendarId: event.calendarId,
                serverId: nil, syncState: .newLocal, isRecurringSeriesMaster: false,
                isRecurrenceException: true, isCancelledOccurrence: true,
                parentSeriesLocalId: event.localEventId, splitFromSeriesLocalId: nil,
                originalOccurrenceDate: occurrenceDate, splitEffectiveFrom: nil, exceptionKind: .cancelled
            )
            cancelException.calendar = event.calendar; modelContext.insert(cancelException)
            var exceptions = event.recurrenceExceptions
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]; df.timeZone = displayTimeZone
            let key = df.string(from: occurrenceDate)
            if !exceptions.contains(key) { exceptions.append(key); event.recurrenceExceptions = exceptions.sorted() }
            event.needsSync = true; event.syncState = .modifiedLocal; event.updatedAt = Date()

        case .thisAndFuture:
            if let originalRule = event.recurrenceRRule {
                let body = originalRule.hasPrefix("RRULE:") ? String(originalRule.dropFirst("RRULE:".count)) : originalRule
                let previousDay = tzCalendar.date(byAdding: .day, value: -1, to: tzCalendar.startOfDay(for: occurrenceDate)) ?? occurrenceDate
                let parts = body.split(separator: ";").map(String.init).filter { !$0.uppercased().hasPrefix("UNTIL=") && !$0.uppercased().hasPrefix("COUNT=") }
                let c = tzCalendar.dateComponents([.year,.month,.day], from: previousDay)
                event.recurrenceRRule = (parts + [String(format: "UNTIL=%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)]).joined(separator: ";")
            }
            event.needsSync = true; event.syncState = .modifiedLocal; event.updatedAt = Date()

        case .allEvents:
            if let rid = event.reminderServerId {
                NotificationManager.shared.cancelAllCalendarNotifications(id: rid); deleteReminder(withServerId: rid); event.reminderServerId = nil
            }
            let masterLocalId = event.localEventId
            let childDescriptor = FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.parentSeriesLocalId == masterLocalId })
            if let children = try? modelContext.fetch(childDescriptor) { for child in children { modelContext.delete(child) } }
            modelContext.delete(event)
        }
        do {
            try modelContext.save()
            print("[CalendarDayView] INLINE DELETE SAVE SUCCESS")
            pendingDeleteEvent = nil
            pendingDeleteOccurrenceDate = nil
        } catch {
            print("[CalendarDayView] INLINE DELETE SAVE FAILED:", error)
        }
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
