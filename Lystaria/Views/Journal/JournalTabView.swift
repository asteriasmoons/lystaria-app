// JournalTabView.swift
// Lystaria

import SwiftUI
import SwiftData
import Combine
import WidgetKit

struct JournalTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @EnvironmentObject private var appState: AppState
    @State private var showBookEditor = false

    @Query(filter: #Predicate<JournalBook> { $0.deletedAt == nil }, sort: \JournalBook.createdAt, order: .reverse) private var books: [JournalBook]
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil }, sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry] // for migration + counts
    @Query private var journalStatsRecords: [JournalStats]

    @State private var editingBook: JournalBook? = nil
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        header

                        DailyIntentionView()
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.top, 14)
                            .padding(.bottom, 12)

                        JournalStreakCard(
                            currentStreak: currentJournalStreak,
                            bestStreak: bestJournalStreak,
                            journaledToday: journaledToday
                        )
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.bottom, 16)

                        bookshelf
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .overlay(alignment: .bottomTrailing) {
                // TO MOVE FAB ADJUST .PADDING(.BOTTOM, 90)
                // AND DECREASE FOR DOWN AND INCREASE FOR UP
                FloatingActionButton {
                    let decision = limits.canCreate(.journalBooksTotal, currentCount: books.count)
                    guard decision.allowed else { return }

                    editingBook = nil
                    showBookEditor = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100)
            }
            .ignoresSafeArea(edges: .bottom)
            
            .overlay {
                if showBookEditor {
                    JournalBookEditorSheet(
                        book: editingBook,
                        onClose: {
                            showBookEditor = false
                            editingBook = nil
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }
            }
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                ZStack {
                    OnboardingOverlay(anchors: anchors)
                        .environmentObject(onboarding)
                }
                .task(id: anchors.count) {
                    if anchors.count > 0 {
                        onboarding.start(page: OnboardingPages.journal)
                    }
                }
            }
            .onAppear {
                migrateEntriesIntoDefaultBookIfNeeded()
                migrateBookUUIDsIfNeeded()
                JournalEntryBlockMigration.migrateEntriesIfNeeded(allEntries, modelContext: modelContext)
                syncWidgetSnapshot()
            }
            .onChange(of: books) { _, _ in
                syncWidgetSnapshot()
            }
            .onChange(of: allEntries) { _, _ in
                syncWidgetSnapshot()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookEditor)
            // Prevent the NavigationStack default backgrounds from covering the custom background
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Journal", font: .system(size: 28, weight: .bold))

                Spacer()

                HStack(spacing: 8) {

                    NavigationLink {
                        MoodLoggerView()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("wavyheart")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("moodLogsIcon")

                    NavigationLink {
                        HabitsView()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("sparklefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("habitsIcon")

                    NavigationLink {
                        ChecklistsView()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image("checkfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .onboardingTarget("checklistsIcon")
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 16)

            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    // MARK: - Bookshelf

    private var bookshelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            if books.isEmpty {
                EmptyState(icon: "books.vertical", message: "No journal books yet.\nTap + to create your first book.")
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    let allowedBookIds = Set(
                        sortedBooks
                            .sorted { $0.createdAt < $1.createdAt }
                            .prefix(1)
                            .map { $0.persistentModelID }
                    )

                    ForEach(sortedBooks, id: \.persistentModelID) { book in
                        NavigationLink {
                            JournalBookDetailView(book: book)
                        } label: {
                            JournalBookCard(
                                title: book.title,
                                coverHex: book.coverHex,
                                entryCount: entryCount(for: book),
                                lastDate: lastEntryDate(for: book),
                                isPinned: book.pinOrder > 0
                            )
                        }
                        .buttonStyle(.plain)
                        .premiumLocked(!limits.hasPremiumAccess && !allowedBookIds.contains(book.persistentModelID))
                        .contextMenu {
                            if book.pinOrder > 0 {
                                Button("Unpin Book") {
                                    unpinBook(book)
                                }
                            } else {
                                Button("Pin Book") {
                                    pinBook(book)
                                }
                            }

                            Button("Edit Book") {
                                editingBook = book
                                showBookEditor = true
                            }
                            Button(role: .destructive) {
                                deleteBook(book)
                            } label: {
                                Text("Delete Book")
                            }
                        }
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 4)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }
    
    private var sortedBooks: [JournalBook] {
        books.sorted { lhs, rhs in
            let lhsPinned = lhs.pinOrder > 0
            let rhsPinned = rhs.pinOrder > 0

            if lhsPinned != rhsPinned {
                return lhsPinned && !rhsPinned
            }

            if lhsPinned && rhsPinned, lhs.pinOrder != rhs.pinOrder {
                return lhs.pinOrder < rhs.pinOrder
            }

            return lhs.createdAt > rhs.createdAt
        }
    }

    // MARK: - Journal Streaks

    private var streakCalendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    private var journaledDayStarts: Set<Date> {
        Set(allEntries.map { streakCalendar.startOfDay(for: $0.createdAt) })
    }

    private var journaledToday: Bool {
        journaledDayStarts.contains(streakCalendar.startOfDay(for: Date()))
    }

    private var currentJournalStreak: Int {
        let todayStart = streakCalendar.startOfDay(for: Date())
        let startDay: Date

        if journaledDayStarts.contains(todayStart) {
            startDay = todayStart
        } else if let yesterday = streakCalendar.date(byAdding: .day, value: -1, to: todayStart),
                  journaledDayStarts.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startDay

        while journaledDayStarts.contains(cursor) {
            streak += 1
            guard let previous = streakCalendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    /// The best streak ever seen. Computed from live entries, but the result is
    /// persisted to `JournalStats` so it can never drop below its historical high
    /// (e.g. due to a book deletion removing backing entries).
    private var bestJournalStreak: Int {
        let computed = computedBestStreak
        let record = journalStatsRecord
        let result = max(computed, record.bestStreakEver)
        if result > record.bestStreakEver {
            record.bestStreakEver = result
            record.updatedAt = Date()
            try? modelContext.save()
        }
        return result
    }

    private var computedBestStreak: Int {
        let sortedDays = journaledDayStarts.sorted()
        guard !sortedDays.isEmpty else { return currentJournalStreak }

        var best = 1
        var current = 1

        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let currentDay = sortedDays[index]

            if let nextExpected = streakCalendar.date(byAdding: .day, value: 1, to: previous),
               streakCalendar.isDate(nextExpected, inSameDayAs: currentDay) {
                current += 1
            } else {
                current = 1
            }

            best = max(best, current)
        }

        return max(best, currentJournalStreak)
    }

    /// Returns the single `JournalStats` record, creating it if it doesn't exist yet.
    private var journalStatsRecord: JournalStats {
        if let existing = journalStatsRecords.first {
            return existing
        }
        let record = JournalStats()
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }

    // MARK: - Helpers

    private func entryCount(for book: JournalBook) -> Int {
        allEntries.filter { $0.book?.persistentModelID == book.persistentModelID }.count
    }

    private func lastEntryDate(for book: JournalBook) -> Date? {
        allEntries
            .filter { $0.book?.persistentModelID == book.persistentModelID }
            .sorted { $0.createdAt > $1.createdAt }
            .first?.createdAt
    }

    private func deleteBook(_ book: JournalBook) {
        let entriesInBook = allEntries.filter { $0.book?.persistentModelID == book.persistentModelID }
        for e in entriesInBook {
            e.deletedAt = Date()
        }
        book.deletedAt = Date()
        try? modelContext.save()
    }
    
    private func pinBook(_ book: JournalBook) {
        let currentPinned = books.filter { $0.pinOrder > 0 }
        let nextPinOrder = (currentPinned.map(\.pinOrder).max() ?? 0) + 1
        book.pinOrder = nextPinOrder
        try? modelContext.save()
    }

    private func unpinBook(_ book: JournalBook) {
        book.pinOrder = 0
        try? modelContext.save()
    }

    private func migrateBookUUIDsIfNeeded() {
        // All existing books got the same UUID default from SwiftData schema migration.
        // Assign each book a unique UUID if it shares the same one as another book.
        var seen = Set<UUID>()
        var needsSave = false
        for book in books {
            if seen.contains(book.uuid) {
                book.uuid = UUID()
                needsSave = true
            } else {
                seen.insert(book.uuid)
            }
        }
        if needsSave {
            try? modelContext.save()
        }
    }

    private func migrateEntriesIntoDefaultBookIfNeeded() {
        // Goal: if user already had entries (old system), they shouldn’t become “homeless”.
        // We auto-create a default book and assign any entries with nil book to it.

        let hasHomelessEntries = allEntries.contains { $0.book == nil }
        guard hasHomelessEntries else { return }

        let defaultTitle = "General Journal"

        // Try find existing default book
        if let existing = books.first(where: { $0.title == defaultTitle }) {
            for e in allEntries where e.book == nil {
                e.book = existing
                e.updatedAt = Date()
            }
            return
        }

        // Create it
        let created = JournalBook(title: defaultTitle, coverHex: "#6A5CFF")
        modelContext.insert(created)

        // Assign
        for e in allEntries where e.book == nil {
            e.book = created
            e.updatedAt = Date()
        }
    }

    // MARK: - Widget Sync

    private func syncWidgetSnapshot() {
        let defaults = UserDefaults(suiteName: "group.com.asteriasmoons.LystariaDev")

        // MARK: - Books Snapshot
        let booksSnapshot: [[String: String]] = books.map { book in
            [
                "id": "\(book.persistentModelID)",
                "title": book.title,
                "coverHex": book.coverHex
            ]
        }

        if let booksData = try? JSONEncoder().encode(booksSnapshot) {
            defaults?.set(booksData, forKey: "journalWidget.books")
        }

        // MARK: - Entries Snapshot (grouped by book)
        var entriesByBook: [String: [[String: String]]] = [:]

        for entry in allEntries {
            guard let book = entry.book else { continue }

            let bookID = "\(book.persistentModelID)"

            let entryData: [String: String] = [
                "id": "\(entry.persistentModelID)",
                "title": entry.title
            ]

            entriesByBook[bookID, default: []].append(entryData)
        }

        if let entriesData = try? JSONEncoder().encode(entriesByBook) {
            defaults?.set(entriesData, forKey: "journalWidget.entries")
        }

        // Refresh widgets
        WidgetCenter.shared.reloadAllTimelines()
    }

}



// MARK: - Journal Streak Card

struct JournalStreakCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let journaledToday: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("pencilwrite")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Journal Streak", font: .system(size: 20, weight: .bold))
                    Spacer()

                    Text(journaledToday ? "Written today" : "Not written today")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(journaledToday ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }

                HStack(spacing: 10) {
                    streakBubble(
                        title: currentStreak == 1 ? "Day in a row" : "Days in a row",
                        value: "\(currentStreak)"
                    )

                    streakBubble(
                        title: bestStreak == 1 ? "Best day" : "Best days",
                        value: "\(bestStreak)"
                    )
                }

                
                Text(journaledToday ? "You’ve already journaled today — your streak is safe." : "Write today to keep your streak going.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func streakBubble(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
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

// MARK: - Overview Card

struct JournalOverviewCard: View {
    let entriesThisWeek: Int
    let entriesThisYear: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image("heartsum")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Overview", font: .system(size: 20, weight: .bold))
                }

                HStack(spacing: 10) {
                    overviewBubble(label: "This Week", value: entriesThisWeek)
                    overviewBubble(label: "This Year", value: entriesThisYear)
                }
            }
        }
    }

    @ViewBuilder
    private func overviewBubble(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)

            Text("\(value)")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)

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

// MARK: - Book Card (realistic book rendering)

struct JournalBookCard: View {
    let title: String
    let coverHex: String
    let entryCount: Int
    let lastDate: Date?
    let isPinned: Bool

    private var coverColor: Color { Color(hex: coverHex) }

    var body: some View {
        bookGraphic
            .frame(height: 230)
            .scaleEffect(0.85)
            .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Book Graphic

    private var bookGraphic: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Shadow behind the whole book
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.28))
                    .blur(radius: 14)
                    .offset(x: 10, y: 12)

                // Page block (right side) — gives thickness
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.92), Color.white.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * 0.18, height: h * 0.88)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<14, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.06))
                                    .frame(height: 1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .opacity(0.55)
                    )
                    .offset(x: w * 0.34, y: 0)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 8, y: 8)

                // Cover (slightly narrower so pages peek out)
                ZStack(alignment: .leading) {
                    // Base cover with subtle depth gradient
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    coverColor.opacity(0.92),
                                    coverColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Spine strip
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.35),
                                    Color.black.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.16)
                        .overlay(
                            VStack(spacing: 6) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.10))
                                        .frame(height: 3)
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.leading, 10)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .opacity(0.7)
                        )

                    // Gloss highlight
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .blendMode(.screen)
                        .opacity(0.75)

                    // Cover content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(title)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isPinned {
                                Image("pinfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.white)
                                    .padding(.top, 2)
                            }
                        }

                        Text("\(entryCount) entries")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.88))

                        Spacer(minLength: 0)

                        // Tiny “label plate” near bottom
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 28)
                            .overlay(
                                HStack(spacing: 8) {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.8))
                                    Text(lastDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "New")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                            )
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .frame(width: w * 0.86, height: h)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 14, x: 10, y: 12)
                .rotation3DEffect(.degrees(-10), axis: (x: 0, y: 1, z: 0))
                .offset(x: -w * 0.06)
            }
        }
    }
}

// MARK: - Book Detail View (entries inside the book)

struct JournalBookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @EnvironmentObject private var appState: AppState
    let book: JournalBook
    
    @Query private var entries: [JournalEntry]
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil }, sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    @Query private var prompts: [JournalPrompt]
    
    @State private var showPromptSheet = false
    @State private var showStoredPromptsPopup = false
    @State private var showPromptEditorPopup = false
    @State private var editorEntryTarget: JournalEntry? = nil
    @State private var previewEntryTarget: JournalEntry? = nil
    @State private var navigateToEditorPage = false
    @State private var navigateToPreviewPage = false
    @State private var tagFilter: String? = nil
    @State private var editingStoredPrompt: JournalPrompt? = nil
    @State private var storedPromptDraft: String = ""
    
    // AI prompt overlay state
    @State private var promptText: String = ""
    @State private var promptLoading = false
    @State private var promptError: String?
    
    // Stored prompt feedback state
    @State private var promptShowCopied = false
    @State private var visibleEntryCount: Int = 4
    @State private var visiblePromptCount: Int = 4
    
    init(book: JournalBook) {
        self.book = book
        
        let bookID = book.persistentModelID
        _entries = Query(
            filter: #Predicate<JournalEntry> { entry in
                entry.book?.persistentModelID == bookID &&
                entry.deletedAt == nil
            },
            sort: \JournalEntry.createdAt,
            order: .reverse
        )
        _prompts = Query(
            filter: #Predicate<JournalPrompt> { prompt in
                prompt.book?.persistentModelID == bookID &&
                prompt.deletedAt == nil
            },
            sort: \JournalPrompt.createdAt,
            order: .reverse
        )
    }
    
    private var filteredEntries: [JournalEntry] {
        guard let tag = tagFilter, !tag.isEmpty else { return entries }
        return entries.filter { $0.tags.contains(tag) }
    }

    private var visibleEntries: [JournalEntry] {
        Array(filteredEntries.prefix(visibleEntryCount))
    }

    private var visiblePrompts: [JournalPrompt] {
        Array(prompts.prefix(visiblePromptCount))
    }
    
    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        // Breathing room under the header
                        Spacer().frame(height: 14)
                        
                        if let tag = tagFilter {
                            tagFilterBar(tag)
                        } else {
                            Spacer().frame(height: 6)
                        }
                        
                        entriesList
                            .padding(.top, 10)
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
                
                // Floating "+" adds ENTRY to this book
                FloatingActionButton {
                    editorEntryTarget = nil
                    navigateToEditorPage = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if showStoredPromptsPopup {
                    storedJournalPromptsOverlay
                        .preferredColorScheme(.dark)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(70)
                }
            }
            .overlay {
                if showPromptEditorPopup {
                    storedJournalPromptEditorOverlay
                        .preferredColorScheme(.dark)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(80)
                }
            }
            .navigationDestination(isPresented: $navigateToEditorPage) {
                JournalBlockEditorPage(
                    book: book,
                    existingEntry: editorEntryTarget
                )
            }
            .navigationDestination(isPresented: $navigateToPreviewPage) {
                Group {
                    if let entry = previewEntryTarget {
                        JournalBlockPreviewPage(entry: entry)
                    } else {
                        Color.clear
                            .navigationBarBackButtonHidden(true)
                    }
                }
            }
            
            // MARK: - Journal Prompt Overlay
            if showPromptSheet {
                journalPromptOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPromptSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStoredPromptsPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPromptEditorPopup)
        .onAppear {
            JournalEntryBlockMigration.migrateEntriesIfNeeded(entries, modelContext: modelContext)
        }
        .onChange(of: tagFilter) { _, _ in
            visibleEntryCount = 4
        }
        .onChange(of: prompts) { _, _ in
            visiblePromptCount = 4
        }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: book.coverHex))
                    .frame(width: 42, height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 2) {
                    GradientTitle(text: book.title, font: .system(size: 20, weight: .bold))
                    Text("Entries")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                
                Spacer()
                
                Button {
                    showStoredPromptsPopup = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("bookmfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    showPromptSheet = true
                } label: {
                    Text("Prompt")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LGradients.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 14)
            
            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }
    
    private func tagFilterBar(_ tag: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(LColors.textSecondary)
                
                Text("Filtered by #\(tag)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
            }
            
            Spacer()
            
            Button { withAnimation { tagFilter = nil } } label: {
                Text("Clear")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LColors.glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
        .padding(.horizontal, LSpacing.pageHorizontal)
        .padding(.top, 14).padding(.bottom, 8)
    }
    
    // MARK: - Overview Stats

    private var entriesThisWeek: Int {
        let cal = Calendar.autoupdatingCurrent
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return entries.filter { $0.createdAt >= weekStart }.count
    }

    private var entriesThisYear: Int {
        let cal = Calendar.autoupdatingCurrent
        let year = cal.component(.year, from: Date())
        return entries.filter { cal.component(.year, from: $0.createdAt) == year }.count
    }

    private var entriesList: some View {
        VStack(spacing: 12) {
            if filteredEntries.isEmpty {
                EmptyState(icon: "doc.text", message: "No entries in this book yet.\nTap + to create one.")
                    .padding(.top, 20)
            } else {
                JournalOverviewCard(entriesThisWeek: entriesThisWeek, entriesThisYear: entriesThisYear)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                let allowedEntrySource = allEntries
                    .sorted { $0.createdAt < $1.createdAt }
                    .prefix(50)
                let allowedEntryIds = Set(allowedEntrySource.map { $0.persistentModelID })

                ForEach(visibleEntries, id: \.persistentModelID) { entry in
                    JournalCard(
                        entry: entry,
                        onView: {
                            previewEntryTarget = $0
                            navigateToPreviewPage = true
                        },
                        onTagSelect: { tagFilter = $0 },
                        onMove: { entry, destination in
                            entry.book = destination
                            entry.updatedAt = Date()
                            try? modelContext.save()
                        }
                    )
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .premiumLocked(!limits.hasPremiumAccess && !allowedEntryIds.contains(entry.persistentModelID))
                }

                if filteredEntries.count > visibleEntryCount {
                    LoadMoreButton {
                        visibleEntryCount += 4
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.top, 2)
    }
    
    // MARK: - Stored Journal Prompts Overlay

    private var storedJournalPromptsOverlay: some View {
        ZStack(alignment: .top) {
            LystariaOverlayPopup(
                onClose: {
                    visiblePromptCount = 4
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showStoredPromptsPopup = false
                    }
                },
                width: 420,
                heightRatio: 0.70,
                header: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            GradientTitle(text: "Journal Prompts", font: .system(size: 20, weight: .bold))

                            Text(book.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }

                        Spacer()

                        Button {
                            editingStoredPrompt = nil
                            storedPromptDraft = ""
                            showStoredPromptsPopup = false
                            showPromptEditorPopup = true
                        } label: {
                            Text("Add")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                },
                content: {
                    if prompts.isEmpty {
                        VStack(spacing: 14) {
                            Image("pencilsparkle")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .foregroundStyle(.white)

                            Text("No saved prompts yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Add your first journal prompt to keep inspiration close by.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        ForEach(visiblePrompts, id: \.persistentModelID) { prompt in
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    prompt.isCompleted.toggle()
                                    prompt.updatedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: prompt.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(prompt.isCompleted ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.textSecondary))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 1)

                                Text(prompt.text)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .strikethrough(prompt.isCompleted, color: .white.opacity(0.7))
                                    .opacity(prompt.isCompleted ? 0.72 : 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    copyStoredPrompt(prompt.text)
                                } label: {
                                    Image("copyfill")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .contextMenu {
                                Button {
                                    editingStoredPrompt = prompt
                                    storedPromptDraft = prompt.text
                                    showStoredPromptsPopup = false
                                    showPromptEditorPopup = true
                                } label: {
                                    Text("Edit")
                                }

                                Button(role: .destructive) {
                                    deleteStoredPrompt(prompt)
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }

                        if prompts.count > visiblePromptCount {
                            HStack {
                                Spacer()
                                LoadMoreButton {
                                    visiblePromptCount += 4
                                }
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                },
                footer: {
                    HStack(spacing: 12) {
                        Button {
                            editingStoredPrompt = nil
                            storedPromptDraft = ""
                            showStoredPromptsPopup = false
                            showPromptEditorPopup = true
                        } label: {
                            Text("Add Prompt")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showStoredPromptsPopup = false
                            }
                        } label: {
                            Text("Close")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
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

            if promptShowCopied {
                Text("Copied")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(LGradients.blue)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .padding(.top, 34)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var storedJournalPromptEditorOverlay: some View {
        LystariaOverlayPopup(
            onClose: {
                storedPromptDraft = ""
                editingStoredPrompt = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showPromptEditorPopup = false
                    showStoredPromptsPopup = true
                }
            },
            width: 420,
            heightRatio: 0.62,
            header: {
                HStack {
                    GradientTitle(
                        text: editingStoredPrompt == nil ? "Add Prompt" : "Edit Prompt",
                        font: .system(size: 20, weight: .bold)
                    )

                    Spacer()
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)

                    TextEditor(text: $storedPromptDraft)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
            },
            footer: {
                HStack(spacing: 12) {
                    Button {
                        storedPromptDraft = ""
                        editingStoredPrompt = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showPromptEditorPopup = false
                            showStoredPromptsPopup = true
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveStoredPrompt()
                    } label: {
                        Text(editingStoredPrompt == nil ? "Save Prompt" : "Save Changes")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LGradients.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                }
            }
        )
    }

    private func copyStoredPrompt(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            promptShowCopied = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    promptShowCopied = false
                }
            }
        }
    }

    private func saveStoredPrompt() {
        let trimmed = storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let prompt = editingStoredPrompt {
            prompt.text = trimmed
            prompt.updatedAt = Date()
        } else {
            let prompt = JournalPrompt(text: trimmed, book: book)
            modelContext.insert(prompt)
        }

        try? modelContext.save()

        storedPromptDraft = ""
        editingStoredPrompt = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showPromptEditorPopup = false
            showStoredPromptsPopup = true
        }
    }

    private func deleteStoredPrompt(_ prompt: JournalPrompt) {
        prompt.deletedAt = Date()
        prompt.updatedAt = Date()
        try? modelContext.save()
    }
    
    // MARK: - Journal Prompt Overlay

    private var journalPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showPromptSheet = false
                    }
                }

            VStack(spacing: 20) {
                GradientTitle(
                    text: "Journal Prompt",
                    font: .system(size: 22, weight: .bold)
                )

                if promptLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .padding(.vertical, 12)
                } else if let error = promptError {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else if !promptText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            Text("Prompt")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = promptText
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    promptShowCopied = true
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        promptShowCopied = false
                                    }
                                }
                            } label: {
                                Image("copyfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(promptText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }

                Button {
                    Task { await generatePrompt() }
                } label: {
                    Text("Generate Prompt")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LGradients.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showPromptSheet = false
                    }
                } label: {
                    Text("Close")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                ZStack {
                    LGradients.blue
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    GradientOverlayBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
            )
            .padding(.horizontal, 28)
            .overlay(alignment: .bottom) {
                if promptShowCopied {
                    Text("Copied to Clipboard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func generatePrompt() async {
        do {
            await MainActor.run {
                promptLoading = true
                promptError = nil
            }

            guard let userId = appState.currentAppleUserId,
                  !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(
                    domain: "JournalPromptService",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "You need to be signed in with Apple to generate a prompt."]
                )
            }
            let response = try await JournalPromptService.shared.generatePrompt(userId: userId, modelContext: modelContext)

            await MainActor.run {
                promptText = response.prompt
                promptLoading = false
            }
        } catch {
            await MainActor.run {
                promptLoading = false
                promptError = error.localizedDescription
            }
        }
    }
}
