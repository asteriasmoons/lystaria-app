//
//  HealthPageView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftData
import SwiftUI

struct HealthPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bodyStateManager = BodyStateHealthKitManager.shared
    @StateObject private var stepManager = HealthKitManager.shared
    @StateObject private var waterManager = WaterHealthKitManager.shared
    @StateObject private var sleepManager = SleepHealthKitManager.shared
    @Query(sort: \HealthMetricEntry.date, order: .reverse)
    private var healthEntries: [HealthMetricEntry]

    @Query(sort: \ExerciseLogEntry.date, order: .reverse)
    private var exerciseEntries: [ExerciseLogEntry]

    @Query(sort: \BodyStateRecord.updatedAt, order: .reverse)
    private var bodyStateRecords: [BodyStateRecord]

    @State private var showAddMetricsPopup = false
    @State private var showAddExercisePopup = false
    @State private var showHealthHistoryPopup = false
    @State private var showExerciseHistoryPopup = false
    @State private var showCurrentFlowInfoPopup = false

    @State private var selectedHealthEntry: HealthMetricEntry?
    @State private var selectedExerciseEntry: ExerciseLogEntry?
    @State private var hasRequestedHealthAuthorization = false
    @State private var completionRefreshTick = Date()
    @State private var dayRefreshID = UUID()
    @StateObject private var onboarding = OnboardingManager()

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                header

                VStack(alignment: .leading, spacing: 18) {
                    healthStreaksCard
                    sleepScoreCard
                    dailyCompletionCard
                        .id(completionRefreshTick)
                    bodyStateCard
                    HealthMetricsCard(latestEntry: latestHealthEntry) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showHealthHistoryPopup = true
                        }
                    } onAdd: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddMetricsPopup = true
                        }
                    }
                    .id(dayRefreshID)

                    ExerciseLogCard(entries: exerciseEntries) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showExerciseHistoryPopup = true
                        }
                    } onAdd: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddExercisePopup = true
                        }
                    }
                    .id(dayRefreshID)
                    Color.clear
                        .frame(height: 120)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .overlay {
            ZStack {
                if showAddMetricsPopup {
                    AddHealthMetricsPopupView(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showAddMetricsPopup = false
                            }
                        },
                    )
                }

                if showAddExercisePopup {
                    AddExercisePopupView(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showAddExercisePopup = false
                            }
                        },
                    )
                }

                if showHealthHistoryPopup {
                    HealthMetricsHistoryPopupView(
                        entries: healthEntries,
                        onSelect: { entry in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedHealthEntry = entry
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showHealthHistoryPopup = false
                            }
                        },
                    )
                }

                if showCurrentFlowInfoPopup {
                    CurrentFlowInfoPopup(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showCurrentFlowInfoPopup = false
                            }
                        }
                    )
                }

                if showExerciseHistoryPopup {
                    ExerciseHistoryPopupView(
                        entries: exerciseEntries,
                        onSelect: { entry in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedExerciseEntry = entry
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showExerciseHistoryPopup = false
                            }
                        },
                    )
                }

                if let healthEntry = selectedHealthEntry {
                    HealthMetricDetailPopupView(
                        entry: healthEntry,
                        onDelete: {
                            modelContext.delete(healthEntry)

                            do {
                                try modelContext.save()
                            } catch {
                                print("Delete health entry error:", error)
                            }

                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedHealthEntry = nil
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedHealthEntry = nil
                            }
                        },
                    )
                }

                if let exerciseEntry = selectedExerciseEntry {
                    ExerciseDetailPopupView(
                        entry: exerciseEntry,
                        onDelete: {
                            modelContext.delete(exerciseEntry)

                            do {
                                try modelContext.save()
                            } catch {
                                print("Delete exercise entry error:", error)
                            }

                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedExerciseEntry = nil
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedExerciseEntry = nil
                            }
                        },
                    )
                }
            }
        }
        .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
            ZStack {
                OnboardingOverlay(anchors: anchors)
                    .environmentObject(onboarding)
            }
            .task(id: anchors.count) {
                if anchors.count > 0 {
                    onboarding.start(page: OnboardingPages.health)
                }
            }
        }
        .task {
            guard !hasRequestedHealthAuthorization else { return }
            hasRequestedHealthAuthorization = true

            do {
                try await HealthMetricsHealthKitManager.shared.requestAuthorization()
                try await ExerciseHealthKitManager.shared.requestAuthorization()
                try await bodyStateManager.requestAuthorization()
                await bodyStateManager.refreshAndStore(in: modelContext)
            } catch {
                print("HealthKit authorization error:", error)
            }

            await sleepManager.requestAuthorization()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await bodyStateManager.refreshAndStore(in: modelContext)
                await MainActor.run {
                    completionRefreshTick = Date()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayRefreshID = UUID()
            completionRefreshTick = Date()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dayRefreshID = UUID()
                completionRefreshTick = Date()
                Task {
                    await bodyStateManager.refreshAndStore(in: modelContext)
                    await sleepManager.fetchLastNightSleep()
                }
            }
        }
    }

    private var sleepScoreCard: some View {
        let hours = sleepManager.lastNightHours
        let score = sleepManager.sleepScore
        let label = sleepManager.sleepLabel
        let hasData = hours > 0

        // Sync to watch
        HealthWidgetSync.syncSleep(hours: hours, score: score, label: label)

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)

                    GradientTitle(text: "Sleep Score", size: 24)
                    Spacer()

                    // Label badge
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(hasData ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.12)))
                        )
                        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                }

                HStack(alignment: .center, spacing: 20) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 10)
                            .frame(width: 90, height: 90)

                        Circle()
                            .trim(from: 0, to: hasData ? score : 0)
                            .stroke(
                                AnyShapeStyle(LGradients.blue),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 90, height: 90)

                        VStack(spacing: 2) {
                            Text(hasData ? String(format: "%.1f", hours) : "--")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Text("hrs")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sleepStatRow(label: "Last Night", value: hasData ? String(format: "%.1fh", hours) : "No data")
                        sleepStatRow(label: "Goal", value: String(format: "%.0fh", sleepManager.sleepGoalHours))
                        sleepStatRow(label: "Score", value: hasData ? "\(Int((score * 100).rounded()))%" : "--")
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func sleepStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.4)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
    }

    private var dailyCompletionCard: some View {
        let arcData = DailyCompletionArcHelper.build(
            modelContext: modelContext,
            waterToday: waterManager.todayWaterFlOz,
            stepsToday: stepManager.todaySteps,
        )

        // Keep watch complication completion bubble in sync
        HealthWidgetSync.syncCompletionPct(arcData.percentage)

        return GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image("sparklefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Daily Completion", size: 24)

                    Spacer()
                }

                HStack {
                    Spacer()

                    ZStack {
                        DailyCompletionBubbleArc(
                            fillStates: arcData.bubbleFillStates,
                            size: 220,
                        )

                        VStack(spacing: 4) {
                            Text("\(Int((arcData.percentage * 100).rounded()))%")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Text("complete")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    completionPill(
                        title: "Water",
                        value: "\(Int((arcData.waterProgress * 100).rounded()))%",
                    )

                    completionPill(
                        title: "Steps",
                        value: "\(Int((arcData.stepsProgress * 100).rounded()))%",
                    )
                }

                HStack(spacing: 10) {
                    completionPill(
                        title: "Mood",
                        value: arcData.moodComplete ? "Done" : "Not Yet",
                    )

                    completionPill(
                        title: "Journal",
                        value: arcData.journalComplete ? "Done" : "Not Yet",
                    )
                }
            }
        }
    }

    private func completionPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1),
        )
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GradientTitle(text: "Health", font: .title2.bold())
                Spacer()

                HStack(spacing: 8) {
                    NavigationLink {
                        WaterTrackingView()
                            .preferredColorScheme(.dark)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("glassfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("waterIcon")

                    NavigationLink {
                        StepCountView()
                            .preferredColorScheme(.dark)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("shoefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("stepsIcon")

                    NavigationLink {
                        MedicationPageView()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("pillfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("medsIcon")
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 6)
        }
    }

    private var healthStreaksCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image("medhand")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Health Streaks", size: 24)

                    Spacer()
                }

                HStack(spacing: 10) {
                    streakBubble(
                        title: "Vitals",
                        value: vitalsStreakCount,
                    )

                    streakBubble(
                        title: "Exercise",
                        value: exerciseStreakCount,
                    )
                }
            }
        }
    }

    private var bodyStateCard: some View {
        let record = latestBodyStateRecord

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image("handheart")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Current Flow", size: 24)

                    Spacer()
                }

                bodyStateBar(
                    title: "Body State",
                    value: record?.bodyScore ?? 0,
                    label: record?.bodyLabel.isEmpty == false ? record!.bodyLabel : "Unavailable",
                )

                bodyStateBar(
                    title: "Nervous System",
                    value: record?.nervousSystemScore ?? 0,
                    label: record?.nervousSystemLabel.isEmpty == false ? record!.nervousSystemLabel : "Unavailable",
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: LSpacing.cardRadius))
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showCurrentFlowInfoPopup = true
            }
        }
    }

    private func bodyStateBar(title: String, value: Double, label: String) -> some View {
        let isUnavailable = label == "Unavailable"
        // Always show at least a sliver so the bar is never completely blank.
        let displayValue = isUnavailable ? 0.0 : max(value, 0.08)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LColors.textSecondary)

                Spacer()

                Text(label)
                    .foregroundStyle(.white)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isUnavailable ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(stateGradient(for: label))),
                    )
                    .overlay(
                        Capsule()
                            .stroke(LColors.glassBorder, lineWidth: 1),
                    )
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    if isUnavailable {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    } else {
                        // Render the gradient at full width then clip to the correct
                        // progress amount. This prevents SwiftUI from producing a
                        // blank bar when the fill width is narrow — which happens
                        // when the gradient is constrained by .frame(width:) alone.
                        Capsule()
                            .fill(stateGradient(for: label))
                            .frame(width: geo.size.width)
                            .mask(alignment: .leading) {
                                Capsule()
                                    .frame(width: geo.size.width * displayValue)
                            }
                    }
                }
            }
            .frame(height: 12)
            .overlay(
                Capsule()
                    .stroke(LColors.glassBorder, lineWidth: 1),
            )
        }
    }

    private var latestBodyStateRecord: BodyStateRecord? {
        bodyStateRecords.first
    }

    private func stateGradient(for label: String) -> LinearGradient {
        switch label {
        case "Excellent":
            LinearGradient(
                colors: [
                    Color(red: 255 / 255, green: 105 / 255, blue: 180 / 255), // bubblegum magenta pink
                    Color(red: 255 / 255, green: 245 / 255, blue: 157 / 255), // pastel yellow
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )

        case "Mellow":
            LinearGradient(
                colors: [
                    Color(red: 64 / 255, green: 224 / 255, blue: 208 / 255), // greenish blue
                    Color(red: 0 / 255, green: 150 / 255, blue: 136 / 255),
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )

        case "Elevated":
            LinearGradient(
                colors: [
                    Color(red: 255 / 255, green: 105 / 255, blue: 180 / 255), // bubblegum magenta
                    Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255), // candy red
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )

        case "Activated":
            LinearGradient(
                colors: [
                    Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255), // candy red
                    Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255), // yellowish
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )

        case "Rest Needed":
            LinearGradient(
                colors: [
                    Color(red: 135 / 255, green: 206 / 255, blue: 250 / 255), // sky blue
                    Color(red: 144 / 255, green: 238 / 255, blue: 144 / 255), // soft greenish
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )

        default:
            LinearGradient(
                colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing,
            )
        }
    }

    private func streakBubble(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08)),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1),
        )
    }

    private var vitalsStreakCount: Int {
        streakCount(from: healthEntries.map(\.date))
    }

    private var exerciseStreakCount: Int {
        streakCount(from: exerciseEntries.map(\.date))
    }

    private func streakCount(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted(by: >)

        guard let firstDay = uniqueDays.first else { return 0 }

        var streak = 1
        var previousDay = firstDay

        for day in uniqueDays.dropFirst() {
            guard let expectedPrevious = calendar.date(byAdding: .day, value: -1, to: previousDay) else {
                break
            }

            if calendar.isDate(day, inSameDayAs: expectedPrevious) {
                streak += 1
                previousDay = day
            } else {
                break
            }
        }

        return streak
    }

    private var latestHealthEntry: HealthMetricEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return healthEntries.first {
            calendar.isDate($0.date, inSameDayAs: today)
        }
    }
}

private struct DailyCompletionBubbleArc: View {
    let fillStates: [Double]
    let size: CGFloat

    private let bubbleSize: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 30)
            let radius = size * 0.42
            let startAngle = Double.pi * 1.0
            let endAngle = Double.pi * 2.0
            let count = max(fillStates.count, 1)

            ZStack {
                ForEach(Array(fillStates.enumerated()), id: \.offset) { index, fill in
                    let progress = count == 1 ? 0 : Double(index) / Double(count - 1)
                    let angle = startAngle + ((endAngle - startAngle) * progress)
                    let x = center.x + CGFloat(cos(angle)) * radius
                    let y = center.y + CGFloat(sin(angle)) * radius

                    DailyCompletionBubble(fill: fill)
                        .frame(width: bubbleSize, height: bubbleSize)
                        .position(x: x, y: y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size, height: size * 0.84)
    }
}

private struct DailyCompletionBubble: View {
    let fill: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Circle()
                        .stroke(LColors.glassBorder, lineWidth: 1),
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 3 / 255, green: 219 / 255, blue: 252 / 255),
                            Color(red: 125 / 255, green: 25 / 255, blue: 247 / 255),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(
                                width: geo.size.width,
                                height: geo.size.height * CGFloat(min(max(fill, 0), 1)),
                                alignment: .bottom,
                            )
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    },
                )
                .opacity(fill > 0 ? 1 : 0)
        }
    }
}

// MARK: - Current Flow Info Popup

struct CurrentFlowInfoPopup: View {
    let onClose: () -> Void

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 500,
            heightRatio: 0.82,
            header: {
                HStack {
                    GradientTitle(text: "Current Flow", size: 28)
                    Spacer()
                    Button(action: onClose) {
                        Image("xmark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                // BODY STATE SECTION
                GradientTitle(text: "Body State", size: 22)
                    .padding(.top, 4)

                Text("The Body State bar reflects your overall physical readiness based on HRV, resting heart rate, respiratory rate, and sleep quality. A higher fill means your body is functioning optimally and recovering well.")
                    .font(.system(size: 13))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 4)

                bodyStateResultRow(
                    label: "Excellent",
                    description: "Your body is thriving. HRV is high, heart rate is low and stable, sleep was restorative, and your system is primed for performance or challenge."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                bodyStateResultRow(
                    label: "Mellow",
                    description: "Your body is calm and balanced. Metrics are within healthy ranges and you're in a relaxed, steady state — good for focused or creative work."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                bodyStateResultRow(
                    label: "Elevated",
                    description: "Your body is running hot. Heart rate or HRV signals heightened activation — this could be excitement, exertion, or early stress. Monitor and pace yourself."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                bodyStateResultRow(
                    label: "Activated",
                    description: "Your body is working harder than baseline. HRV is moderately suppressed and your system is running with more effort — not harmful, but worth being gentle with yourself."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                bodyStateResultRow(
                    label: "Rest Needed",
                    description: "Your body is calling for rest. Sleep or recovery metrics are low, and your system needs time to recharge before it can perform at its best."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 8)

                // NERVOUS SYSTEM SECTION
                GradientTitle(text: "Nervous System", size: 22)
                    .padding(.top, 4)

                Text("The Nervous System bar shows the state of your autonomic nervous system — the balance between your sympathetic (fight-or-flight) and parasympathetic (rest-and-digest) responses, primarily derived from HRV patterns.")
                    .font(.system(size: 13))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 4)

                nervousSystemResultRow(
                    label: "Excellent",
                    description: "Your autonomic nervous system is thriving. HRV is well above your baseline, indicating strong parasympathetic tone and exceptional resilience."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                nervousSystemResultRow(
                    label: "Mellow",
                    description: "Your nervous system is calm and regulated. HRV is healthy relative to your baseline and your body is in a balanced, steady state."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                nervousSystemResultRow(
                    label: "Elevated",
                    description: "Your nervous system is moderately activated. Sympathetic activity is slightly raised — this could be alertness, mild exertion, or early stress building up."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                nervousSystemResultRow(
                    label: "Activated",
                    description: "Your nervous system is running with more sympathetic activity than usual. HRV is moderately below baseline — your body is engaged and working, not necessarily in distress."
                )

                Divider()
                    .background(LColors.glassBorder)
                    .padding(.vertical, 2)

                nervousSystemResultRow(
                    label: "Rest Needed",
                    description: "Your nervous system is depleted. HRV is significantly below baseline and your body urgently needs rest, calm, and recovery to restore regulation."
                )
            },
            footer: { EmptyView() }
        )
    }

    @ViewBuilder
    private func bodyStateResultRow(label: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nervousSystemResultRow(label: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        HealthPageView()
    }
}
