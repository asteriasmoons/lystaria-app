// ReadingTabView.swift
// Lystaria

import SwiftUI
import SwiftData
import PhotosUI
import Combine
import UIKit
import ActivityKit

// Cross-platform: numeric keyboard only exists on iOS/visionOS
extension View {
    @ViewBuilder
    func numericKeyboardIfAvailable() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

struct ReadingTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingStats.updatedAt, order: .reverse) private var readingStats: [ReadingStats]
    @Query(sort: \ReadingGoal.updatedAt, order: .reverse) private var readingGoals: [ReadingGoal]
    @Query(sort: \ReadingSession.sessionDate, order: .reverse) private var readingSessions: [ReadingSession]
    @Query(sort: \WeeklyReadingSnapshot.startDate, order: .reverse) private var weeklyReadingSnapshots: [WeeklyReadingSnapshot]
    @Query(sort: \ReadingPointsEntry.date, order: .reverse) private var readingPointsEntries: [ReadingPointsEntry]
    @EnvironmentObject private var appState: AppState
    
    @State private var showAddBook = false
    @State private var editingBook: Book? = nil
    @State private var visibleBookCount: Int = 4
    @State private var showBookmarksView = false
    @State private var showNotesView = false
    @State private var showingReadingGoalSheet = false
    @State private var editingReadingGoal: ReadingGoal? = nil
    @State private var showingReadingGoalProgressPopup = false
    @State private var showingReadingGoalHistoryPopup = false
    
    @State private var showingBookNotesPopup = false
    @State private var notesBook: Book? = nil
    @State private var selectedBookNote: BookNote? = nil
    @State private var showingAddBookNotePopup = false
    
    @State private var showingSeriesPopup: Bool = false
    @State private var selectedSeriesForPopup: BookSeries? = nil
    
    @State private var showDeleteConfirm = false
    @State private var bookPendingDeletion: Book? = nil
    @State private var showSummary = true
    @State private var showBookSummaryPopup = false
    @State private var showBookRecommendationsPopup = false
    @State private var showReadingTimerSheet = false
    @State private var tagFilter: String? = nil
    @State private var selectedStatus: BookStatus? = nil
    
    @State private var loggingSessionForBook: Book? = nil
    @State private var selectedBookForDetails: Book? = nil
    @State private var showingSessionHistoryForBook: Book? = nil
    
    @State private var showingBookPointsPopup: Bool = false
    @State private var selectedBookForPointsPopup: Book? = nil
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()
    
    private var currentUserId: String? {
        appState.currentAppleUserId
    }
    
    private var currentStats: ReadingStats? {
        if let currentUserId, !currentUserId.isEmpty {
            let matches = readingStats.filter { $0.userId == currentUserId }
            if let bestMatch = matches.max(by: { $0.updatedAt < $1.updatedAt }) {
                return bestMatch
            }
        }
        
        return readingStats.max(by: { $0.updatedAt < $1.updatedAt })
    }
    
    private var streakDays: Int {
        currentStats?.streakDays ?? 0
    }
    
    private var bestStreakDays: Int {
        currentStats?.bestStreakDays ?? 0
    }
    
    private var lastCheckInDate: Date? {
        currentStats?.lastCheckInDate
    }
    
    private var alreadyCheckedInToday: Bool {
        guard let lastCheckInDate else { return false }
        return Calendar.current.isDateInToday(lastCheckInDate)
    }
    
    private var readingStreakStatusText: String {
        alreadyCheckedInToday ? "Checked in today" : "Not checked in today"
    }
    
    private var readingStreakSupportText: String {
        alreadyCheckedInToday
        ? "You already protected your streak today."
        : "Check in today to keep your streak going."
    }

    private var currentUserPointsEntries: [ReadingPointsEntry] {
        guard let currentUserId else { return [] }
        return readingPointsEntries.filter { $0.userId == currentUserId }
    }

    private var totalReadingPoints: Int {
        currentUserPointsEntries.reduce(0) { $0 + max($1.pointsEarned, 0) }
    }

    private var totalReadingPointsMinutes: Int {
        currentUserPointsEntries.reduce(0) { $0 + max($1.minutesRead, 0) }
    }

    private var totalReadingPointsSessions: Int {
        currentUserPointsEntries.count
    }
    
    private var currentGoal: ReadingGoal? {
        guard let currentUserId else { return nil }
        let matches = readingGoals.filter { $0.userId == currentUserId && $0.isActive }
        return matches.max(by: { $0.updatedAt < $1.updatedAt })
    }
    
    private var currentGoalTargetDisplay: String {
        guard let currentGoal else { return "" }
        
        switch currentGoal.metric {
        case .minutes:
            return "\(currentGoal.targetValue) min"
        case .hours:
            return "\(currentGoal.targetValue) hr"
        case .pages:
            return "\(currentGoal.targetValue) pages"
        case .books:
            return "\(currentGoal.targetValue) books"
        }
    }
    
    private var currentGoalProgressValue: Int {
        guard let goal = currentGoal else { return 0 }
        
        let range = goalDateRange(for: goal.period)
        
        switch goal.metric {
        case .minutes:
            return readingSessions
                .filter { session in
                    session.sessionDate >= range.start &&
                    session.sessionDate < range.end
                }
                .reduce(0) { $0 + $1.minutesRead }
            
        case .hours:
            return readingSessions
                .filter { session in
                    session.sessionDate >= range.start &&
                    session.sessionDate < range.end
                }
                .reduce(0) { $0 + $1.minutesRead }
            
        case .pages:
            return readingSessions
                .filter { session in
                    session.sessionDate >= range.start &&
                    session.sessionDate < range.end
                }
                .reduce(0) { $0 + $1.pagesRead }
            
        case .books:
            return books.filter { book in
                guard book.deletedAt == nil else { return false }
                guard book.status == .finished else { return false }
                guard let finishedAt = book.finishedAt else { return false }
                return finishedAt >= range.start && finishedAt < range.end
            }.count
        }
    }
    
    private var currentGoalProgressDisplay: String {
        guard let goal = currentGoal else { return "" }
        
        switch goal.metric {
        case .minutes:
            return "\(currentGoalProgressValue) / \(goal.targetValue) min"
        case .hours:
            let targetMinutes = goal.targetValue * 60
            return "\(currentGoalProgressValue) / \(targetMinutes) min"
        case .pages:
            return "\(currentGoalProgressValue) / \(goal.targetValue) pages"
        case .books:
            return "\(currentGoalProgressValue) / \(goal.targetValue) books"
        }
    }
    
    private var currentGoalProgressFraction: Double {
        guard let goal = currentGoal else { return 0 }
        
        let target: Double
        switch goal.metric {
        case .minutes:
            target = Double(goal.targetValue)
        case .hours:
            target = Double(goal.targetValue * 60)
        case .pages:
            target = Double(goal.targetValue)
        case .books:
            target = Double(goal.targetValue)
        }
        
        guard target > 0 else { return 0 }
        return min(max(Double(currentGoalProgressValue) / target, 0), 1)
    }
    
    private var currentGoalSegmentCount: Int {
        10
    }
    
    private var currentGoalFilledSegments: Int {
        guard let goal = currentGoal else { return 0 }
        guard goal.targetValue > 0 else { return 0 }
        guard currentWeekPagesRead > 0 else { return 0 }
        
        let ratio = min(Double(currentWeekPagesRead) / Double(goal.targetValue), 1.0)
        return min(max(Int(ceil(ratio * Double(currentGoalSegmentCount))), 0), currentGoalSegmentCount)
    }
    
    private func goalDateRange(for period: ReadingGoalPeriod) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .daily:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
        case .weekly:
            let interval = calendar.dateInterval(of: .weekOfYear, for: now)
            return (interval?.start ?? now, interval?.end ?? now)
        case .monthly:
            let interval = calendar.dateInterval(of: .month, for: now)
            return (interval?.start ?? now, interval?.end ?? now)
        case .yearly:
            let interval = calendar.dateInterval(of: .year, for: now)
            return (interval?.start ?? now, interval?.end ?? now)
        }
    }

    
    @ViewBuilder
    private var readingPopupsOverlay: some View {
        if showBookSummaryPopup {
            BookSummarySheet(isPresented: $showBookSummaryPopup)
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(50)
        }
        
        if showBookRecommendationsPopup {
            BookRecommendationsSheet(isPresented: $showBookRecommendationsPopup)
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(51)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Reading", font: .largeTitle.bold())
                Spacer()
                
                Button {
                    showBookmarksView = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)
                        
                        Image("markfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .onboardingTarget("bookmarkIcon")
                
                Button {
                    showNotesView = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)
                        Image("notepad")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .onboardingTarget("notesIcon")
            }
            .padding(.top, 24)
            
            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 12)
        }
    }
    
    private var topToggleSection: some View {
        HStack(spacing: 10) {
            Button {
                showSummary = true
                showBookSummaryPopup = true
                showBookRecommendationsPopup = false
            } label: {
                Text("Summary")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(showSummary ? .white : LColors.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(showSummary ? LColors.accent : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(showSummary ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                showSummary = false
                showBookRecommendationsPopup = true
                showBookSummaryPopup = false
            } label: {
                Text("Recs")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(!showSummary ? .white : LColors.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(!showSummary ? LColors.accent : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(!showSummary ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                showReadingTimerSheet = true
                showBookSummaryPopup = false
                showBookRecommendationsPopup = false
            } label: {
                Text("Timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    private func handleAddBookTap() {
        let decision = limits.canCreate(.bookCardsTotal, currentCount: books.count)
        guard decision.allowed else { return }
        showAddBook = true
    }
    
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationDestination(isPresented: $showBookmarksView) {
                    BookmarksView()
                }
                .navigationDestination(isPresented: $showNotesView) {
                    NotesView()
                }
        }
        .sheet(isPresented: $showReadingTimerSheet) {
            ReadingTimerSheet(isPresented: $showReadingTimerSheet)
                .preferredColorScheme(.dark)
        }
        .onOpenURL { url in
            handleReadingDeepLink(url)
        }
    }

    // Extracted to break the modifier chain that was causing the type-checker timeout.
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            LystariaBackground()
            mainScrollContent
            readingPopupsOverlay
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookSummaryPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookRecommendationsPopup)
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton {
                handleAddBookTap()
            }
            .padding(.trailing, 26)
            .padding(.bottom, 100)
            .zIndex(10000)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay { sheetOverlaysA }
        .overlay { sheetOverlaysB }
        .onChange(of: selectedStatus) { _, _ in visibleBookCount = 4 }
        .onChange(of: tagFilter) { _, _ in visibleBookCount = 4 }
        .lystariaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete book?",
            message: "This will permanently remove this book.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let b = bookPendingDeletion {
                b.deletedAt = Date()
                b.updatedAt = Date()
                try? modelContext.save()
            }
            bookPendingDeletion = nil
        }
        .onAppear {
            ensureReadingStatsRecordExists()
            syncBestReadingStreakIfNeeded()
            savePreviousWeekSnapshotIfNeeded()
            visibleBookCount = 4
        }
        .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
            ZStack {
                OnboardingOverlay(anchors: anchors)
                    .environmentObject(onboarding)
            }
            .task(id: anchors.count) {
                if anchors.count > 0 {
                    onboarding.start(page: OnboardingPages.reading)
                }
            }
        }
    }

    // First batch of sheet overlays — split to keep each expression small.
    @ViewBuilder
    private var sheetOverlaysA: some View {
        ZStack {
            if showAddBook {
                AddBookSheet(onClose: { showAddBook = false })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(70)
            }
            if let book = editingBook {
                EditBookSheet(book: book, onClose: { editingBook = nil })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(70)
            }
            if let book = loggingSessionForBook {
                LogReadingSessionSheet(book: book, onClose: { loggingSessionForBook = nil })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(71)
            }
            if let book = selectedBookForDetails {
                BookDetailSheet(
                    book: book,
                    onClose: { selectedBookForDetails = nil },
                    onLogSession: { loggingSessionForBook = book },
                    onShowSessionHistory: { showingSessionHistoryForBook = book },
                    onShowNotes: {
                        notesBook = book
                        showingBookNotesPopup = true
                    },
                    onShowSeries: {
                        selectedSeriesForPopup = book.series
                        showingSeriesPopup = true
                    },
                    onShowPoints: {
                        selectedBookForPointsPopup = book
                        showingBookPointsPopup = true
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(72)
            }
            if let book = showingSessionHistoryForBook {
                BookSessionHistorySheet(book: book, onClose: { showingSessionHistoryForBook = nil })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(73)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showAddBook)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: editingBook != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: loggingSessionForBook != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedBookForDetails != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingSessionHistoryForBook != nil)
    }

    // Second batch of sheet overlays.
    @ViewBuilder
    private var sheetOverlaysB: some View {
        ZStack {
            if showingBookNotesPopup, let book = notesBook {
                BookNotesPopup(
                    book: book,
                    onClose: {
                        showingBookNotesPopup = false
                        if !showingAddBookNotePopup && selectedBookNote == nil { notesBook = nil }
                    },
                    onAddNote: { showingAddBookNotePopup = true },
                    onSelectNote: { note in selectedBookNote = note }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(73)
            }
            if showingAddBookNotePopup, let book = notesBook {
                AddBookNotePopup(book: book, onClose: { showingAddBookNotePopup = false })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(74)
            }
            if let note = selectedBookNote {
                BookNoteDetailPopup(note: note, onClose: { selectedBookNote = nil })
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(75)
            }
            if showingReadingGoalSheet {
                ReadingGoalSheet(
                    existingGoal: editingReadingGoal,
                    currentUserId: currentUserId,
                    onClose: {
                        showingReadingGoalSheet = false
                        editingReadingGoal = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(74)
            }
            if showingReadingGoalProgressPopup {
                ReadingGoalProgressPopup(
                    currentGoal: currentGoal,
                    currentUserId: currentUserId,
                    onClose: { showingReadingGoalProgressPopup = false },
                    onShowHistory: { showingReadingGoalHistoryPopup = true }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(76)
            }
            if showingReadingGoalHistoryPopup {
                ReadingGoalHistoryPopup(
                    currentUserId: currentUserId,
                    onClose: { showingReadingGoalHistoryPopup = false }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(77)
            }
            if showingSeriesPopup, let series = selectedSeriesForPopup {
                BookSeriesDetailPopup(
                    series: series,
                    onClose: {
                        showingSeriesPopup = false
                        selectedSeriesForPopup = nil
                    }
                )
                .environment(\.colorScheme, .dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(120)
            }

            if showingBookPointsPopup, let book = selectedBookForPointsPopup {
                BookPointsPopup(
                    book: book,
                    onClose: {
                        showingBookPointsPopup = false
                        selectedBookForPointsPopup = nil
                    }
                )
                .environment(\.colorScheme, .dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(121)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingBookPointsPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingBookNotesPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingAddBookNotePopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedBookNote != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingReadingGoalSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingReadingGoalProgressPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingReadingGoalHistoryPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingSeriesPopup)
    }
    
    private var mainScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                topToggleSection
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image("booksfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.white)
                                    .padding(.top, 1)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    GradientTitle(text: "Reading Streak", font: .system(size: 14, weight: .bold))
                                }
                            }
                            
                            Spacer()
                            
                            Text(readingStreakStatusText)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT STREAK")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.8)

                                Text("\(streakDays)")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(LColors.glassSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BEST DAYS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.8)

                                Text("\(bestStreakDays)")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(LColors.glassSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                        
                        Text(readingStreakSupportText)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 10) {
                            Button {
                                do {
                                    guard let currentUserId else {
                                        print("[ReadingTabView] No signed-in Apple user ID available")
                                        return
                                    }
                                    let didCheckIn = try ReadingCheckInWriter.checkInToday(
                                        modelContext: modelContext,
                                        userId: currentUserId
                                    )
                                    if didCheckIn {
                                        syncBestReadingStreakIfNeeded()
                                        print("[ReadingTabView] Reading check-in complete")
                                    } else {
                                        print("[ReadingTabView] Check-in ignored (already checked in today)")
                                    }
                                } catch {
                                    print("[ReadingTabView] Failed to check in: \(error)")
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: alreadyCheckedInToday ? "checkmark.circle" : "checkmark.circle.fill")
                                    Text(alreadyCheckedInToday ? "Checked In" : "Check In")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(alreadyCheckedInToday ? Color.gray.opacity(0.35) : LColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyCheckedInToday)
                            
                            Button {
                                if let record = currentStats {
                                    record.streakDays = 0
                                    record.lastCheckInDate = nil
                                    record.updatedAt = Date()
                                    try? modelContext.save()
                                    print("[ReadingTabView] Reset: streak is now 0")
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
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
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .center, spacing: 10) {
                                Image("trophyfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)

                                GradientTitle(text: "Reading Points", font: .system(size: 14, weight: .bold))
                            }

                            Spacer()
                        }

                        Text("Earned through reading timer sessions")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TOTAL POINTS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.8)

                                Text("\(totalReadingPoints)")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(LColors.glassSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("MINUTES READ")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.8)

                                Text("\(totalReadingPointsMinutes)")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(LColors.glassSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }

                        HStack(spacing: 10) {
                            Text("Sessions logged: \(totalReadingPointsSessions)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            Spacer()
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "target")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.top, 1)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    GradientTitle(text: "Reading Goal", font: .system(size: 14, weight: .bold))
                                    
                                    if let goal = currentGoal {
                                        Text("\(goal.period.label) • \(goal.metric.label)")
                                            .font(.subheadline)
                                            .foregroundStyle(LColors.textSecondary)
                                    } else {
                                        Text("No active goal yet")
                                            .font(.subheadline)
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        if let goal = currentGoal {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 18) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Your progress is wrapped into a half-circle view so you can see how close you are at a glance.")
                                            .font(.subheadline)
                                            .foregroundStyle(LColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HalfCircleDashedGoalProgressView(
                                        segmentCount: currentGoalSegmentCount,
                                        filledSegments: currentGoalFilledSegments,
                                        centerText: "\(currentWeekPagesRead) / \(goal.targetValue)",
                                        bottomText: goal.metric.label.lowercased()
                                    )
                                    .padding(.top, -45)
                                }
                                
                                HStack(spacing: 10) {
                                    Button {
                                        editingReadingGoal = goal
                                        showingReadingGoalSheet = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "pencil")
                                            Text("Edit")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .fixedSize(horizontal: true, vertical: false)
                                    
                                    Button {
                                        goal.progressValue = 0
                                        goal.updatedAt = Date()
                                        try? modelContext.save()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("Reset")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(AnyShapeStyle(LGradients.blue))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                        .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .fixedSize(horizontal: true, vertical: false)
                                    
                                    Spacer(minLength: 0)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingReadingGoalProgressPopup = true
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Set a goal for pages, minutes, hours, or books across a daily, weekly, monthly, or yearly period.")
                                    .font(.subheadline)
                                    .foregroundStyle(LColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack(spacing: 10) {
                                    GradientCapsuleButton(title: "+ Goal", icon: "target") {
                                        editingReadingGoal = nil
                                        showingReadingGoalSheet = true
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Pill(title: "All", on: selectedStatus == nil) {
                            withAnimation { selectedStatus = nil }
                        }
                        
                        ForEach(BookStatus.allCases, id: \.self) { status in
                            Pill(title: status.label, on: selectedStatus == status) {
                                withAnimation { selectedStatus = status }
                            }
                        }
                    }
                }
                
                if let currentTag = tagFilter {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(LColors.textSecondary)
                            
                            Text("Filtered by #\(currentTag)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                tagFilter = nil
                            }
                        } label: {
                            Text("Clear")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(LColors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
                
                booksSection
                
                Spacer(minLength: 96)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }
    
    private func seriesChipText(for book: Book, series: BookSeries) -> String {
        let cleanLabel = book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanLabel.isEmpty {
            return "\(series.title) • \(cleanLabel)"
        }

        if let index = book.seriesIndex {
            return "\(series.title) • Book \(index)"
        }

        return series.title
    }
    
    private var booksSection: some View {
        VStack(spacing: 14) {
            let filteredBooks = books.filter { book in
                guard book.deletedAt == nil else { return false }
                let statusMatches = selectedStatus.map { book.status == $0 } ?? true
                let tagMatches: Bool
                if let currentTag = tagFilter, !currentTag.isEmpty {
                    tagMatches = book.tags.contains(where: { $0.caseInsensitiveCompare(currentTag) == .orderedSame })
                } else {
                    tagMatches = true
                }
                return statusMatches && tagMatches
            }
                .sorted { a, b in
                    if a.status == .reading && b.status != .reading { return true }
                    if a.status != .reading && b.status == .reading { return false }
                    return a.createdAt > b.createdAt
                }
            
            let visibleBooks = Array(filteredBooks.prefix(visibleBookCount))
            let allowedBookIds = Set(
                books
                    .filter { $0.deletedAt == nil }
                    .sorted { $0.createdAt < $1.createdAt }
                    .prefix(4)
                    .map { $0.persistentModelID }
            )
            
            if filteredBooks.isEmpty {
                GlassCard {
                    Text("No books yet.")
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            } else {
                ForEach(visibleBooks) { book in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 10) {
                                Text(book.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                Spacer(minLength: 8)

                                StatusBadge(status: book.status)
                            }

                            if let series = book.series {
                                let cleanLabel = book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                let text: String = {
                                    if !cleanLabel.isEmpty {
                                        return "\(series.title) • \(cleanLabel)"
                                    }
                                    if let index = book.seriesIndex {
                                        return "\(series.title) • Book \(index)"
                                    }
                                    return series.title
                                }()

                                Text(text)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            
                            if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { i in
                                    Button {
                                        let newValue = (book.rating == i) ? 0 : i
                                        book.rating = newValue
                                        book.updatedAt = Date()
                                        try? modelContext.save()
                                    } label: {
                                        Image("starfill")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(i <= book.rating ? Color.white : LColors.textSecondary.opacity(0.35))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Rate \(i) star\(i == 1 ? "" : "s")")
                                }
                            }
                            .padding(.top, 2)
                            
                            if !book.shortSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(book.shortSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(LColors.textSecondary)
                                    .lineLimit(8)
                            }
                            
                            if book.status == .reading,
                               let total = book.totalPages, total > 0,
                               let current = book.currentPage, current >= 0 {
                                let clampedCurrent = min(max(current, 0), total)
                                let progress = CGFloat(book.progressPercent)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.10))
                                            .frame(height: 10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(LColors.glassBorder, lineWidth: 1)
                                            )
                                        
                                        GeometryReader { geo in
                                            let width = max(0, min(geo.size.width * progress, geo.size.width))
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(AnyShapeStyle(LGradients.blue))
                                                .frame(width: width, height: 10)
                                        }
                                        .frame(height: 10)
                                    }
                                    
                                    HStack {
                                        Text("\(clampedCurrent) / \(total) pages")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                        
                                        Spacer()
                                        
                                        Text("\(Int((progress * 100).rounded()))%")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                                .padding(.top, 6)
                            }
                            
                            if !book.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(book.tags, id: \.self) { tag in
                                            Button {
                                                withAnimation {
                                                    tagFilter = tag
                                                    visibleBookCount = 4
                                                }
                                            } label: {
                                                Text("#\(tag)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .lineLimit(1)
                                                    .foregroundStyle(LGradients.tag)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.white.opacity(0.06))
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule().stroke(LGradients.tag, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 6)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Button {
                                        editingBook = book
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "pencil")
                                            Text("Edit")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        selectedBookForDetails = book
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "ellipsis.circle")
                                            Text("Details")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    GradientCapsuleButton(title: "Log Session", icon: "booksfill") {
                                        loggingSessionForBook = book
                                    }
                                }
                                
                                HStack(spacing: 10) {
                                    if book.status == .reading,
                                       let total = book.totalPages, total > 0,
                                       let current = book.currentPage {
                                        
                                        Button {
                                            let newValue = max(current - 1, 0)
                                            if newValue != current {
                                                book.currentPage = newValue
                                                book.updatedAt = Date()
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Image("chevrondownfill")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                                .foregroundStyle(.white)
                                                .frame(width: 38, height: 38)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            let newValue = min(current + 1, total)
                                            if newValue != current {
                                                book.currentPage = newValue
                                                book.updatedAt = Date()
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Image("chevronupfill")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                                .foregroundStyle(.white)
                                                .frame(width: 38, height: 38)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            if let total = book.totalPages, total > 0 {
                                                book.currentPage = total
                                            }
                                            
                                            book.status = .finished
                                            book.finishedAt = Date() // ← THIS is what you’re adding
                                            book.updatedAt = Date()
                                            
                                            try? modelContext.save()
                                        } label: {
                                            Image("checkfill")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                                .foregroundStyle(.white)
                                                .frame(width: 38, height: 38)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    GradientCapsuleButton(title: "Delete", icon: "trashfill") {
                                        bookPendingDeletion = book
                                        showDeleteConfirm = true
                                    }
                                }
                            }
                            .padding(.top, 10)
                            
                        }
                        // Removed whole-card tap behavior
                    }
                    .premiumLocked(!limits.hasPremiumAccess && !allowedBookIds.contains(book.persistentModelID))
                }
            }
            
            if filteredBooks.count > visibleBooks.count {
                HStack {
                    Spacer()
                    LoadMoreButton {
                        visibleBookCount += 4
                    }
                    Spacer()
                }
                .padding(.top, 6)
            }
        }
        .lystariaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete book?",
            message: "This will remove this book from your library.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let book = bookPendingDeletion {
                modelContext.delete(book)
                try? modelContext.save()
            }
            bookPendingDeletion = nil
        }
    }
    
    private func handleReadingDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "lystaria" else { return }
        guard url.host?.lowercased() == "reading-timer" else { return }

        DispatchQueue.main.async {
            showReadingTimerSheet = true
        }
    }
    
    private func syncBestReadingStreakIfNeeded() {
        guard let record = currentStats else { return }
        let correctedBest = max(record.bestStreakDays, record.streakDays)
        guard correctedBest != record.bestStreakDays else { return }
        record.bestStreakDays = correctedBest
        record.updatedAt = Date()
        try? modelContext.save()
    }
    
    private var currentWeekDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }
    
    private var previousWeekDateRange: (start: Date, end: Date) {
        weekDateRange(weeksAgo: 1)
    }
    
    private func weekDateRange(weeksAgo: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let referenceDate = calendar.date(byAdding: .day, value: -(weeksAgo * 7), to: Date()) ?? Date()
        let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let start = interval?.start ?? calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }
    
    private func weekRange(startingAt start: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: start)
        let end = calendar.date(byAdding: .day, value: 6, to: normalizedStart) ?? normalizedStart
        return (start: normalizedStart, end: end)
    }
    
    private var mostRecentSnapshotStartDate: Date? {
        guard let currentUserId else { return nil }
        return weeklyReadingSnapshots
            .filter { $0.userId == currentUserId }
            .map { $0.startDate }
            .max()
    }
    
    private func snapshotExists(for range: (start: Date, end: Date)) -> Bool {
        guard let currentUserId else { return false }
        let calendar = Calendar.current
        
        return weeklyReadingSnapshots.contains { snapshot in
            snapshot.userId == currentUserId &&
            calendar.isDate(snapshot.startDate, inSameDayAs: range.start) &&
            calendar.isDate(snapshot.endDate, inSameDayAs: range.end)
        }
    }
    
    private func totalProgress(for range: (start: Date, end: Date), metric: ReadingGoalMetric) -> Int {
        (books.flatMap { $0.sessions ?? [] })
            .filter { session in
                range.start <= session.sessionDate && session.sessionDate <= range.end
            }
            .reduce(0) { partial, session in
                partial + progressContribution(for: metric, session: session)
            }
    }
    
    private var activeGoalForSnapshots: ReadingGoal? {
        guard let currentUserId else { return nil }
        return readingGoals.first(where: { $0.userId == currentUserId && $0.isActive })
    }
    
    private func savePreviousWeekSnapshotIfNeeded() {
        guard let currentUserId else { return }
        guard let goal = activeGoalForSnapshots else { return }
        
        let calendar = Calendar.current
        let previousRange = previousWeekDateRange
        let currentWeekStart = currentWeekDateRange.start
        
        let firstUnsavedStart: Date = {
            if let mostRecent = mostRecentSnapshotStartDate {
                return calendar.date(byAdding: .day, value: 7, to: mostRecent) ?? previousRange.start
            } else {
                return previousRange.start
            }
        }()
        
        var nextStart = calendar.startOfDay(for: firstUnsavedStart)
        
        while nextStart < currentWeekStart {
            let range = weekRange(startingAt: nextStart)
            
            if !snapshotExists(for: range) {
                let goalTarget = max(goal.targetValue, 0)
                let goalMetric = goal.metric
                let totalProgress = totalProgress(for: range, metric: goalMetric)
                let metGoal = goalTarget > 0 ? totalProgress >= goalTarget : false
                
                let snapshot = WeeklyReadingSnapshot(
                    userId: currentUserId,
                    startDate: range.start,
                    endDate: range.end,
                    totalProgress: totalProgress,
                    goalTarget: goalTarget,
                    metGoal: metGoal,
                    goalMetric: goalMetric,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                modelContext.insert(snapshot)
            }
            
            nextStart = calendar.date(byAdding: .day, value: 7, to: nextStart) ?? currentWeekStart
        }
        
        try? modelContext.save()
    }
    
    private var currentWeekPagesRead: Int {
        guard let goal = currentGoal else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        
        return (books.flatMap { $0.sessions ?? [] })
            .filter { session in
                interval.contains(session.sessionDate)
            }
            .reduce(0) { partial, session in
                partial + progressContribution(for: goal.metric, session: session)
            }
    }
    
    private func progressContribution(for metric: ReadingGoalMetric, session: ReadingSession) -> Int {
        switch metric {
        case .pages:
            return max(session.pagesRead, 0)
        case .minutes:
            return max(session.minutesRead, 0)
        case .hours:
            guard session.minutesRead > 0 else { return 0 }
            return max(Int(ceil(Double(session.minutesRead) / 60.0)), 0)
        case .books:
            guard let book = session.book,
                  let total = book.totalPages,
                  total > 0,
                  let endPage = session.endPage,
                  endPage >= total else { return 0 }
            return 1
        }
    }
    
    /// Ensures there is exactly one ReadingStats record for the current user,
    /// and safely adopts/merges an existing record if Sign in with Apple testing changed IDs.
    private func ensureReadingStatsRecordExists() {
        guard let uid = currentUserId, !uid.isEmpty else {
            print("[ReadingTabView] No signed-in Apple user ID available")
            return
        }
        
        let allDescriptor = FetchDescriptor<ReadingStats>()
        
        do {
            let allRecords = try modelContext.fetch(allDescriptor)
            let uidMatches = allRecords.filter { $0.userId == uid }
            
            if uidMatches.isEmpty {
                if let adopted = allRecords.max(by: { $0.updatedAt < $1.updatedAt }) {
                    adopted.userId = uid
                    adopted.bestStreakDays = max(adopted.bestStreakDays, adopted.streakDays)
                    adopted.updatedAt = Date()
                    try? modelContext.save()
                    print("[ReadingTabView] Adopted existing ReadingStats record for new userId=\(uid)")
                    return
                }
                
                let new = ReadingStats(userId: uid, streakDays: 0, bestStreakDays: 0)
                modelContext.insert(new)
                try? modelContext.save()
                print("[ReadingTabView] Created ReadingStats record for userId=\(uid)")
                return
            }
            
            if uidMatches.count == 1 {
                let record = uidMatches[0]
                let globalBest = allRecords.map { $0.bestStreakDays }.max() ?? 0
                let globalCurrent = allRecords.map { $0.streakDays }.max() ?? 0
                let correctedBest = max(record.bestStreakDays, record.streakDays, globalBest, globalCurrent)
                if correctedBest != record.bestStreakDays {
                    record.bestStreakDays = correctedBest
                    record.updatedAt = Date()
                    try? modelContext.save()
                }
                return
            }
            
            let best = uidMatches.max(by: { $0.updatedAt < $1.updatedAt }) ?? uidMatches[0]
            let mergedBestStreak = uidMatches.map { $0.bestStreakDays }.max() ?? 0
            let mergedCurrentStreak = uidMatches.map { $0.streakDays }.max() ?? 0
            best.bestStreakDays = max(best.bestStreakDays, best.streakDays, mergedBestStreak, mergedCurrentStreak)
            best.streakDays = max(best.streakDays, mergedCurrentStreak)
            best.userId = uid
            
            for dupe in uidMatches where dupe.persistentModelID != best.persistentModelID {
                modelContext.delete(dupe)
            }
            
            best.updatedAt = Date()
            try? modelContext.save()
            print("[ReadingTabView] Cleaned up \(uidMatches.count - 1) duplicate ReadingStats record(s)")
        } catch {
            print("[ReadingTabView] Failed to ensure ReadingStats record: \(error)")
        }
    }
}

struct ReadingTimerSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    @State private var selectedPresetMinutes: Int = 20
    @State private var customMinutesText: String = ""
    @State private var useCustomTime: Bool = false
    @State private var totalSeconds: Int = 20 * 60
    @State private var remainingSeconds: Int = 20 * 60
    @State private var isRunning: Bool = false
    @State private var timerCancellable: AnyCancellable? = nil
    @FocusState private var isCustomMinutesFocused: Bool
    @State private var selectedBookPersistentIDString: String = ""
    @State private var liveActivity: Activity<ReadingTimerActivityAttributes>? = nil
    @State private var didFinalizeCurrentSession: Bool = false
    @State private var timerStartedAt: Date? = nil

    private let presetOptions: [Int] = [10, 15, 20, 30, 45, 60]
    
    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var readingBooks: [Book] {
        books
            .filter { $0.status == .reading }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var selectedBook: Book? {
        readingBooks.first {
            String(describing: $0.persistentModelID) == selectedBookPersistentIDString
        }
    }

    private var canStartTimer: Bool {
        selectedBook != nil && resolvedMinutes > 0
    }

    private var resolvedMinutes: Int {
        if useCustomTime {
            let value = Int(customMinutesText.filter { $0.isNumber }) ?? 0
            return max(value, 1)
        }
        return max(selectedPresetMinutes, 1)
    }

    private var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max(Double(remainingSeconds) / Double(totalSeconds), 0), 1)
    }

    private var timeDisplay: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var durationLabel: String {
        "\(resolvedMinutes) min"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCustomMinutesFocused = false
                    }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    GradientTitle(text: "Reading Timer", font: .title2.bold())
                                    Spacer()
                                    Button {
                                        finalizeCurrentSessionIfNeeded()
                                        stopTimer()
                                        Task {
                                            await endLiveActivity()
                                        }
                                        isPresented = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text("Set a timer for your reading session with a quick preset or your own custom time.")
                                    .font(.subheadline)
                                    .foregroundStyle(LColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BOOK")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                Menu {
                                    if readingBooks.isEmpty {
                                        Text("No books marked Reading")
                                    } else {
                                        ForEach(readingBooks) { book in
                                            Button(book.title) {
                                                selectedBookPersistentIDString = String(describing: book.persistentModelID)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image("booksfill")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)

                                        Text(selectedBook?.title ?? "Select a currently reading book")
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                }

                                if readingBooks.isEmpty {
                                    Text("Mark a book as Reading to earn timer points.")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("TIME")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(presetOptions, id: \.self) { minutes in
                                            Button {
                                                useCustomTime = false
                                                selectedPresetMinutes = minutes
                                                applySelectedDuration()
                                            } label: {
                                                Text("\(minutes) min")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(!useCustomTime && selectedPresetMinutes == minutes ? .white : LColors.textPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(!useCustomTime && selectedPresetMinutes == minutes ? LColors.accent : Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(!useCustomTime && selectedPresetMinutes == minutes ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Toggle(isOn: $useCustomTime) {
                                    Text("CUSTOM TIME")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.5)
                                }
                                .tint(LColors.accent)
                                .onChange(of: useCustomTime) { _, _ in
                                    applySelectedDuration()
                                }

                                if useCustomTime {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("MINUTES")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)

                                        TextField("25", text: $customMinutesText)
                                            .textFieldStyle(.plain)
                                            .padding(12)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(LColors.glassBorder, lineWidth: 1)
                                            )
                                            .foregroundStyle(LColors.textPrimary)
                                            .keyboardType(.numberPad)
                                            .focused($isCustomMinutesFocused)
                                            .onChange(of: customMinutesText) { _, newValue in
                                                let filtered = newValue.filter { $0.isNumber }
                                                if filtered != newValue {
                                                    customMinutesText = filtered
                                                }
                                                applySelectedDuration()
                                            }
                                    }
                                }
                            }
                        }

                        GlassCard {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 12)
                                        .frame(width: 190, height: 190)

                                    Circle()
                                        .trim(from: 0, to: progressFraction)
                                        .stroke(AnyShapeStyle(LGradients.blue), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                        .frame(width: 190, height: 190)
                                        .rotationEffect(.degrees(-90))

                                    VStack(spacing: 6) {
                                        Text(timeDisplay)
                                            .font(.system(size: 34, weight: .black, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(LColors.textPrimary)

                                        Text(durationLabel)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        if isRunning {
                                            pauseTimer()
                                        } else {
                                            startTimer()
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                            Text(isRunning ? "Pause" : "Start")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(AnyShapeStyle(LGradients.blue))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!isRunning && !canStartTimer)
                                    .opacity(!isRunning && !canStartTimer ? 0.55 : 1)

                                    Button {
                                        resetTimer()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("Reset")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(LColors.textPrimary)
                                        .padding(.horizontal, 14)
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
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCustomMinutesFocused = false
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isCustomMinutesFocused = false
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
        .onAppear {
            if selectedBookPersistentIDString.isEmpty,
               let firstReadingBook = readingBooks.first {
                selectedBookPersistentIDString = String(describing: firstReadingBook.persistentModelID)
            }
            applySelectedDuration()
        }
        .onChange(of: selectedBookPersistentIDString) { _, _ in
            Task {
                await updateLiveActivityIfNeeded()
            }
        }
        .onChange(of: selectedPresetMinutes) { _, _ in
            Task {
                await updateLiveActivityIfNeeded()
            }
        }
        .onChange(of: customMinutesText) { _, _ in
            Task {
                await updateLiveActivityIfNeeded()
            }
        }
        .onChange(of: useCustomTime) { _, _ in
            Task {
                await updateLiveActivityIfNeeded()
            }
        }
        .onChange(of: remainingSeconds) { _, _ in
            Task {
                await updateLiveActivityIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                syncRemainingSecondsFromWallClock()
            }
        }
        .onDisappear {
            stopTimer()
            Task {
                await endLiveActivity()
            }
        }
    }

    private func applySelectedDuration() {
        guard !isRunning else { return }
        totalSeconds = resolvedMinutes * 60
        remainingSeconds = totalSeconds
        didFinalizeCurrentSession = false
    }
    
    private func elapsedSeconds() -> Int {
        max(totalSeconds - remainingSeconds, 0)
    }

    private func elapsedMinutesRoundedUp() -> Int {
        let seconds = elapsedSeconds()
        guard seconds > 0 else { return 0 }
        return max(Int(ceil(Double(seconds) / 60.0)), 1)
    }

    private func finalizeCurrentSessionIfNeeded() {
        guard !didFinalizeCurrentSession else { return }
        guard let currentUserId,
              let selectedBook else { return }

        let minutesRead = elapsedMinutesRoundedUp()
        guard minutesRead > 0 else { return }

        didFinalizeCurrentSession = true

        let sessionDate = Date()

        let session = ReadingSession(
            book: selectedBook,
            startPage: nil,
            endPage: nil,
            minutesRead: minutesRead,
            pagesRead: 0,
            sessionDate: sessionDate
        )
        session.isTimerSession = true
        modelContext.insert(session)

        let entry = ReadingPointsEntry(
            userId: currentUserId,
            bookId: String(describing: selectedBook.persistentModelID),
            bookTitle: selectedBook.title,
            minutesRead: minutesRead,
            pointsEarned: minutesRead,
            date: sessionDate
        )
        modelContext.insert(entry)

        try? modelContext.save()
    }
    
    private func liveActivityEndDate() -> Date {
        Date().addingTimeInterval(TimeInterval(remainingSeconds))
    }

    private func makeLiveActivityState() -> ReadingTimerActivityAttributes.ContentState? {
        guard let selectedBook else { return nil }
        return ReadingTimerActivityAttributes.ContentState(
            endDate: liveActivityEndDate(),
            bookTitle: selectedBook.title,
            minutesTotal: resolvedMinutes
        )
    }

    private func startLiveActivityIfPossible() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let selectedBook, let state = makeLiveActivityState() else { return }

        if let existingActivity = liveActivity {
            await updateLiveActivity(existingActivity, with: state)
            return
        }

        let attributes = ReadingTimerActivityAttributes(bookTitle: selectedBook.title)

        do {
            let activity = try Activity<ReadingTimerActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: state.endDate),
                pushType: nil
            )
            await MainActor.run {
                liveActivity = activity
            }
        } catch {
            print("[ReadingTimerSheet] Failed to start live activity: \(error)")
        }
    }

    private func updateLiveActivity(_ activity: Activity<ReadingTimerActivityAttributes>, with state: ReadingTimerActivityAttributes.ContentState) async {
        await activity.update(.init(state: state, staleDate: state.endDate))
    }

    private func updateLiveActivityIfNeeded() async {
        guard isRunning, let activity = liveActivity, let state = makeLiveActivityState() else { return }
        await updateLiveActivity(activity, with: state)
    }

    private func endLiveActivity() async {
        guard let activity = liveActivity else { return }
        let finalState = makeLiveActivityState() ?? ReadingTimerActivityAttributes.ContentState(
            endDate: Date(),
            bookTitle: selectedBook?.title ?? "Reading Timer",
            minutesTotal: resolvedMinutes
        )
        await activity.end(.init(state: finalState, staleDate: Date()), dismissalPolicy: .immediate)
        await MainActor.run {
            liveActivity = nil
        }
    }

    private func startTimer() {
        if remainingSeconds <= 0 {
            applySelectedDuration()
        }

        guard !isRunning else { return }
        guard canStartTimer else { return }

        isRunning = true
        timerStartedAt = Date().addingTimeInterval(-TimeInterval(totalSeconds - remainingSeconds))

        Task {
            await startLiveActivityIfPossible()
        }

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    finalizeCurrentSessionIfNeeded()
                    stopTimer()
                    Task {
                        await endLiveActivity()
                    }
                }
            }
    }

    private func syncRemainingSecondsFromWallClock() {
        guard isRunning, let startedAt = timerStartedAt else { return }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let computed = totalSeconds - elapsed
        remainingSeconds = max(computed, 0)
    }
    
    private func pauseTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        timerStartedAt = nil
    }

    private func stopTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func resetTimer() {
        finalizeCurrentSessionIfNeeded()
        stopTimer()
        Task {
            await endLiveActivity()
        }
        applySelectedDuration()
    }
}

struct HalfCircleDashedGoalProgressView: View {
    let segmentCount: Int
    let filledSegments: Int
    let centerText: String
    let bottomText: String

    private var safeSegmentCount: Int {
        max(segmentCount, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let radius = min(width * 0.42, height * 0.78)
            let centerX = width / 2
            let centerY = height * 0.95

            ZStack {
                ForEach(0..<safeSegmentCount, id: \.self) { index in
                    let fraction = safeSegmentCount == 1
                        ? 0.5
                        : Double(index) / Double(safeSegmentCount - 1)
                    let angleDegrees = 180.0 - (180.0 * fraction)
                    let angleRadians = angleDegrees * .pi / 180.0
                    let x = centerX + CGFloat(cos(angleRadians)) * radius
                    let y = centerY - CGFloat(sin(angleRadians)) * radius
                    let isFilled = index < filledSegments
                    let rotation = Angle(degrees: -90 + (180 * fraction))

                    Capsule()
                        .fill(
                            isFilled
                            ? AnyShapeStyle(LGradients.blue)
                            : AnyShapeStyle(Color.white.opacity(0.08))
                        )
                        .frame(width: 26, height: 10)
                        .overlay(
                            Capsule()
                                .stroke(
                                    isFilled
                                    ? AnyShapeStyle(LGradients.blue)
                                    : AnyShapeStyle(LColors.glassBorder),
                                    lineWidth: 1
                                )
                        )
                        .rotationEffect(rotation)
                        .position(x: x, y: y)
                }
                Text(centerText)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(LColors.textSecondary)
                    .position(x: centerX, y: centerY - radius * 0.48)

                Text(bottomText)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(LColors.textSecondary)
                    .position(x: centerX, y: centerY - radius * 0.20)
            }
        }
        .frame(width: 170, height: 110)
        .accessibilityHidden(true)
    }
}

// MARK: - Book Series Detail Popup
struct BookSeriesDetailPopup: View {
    let series: BookSeries
    var onClose: (() -> Void)? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var booksSorted: [Book] {
        (series.books ?? []).sorted {
            let a = $0.seriesIndex ?? Int.max
            let b = $1.seriesIndex ?? Int.max

            if a != b { return a < b }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func labelText(for book: Book) -> String {
        let clean = book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        if let index = book.seriesIndex { return "Book \(index)" }
        return ""
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.75,
            header: {
                HStack {
                    GradientTitle(text: series.title, font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                if booksSorted.isEmpty {
                    GlassCard {
                        Text("No books in this series yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    ForEach(booksSorted) { book in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(book.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Spacer()

                                    StatusBadge(status: book.status)
                                }

                                if !labelText(for: book).isEmpty {
                                    Text(labelText(for: book))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
    }
}

// MARK: - Reading Goal Progress Popup & History
struct ReadingGoalProgressPopup: View {
    let currentGoal: ReadingGoal?
    let currentUserId: String?
    var onClose: (() -> Void)? = nil
    var onShowHistory: (() -> Void)? = nil

    @Query(sort: \DailyReadingProgress.date, order: .reverse) private var dailyReadingProgress: [DailyReadingProgress]
    @Query(sort: \ReadingSession.sessionDate, order: .reverse) private var readingSessions: [ReadingSession]

    private var closeAction: () -> Void { onClose ?? {} }

    private var currentWeekRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: currentWeekRange.start)
        }
    }
    
    private var currentWeekTotal: Int {
        guard let currentGoal else { return 0 }
        let calendar = Calendar.current

        return readingSessions
            .filter { session in
                guard let book = session.book else { return false }
                guard book.deletedAt == nil else { return false }
                return calendar.isDate(session.sessionDate, equalTo: currentWeekRange.start, toGranularity: .weekOfYear)
            }
            .reduce(0) { partial, session in
                partial + progressContribution(for: currentGoal.metric, session: session)
            }
    }

    private func pagesRead(for day: Date) -> Int {
        guard let currentGoal else { return 0 }
        let calendar = Calendar.current

        return readingSessions
            .filter { session in
                guard let book = session.book else { return false }
                guard book.deletedAt == nil else { return false }
                return calendar.isDate(session.sessionDate, inSameDayAs: day)
            }
            .reduce(0) { partial, session in
                partial + progressContribution(for: currentGoal.metric, session: session)
            }
    }

    private func progressContribution(for metric: ReadingGoalMetric, session: ReadingSession) -> Int {
        switch metric {
        case .pages:
            return max(session.pagesRead, 0)
        case .minutes:
            return max(session.minutesRead, 0)
        case .hours:
            guard session.minutesRead > 0 else { return 0 }
            return max(Int(ceil(Double(session.minutesRead) / 60.0)), 0)
        case .books:
            guard let book = session.book,
                  let total = book.totalPages,
                  total > 0,
                  let endPage = session.endPage,
                  endPage >= total else { return 0 }
            return 1
        }
    }

    private func shortWeekday(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: day)
    }

    private var weekRangeDisplay: String {
        let start = currentWeekRange.start.formatted(date: .abbreviated, time: .omitted)
        let end = currentWeekRange.end.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 700,
            heightRatio: 0.72,
            header: {
                HStack {
                    GradientTitle(text: "Goal Progress", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(weekRangeDisplay)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)

                    if let currentGoal {
                        Text("\(currentWeekTotal) / \(currentGoal.targetValue) \(currentGoal.metric.label.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)

                        ForEach(Array(weekDates.prefix(4)), id: \.self) { day in
                            let value = pagesRead(for: day)

                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(value > 0 ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .frame(width: 46, height: 46)
                                        .overlay(
                                            Circle()
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )

                                    Text("\(value)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }

                                Text(shortWeekday(for: day))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(width: 58)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        Spacer(minLength: 0)

                        ForEach(Array(weekDates.suffix(3)), id: \.self) { day in
                            let value = pagesRead(for: day)

                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(value > 0 ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .frame(width: 46, height: 46)
                                        .overlay(
                                            Circle()
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )

                                    Text("\(value)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }

                                Text(shortWeekday(for: day))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(width: 58)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            },
            footer: {
                HStack(spacing: 10) {
                    Button {
                        onShowHistory?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 14)
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
                }
            }
        )
    }
}

// MARK: - Reading Goal History Popup
struct ReadingGoalHistoryPopup: View {
    let currentUserId: String?
    var onClose: (() -> Void)? = nil

    @Query(sort: \WeeklyReadingSnapshot.startDate, order: .reverse) private var snapshots: [WeeklyReadingSnapshot]

    private var closeAction: () -> Void { onClose ?? {} }

    private var userSnapshots: [WeeklyReadingSnapshot] {
        guard let currentUserId else { return [] }
        return snapshots.filter { $0.userId == currentUserId }
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 700,
            heightRatio: 0.72,
            header: {
                HStack {
                    GradientTitle(text: "Goal History", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                if userSnapshots.isEmpty {
                    GlassCard {
                        Text("No weekly history yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    ForEach(userSnapshots) { snapshot in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(snapshot.startDate.formatted(date: .abbreviated, time: .omitted)) – \(snapshot.endDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                HStack(spacing: 10) {
                                    Text("\(snapshot.totalProgress) / \(snapshot.goalTarget) \(snapshot.goalMetric.label.lowercased())")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    Spacer()

                                    Text(snapshot.metGoal ? "Met Goal" : "Missed Goal")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(snapshot.metGoal ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
    }
}

// MARK: - Add Book Sheet
struct AddBookSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookSeries.title, order: .forward) private var bookSeries: [BookSeries]
    @StateObject private var limits = LimitManager.shared
    var onClose: (() -> Void)? = nil

    @State private var title = ""
    @State private var author = ""
    @State private var status: BookStatus = .tbr
    @State private var currentPageText = ""
    @State private var totalPagesText = ""
    @State private var shortSummary = ""
    @State private var tagsRaw = ""
    @State private var hasStartedDate = false
    @State private var startedDate = Date()
    @State private var hasFinishedDate = false
    @State private var finishedDate = Date()
    @State private var hasSeries = false
    @State private var selectedSeries: BookSeries? = nil
    @State private var selectedSeriesName = ""
    @State private var seriesPositionText = ""
    @State private var seriesLabelText = ""
    @State private var showSeriesPicker = false
    @State private var showNewSeriesPopup = false

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var closeAction: () -> Void {
        onClose ?? {}
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Add Book", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Book title", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AUTHOR")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Author name", text: $author)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUMMARY")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextArea(placeholder: "Short summary (optional)", text: $shortSummary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Fantasy, Romance, Fae", text: $tagsRaw)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(BookStatus.allCases, id: \.self) { s in
                                    let isSelected = status == s

                                    Button {
                                        status = s
                                    } label: {
                                        Text(s.label)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white : LColors.textPrimary)
                                            .lineLimit(1)
                                            .fixedSize()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                isSelected
                                                ? LColors.accent
                                                : Color.white.opacity(0.08)
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(
                                                        isSelected
                                                        ? LColors.accent
                                                        : LColors.glassBorder,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasSeries) {
                            Text("SERIES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasSeries {
                            HStack(spacing: 10) {
                                Button {
                                    showSeriesPicker = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "books.vertical")
                                        Text(selectedSeriesName.isEmpty ? "Select Series" : selectedSeriesName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showNewSeriesPopup = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                        Text("New Series")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
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

                            VStack(alignment: .leading, spacing: 8) {
                                Text("POSITION")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                LystariaNumberField(placeholder: "1", text: $seriesPositionText)
                                    .numericKeyboardIfAvailable()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("LABEL")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                LystariaTextField(placeholder: "Book 1, Novella 0.5, Companion", text: $seriesLabelText)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasStartedDate) {
                            Text("START DATE")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasStartedDate {
                            DatePicker(
                                "",
                                selection: $startedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasFinishedDate) {
                            Text("FINISH DATE")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasFinishedDate {
                            DatePicker(
                                "",
                                selection: $finishedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                    }

                    if status == .reading {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PAGES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("CURRENT")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    LystariaNumberField(placeholder: "0", text: $currentPageText)
                                        .numericKeyboardIfAvailable()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TOTAL")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    LystariaNumberField(placeholder: "0", text: $totalPagesText)
                                        .numericKeyboardIfAvailable()
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }
            },
            footer: {
                Button { save() } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(titleTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: titleTrimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(titleTrimmed.isEmpty)
            }
        )
        .onChange(of: status) { _, newStatus in
            if newStatus != .reading {
                currentPageText = ""
                totalPagesText = ""
            }

            if newStatus == .finished && !hasFinishedDate {
                finishedDate = Date()
                hasFinishedDate = true
            }
        }
        .overlay {
            if showSeriesPicker {
                BookSeriesPickerPopup(
                    seriesList: bookSeries,
                    onClose: {
                        showSeriesPicker = false
                    },
                    onSelect: { series in
                        selectedSeries = series
                        selectedSeriesName = series.title
                        showSeriesPicker = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(90)
            }
        }
        .overlay {
            if showNewSeriesPopup {
                CreateBookSeriesPopup(
                    onClose: {
                        showNewSeriesPopup = false
                    },
                    onCreate: { title in
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { return }

                        if let existing = bookSeries.first(where: { $0.title.caseInsensitiveCompare(cleanTitle) == .orderedSame }) {
                            selectedSeries = existing
                            selectedSeriesName = existing.title
                        } else {
                            let newSeries = BookSeries(title: cleanTitle)
                            modelContext.insert(newSeries)
                            try? modelContext.save()
                            selectedSeries = newSeries
                            selectedSeriesName = newSeries.title
                        }

                        showNewSeriesPopup = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(91)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSeriesPicker)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNewSeriesPopup)
    }

    private func save() {
        // Enforce book limit (4 total for free users)
        let descriptor = FetchDescriptor<Book>()
        let existingBooks = (try? modelContext.fetch(descriptor)) ?? []
        let decision = limits.canCreate(.bookCardsTotal, currentCount: existingBooks.count)
        guard decision.allowed else { return }
        let cleanTitle = titleTrimmed
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanSeriesLabel = seriesLabelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSeries: BookSeries? = {
            guard hasSeries else { return nil }
            if let selectedSeries { return selectedSeries }

            let cleanSeriesName = selectedSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanSeriesName.isEmpty else { return nil }

            if let existing = bookSeries.first(where: { $0.title.caseInsensitiveCompare(cleanSeriesName) == .orderedSame }) {
                return existing
            }

            let newSeries = BookSeries(title: cleanSeriesName)
            modelContext.insert(newSeries)
            try? modelContext.save()
            return newSeries
        }()

        let book = Book(
            title: cleanTitle,
            author: cleanAuthor,
            shortSummary: cleanSummary,
            tagsRaw: tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: 0,
            status: status,
            startedAt: hasStartedDate ? startedDate : nil,
            finishedAt: hasFinishedDate ? finishedDate : nil
        )
        
        if hasSeries {
            book.series = resolvedSeries
            book.seriesIndex = Int(seriesPositionText.filter { $0.isNumber })
            book.seriesLabel = cleanSeriesLabel
        } else {
            book.series = nil
            book.seriesIndex = nil
            book.seriesLabel = ""
        }

        if status == .reading {
            let current = Int(currentPageText.filter { $0.isNumber })
            let total = Int(totalPagesText.filter { $0.isNumber })

            if let total, total > 0 {
                let safeCurrent = min(max(current ?? 0, 0), total)
                book.totalPages = total
                book.currentPage = safeCurrent
            } else {
                book.totalPages = nil
                book.currentPage = nil
            }

            if !hasFinishedDate {
                book.finishedAt = nil
            }
        } else {
            book.totalPages = nil
            book.currentPage = nil

            if status == .finished {
                book.finishedAt = hasFinishedDate ? finishedDate : Date()
            } else {
                book.finishedAt = hasFinishedDate ? finishedDate : nil
            }
        }

        book.updatedAt = Date()

        modelContext.insert(book)
        try? modelContext.save()
        closeAction()
    }


}

// MARK: - Edit Book Sheet
struct EditBookSheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookSeries.title, order: .forward) private var bookSeries: [BookSeries]
    var onClose: (() -> Void)? = nil

    @State private var title: String
    @State private var author: String
    @State private var status: BookStatus
    @State private var currentPageText: String
    @State private var totalPagesText: String
    @State private var shortSummary: String
    @State private var tagsRaw: String
    @State private var hasStartedDate: Bool
    @State private var startedDate: Date
    @State private var hasFinishedDate: Bool
    @State private var finishedDate: Date
    @State private var hasSeries: Bool
    @State private var selectedSeries: BookSeries?
    @State private var selectedSeriesName: String
    @State private var seriesPositionText: String
    @State private var seriesLabelText: String
    @State private var showSeriesPicker: Bool = false
    @State private var showNewSeriesPopup: Bool = false

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var closeAction: () -> Void {
        onClose ?? {}
    }

    init(book: Book, onClose: (() -> Void)? = nil) {
        self.book = book
        self.onClose = onClose
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _status = State(initialValue: book.status)
        _currentPageText = State(initialValue: book.currentPage.map(String.init) ?? "")
        _totalPagesText = State(initialValue: book.totalPages.map(String.init) ?? "")
        _shortSummary = State(initialValue: book.shortSummary)
        _tagsRaw = State(initialValue: book.tagsRaw)
        _hasStartedDate = State(initialValue: book.startedAt != nil)
        _startedDate = State(initialValue: book.startedAt ?? Date())
        _hasFinishedDate = State(initialValue: book.finishedAt != nil)
        _finishedDate = State(initialValue: book.finishedAt ?? Date())
        _hasSeries = State(initialValue: book.series != nil || book.seriesIndex != nil || !book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        _selectedSeries = State(initialValue: book.series)
        _selectedSeriesName = State(initialValue: book.series?.title ?? "")
        _seriesPositionText = State(initialValue: book.seriesIndex.map(String.init) ?? "")
        _seriesLabelText = State(initialValue: book.seriesLabel)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Edit Book", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Book title", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AUTHOR")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Author name", text: $author)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUMMARY")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextArea(placeholder: "Short summary (optional)", text: $shortSummary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Fantasy, Romance, Fae", text: $tagsRaw)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(BookStatus.allCases, id: \.self) { s in
                                    let isSelected = status == s
                                    let backgroundStyle = isSelected ? LColors.accent : Color.white.opacity(0.08)
                                    let strokeColor = isSelected ? LColors.accent : LColors.glassBorder
                                    let textColor = isSelected ? Color.white : LColors.textPrimary

                                    Button {
                                        status = s
                                    } label: {
                                        Text(s.label)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(textColor)
                                            .lineLimit(1)
                                            .fixedSize()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(backgroundStyle)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(strokeColor, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasSeries) {
                            Text("SERIES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasSeries {
                            HStack(spacing: 10) {
                                Button {
                                    showSeriesPicker = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "books.vertical")
                                        Text(selectedSeriesName.isEmpty ? "Select Series" : selectedSeriesName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showNewSeriesPopup = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                        Text("New Series")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
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

                            VStack(alignment: .leading, spacing: 8) {
                                Text("POSITION")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                LystariaNumberField(placeholder: "1", text: $seriesPositionText)
                                    .numericKeyboardIfAvailable()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("LABEL")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                LystariaTextField(placeholder: "Book 1, Novella 0.5, Companion", text: $seriesLabelText)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasStartedDate) {
                            Text("START DATE")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasStartedDate {
                            DatePicker(
                                "",
                                selection: $startedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasFinishedDate) {
                            Text("FINISH DATE")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)
                        }
                        .tint(LColors.accent)

                        if hasFinishedDate {
                            DatePicker(
                                "",
                                selection: $finishedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                    }

                    if status == .reading {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PAGES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("CURRENT")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    LystariaNumberField(placeholder: "0", text: $currentPageText)
                                        .numericKeyboardIfAvailable()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TOTAL")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    LystariaNumberField(placeholder: "0", text: $totalPagesText)
                                        .numericKeyboardIfAvailable()
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }
            },
            footer: {
                Button { save() } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(titleTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: titleTrimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(titleTrimmed.isEmpty)
            }
        )
        .onChange(of: status) { _, newStatus in
            if newStatus != .reading {
                currentPageText = ""
                totalPagesText = ""
            }

            if newStatus == .finished && !hasFinishedDate {
                finishedDate = Date()
                hasFinishedDate = true
            }
        }
        .overlay {
            if showSeriesPicker {
                BookSeriesPickerPopup(
                    seriesList: bookSeries,
                    onClose: {
                        showSeriesPicker = false
                    },
                    onSelect: { series in
                        selectedSeries = series
                        selectedSeriesName = series.title
                        showSeriesPicker = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(90)
            }
        }
        .overlay {
            if showNewSeriesPopup {
                CreateBookSeriesPopup(
                    onClose: {
                        showNewSeriesPopup = false
                    },
                    onCreate: { title in
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { return }

                        if let existing = bookSeries.first(where: { $0.title.caseInsensitiveCompare(cleanTitle) == .orderedSame }) {
                            selectedSeries = existing
                            selectedSeriesName = existing.title
                        } else {
                            let newSeries = BookSeries(title: cleanTitle)
                            modelContext.insert(newSeries)
                            try? modelContext.save()
                            selectedSeries = newSeries
                            selectedSeriesName = newSeries.title
                        }

                        showNewSeriesPopup = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(91)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSeriesPicker)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNewSeriesPopup)
    }

    private func save() {
        let cleanTitle = titleTrimmed
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSeriesLabel = seriesLabelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSeries: BookSeries? = {
            guard hasSeries else { return nil }
            if let selectedSeries { return selectedSeries }

            let cleanSeriesName = selectedSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanSeriesName.isEmpty else { return nil }

            if let existing = bookSeries.first(where: { $0.title.caseInsensitiveCompare(cleanSeriesName) == .orderedSame }) {
                return existing
            }

            let newSeries = BookSeries(title: cleanSeriesName)
            modelContext.insert(newSeries)
            try? modelContext.save()
            return newSeries
        }()

        book.title = cleanTitle
        book.author = cleanAuthor
        book.status = status
        book.shortSummary = cleanSummary
        book.tagsRaw = tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        book.startedAt = hasStartedDate ? startedDate : nil
        book.finishedAt = hasFinishedDate ? finishedDate : nil
        
        if hasSeries {
            book.series = resolvedSeries
            book.seriesIndex = Int(seriesPositionText.filter { $0.isNumber })
            book.seriesLabel = cleanSeriesLabel
        } else {
            book.series = nil
            book.seriesIndex = nil
            book.seriesLabel = ""
        }

        if status == .reading {
            let current = Int(currentPageText.filter { $0.isNumber })
            let total = Int(totalPagesText.filter { $0.isNumber })

            if let total, total > 0 {
                let safeCurrent = min(max(current ?? 0, 0), total)
                book.totalPages = total
                book.currentPage = safeCurrent
            } else {
                book.totalPages = nil
                book.currentPage = nil
            }

            if !hasFinishedDate {
                book.finishedAt = nil
            }
        } else {
            book.totalPages = nil
            book.currentPage = nil

            if status == .finished {
                book.finishedAt = hasFinishedDate ? finishedDate : Date()
            } else {
                book.finishedAt = hasFinishedDate ? finishedDate : nil
            }
        }

        book.updatedAt = Date()
        try? modelContext.save()
        closeAction()
    }
}

// MARK: - Book Series Picker Popup
struct BookSeriesPickerPopup: View {
    let seriesList: [BookSeries]
    var onClose: (() -> Void)? = nil
    var onSelect: ((BookSeries) -> Void)? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var sortedSeries: [BookSeries] {
        seriesList.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 620,
            heightRatio: 0.68,
            header: {
                HStack {
                    GradientTitle(text: "Select Series", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                if sortedSeries.isEmpty {
                    GlassCard {
                        Text("No series yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    ForEach(sortedSeries) { series in
                        Button {
                            onSelect?(series)
                        } label: {
                            GlassCard {
                                Text(series.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
    }
}

// MARK: - Create Book Series Popup
struct CreateBookSeriesPopup: View {
    var onClose: (() -> Void)? = nil
    var onCreate: ((String) -> Void)? = nil

    @State private var title: String = ""

    private var closeAction: () -> Void { onClose ?? {} }
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 620,
            heightRatio: 0.54,
            header: {
                HStack {
                    GradientTitle(text: "New Series", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaTextField(placeholder: "Series title", text: $title)
                }
            },
            footer: {
                Button {
                    onCreate?(trimmedTitle)
                } label: {
                    Text("Create")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(trimmedTitle.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: trimmedTitle.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(trimmedTitle.isEmpty)
            }
        )
    }
}

// MARK: - Log Reading Session Sheet
struct LogReadingSessionSheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \ReadingGoal.updatedAt, order: .reverse) private var readingGoals: [ReadingGoal]
    var onClose: (() -> Void)? = nil

    @State private var startPageText: String
    @State private var endPageText: String
    @State private var minutesReadText: String = ""
    @State private var sessionDate: Date = Date()

    private var closeAction: () -> Void {
        onClose ?? {}
    }

    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var activeGoal: ReadingGoal? {
        guard let currentUserId else { return nil }
        return readingGoals.first(where: { $0.userId == currentUserId && $0.isActive })
    }

    private var normalizedSessionDay: Date {
        Calendar.current.startOfDay(for: sessionDate)
    }

    private var canSave: Bool {
        let start = Int(startPageText.filter { $0.isNumber })
        let end = Int(endPageText.filter { $0.isNumber })
        let minutes = Int(minutesReadText.filter { $0.isNumber })

        return start != nil || end != nil || (minutes ?? 0) > 0
    }

    init(book: Book, onClose: (() -> Void)? = nil) {
        self.book = book
        self.onClose = onClose
        let current = book.currentPage ?? 0
        _startPageText = State(initialValue: current > 0 ? "\(current)" : "")
        _endPageText = State(initialValue: current > 0 ? "\(current)" : "")
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.68,
            header: {
                HStack {
                    GradientTitle(text: "Log Session", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(LColors.textPrimary)

                    if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("PAGES")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("START PAGE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            LystariaNumberField(placeholder: "0", text: $startPageText)
                                .numericKeyboardIfAvailable()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("END PAGE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            LystariaNumberField(placeholder: "0", text: $endPageText)
                                .numericKeyboardIfAvailable()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("MINUTES READ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaNumberField(placeholder: "0", text: $minutesReadText)
                        .numericKeyboardIfAvailable()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DATE & TIME")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    DatePicker(
                        "",
                        selection: $sessionDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
            },
            footer: {
                Button {
                    save()
                } label: {
                    Text("Save Session")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: canSave ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        )
    }

    private func save() {
        let start = Int(startPageText.filter { $0.isNumber })
        let end = Int(endPageText.filter { $0.isNumber })
        let minutes = Int(minutesReadText.filter { $0.isNumber }) ?? 0
        let pagesRead = {
            guard let start, let end else { return 0 }
            return max(end - start, 0)
        }()

        let session = ReadingSession(
            book: book,
            startPage: start,
            endPage: end,
            minutesRead: minutes,
            pagesRead: pagesRead,   // ← ADD THIS
            sessionDate: sessionDate
        )

        modelContext.insert(session)

        if let end, end >= 0 {
            if let total = book.totalPages, total > 0 {
                book.currentPage = min(end, total)

                if end >= total {
                    if book.status != .finished || book.finishedAt == nil {
                        book.finishedAt = Date()
                    }
                    book.status = .finished
                } else {
                    book.finishedAt = nil
                    if book.status != .reading {
                        book.status = .reading
                    }
                }
            } else {
                book.currentPage = end
                book.finishedAt = nil
                if book.status != .reading {
                    book.status = .reading
                }
            }
        }

        if let currentUserId {
            var dailyDescriptor = FetchDescriptor<DailyReadingProgress>(
                predicate: #Predicate<DailyReadingProgress> { progress in
                    progress.userId == currentUserId && progress.date == normalizedSessionDay
                }
            )
            dailyDescriptor.fetchLimit = 1

            let existingDailyProgress = try? modelContext.fetch(dailyDescriptor).first
            let dailyProgress = existingDailyProgress ?? DailyReadingProgress(
                userId: currentUserId,
                date: normalizedSessionDay,
                pagesRead: 0,
                minutesRead: 0,
                createdAt: Date(),
                updatedAt: Date()
            )

            dailyProgress.pagesRead += max(pagesRead, 0)
            dailyProgress.minutesRead += max(minutes, 0)
            dailyProgress.updatedAt = Date()

            if existingDailyProgress == nil {
                modelContext.insert(dailyProgress)
            }
        }

        if let goal = activeGoal, sessionCountsTowardGoal(goal, sessionDate: sessionDate) {
            let progressIncrement = progressContribution(for: goal, pagesRead: pagesRead, minutesRead: minutes, book: book, sessionEndPage: end)
            if progressIncrement > 0 {
                goal.progressValue += progressIncrement
                goal.updatedAt = Date()
            }
        }

        book.updatedAt = Date()
        session.updatedAt = Date()

        try? modelContext.save()
        closeAction()
    }

    private func sessionCountsTowardGoal(_ goal: ReadingGoal, sessionDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch goal.period {
        case .daily:
            return calendar.isDate(sessionDate, inSameDayAs: now)
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return interval.contains(sessionDate)
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return false }
            return interval.contains(sessionDate)
        case .yearly:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return false }
            return interval.contains(sessionDate)
        }
    }

    private func progressContribution(for goal: ReadingGoal, pagesRead: Int, minutesRead: Int, book: Book, sessionEndPage: Int?) -> Int {
        switch goal.metric {
        case .pages:
            return max(pagesRead, 0)
        case .minutes:
            return max(minutesRead, 0)
        case .hours:
            guard minutesRead > 0 else { return 0 }
            return max(Int(ceil(Double(minutesRead) / 60.0)), 0)
        case .books:
            guard let total = book.totalPages,
                  total > 0,
                  let sessionEndPage,
                  sessionEndPage >= total else { return 0 }
            return 1
        }
    }
}

// MARK: - Book Detail Sheet
struct BookDetailSheet: View {
    let book: Book
    var onClose: (() -> Void)? = nil
    var onLogSession: (() -> Void)? = nil
    var onShowSessionHistory: (() -> Void)? = nil
    var onShowNotes: (() -> Void)? = nil
    var onShowSeries: (() -> Void)? = nil
    var onShowPoints: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var sessionsSorted: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
    }

    // --- Simplified footer button views ---
    private var sessionHistoryButton: some View {
        Button {
            onShowSessionHistory?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                Text("Session History")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 14)
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

    private var notesButton: some View {
            Button {
                onShowNotes?()
            } label: {
                HStack(spacing: 8) {
                    Image("pencilcircle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(LColors.textPrimary)
                .padding(.horizontal, 14)
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
    
    private var pointsButton: some View {
        Button {
            onShowPoints?()
        } label: {
            HStack(spacing: 8) {
                Image("sparklefill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.white)
                    .padding(.top, 1)
                Text("Points")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 14)
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

    private var seriesButton: some View {
        Group {
            if book.series != nil {
                Button {
                    onShowSeries?()
                } label: {
                    HStack(spacing: 8) {
                        Image("openmark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("View Series")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(LColors.textPrimary)
                    .padding(.horizontal, 14)
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
    }

    // MARK: - Book Detail Sheet content refactored for type-checking

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            topSection
            summarySection
            timelineSection
            tagsSection
            progressSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topSection: some View {
        HStack(alignment: .top, spacing: 16) {
            coverSection

            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.title3.bold())
                    .foregroundStyle(LColors.textPrimary)

                if let series = book.series {
                    let cleanLabel = book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    let text: String = {
                        if !cleanLabel.isEmpty {
                            return "\(series.title) • \(cleanLabel)"
                        }
                        if let index = book.seriesIndex {
                            return "\(series.title) • Book \(index)"
                        }
                        return series.title
                    }()

                    Text(text)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(book.author)
                        .font(.body) // increased from subheadline
                        .foregroundStyle(LColors.textSecondary)
                }

                StatusBadge(status: book.status)

                ratingSection
            }

            Spacer()
        }
    }

    private func seriesSection(_ series: BookSeries) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SERIES")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(series.title)
                    .font(.subheadline)
                    .foregroundStyle(LColors.textPrimary)

                if !book.seriesLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(book.seriesLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                } else if let index = book.seriesIndex {
                    Text("Book \(index)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
    }

    private var ratingSection: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    let newValue = (book.rating == i) ? 0 : i
                    book.rating = newValue
                    book.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image("starfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(i <= book.rating ? Color.white : LColors.textSecondary.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var summarySection: some View {
        Group {
            if !book.shortSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUMMARY")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    Text(book.shortSummary)
                        .font(.subheadline)
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
    }

    private var timelineSection: some View {
        Group {
            if book.startedAt != nil || book.finishedAt != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIMELINE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        if let started = book.startedAt {
                            Text("Started: \(started.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(red: 0.00, green: 0.86, blue: 1.00).opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AnyShapeStyle(LGradients.blue), lineWidth: 1)
                                )
                        }

                        if let finished = book.finishedAt {
                            Text("Finished: \(finished.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(red: 0.49, green: 0.10, blue: 0.97).opacity(0.18))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AnyShapeStyle(LGradients.blue), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        Group {
            if !book.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(book.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AnyShapeStyle(LGradients.blue))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(AnyShapeStyle(LGradients.blue), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private var progressSection: some View {
        Group {
            if book.status == .reading,
               let total = book.totalPages, total > 0,
               let current = book.currentPage {
                let clampedCurrent = min(max(current, 0), total)
                let progress = CGFloat(book.progressPercent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PROGRESS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )

                        GeometryReader { geo in
                            let width = max(0, min(geo.size.width * progress, geo.size.width))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AnyShapeStyle(LGradients.blue))
                                .frame(width: width, height: 10)
                        }
                        .frame(height: 10)
                    }

                    HStack {
                        Text("\(clampedCurrent) / \(total) pages")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            }
        }
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.78,
            header: {
                HStack {
                    GradientTitle(text: "Book Details", font: .title2.bold())
                    Spacer()
                    // EXISTING icon button
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                contentView
            },
            footer: {
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .vertical) {
                        HStack(spacing: 10) {
                            sessionHistoryButton
                            notesButton
                            pointsButton
                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                sessionHistoryButton
                                notesButton
                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 10) {
                                pointsButton
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    if book.series != nil {
                        HStack(spacing: 10) {
                            seriesButton
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }

            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        book.coverImageData = data
                        book.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coverSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )

                if let data = book.coverImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Image("booksfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(LColors.textSecondary)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Upload Cover")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Book Points Popup
struct BookPointsPopup: View {
    let book: Book
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \ReadingPointsEntry.date, order: .reverse) private var readingPointsEntries: [ReadingPointsEntry]

    @State private var visibleEntryCount: Int = 6
    @State private var pointsEntryPendingDeletion: ReadingPointsEntry? = nil
    @State private var showDeletePointsConfirm: Bool = false

    private var closeAction: () -> Void { onClose ?? {} }

    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var bookIdString: String {
        String(describing: book.persistentModelID)
    }

    private var filteredEntries: [ReadingPointsEntry] {
        guard let currentUserId else { return [] }
        return readingPointsEntries.filter { entry in
            guard entry.userId == currentUserId else { return false }

            let matchesBookId = entry.bookId == bookIdString
            let matchesBookTitle = entry.bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(book.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame

            return matchesBookId || matchesBookTitle
        }
    }

    private var totalPoints: Int {
        filteredEntries.reduce(0) { $0 + max($1.pointsEarned, 0) }
    }

    private var totalMinutes: Int {
        filteredEntries.reduce(0) { $0 + max($1.minutesRead, 0) }
    }

    private var sessionCount: Int {
        filteredEntries.count
    }

    private var visibleEntries: [ReadingPointsEntry] {
        Array(filteredEntries.prefix(visibleEntryCount))
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 700,
            heightRatio: 0.76,
            header: {
                HStack {
                    GradientTitle(text: "Book Points", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(LColors.textPrimary)

                    if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOTAL POINTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.8)

                        Text("\(totalPoints)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(LColors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("MINUTES READ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.8)

                        Text("\(totalMinutes)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(LColors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }

                HStack(spacing: 10) {
                    Text("Sessions logged: \(sessionCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer()
                }

                if filteredEntries.isEmpty {
                    GlassCard {
                        Text("No points earned for this book yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    ForEach(visibleEntries) { entry in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                HStack(spacing: 12) {
                                    Text("Minutes: \(entry.minutesRead)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text("Points: \(entry.pointsEarned)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.6) {
                            pointsEntryPendingDeletion = entry
                            showDeletePointsConfirm = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                pointsEntryPendingDeletion = entry
                                showDeletePointsConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image("trashfill")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                    Text("Delete Points Entry")
                                }
                            }
                        }
                    }

                    if filteredEntries.count > visibleEntries.count {
                        HStack {
                            Spacer()
                            LoadMoreButton {
                                visibleEntryCount += 6
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
        .onAppear {
            visibleEntryCount = 6
        }
        .alert("Delete points entry?", isPresented: $showDeletePointsConfirm) {
            Button("Delete", role: .destructive) {
                if let entry = pointsEntryPendingDeletion {
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
                pointsEntryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pointsEntryPendingDeletion = nil
            }
        } message: {
            Text("This will remove this stored points entry from the book points history.")
        }
    }
}

// MARK: - Book Notes Popup
struct BookNotesPopup: View {
    let book: Book
    var onClose: (() -> Void)? = nil
    var onAddNote: (() -> Void)? = nil
    var onSelectNote: ((BookNote) -> Void)? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var notesSorted: [BookNote] {
        (book.notes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private func noteDateText(_ note: BookNote) -> String {
        note.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.72,
            header: {
                HStack {
                    GradientTitle(text: "Notes", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(LColors.textPrimary)

                    if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onAddNote?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Note")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 14)
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
                }

                if notesSorted.isEmpty {
                    GlassCard {
                        Text("No notes yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    ForEach(notesSorted) { note in
                        Button {
                            onSelectNote?(note)
                        } label: {
                            GlassCard {
                                Text(noteDateText(note))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
    }
}

// MARK: - Add Book Note Popup
struct AddBookNotePopup: View {
    let book: Book
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    private var closeAction: () -> Void { onClose ?? {} }

    private var autoDateText: String {
        Date().formatted(date: .abbreviated, time: .omitted)
    }

    private var trimmedNoteText: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.68,
            header: {
                HStack {
                    GradientTitle(text: "Add Note", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(autoDateText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextArea(placeholder: "Write your note...", text: $noteText)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }
            },
            footer: {
                Button {
                    let note = BookNote(
                        book: book,
                        text: trimmedNoteText,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    modelContext.insert(note)
                    try? modelContext.save()
                    closeAction()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(trimmedNoteText.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: trimmedNoteText.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(trimmedNoteText.isEmpty)
            }
        )
    }
}

// MARK: - Book Note Detail Popup
struct BookNoteDetailPopup: View {
    let note: BookNote
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm: Bool = false
    @State private var showingEditPopup: Bool = false

    private var closeAction: () -> Void { onClose ?? {} }

    private var noteDateText: String {
        note.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Note", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(noteDateText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassCard {
                        Text(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No note text." : note.text)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            },
            footer: {
                HStack(spacing: 10) {
                    Button {
                        showingEditPopup = true
                    } label: {
                        HStack(spacing: 8) {
                            Image("pencilcircle")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Delete")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 14)
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
                }
            }
        )
        .overlay {
            if showingEditPopup {
                EditBookNotePopup(
                    note: note,
                    onClose: {
                        showingEditPopup = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingEditPopup)
        .alert("Delete note?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
                closeAction()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This will permanently remove this note.")
        }
    }
}

struct EditBookNotePopup: View {
    let note: BookNote
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String

    private var closeAction: () -> Void { onClose ?? {} }

    private var noteDateText: String {
        note.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var trimmedNoteText: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(note: BookNote, onClose: (() -> Void)? = nil) {
        self.note = note
        self.onClose = onClose
        _noteText = State(initialValue: note.text)
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: "Edit Note", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(noteDateText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    LystariaTextArea(placeholder: "Write your note...", text: $noteText)
                }
            },
            footer: {
                Button {
                    note.text = trimmedNoteText
                    note.updatedAt = Date()
                    try? modelContext.save()
                    closeAction()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(trimmedNoteText.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: trimmedNoteText.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(trimmedNoteText.isEmpty)
            }
        )
    }
}

// MARK: - Book Session History Sheet
struct BookSessionHistorySheet: View {
    let book: Book
    var onClose: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @State private var visibleSessionCount: Int = 4
    @State private var showDeleteSessionConfirm: Bool = false
    @State private var sessionPendingDeletion: ReadingSession? = nil
    
    @Query(sort: \ReadingGoal.updatedAt, order: .reverse) private var readingGoals: [ReadingGoal]
    @Query(sort: \ReadingPointsEntry.date, order: .reverse) private var readingPointsEntries: [ReadingPointsEntry]

    private var closeAction: () -> Void { onClose ?? {} }

    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var activeGoal: ReadingGoal? {
        guard let currentUserId else { return nil }
        return readingGoals.first(where: { $0.userId == currentUserId && $0.isActive })
    }

    private var sessionsSorted: [ReadingSession] {
        (book.sessions ?? [])
            .filter { !$0.isTimerSession }
            .sorted { $0.sessionDate > $1.sessionDate }
    }

    private var bookIdString: String {
        String(describing: book.persistentModelID)
    }

    private func deleteMatchingPointsEntries(for session: ReadingSession) {
        let matchingEntries = readingPointsEntries.filter { entry in
            guard entry.userId == currentUserId else { return false }

            let sameBook = entry.bookId == bookIdString ||
                entry.bookTitle.caseInsensitiveCompare(book.title) == .orderedSame
            guard sameBook else { return false }

            let sameMinutes = entry.minutesRead == session.minutesRead && entry.pointsEarned == session.minutesRead
            guard sameMinutes else { return false }

            let timeDelta = abs(entry.date.timeIntervalSince(session.sessionDate))
            return timeDelta <= 120
        }

        for entry in matchingEntries {
            modelContext.delete(entry)
        }
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 680,
            heightRatio: 0.75,
            header: {
                HStack {
                    GradientTitle(text: "Session History", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(LColors.textPrimary)

                    if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                if sessionsSorted.isEmpty {
                    GlassCard {
                        Text("No sessions logged yet.")
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                } else {
                    let visibleSessions = Array(sessionsSorted.prefix(visibleSessionCount))

                    ForEach(visibleSessions) { session in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.sessionDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                HStack(spacing: 12) {
                                    if let start = session.startPage {
                                        Text("Start: \(start)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    if let end = session.endPage {
                                        Text("End: \(end)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    Text("Minutes: \(session.minutesRead)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LColors.textSecondary)

                                    Text("Pages: \(session.pagesRead)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.6) {
                            sessionPendingDeletion = session
                            showDeleteSessionConfirm = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                sessionPendingDeletion = session
                                showDeleteSessionConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image("trashfill")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                    Text("Delete Session")
                                }
                            }
                        }
                    }

                    if sessionsSorted.count > visibleSessions.count {
                        HStack {
                            Spacer()
                            LoadMoreButton {
                                visibleSessionCount += 4
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            },
            footer: {
                EmptyView()
            }
        )
        .onAppear {
            visibleSessionCount = 4
        }
        .alert("Delete session?", isPresented: $showDeleteSessionConfirm) {
            Button("Delete", role: .destructive) {
                if let session = sessionPendingDeletion {
                    deleteSession(session)
                }
                sessionPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            Text("This will remove this reading session from the book history.")
        }
    }

    private func deleteSession(_ session: ReadingSession) {
        if let goal = activeGoal, sessionCountsTowardGoal(goal, sessionDate: session.sessionDate) {
            let progressDecrement = progressContribution(for: goal, session: session, book: book)
            if progressDecrement > 0 {
                goal.progressValue = max(goal.progressValue - progressDecrement, 0)
                goal.updatedAt = Date()
            }
        }

        let remainingSessions = (book.sessions ?? [])
            .filter { $0.persistentModelID != session.persistentModelID }
            .sorted { $0.sessionDate > $1.sessionDate }

        let latestEndPage = remainingSessions
            .compactMap { $0.endPage }
            .first

        if let latestEndPage {
            if let total = book.totalPages, total > 0 {
                let clamped = min(max(latestEndPage, 0), total)
                book.currentPage = clamped

                if clamped >= total {
                    book.status = .finished
                    book.finishedAt = book.finishedAt ?? Date()
                } else {
                    book.status = .reading
                    book.finishedAt = nil
                }
            } else {
                book.currentPage = max(latestEndPage, 0)
                book.status = .reading
                book.finishedAt = nil
            }
        } else {
            book.currentPage = nil
            book.finishedAt = nil
            if book.status == .finished {
                book.status = .reading
            }
        }

        deleteMatchingPointsEntries(for: session)
        book.updatedAt = Date()
        modelContext.delete(session)
        try? modelContext.save()
    }

    private func sessionCountsTowardGoal(_ goal: ReadingGoal, sessionDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch goal.period {
        case .daily:
            return calendar.isDate(sessionDate, inSameDayAs: now)
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return interval.contains(sessionDate)
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return false }
            return interval.contains(sessionDate)
        case .yearly:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return false }
            return interval.contains(sessionDate)
        }
    }

    private func progressContribution(for goal: ReadingGoal, session: ReadingSession, book: Book) -> Int {
        switch goal.metric {
        case .pages:
            return max(session.pagesRead, 0)
        case .minutes:
            return max(session.minutesRead, 0)
        case .hours:
            guard session.minutesRead > 0 else { return 0 }
            return max(Int(ceil(Double(session.minutesRead) / 60.0)), 0)
        case .books:
            guard let total = book.totalPages,
                  total > 0,
                  let endPage = session.endPage,
                  endPage >= total else { return 0 }
            return 1
        }
    }
}


// MARK: - Small UI helpers
struct Pill: View {
    let title: String
    let on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? .white : LColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(on ? LColors.accent : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(on ? LColors.accent : LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status badge
struct StatusBadge: View {
    let status: BookStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.badgeColor.opacity(0.90))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
    }
}

extension BookStatus {
    /// Badge color used on book cards.
    var badgeColor: Color {
        switch self {
        case .tbr:
            return Color(red: 0.36, green: 0.20, blue: 0.88)   // purple
        case .reading:
            return Color(red: 0.00, green: 0.86, blue: 1.00)   // teal
        case .finished:
            return Color(red: 0.22, green: 0.84, blue: 0.49)   // green
        case .paused:
            return Color(red: 0.98, green: 0.76, blue: 0.18)   // amber
        case .dnf:
            return Color(red: 0.96, green: 0.33, blue: 0.37)   // red
        @unknown default:
            return LColors.accent
        }
    }
}

// MARK: - LystariaTextField (plain, glassy, no macOS grey chrome)
struct LystariaTextField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain) // removes the default macOS rounded grey field
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
            .foregroundStyle(LColors.textPrimary)
    }
}

// MARK: - LystariaTextArea (multiline, glassy)
struct LystariaTextArea: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(10)
                .foregroundStyle(LColors.textPrimary)
                .frame(minHeight: 110)
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - LystariaNumberField (digits only, glassy)
struct LystariaNumberField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
            .foregroundStyle(LColors.textPrimary)
            .onChange(of: text) { _, newValue in
                // keep only digits
                let filtered = newValue.filter { $0.isNumber }
                if filtered != newValue {
                    text = filtered
                }
            }
    }
}

// MARK: - Reading Goal Sheet
struct ReadingGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    
    let existingGoal: ReadingGoal?
    let currentUserId: String?
    var onClose: (() -> Void)? = nil
    
    @Query(sort: \ReadingGoal.updatedAt, order: .reverse) private var readingGoals: [ReadingGoal]
    
    @State private var period: ReadingGoalPeriod
    @State private var metric: ReadingGoalMetric
    @State private var targetValueText: String
    
    private var closeAction: () -> Void { onClose ?? {} }
    
    private var canSave: Bool {
        guard let value = Int(targetValueText.filter { $0.isNumber }) else { return false }
        return value > 0 && currentUserId != nil
    }
    
    init(existingGoal: ReadingGoal?, currentUserId: String?, onClose: (() -> Void)? = nil) {
        self.existingGoal = existingGoal
        self.currentUserId = currentUserId
        self.onClose = onClose
        _period = State(initialValue: existingGoal?.period ?? .weekly)
        _metric = State(initialValue: existingGoal?.metric ?? .pages)
        _targetValueText = State(initialValue: existingGoal.map { String($0.targetValue) } ?? "")
    }
    
    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: existingGoal == nil ? "Reading Goal" : "Edit Reading Goal", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERIOD")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ReadingGoalPeriod.allCases, id: \.self) { option in
                                Button {
                                    period = option
                                } label: {
                                    Text(option.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(period == option ? .white : LColors.textPrimary)
                                        .lineLimit(1)
                                        .fixedSize()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(period == option ? LColors.accent : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(period == option ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("METRIC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ReadingGoalMetric.allCases, id: \.self) { option in
                                Button {
                                    metric = option
                                } label: {
                                    Text(option.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(metric == option ? .white : LColors.textPrimary)
                                        .lineLimit(1)
                                        .fixedSize()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(metric == option ? LColors.accent : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(metric == option ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    
                    LystariaNumberField(placeholder: "Enter target", text: $targetValueText)
                        .numericKeyboardIfAvailable()
                }
            },
            footer: {
                Button {
                    save()
                } label: {
                    Text(existingGoal == nil ? "Save Goal" : "Save Changes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: canSave ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        )
    }
    
    private func save() {
        guard let currentUserId else { return }
        guard let targetValue = Int(targetValueText.filter { $0.isNumber }), targetValue > 0 else { return }
        
        if let existingGoal {
            existingGoal.period = period
            existingGoal.metric = metric
            existingGoal.targetValue = targetValue
            existingGoal.isActive = true
            existingGoal.updatedAt = Date()
        } else {
            for goal in readingGoals where goal.userId == currentUserId && goal.isActive {
                goal.isActive = false
                goal.updatedAt = Date()
            }
            
            let goal = ReadingGoal(
                userId: currentUserId,
                isActive: true,
                period: period,
                metric: metric,
                targetValue: targetValue,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(goal)
        }
        
        try? modelContext.save()
        closeAction()
    }
}

// MARK: - Keyboard Dismiss Helper
#if canImport(UIKit)
import UIKit
#endif

fileprivate func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
