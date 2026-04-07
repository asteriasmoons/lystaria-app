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

    @Query(sort: \DailyIntention.updatedAt, order: .reverse)
    private var intentions: [DailyIntention]

    @State private var text: String = ""
    @State private var isEditing: Bool = true
    @State private var lastSyncedText: String = ""
    @State private var dayChangeChecksEnabled: Bool = false
    @FocusState private var isTextEditorFocused: Bool

    private let dayChangeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var todayKey: String {
        DailyIntentionWriter.todayKey()
    }

    private var todayRecord: DailyIntention? {
        intentions.first(where: { $0.dateKey == todayKey })
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
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
                        Button(action: {
                            isTextEditorFocused = false
                            save()
                        }) {
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
                    ZStack(alignment: .topLeading) {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Set an intention for today…")
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }

                        TextEditor(text: $text)
                            .focused($isTextEditorFocused)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(minHeight: 90)
                            .padding(6)
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextEditorFocused = true
                                }
                            }

                            GradientCapsuleButton(title: "Clear", icon: "trashfill") {
                                clear()
                            }

                            Spacer()
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isTextEditorFocused {
                    isTextEditorFocused = false
                }
            }
        }
        .onAppear {
            ensureTodayRecordExists()
            syncFromModel()

            dayChangeChecksEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dayChangeChecksEnabled = true
            }
        }
        .onReceive(dayChangeTimer) { _ in
            guard dayChangeChecksEnabled else { return }
            refreshForDayChangeIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, dayChangeChecksEnabled {
                refreshForDayChangeIfNeeded(forceReload: true)
                syncFromModel()
            }
        }
        .onChange(of: todayRecord?.text ?? "") { _, newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let current = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalized != current, !isEditing {
                text = normalized
            }

            lastSyncedText = normalized
            isEditing = normalized.isEmpty
        }
    }

    private func ensureTodayRecordExists() {
        do {
            _ = try DailyIntentionWriter.fetchOrCreateTodayRecord(modelContext: modelContext)
        } catch {
            print("Failed to ensure daily intention record exists: \(error)")
        }
    }

    private func syncFromModel() {
        let modelText = todayRecord?.text ?? ""
        let normalized = modelText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !isEditing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == lastSyncedText {
            text = normalized
        }

        lastSyncedText = normalized
        isEditing = normalized.isEmpty
        if !isEditing {
            isTextEditorFocused = false
        }
    }

    private func refreshForDayChangeIfNeeded(forceReload: Bool = false) {
        let currentKey = todayKey
        let currentRecordKey = todayRecord?.dateKey ?? ""

        guard forceReload || currentRecordKey != currentKey else { return }

        do {
            _ = try DailyIntentionWriter.fetchOrCreateTodayRecord(modelContext: modelContext)
            syncFromModel()
        } catch {
            print("Failed to refresh daily intention for day change: \(error)")
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try DailyIntentionWriter.setTodayIntention(
                trimmed,
                modelContext: modelContext
            )

            text = trimmed
            lastSyncedText = trimmed
            isEditing = false
            isTextEditorFocused = false
        } catch {
            print("Failed to save daily intention: \(error)")
        }
    }

    private func clear() {
        do {
            try DailyIntentionWriter.clearTodayIntention(modelContext: modelContext)
            text = ""
            lastSyncedText = ""
            isEditing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextEditorFocused = true
            }
        } catch {
            print("Failed to clear daily intention: \(error)")
        }
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
