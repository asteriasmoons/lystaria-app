// ReadingTabView.swift
// Lystaria

import SwiftUI
import SwiftData
import PhotosUI

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
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingStats.updatedAt, order: .reverse) private var readingStats: [ReadingStats]
    @Query(sort: \ReadingGoal.updatedAt, order: .reverse) private var readingGoals: [ReadingGoal]
    @Query(sort: \ReadingSession.sessionDate, order: .reverse) private var readingSessions: [ReadingSession]
    @EnvironmentObject private var appState: AppState

    @State private var showAddBook = false
    @State private var editingBook: Book? = nil
    @State private var visibleBookCount: Int = 4
    @State private var showBookmarksView = false
    @State private var showingReadingGoalSheet = false
    @State private var editingReadingGoal: ReadingGoal? = nil

    @State private var showDeleteConfirm = false
    @State private var bookPendingDeletion: Book? = nil
    @State private var showSummary = true
    @State private var showBookSummaryPopup = false
    @State private var showBookRecommendationsPopup = false
    @State private var tagFilter: String? = nil
    @State private var selectedStatus: BookStatus? = nil
    
    @State private var loggingSessionForBook: Book? = nil
    @State private var selectedBookForDetails: Book? = nil
    @State private var showingSessionHistoryForBook: Book? = nil

    private var currentUserId: String? {
        appState.currentAppleUserId
    }

    private var currentStats: ReadingStats? {
        guard let currentUserId else { return nil }
        let matches = readingStats.filter { $0.userId == currentUserId }
        return matches.max(by: { $0.updatedAt < $1.updatedAt })
    }

    private var streakDays: Int {
        currentStats?.streakDays ?? 0
    }

    private var lastCheckInDate: Date? {
        currentStats?.lastCheckInDate
    }

    private var alreadyCheckedInToday: Bool {
        guard let lastCheckInDate else { return false }
        return Calendar.current.isDateInToday(lastCheckInDate)
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
        Int((currentGoalProgressFraction * Double(currentGoalSegmentCount)).rounded(.up))
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

            Spacer()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                mainScrollContent
                readingPopupsOverlay
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookSummaryPopup)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookRecommendationsPopup)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAddBook = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LColors.accent.opacity(0.85))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                        .shadow(color: LColors.accent.opacity(0.25), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 26)
                .padding(.bottom, 110)
                .zIndex(10000)
            }
            .zIndex(10000)
            .overlay {
                if showAddBook {
                    AddBookSheet(
                        onClose: {
                            showAddBook = false
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(70)
                }
            }
            .overlay {
                if let book = editingBook {
                    EditBookSheet(
                        book: book,
                        onClose: {
                            editingBook = nil
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(70)
                }
            }
            .overlay {
                if let book = loggingSessionForBook {
                    LogReadingSessionSheet(
                        book: book,
                        onClose: {
                            loggingSessionForBook = nil
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(71)
                }
            }
            .overlay {
                if let book = selectedBookForDetails {
                    BookDetailSheet(
                        book: book,
                        onClose: {
                            selectedBookForDetails = nil
                        },
                        onLogSession: {
                            loggingSessionForBook = book
                        },
                        onShowSessionHistory: {
                            showingSessionHistoryForBook = book
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(72)
                }
            }
            .overlay {
                if let book = showingSessionHistoryForBook {
                    BookSessionHistorySheet(
                        book: book,
                        onClose: {
                            showingSessionHistoryForBook = nil
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(73)
                }
            }
            .overlay {
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
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showAddBook)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: editingBook != nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingReadingGoalSheet)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: loggingSessionForBook != nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedBookForDetails != nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingSessionHistoryForBook != nil)
            .onChange(of: selectedStatus) { _, _ in
                visibleBookCount = 4
            }
            .onChange(of: tagFilter) { _, _ in
                visibleBookCount = 4
            }
            .alert("Delete book?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let b = bookPendingDeletion {
                        b.deletedAt = Date()
                        b.updatedAt = Date()
                        try? modelContext.save()
                    }
                    bookPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    bookPendingDeletion = nil
                }
            } message: {
                Text("This will permanently remove this book.")
            }
            .onAppear {
                ensureReadingStatsRecordExists()
                visibleBookCount = 4
            }
            .navigationDestination(isPresented: $showBookmarksView) {
                BookmarksView()
            }
        }
    }

    private var mainScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                topToggleSection

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
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

                                    Text("\(streakDays) \(streakDays == 1 ? "day" : "days") in a row")
                                        .font(.subheadline)
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }

                            Spacer()

                            HStack {
                                Text("\(streakDays)")
                                    .font(.system(size: 40, weight: .black))
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(LColors.glassSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }

                        HStack(spacing: 12) {
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
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(currentGoalProgressDisplay)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)

                                    Spacer()

                                    Text(currentGoalTargetDisplay)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                HStack(spacing: 8) {
                                    ForEach(0..<currentGoalSegmentCount, id: \.self) { index in
                                        Capsule()
                                            .fill(
                                                index < currentGoalFilledSegments
                                                ? AnyShapeStyle(LGradients.blue)
                                                : AnyShapeStyle(Color.white.opacity(0.08))
                                            )
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 10)
                                            .overlay(
                                                Capsule()
                                                    .stroke(
                                                        index < currentGoalFilledSegments
                                                        ? AnyShapeStyle(LGradients.blue)
                                                        : AnyShapeStyle(LColors.glassBorder),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
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

                                    Spacer()
                                }
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
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(book.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)

                                Spacer(minLength: 8)

                                StatusBadge(status: book.status)
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
    }


    /// Ensures there is exactly one ReadingStats record for the current user.
    private func ensureReadingStatsRecordExists() {
        guard let uid = currentUserId, !uid.isEmpty else {
            print("[ReadingTabView] No signed-in Apple user ID available")
            return
        }

        var descriptor = FetchDescriptor<ReadingStats>(
            predicate: #Predicate<ReadingStats> { record in
                record.userId == uid
            }
        )
        descriptor.fetchLimit = 50

        do {
            let matches = try modelContext.fetch(descriptor)

            if matches.isEmpty {
                let new = ReadingStats(userId: uid, streakDays: 0)
                modelContext.insert(new)
                try modelContext.save()
                print("[ReadingTabView] Created ReadingStats record for userId=\(uid)")
            } else if matches.count > 1 {
                let best = matches.max(by: { $0.updatedAt < $1.updatedAt }) ?? matches[0]
                for dupe in matches where dupe.persistentModelID != best.persistentModelID {
                    modelContext.delete(dupe)
                }
                try modelContext.save()
                print("[ReadingTabView] Cleaned up \(matches.count - 1) duplicate ReadingStats record(s)")
            }
        } catch {
            print("[ReadingTabView] Failed to ensure ReadingStats record: \(error)")
        }
    }


}

// MARK: - Add Book Sheet
struct AddBookSheet: View {
    @Environment(\.modelContext) private var modelContext
    var onClose: (() -> Void)? = nil

    @State private var title = ""
    @State private var author = ""
    @State private var status: BookStatus = .tbr
    @State private var currentPageText = ""
    @State private var totalPagesText = ""
    @State private var shortSummary = ""
    @State private var tagsRaw = ""

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
        }
    }

    private func save() {
        let cleanTitle = titleTrimmed
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        let book = Book(
            title: cleanTitle,
            author: cleanAuthor,
            shortSummary: cleanSummary,
            tagsRaw: tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: 0,
            status: status
        )

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
            book.finishedAt = nil
        } else {
            book.totalPages = nil
            book.currentPage = nil
            book.finishedAt = status == .finished ? Date() : nil
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
    var onClose: (() -> Void)? = nil

    @State private var title: String
    @State private var author: String
    @State private var status: BookStatus
    @State private var currentPageText: String
    @State private var totalPagesText: String
    @State private var shortSummary: String
    @State private var tagsRaw: String

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
                                        .background(isSelected ? LColors.accent : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(isSelected ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
        }
    }

    private func save() {
        let cleanTitle = titleTrimmed
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        let previousStatus = book.status

        book.title = cleanTitle
        book.author = cleanAuthor
        book.status = status
        book.shortSummary = cleanSummary
        book.tagsRaw = tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines)

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
            book.finishedAt = nil
        } else {
            book.totalPages = nil
            book.currentPage = nil

            if status == .finished {
                if previousStatus != .finished || book.finishedAt == nil {
                    book.finishedAt = Date()
                }
            } else {
                book.finishedAt = nil
            }
        }

        book.updatedAt = Date()
        try? modelContext.save()
        closeAction()
    }
}

// MARK: - Log Reading Session Sheet
struct LogReadingSessionSheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    var onClose: (() -> Void)? = nil

    @State private var startPageText: String
    @State private var endPageText: String
    @State private var minutesReadText: String = ""
    @State private var sessionDate: Date = Date()

    private var closeAction: () -> Void {
        onClose ?? {}
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

        let session = ReadingSession(
            book: book,
            startPage: start,
            endPage: end,
            minutesRead: minutes,
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

        book.updatedAt = Date()
        session.updatedAt = Date()

        try? modelContext.save()
        closeAction()
    }
}

// MARK: - Book Detail Sheet
struct BookDetailSheet: View {
    let book: Book
    var onClose: (() -> Void)? = nil
    var onLogSession: (() -> Void)? = nil
    var onShowSessionHistory: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var sessionsSorted: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
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
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                HStack(alignment: .top, spacing: 16) {
                    coverSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.title3.bold())
                            .foregroundStyle(LColors.textPrimary)

                        if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundStyle(LColors.textSecondary)
                        }

                        StatusBadge(status: book.status)

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

                    Spacer()
                }

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

                if book.status == .reading,
                   let total = book.totalPages, total > 0,
                   let current = book.currentPage {
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
                            Text("\(current) / \(total) pages")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            Spacer()

                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("READING")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 10) {
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
                }
            },
            footer: {
                EmptyView()
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

// MARK: - Book Session History Sheet
struct BookSessionHistorySheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    var onClose: (() -> Void)? = nil
    @State private var visibleSessionCount: Int = 4
    @State private var showDeleteSessionConfirm: Bool = false
    @State private var sessionPendingDeletion: ReadingSession? = nil

    private var closeAction: () -> Void { onClose ?? {} }

    private var sessionsSorted: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
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
                        .onLongPressGesture {
                            sessionPendingDeletion = session
                            showDeleteSessionConfirm = true
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

        book.updatedAt = Date()
        modelContext.delete(session)
        try? modelContext.save()
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
