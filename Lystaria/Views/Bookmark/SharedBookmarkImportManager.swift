//
//  SharedBookmarkImportManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

enum SharedBookmarkImportManager {
    static func importPendingBookmark(modelContext: ModelContext) {
        do {
            guard let payload = try SharedBookmarkInbox.load() else { return }

            let descriptor = FetchDescriptor<BookmarkFolder>()
            let folders = try modelContext.fetch(descriptor)

            let trimmedSystemKey = payload.targetFolderSystemKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFolderName = payload.targetFolderName.trimmingCharacters(in: .whitespacesAndNewlines)

            let targetFolder: BookmarkFolder
            if !trimmedSystemKey.isEmpty,
               let matchingBySystemKey = folders.first(where: { folder in
                   folder.systemKey == trimmedSystemKey
               }) {
                targetFolder = matchingBySystemKey
            } else if !trimmedFolderName.isEmpty,
                      let matchingByName = folders.first(where: { folder in
                          folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
                              .localizedCaseInsensitiveCompare(trimmedFolderName) == .orderedSame
                      }) {
                targetFolder = matchingByName
            } else if let inbox = folders.first(where: { $0.systemKey == "inbox" }) {
                targetFolder = inbox
            } else {
                let newInbox = BookmarkFolder(
                    name: "Inbox",
                    systemKey: "inbox",
                    iconName: "tray.full.fill",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                modelContext.insert(newInbox)
                targetFolder = newInbox
            }

            let finalTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? payload.url
                : payload.title

            let bookmark = BookmarkItem(
                title: finalTitle,
                bookmarkDescription: payload.bookmarkDescription,
                link: payload.url,
                tagsRaw: payload.tagsRaw,
                notes: "",
                isFavorite: false,
                createdAt: Date(),
                updatedAt: Date(),
                folder: targetFolder
            )

            modelContext.insert(bookmark)
            try modelContext.save()

            Task {
                await fetchMetadataAndApply(to: bookmark, modelContext: modelContext)
            }

            try SharedBookmarkInbox.clear()
        } catch {
            print("Shared bookmark import failed: \(error)")
        }
    }
    

    @MainActor
    static func fetchMetadataAndApply(to bookmark: BookmarkItem, modelContext: ModelContext) async {
        guard let url = normalizedURL(from: bookmark.link) else { return }

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
            try? modelContext.save()
        } catch {
            print("Shared bookmark metadata fetch failed: \(error)")
        }
    }

    static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
    }

    static func loadData(from itemProvider: NSItemProvider?) async -> Data? {
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
}
