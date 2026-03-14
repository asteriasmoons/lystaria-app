// JournalTabView.swift
// Lystaria

import SwiftUI
import SwiftData
import Combine
import Supabase

struct JournalTabView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<JournalBook> { $0.deletedAt == nil }, sort: \JournalBook.createdAt, order: .reverse) private var books: [JournalBook]
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil }, sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry] // for migration + counts

    @State private var showBookEditor = false
    @State private var editingBook: JournalBook? = nil
    // Onboarding for hidden header icons
    @StateObject private var onboarding = OnboardingManager()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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

                // Floating "+" now adds BOOKS
                FloatingActionButton {
                    editingBook = nil
                    showBookEditor = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 96)
            }
            .sheet(isPresented: $showBookEditor) {
                JournalBookEditorSheet(book: editingBook)
                    .preferredColorScheme(.dark)
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
            }
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
                    ForEach(books, id: \.persistentModelID) { book in
                        NavigationLink {
                            JournalBookDetailView(book: book)
                        } label: {
                            JournalBookCard(
                                title: book.title,
                                coverHex: book.coverHex,
                                entryCount: entryCount(for: book),
                                lastDate: lastEntryDate(for: book)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
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

    private var bestJournalStreak: Int {
        let sortedDays = journaledDayStarts.sorted()
        guard !sortedDays.isEmpty else { return 0 }

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

        return best
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
            e.needsSync = true
        }
        book.deletedAt = Date()
        book.needsSync = true
        try? modelContext.save()
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
                e.needsSync = true
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
            e.needsSync = true
        }
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
                    Image("pencilsparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
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

// MARK: - Book Card (realistic book rendering)

struct JournalBookCard: View {
    let title: String
    let coverHex: String
    let entryCount: Int
    let lastDate: Date?

    private var coverColor: Color { Color(hex: coverHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bookGraphic
                .frame(height: 138)

            // Meta only (title is already on the book cover)
            HStack(spacing: 8) {
                Text("\(entryCount) entries")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                Spacer()

                if let lastDate {
                    Text(lastDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LColors.glassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        )
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
                        Text(title)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                            .lineLimit(2)

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
    let book: JournalBook
    
    @Query private var entries: [JournalEntry]
    
    @State private var showEditor = false
    @State private var showPromptSheet = false
    @State private var editingEntry: JournalEntry? = nil
    @State private var viewerEntry: JournalEntry? = nil
    @State private var tagFilter: String? = nil
    
    // Prompt overlay state
    @State private var promptText: String = ""
    @State private var promptLoading = false
    @State private var promptError: String?
    @State private var promptShowCopied = false
    
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
    }
    
    private var filteredEntries: [JournalEntry] {
        guard let tag = tagFilter, !tag.isEmpty else { return entries }
        return entries.filter { $0.tags.contains(tag) }
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
                    editingEntry = nil
                    showEditor = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 96)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditor) {
                JournalEditorSheet(entry: editingEntry, book: book)
                    .preferredColorScheme(.dark)
            }
            
            .sheet(item: $viewerEntry) { entry in
                JournalPreviewSheet(
                    entry: entry,
                    onEdit: { e in
                        viewerEntry = nil
                        editingEntry = e
                        showEditor = true
                    },
                    onDelete: { e in
                        viewerEntry = nil
                        // Soft-delete: set deletedAt so pushJournalEntries syncs
                        // the deletion to Supabase. pullJournalEntries will then
                        // hard-delete the local record after confirming remote deletion.
                        e.deletedAt = Date()
                        e.needsSync = true
                        try? modelContext.save()
                    }
                )
                .preferredColorScheme(.dark)
            }
            
            // MARK: - Journal Prompt Overlay
            if showPromptSheet {
                journalPromptOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPromptSheet)
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
    
    private var entriesList: some View {
        VStack(spacing: 12) {
            if filteredEntries.isEmpty {
                EmptyState(icon: "doc.text", message: "No entries in this book yet.\nTap + to create one.")
                    .padding(.top, 20)
            } else {
                ForEach(filteredEntries, id: \.persistentModelID) { entry in
                    JournalCard(
                        entry: entry,
                        onView: { viewerEntry = $0 },
                        onTagSelect: { tagFilter = $0 }
                    )
                    .padding(.horizontal, LSpacing.pageHorizontal)
                }
            }
        }
        .padding(.top, 2)
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

            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            let response = try await JournalPromptService.shared.generatePrompt(userId: userId)

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

