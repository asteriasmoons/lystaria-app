//
//  AddEditBookmarkView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct AddEditBookmarkView: View {
    @Environment(\.modelContext) private var modelContext

    let bookmark: BookmarkItem?   // nil = create mode
    let folders: [BookmarkFolder]
    let onClose: () -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var link: String = ""
    @State private var tags: String = ""
    @State private var selectedFolder: BookmarkFolder? = nil

    @State private var duplicateWarning: String = ""

    var isEditing: Bool {
        bookmark != nil
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 620,
            heightRatio: 0.78
        ) {
            VStack(alignment: .leading, spacing: 6) {
                GradientTitle(text: isEditing ? "Edit Bookmark" : "Add Bookmark", size: 28)

                Text(isEditing
                     ? "Update your saved link, notes, and organization."
                     : "Save a link with context so it stays meaningful later.")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                label("Title")
                GlassTextField(placeholder: "Name this bookmark", text: $title)

                label("Description")
                GlassTextEditor(
                    placeholder: "Add a short description",
                    text: $description,
                    minHeight: 120
                )

                label("Link")
                GlassTextField(
                    placeholder: "https://example.com",
                    text: $link
                )
                .onChange(of: link) { _, newValue in
                    duplicateWarning = duplicateWarningMessage(for: newValue)
                }

                if !duplicateWarning.isEmpty {
                    Text(duplicateWarning)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LColors.warning)
                }

                label("Tags")
                GlassTextField(
                    placeholder: "Comma-separated tags",
                    text: $tags
                )

                label("Folder")
                folderPicker
            }
        } footer: {
            actionRow
        }
        .onAppear {
            loadData()
        }
    }
}

// MARK: - UI

private extension AddEditBookmarkView {
    var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEditing
                     ? "Update your saved link, notes, and organization."
                     : "Save a link with context so it stays meaningful later.")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    var form: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                label("Title")
                GlassTextField(placeholder: "Name this bookmark", text: $title)

                label("Description")
                GlassTextEditor(
                    placeholder: "Add a short description",
                    text: $description,
                    minHeight: 120
                )

                label("Link")
                GlassTextField(
                    placeholder: "https://example.com",
                    text: $link
                )
                .onChange(of: link) { _, newValue in
                    duplicateWarning = duplicateWarningMessage(for: newValue)
                }

                if !duplicateWarning.isEmpty {
                    Text(duplicateWarning)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LColors.warning)
                }

                label("Tags")
                GlassTextField(
                    placeholder: "Comma-separated tags",
                    text: $tags
                )

                label("Folder")
                folderPicker

                actionRow
            }
        }
    }

    var folderPicker: some View {
        Menu {
            ForEach(folders) { folder in
                Button(folder.name.isEmpty ? "Untitled" : folder.name) {
                    selectedFolder = folder
                }
            }
        } label: {
            HStack {
                Text(selectedFolder?.name ?? "Inbox")
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundStyle(LColors.textSecondary)
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var actionRow: some View {
        HStack {
            LButton(title: "Cancel", icon: "xmark", style: .secondary) {
                onClose()
            }

            Spacer()

            LButton(
                title: isEditing ? "Save Changes" : "Save Bookmark",
                icon: "checkmark",
                style: .gradient
            ) {
                save()
            }
        }
    }

    func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }
}

// MARK: - Logic

private extension AddEditBookmarkView {
    func loadData() {
        guard let bookmark else {
            selectedFolder = folders.first(where: { $0.systemKey == "inbox" })
            return
        }

        title = bookmark.title
        description = bookmark.bookmarkDescription
        link = bookmark.link
        tags = bookmark.tagsRaw
        selectedFolder = bookmark.folder
    }

    func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTitle.isEmpty, !cleanedLink.isEmpty else { return }

        if let bookmark {
            bookmark.title = cleanedTitle
            bookmark.bookmarkDescription = description
            bookmark.link = cleanedLink
            bookmark.tagsRaw = tags
            bookmark.folder = selectedFolder
            bookmark.updatedAt = Date()
        } else {
            let new = BookmarkItem(
                title: cleanedTitle,
                bookmarkDescription: description,
                link: cleanedLink,
                tagsRaw: tags,
                notes: "",
                isFavorite: false,
                createdAt: Date(),
                updatedAt: Date(),
                folder: selectedFolder
            )
            modelContext.insert(new)
        }

        do {
            try modelContext.save()
            onClose()
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    func duplicateWarningMessage(for link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }

        return "" // Keep simple here; your main view already handles full detection
    }
}
