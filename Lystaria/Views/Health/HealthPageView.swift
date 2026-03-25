//
//  HealthPageView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct HealthPageView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bodyStateManager = BodyStateHealthKitManager.shared
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

    @State private var selectedHealthEntry: HealthMetricEntry?
    @State private var selectedExerciseEntry: ExerciseLogEntry?
    @State private var hasRequestedHealthAuthorization = false
    @StateObject private var onboarding = OnboardingManager()


    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                header

                VStack(alignment: .leading, spacing: 18) {
                    healthStreaksCard
                    bodyStateCard

                    HealthMetricsCard(latestEntry: latestHealthEntry) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showHealthHistoryPopup = true
                        }
                    }

                    ExerciseLogCard(entries: exerciseEntries) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showExerciseHistoryPopup = true
                        }
                    }

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
                        }
                    )
                }

                if showAddExercisePopup {
                    AddExercisePopupView(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showAddExercisePopup = false
                            }
                        }
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
                        }
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
                        }
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
                        }
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
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GradientTitle(text: "Health", font: .title2.bold())
                Spacer()

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddMetricsPopup = true
                        }
                    } label: {
                        Text("+ Metrics")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 42)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddExercisePopup = true
                        }
                    } label: {
                        Text("+ Exercise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 42)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        MedicationPageView()
                    } label: {
                        Text("+ Manager")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 42)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Image("medhand")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Health Streaks", size: 26)

                    Spacer()
                }

                HStack(spacing: 14) {
                    streakBubble(
                        title: "Vitals",
                        value: vitalsStreakCount
                    )

                    streakBubble(
                        title: "Exercise",
                        value: exerciseStreakCount
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
                    label: record?.bodyLabel.isEmpty == false ? record!.bodyLabel : "Unavailable"
                )

                bodyStateBar(
                    title: "Nervous System",
                    value: record?.nervousSystemScore ?? 0,
                    label: record?.nervousSystemLabel.isEmpty == false ? record!.nervousSystemLabel : "Unavailable"
                )
            }
        }
    }

    private func bodyStateBar(title: String, value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .fill(stateGradient(for: label))
                    )
                    .overlay(
                        Capsule()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(stateGradient(for: label))
                        .frame(width: geo.size.width * max(0, min(1, value)))
                }
            }
            .frame(height: 12)
            .overlay(
                Capsule()
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }

    private var latestBodyStateRecord: BodyStateRecord? {
        bodyStateRecords.first
    }
    
    private func stateGradient(for label: String) -> LinearGradient {
        switch label {

        case "Excellent":
            return LinearGradient(
                colors: [
                    Color(red: 255/255, green: 105/255, blue: 180/255), // bubblegum magenta pink
                    Color(red: 255/255, green: 245/255, blue: 157/255)  // pastel yellow
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

        case "Mellow":
            return LinearGradient(
                colors: [
                    Color(red: 64/255, green: 224/255, blue: 208/255), // greenish blue
                    Color(red: 0/255, green: 150/255, blue: 136/255)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

        case "Elevated":
            return LinearGradient(
                colors: [
                    Color(red: 255/255, green: 105/255, blue: 180/255), // bubblegum magenta
                    Color(red: 255/255, green: 59/255, blue: 48/255)    // candy red
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

        case "Stressed":
            return LinearGradient(
                colors: [
                    Color(red: 255/255, green: 59/255, blue: 48/255),   // candy red
                    Color(red: 255/255, green: 204/255, blue: 0/255)    // yellowish
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

        case "Rest Needed":
            return LinearGradient(
                colors: [
                    Color(red: 135/255, green: 206/255, blue: 250/255), // sky blue
                    Color(red: 144/255, green: 238/255, blue: 144/255)  // soft greenish
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

        default:
            return LinearGradient(
                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func streakBubble(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LColors.glassBorder, lineWidth: 1)
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
        healthEntries.first
    }

}

#Preview {
    NavigationStack {
        HealthPageView()
    }
}
