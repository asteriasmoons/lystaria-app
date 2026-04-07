// CalendarTabView.swift
// Lystaria

import SwiftUI
import SwiftData
import UIKit
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
    @Query(sort: [SortDescriptor(\EventCalendar.sortOrder), SortDescriptor(\EventCalendar.name)]) private var calendars: [EventCalendar]
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]

    @State private var currentMonth = Date()
    @State private var showingAddCalendarPopup = false
    @State private var selectedCalendarFilter: CalendarFilterOption = .all
    @State private var newCalendarName = ""
    @State private var newCalendarColor = "#5b8def"
    @State private var newCalendarColorUI: Color = Color(ly_hex: "#5b8def")
    @State private var sheetConfig: EventSheetConfig? = nil
    @State private var showingSettingsSheet = false
    @State private var detailOverlayPayload: EventDetailOverlayPayload?
    @State private var pendingDeleteEvent: CalendarEvent? = nil
    @State private var pendingDeleteOccurrenceDate: Date? = nil
    @State private var showDeleteEventDialog = false
    @State private var showDeleteRecurringDialog = false
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()
    @StateObject private var limits = LimitManager.shared

    @State private var showingDayView = false
    @State private var dayViewDate: Date = Date()

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

    /// Global display-order index for every event instance rendered this month.
    /// The first 20 instances (in day + time order) are free; the rest are locked.
    private var allowedEventIds: Set<String> {
        guard !limits.hasPremiumAccess else { return Set() }
        let instances = daysInMonth.flatMap { date -> [EventInstance] in
            let key = isoDayString(tzCalendar.startOfDay(for: date))
            return (eventsByDay[key] ?? []).sorted { $0.occurrenceStart < $1.occurrenceStart }
        }
        return Set(instances.prefix(20).map { $0.id })
    }

    enum CalendarFilterOption: Equatable {
        case all
        case calendar(String)
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
            print("[CalendarTabView] BUILD DAY:", key)
            // Snapshot each event's recurrence value safely before any UI access
            map[key] = computeEventsFor(date)
        }
        eventsByDay = map
    }

    private func computeEventsFor(_ date: Date) -> [EventInstance] {
        let filtered: [CalendarEvent] = {
            switch selectedCalendarFilter {
            case .all:
                return allEvents
            case .calendar(let id):
                return allEvents.filter { $0.calendarId == id }
            }
        }()

        let dayAnchor = tzCalendar.startOfDay(for: date)

        print("[CalendarTabView] INPUT DATE:", date)
        print("[CalendarTabView] DAY ANCHOR:", dayAnchor)
        print("[CalendarTabView] TZ:", displayTimeZone.identifier)

        let resolved = CalendarEventResolver.occurrences(
            on: dayAnchor,
            from: filtered,
            timeZone: displayTimeZone
        )

        print("[CalendarTabView] RESOLVED COUNT:", resolved.count)

        let ostaraResolved = resolved.filter {
            $0.title.localizedCaseInsensitiveContains("Ostara")
        }

        print("CHECKING DATE:", date, "resolved count:", resolved.count, "ostara count:", ostaraResolved.count)

        if !ostaraResolved.isEmpty {
            print("OSTARA RESOLVED ON:", date)
            for occ in ostaraResolved {
                print("  -> title:", occ.title)
                print("  -> start:", occ.startDate)
                print("  -> end:", String(describing: occ.endDate))
                print("  -> sourceEventId:", occ.sourceEventId)
            }
        } // End of ostaraResolved

        let eventById = Dictionary(allEvents.map { ($0.localEventId, $0) }, uniquingKeysWith: { _, last in last })

        print("[CalendarTabView] ALL EVENTS COUNT:", allEvents.count)
        for e in allEvents {
            print("  -> EVENT:", e.title, "| start:", e.startDate, "| rrule:", e.recurrenceRRule ?? "none")
        }

        return resolved.compactMap { occ -> EventInstance? in
            guard let event = eventById[occ.sourceEventId] else { return nil }
            return EventInstance(
                id: occ.id,
                event: event,
                occurrenceStart: occ.startDate,
                occurrenceEnd: occ.endDate
            )
        }
    }


    private func isoDayString(_ date: Date) -> String {
        let cal = tzCalendar
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 1970
        let m = c.month ?? 1
        let d = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
    
    private var createCalendarButtonBackground: AnyShapeStyle {
        let isEmpty = newCalendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue)
    }
    
    @ViewBuilder
    private var deleteRecurringDialogMessage: some View {
        Text("Choose how this recurring event should be deleted.")
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
                
                // Detail overlay as a true full-screen ZStack sibling
                if let payload = detailOverlayPayload {
                    CalendarEventDetailOverlay(
                        event: payload.event,
                        occurrenceStart: payload.occurrenceStart,
                        occurrenceEnd: payload.occurrenceEnd,
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                detailOverlayPayload = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(100)
                }
            }
            // FIX 5: Build the map on appear and whenever allEvents or the month changes.
            .onAppear {
                // Ensure at least one calendar exists
                if calendars.isEmpty {
                    let defaultCal = EventCalendar(
                        serverId: UUID().uuidString,
                        name: "My Calendar",
                        color: "#5b8def",
                        sortOrder: 0,
                        isDefault: true,
                        isSelectedInCalendarView: true
                    )
                    modelContext.insert(defaultCal)
                    try? modelContext.save()
                }
                
                // Assign existing events without a calendar
                if let defaultCal = calendars.first(where: { $0.isDefault }) {
                    let unassigned = allEvents.filter { $0.calendarId == nil }
                    
                    if !unassigned.isEmpty {
                        for e in unassigned {
                            e.calendarId = defaultCal.serverId
                            e.calendar = defaultCal
                        }
                        try? modelContext.save()
                    }
                }
                
                // Build UI map
                rebuildEventsByDay()

                // One-shot dedup: purge exact-duplicate non-exception events
                // (same title + same startDate), keeping the oldest by createdAt.
                // Runs in a Task so it fires after the initial render settles.
                Task { @MainActor in
                    let cal = tzCalendar
                    let nonExceptions = allEvents.filter { !$0.isRecurrenceException }
                    var seen: [String: CalendarEvent] = [:]
                    var deleted = false
                    for event in nonExceptions.sorted(by: { $0.createdAt < $1.createdAt }) {
                        // Key on title + rrule + time-of-day (ignore date for recurring,
                        // use full date for non-recurring) so yearly events on different
                        // calendar dates still deduplicate correctly.
                        let key: String
                        if let rrule = event.recurrenceRRule, !rrule.isEmpty,
                           let parsed = ParsedRRule.parse(rrule) {
                            // For recurring events key on title + frequency only.
                            // This catches duplicates where each copy has a slightly
                            // different startDate (and thus different BYMONTHDAY etc).
                            key = "\(event.title)|recurring|\(parsed.freq.rawValue)"
                        } else {
                            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: event.startDate)
                            key = "\(event.title)|\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)T\(comps.hour ?? 0):\(comps.minute ?? 0)"
                        }
                        if seen[key] != nil {
                            modelContext.delete(event)
                            deleted = true
                        } else {
                            seen[key] = event
                        }
                    }
                    if deleted {
                        try? modelContext.save()
                        rebuildEventsByDay()
                    }
                }
            }
            .onChange(of: allEvents) { _, _ in
                rebuildEventsByDay()
            }
            .onChange(of: currentMonth) { _, _ in
                rebuildEventsByDay()
            }
            .onChange(of: selectedCalendarFilter) { _, _ in
                rebuildEventsByDay()
            }
            .onChange(of: calendars.count) { _, _ in
                rebuildEventsByDay()
            }
            .navigationDestination(isPresented: $showingDayView) {
                CalendarDayView(selectedDate: dayViewDate, onBack: { showingDayView = false })
                    .navigationBarHidden(true)
            }
            .overlay {
                if let config = sheetConfig {
                    EventSheet(
                        onClose: {
                            sheetConfig = nil
                            rebuildEventsByDay()
                        },
                        selectedDate: config.selectedDate,
                        editingEvent: config.editingEvent
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(70)
                }
            }
            .overlay {
                if showingAddCalendarPopup {
                    LystariaOverlayPopup(
                        onClose: {
                            showingAddCalendarPopup = false
                            newCalendarName = ""
                        },
                        width: 560,
                        heightRatio: 0.70,
                        header: {
                            HStack {
                                GradientTitle(text: "New Calendar", font: .title2.bold())
                                Spacer()
                                Button {
                                    showingAddCalendarPopup = false
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
                                CalendarLabeledGlassField(label: "NAME") {
                                    TextField("Calendar name", text: $newCalendarName)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("COLOR")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.5)
                                    
                                    ColorPicker("", selection: $newCalendarColorUI, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: newCalendarColorUI) { _, newColor in
                                            newCalendarColor = newColor.toHexString()
                                        }
                                }
                            }
                        },
                        footer: {
                            Button {
                                saveNewCalendar()
                            } label: {
                                Text("Create Calendar")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(createCalendarButtonBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                            }
                            .buttonStyle(.plain)
                            .disabled(newCalendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(80)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sheetConfig != nil)
            
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                ZStack {
                    OnboardingOverlay(anchors: anchors)
                        .environmentObject(onboarding)
                }
                .task(id: anchors.count) {
                    if anchors.count > 0 {
                        onboarding.start(page: OnboardingPages.calendar)
                    }
                }
            }
            .lystariaAlertConfirm(
                isPresented: $showDeleteEventDialog,
                title: "Delete event?",
                message: "This will permanently delete this event.",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                if let event = pendingDeleteEvent {
                    if let rid = event.reminderServerId {
                        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
                        deleteReminder(withServerId: rid)
                        event.reminderServerId = nil
                    }
                    modelContext.delete(event)
                    pendingDeleteEvent = nil
                    pendingDeleteOccurrenceDate = nil
                    rebuildEventsByDay()
                }
            }
            .confirmationDialog(
                            "Delete recurring event",
                            isPresented: $showDeleteRecurringDialog,
                            titleVisibility: .visible
                        ) {
                            Button("This Event Only", role: .destructive) {
                                inlineDeleteRecurring(scope: .thisEventOnly)
                            }
                            Button("This and Future", role: .destructive) {
                                inlineDeleteRecurring(scope: .thisAndFuture)
                            }
                            Button("All Events", role: .destructive) {
                                inlineDeleteRecurring(scope: .allEvents)
                            }
                            Button("Cancel", role: .cancel) {
                                pendingDeleteEvent = nil
                                pendingDeleteOccurrenceDate = nil
                            }
                        } message: {
                            deleteRecurringDialogMessage
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
                        .onTapGesture {
                            dayViewDate = Date()
                            showingDayView = true
                        }
                    
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
                
                // FILTER DROPDOWN
                Menu {
                    Button("All") {
                        selectedCalendarFilter = .all
                    }

                    ForEach(calendars) { calendar in
                        Button(calendar.name) {
                            selectedCalendarFilter = .calendar(calendar.serverId)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)


                // ADD CALENDAR BUTTON
                Button {
                    showingAddCalendarPopup = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                
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
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, instance in
                            eventCard(instance)
                                .premiumLocked(!limits.hasPremiumAccess && !allowedEventIds.contains(instance.id))
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
        let calendarName =
            event.calendar?.name
            ?? calendars.first(where: { $0.serverId == event.calendarId })?.name
            ?? ""
        let hasCalendar = !calendarName.isEmpty
        
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 4)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if hasCalendar {
                        Text(calendarName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }

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
                
            }
            .padding(.leading, 10)
            
            Spacer()
            
            VStack(spacing: 8) {
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
                    pendingDeleteEvent = event
                    pendingDeleteOccurrenceDate = instance.occurrenceStart
                    if event.recurrenceRRule != nil {
                        showDeleteRecurringDialog = true
                    } else {
                        showDeleteEventDialog = true
                    }
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
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            detailOverlayPayload = EventDetailOverlayPayload(
                event: event,
                occurrenceStart: instance.occurrenceStart,
                occurrenceEnd: instance.occurrenceEnd
            )
        }
    }

    private func inlineDeleteRecurring(scope: EventSheet.RecurringEditScope) {
        guard let event = pendingDeleteEvent else { return }
        let occurrenceDate = pendingDeleteOccurrenceDate ?? event.startDate

        switch scope {
        case .thisEventOnly:
            let cancelException = CalendarEvent(
                title: event.title,
                startDate: occurrenceDate,
                endDate: event.endDate,
                allDay: event.allDay,
                eventDescription: event.eventDescription,
                color: event.color,
                meetingUrl: event.meetingUrl,
                location: event.location,
                recurrenceRRule: nil,
                timeZoneId: event.timeZoneId,
                recurrence: nil,
                recurrenceExceptions: [],
                calendarId: event.calendarId,
                serverId: nil,
                syncState: .newLocal,
                isRecurringSeriesMaster: false,
                isRecurrenceException: true,
                isCancelledOccurrence: true,
                parentSeriesLocalId: event.localEventId,
                splitFromSeriesLocalId: nil,
                originalOccurrenceDate: occurrenceDate,
                splitEffectiveFrom: nil,
                exceptionKind: .cancelled
            )
            cancelException.calendar = event.calendar
            modelContext.insert(cancelException)

            var exceptions = event.recurrenceExceptions
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
            df.timeZone = displayTimeZone
            let key = df.string(from: occurrenceDate)
            if !exceptions.contains(key) {
                exceptions.append(key)
                event.recurrenceExceptions = exceptions.sorted()
            }
            event.needsSync = true
            event.syncState = .modifiedLocal
            event.updatedAt = Date()

        case .thisAndFuture:
            if let originalRule = event.recurrenceRRule {
                let body = originalRule.hasPrefix("RRULE:") ? String(originalRule.dropFirst("RRULE:".count)) : originalRule
                let previousDay = tzCalendar.date(byAdding: .day, value: -1, to: tzCalendar.startOfDay(for: occurrenceDate)) ?? occurrenceDate
                let parts = body
                    .split(separator: ";")
                    .map(String.init)
                    .filter { !$0.uppercased().hasPrefix("UNTIL=") && !$0.uppercased().hasPrefix("COUNT=") }
                let c = tzCalendar.dateComponents([.year, .month, .day], from: previousDay)
                let until = String(format: "UNTIL=%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
                event.recurrenceRRule = (parts + [until]).joined(separator: ";")
            }
            event.needsSync = true
            event.syncState = .modifiedLocal
            event.updatedAt = Date()

        case .allEvents:
            if let rid = event.reminderServerId {
                NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
                deleteReminder(withServerId: rid)
                event.reminderServerId = nil
            }
            let masterLocalId = event.localEventId
            let childDescriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.parentSeriesLocalId == masterLocalId }
            )
            if let children = try? modelContext.fetch(childDescriptor) {
                for child in children { modelContext.delete(child) }
            }
            modelContext.delete(event)
        }

        try? modelContext.save()
        pendingDeleteEvent = nil
        pendingDeleteOccurrenceDate = nil
        rebuildEventsByDay()
    }

    private func deleteReminder(withServerId id: String) {
        // rid is stored in linkedHabitId (UUID) since LystariaReminder has no serverId field.
        guard let targetUUID = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<LystariaReminder>(
            predicate: #Predicate { $0.linkedHabitId == targetUUID }
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
    private func saveNewCalendar() {
        // Enforce calendar limit (3 total for free users)
        let descriptor = FetchDescriptor<EventCalendar>()
        let existingCalendars = (try? modelContext.fetch(descriptor)) ?? []
        let decision = limits.canCreate(.calendarsTotal, currentCount: existingCalendars.count)
        guard decision.allowed else { return }
        let trimmed = newCalendarName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (calendars.map { $0.sortOrder }.max() ?? -1) + 1

        let calendar = EventCalendar(
            serverId: UUID().uuidString,
            name: trimmed,
            color: newCalendarColor,
            sortOrder: nextOrder,
            isDefault: false,
            isSelectedInCalendarView: true
        )

        modelContext.insert(calendar)
        if calendars.isEmpty {
            calendar.isDefault = true
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save calendar: \(error)")
        }

        newCalendarName = ""
        showingAddCalendarPopup = false
    }

    private struct EventDetailOverlayPayload: Identifiable {
        let id = UUID()
        let event: CalendarEvent
        let occurrenceStart: Date
        let occurrenceEnd: Date?
    }
}


// MARK: - Event Sheet (New/Edit)

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

    enum RecurringEditScope: String, Identifiable {
        case thisEventOnly
        case allEvents
        case thisAndFuture

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
        case never
        case afterCount
        case onDate
        var id: String { rawValue }
    }

    @State private var recurrenceEndMode: RecurrenceEndMode = .never
    @State private var recurrenceCount: Int = 10
    @State private var recurrenceUntilDay: Date = Date()
    @State private var showRecurringEditScopeDialog = false
    @State private var showDeleteConfirm = false
    @State private var showRecurringDeleteScopeDialog = false

    private let colorOptions = ["#5b8def","#a855f7","#ec4899","#4caf50","#ff9800","#f44336","#00dbff"]

    private var weekdayOptions: [(Int, String)] {
        [(1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday"), (6, "Friday"), (7, "Saturday")]
    }

    private var monthOptions: [(Int, String)] {
        [(1, "January"), (2, "February"), (3, "March"), (4, "April"), (5, "May"), (6, "June"), (7, "July"), (8, "August"), (9, "September"), (10, "October"), (11, "November"), (12, "December")]
    }

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var closeAction: () -> Void {
        onClose ?? {}
    }

    private var isEditingRecurringSeries: Bool {
        guard let editingEvent else { return false }
        return !editingEvent.isRecurrenceException && (editingEvent.isRecurringSeriesMaster || editingEvent.recurrenceRRule != nil)
    }

    private var isEditingOccurrenceFromSeries: Bool {
        guard let editingEvent, isEditingRecurringSeries else { return false }
        return abs(selectedDate.timeIntervalSince(editingEvent.startDate)) > 60
    }

    private var canDeleteCurrentEvent: Bool {
        editingEvent != nil
    }

    private var occurrenceAnchorDate: Date {
        guard let editingEvent else { return selectedDate }
        if isEditingOccurrenceFromSeries {
            return selectedDate
        }
        return editingEvent.startDate
    }

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }
    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    var body: some View {
        LystariaFullScreenForm(
            title: editingEvent != nil ? "Edit Event" : "New Event",
            onCancel: { closeAction() },
            canSave: !titleTrimmed.isEmpty,
            onSave: { handleSaveTapped() }
        ) {
            formContent
        }
        .onAppear { loadInitialState() }
        .sheet(isPresented: $showLocationSearchSheet) {
            LocationSearchSheet { displayName, _, _ in
                location = displayName
            }
        }
        .confirmationDialog(
            "Apply changes to recurring event",
            isPresented: $showRecurringEditScopeDialog,
            titleVisibility: .visible
        ) {
            Button(RecurringEditScope.thisEventOnly.title) {
                save(editScope: .thisEventOnly)
            }
            Button(RecurringEditScope.allEvents.title) {
                save(editScope: .allEvents)
            }
            Button(RecurringEditScope.thisAndFuture.title) {
                save(editScope: .thisAndFuture)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how these changes should apply to this recurring event.")
        }
        .lystariaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete event?",
            message: "This event will be removed.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            performDelete(scope: .allEvents)
        }
        .confirmationDialog(
            "Delete recurring event",
            isPresented: $showRecurringDeleteScopeDialog,
            titleVisibility: .visible
        ) {
            Button(RecurringEditScope.thisEventOnly.title, role: .destructive) {
                performDelete(scope: .thisEventOnly)
            }
            Button(RecurringEditScope.allEvents.title, role: .destructive) {
                performDelete(scope: .allEvents)
            }
            Button(RecurringEditScope.thisAndFuture.title, role: .destructive) {
                performDelete(scope: .thisAndFuture)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how this recurring event should be deleted.")
        }
    }

    private var formContent: some View {
        VStack(spacing: 16) {
                CalendarControlRow(label: "Calendar") {
                    Picker("", selection: $selectedCalendarId) {
                        Text("No Calendar").tag(nil as String?)
                        ForEach(calendars) { calendar in
                            Text(calendar.name).tag(Optional(calendar.serverId))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: selectedCalendarId) { _, newValue in
                        if let id = newValue,
                           let selectedCalendar = calendars.first(where: { $0.serverId == id }) {
                            eventColor = selectedCalendar.color
                            eventColorUI = Color(ly_hex: selectedCalendar.color)
                        }
                    }
                }

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

                            VStack(alignment: .leading, spacing: 8) {
                                Text("INTERVAL")
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

                                    Text("Every \(recurrenceInterval) \(recurrenceInterval == 1 ? unitLabel(for: recurrenceFreq) : unitLabel(for: recurrenceFreq) + "s")")
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
                                        recurrenceInterval = min(365, recurrenceInterval + 1)
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
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Add location (optional)", text: $location)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)

                        HStack(spacing: 10) {
                            Button {
                                showLocationSearchSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Search Place")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("LystariaUseCurrentLocation"), object: nil)
                                showLocationSearchSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Current Location")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
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
                }

                CalendarLabeledGlassField(label: "LINK") {
                    TextField("Add link (optional)", text: $meetingUrl)
                        .textFieldStyle(.plain)
                        .foregroundStyle(LColors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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

                if canDeleteCurrentEvent {
                    LButton(
                        title: "Delete Event",
                        icon: "trash",
                        style: .danger,
                        action: { handleDeleteTapped() }
                    )
                    .padding(.top, 4)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private func loadInitialState() {
        if let e = editingEvent {
            title = e.title
            allDay = e.allDay
            location = e.location ?? ""
            meetingUrl = e.meetingUrl ?? ""
            eventDescription = e.eventDescription ?? ""
            eventColor = e.color ?? "#5b8def"
            eventColorUI = Color(ly_hex: eventColor)
            selectedCalendarId = e.calendarId

            let editingStart = occurrenceAnchorDate
            startDay = editingStart
            startTime = editingStart

            if let end = e.endDate {
                let duration = end.timeIntervalSince(e.startDate)
                let resolvedEnd = duration > 0 ? editingStart.addingTimeInterval(duration) : end
                endDay = resolvedEnd
                endTime = resolvedEnd
            } else {
                let end = tzCalendar.date(byAdding: .hour, value: 1, to: editingStart) ?? editingStart
                endDay = end
                endTime = end
            }

            if let rid = e.reminderServerId, let r = findReminder(serverId: rid) {
                reminderEnabled = true
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
            meetingUrl = ""
            eventDescription = ""
            // Set color to selected calendar color if possible, else fallback
            if let defaultCal = calendars.first(where: { $0.isDefault }) ?? calendars.first {
                eventColor = defaultCal.color
                eventColorUI = Color(ly_hex: defaultCal.color)
            } else {
                eventColor = "#5b8def"
                eventColorUI = Color(ly_hex: eventColor)
            }

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
            if let defaultCal = calendars.first(where: { $0.isDefault }) {
                selectedCalendarId = defaultCal.serverId
            } else {
                selectedCalendarId = calendars.first?.serverId
            }
            if let id = selectedCalendarId,
               let selectedCalendar = calendars.first(where: { $0.serverId == id }) {
                eventColor = selectedCalendar.color
                eventColorUI = Color(ly_hex: selectedCalendar.color)
            }
        }
    }

    private func findReminder(serverId: String) -> LystariaReminder? {
        guard let targetUUID = UUID(uuidString: serverId) else { return nil }
        let descriptor = FetchDescriptor<LystariaReminder>(
            predicate: #Predicate { $0.linkedHabitId == targetUUID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func handleSaveTapped() {
        if isEditingRecurringSeries {
            showRecurringEditScopeDialog = true
        } else {
            save(editScope: .allEvents)
        }
    }

    private func recurringExceptionDateKey(_ date: Date) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        df.timeZone = displayTimeZone
        return df.string(from: date)
    }

    private func applyingUntil(_ rrule: String, before splitDate: Date) -> String {
        let body = rrule.hasPrefix("RRULE:") ? String(rrule.dropFirst("RRULE:".count)) : rrule
        let previousDay = tzCalendar.date(byAdding: .day, value: -1, to: tzCalendar.startOfDay(for: splitDate)) ?? splitDate
        let parts = body
            .split(separator: ";")
            .map(String.init)
            .filter { !$0.uppercased().hasPrefix("UNTIL=") && !$0.uppercased().hasPrefix("COUNT=") }

        let c = tzCalendar.dateComponents([.year, .month, .day], from: previousDay)
        let y = c.year ?? 1970
        let m = c.month ?? 1
        let d = c.day ?? 1
        let until = String(format: "UNTIL=%04d%02d%02d", y, m, d)

        return (parts + [until]).joined(separator: ";")
    }
    

    private func save(editScope: RecurringEditScope) {
        let cleanTitle      = titleTrimmed
        let cleanLocation   = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMeetingUrl = meetingUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc       = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAllDay        = allDay
        let chosenColor: String = {
            if let id = selectedCalendarId,
               let selectedCalendar = calendars.first(where: { $0.serverId == id }) {
                return selectedCalendar.color
            }
            return eventColorUI.toHexString()
        }()
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
                    let dayOfMonth = tzCalendar.component(.day, from: start)
                    components.append("BYMONTHDAY=\(dayOfMonth)")
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
                    let month = tzCalendar.component(.month, from: start)
                    let day = tzCalendar.component(.day, from: start)
                    components.append("BYMONTH=\(month)")
                    components.append("BYMONTHDAY=\(day)")
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

        let existingReminderId: String? = editingEvent?.reminderServerId

        let targetEvent: CalendarEvent
        if editingEvent == nil {
            let descriptor = FetchDescriptor<CalendarEvent>()
            let existingEvents = (try? modelContext.fetch(descriptor)) ?? []
            let decision = limits.canCreate(.calendarEventsTotal, currentCount: existingEvents.count)
            guard decision.allowed else { return }
        }
        if let e = editingEvent {
            switch editScope {
            case .allEvents:
                e.title = cleanTitle
                e.allDay = isAllDay
                e.startDate = start
                e.endDate = end
                e.location = cleanLocation.isEmpty ? nil : cleanLocation
                e.meetingUrl = cleanMeetingUrl.isEmpty ? nil : cleanMeetingUrl
                e.eventDescription = cleanDesc.isEmpty ? nil : cleanDesc
                e.color = chosenColor
                e.updatedAt = Date()
                e.recurrenceRRule = resolvedRRule
                e.timeZoneId = NotificationManager.shared.effectiveTimezoneID
                e.calendarId = selectedCalendarId
                e.needsSync = true
                e.syncState = .modifiedLocal
                e.isRecurringSeriesMaster = recurrenceEnabled || e.isRecurringSeriesMaster
                if let id = selectedCalendarId {
                    e.calendar = calendars.first(where: { $0.serverId == id })
                } else {
                    e.calendar = nil
                }
                targetEvent = e

            case .thisEventOnly:
                let exceptionDate = occurrenceAnchorDate
                let exception = CalendarEvent(
                    title: cleanTitle,
                    startDate: start,
                    endDate: end,
                    allDay: isAllDay,
                    eventDescription: cleanDesc.isEmpty ? nil : cleanDesc,
                    color: chosenColor,
                    meetingUrl: cleanMeetingUrl.isEmpty ? nil : cleanMeetingUrl,
                    location: cleanLocation.isEmpty ? nil : cleanLocation,
                    recurrenceRRule: nil,
                    timeZoneId: NotificationManager.shared.effectiveTimezoneID,
                    recurrence: nil,
                    recurrenceExceptions: [],
                    calendarId: selectedCalendarId,
                    serverId: nil,
                    syncState: .newLocal,
                    isRecurringSeriesMaster: false,
                    isRecurrenceException: true,
                    isCancelledOccurrence: false,
                    parentSeriesLocalId: e.localEventId,
                    splitFromSeriesLocalId: nil,
                    originalOccurrenceDate: exceptionDate,
                    splitEffectiveFrom: nil,
                    exceptionKind: start == exceptionDate ? .edited : .moved
                )
                if let id = selectedCalendarId {
                    exception.calendar = calendars.first(where: { $0.serverId == id })
                }
                modelContext.insert(exception)

                var exceptions = e.recurrenceExceptions
                let key = recurringExceptionDateKey(exceptionDate)
                if !exceptions.contains(key) {
                    exceptions.append(key)
                    e.recurrenceExceptions = exceptions.sorted()
                }
                e.updatedAt = Date()
                e.needsSync = true
                e.syncState = .modifiedLocal
                targetEvent = exception

            case .thisAndFuture:
                let splitDate = occurrenceAnchorDate
                if let originalRule = e.recurrenceRRule {
                    e.recurrenceRRule = applyingUntil(originalRule, before: splitDate)
                }
                e.updatedAt = Date()
                e.needsSync = true
                e.syncState = .modifiedLocal

                let splitEvent = CalendarEvent(
                    title: cleanTitle,
                    startDate: start,
                    endDate: end,
                    allDay: isAllDay,
                    eventDescription: cleanDesc.isEmpty ? nil : cleanDesc,
                    color: chosenColor,
                    meetingUrl: cleanMeetingUrl.isEmpty ? nil : cleanMeetingUrl,
                    location: cleanLocation.isEmpty ? nil : cleanLocation,
                    recurrenceRRule: resolvedRRule,
                    timeZoneId: NotificationManager.shared.effectiveTimezoneID,
                    recurrence: nil,
                    recurrenceExceptions: [],
                    calendarId: selectedCalendarId,
                    serverId: nil,
                    syncState: .newLocal,
                    isRecurringSeriesMaster: recurrenceEnabled,
                    isRecurrenceException: true,
                    isCancelledOccurrence: false,
                    parentSeriesLocalId: e.localEventId,
                    splitFromSeriesLocalId: e.localEventId,
                    originalOccurrenceDate: splitDate,
                    splitEffectiveFrom: splitDate,
                    exceptionKind: .split
                )
                if let id = selectedCalendarId {
                    splitEvent.calendar = calendars.first(where: { $0.serverId == id })
                }
                modelContext.insert(splitEvent)
                targetEvent = splitEvent
            }
        } else {
            let e = CalendarEvent(
                title: cleanTitle,
                startDate: start,
                endDate: end,
                allDay: isAllDay,
                eventDescription: cleanDesc.isEmpty ? nil : cleanDesc,
                color: chosenColor,
                meetingUrl: cleanMeetingUrl.isEmpty ? nil : cleanMeetingUrl,
                location: cleanLocation.isEmpty ? nil : cleanLocation,
                recurrenceRRule: resolvedRRule,
                timeZoneId: NotificationManager.shared.effectiveTimezoneID,
                recurrence: nil,
                recurrenceExceptions: [],
                calendarId: selectedCalendarId,
                serverId: nil,
                syncState: .newLocal,
                isRecurringSeriesMaster: recurrenceEnabled,
                isRecurrenceException: false,
                isCancelledOccurrence: false,
                parentSeriesLocalId: nil,
                splitFromSeriesLocalId: nil,
                originalOccurrenceDate: nil,
                splitEffectiveFrom: nil,
                exceptionKind: nil
            )
            modelContext.insert(e)
            if let id = selectedCalendarId {
                e.calendar = calendars.first(where: { $0.serverId == id })
            } else {
                e.calendar = nil
            }
            targetEvent = e
        }

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
            resolvedExceptions: editingEvent?.recurrenceExceptions ?? []
        )

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save event: \(error)")
        }

        closeAction()
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

            return .once
        }

        guard let runAt = resolvedRunAt else {
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

        let rid: String = existingReminderId ?? {
            let new = UUID().uuidString
            event.reminderServerId = new
            return new
        }()
        if existingReminderId == nil {
            event.reminderServerId = rid
        }

        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)

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
            r.linkedHabitId = UUID(uuidString: rid)
            r.updatedAt = Date()
        } else {
            let r = LystariaReminder(
                title: title,
                status: .scheduled,
                nextRunAt: runAt,
                schedule: computedSchedule,
                timezone: NotificationManager.shared.effectiveTimezoneID
            )
            modelContext.insert(r)
            r.details = desc
            r.linkedKindRaw = "event"
            r.linkedHabitId = UUID(uuidString: rid)
            r.updatedAt = Date()
        }

        NotificationManager.shared.requestPermissionIfNeeded()
        debugDumpPendingNotifications(tag: "after requestPermission", filterId: rid)

        if let rule = resolvedRule {
            NotificationManager.shared.scheduleRecurringCalendarEvent(
                id: rid,
                title: title,
                body: bodyText,
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

    private func handleDeleteTapped() {
        if isEditingRecurringSeries {
            showRecurringDeleteScopeDialog = true
        } else {
            showDeleteConfirm = true
        }
    }

    private func performDelete(scope: RecurringEditScope) {
        guard let event = editingEvent else { return }

        switch scope {
        case .allEvents:
            deleteReminderIfNeeded(for: event)
            event.syncState = .pendingDeleteLocal
            event.needsSync = true
            event.updatedAt = Date()
            modelContext.delete(event)

        case .thisEventOnly:
            let exceptionDate = occurrenceAnchorDate

            let cancelException = CalendarEvent(
                title: event.title,
                startDate: exceptionDate,
                endDate: event.endDate,
                allDay: event.allDay,
                eventDescription: event.eventDescription,
                color: event.color,
                meetingUrl: event.meetingUrl,
                location: event.location,
                recurrenceRRule: nil,
                timeZoneId: event.timeZoneId,
                recurrence: nil,
                recurrenceExceptions: [],
                calendarId: event.calendarId,
                serverId: nil,
                syncState: .newLocal,
                isRecurringSeriesMaster: false,
                isRecurrenceException: true,
                isCancelledOccurrence: true,
                parentSeriesLocalId: event.localEventId,
                splitFromSeriesLocalId: nil,
                originalOccurrenceDate: exceptionDate,
                splitEffectiveFrom: nil,
                exceptionKind: .cancelled
            )
            cancelException.calendar = event.calendar
            modelContext.insert(cancelException)

            var exceptions = event.recurrenceExceptions
            let key = recurringExceptionDateKey(exceptionDate)
            if !exceptions.contains(key) {
                exceptions.append(key)
                event.recurrenceExceptions = exceptions.sorted()
            }
            event.needsSync = true
            event.syncState = .modifiedLocal
            event.updatedAt = Date()

        case .thisAndFuture:
            let splitDate = occurrenceAnchorDate
            if let originalRule = event.recurrenceRRule {
                event.recurrenceRRule = applyingUntil(originalRule, before: splitDate)
            }
            event.needsSync = true
            event.syncState = .modifiedLocal
            event.updatedAt = Date()

            let splitDeletionMarker = CalendarEvent(
                title: event.title,
                startDate: splitDate,
                endDate: event.endDate,
                allDay: event.allDay,
                eventDescription: event.eventDescription,
                color: event.color,
                meetingUrl: event.meetingUrl,
                location: event.location,
                recurrenceRRule: nil,
                timeZoneId: event.timeZoneId,
                recurrence: nil,
                recurrenceExceptions: [],
                calendarId: event.calendarId,
                serverId: nil,
                syncState: .newLocal,
                isRecurringSeriesMaster: false,
                isRecurrenceException: true,
                isCancelledOccurrence: true,
                parentSeriesLocalId: event.localEventId,
                splitFromSeriesLocalId: event.localEventId,
                originalOccurrenceDate: splitDate,
                splitEffectiveFrom: splitDate,
                exceptionKind: .split
            )
            splitDeletionMarker.calendar = event.calendar
            modelContext.insert(splitDeletionMarker)
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete event: \(error)")
        }

        closeAction()
    }

    private func deleteReminderIfNeeded(for event: CalendarEvent) {
        guard let rid = event.reminderServerId else { return }
        NotificationManager.shared.cancelAllCalendarNotifications(id: rid)
        if let reminder = findReminder(serverId: rid) {
            modelContext.delete(reminder)
        }
        event.reminderServerId = nil
    }
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

struct ResolvedCalendarOccurrence: Identifiable, Hashable {
    let id: String
    let sourceEventId: String
    let originalOccurrenceDate: Date?
    let startDate: Date
    let endDate: Date?
    let allDay: Bool
    let title: String
    let color: String?
    let eventDescription: String?
    let location: String?
    let meetingUrl: String?
    let calendarId: String?
    let isException: Bool
    let isCancelled: Bool
}

enum CalendarEventResolver {
    static func occurrences(on day: Date, from events: [CalendarEvent], timeZone: TimeZone? = nil) -> [ResolvedCalendarOccurrence] {
        let tz = timeZone ?? CalendarCompute.displayTimeZone
        var cal = Calendar.current
        cal.timeZone = tz

        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let masters = events.filter { !$0.isRecurrenceException }
        let exceptions = events.filter { $0.isRecurrenceException }

        let exceptionsByParent = Dictionary(grouping: exceptions) { $0.parentSeriesLocalId ?? "" }

        var resolved: [ResolvedCalendarOccurrence] = []

        for master in masters {
            let masterExceptions = exceptionsByParent[master.localEventId] ?? []

            if master.recurrenceRRule == nil {
                if occursInRange(start: master.startDate, end: master.endDate, dayStart: dayStart, dayEnd: dayEnd, calendar: cal) {
                    resolved.append(makeOccurrence(from: master, startDate: master.startDate, endDate: master.endDate, originalOccurrenceDate: nil, isException: false, isCancelled: false))
                }
                continue
            }

            guard let rrule = master.recurrenceRRule,
                  let parsed = ParsedRRule.parse(rrule) else {
                continue
            }

            if hasSplitBlocking(masterExceptions: masterExceptions, on: dayStart, calendar: cal) {
                continue
            }

            guard recurringMaster(master, occursOn: dayStart, parsed: parsed, calendar: cal) else {
                continue
            }

            let occurrenceStart = occurrenceDate(for: dayStart, matching: master.startDate, calendar: cal, allDay: master.allDay)
            let occurrenceEnd: Date? = {
                guard let end = master.endDate else { return nil }
                let duration = end.timeIntervalSince(master.startDate)
                return occurrenceStart.addingTimeInterval(duration)
            }()

            let matchingExceptions = masterExceptions.filter {
                guard let original = $0.originalOccurrenceDate else { return false }
                return cal.isDate(original, inSameDayAs: dayStart)
            }

            if let cancelled = matchingExceptions.first(where: { $0.isCancelledOccurrence }) {
                resolved.append(makeOccurrence(from: cancelled, startDate: occurrenceStart, endDate: occurrenceEnd, originalOccurrenceDate: cancelled.originalOccurrenceDate, isException: true, isCancelled: true))
                continue
            }

            if let replacement = matchingExceptions.first(where: { !$0.isCancelledOccurrence }) {
                if occursInRange(start: replacement.startDate, end: replacement.endDate, dayStart: dayStart, dayEnd: dayEnd, calendar: cal) {
                    resolved.append(makeOccurrence(from: replacement, startDate: replacement.startDate, endDate: replacement.endDate, originalOccurrenceDate: replacement.originalOccurrenceDate, isException: true, isCancelled: false))
                }
                continue
            }

            resolved.append(makeOccurrence(from: master, startDate: occurrenceStart, endDate: occurrenceEnd, originalOccurrenceDate: occurrenceStart, isException: false, isCancelled: false))
        }

        return resolved
            .filter { !$0.isCancelled }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private static func makeOccurrence(
        from event: CalendarEvent,
        startDate: Date,
        endDate: Date?,
        originalOccurrenceDate: Date?,
        isException: Bool,
        isCancelled: Bool
    ) -> ResolvedCalendarOccurrence {
        let originalKey: String = {
            guard let originalOccurrenceDate else { return "base" }
            return ISO8601DateFormatter().string(from: originalOccurrenceDate)
        }()

        return ResolvedCalendarOccurrence(
            id: "\(event.localEventId)|\(originalKey)|\(isException ? "exception" : "base")",
            sourceEventId: event.localEventId,
            originalOccurrenceDate: originalOccurrenceDate,
            startDate: startDate,
            endDate: endDate,
            allDay: event.allDay,
            title: event.title,
            color: event.color,
            eventDescription: event.eventDescription,
            location: event.location,
            meetingUrl: event.meetingUrl,
            calendarId: event.calendarId,
            isException: isException,
            isCancelled: isCancelled
        )
    }

    private static func occursInRange(start: Date, end: Date?, dayStart: Date, dayEnd: Date, calendar: Calendar) -> Bool {
        if calendar.isDate(start, inSameDayAs: dayStart) { return true }
        if let end {
            return start < dayEnd && end > dayStart
        }
        return false
    }

    private static func hasSplitBlocking(masterExceptions: [CalendarEvent], on day: Date, calendar: Calendar) -> Bool {
        masterExceptions.contains { exception in
            guard exception.exceptionKind == .split,
                  exception.isCancelledOccurrence,
                  let splitFrom = exception.splitEffectiveFrom ?? exception.originalOccurrenceDate else {
                return false
            }
            return day >= calendar.startOfDay(for: splitFrom)
        }
    }

    private static func occurrenceDate(for occurrenceDay: Date, matching sourceStart: Date, calendar: Calendar, allDay: Bool) -> Date {
        if allDay {
            return calendar.startOfDay(for: occurrenceDay)
        }
        let time = calendar.dateComponents([.hour, .minute, .second], from: sourceStart)
        var day = calendar.dateComponents([.year, .month, .day], from: occurrenceDay)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second
        return calendar.date(from: day) ?? occurrenceDay
    }

    private static func recurringMaster(_ event: CalendarEvent, occursOn day: Date, parsed: ParsedRRule, calendar: Calendar) -> Bool {
        let seriesStartDay = calendar.startOfDay(for: event.startDate)
        let targetDay = calendar.startOfDay(for: day)

        if targetDay < seriesStartDay { return false }
        if let until = parsed.until, targetDay > calendar.startOfDay(for: until) { return false }

        let dayOffset = calendar.dateComponents([.day], from: seriesStartDay, to: targetDay).day ?? 0
        let interval = max(1, parsed.interval)

        switch parsed.freq {
        case .daily:
            return dayOffset % interval == 0

        case .weekly:
            let weekOffset = dayOffset / 7
            guard weekOffset % interval == 0 else { return false }
            let weekdayCodeForTarget = weekdayCode(from: calendar.component(.weekday, from: targetDay))
            let byDay = parsed.byDay ?? [weekdayCode(from: calendar.component(.weekday, from: event.startDate))]
            return byDay.contains(weekdayCodeForTarget)

        case .monthly:
            let monthDelta = monthsBetween(seriesStartDay, targetDay, calendar: calendar)
            guard monthDelta >= 0, monthDelta % interval == 0 else { return false }

            if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                let dayOfMonth = calendar.component(.day, from: targetDay)
                return byMonthDay.contains(dayOfMonth)
            }

            if let byDay = parsed.byDay?.first,
               let bySetPos = parsed.bySetPos {
                return matchesNthWeekday(targetDay, weekdayCode: byDay, setPos: bySetPos, calendar: calendar)
            }

            return calendar.component(.day, from: targetDay) == calendar.component(.day, from: event.startDate)

        case .yearly:
            let yearDelta = (calendar.component(.year, from: targetDay) - calendar.component(.year, from: seriesStartDay))
            guard yearDelta >= 0, yearDelta % interval == 0 else { return false }

            let targetMonth = calendar.component(.month, from: targetDay)
            let fallbackMonth = calendar.component(.month, from: event.startDate)
            let allowedMonths = (parsed.byMonth?.isEmpty == false) ? parsed.byMonth! : [fallbackMonth]
            guard allowedMonths.contains(targetMonth) else { return false }

            if let byMonthDay = parsed.byMonthDay, !byMonthDay.isEmpty {
                return byMonthDay.contains(calendar.component(.day, from: targetDay))
            }

            if let byDay = parsed.byDay?.first,
               let bySetPos = parsed.bySetPos {
                return matchesNthWeekday(targetDay, weekdayCode: byDay, setPos: bySetPos, calendar: calendar)
            }

            return targetMonth == fallbackMonth
                && calendar.component(.day, from: targetDay) == calendar.component(.day, from: event.startDate)
        }
    }

    private static func monthsBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        let startComps = calendar.dateComponents([.year, .month], from: start)
        let endComps = calendar.dateComponents([.year, .month], from: end)
        let startYear = startComps.year ?? 0
        let startMonth = startComps.month ?? 1
        let endYear = endComps.year ?? 0
        let endMonth = endComps.month ?? 1
        return (endYear - startYear) * 12 + (endMonth - startMonth)
    }

    private static func matchesNthWeekday(_ date: Date, weekdayCode: String, setPos: Int, calendar: Calendar) -> Bool {
        let weekdayMap: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
        guard let targetWeekday = weekdayMap[weekdayCode.uppercased()],
              calendar.component(.weekday, from: date) == targetWeekday else {
            return false
        }

        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return false }
        var matches: [Date] = []
        var cursor = monthInterval.start

        while cursor < monthInterval.end {
            if calendar.component(.weekday, from: cursor) == targetWeekday,
               calendar.isDate(cursor, equalTo: date, toGranularity: .month) {
                matches.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? monthInterval.end
        }

        guard !matches.isEmpty else { return false }

        if setPos > 0 {
            let index = setPos - 1
            return matches.indices.contains(index) && calendar.isDate(matches[index], inSameDayAs: date)
        } else {
            let index = matches.count + setPos
            return matches.indices.contains(index) && calendar.isDate(matches[index], inSameDayAs: date)
        }
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
        let cal = CalendarCompute.tzCalendar
        dateTime = cal.date(byAdding: .day, value: days, to: dateTime) ?? dateTime
    }
}

struct TimeEntryRow: View {
    let label: String
    @Binding var dateTime: Date

    @FocusState private var focused: Bool
    @State private var text: String = ""

    // Instance properties so timezone is always current, not captured once at app launch.
    private var displayFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = CalendarCompute.displayTimeZone
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }

    private var parseFormatters: [DateFormatter] {
        func make(_ fmt: String) -> DateFormatter {
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = CalendarCompute.displayTimeZone
            df.dateFormat = fmt
            return df
        }
        return [
            make("h:mm a"), make("h:mma"),
            make("hh:mm a"), make("hh:mma"),
            make("h a"), make("ha")
        ]
    }

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
        text = displayFormatter.string(from: dateTime)
    }

    private func applyTypedTime() {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { syncFromDate(); return }

        for df in parseFormatters {
            if let parsed = df.date(from: raw.uppercased()) {
                let cal = CalendarCompute.tzCalendar
                let c = cal.dateComponents([.hour, .minute], from: parsed)
                dateTime = CalendarCompute.setTimeKeepingDay(day: dateTime, hour: c.hour ?? 0, minute: c.minute ?? 0)
                syncFromDate()
                return
            }
        }
        syncFromDate()
    }

    private func bump(minutes delta: Int) {
        let cal = CalendarCompute.tzCalendar
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

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
