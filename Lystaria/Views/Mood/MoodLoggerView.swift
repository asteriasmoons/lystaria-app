//
// MoodLoggerView.swift
// Lystaria
//

import SwiftUI
import SwiftData
import WidgetKit

struct MoodLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let moodWidgetAppGroupID = "group.com.asteriasmoons.LystariaDev"
    private let lastMoodLogDateKey = "lastMoodLogDate"
    
    // Latest logs for display
    @Query(
        filter: #Predicate<MoodLog> { $0.deletedAt == nil },
        sort: \MoodLog.createdAt,
        order: .reverse
    ) private var logs: [MoodLog]
    
    // UI state
    @State private var selectedMoods: Set<String> = []
    @State private var selectedActivities: Set<String> = []
    @State private var note: String = ""
    @FocusState private var noteEditorFocused: Bool
    
    @State private var moodsExpanded: Bool = false
    @State private var activitiesExpanded: Bool = false
    
    @State private var selectedTab: MoodLogTab = .today
    @State private var historyVisibleCount: Int = 4
    @State private var showScoringInfoPopup: Bool = false
    @State private var logPendingDelete: MoodLog?
    @State private var showDeleteConfirmation: Bool = false
    
    private var latestLog: MoodLog? { logs.first }
    
    private var visibleHistoryLogs: [MoodLog] {
        Array(logs.prefix(historyVisibleCount))
    }
    
    private var canLoadMoreHistory: Bool {
        logs.count > historyVisibleCount
    }
    
    private var shouldShowMoodInsights: Bool {
        logs.count >= 3
    }

    private var allowedHistoryLogIds: Set<PersistentIdentifier> {
        guard let cutoff = limits.cutoffDate(for: .moodHistory) else {
            return Set(logs.map { $0.persistentModelID })
        }

        return Set(
            logs
                .filter { $0.createdAt >= cutoff }
                .map { $0.persistentModelID }
        )
    }
    
    private var averageMoodScore: Double {
        guard !logs.isEmpty else { return 0 }
        let total = logs.reduce(0.0) { $0 + $1.score }
        return total / Double(logs.count)
    }

    private func clampedValence(_ raw: Double) -> Double {
        if raw >= 0 {
            return max(raw, 1.0)
        } else {
            return min(raw, -1.0)
        }
    }

    private var averageValence: Double {
        guard !logs.isEmpty else { return 1.0 }
        let total = logs.reduce(0.0) { $0 + clampedValence($1.valence) }
        let avg = total / Double(logs.count)
        return clampedValence(avg)
    }

    private var averageIntensity: Double {
        guard !logs.isEmpty else { return 1 }
        let total = logs.reduce(0.0) { $0 + $1.intensity }
        return total / Double(logs.count)
    }
    
    private var mostPickedMoodKey: String? {
        var stats: [String: (count: Int, latestDate: Date)] = [:]

        for log in logs {
            for mood in log.moods {
                if let existing = stats[mood] {
                    stats[mood] = (
                        count: existing.count + 1,
                        latestDate: max(existing.latestDate, log.createdAt)
                    )
                } else {
                    stats[mood] = (count: 1, latestDate: log.createdAt)
                }
            }
        }

        return stats.max { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count < rhs.value.count
            }
            if lhs.value.latestDate != rhs.value.latestDate {
                return lhs.value.latestDate < rhs.value.latestDate
            }
            return lhs.key > rhs.key
        }?.key
    }
    
    private var mostPickedActivityKey: String? {
        var stats: [String: (count: Int, latestDate: Date)] = [:]

        for log in logs {
            for activity in log.activities {
                if let existing = stats[activity] {
                    stats[activity] = (
                        count: existing.count + 1,
                        latestDate: max(existing.latestDate, log.createdAt)
                    )
                } else {
                    stats[activity] = (count: 1, latestDate: log.createdAt)
                }
            }
        }

        return stats.max { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count < rhs.value.count
            }
            if lhs.value.latestDate != rhs.value.latestDate {
                return lhs.value.latestDate < rhs.value.latestDate
            }
            return lhs.key > rhs.key
        }?.key
    }

    // MARK: - Mood Streak

    private var uniqueLogDaysDescending: [Date] {
        let calendar = Calendar.current
        let days = Set(logs.map { calendar.startOfDay(for: $0.createdAt) })
        return days.sorted(by: >)
    }

    private var hasLoggedToday: Bool {
        guard let first = uniqueLogDaysDescending.first else { return false }
        return Calendar.current.isDateInToday(first)
    }

    private var currentMoodStreak: Int {
        let calendar = Calendar.current
        let days = uniqueLogDaysDescending
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var expected = calendar.startOfDay(for: Date())

        // If no log today, start from yesterday (so streak shows but user hasn't logged today)
        if !hasLoggedToday {
            expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
        }

        for day in days {
            if calendar.isDate(day, inSameDayAs: expected) {
                streak += 1
                expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
            } else {
                break
            }
        }

        return streak
    }

    private var bestMoodStreak: Int {
        let calendar = Calendar.current
        let days = uniqueLogDaysDescending
        guard !days.isEmpty else { return 0 }

        var best = 0
        var current = 0
        var previous: Date?

        for day in days.sorted(by: <) { // iterate oldest → newest
            if let prev = previous {
                let expected = calendar.date(byAdding: .day, value: 1, to: prev)!
                if calendar.isDate(day, inSameDayAs: expected) {
                    current += 1
                } else {
                    current = 1
                }
            } else {
                current = 1
            }

            best = max(best, current)
            previous = day
        }

        return best
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                
                VStack(spacing: 14) {
                    if shouldShowMoodInsights {
                        MoodInsightsCard(
                            mostPickedMood: mostPickedMoodKey.map { moodLabel($0) } ?? "No mood yet",
                            mostPickedActivity: mostPickedActivityKey.map { activityLabel($0) } ?? "No activity yet",
                            averageScore: averageMoodScore,
                            averageValence: averageValence,
                            averageIntensity: averageIntensity
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                        .onTapGesture {
                            showScoringInfoPopup = true
                        }
                    }

                    MoodStreakCard(
                        streak: currentMoodStreak,
                        bestStreak: bestMoodStreak,
                        hasLoggedToday: hasLoggedToday
                    )
                    
                    moodLogTabs
                    
                    // Logger card
                    FreeFormGlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            MultiSelectDropdown(
                                title: "Moods",
                                subtitle: "Choose one or more",
                                isExpanded: $moodsExpanded,
                                selections: $selectedMoods,
                                options: MoodLog.moodValues,
                                pillLabel: { key in
                                    moodLabel(key)
                                },
                                accent: Color(red: 3/255, green: 219/255, blue: 252/255)
                            )
                            
                            MultiSelectDropdown(
                                title: "Activities",
                                subtitle: "Choose one or more",
                                isExpanded: $activitiesExpanded,
                                selections: $selectedActivities,
                                options: MoodLog.moodActivities,
                                pillLabel: { key in
                                    activityLabel(key)
                                },
                                accent: Color(red: 125/255, green: 25/255, blue: 247/255)
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NOTE")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                AutoGrowingMoodNoteEditor(
                                    placeholder: "How's your day going?",
                                    text: $note,
                                    minHeight: 80,
                                    isFocused: $noteEditorFocused
                                )
                            }
                            
                            HStack {
                                Spacer()
                                
                                Button {
                                    logMood()
                                } label: {
                                    Text("Log Mood")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(
                                            (selectedMoods.isEmpty || selectedActivities.isEmpty)
                                            ? AnyShapeStyle(Color.gray.opacity(0.3))
                                            : AnyShapeStyle(LGradients.blue)
                                        )
                                        .clipShape(Capsule())
                                        .shadow(color: (selectedMoods.isEmpty || selectedActivities.isEmpty) ? .clear : LColors.accent.opacity(0.3), radius: 8, y: 4)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedMoods.isEmpty || selectedActivities.isEmpty)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    if selectedTab == .today {
                        if let latestLog {
                            MoodLogCard(log: latestLog)
                        } else {
                            EmptyState(icon: "face.smiling", message: "No mood logs yet.\nLog your first mood above.")
                                .padding(.top, 8)
                        }
                    } else {
                        if visibleHistoryLogs.isEmpty {
                            EmptyState(icon: "clock.arrow.circlepath", message: "No mood history yet.\nYour logged moods will appear here.")
                                .padding(.top, 8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(visibleHistoryLogs) { log in
                                    MoodLogCard(
                                        log: log,
                                        showsDeleteButton: true,
                                        onDelete: {
                                            logPendingDelete = log
                                            showDeleteConfirmation = true
                                        }
                                    )
                                    .premiumLocked(!limits.hasPremiumAccess && !allowedHistoryLogIds.contains(log.persistentModelID))
                                }
                                
                                if canLoadMoreHistory {
                                    Button {
                                        historyVisibleCount += 4
                                    } label: {
                                        Text("Load More")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 10)
                                            .background(AnyShapeStyle(LGradients.blue))
                                            .clipShape(Capsule())
                                            .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 14)
                .padding(.bottom, 140)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 24)
        }
        .background(
            LystariaBackground()
                .ignoresSafeArea()
        )
        .overlay {
            if showScoringInfoPopup {
                LystariaOverlayPopup(
                    onClose: { showScoringInfoPopup = false },
                    width: 560,
                    heightRatio: 0.72
                ) {
                    HStack {
                        GradientTitle(text: "How Scores Work", size: 24)
                        Spacer()
                    }
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When you log a mood, Lystaria calculates three numbers behind the scenes. Here's what they actually mean.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                            .padding(.bottom, 4)

                        scoringExplainerRow(
                            icon: "starfill",
                            title: "Mood Score",
                            range: "1.0 – 5.0",
                            description: "Every mood in the list has a score assigned to it — something like 4.3 for \"happy\" or 1.6 for \"overwhelmed\". When you select multiple moods, those scores get averaged into one number. Think of it as a simple snapshot of how good or hard your day felt emotionally. A score around 3 is neutral. Above 4 is a genuinely good day. Below 2 usually means something heavy was going on."
                        )

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)

                        scoringExplainerRow(
                            icon: "wavyheart",
                            title: "Emotional Tone",
                            range: "-3.0 to +3.0",
                            description: "Emotional tone goes a step further than the score — it looks at whether your feelings were leaning positive or negative, and how strongly. It runs from -3 (deeply negative, like feeling scared or defeated) to +3 (deeply positive, like feeling loved or grateful). The calculation also considers intensity, so a mild negative feeling won't drag your tone down as much as an intense one would. It never lands at exactly zero — it always leans one way, even slightly."
                        )

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)

                        scoringExplainerRow(
                            icon: "boltfill",
                            title: "Intensity",
                            range: "1.0 – 5.0",
                            description: "Intensity has nothing to do with whether you felt good or bad. It's about how much emotional energy was behind your feelings. Calm, mellow, composed — those are low intensity, around 1 or 2. Energized, angry, overwhelmed, inspired — those are high intensity, around 4 or 5. You can have a great day with high intensity (energized, motivated) or a rough day with low intensity (apathetic, detached). Tracking this over time helps you notice patterns in your emotional energy, separate from whether things were going well."
                        )
                    }
                } footer: {
                    LButton(title: "Got It", style: .gradient) {
                        showScoringInfoPopup = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showScoringInfoPopup)
        .alert("Delete Mood Log?", isPresented: $showDeleteConfirmation, presenting: logPendingDelete) { log in
            Button("Cancel", role: .cancel) {
                logPendingDelete = nil
            }

            Button("Delete", role: .destructive) {
                deleteLog(log)
                logPendingDelete = nil
            }
        } message: { _ in
            Text("This mood log will be permanently removed.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    noteEditorFocused = false
                }
                .font(.system(size: 16, weight: .bold))
            }
        }
    }
    
    private var moodLogTabs: some View {
        HStack(spacing: 8) {
            moodTabButton(.today, title: "Today")
            moodTabButton(.history, title: "History")
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private func moodTabButton(_ tab: MoodLogTab, title: String) -> some View {
        let isSelected = selectedTab == tab
        
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? AnyShapeStyle(LGradients.blue)
                    : AnyShapeStyle(Color.white.opacity(0.08))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Mood Log", font: .system(size: 28, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }
    
    // MARK: - Actions
    
    private func logMood() {
        // Enforce 1 mood log per day
        let descriptor = FetchDescriptor<MoodLog>()
        let existingLogs = (try? modelContext.fetch(descriptor)) ?? []
        let todayCount = existingLogs.filter { limits.isSameDay($0.createdAt, Date()) }.count
        let decision = limits.canCreate(.moodEntriesPerDay, currentCount: todayCount)
        guard decision.allowed else { return }
        guard !selectedMoods.isEmpty else { return }
        
        do {
            try MoodLogWriter.saveMoodLog(
                moods: Array(selectedMoods),
                activities: Array(selectedActivities),
                note: note,
                modelContext: modelContext
            )

            if let newestLog = logs.first {
                _ = try? SelfCarePointsManager.awardPoints(
                    in: modelContext,
                    sourceType: .moodLog,
                    sourceId: "\(newestLog.persistentModelID)",
                    sourceKey: "moodLog:\(newestLog.persistentModelID)",
                    points: SelfCarePointsManager.moodLogPoints,
                    title: "Mood Log",
                    earnedAt: newestLog.createdAt
                )
            }
            
            if let defaults = UserDefaults(suiteName: moodWidgetAppGroupID) {
                defaults.set(Date(), forKey: lastMoodLogDateKey)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "Lystaria_Widgets")

            selectedMoods.removeAll()
            selectedActivities.removeAll()
            note = ""
            moodsExpanded = false
            activitiesExpanded = false
        } catch {
            print("Failed to save mood log: \(error)")
        }
    }

    @ViewBuilder
    private func scoringExplainerRow(icon: String, title: String, range: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GradientTitle(text: title, size: 20)

            Text(description)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }

    private func deleteLog(_ log: MoodLog) {
        log.deletedAt = Date()
        log.touchUpdated()

        do {
            try modelContext.save()

            let calendar = Calendar.current
            let hasRemainingMoodLogToday = logs.contains {
                $0.persistentModelID != log.persistentModelID &&
                $0.deletedAt == nil &&
                calendar.isDate($0.createdAt, inSameDayAs: Date())
            }

            if let defaults = UserDefaults(suiteName: moodWidgetAppGroupID) {
                if hasRemainingMoodLogToday {
                    defaults.set(Date(), forKey: lastMoodLogDateKey)
                } else {
                    defaults.removeObject(forKey: lastMoodLogDateKey)
                }
            }

            WidgetCenter.shared.reloadTimelines(ofKind: "Lystaria_Widgets")
        } catch {
            print("Failed to delete mood log: \(error)")
        }
    }
}


// MARK: - FreeFormGlassCard

private struct FreeFormGlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LColors.glassSurface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            )
    }
}

private struct AutoGrowingMoodNoteEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    var isFocused: FocusState<Bool>.Binding

    @State private var measuredHeight: CGFloat = 80

    private var editorHeight: CGFloat {
        max(minHeight, measuredHeight)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused(isFocused)
                .font(.system(size: 15))
                .foregroundStyle(LColors.textPrimary)
                .frame(height: editorHeight)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .background(
                    AutoGrowingTextMeasure(text: text, minHeight: minHeight, measuredHeight: $measuredHeight)
                )
        }
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        )
    }
}

private struct AutoGrowingTextMeasure: View {
    let text: String
    let minHeight: CGFloat
    @Binding var measuredHeight: CGFloat

    var body: some View {
        Text(text.isEmpty ? " " : text + "\n")
            .font(.system(size: 15))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            measuredHeight = max(minHeight, proxy.size.height)
                        }
                        .onChange(of: text) { _, _ in
                            measuredHeight = max(minHeight, proxy.size.height)
                        }
                }
            )
            .hidden()
            .allowsHitTesting(false)
    }
}

// MARK: - Multi Select Dropdown

private struct MultiSelectDropdown: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @Binding var selections: Set<String>
    let options: [String]
    let pillLabel: (String) -> String
    let accent: Color

    private var selectedPreview: String {
        if selections.isEmpty { return "None" }
        if selections.count == 1 { return pillLabel(selections.first!) }
        return "\(selections.count) selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary.opacity(0.8))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedPreview)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(1)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(options, id: \.self) { key in
                        let isOn = selections.contains(key)
                        Button {
                            if isOn { selections.remove(key) } else { selections.insert(key) }
                        } label: {
                            Text(pillLabel(key))
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(isOn ? accent.opacity(0.18) : Color.white.opacity(0.06))
                                .foregroundStyle(isOn ? accent : LColors.textPrimary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isOn ? accent : LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }

            if !selections.isEmpty {
                // Selected chips row
                FlowChips(
                    items: selections.sorted(),
                    label: { "#\($0)" },
                    onRemove: { selections.remove($0) },
                    tint: accent
                )
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Mood Insights Card

private struct MoodInsightsCard: View {
    let mostPickedMood: String
    let mostPickedActivity: String
    let averageScore: Double
    let averageValence: Double
    let averageIntensity: Double

    private var averageScoreProgress: Double {
        min(max(averageScore / 5.0, 0), 1)
    }

    private var averageValenceProgress: Double {
        min(max((averageValence + 3.0) / 6.0, 0), 1)
    }

    private var averageIntensityProgress: Double {
        min(max(averageIntensity / 5.0, 0), 1)
    }
    
    private var averageValenceText: String {
        if averageValence > 0 {
            return String(format: "+%.1f", averageValence)
        } else {
            return String(format: "%.1f", averageValence)
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("facefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Mood Insights", font: .system(size: 20, weight: .bold))
                    Spacer()
                }

                HStack(spacing: 10) {
                    insightBubble(title: "MOST PICKED MOOD", value: mostPickedMood)
                    insightBubble(title: "MOST PICKED ACTIVITY", value: mostPickedActivity)
                }

                VStack(alignment: .leading, spacing: 12) {
                    insightProgressRow(
                        title: "Average Score",
                        valueText: String(format: "%.1f", averageScore),
                        progress: averageScoreProgress
                    )

                    insightProgressRow(
                        title: "Emotional Tone",
                        valueText: averageValenceText,
                        progress: averageValenceProgress
                    )

                    insightProgressRow(
                        title: "Average Intensity",
                        valueText: String(format: "%.1f", averageIntensity),
                        progress: averageIntensityProgress
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func insightProgressRow(title: String, valueText: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
            }

            ScoreBar(progress: progress)
        }
    }

    @ViewBuilder
    private func insightBubble(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Mood Log Card

private struct MoodLogCard: View {
    let log: MoodLog
    var showsDeleteButton: Bool = false
    var onDelete: (() -> Void)? = nil

    private var scoreProgress: Double {
        min(max(log.score / 5.0, 0), 1)
    }

    private var valenceProgress: Double {
        min(max((displayValence + 3.0) / 6.0, 0), 1)
    }

    private var intensityProgress: Double {
        min(max(log.intensity / 5.0, 0), 1)
    }

    private var displayValence: Double {
        if log.valence >= 0 {
            return max(log.valence, 1.0)
        } else {
            return min(log.valence, -1.0)
        }
    }

    private var valenceText: String {
        if displayValence > 0 {
            return String(format: "+%.1f", displayValence)
        } else {
            return String(format: "%.1f", displayValence)
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GradientTitle(text: "Latest Mood", font: .system(size: 18, weight: .bold))
                    Spacer()
                    Text(log.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    logMetricRow(
                        title: "Mood Score",
                        valueText: String(format: "%.1f", log.score),
                        progress: scoreProgress
                    )

                    logMetricRow(
                        title: "Emotional Tone",
                        valueText: valenceText,
                        progress: valenceProgress
                    )

                    logMetricRow(
                        title: "Intensity",
                        valueText: String(format: "%.1f", log.intensity),
                        progress: intensityProgress
                    )
                }

                if !log.moods.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Moods")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        FlowChips(
                            items: log.moods,
                            label: { moodLabel($0) },
                            onRemove: nil,
                            tint: Color(red: 3/255, green: 219/255, blue: 252/255)
                        )
                    }
                }

                if !log.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activities")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        FlowChips(
                            items: log.activities,
                            label: { "#\(activityLabel($0))" },
                            onRemove: nil,
                            tint: Color(red: 125/255, green: 25/255, blue: 247/255)
                        )
                    }
                }

                if let note = log.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    GlassCard(padding: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)

                            Text(note)
                                .font(.system(size: 13))
                                .foregroundStyle(LColors.textPrimary)
                        }
                    }
                }
                if showsDeleteButton, let onDelete {
                    HStack {
                        Spacer()

                        Button {
                            onDelete()
                        } label: {
                            HStack(spacing: 8) {
                                Image("trashfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.white)

                                Text("Delete")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AnyShapeStyle(LGradients.blue))
                            .clipShape(Capsule())
                            .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Score Bar

private struct ScoreBar: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 3/255, green: 219/255, blue: 252/255),
                                Color(red: 125/255, green: 25/255, blue: 247/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, w * CGFloat(min(1, max(0, progress)))))
            }
        }
        .frame(height: 10)
        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Flow Chips (wrap layout)

private struct FlowChips: View {
    let items: [String]
    let label: (String) -> String
    let onRemove: ((String) -> Void)?
    let tint: Color

    // Adaptive grid wraps to new lines without breaking ScrollView layout.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(label(item))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                        .lineLimit(1)

                    if let onRemove {
                        Button {
                            onRemove(item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(tint.opacity(0.6), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Labels / Emoji

private func moodLabel(_ key: String) -> String {
    // Title-case-ish label (keeps hyphens as-is)
    let parts = key.split(separator: "-").map { part -> String in
        guard let first = part.first else { return "" }
        return String(first).uppercased() + part.dropFirst()
    }
    return parts.joined(separator: " ")
}

private func activityLabel(_ key: String) -> String {
    let parts = key.split(separator: "-").map { part -> String in
        guard let first = part.first else { return "" }
        return String(first).uppercased() + part.dropFirst()
    }
    return parts.joined(separator: " ")
}



#Preview {
    ZStack {
        LystariaBackground()
        MoodLoggerView()
            .padding(.vertical, 20)
    }
}

enum MoodLogTab {
    case today
    case history
}

// MARK: - Mood Streak Card

private struct MoodStreakCard: View {
    let streak: Int
    let bestStreak: Int
    let hasLoggedToday: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 10) {
                    Image("boltfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Mood Streak", font: .system(size: 20, weight: .bold))

                    Spacer()

                    Text(hasLoggedToday ? "Active" : "Waiting")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(hasLoggedToday ? LColors.textPrimary : LColors.textSecondary)
                }

                HStack(spacing: 12) {
                    streakBubble(
                        value: streak,
                        label: "Current"
                    )

                    streakBubble(
                        value: bestStreak,
                        label: "Best"
                    )
                }
                .frame(maxWidth: .infinity)

                Text(hasLoggedToday
                     ? "You showed up for yourself today."
                     : "Log today to keep your streak going.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func streakBubble(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text("\(value)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LColors.glassBorder.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

    @ViewBuilder
    private func logMetricRow(title: String, valueText: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
            }

            ScoreBar(progress: progress)
        }
    }
