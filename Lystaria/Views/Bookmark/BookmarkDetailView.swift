//
//  BookmarkDetailView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

//
//  BookmarkDetailView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct BookmarkDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bookmark: BookmarkItem
    let availableFolders: [BookmarkFolder]

    @State private var selectedTab: BookmarkDetailTab = .notes
    @State private var notesText: String = ""
    @State private var showDeleteDialog: Bool = false

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    tabPickerCard

                    switch selectedTab {
                    case .notes:
                        notesCard
                    case .preview:
                        previewCard
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                GradientTitle(text: "Bookmark", size: 28)
            }
        }
        .onAppear {
            notesText = bookmark.notes
        }
        .onChange(of: notesText) { _, newValue in
            saveNotes(newValue)
        }
        .lystariaAlertConfirm(
            isPresented: $showDeleteDialog,
            title: "Delete Bookmark",
            message: "Are you sure you want to delete this bookmark? This cannot be undone.",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            deleteBookmark()
        }
    }
}

// MARK: - Main Sections

private extension BookmarkDetailView {
    var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bookmark.title.isEmpty ? "Untitled Bookmark" : bookmark.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        if !bookmark.bookmarkDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bookmark.bookmarkDescription)
                                .font(.subheadline)
                                .foregroundStyle(LColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 8) {
                            if let folderName = folderName, !folderName.isEmpty {
                                LBadge(text: folderName, color: LColors.accent)
                            }

                            if !bookmark.hostDisplay.isEmpty {
                                Text(bookmark.hostDisplay)
                                    .font(.caption)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(bookmark.isFavorite ? .white : Color.gray.opacity(0.95))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if !bookmark.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(bookmark.tags, id: \.self) { tag in
                                TagPill(text: tag)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    labelText("Link")

                    if !bookmark.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(bookmark.link)
                            .font(.footnote)
                            .foregroundStyle(LColors.textSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                actionRow
            }
        }
    }

    var tabPickerCard: some View {
        GlassCard(padding: 14) {
            Picker("Bookmark Tab", selection: $selectedTab) {
                ForEach(BookmarkDetailTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var notesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeaderInline(title: "Notes", icon: "note.text")

                    Spacer()

                    Text(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Empty" : "Saved")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                GlassTextEditor(
                    placeholder: "Add your thoughts, takeaways, quotes, reminders, or anything else you want to remember about this link.",
                    text: $notesText,
                    minHeight: 240
                )
            }
        }
    }

    var previewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeaderInline(title: "Preview", icon: "globe")

                    Spacer()

                    if validPreviewURL != nil {
                        LButton(title: "Open in Browser", icon: "safari", style: .secondary) {
                            openInSystemBrowser()
                        }
                    }
                }

                if let validPreviewURL {
                    BookmarkWebView(url: validPreviewURL)
                        .frame(minHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                } else {
                    invalidLinkState
                }
            }
        }
    }

    var invalidLinkState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(LColors.textSecondary)

            Text("This link can’t be previewed")
                .font(.headline)
                .foregroundStyle(.white)

            Text("The saved link looks incomplete or invalid. You can still open it externally after fixing the URL.")
                .font(.subheadline)
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: LSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }

    var actionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                moveMenu

                LButton(title: "Open in Browser", icon: "safari", style: .secondary) {
                    openInSystemBrowser()
                }

                Spacer()

                LButton(title: "Delete", icon: "trash", style: .danger) {
                    showDeleteDialog = true
                }
            }
        }
    }

    var moveMenu: some View {
        Menu {
            ForEach(availableFolders) { folder in
                Button(folder.name.isEmpty ? "Untitled" : folder.name) {
                    moveToFolder(folder)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption)

                Text("Move to Folder")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Computed

private extension BookmarkDetailView {
    var validPreviewURL: URL? {
        let trimmed = bookmark.link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }

        return URL(string: "https://\(trimmed)")
    }

    var folderName: String? {
        bookmark.folder?.name.isEmpty == false ? bookmark.folder?.name : "Inbox"
    }
}

// MARK: - Actions

private extension BookmarkDetailView {
    func saveNotes(_ newValue: String) {
        bookmark.notes = newValue
        bookmark.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to save bookmark notes: \(error)")
        }
    }

    func toggleFavorite() {
        bookmark.isFavorite.toggle()
        bookmark.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle bookmark favorite: \(error)")
        }
    }

    func moveToFolder(_ folder: BookmarkFolder) {
        bookmark.folder = folder
        bookmark.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to move bookmark to folder: \(error)")
        }
    }

    func deleteBookmark() {
        modelContext.delete(bookmark)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to delete bookmark: \(error)")
        }
    }

    func openInSystemBrowser() {
        guard let url = validPreviewURL else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    func labelText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }
}

// MARK: - Small Supporting Views

private struct SectionHeaderInline: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(LColors.accent)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Tab Enum

enum BookmarkDetailTab: String, CaseIterable, Identifiable {
    case notes
    case preview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notes: return "Notes"
        case .preview: return "Preview"
        }
    }
}

