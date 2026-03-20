//
//  BookmarkCard.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import SwiftData

struct BookmarkCard: View {
    let bookmark: BookmarkItem
    let folderName: String
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void
    let onMoveToFolder: (BookmarkFolder) -> Void
    let onDelete: () -> Void
    let availableFolders: [BookmarkFolder]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                topRow
                middleContent
                bottomRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: LSpacing.cardRadius))
        .onTapGesture {
            onOpen()
        }
        .contentShape(RoundedRectangle(cornerRadius: LSpacing.cardRadius))
        .onTapGesture {
            onOpen()
        }
    }
}

// MARK: - UI

private extension BookmarkCard {
    var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(bookmark.title.isEmpty ? "Untitled Bookmark" : bookmark.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if !folderName.isEmpty {
                        LBadge(text: folderName, color: LColors.accent)
                    }

                    if !bookmark.hostDisplay.isEmpty {
                        Text(bookmark.hostDisplay)
                            .font(.caption)
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                onToggleFavorite()
            } label: {
                Image("starfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white.opacity(bookmark.isFavorite ? 1 : 0.4))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onTapGesture { }
        }
    }

    var middleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !bookmark.bookmarkDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bookmark.bookmarkDescription)
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !bookmark.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bookmark.tags, id: \.self) { tag in
                            TagPill(text: tag)
                        }
                    }
                }
            }

            if !bookmark.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(bookmark.notes)
                        .font(.footnote)
                        .foregroundStyle(LColors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var bottomRow: some View {
        HStack(spacing: 10) {
            if !bookmark.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bookmark.link)
                    .font(.caption)
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            moveMenu

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    var moveMenu: some View {
        Menu {
            ForEach(availableFolders) { folder in
                Button(folder.name.isEmpty ? "Untitled" : folder.name) {
                    onMoveToFolder(folder)
                }
            }
        } label: {
            Image(systemName: "folder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(
                    Circle()
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
