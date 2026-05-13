//
//  DocumentFolderView.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/10/26.
//

//
//  DocumentFolderView.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData

struct DocumentFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: DocumentBook
    let folder: DocumentFolder

    @State private var entries: [DocumentEntry] = []

    @State private var navigateToEditorPage = false
    @State private var navigateToPreviewPage = false

    @State private var editorEntryTarget: DocumentEntry? = nil
    @State private var previewEntryTarget: DocumentEntry? = nil

    @State private var visibleEntryCount = 12
    @State private var searchText = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var filteredEntries: [DocumentEntry] {
        guard isSearching else { return entries }

        let query = trimmedSearchText.lowercased()

        return entries.filter { entry in
            entry.title.lowercased().contains(query) ||
            entry.blockPreviewText.lowercased().contains(query)
        }
    }

    private var iconItem: BookmarkIconItem {
        FolderViewIconHelpers.item(from: folder.iconName)
    }

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        header

                        FolderViewSearchBar(
                            text: $searchText,
                            placeholder: "Search this folder"
                        )
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.top, 14)

                        Spacer()
                            .frame(height: 18)

                        documentGrid
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)

                FloatingActionButton {
                    editorEntryTarget = nil
                    navigateToEditorPage = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            reloadEntries()
        }
        .onChange(of: navigateToEditorPage) { _, isPresented in
            if !isPresented {
                reloadEntries()
            }
        }
        .onChange(of: navigateToPreviewPage) { _, isPresented in
            if !isPresented {
                reloadEntries()
            }
        }
        .navigationDestination(isPresented: $navigateToEditorPage) {
            DocumentBlockEditorPage(
                book: book,
                existingEntry: editorEntryTarget,
                defaultFolder: folder
            )
        }
        .navigationDestination(isPresented: $navigateToPreviewPage) {
            Group {
                if let entry = previewEntryTarget {
                    DocumentBlockPreviewPage(entry: entry)
                } else {
                    Color.clear
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                folderIcon

                VStack(alignment: .leading, spacing: 2) {
                    GradientTitle(
                        text: folder.title,
                        font: .system(size: 20, weight: .bold)
                    )

                    Text(subtitleText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 14)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
        }
    }

    private var subtitleText: String {
        filteredEntries.count == 1
            ? "1 document"
            : "\(filteredEntries.count) documents"
    }

    private var folderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: book.coverHex).opacity(0.92),
                            Color(hex: book.coverHex).opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            FolderViewIconView(
                item: iconItem,
                size: 22,
                color: Color.white
            )
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var documentGrid: some View {
        if entries.isEmpty {
            EmptyState(
                icon: "doc.text",
                message: "No documents in this folder yet.\nTap + to create one."
            )
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

        } else if filteredEntries.isEmpty {
            EmptyState(
                icon: "magnifyingglass",
                message: "No matching documents found."
            )
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                ForEach(
                    Array(filteredEntries.prefix(visibleEntryCount)),
                    id: \.persistentModelID
                ) { entry in

                    DocumentPageCard(
                        entry: entry,
                        bookCoverHex: book.coverHex
                    )
                    .onTapGesture {
                        previewEntryTarget = entry
                        navigateToPreviewPage = true
                    }
                    .contextMenu {
                        Button("Edit") {
                            editorEntryTarget = entry
                            navigateToEditorPage = true
                        }

                        Button("Remove From Folder") {
                            entry.folder = nil
                            entry.updatedAt = Date()

                            try? modelContext.save()

                            reloadEntries()
                        }

                        Button(role: .destructive) {
                            entry.deletedAt = Date()
                            entry.updatedAt = Date()

                            try? modelContext.save()

                            reloadEntries()
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)

            if filteredEntries.count > visibleEntryCount {
                LoadMoreButton {
                    visibleEntryCount += 12
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Data

    private func reloadEntries() {
        let targetFolderID = folder.persistentModelID

        var descriptor = FetchDescriptor<DocumentEntry>(
            predicate: #Predicate<DocumentEntry> { entry in
                entry.deletedAt == nil &&
                entry.isNestedPage == false
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )

        descriptor.fetchLimit = 500

        do {
            let fetchedEntries = try modelContext.fetch(descriptor)

            entries = fetchedEntries.filter { entry in
                entry.folder?.persistentModelID == targetFolderID
            }

            visibleEntryCount = 12

        } catch {
            entries = []

            print("❌ Failed to reload folder entries: \(error.localizedDescription)")
        }
    }
}

// MARK: - Folder View Helpers

private enum FolderViewIconHelpers {
    static let fallback = BookmarkIconItem(name: "folder.fill", source: .system)

    static func storageValue(for item: BookmarkIconItem) -> String {
        "\(item.source.rawValue):\(item.name)"
    }

    static func item(from storage: String) -> BookmarkIconItem {
        let trimmed = storage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if let match = BookmarkCombinedIconLibrary.all.first(where: { storageValue(for: $0) == trimmed }) {
            return match
        }

        if let match = BookmarkCombinedIconLibrary.all.first(where: { $0.name == trimmed }) {
            return match
        }

        if trimmed.hasPrefix("asset:") {
            let name = String(trimmed.dropFirst("asset:".count))
            return BookmarkIconItem(name: name, source: .asset)
        }

        if trimmed.hasPrefix("system:") {
            let name = String(trimmed.dropFirst("system:".count))
            return BookmarkIconItem(name: name, source: .system)
        }

        return fallback
    }
}

private struct FolderViewIconView: View {
    let item: BookmarkIconItem
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            switch item.source {
            case .system:
                Image(systemName: item.name)
                    .font(.system(size: size, weight: .bold))
            case .asset:
                Image(item.name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .foregroundStyle(color)
    }
}

private struct FolderViewSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
