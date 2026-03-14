//
// DailyIntentionView.swift
//
// Created by Asteria Moon
//

import SwiftUI
import SwiftData
import Combine

struct DailyIntentionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // UI state
    @State private var text: String = ""
    @State private var isEditing: Bool = true
    @State private var loaded: Bool = false
    @State private var loadedDayKey: String = ""
    @State private var dayChangeChecksEnabled: Bool = false

    // The SwiftData record for today
    @State private var record: DailyIntention? = nil

    private let dayChangeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - Date helpers

    private var todayComponents: DateComponents {
        Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: Date())
    }

    private var todayDate: Date {
        Calendar.current.date(from: todayComponents) ?? Date()
    }

    private var todayKey: String {
        let cal = Calendar.autoupdatingCurrent
        let df = DateFormatter()
        df.calendar = cal
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: todayDate)
    }

    private var storageKey: String {
        "dailyIntentionText.\(todayKey)"
    }

    // MARK: - Body

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: star icon + title, right-aligned action when editing state
                HStack(spacing: 10) {
                    Image("starfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.white)

                    GradientTitle(text: "Daily Intention", font: .system(size: 16, weight: .bold))

                    Spacer()

                    if isEditing {
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(LColors.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if isEditing {
                    // Entry mode: TextEditor with placeholder
                    ZStack(alignment: .topLeading) {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Set an intention for today…")
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }

                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(minHeight: 90)
                            .padding(6)
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    // Saved mode: quote stripe with clear/edit actions
                    VStack(alignment: .leading, spacing: 10) {
                        // Stripe box (flush, no overlap)
                        HStack(spacing: 0) {
                            // Left accent stripe
                            Rectangle()
                                .fill(LColors.accent.opacity(0.55))
                                .frame(width: 5)

                            Text(text)
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(LColors.glassSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )

                        HStack(spacing: 10) {
                            LButton(title: "Edit", icon: "pencil", style: .secondary) {
                                isEditing = true
                            }
                            GradientCapsuleButton(title: "Clear", icon: "trashfill") {
                                clear()
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadForToday()

            // Do not run day-change reset logic immediately on app/view startup.
            // Give the app a moment to finish loading first.
            dayChangeChecksEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dayChangeChecksEnabled = true
            }
        }
        .onReceive(dayChangeTimer) { _ in
            guard dayChangeChecksEnabled else { return }
            refreshForDayChangeIfNeeded()
        }
        .onDisappear {
            // Extra insurance if the user navigates away.
            persistToUserDefaults()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // If the app becomes active after midnight or a timezone change, reload for the new day,
            // but only after the initial startup delay has passed.
            if newPhase == .active, dayChangeChecksEnabled {
                refreshForDayChangeIfNeeded(forceReload: true)
            }

            // If the app is closed/backgrounded quickly, ensure the latest text is written.
            if newPhase == .inactive || newPhase == .background {
                persistToUserDefaults()
                try? modelContext.save()
            }
        }
    }

    // MARK: - Actions

    private func loadForToday() {
        guard !loaded || loadedDayKey != todayKey else { return }

        // Try to load today’s record
        if let existing = try? modelContext.fetch(
            FetchDescriptor<DailyIntention>(
                predicate: #Predicate { $0.dateKey == todayKey }
            )
        ).first {
            record = existing
            text = existing.text
            isEditing = existing.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            // No SwiftData record for today yet.
            // Fall back to UserDefaults so intentions survive restarts even if SwiftData save didn't happen.
            let cached = UserDefaults.standard.string(forKey: storageKey) ?? ""
            if !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = cached
                isEditing = false

                // Rehydrate SwiftData so future loads come from the model.
                let r = DailyIntention(date: todayDate, text: cached)
                modelContext.insert(r)
                record = r
                try? modelContext.save()
            } else {
                record = nil
                text = ""
                isEditing = true
            }
        }
        loadedDayKey = todayKey
        loaded = true
    }

    private func refreshForDayChangeIfNeeded(forceReload: Bool = false) {
        let currentKey = todayKey
        guard forceReload || loadedDayKey != currentKey else { return }

        // Day changed (or app re-activated): clear view state and load the record for the new day.
        text = ""
        isEditing = true
        record = nil
        loaded = false
        loadedDayKey = ""
        loadForToday()
    }

    private func persistToUserDefaults() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: storageKey)
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try DailyIntentionWriter.setTodayIntention(
                trimmed,
                modelContext: modelContext
            )

            let key = DailyIntentionWriter.todayKey()

            let descriptor = FetchDescriptor<DailyIntention>(
                predicate: #Predicate<DailyIntention> { $0.dateKey == key }
            )

            record = try modelContext.fetch(descriptor).first
            text = trimmed
            isEditing = false

        } catch {
            print("Failed to save daily intention: \(error)")
        }
    }

    private func clear() {
        text = ""
        UserDefaults.standard.set("", forKey: storageKey)
        if let r = record {
            r.text = ""
            r.updatedAt = Date()
            try? modelContext.save()
        }
        isEditing = true
    }
}

#Preview {
    ZStack {
        LystariaBackground()
        DailyIntentionView()
            .padding()
    }
    .preferredColorScheme(.dark)
}
