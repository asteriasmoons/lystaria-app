//
//  HealthPageView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import SwiftUI
import SwiftData

struct HealthPageView: View {
    @Query(sort: \HealthMetricEntry.date, order: .reverse)
    private var healthEntries: [HealthMetricEntry]

    @Query(sort: \ExerciseLogEntry.date, order: .reverse)
    private var exerciseEntries: [ExerciseLogEntry]

    @State private var showAddMetricsPopup = false
    @State private var showAddExercisePopup = false
    @State private var showHealthHistoryPopup = false
    @State private var showExerciseHistoryPopup = false

    @State private var selectedHealthEntry: HealthMetricEntry?
    @State private var selectedExerciseEntry: ExerciseLogEntry?
    @State private var hasRequestedHealthAuthorization = false

    // Add Metrics footer state
    @State private var metricsSaveTrigger = false
    @State private var metricsIsSaving = false
    @State private var metricsIsValid = false

    // Add Exercise footer state
    @State private var exerciseSaveTrigger = false
    @State private var exerciseIsSaving = false
    @State private var exerciseIsValid = false

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                header

                VStack(alignment: .leading, spacing: 18) {
                    healthStreaksCard

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
                    LystariaOverlayPopup(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showAddMetricsPopup = false
                            }
                        },
                        width: 560,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Add Metrics", size: 24)
                        },
                        content: {
                            AddHealthMetricsPopupView(
                                onClose: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showAddMetricsPopup = false
                                    }
                                },
                                saveTrigger: $metricsSaveTrigger,
                                isSaving: $metricsIsSaving,
                                isValid: $metricsIsValid
                            )
                        },
                        footer: {
                            Button {
                                metricsSaveTrigger = true
                            } label: {
                                Text(metricsIsSaving ? "Saving..." : "Save")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LColors.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .opacity(metricsIsValid ? 1.0 : 0.5)
                            }
                            .disabled(metricsIsSaving || !metricsIsValid)
                        }
                    )
                }

                if showAddExercisePopup {
                    LystariaOverlayPopup(
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showAddExercisePopup = false
                            }
                        },
                        width: 560,
                        heightRatio: 0.55,
                        header: {
                            GradientTitle(text: "Add Exercise", size: 24)
                        },
                        content: {
                            AddExercisePopupView(
                                onClose: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showAddExercisePopup = false
                                    }
                                },
                                saveTrigger: $exerciseSaveTrigger,
                                isSaving: $exerciseIsSaving,
                                isValid: $exerciseIsValid
                            )
                        },
                        footer: {
                            Button {
                                exerciseSaveTrigger = true
                            } label: {
                                Text(exerciseIsSaving ? "Saving..." : "Save")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LColors.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .opacity(exerciseIsValid ? 1.0 : 0.5)
                            }
                            .disabled(exerciseIsSaving || !exerciseIsValid)
                        }
                    )
                }

                if showHealthHistoryPopup {
                    LystariaOverlayPopup(
                        onClose: {
                            showHealthHistoryPopup = false
                        },
                        width: 620,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Health Metrics", size: 24)
                        },
                        content: {
                            HealthMetricsHistoryPopupView(entries: healthEntries) { entry in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedHealthEntry = entry
                                }
                            }
                        },
                        footer: {
                            HStack {
                                Spacer()
                                Button("Close") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showHealthHistoryPopup = false
                                    }
                                }
                            }
                        }
                    )
                }

                if showExerciseHistoryPopup {
                    LystariaOverlayPopup(
                        onClose: {
                            showExerciseHistoryPopup = false
                        },
                        width: 620,
                        heightRatio: 0.70,
                        header: {
                            GradientTitle(text: "Exercise Log", size: 24)
                        },
                        content: {
                            ExerciseHistoryPopupView(entries: exerciseEntries) { entry in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedExerciseEntry = entry
                                }
                            }
                        },
                        footer: {
                            HStack {
                                Spacer()
                                Button("Close") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showExerciseHistoryPopup = false
                                    }
                                }
                            }
                        }
                    )
                }

                if let healthEntry = selectedHealthEntry {
                    LystariaOverlayPopup(
                        onClose: {
                            selectedHealthEntry = nil
                        },
                        width: 520,
                        heightRatio: 0.55,
                        header: {
                            GradientTitle(text: "Health Entry", size: 24)
                        },
                        content: {
                            HealthMetricDetailPopupView(entry: healthEntry)
                        },
                        footer: {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedHealthEntry = nil
                                }
                            } label: {
                                Text("Save")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LColors.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    )
                }

                if let exerciseEntry = selectedExerciseEntry {
                    LystariaOverlayPopup(
                        onClose: {
                            selectedExerciseEntry = nil
                        },
                        width: 520,
                        heightRatio: 0.50,
                        header: {
                            GradientTitle(text: "Exercise Entry", size: 24)
                        },
                        content: {
                            ExerciseDetailPopupView(entry: exerciseEntry)
                        },
                        footer: {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedExerciseEntry = nil
                                }
                            } label: {
                                Text("Save")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LColors.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    )
                }
            }
        }
        .task {
            guard !hasRequestedHealthAuthorization else { return }
            hasRequestedHealthAuthorization = true

            do {
                try await HealthMetricsHealthKitManager.shared.requestAuthorization()
                try await ExerciseHealthKitManager.shared.requestAuthorization()
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

                HStack(spacing: 10) {
                    LButton(title: "+ Metrics", style: .gradient) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddMetricsPopup = true
                        }
                    }

                    LButton(title: "+ Exercise", style: .gradient) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddExercisePopup = true
                        }
                    }
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
