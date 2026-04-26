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
    @StateObject private var limits = LimitManager.shared
    
    @AppStorage("isAdminMode") private var isAdminMode: Bool = false
    @State private var selectedEntryForAdminAction: SelfCarePointEntry? = nil
    @State private var showDeleteEntryConfirmation: Bool = false
    @State private var showManualHistoryConfirmation: Bool = false
    
    @State private var showLogHistoryPopup: Bool = false
    @State private var selectedHistoryLog: SelfCarePointsResetLog? = nil
    @State private var visibleHistoryCount: Int = 4
    @State private var historyLogToDelete: SelfCarePointsResetLog? = nil
    @State private var showDeleteHistoryConfirmation: Bool = false
    @State private var currentDayKey: String = SelfCarePointsManager.dayKey()
    @State private var visibleRecentEntryCount: Int = 4
    private let dayRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Query(sort: \SelfCarePointsResetLog.createdAt, order: .reverse)
    private var resetLogs: [SelfCarePointsResetLog]

    @Query private var profiles: [SelfCarePointsProfile]
    @Query(sort: \SelfCarePointEntry.createdAt, order: .reverse)
    private var allEntries: [SelfCarePointEntry]

    @State private var activeUserId: String? = nil

    private var currentProfile: SelfCarePointsProfile? {
        if let userId = activeUserId {
            return profiles.first { $0.userId == userId } ?? profiles.first
        }
        return profiles.first
    }

    private var recentEntries: [SelfCarePointEntry] {
        _ = currentDayKey
        if let userId = activeUserId {
            let filtered = allEntries.filter { $0.userId == userId }
            return filtered.isEmpty ? allEntries.sorted { $0.createdAt > $1.createdAt }
                                    : filtered.sorted { $0.createdAt > $1.createdAt }
        }
        return allEntries.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var recentResetLogs: [SelfCarePointsResetLog] {
        // Show all logs — there is only one user per device.
        // Filtering by userId is the bug: if userId resolves differently
        // than what was stored, the list is always empty.
        return resetLogs
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
                        manualLogHistoryButtonSection
                        logHistoryButtonSection

                        Spacer(minLength: 80)
                    }
                    .task {
                        activeUserId = try? SelfCarePointsManager.resolveActiveUserId(in: modelContext)
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
                .premiumLocked(!limits.canAccess(.selfCareSystem))
            }

            if showLogHistoryPopup {
                LystariaOverlayPopup(
                    onClose: {
                        showLogHistoryPopup = false
                        visibleHistoryCount = 4
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
                                    visibleHistoryCount = 4
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
                        if recentResetLogs.isEmpty {
                            Text("No automatic or manual history has been saved yet.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                                .multilineTextAlignment(.leading)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(recentResetLogs.prefix(visibleHistoryCount))) { log in
                                    GlassCard {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(historyTitle(for: log))
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(LColors.textPrimary)
                                                    .lineLimit(1)

                                                Text(log.resetAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(LColors.textSecondary)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("\(log.pointsBeforeReset) pts")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(LColors.textPrimary)

                                                Text("Lv \(log.levelBeforeReset)")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(LColors.textSecondary)
                                            }

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(LColors.textSecondary)
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            selectedHistoryLog = log
                                        }
                                    }
                                    .onLongPressGesture {
                                        historyLogToDelete = log
                                        showDeleteHistoryConfirmation = true
                                    }
                                    .confirmationDialog(
                                        "Delete History Entry?",
                                        isPresented: $showDeleteHistoryConfirmation,
                                        titleVisibility: .visible
                                    ) {
                                        Button("Delete", role: .destructive) {
                                            if let toDelete = historyLogToDelete {
                                                modelContext.delete(toDelete)
                                                try? modelContext.save()
                                                historyLogToDelete = nil
                                                if visibleHistoryCount > recentResetLogs.count {
                                                    visibleHistoryCount = max(4, recentResetLogs.count)
                                                }
                                            }
                                        }
                                        Button("Cancel", role: .cancel) {
                                            historyLogToDelete = nil
                                        }
                                    } message: {
                                        Text("This will permanently remove this history entry. This cannot be undone.")
                                    }
                                }

                                if recentResetLogs.count > visibleHistoryCount {
                                    LoadMoreButton {
                                        visibleHistoryCount += 4
                                    }
                                    .padding(.top, 4)
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
                                    visibleHistoryCount = 4
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

            historyDetailPopup

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
                    divider
                    earnRow(icon: "book.pages.fill", title: "Reading Session", amount: SelfCarePointsManager.readingSessionPoints)
                    divider
                    earnRow(icon: "timer", title: "Reading Timer Session", amount: SelfCarePointsManager.readingTimerSessionPoints)
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

    private var manualLogHistoryButtonSection: some View {
        GlassCard {
            Button {
                showManualHistoryConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LColors.glassSurface2)
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log History")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)

                        Text("Save a manual snapshot of your current points and level.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Save Manual History Snapshot?",
                isPresented: $showManualHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Save Snapshot") {
                    _ = try? SelfCarePointsManager.createManualHistorySnapshot(in: modelContext)
                    activeUserId = try? SelfCarePointsManager.resolveActiveUserId(in: modelContext)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will save your current points and level into history without resetting anything.")
            }
        }
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
                        Text("History")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)

                        Text("View automatic reset history and manual saved snapshots.")
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
        case .readingSession:
            return "book.pages.fill"
        case .readingTimerSession:
            return "timer"
        }
    }

    @ViewBuilder
    private var historyDetailPopup: some View {
        if let log = selectedHistoryLog {
            LystariaOverlayPopup(
                onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedHistoryLog = nil
                    }
                },
                width: 560,
                heightRatio: 0.52,
                header: {
                    HStack {
                        GradientTitle(text: historyTitle(for: log), size: 24)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedHistoryLog = nil
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LColors.glassSurface2)
                                    .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
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
                    VStack(spacing: 12) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: log.weekStartDayKey.hasPrefix("manual-") ? "square.and.pencil" : "arrow.clockwise.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.accent)
                                    Text(historySubtitle(for: log))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(height: 1)

                                HStack {
                                    Text("Saved")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                    Text(log.resetAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                }

                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(height: 1)

                                HStack {
                                    Text("Points at save")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                    Text("\(log.pointsBeforeReset)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                }

                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(height: 1)

                                HStack {
                                    Text("Level at save")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                    Text("\(log.levelBeforeReset)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                            }
                        }
                    }
                },
                footer: {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedHistoryLog = nil
                            }
                        } label: {
                            Text("Close")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            )
            .zIndex(15)
        }
    }

    private func historyTitle(for log: SelfCarePointsResetLog) -> String {
        if log.weekStartDayKey.hasPrefix("manual-") {
            return "Manual History Snapshot"
        }

        if log.weekStartDayKey == "legacy-pre-weekly-reset" {
            return "Legacy Weekly Reset"
        }

        return "Automatic Weekly Reset"
    }

    private func historySubtitle(for log: SelfCarePointsResetLog) -> String {
        if log.weekStartDayKey.hasPrefix("manual-") {
            return "Saved manually"
        }

        if log.weekStartDayKey == "legacy-pre-weekly-reset" {
            return "Imported from pre-weekly-reset history"
        }

        return "Saved automatically during weekly reset"
    }
}
