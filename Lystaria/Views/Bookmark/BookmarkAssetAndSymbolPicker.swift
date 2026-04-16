//
//  BookmarkAssetAndSymbolPicker.swift
//  Lystaria
//

import SwiftUI

struct BookmarkAssetAndSymbolPicker: View {
    @Binding var selectedIcon: BookmarkIconItem?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    let icons: [BookmarkIconItem]

    private var filteredIcons: [BookmarkIconItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return icons
        }

        return icons.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 48, maximum: 60), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 12) {
            GlassTextField(
                placeholder: "Search icons",
                text: $searchText
            )
            .focused($isSearchFocused)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredIcons) { icon in
                        Button {
                            selectedIcon = icon
                            isSearchFocused = false
                        } label: {
                            iconView(for: icon)
                                .frame(width: 24, height: 24)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedIcon == icon
                                            ? Color.white.opacity(0.9)
                                            : Color.white.opacity(0.12),
                                            lineWidth: selectedIcon == icon ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .onTapGesture {
                isSearchFocused = false
            }
        }
    }

    @ViewBuilder
    private func iconView(for icon: BookmarkIconItem) -> some View {
        switch icon.source {
        case .system:
            Image(systemName: icon.name)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

        case .asset:
            Image(icon.name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        }
    }
}
