//
//  ShareBookmarkViewModel.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Combine
import Foundation
import LinkPresentation
import UIKit
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

    @Published var previewIconData: Data? = nil
    @Published var previewThumbnailData: Data? = nil

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
        Task {
            var detectedURLString: String?
            var detectedText: String?

            for provider in items {
                if detectedURLString == nil,
                   let urlString = await extractURLString(from: provider) {
                    detectedURLString = urlString
                }

                if detectedText == nil,
                   let text = await extractText(from: provider) {
                    detectedText = text
                }

                if detectedURLString != nil && detectedText != nil {
                    break
                }
            }

            await MainActor.run {
                let cleanedURL = detectedURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let cleanedText = detectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if !cleanedURL.isEmpty {
                    self.url = cleanedURL
                }

                if !cleanedText.isEmpty {
                    if self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if self.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           looksLikeURL(cleanedText) {
                            self.url = cleanedText
                        } else if !looksLikeURL(cleanedText) {
                            self.title = cleanedText
                        }
                    } else if self.bookmarkDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !looksLikeURL(cleanedText) {
                        self.bookmarkDescription = cleanedText
                    }
                }

                if self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let fallbackTitle = fallbackTitle(from: self.url),
                   !fallbackTitle.isEmpty {
                    self.title = fallbackTitle
                }

                let resolvedURL = self.url
                completion()

                if !resolvedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                        await self.fetchPreviewMetadata(from: resolvedURL)
                    }
                }
            }
        }
    }

    private func fetchPreviewMetadata(from rawURL: String) async {
        guard let url = normalizedURL(from: rawURL) else { return }

        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)

            let iconData = await loadData(from: metadata.iconProvider)
            let thumbnailData = await loadData(from: metadata.imageProvider)

            await MainActor.run {
                if let iconData {
                    self.previewIconData = iconData
                }

                if let thumbnailData {
                    self.previewThumbnailData = thumbnailData
                }

                if self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let fetchedTitle = metadata.title,
                   !fetchedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.title = fetchedTitle
                }
            }
        } catch {
            print("Failed to fetch share preview metadata: \(error)")
        }
    }

    private func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
    }

    private func loadData(from itemProvider: NSItemProvider?) async -> Data? {
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

        for typeIdentifier in supportedTypes where itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
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

        return nil
    }

    private func extractURLString(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else {
            return nil
        }

        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil)

            if let url = item as? URL {
                return url.absoluteString
            }

            if let nsURL = item as? NSURL, let absolute = nsURL.absoluteString {
                return absolute
            }

            if let text = item as? String, looksLikeURL(text) {
                return text
            }

            if let nsText = item as? NSString {
                let text = nsText as String
                return looksLikeURL(text) ? text : nil
            }
        } catch {
            print("Failed to extract shared URL: \(error)")
        }

        return nil
    }

    private func extractText(from provider: NSItemProvider) async -> String? {
        let supportedTypes = [UTType.plainText.identifier, UTType.text.identifier]

        for typeIdentifier in supportedTypes where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            do {
                let item = try await provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil)

                if let text = item as? String {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }

                if let nsText = item as? NSString {
                    let cleaned = (nsText as String).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            } catch {
                print("Failed to extract shared text: \(error)")
            }
        }

        return nil
    }

    private func looksLikeURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let url = URL(string: trimmed), url.scheme != nil {
            return true
        }

        return trimmed.contains(".") && !trimmed.contains(" ")
    }

    private func fallbackTitle(from rawURL: String) -> String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized: String
        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            normalized = trimmed
        } else {
            normalized = "https://\(trimmed)"
        }

        guard let url = URL(string: normalized) else { return nil }

        if let host = url.host, !host.isEmpty {
            return host.replacingOccurrences(of: "www.", with: "")
        }

        return url.absoluteString
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
