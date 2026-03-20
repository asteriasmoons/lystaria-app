//
//  BookmarksView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BookmarkFolder.createdAt, order: .forward)
    private var folders: [BookmarkFolder]

    @Query(sort: \BookmarkItem.createdAt, order: .reverse)
    private var bookmarks: [BookmarkItem]

    @State private var searchText: String = ""

    @State private var showingAddBookmarkScreen = false
    @State private var showingAddFolderScreen = false
    @State private var editingFolder: BookmarkFolder? = nil

    

    private let recentDays: Int = 7

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    savedReadingCard
                    searchSection
                    folderSection
                }
                .padding(.bottom, 28)
            }

            if showingAddBookmarkScreen {
                AddEditBookmarkView(
                    bookmark: nil,
                    folders: sortedFoldersForStrip,
                    onClose: {
                        showingAddBookmarkScreen = false
                    }
                )
            }

            if showingAddFolderScreen {
                AddEditBookmarkFolderView(
                    folder: nil,
                    onClose: {
                        showingAddFolderScreen = false
                    }
                )
            }

            if let editingFolder {
                AddEditBookmarkFolderView(
                    folder: editingFolder,
                    onClose: {
                        self.editingFolder = nil
                    }
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureInboxExists()
        }
        .onAppear {
        }
    }
}

// MARK: - Sections

private extension BookmarksView {
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GradientTitle(text: "Bookmarks", font: .title2.bold())
                Spacer()

                Button {
                    showingAddBookmarkScreen = true
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

    var savedReadingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        GradientTitle(text: "Saved Reading", size: 30)

                        Text("Save links with notes, folders, tags, and favorites so your reading pile stays organized instead of turning into chaos.")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    LButton(title: "Add Bookmark", icon: "plus", style: .gradient) {
                        showingAddBookmarkScreen = true
                    }

                    LButton(title: "New Folder", icon: "folder.badge.plus", style: .secondary) {
                        showingAddFolderScreen = true
                    }
                }
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    var searchSection: some View {
        GlassCard {
            GlassTextField(
                placeholder: "Search folders",
                text: $searchText
            )
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    var folderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(filteredFolders) { folder in
                GlassCard {
                    HStack(spacing: 14) {
                        Button {
                            editingFolder = folder
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                    .frame(width: 38, height: 38)

                                Image(systemName: folder.systemKey == "inbox"
                                      ? "tray.full.fill"
                                      : (folder.iconName.isEmpty ? "folder.fill" : folder.iconName))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BookmarkFolderDetailView(folder: folder)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folder.name.isEmpty ? "Untitled" : folder.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(folder.systemKey == "inbox"
                                         ? "Your catch-all space for saved links."
                                         : "Open this folder to view and manage its bookmarks.")
                                        .font(.subheadline)
                                        .foregroundStyle(LColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

}

// MARK: - Computed Data

private extension BookmarksView {
    var inboxFolder: BookmarkFolder? {
        folders.first(where: { $0.systemKey == "inbox" })
    }

    var sortedFoldersForStrip: [BookmarkFolder] {
        let sorted = folders.sorted {
            if $0.systemKey == "inbox" && $1.systemKey != "inbox" { return true }
            if $1.systemKey == "inbox" && $0.systemKey != "inbox" { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return sorted
    }

    var filteredFolders: [BookmarkFolder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedFoldersForStrip }

        return sortedFoldersForStrip.filter { folder in
            let name = folder.name.lowercased()
            let systemKey = folder.systemKey.lowercased()
            return name.contains(query.lowercased()) || systemKey.contains(query.lowercased())
        }
    }
}

// MARK: - Actions

private extension BookmarksView {
    func ensureInboxExists() {
        guard inboxFolder == nil else { return }

        let folder = BookmarkFolder(
            name: "Inbox",
            systemKey: "inbox",
            iconName: "tray.full.fill",
            createdAt: Date(),
            updatedAt: Date()
        )
        modelContext.insert(folder)

        do {
            try modelContext.save()
        } catch {
            print("Failed to create Inbox folder: \(error)")
        }
    }
}

// MARK: - Small UI Pieces


// MARK: - Enums

