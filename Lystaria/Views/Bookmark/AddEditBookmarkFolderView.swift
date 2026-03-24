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

    let folder: BookmarkFolder? // nil = create
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var selectedIconName: String = "folder.fill"
    @State private var iconSearchText: String = ""

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

                        Image(systemName: selectedIconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        label("Folder Icon")

                        Text("Pick an SF Symbol for this folder.")
                            .font(.footnote)
                            .foregroundStyle(LColors.textSecondary)
                    }
                }

                label("Folder Name")

                GlassTextField(
                    placeholder: "Enter folder name",
                    text: $name
                )

                label("Search Icons")

                GlassTextField(
                    placeholder: "Search SF Symbols",
                    text: $iconSearchText
                )

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                        spacing: 12
                    ) {
                        ForEach(filteredIconOptions, id: \.self) { icon in
                            Button {
                                selectedIconName = icon
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    selectedIconName == icon ? LColors.accent : LColors.glassBorder,
                                                    lineWidth: 1
                                                )
                                        )
                                        .frame(height: 56)

                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxHeight: 220)

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
                selectedIconName = folder.iconName.isEmpty ? "folder.fill" : folder.iconName
            } else {
                selectedIconName = "folder.fill"
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
            folder.iconName = selectedIconName
            folder.updatedAt = Date()
        } else {
            let new = BookmarkFolder(
                name: cleaned,
                systemKey: "",
                iconName: selectedIconName,
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

    var filteredIconOptions: [String] {
        let query = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return BookmarkIconLibrary.all }

        return BookmarkIconLibrary.all.filter { icon in
            icon.lowercased().contains(query)
        }
    }
}
