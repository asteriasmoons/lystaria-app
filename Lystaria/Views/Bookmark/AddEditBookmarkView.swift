//
//  AddEditBookmarkView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

struct AddEditBookmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared

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
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTitle.isEmpty, !cleanedLink.isEmpty else { return }

        if let bookmark {
            bookmark.title = cleanedTitle
            bookmark.bookmarkDescription = cleanedDescription
            bookmark.link = cleanedLink
            bookmark.tagsRaw = cleanedTags
            bookmark.folder = selectedFolder
            bookmark.updatedAt = Date()

            do {
                try modelContext.save()
            } catch {
                print("Failed to save bookmark: \(error)")
                return
            }

            Task {
                await fetchMetadataAndApply(to: bookmark, link: cleanedLink)
                await MainActor.run {
                    onClose()
                }
            }
        } else {
            let descriptor = FetchDescriptor<BookmarkItem>()
            let bookmarks = (try? modelContext.fetch(descriptor)) ?? []
            let decision = limits.canCreate(.bookmarksTotal, currentCount: bookmarks.count)
            guard decision.allowed else {
                return
            }

            let new = BookmarkItem(
                title: cleanedTitle,
                bookmarkDescription: cleanedDescription,
                link: cleanedLink,
                tagsRaw: cleanedTags,
                notes: "",
                isFavorite: false,
                iconData: nil,
                thumbnailData: nil,
                createdAt: Date(),
                updatedAt: Date(),
                folder: selectedFolder
            )
            modelContext.insert(new)

            do {
                try modelContext.save()
            } catch {
                print("Failed to save bookmark: \(error)")
                return
            }

            Task {
                await fetchMetadataAndApply(to: new, link: cleanedLink)
                await MainActor.run {
                    onClose()
                }
            }
        }
    }

    @MainActor
    func fetchMetadataAndApply(to bookmark: BookmarkItem, link: String) async {
        guard let url = normalizedURL(from: link) else { return }

        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)

            let fetchedIconData = await loadData(from: metadata.iconProvider)
            let fetchedThumbnailData = await loadData(from: metadata.imageProvider)

            if let fetchedIconData {
                bookmark.iconData = fetchedIconData
            }

            if let fetchedThumbnailData {
                bookmark.thumbnailData = fetchedThumbnailData
            }

            if bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedTitle = metadata.title,
               !fetchedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bookmark.title = fetchedTitle
            }

            bookmark.updatedAt = Date()
            try modelContext.save()
        } catch {
            print("Failed to fetch bookmark metadata: \(error)")
        }
    }

    func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
    }

    func loadData(from itemProvider: NSItemProvider?) async -> Data? {
        guard let itemProvider else { return nil }

        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            let image: UIImage? = await withCheckedContinuation { continuation in
                itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }

            if let image {
                return image.pngData()
            }
        }

        let supportedTypes = [UTType.png.identifier, UTType.jpeg.identifier, UTType.image.identifier]

        for typeIdentifier in supportedTypes {
            if itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                let item: NSSecureCoding? = await withCheckedContinuation { continuation in
                    itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                        continuation.resume(returning: item)
                    }
                }

                if let data = item as? Data {
                    return data
                }

                if let url = item as? URL {
                    return try? Data(contentsOf: url)
                }

                if let nsURL = item as? NSURL, let url = nsURL as URL? {
                    return try? Data(contentsOf: url)
                }
            }
        }

        return nil
    }

    func duplicateWarningMessage(for link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }

        return "" // Keep simple here; your main view already handles full detection
    }
}
