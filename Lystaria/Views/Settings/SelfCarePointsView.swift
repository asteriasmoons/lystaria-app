//
//  SelfCarePointsView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import SwiftUI
import SwiftData
import Combine

struct SelfCarePointsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("isAdminMode") private var isAdminMode: Bool = false
    @State private var selectedEntryForAdminAction: SelfCarePointEntry? = nil
    @State private var showDeleteEntryConfirmation: Bool = false
    
    @State private var showLogHistoryPopup: Bool = false
    @State private var currentDayKey: String = SelfCarePointsManager.dayKey()
    @State private var visibleRecentEntryCount: Int = 4
    private let dayRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Query(sort: \SelfCarePointsResetLog.createdAt, order: .reverse)
    private var resetLogs: [SelfCarePointsResetLog]

    @Query private var profiles: [SelfCarePointsProfile]
    @Query(sort: \SelfCarePointEntry.createdAt, order: .reverse)
    private var allEntries: [SelfCarePointEntry]

    private var activeUserId: String? {
        try? SelfCarePointsManager.resolveActiveUserId(in: modelContext)
    }

    private var currentProfile: SelfCarePointsProfile? {
        guard let userId = activeUserId else { return nil }
        return profiles.first { $0.userId == userId }
    }

    private var recentEntries: [SelfCarePointEntry] {
        _ = currentDayKey
        guard let userId = activeUserId else { return [] }
        return allEntries
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var recentResetLogs: [SelfCarePointsResetLog] {
        guard let userId = activeUserId else { return [] }
        return resetLogs.filter { $0.userId == userId }
    }

    private var currentPoints: Int {
        currentProfile?.currentPoints ?? 0
    }

    private var lifetimePoints: Int {
        currentProfile?.lifetimePoints ?? 0
    }

    private var spentPoints: Int {
        currentProfile?.spentPoints ?? 0
    }

    private var level: Int {
        SelfCarePointsManager.level(for: currentPoints)
    }

    private var todayPoints: Int {
        _ = currentDayKey
        guard let userId = activeUserId else { return 0 }
        return (try? SelfCarePointsManager.pointsEarnedToday(in: modelContext, userId: userId)) ?? 0
    }

    private var progressValue: Int {
        SelfCarePointsManager.progressInCurrentLevel(for: currentPoints)
    }

    private var nextThreshold: Int {
        SelfCarePointsManager.pointsPerLevel
    }

    private var pointsNeeded: Int {
        SelfCarePointsManager.pointsNeededToNextLevel(for: currentPoints)
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 14) {
                    headerSection
                    statsGridSection
                    levelProgressSection
                    breakdownSection
                    recentActivitySection
                    earningGuideSection
                    logHistoryButtonSection

                    Spacer(minLength: 80)
                }
                .task {
                    if let userId = activeUserId {
                        _ = try? SelfCarePointsManager.fetchOrCreateProfile(in: modelContext, userId: userId)
                    }
                }
                .onReceive(dayRefreshTimer) { _ in
                    let newDayKey = SelfCarePointsManager.dayKey()
                    if newDayKey != currentDayKey {
                        currentDayKey = newDayKey
                        visibleRecentEntryCount = 4
                    }
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.vertical, 20)
            }

            if showLogHistoryPopup {
                LystariaOverlayPopup(
                    onClose: {
                        showLogHistoryPopup = false
                    },
                    width: 560,
                    heightRatio: 0.70,
                    header: {
                        HStack {
                            GradientTitle(text: "Log History", size: 28)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    showLogHistoryPopup = false
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(LColors.glassSurface2)
                                        .overlay(
                                            Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    },
                    content: {
                        Text(
                            recentResetLogs.isEmpty
                            ? "Your weekly reset history will appear here once your first Sunday reset happens."
                            : "Your weekly reset history page is coming next."
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading)

                        if let latest = recentResetLogs.first {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Latest Reset")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text(latest.resetAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text("Points archived: \(latest.pointsBeforeReset)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text("Level archived: \(latest.levelBeforeReset)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                    },
                    footer: {
                        HStack {
                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    showLogHistoryPopup = false
                                }
                            } label: {
                                Text("Close")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )
                .zIndex(10)
            }

            if showDeleteEntryConfirmation, let selectedEntry = selectedEntryForAdminAction {
                LystariaOverlayPopup(
                    onClose: {
                        selectedEntryForAdminAction = nil
                        showDeleteEntryConfirmation = false
                    },
                    width: 520,
                    heightRatio: 0.46,
                    header: {
                        HStack {
                            GradientTitle(text: "Delete Entry", size: 28)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedEntryForAdminAction = nil
                                    showDeleteEntryConfirmation = false
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(LColors.glassSurface2)
                                        .overlay(
                                            Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    },
                    content: {
                        Text("This admin action will remove the selected Recent Activity entry and adjust your points totals to match.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.leading)

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedEntry.title.isEmpty ? selectedEntry.sourceType.label : selectedEntry.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                Text(selectedEntry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)

                                Text("Points: +\(selectedEntry.points)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    },
                    footer: {
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedEntryForAdminAction = nil
                                    showDeleteEntryConfirmation = false
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                _ = try? SelfCarePointsManager.deletePointEntryAndAdjustTotals(
                                    in: modelContext,
                                    entry: selectedEntry
                                )

                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedEntryForAdminAction = nil
                                    showDeleteEntryConfirmation = false
                                }
                            } label: {
                                Text("Delete")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [LColors.gradientPink, LColors.danger],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )
                .zIndex(11)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                GradientTitle(text: "Self Care Points", size: 28)

                Spacer()
            }

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(
                    title: "Current Points",
                    value: "\(currentPoints)",
                    icon: "starburst",
                    gradient: [LColors.gradientPurple, LColors.gradientBlue]
                )

                statCard(
                    title: "Level",
                    value: "\(level)",
                    icon: "levelup",
                    gradient: [LColors.gradientPink, LColors.gradientYellow]
                )
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Today",
                    value: "\(todayPoints)",
                    icon: "calstar",
                    gradient: [LColors.gradientPink, LColors.gradientBlue]
                )

                statCard(
                    title: "Lifetime",
                    value: "\(lifetimePoints)",
                    icon: "infinity.circle.fill",
                    gradient: [LColors.gradientBlue, LColors.gradientDeepPurple]
                )
            }
        }
    }

    private func statCard(
        title: String,
        value: String,
        icon: String,
        gradient: [Color]
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                .fill(LColors.glassSurface)

            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            gradient[0].opacity(0.32),
                            gradient[1].opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                .stroke(LColors.glassBorder, lineWidth: 1)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.09))
                            .frame(width: 30, height: 30)

                        if UIImage(named: icon) != nil {
                            Image(icon)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(LColors.textPrimary)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                    }

                    Spacer()

                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Spacer()

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
    }

    // MARK: - Level Progress

    private var levelProgressSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Level Progress", icon: "chart.line.uptrend.xyaxis")

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You need \(pointsNeeded) more points to reach the next level.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LColors.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            let ratio = max(
                                0,
                                min(CGFloat(progressValue) / CGFloat(max(nextThreshold, 1)), 1)
                            )

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: LSpacing.pillRadius)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 14)

                                RoundedRectangle(cornerRadius: LSpacing.pillRadius)
                                    .fill(LGradients.header)
                                    .frame(width: geo.size.width * ratio, height: 14)
                            }
                        }
                        .frame(height: 14)

                        HStack {
                            Text("\(progressValue) / \(nextThreshold)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            Spacer()

                            Text("Level \(level + 1)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }
                }
            }
        }
        
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Points Breakdown", icon: "square.grid.2x2.fill")

            GlassCard {
                VStack(spacing: 12) {
                    breakdownRow(
                        icon: "sparkles",
                        title: "Current Points",
                        value: "\(currentPoints)"
                    )

                    divider

                    breakdownRow(
                        icon: "infinity.circle.fill",
                        title: "Lifetime Points",
                        value: "\(lifetimePoints)"
                    )

                    divider

                    breakdownRow(
                        icon: "arrow.up.arrow.down.circle.fill",
                        title: "Spent Points",
                        value: "\(spentPoints)"
                    )

                    divider

                    breakdownRow(
                        icon: "sun.max.fill",
                        title: "Earned Today",
                        value: "\(todayPoints)"
                    )
                }
            }
        }
    }

    private func breakdownRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LColors.accent)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Recent Activity", icon: "clock.arrow.circlepath")

            GlassCard {
                if recentEntries.isEmpty {
                    Text("No point activity yet. Start checking in, logging, and completing reminders to build your score.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(recentEntries.prefix(visibleRecentEntryCount))) { entry in
                            recentEntryRow(entry)
                                .onLongPressGesture {
                                    guard isAdminMode else { return }
                                    selectedEntryForAdminAction = entry
                                    showDeleteEntryConfirmation = true
                                }
                        }

                        if recentEntries.count > visibleRecentEntryCount {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        visibleRecentEntryCount += 4
                                    }
                                } label: {
                                    Text("Load More")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            LinearGradient(
                                                colors: [LColors.gradientBlue, LColors.gradientPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private func recentEntryRow(_ entry: SelfCarePointEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                    )
                    .frame(width: 38, height: 38)

                Image(systemName: iconName(for: entry.sourceType))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title.isEmpty ? entry.sourceType.label : entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)

                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            if isAdminMode {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }

            Text("+\(entry.points)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LColors.success)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Earning Guide

    private var earningGuideSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "How to Earn", icon: "gift.fill")

            GlassCard {
                VStack(spacing: 12) {
                    earnRow(icon: "checkmark.circle.fill", title: "Reminder Completion", amount: SelfCarePointsManager.reminderPoints)
                    divider
                    earnRow(icon: "calendar.badge.clock", title: "Event Reminder Completion", amount: SelfCarePointsManager.eventReminderPoints)
                    divider
                    earnRow(icon: "repeat.circle.fill", title: "Habit Reminder Completion", amount: SelfCarePointsManager.habitReminderPoints)
                    divider
                    earnRow(icon: "checklist.checked", title: "Habit Log", amount: SelfCarePointsManager.habitLogPoints)
                    divider
                    earnRow(icon: "book.fill", title: "Reading Check-In", amount: SelfCarePointsManager.readingCheckInPoints)
                    divider
                    earnRow(icon: "square.and.pencil", title: "Journal Entry", amount: SelfCarePointsManager.journalEntryPoints)
                    divider
                    earnRow(icon: "heart.text.square.fill", title: "Health Log", amount: SelfCarePointsManager.healthLogPoints)
                    divider
                    earnRow(icon: "figure.walk", title: "Exercise Log", amount: SelfCarePointsManager.exerciseLogPoints)
                    divider
                    earnRow(icon: "face.smiling.fill", title: "Mood Log", amount: SelfCarePointsManager.moodLogPoints)
                }
            }
        }
    }

    private func earnRow(icon: String, title: String, amount: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LColors.accent)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Text("+\(amount)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(LColors.glassBorder)
            .frame(height: 1)
    }

    private var logHistoryButtonSection: some View {
        GlassCard {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showLogHistoryPopup = true
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LColors.glassSurface2)
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "clock.badge")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log History")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)

                        Text("View weekly reset history and archived totals.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func iconName(for sourceType: SelfCarePointSourceType) -> String {
        switch sourceType {
        case .reminder:
            return "checkmark.circle.fill"
        case .eventReminder:
            return "calendar.badge.clock"
        case .habitReminder:
            return "repeat.circle.fill"
        case .habitLog:
            return "checklist.checked"
        case .readingCheckIn:
            return "book.fill"
        case .journalEntry:
            return "square.and.pencil"
        case .healthLog:
            return "heart.text.square.fill"
        case .exerciseLog:
            return "figure.walk"
        case .moodLog:
            return "face.smiling.fill"
        }
    }
    
}

