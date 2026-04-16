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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var water = WaterHealthKitManager.shared
    @StateObject private var limits = LimitManager.shared

    @Query(
        filter: #Predicate<DailyCompletionSettings> { $0.key == "default" }
    ) private var settingsResults: [DailyCompletionSettings]

    @Query private var waterBottlePlans: [WaterBottlePlanEntry]

    private var settings: DailyCompletionSettings {
        if let existing = settingsResults.first { return existing }
        let s = DailyCompletionSettings(key: DailyCompletionSettings.defaultKey)
        modelContext.insert(s)
        return s
    }

    private var amountGoal: Double {
        settings.waterGoalFlOz
    }

    private var plannedBottlesToday: Int {
        todayWaterPlanEntry?.plannedBottles ?? 0
    }

    private var extraBottlesToday: Int {
        todayWaterPlanEntry?.extraBottles ?? 0
    }

    private var sortedWaterPlanningHistory: [WaterBottlePlanEntry] {
        let sorted = waterBottlePlans.sorted {
            if $0.key == $1.key {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.date > $1.date
        }

        var seenKeys = Set<String>()
        var unique: [WaterBottlePlanEntry] = []

        for entry in sorted {
            guard !seenKeys.contains(entry.key) else { continue }
            seenKeys.insert(entry.key)
            unique.append(entry)
        }

        return unique
    }
    
    private var displayedWaterPlanningHistory: [WaterBottlePlanEntry] {
        Array(sortedWaterPlanningHistory.prefix(visibleWaterHistoryCount))
    }

    @State private var showCustomAmountPopup = false
    @State private var customAmountText = ""
    @State private var showClearCustomPopup = false
    @State private var clearCustomAmountText = ""
    @State private var showGoalPopup = false
    @State private var goalText = ""
    @State private var showPlanPopup = false
    @State private var showExtraPopup = false
    @State private var plannedBottleText = ""
    @State private var extraBottleText = ""
    @State private var dayRefreshID = UUID()
    @State private var todayWaterPlanEntry: WaterBottlePlanEntry?
    @State private var todayWaterPlanKey: String = ""

    @State private var displayedMonth = Date()
    @State private var reachedGoalDates: Set<String> = []
    @State private var selectedDate: Date?
    @State private var selectedDayWater: Double = 0
    @State private var showWaterPlanningHistoryPopup = false
    @State private var visibleWaterHistoryCount = 4

    @FocusState private var focusedField: PopupField?

    fileprivate enum PopupField {
        case customAmount
        case clearCustomAmount
        case goal
        case plannedBottles
        case extraBottles
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
    
    private func ensureTodayWaterPlan() {
        let today = calendar.startOfDay(for: Date())
        let todayKey = WaterBottlePlanEntry.key(for: today, calendar: calendar)

        if todayWaterPlanKey == todayKey, todayWaterPlanEntry != nil {
            return
        }

        if let existing = waterBottlePlans.first(where: { $0.key == todayKey }) {
            todayWaterPlanEntry = existing
            todayWaterPlanKey = todayKey
            return
        }

        let entry = WaterBottlePlanEntry(
            key: todayKey,
            date: today
        )
        modelContext.insert(entry)
        todayWaterPlanEntry = entry
        todayWaterPlanKey = todayKey

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save today's water plan: \(error)")
        }
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
                    VStack(spacing: 0) {
                        HStack {
                            GradientTitle(text: "Water", font: .title2.bold())
                            Spacer()
                        }
                        .padding(.top, 20)

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)
                            .padding(.top, 6)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image("bottlefill")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.white)

                                        Text("Water Planning")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(LColors.textPrimary)
                                    }

                                    Text("Track planned vs extra bottles for today")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: 12) {
                                planningBubble(title: "Planned", value: plannedBottlesToday)
                                planningBubble(title: "Extra", value: extraBottlesToday)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    plannedBottleText = plannedBottlesToday == 0 ? "" : String(plannedBottlesToday)
                                    showPlanPopup = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image("wavyplus")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(.white)

                                        Text("Plan")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    extraBottleText = extraBottlesToday == 0 ? "" : String(extraBottlesToday)
                                    showExtraPopup = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image("wavyplus")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(.white)

                                        Text("Extra")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        visibleWaterHistoryCount = 4
                        showWaterPlanningHistoryPopup = true
                    }
                    .id(dayRefreshID)

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

                            // Row 1: Add buttons
                            HStack(spacing: 8) {
                                Button {
                                    Task { await water.addWater(flOz: 8) }
                                } label: {
                                    Text("+ 8 FL OZ")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await water.addWater(flOz: 20) }
                                } label: {
                                    Text("+ 20 FL OZ")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    customAmountText = ""
                                    showCustomAmountPopup = true
                                } label: {
                                    Text("+ Other")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }

                            // Row 2: Utility buttons
                            HStack(spacing: 8) {
                                Button {
                                    Task { await water.fetchTodayWater() }
                                } label: {
                                    Text("Refresh")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedDate = Date()
                                    selectedDayWater = water.todayWaterFlOz
                                } label: {
                                    Text("Today")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    goalText = amountGoal == 0 ? "" : String(Int(amountGoal))
                                    showGoalPopup = true
                                } label: {
                                    Text("+ Goal")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            // Row 3: Clear buttons
                            HStack(spacing: 8) {
                                Button {
                                    Task { await water.clearTodayWater() }
                                } label: {
                                    Text("Clear All")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    clearCustomAmountText = ""
                                    showClearCustomPopup = true
                                } label: {
                                    Text("Clear Custom")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
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

            if showClearCustomPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        showClearCustomPopup = false
                    }

                VStack {
                    Spacer()
                    VStack(spacing: 18) {
                        GradientTitle(text: "Clear FL OZ", font: .title2.bold())

                        TextField("Amount to clear", text: $clearCustomAmountText)
#if os(iOS) || os(visionOS)
                            .keyboardType(.decimalPad)
#endif
                            .focused($focusedField, equals: .clearCustomAmount)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))

                        LButton(title: "Clear", style: .secondary) {
                            let cleaned = clearCustomAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                focusedField = nil
                                showClearCustomPopup = false
                                Task { await water.clearCustomAmount(flOz: value) }
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
                .zIndex(21)
            }

            if showPlanPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        showPlanPopup = false
                    }

                VStack {
                    Spacer()
                    LystariaOverlayPopup(
                        onClose: {
                            focusedField = nil
                            showPlanPopup = false
                        },
                        width: 540,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Planned Bottles", font: .title2.bold())
                        },
                        content: {
                            TextField("Bottle count", text: $plannedBottleText)
#if os(iOS) || os(visionOS)
                                .keyboardType(.numberPad)
#endif
                                .focused($focusedField, equals: .plannedBottles)
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        },
                        footer: {
                            HStack(spacing: 10) {
                                LButton(title: "Close", style: .secondary) {
                                    focusedField = nil
                                    showPlanPopup = false
                                }

                                LButton(title: "Save", style: .gradient) {
                                    savePlannedBottles()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(21)
            }

            if showExtraPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        showExtraPopup = false
                    }

                VStack {
                    Spacer()
                    LystariaOverlayPopup(
                        onClose: {
                            focusedField = nil
                            showExtraPopup = false
                        },
                        width: 540,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Extra Bottles", font: .title2.bold())
                        },
                        content: {
                            TextField("Bottle count", text: $extraBottleText)
#if os(iOS) || os(visionOS)
                                .keyboardType(.numberPad)
#endif
                                .focused($focusedField, equals: .extraBottles)
                                .textFieldStyle(.plain)
                                .foregroundStyle(LColors.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        },
                        footer: {
                            HStack(spacing: 10) {
                                LButton(title: "Close", style: .secondary) {
                                    focusedField = nil
                                    showExtraPopup = false
                                }

                                LButton(title: "Save", style: .gradient) {
                                    saveExtraBottles()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(21)
            }

            if showWaterPlanningHistoryPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        visibleWaterHistoryCount = 4
                        showWaterPlanningHistoryPopup = false
                    }

                VStack {
                    Spacer()
                    LystariaOverlayPopup(
                        onClose: {
                            visibleWaterHistoryCount = 4
                            showWaterPlanningHistoryPopup = false
                        },
                        width: 540,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Water Planning History", font: .title2.bold())
                        },
                        content: {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    if sortedWaterPlanningHistory.isEmpty {
                                        Text("No water planning history yet")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ForEach(displayedWaterPlanningHistory) { entry in
                                            waterPlanningHistoryCard(entry: entry)
                                        }

                                        if sortedWaterPlanningHistory.count > visibleWaterHistoryCount {
                                            HStack {
                                                Spacer()
                                                LoadMoreButton {
                                                    visibleWaterHistoryCount += 4
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            }
                        },
                        footer: {
                            HStack(spacing: 10) {
                                LButton(title: "Close", style: .gradient) {
                                    visibleWaterHistoryCount = 4
                                    showWaterPlanningHistoryPopup = false
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(22)
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
        .modifier(WaterTrackingLifecycleModifier(
            water: water,
            limits: limits,
            amountGoal: amountGoal,
            displayedMonth: displayedMonth,
            calendar: calendar,
            waterBottlePlans: waterBottlePlans,
            showCustomAmountPopup: $showCustomAmountPopup,
            showClearCustomPopup: $showClearCustomPopup,
            showGoalPopup: $showGoalPopup,
            showPlanPopup: $showPlanPopup,
            showExtraPopup: $showExtraPopup,
            showWaterPlanningHistoryPopup: $showWaterPlanningHistoryPopup,
            plannedBottleText: $plannedBottleText,
            extraBottleText: $extraBottleText,
            dayRefreshID: $dayRefreshID,
            todayWaterPlanEntry: $todayWaterPlanEntry,
            todayWaterPlanKey: $todayWaterPlanKey,
            selectedDate: $selectedDate,
            selectedDayWater: $selectedDayWater,
            recalculateReachedGoalDates: recalculateReachedGoalDates,
            syncGoalToWatch: syncGoalToWatch,
            ensureTodayWaterPlan: ensureTodayWaterPlan
        ))
        .modifier(WaterTrackingPopupFocusModifier(
            showCustomAmountPopup: showCustomAmountPopup,
            showClearCustomPopup: showClearCustomPopup,
            showGoalPopup: showGoalPopup,
            showPlanPopup: showPlanPopup,
            showExtraPopup: showExtraPopup,
            showWaterPlanningHistoryPopup: showWaterPlanningHistoryPopup,
            focusedField: $focusedField
        ))
    }

    private func savePlannedBottles() {
        ensureTodayWaterPlan()

        guard let entry = todayWaterPlanEntry else { return }

        let cleaned = plannedBottleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Int(cleaned) ?? 0

        entry.plannedBottles = max(0, value)
        entry.touchUpdated()

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save planned bottles: \(error)")
        }

        todayWaterPlanEntry = entry
        focusedField = nil
        showPlanPopup = false
    }

    private func saveExtraBottles() {
        ensureTodayWaterPlan()

        guard let entry = todayWaterPlanEntry else { return }

        let cleaned = extraBottleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Int(cleaned) ?? 0

        entry.extraBottles = max(0, value)
        entry.touchUpdated()

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save extra bottles: \(error)")
        }

        todayWaterPlanEntry = entry
        focusedField = nil
        showExtraPopup = false
    }

    private func waterPlanningHistoryCard(entry: WaterBottlePlanEntry) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"

        return VStack(alignment: .leading, spacing: 10) {
            Text(formatter.string(from: entry.date))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                planningBubble(title: "Planned", value: entry.plannedBottles)
                planningBubble(title: "Extra", value: entry.extraBottles)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    private func planningBubble(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(value) bottles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    private struct CalendarDayItem: Identifiable {
        let id = UUID()
        let dayNumber: Int?
        let date: Date?
        let isGoalMet: Bool
        let isToday: Bool
    }
}

fileprivate struct WaterTrackingLifecycleModifier: ViewModifier {
    let water: WaterHealthKitManager
    let limits: LimitManager
    let amountGoal: Double
    let displayedMonth: Date
    let calendar: Calendar
    let waterBottlePlans: [WaterBottlePlanEntry]

    @Binding var showCustomAmountPopup: Bool
    @Binding var showClearCustomPopup: Bool
    @Binding var showGoalPopup: Bool
    @Binding var showPlanPopup: Bool
    @Binding var showExtraPopup: Bool
    @Binding var showWaterPlanningHistoryPopup: Bool
    @Binding var plannedBottleText: String
    @Binding var extraBottleText: String
    @Binding var dayRefreshID: UUID
    @Binding var todayWaterPlanEntry: WaterBottlePlanEntry?
    @Binding var todayWaterPlanKey: String
    @Binding var selectedDate: Date?
    @Binding var selectedDayWater: Double

    let recalculateReachedGoalDates: () async -> Void
    let syncGoalToWatch: (Double) -> Void
    let ensureTodayWaterPlan: () -> Void

    func body(content: Content) -> some View {
        content
            .task {
                await water.requestAuthorization()
                water.updateWaterGoalForSync(amountGoal)
                selectedDate = Date()
                selectedDayWater = water.todayWaterFlOz
                await recalculateReachedGoalDates()
                HealthWidgetSync.syncWater(waterToday: water.todayWaterFlOz, waterGoal: amountGoal)
                syncGoalToWatch(amountGoal)
                ensureTodayWaterPlan()
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
            .onChange(of: amountGoal) { _, newGoal in
                water.updateWaterGoalForSync(newGoal)
            }
            .onChange(of: waterBottlePlans.count) { _, _ in
                let today = calendar.startOfDay(for: Date())
                let todayKey = WaterBottlePlanEntry.key(for: today, calendar: calendar)

                if let existing = waterBottlePlans.first(where: { $0.key == todayKey }) {
                    todayWaterPlanEntry = existing
                    todayWaterPlanKey = todayKey
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dayRefreshID = UUID()
                plannedBottleText = ""
                extraBottleText = ""
                todayWaterPlanEntry = nil
                todayWaterPlanKey = ""
                ensureTodayWaterPlan()
            }
            .onChange(of: scenePhaseValue) { _, newPhase in
                if newPhase == .active {
                    dayRefreshID = UUID()
                    ensureTodayWaterPlan()
                }
            }
    }

    @Environment(\.scenePhase) private var scenePhaseValue
}

fileprivate struct WaterTrackingPopupFocusModifier: ViewModifier {
    let showCustomAmountPopup: Bool
    let showClearCustomPopup: Bool
    let showGoalPopup: Bool
    let showPlanPopup: Bool
    let showExtraPopup: Bool
    let showWaterPlanningHistoryPopup: Bool
    let focusedField: FocusState<WaterTrackingView.PopupField?>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: showCustomAmountPopup) { _, isShowing in
                if isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusedField.wrappedValue = .customAmount
                    }
                } else if focusedField.wrappedValue == .customAmount {
                    focusedField.wrappedValue = nil
                }
            }
            .onChange(of: showClearCustomPopup) { _, isShowing in
                if isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusedField.wrappedValue = .clearCustomAmount
                    }
                } else if focusedField.wrappedValue == .clearCustomAmount {
                    focusedField.wrappedValue = nil
                }
            }
            .onChange(of: showGoalPopup) { _, isShowing in
                if isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusedField.wrappedValue = .goal
                    }
                } else if focusedField.wrappedValue == .goal {
                    focusedField.wrappedValue = nil
                }
            }
            .onChange(of: showPlanPopup) { _, isShowing in
                if isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusedField.wrappedValue = .plannedBottles
                    }
                } else if focusedField.wrappedValue == .plannedBottles {
                    focusedField.wrappedValue = nil
                }
            }
            .onChange(of: showExtraPopup) { _, isShowing in
                if isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusedField.wrappedValue = .extraBottles
                    }
                } else if focusedField.wrappedValue == .extraBottles {
                    focusedField.wrappedValue = nil
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField.wrappedValue = nil
                    }
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showCustomAmountPopup)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showClearCustomPopup)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showGoalPopup)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showPlanPopup)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showExtraPopup)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showWaterPlanningHistoryPopup)
    }
}
