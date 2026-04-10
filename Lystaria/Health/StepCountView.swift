//
//  StepCountView.swift
//  Lystaria
//

import SwiftUI
import SwiftData
import Foundation

struct StepCountView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var limits = LimitManager.shared

    @Query(
        filter: #Predicate<DailyCompletionSettings> { $0.key == "default" }
    ) private var settingsResults: [DailyCompletionSettings]

    private var settings: DailyCompletionSettings {
        if let existing = settingsResults.first { return existing }
        let s = DailyCompletionSettings(key: DailyCompletionSettings.defaultKey)
        modelContext.insert(s)
        return s
    }

    private var stepGoal: Double {
        settings.stepGoal
    }

    @State private var showGoalPopup = false
    @State private var goalText = ""
    @State private var displayedMonth = Date()
    @State private var reachedGoalDates: Set<String> = []
    @State private var selectedDate: Date?
    @State private var selectedDaySteps: Double = 0
    @FocusState private var isGoalFieldFocused: Bool

    private let calendar = Calendar.current

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var isGoalCalendarLocked: Bool {
        !limits.canAccess(.stepsGoalCalendar)
    }

    private var selectedGoalCalendarDate: Date {
        selectedDate ?? Date()
    }

    private var displayedSteps: Double {
        if let selectedDate,
           !calendar.isDateInToday(selectedDate) {
            return selectedDaySteps
        }
        return health.todaySteps
    }

    private var cardTitleText: String {
        if let selectedDate {
            if calendar.isDateInToday(selectedDate) { return "Today's Steps" }
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL d"
            return "Steps for \(formatter.string(from: selectedDate))"
        }
        return "Today's Steps"
    }

    private var cardSubtitleText: String {
        if let selectedDate {
            if calendar.isDateInToday(selectedDate) { return "Your movement progress for today" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, LLLL d"
            return formatter.string(from: selectedDate)
        }
        return "Your movement progress for today"
    }

    @ViewBuilder
    private func premiumBlockedCalendar<Content: View>(
        _ locked: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .premiumLocked(locked)
    }

    private var daysInDisplayedMonth: [CalendarDayItem] {
        let start = startOfMonth(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<2
        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingEmpty = max(0, firstWeekday - 1)

        var items: [CalendarDayItem] = []

        for _ in 0..<leadingEmpty {
            items.append(CalendarDayItem(dayNumber: nil, date: nil, isGoalMet: false, isToday: false))
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            let key = dateKey(for: date)
            let goalMet = reachedGoalDates.contains(key)
            let isToday = calendar.isDateInToday(date)
            items.append(CalendarDayItem(dayNumber: day, date: date, isGoalMet: goalMet, isToday: isToday))
        }

        while items.count % 7 != 0 {
            items.append(CalendarDayItem(dayNumber: nil, date: nil, isGoalMet: false, isToday: false))
        }

        return items
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    GradientTitle(text: "Steps", font: .title.bold())
                        .padding(.top, 24)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(cardTitleText)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text(cardSubtitleText)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                            )
                                            .frame(width: 42, height: 42)

                                        Image("shoefill")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(.white)
                                    }

                                    Text("Goal \(Int(stepGoal))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(Int(displayedSteps))")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("steps")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)
                            }

                            Button {
                                Task {
                                    await health.fetchTodaySteps()
                                    await recalculateReachedGoalDates()
                                }
                            } label: {
                                Text("Refresh Steps")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)

                            Button {
                                selectedDate = Date()
                                selectedDaySteps = health.todaySteps
                            } label: {
                                Text("Back to Today")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                goalText = stepGoal == 0 ? "" : String(Int(stepGoal))
                                showGoalPopup = true
                            } label: {
                                Text("+ Goal")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    premiumBlockedCalendar(isGoalCalendarLocked) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    Text("Goal Calendar")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Button {
                                            changeMonth(by: -1)
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                                    .overlay(
                                                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                                    )
                                                    .frame(width: 34, height: 34)

                                                Image("chevleft")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 14, height: 14)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            changeMonth(by: 1)
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                                    .overlay(
                                                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                                    )
                                                    .frame(width: 34, height: 34)

                                                Image("chevright")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 14, height: 14)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text(monthTitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 12) {
                                    ForEach(weekdaySymbols, id: \.self) { symbol in
                                        Text(symbol)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                    }

                                    ForEach(daysInDisplayedMonth) { item in
                                        if let day = item.dayNumber, let itemDate = item.date {
                                            let isSelected = calendar.isDate(itemDate, inSameDayAs: selectedGoalCalendarDate)

                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                                    .frame(width: 36, height: 36)
                                                    .overlay {
                                                        if item.isGoalMet {
                                                            ZStack {
                                                                LGradients.blue
                                                                GradientOverlayBackground()
                                                                    .clipShape(Circle())
                                                            }
                                                            .clipShape(Circle())
                                                        }
                                                    }
                                                    .overlay(
                                                        Circle().stroke(
                                                            isSelected ? Color.white : (item.isToday ? Color.white.opacity(0.55) : LColors.glassBorder),
                                                            lineWidth: isSelected ? 2 : 1
                                                        )
                                                    )

                                                Text("\(day)")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedDate = itemDate
                                                Task {
                                                    selectedDaySteps = await totalSteps(for: itemDate)
                                                }
                                            }
                                        } else {
                                            Color.clear
                                                .frame(width: 36, height: 36)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 96)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
            }
            .frame(maxWidth: .infinity)
            .clipped()

            if showGoalPopup {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isGoalFieldFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showGoalPopup = false
                            }
                        }

                    VStack(spacing: 20) {
                        GradientTitle(
                            text: "Set Goal",
                            font: .system(size: 22, weight: .bold)
                        )

                        TextField("Goal", text: $goalText)
#if os(iOS) || os(visionOS)
                            .keyboardType(.decimalPad)
#endif
                            .focused($isGoalFieldFocused)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )

                        Button {
                            let cleaned = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                settings.stepGoal = value
                                settings.touchUpdated()
                                try? modelContext.save()
                                isGoalFieldFocused = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showGoalPopup = false
                                }
                                Task {
                                    await recalculateReachedGoalDates()
                                    HealthWidgetSync.syncSteps(
                                        stepsToday: health.todaySteps,
                                        stepGoal: value
                                    )
                                }
                            }
                        } label: {
                            Text("Save Goal")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            let cleaned = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                health.updateStepGoalForSync(value)
                            }
                        })

                        Button {
                            isGoalFieldFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showGoalPopup = false
                            }
                        } label: {
                            Text("Close")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(
                        ZStack {
                            LGradients.blue
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            GradientOverlayBackground()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
                    )
                    .padding(.horizontal, 28)
                    .onTapGesture { }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await health.requestAuthorization()
            health.updateStepGoalForSync(stepGoal)
            selectedDate = Date()
            selectedDaySteps = health.todaySteps
            await recalculateReachedGoalDates()
            HealthWidgetSync.syncSteps(
                stepsToday: health.todaySteps,
                stepGoal: stepGoal
            )
        }
        .onChange(of: displayedMonth) { _, _ in
            if let selectedDate {
                let selectedMonth = calendar.dateComponents([.year, .month], from: selectedDate)
                let visibleMonth = calendar.dateComponents([.year, .month], from: displayedMonth)
                if selectedMonth.year != visibleMonth.year || selectedMonth.month != visibleMonth.month {
                    self.selectedDate = nil
                    self.selectedDaySteps = health.todaySteps
                }
            }
            Task { await recalculateReachedGoalDates() }
        }
        .onChange(of: health.todaySteps) { _, newValue in
            if let selectedDate, calendar.isDateInToday(selectedDate) {
                selectedDaySteps = newValue
            }
            Task { await recalculateReachedGoalDates() }
            HealthWidgetSync.syncSteps(stepsToday: newValue, stepGoal: stepGoal)
        }
        .onChange(of: showGoalPopup) { _, isShowing in
            if !isShowing { isGoalFieldFocused = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isGoalFieldFocused = false }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showGoalPopup)
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func changeMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func totalSteps(for date: Date) async -> Double {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        return await health.totalSteps(from: startOfDay, to: nextDay)
    }

    private func recalculateReachedGoalDates() async {
        let today = Date()
        let monthStart = startOfMonth(for: displayedMonth)
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return }

        var cursor = monthInterval.start
        var result: Set<String> = []

        while cursor < monthInterval.end && cursor <= today {
            let startOfDay = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { break }
            let total = await health.totalSteps(from: startOfDay, to: nextDay)
            if total >= stepGoal { result.insert(dateKey(for: startOfDay)) }
            cursor = nextDay
        }

        reachedGoalDates = result
    }

    private struct CalendarDayItem: Identifiable {
        let id = UUID()
        let dayNumber: Int?
        let date: Date?
        let isGoalMet: Bool
        let isToday: Bool
    }
}
