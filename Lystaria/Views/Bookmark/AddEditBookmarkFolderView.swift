//
//  AddEditBookmarkFolderView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct AddEditBookmarkFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared

    let folder: BookmarkFolder? // nil = create
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var selectedIcon: BookmarkIconItem? = BookmarkIconItem(name: "folder.fill", source: .system)

    var isEditing: Bool {
        folder != nil
    }

    var isInbox: Bool {
        folder?.systemKey == "inbox"
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 520,
            heightRatio: 0.70
        ) {
            VStack(alignment: .leading, spacing: 6) {
                GradientTitle(
                    text: isEditing ? "Edit Folder" : "New Folder",
                    size: 28
                )

                Text("Organize your saved links into intentional spaces.")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 46, height: 46)

                        Group {
                            switch selectedIcon?.source {
                            case .system, .none:
                                Image(systemName: selectedIcon?.name ?? "folder.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            case .asset:
                                Image(selectedIcon?.name ?? "folder.fill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        label("Folder Icon")

                        Text("Pick an icon for this folder.")
                            .font(.footnote)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                label("Folder Name")

                GlassTextField(
                    placeholder: "Enter folder name",
                    text: $name
                )

                label("Choose Icon")

                BookmarkAssetAndSymbolPicker(
                    selectedIcon: $selectedIcon,
                    icons: BookmarkCombinedIconLibrary.all
                )
                .frame(maxHeight: 280)

                if isInbox {
                    Text("The Inbox folder cannot be renamed.")
                        .font(.footnote)
                        .foregroundStyle(LColors.warning)
                }
            }
        } footer: {
            actionRow
        }
        .onAppear {
            if let folder {
                name = folder.name
                selectedIcon = BookmarkIconItem(
                    name: folder.iconName.isEmpty ? "folder.fill" : folder.iconName,
                    source: folder.iconSource
                )
            } else {
                selectedIcon = BookmarkIconItem(name: "folder.fill", source: .system)
            }
        }
    }
}

// MARK: - UI

private extension AddEditBookmarkFolderView {
    var actionRow: some View {
        HStack {
            LButton(title: "Cancel", icon: "xmark", style: .secondary) {
                onClose()
            }

            Spacer()

            LButton(
                title: isEditing ? "Save" : "Create",
                icon: "checkmark",
                style: .gradient
            ) {
                save()
            }
            .opacity(isInbox ? 0.5 : 1)
            .disabled(isInbox)
        }
    }

    func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }
}

// MARK: - Logic

private extension AddEditBookmarkFolderView {
    func save() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        if let folder {
            guard folder.systemKey != "inbox" else { return }

            folder.name = cleaned
            folder.iconName = selectedIcon?.name ?? "folder.fill"
            folder.iconSource = selectedIcon?.source ?? .system
            folder.updatedAt = Date()
        } else {
            // Enforce free folder limit (exclude inbox)
            let descriptor = FetchDescriptor<BookmarkFolder>()
            let folders = (try? modelContext.fetch(descriptor)) ?? []
            let customFolderCount = folders.filter { $0.systemKey != "inbox" }.count

            let decision = limits.canCreate(.bookmarkFoldersTotal, currentCount: customFolderCount)
            guard decision.allowed else {
                return
            }

            let new = BookmarkFolder(
                name: cleaned,
                systemKey: "",
                iconName: selectedIcon?.name ?? "folder.fill",
                iconSourceRaw: selectedIcon?.source.rawValue ?? BookmarkIconSource.system.rawValue,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(new)
        }

        do {
            try modelContext.save()
            SharedFolderExportManager.exportFolders(modelContext: modelContext)
            onClose()
        } catch {
            print("Failed to save folder: \(error)")
        }
    }

}
