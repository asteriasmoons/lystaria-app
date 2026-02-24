//
//  WatchMoodLogger.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import SwiftData

struct WatchMoodLoggerView: View {

    @Environment(\.modelContext) private var modelContext

    private var lystariaBackground: some View {
        WatchLystariaBackground()
    }

    var body: some View {
        NavigationStack {
            MoodSelectionView()
                .background(lystariaBackground)
        }
    }
}

struct MoodSelectionView: View {

    @State private var selectedMoods: Set<String> = []

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 10) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(MoodLog.moodValues, id: \.self) { mood in
                            Button {
                                if selectedMoods.contains(mood) {
                                    selectedMoods.remove(mood)
                                } else {
                                    selectedMoods.insert(mood)
                                }
                            } label: {
                                HStack {
                                    Text(mood.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    if selectedMoods.contains(mood) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.18))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            ActivitySelectionView(selectedMoods: Array(selectedMoods))
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 125/255, green: 25/255, blue: 247/255),
                                            Color(red: 3/255, green: 219/255, blue: 252/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selectedMoods.isEmpty)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Mood")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct ActivitySelectionView: View {

    let selectedMoods: [String]

    @State private var selectedActivities: Set<String> = []

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 10) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(MoodLog.moodActivities, id: \.self) { activity in
                            Button {
                                if selectedActivities.contains(activity) {
                                    selectedActivities.remove(activity)
                                } else {
                                    selectedActivities.insert(activity)
                                }
                            } label: {
                                HStack {
                                    Text(activity.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    if selectedActivities.contains(activity) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.18))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            SaveMoodView(moods: selectedMoods, activities: Array(selectedActivities))
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 125/255, green: 25/255, blue: 247/255),
                                            Color(red: 3/255, green: 219/255, blue: 252/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selectedActivities.isEmpty)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Activity")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct SaveMoodView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let moods: [String]
    let activities: [String]

    @State private var saved = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack {
                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                } else if saved {
                    Text("Saved")
                        .font(.headline)
                        .foregroundStyle(.white)
                } else if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Button {
                        Task {
                            await logMood()
                        }
                    } label: {
                        Text("Log Mood")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 125/255, green: 25/255, blue: 247/255),
                                        Color(red: 3/255, green: 219/255, blue: 252/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .navigationTitle("Log Mood")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func logMood() async {
        isSaving = true
        errorMessage = nil

        let log = MoodLog(
            moods: moods,
            activities: activities,
            note: nil
        )

        modelContext.insert(log)

        do {
            try modelContext.save()
            try await MoodLogService.shared.saveMoodLog(log, in: modelContext)
            saved = true
            dismiss()
        } catch {
            errorMessage = "Unable to Save"
            print("Failed to save mood log: \(error)")
        }

        isSaving = false
    }
}

struct WatchLystariaBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.13, blue: 0.22),
                    Color.black,
                    Color(red: 0.08, green: 0.06, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.35),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 160
            )

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.25),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 170
            )

            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WatchMoodLoggerView()
}
