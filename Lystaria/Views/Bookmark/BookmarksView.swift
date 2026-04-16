//
//  BookmarksView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared

    @Query(sort: \BookmarkFolder.createdAt, order: .forward)
    private var folders: [BookmarkFolder]

    @Query(sort: \BookmarkItem.createdAt, order: .reverse)
    private var bookmarks: [BookmarkItem]

    @State private var searchText: String = ""

    @State private var showingAddBookmarkScreen = false
    @State private var showingAddFolderScreen = false
    @State private var editingFolder: BookmarkFolder? = nil
    @State private var visibleFolderCount: Int = 5
    @State private var isReorderMode: Bool = false
    @State private var draggedFolderID: PersistentIdentifier? = nil
    @State private var pendingReorderFolder: BookmarkFolder? = nil
    @State private var folderToDelete: BookmarkFolder? = nil
    @State private var showingDeleteFolderDialog: Bool = false

    

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
            visibleFolderCount = 5
            resetReorderStateIfNeeded()
        }
        .confirmationDialog(
            "Delete Folder",
            isPresented: $showingDeleteFolderDialog,
            titleVisibility: .visible
        ) {
            Button("Delete Folder", role: .destructive) {
                if let folderToDelete {
                    deleteFolder(folderToDelete)
                }
            }

            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
        } message: {
            Text("This will delete the folder and move its bookmarks into Inbox.")
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

                if isReorderMode {
                    LButton(title: "Done", icon: "checkmark", style: .secondary) {
                        withAnimation {
                            isReorderMode = false
                            draggedFolderID = nil
                            pendingReorderFolder = nil
                        }
                    }
                }

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
        .onChange(of: searchText) { _, _ in
            visibleFolderCount = 5
        }
    }

    var folderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(visibleFolders.enumerated()), id: \.element.id) { index, folder in
                GlassCard {
                    HStack(spacing: 14) {
                        Button {
                            if !isReorderMode {
                                editingFolder = folder
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                    .frame(width: 38, height: 38)

                                folderIconView(for: folder, size: 15)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isReorderMode)

                        if isReorderMode {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folder.name.isEmpty ? "Untitled" : folder.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(folder.systemKey == "inbox"
                                         ? "Your catch-all space for saved links."
                                         : "Drag to change this folder’s position.")
                                        .font(.subheadline)
                                        .foregroundStyle(LColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onDrag {
                                draggedFolderID = folder.persistentModelID
                                return NSItemProvider(object: String(describing: folder.persistentModelID) as NSString)
                            }
                            .onDrop(of: [.text], delegate: FolderReorderDropDelegate(
                                targetFolder: folder,
                                folders: filteredFolders,
                                draggedFolderID: $draggedFolderID,
                                modelContext: modelContext
                            ))
                        } else {
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
                .premiumLocked(index >= 2 && !limits.hasPremiumAccess)
                .contextMenu {
                    Button {
                        withAnimation {
                            isReorderMode = true
                            pendingReorderFolder = folder
                        }
                    } label: {
                        Label("Reorder", systemImage: "line.3.horizontal")
                    }

                    if folder.systemKey != "inbox" {
                        Button(role: .destructive) {
                            folderToDelete = folder
                            showingDeleteFolderDialog = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if filteredFolders.count > visibleFolderCount {
                HStack {
                    Spacer()

                    LoadMoreButton {
                        withAnimation {
                            visibleFolderCount += 5
                        }
                    }

                    Spacer()
                }
                .padding(.top, 2)
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
        folders.sorted {
            if $0.systemKey == "inbox" && $1.systemKey != "inbox" { return true }
            if $1.systemKey == "inbox" && $0.systemKey != "inbox" { return false }
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var filteredFolders: [BookmarkFolder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.lowercased()
        guard !query.isEmpty else { return sortedFoldersForStrip }

        return sortedFoldersForStrip.filter { folder in
            let name = folder.name.lowercased()
            let systemKey = folder.systemKey.lowercased()
            return name.contains(normalizedQuery) || systemKey.contains(normalizedQuery)
        }
    }

    var visibleFolders: [BookmarkFolder] {
        Array(filteredFolders.prefix(visibleFolderCount))
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
            sortOrder: 0,
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

    func moveFolder(with draggedID: PersistentIdentifier, before targetFolder: BookmarkFolder, in sourceFolders: [BookmarkFolder]) {
        guard let fromIndex = sourceFolders.firstIndex(where: { $0.persistentModelID == draggedID }),
              let toIndex = sourceFolders.firstIndex(where: { $0.persistentModelID == targetFolder.persistentModelID }),
              fromIndex != toIndex else { return }

        var reordered = sourceFolders
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)

        for (index, folder) in reordered.enumerated() {
            folder.sortOrder = folder.systemKey == "inbox" ? 0 : index + 1
            folder.updatedAt = Date()
        }

        do {
            try modelContext.save()
            SharedFolderExportManager.exportFolders(modelContext: modelContext)
        } catch {
            print("Failed to reorder folders: \(error)")
        }
    }

    func deleteFolder(_ folder: BookmarkFolder) {
        guard folder.systemKey != "inbox" else {
            folderToDelete = nil
            showingDeleteFolderDialog = false
            return
        }

        guard let inboxFolder else {
            folderToDelete = nil
            showingDeleteFolderDialog = false
            return
        }

        let bookmarksInFolder = bookmarks.filter { $0.folder?.persistentModelID == folder.persistentModelID }
        for bookmark in bookmarksInFolder {
            bookmark.folder = inboxFolder
            bookmark.updatedAt = Date()
        }

        modelContext.delete(folder)

        do {
            try modelContext.save()
            SharedFolderExportManager.exportFolders(modelContext: modelContext)
        } catch {
            print("Failed to delete folder: \(error)")
        }

        folderToDelete = nil
        showingDeleteFolderDialog = false
    }

    func resetReorderStateIfNeeded() {
        if !isReorderMode {
            draggedFolderID = nil
            pendingReorderFolder = nil
        }

        if !showingDeleteFolderDialog {
            folderToDelete = nil
        }
    }
}

// MARK: - Small UI Pieces

private extension BookmarksView {
    @ViewBuilder
    func folderIconView(for folder: BookmarkFolder, size: CGFloat) -> some View {
        if folder.systemKey == "inbox" {
            Image(systemName: "tray.full.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            switch folder.iconSource {
            case .system:
                Image(systemName: folder.iconName.isEmpty ? "folder.fill" : folder.iconName)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.white)
            case .asset:
                Image(folder.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size + 4, height: size + 4)
                    .foregroundStyle(.white)
            }
        }
    }
}
// MARK: - Enums


private struct FolderReorderDropDelegate: DropDelegate {
    let targetFolder: BookmarkFolder
    let folders: [BookmarkFolder]
    @Binding var draggedFolderID: PersistentIdentifier?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedFolderID,
              draggedFolderID != targetFolder.persistentModelID,
              let fromIndex = folders.firstIndex(where: { $0.persistentModelID == draggedFolderID }),
              let toIndex = folders.firstIndex(where: { $0.persistentModelID == targetFolder.persistentModelID }),
              fromIndex != toIndex else { return }

        var reordered = folders
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)

        for (index, folder) in reordered.enumerated() {
            folder.sortOrder = folder.systemKey == "inbox" ? 0 : index + 1
            folder.updatedAt = Date()
        }

        do {
            try modelContext.save()
            SharedFolderExportManager.exportFolders(modelContext: modelContext)
        } catch {
            print("Failed to update folder order during drag: \(error)")
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedFolderID = nil
        return true
    }
}
