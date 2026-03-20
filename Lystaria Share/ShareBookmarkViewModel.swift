//
//  ShareBookmarkViewModel.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ShareBookmarkViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var bookmarkDescription: String = ""
    @Published var url: String = ""
    @Published var tagsRaw: String = ""
    @Published var selectedFolder: SharedFolderOption = SharedFolderOption(
        id: "inbox",
        name: "Inbox",
        systemKey: "inbox",
        iconName: "tray.full.fill"
    )
    @Published var availableFolders: [SharedFolderOption] = []
    @Published var errorMessage: String = ""

    func loadFolders() {
        do {
            let folders = try SharedFolderStore.load()
            if folders.isEmpty {
                availableFolders = [
                    SharedFolderOption(
                        id: "inbox",
                        name: "Inbox",
                        systemKey: "inbox",
                        iconName: "tray.full.fill"
                    )
                ]
            } else {
                availableFolders = folders
            }

            if let inbox = availableFolders.first(where: { $0.systemKey == "inbox" }) {
                selectedFolder = inbox
            } else if let first = availableFolders.first {
                selectedFolder = first
            }
        } catch {
            availableFolders = [
                SharedFolderOption(
                    id: "inbox",
                    name: "Inbox",
                    systemKey: "inbox",
                    iconName: "tray.full.fill"
                )
            ]
            selectedFolder = availableFolders[0]
        }
    }

    func populateFromSharedItems(_ items: [NSItemProvider], completion: @escaping () -> Void) {
        if let urlProvider = items.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self.url = url.absoluteString
                    } else if let nsURL = item as? NSURL, let absolute = nsURL.absoluteString {
                        self.url = absolute
                    }
                    completion()
                }
            }
            return
        }

        if let textProvider = items.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }) {
            let type = textProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                ? UTType.plainText.identifier
                : UTType.text.identifier

            textProvider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                DispatchQueue.main.async {
                    if let text = item as? String {
                        self.title = text
                    } else if let nsText = item as? NSString {
                        self.title = nsText as String
                    }
                    completion()
                }
            }
            return
        }

        completion()
    }

    func save() throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = bookmarkDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTags = tagsRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty || !trimmedURL.isEmpty else {
            throw NSError(domain: "ShareBookmarkViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Please provide at least a title or a link."
            ])
        }

        let payload = SharedBookmarkPayload(
            title: trimmedTitle,
            bookmarkDescription: trimmedDescription,
            url: trimmedURL,
            tagsRaw: trimmedTags,
            targetFolderSystemKey: selectedFolder.systemKey,
            targetFolderName: selectedFolder.name,
            sharedAt: Date()
        )

        try SharedBookmarkInbox.save(payload)
    }
}
