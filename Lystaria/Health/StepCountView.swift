//
//  StepCountView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import Foundation

struct StepCountView: View {
    @StateObject private var health = HealthKitManager.shared

    @AppStorage("stepGoal") private var stepGoal: Double = 5000
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
    
    private var effectiveSelectedDate: Date {
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
            if calendar.isDateInToday(selectedDate) {
                return "Today’s Steps"
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL d"
            return "Steps for \(formatter.string(from: selectedDate))"
        }

        return "Today’s Steps"
    }

    private var cardSubtitleText: String {
        if let selectedDate {
            if calendar.isDateInToday(selectedDate) {
                return "Your movement progress for today"
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, LLLL d"
            return formatter.string(from: selectedDate)
        }

        return "Your movement progress for today"
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
                                    recalculateReachedGoalDates()
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
                                        let isSelected = calendar.isDate(itemDate, inSameDayAs: effectiveSelectedDate)

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
                                            selectedDaySteps = totalSteps(for: itemDate)
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

                    Spacer(minLength: 96)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
            }
            .frame(maxWidth: .infinity)
            .clipped()

            if showGoalPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isGoalFieldFocused = false
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

                        LButton(title: "Save Goal", style: .secondary) {
                            let cleaned = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let value = Double(cleaned), value > 0 {
                                stepGoal = value
                                isGoalFieldFocused = false
                                showGoalPopup = false
                                recalculateReachedGoalDates()
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 320)
                    .background {
                        ZStack {
                            LGradients.blue
                            GradientOverlayBackground()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
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
            await health.requestAuthorization()
            selectedDate = Date()
            selectedDaySteps = health.todaySteps
            recalculateReachedGoalDates()
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
            recalculateReachedGoalDates()
        }
        .onChange(of: stepGoal) { _, _ in
            recalculateReachedGoalDates()
        }
        .onChange(of: health.todaySteps) { _, newValue in
            if let selectedDate, calendar.isDateInToday(selectedDate) {
                selectedDaySteps = newValue
            }
            recalculateReachedGoalDates()
        }
        .onChange(of: showGoalPopup) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isGoalFieldFocused = true
                }
            } else {
                isGoalFieldFocused = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isGoalFieldFocused = false
                }
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
    
    private func totalSteps(for date: Date) -> Double {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        return health.totalSteps(from: startOfDay, to: nextDay) ?? 0
    }

    private func recalculateReachedGoalDates() {
        let today = Date()
        let monthStart = startOfMonth(for: displayedMonth)
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return }

        var cursor = monthInterval.start
        var result: Set<String> = []

        while cursor < monthInterval.end && cursor <= today {
            let startOfDay = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { break }

            if let total = health.totalSteps(from: startOfDay, to: nextDay), total >= stepGoal {
                result.insert(dateKey(for: startOfDay))
            }

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
