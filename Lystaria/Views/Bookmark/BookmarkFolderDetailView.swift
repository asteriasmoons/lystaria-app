//
//  BookmarkFolderDetailView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct BookmarkFolderDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let folder: BookmarkFolder

    @Query(sort: \BookmarkItem.createdAt, order: .reverse)
    private var bookmarks: [BookmarkItem]

    @Query(sort: \BookmarkFolder.createdAt, order: .forward)
    private var folders: [BookmarkFolder]

    @State private var searchText: String = ""
    @State private var selectedFilter: BookmarkQuickFilter = .all
    @State private var selectedSort: BookmarkSortOption = .newest

    @State private var selectedBookmark: BookmarkItem? = nil
    @State private var showAddBookmarkPopup: Bool = false

    @State private var bookmarkTitle: String = ""
    @State private var bookmarkDescription: String = ""
    @State private var bookmarkLink: String = ""
    @State private var bookmarkTags: String = ""
    @State private var duplicateWarningText: String = ""

    @State private var bookmarkToDelete: BookmarkItem? = nil
    @State private var showDeleteDialog: Bool = false

    private let recentDays: Int = 7

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    folderInfoCard
                    controlSection
                    bookmarksSection
                }
                .padding(.bottom, 28)
            }

            if showAddBookmarkPopup {
                addBookmarkPopup
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBookmark) { bookmark in
            BookmarkDetailView(
                bookmark: bookmark,
                availableFolders: sortedFoldersForMoves
            )
        }
        .lystariaAlertConfirm(
            isPresented: $showDeleteDialog,
            title: "Delete Bookmark",
            message: "Are you sure you want to delete this bookmark? This cannot be undone.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let bookmarkToDelete {
                deleteBookmark(bookmarkToDelete)
            }
        }
    }
}

// MARK: - Sections

private extension BookmarkFolderDetailView {
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Circle().stroke(LColors.glassBorder, lineWidth: 1)
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: folder.systemKey == "inbox"
                          ? "tray.full.fill"
                          : (folder.iconName.isEmpty ? "folder.fill" : folder.iconName))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                GradientTitle(
                    text: folder.name.isEmpty ? "Untitled Folder" : folder.name,
                    font: .title2.bold()
                )
                Spacer()

                Button {
                    resetAddBookmarkForm()
                    showAddBookmarkPopup = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 6)
        }
    }

    var folderInfoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 42, height: 42)

                        Image(systemName: folder.systemKey == "inbox"
                              ? "tray.full.fill"
                              : (folder.iconName.isEmpty ? "folder.fill" : folder.iconName))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        GradientTitle(
                            text: folder.name.isEmpty ? "Untitled Folder" : folder.name,
                            size: 30
                        )

                        Text(folderDescriptionText)
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    LButton(title: "Add Bookmark", icon: "plus", style: .gradient) {
                        resetAddBookmarkForm()
                        showAddBookmarkPopup = true
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    var controlSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                GlassTextField(
                    placeholder: "Search title, description, tags, notes, or link",
                    text: $searchText
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(BookmarkQuickFilter.allCases) { filter in
                            filterChip(
                                title: filter.label,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                }

                Menu {
                    ForEach(BookmarkSortOption.allCases) { option in
                        Button(option.label) {
                            selectedSort = option
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSort.label)
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredAndSortedBookmarks.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredAndSortedBookmarks) { bookmark in
                        BookmarkCard(
                            bookmark: bookmark,
                            folderName: folder.name.isEmpty ? "Untitled Folder" : folder.name,
                            onToggleFavorite: {
                                toggleFavorite(for: bookmark)
                            },
                            onOpen: {
                                selectedBookmark = bookmark
                            },
                            onMoveToFolder: { targetFolder in
                                move(bookmark: bookmark, to: targetFolder)
                            },
                            onDelete: {
                                bookmarkToDelete = bookmark
                                showDeleteDialog = true
                            },
                            availableFolders: sortedFoldersForMoves
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    var emptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                GradientTitle(
                    text: folder.name.isEmpty ? "Untitled Folder" : folder.name,
                    size: 28
                )

                Image("bookmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white.opacity(0.85))

                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    LButton(title: "Add Bookmark", icon: "plus", style: .gradient) {
                        resetAddBookmarkForm()
                        showAddBookmarkPopup = true
                    }

                    if selectedFilter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LButton(title: "Show All", icon: "tray.full", style: .secondary) {
                            selectedFilter = .all
                            searchText = ""
                        }
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var addBookmarkPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                showAddBookmarkPopup = false
            },
            width: 620,
            heightRatio: 0.78
        ) {
            VStack(alignment: .leading, spacing: 6) {
                GradientTitle(text: "Add Bookmark", size: 28)

                Text("Save a link directly into \(folder.name.isEmpty ? "this folder" : folder.name).")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                popupLabel("Title")
                GlassTextField(
                    placeholder: "Name this bookmark",
                    text: $bookmarkTitle
                )

                popupLabel("Description")
                GlassTextEditor(
                    placeholder: "Add a short description",
                    text: $bookmarkDescription,
                    minHeight: 120
                )

                popupLabel("Link")
                GlassTextField(
                    placeholder: "https://example.com",
                    text: $bookmarkLink
                )
                .onChange(of: bookmarkLink) { _, newValue in
                    duplicateWarningText = duplicateWarningMessage(for: newValue)
                }

                if !duplicateWarningText.isEmpty {
                    Text(duplicateWarningText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LColors.warning)
                }

                popupLabel("Tags")
                GlassTextField(
                    placeholder: "Comma-separated tags",
                    text: $bookmarkTags
                )
            }
        } footer: {
            HStack {
                LButton(title: "Cancel", icon: "xmark", style: .secondary) {
                    showAddBookmarkPopup = false
                }

                Spacer()

                LButton(title: "Save Bookmark", icon: "checkmark", style: .gradient) {
                    saveBookmarkToCurrentFolder()
                }
            }
        }
    }
}

// MARK: - Computed Data

private extension BookmarkFolderDetailView {
    var sortedFoldersForMoves: [BookmarkFolder] {
        folders.sorted {
            if $0.systemKey == "inbox" && $1.systemKey != "inbox" { return true }
            if $1.systemKey == "inbox" && $0.systemKey != "inbox" { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var folderBookmarks: [BookmarkItem] {
        bookmarks.filter { bookmark in
            bookmark.folder?.persistentModelID == folder.persistentModelID
        }
    }

    var filteredAndSortedBookmarks: [BookmarkItem] {
        let now = Date()
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -recentDays, to: now) ?? now

        let base = folderBookmarks.filter { bookmark in
            let matchesQuickFilter: Bool = {
                switch selectedFilter {
                case .all:
                    return true
                case .favorites:
                    return bookmark.isFavorite
                case .recent:
                    return bookmark.createdAt >= recentCutoff
                }
            }()

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch: Bool = {
                guard !query.isEmpty else { return true }
                let haystack = [
                    bookmark.title,
                    bookmark.bookmarkDescription,
                    bookmark.tagsRaw,
                    bookmark.notes,
                    bookmark.link
                ]
                .joined(separator: " ")
                .lowercased()

                return haystack.contains(query.lowercased())
            }()

            return matchesQuickFilter && matchesSearch
        }

        switch selectedSort {
        case .newest:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return base.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return base.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    var folderDescriptionText: String {
        if folder.systemKey == "inbox" {
            return "This is your catch-all space for saved links before you sort them somewhere more intentional."
        } else {
            return "Everything saved in this folder lives here, with notes, tags, favorites, and preview support."
        }
    }

    var emptyStateTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No bookmarks matched your search"
        }

        switch selectedFilter {
        case .favorites:
            return "No favorites in this folder"
        case .recent:
            return "No recent bookmarks in this folder"
        case .all:
            return "This folder is empty"
        }
    }

    var emptyStateMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try a different keyword, clear the search, or switch your filter."
        }

        switch selectedFilter {
        case .favorites:
            return "Tap the star on any bookmark card in this folder to build a favorites pile here."
        case .recent:
            return "Anything added to this folder within the last \(recentDays) days will show up here."
        case .all:
            return "Save a bookmark and it will appear in this folder immediately."
        }
    }
}

// MARK: - Actions

private extension BookmarkFolderDetailView {
    func resetAddBookmarkForm() {
        bookmarkTitle = ""
        bookmarkDescription = ""
        bookmarkLink = ""
        bookmarkTags = ""
        duplicateWarningText = ""
    }

    func saveBookmarkToCurrentFolder() {
        let cleanedTitle = bookmarkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLink = bookmarkLink.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTitle.isEmpty, !cleanedLink.isEmpty else { return }

        let item = BookmarkItem(
            title: cleanedTitle,
            bookmarkDescription: bookmarkDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            link: cleanedLink,
            tagsRaw: bookmarkTags,
            notes: "",
            isFavorite: false,
            createdAt: Date(),
            updatedAt: Date(),
            folder: folder
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            showAddBookmarkPopup = false
            resetAddBookmarkForm()
        } catch {
            print("Failed to save bookmark in folder: \(error)")
        }
    }

    func toggleFavorite(for bookmark: BookmarkItem) {
        bookmark.isFavorite.toggle()
        bookmark.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }

    func move(bookmark: BookmarkItem, to targetFolder: BookmarkFolder) {
        bookmark.folder = targetFolder
        bookmark.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to move bookmark: \(error)")
        }
    }

    func deleteBookmark(_ bookmark: BookmarkItem) {
        modelContext.delete(bookmark)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete bookmark: \(error)")
        }

        bookmarkToDelete = nil
    }

    func duplicateWarningMessage(for link: String) -> String {
        let normalizedCandidate = normalizedURLString(link)
        guard !normalizedCandidate.isEmpty else { return "" }

        let duplicate = bookmarks.first {
            normalizedURLString($0.link) == normalizedCandidate
        }

        if let duplicate {
            let title = duplicate.title.isEmpty ? "Untitled bookmark" : duplicate.title
            return "This link is already saved as “\(title)”. You can still save it again if you want."
        }

        return ""
    }

    func normalizedURLString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        } else {
            return "https://\(trimmed)"
        }
    }
}

// MARK: - Small UI Pieces

private extension BookmarkFolderDetailView {
    func popupLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }

    func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(LGradients.blue)
                        : AnyShapeStyle(Color.white.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? .clear : LColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Filter + Sort Enums

enum BookmarkQuickFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .favorites:
            return "Favorites"
        case .recent:
            return "Recent"
        }
    }
}

enum BookmarkSortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case titleAZ

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest:
            return "Newest First"
        case .oldest:
            return "Oldest First"
        case .titleAZ:
            return "Title A–Z"
        }
    }
}
