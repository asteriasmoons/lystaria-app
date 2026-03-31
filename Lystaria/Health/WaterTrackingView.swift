//
//  WaterTrackingView.swift
//  Lystaria
//

import SwiftUI
import SwiftData
import Foundation
import WatchConnectivity

struct WaterTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var water = WaterHealthKitManager.shared
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

    private var amountGoal: Double {
        settings.waterGoalFlOz
    }

    @State private var showCustomAmountPopup = false
    @State private var customAmountText = ""
    @State private var showGoalPopup = false
    @State private var goalText = ""

    @State private var displayedMonth = Date()
    @State private var reachedGoalDates: Set<String> = []
    @State private var selectedDate: Date?
    @State private var selectedDayWater: Double = 0

    @FocusState private var focusedField: PopupField?

    private enum PopupField {
        case customAmount
        case goal
    }

    private var currentAmount: Double {
        displayedWaterAmount
    }

    private var progress: Double {
        guard amountGoal > 0 else { return 0 }
        return min(currentAmount / amountGoal, 1.0)
    }

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
        !limits.canAccess(.waterGoalCalendar)
    }

    private var selectedGoalCalendarDate: Date {
        selectedDate ?? Date()
    }

    private var displayedWaterAmount: Double {
        if let selectedDate,
           !calendar.isDateInToday(selectedDate) {
            return selectedDayWater
        }
        return water.todayWaterFlOz
    }

    private var cardTitleText: String {
        if let selectedDate {
            if calendar.isDateInToday(selectedDate) { return "Today's Water" }
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL d"
            return "Water for \(formatter.string(from: selectedDate))"
        }
        return "Today's Water"
    }

    private var cardSubtitleText: String {
        if let selectedDate {
            if calendar.isDateInToday(selectedDate) { return "Track your intake in FL OZ" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, LLLL d"
            return formatter.string(from: selectedDate)
        }
        return "Track your intake in FL OZ"
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

    private func totalWater(for date: Date) async -> Double {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        return await water.totalWaterFlOz(from: startOfDay, to: nextDay)
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
            let total = await water.totalWaterFlOz(from: startOfDay, to: nextDay)
            if total >= amountGoal { result.insert(dateKey(for: startOfDay)) }
            cursor = nextDay
        }

        reachedGoalDates = result
    }

    // MARK: - Watch Sync

    private func syncGoalToWatch(_ goal: Double) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(["waterGoal": goal])
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    GradientTitle(text: "Water", font: .title.bold())
                        .padding(.top, 24)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(cardTitleText)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text(cardSubtitleText)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                Spacer()

                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                                        .frame(width: 42, height: 42)

                                    Image("glassfill")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(.white)
                                }
                            }

                            HStack {
                                Spacer()

                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 14)
                                        .frame(width: 170, height: 170)

                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            LGradients.blue,
                                            style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 170, height: 170)

                                    VStack(spacing: 4) {
                                        Text("\(Int(currentAmount)) / \(Int(amountGoal))")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(.white)

                                        Text("FL OZ")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.6)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)

                            HStack(spacing: 10) {
                                Button {
                                    Task { await water.addWater(flOz: 8) }
                                } label: {
                                    Text("8 FL OZ")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await water.addWater(flOz: 20) }
                                } label: {
                                    Text("20 FL OZ")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    customAmountText = ""
                                    showCustomAmountPopup = true
                                } label: {
                                    Text("Other FL OZ")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                Task { await water.fetchTodayWater() }
                            } label: {
                                Text("Refresh")
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
                                selectedDayWater = water.todayWaterFlOz
                            } label: {
                                Text("Back to Today")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button {
                                goalText = amountGoal == 0 ? "" : String(Int(amountGoal))
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

                            Button {
                                Task { await water.clearTodayWater() }
                            } label: {
                                Text("Clear")
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
                                        Button { changeMonth(by: -1) } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                                    .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
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

                                        Button { changeMonth(by: 1) } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                                    .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
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
                                                                GradientOverlayBackground().clipShape(Circle())
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
                                                Task { selectedDayWater = await totalWater(for: itemDate) }
                                            }
                                        } else {
                                            Color.clear.frame(width: 36, height: 36).frame(maxWidth: .infinity)
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

            if showCustomAmountPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        showCustomAmountPopup = false
                    }

                VStack {
                    Spacer()
                    VStack(spacing: 18) {
                        GradientTitle(text: "Other FL OZ", font: .title2.bold())

                        TextField("Amount", text: $customAmountText)
#if os(iOS) || os(visionOS)
                            .keyboardType(.decimalPad)
#endif
                            .focused($focusedField, equals: .customAmount)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))

                        LButton(title: "Add Water", style: .secondary) {
                            let cleaned = customAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                focusedField = nil
                                showCustomAmountPopup = false
                                Task { await water.addWater(flOz: value) }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 320)
                    .background {
                        ZStack {
                            LGradients.blue
                            GradientOverlayBackground().clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    .onTapGesture { }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(20)
            }

            if showGoalPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        showGoalPopup = false
                    }

                VStack {
                    Spacer()
                    VStack(spacing: 18) {
                        GradientTitle(text: "Set Goal", font: .title2.bold())

                        TextField("Goal", text: $goalText)
#if os(iOS) || os(visionOS)
                            .keyboardType(.decimalPad)
#endif
                            .focused($focusedField, equals: .goal)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))

                        LButton(title: "Save Goal", style: .secondary) {
                            let cleaned = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                settings.waterGoalFlOz = value
                                settings.touchUpdated()
                                try? modelContext.save()
                                focusedField = nil
                                showGoalPopup = false
                                Task {
                                    await recalculateReachedGoalDates()
                                    HealthWidgetSync.syncWater(waterToday: water.todayWaterFlOz, waterGoal: value)
                                    syncGoalToWatch(value)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 320)
                    .background {
                        ZStack {
                            LGradients.blue
                            GradientOverlayBackground().clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    .onTapGesture { }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await water.requestAuthorization()
            selectedDate = Date()
            selectedDayWater = water.todayWaterFlOz
            await recalculateReachedGoalDates()
            HealthWidgetSync.syncWater(waterToday: water.todayWaterFlOz, waterGoal: amountGoal)
            syncGoalToWatch(amountGoal)
        }
        .onChange(of: displayedMonth) { _, _ in
            if let selectedDate {
                let selectedMonth = calendar.dateComponents([.year, .month], from: selectedDate)
                let visibleMonth = calendar.dateComponents([.year, .month], from: displayedMonth)
                if selectedMonth.year != visibleMonth.year || selectedMonth.month != visibleMonth.month {
                    self.selectedDate = nil
                    self.selectedDayWater = water.todayWaterFlOz
                }
            }
            Task { await recalculateReachedGoalDates() }
        }
        .onChange(of: water.todayWaterFlOz) { _, newValue in
            if let selectedDate, calendar.isDateInToday(selectedDate) {
                selectedDayWater = newValue
            }
            Task { await recalculateReachedGoalDates() }
            HealthWidgetSync.syncWater(waterToday: newValue, waterGoal: amountGoal)
        }
        .onChange(of: showCustomAmountPopup) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { focusedField = .customAmount }
            } else if focusedField == .customAmount {
                focusedField = nil
            }
        }
        .onChange(of: showGoalPopup) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { focusedField = .goal }
            } else if focusedField == .goal {
                focusedField = nil
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showCustomAmountPopup)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showGoalPopup)
    }

    private struct CalendarDayItem: Identifiable {
        let id = UUID()
        let dayNumber: Int?
        let date: Date?
        let isGoalMet: Bool
        let isToday: Bool
    }
}
