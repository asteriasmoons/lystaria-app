// MoodLoggerView.swift
// Lystaria

import SwiftUI
import SwiftData

struct MoodLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
    
    @State private var moodsExpanded: Bool = false
    @State private var activitiesExpanded: Bool = false
    
    @State private var selectedTab: MoodLogTab = .today
    @State private var historyVisibleCount: Int = 4
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
    
    private var averageMoodScore: Double {
        guard !logs.isEmpty else { return 0 }
        let total = logs.reduce(0.0) { $0 + $1.score }
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                
                VStack(spacing: 14) {
                    if shouldShowMoodInsights {
                        MoodInsightsCard(
                            mostPickedMood: mostPickedMoodKey.map { moodLabel($0) } ?? "No mood yet",
                            mostPickedActivity: mostPickedActivityKey.map { activityLabel($0) } ?? "No activity yet",
                            averageScore: averageMoodScore
                        )
                    }
                    
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
                                
                                GlassTextEditor(
                                    placeholder: "How's your day going? (optional)",
                                    text: $note,
                                    minHeight: 120
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
        guard !selectedMoods.isEmpty else { return }
        
        do {
            try MoodLogWriter.saveMoodLog(
                moods: Array(selectedMoods),
                activities: Array(selectedActivities),
                note: note,
                modelContext: modelContext
            )
            
            selectedMoods.removeAll()
            selectedActivities.removeAll()
            note = ""
            moodsExpanded = false
            activitiesExpanded = false
        } catch {
            print("Failed to save mood log: \(error)")
        }
    }

    private func deleteLog(_ log: MoodLog) {
        log.deletedAt = Date()
        log.touchUpdated()

        do {
            try modelContext.save()
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

    private var averageProgress: Double {
        min(max(averageScore / 5.0, 0), 1)
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Average Mood Score")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f / 5", averageScore))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    ScoreBar(progress: averageProgress)
                }
            }
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

    private var percent: Double {
        // score is 1...5
        (log.score / 5.0)
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

                // Score bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mood score")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f / 5", log.score))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    ScoreBar(progress: percent)
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(LColors.textPrimary)
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
