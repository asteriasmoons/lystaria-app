//
//  SharedBookmarkImportManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

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
            try SharedBookmarkInbox.clear()
        } catch {
            print("Shared bookmark import failed: \(error)")
        }
    }
}
