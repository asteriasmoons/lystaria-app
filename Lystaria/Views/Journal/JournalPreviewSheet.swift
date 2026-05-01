//
// JournalPreviewSheet.swift
//
// Created By Asteria Moon
//

import SwiftUI
import UIKit
import SwiftData

struct JournalPreviewSheet: View {

    let entry: JournalEntry
    let onClose: () -> Void
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void

    // Load attributed text once into state so SwiftData fully faults the
    // Data blob before the viewer renders. Accessing bodyAttributedText
    // directly in the SwiftUI body can return an unfaulted (empty) value.
    @State private var attributedBody: NSAttributedString = NSAttributedString(string: "")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            onClose()
                        }
                    }

                VStack(alignment: .leading, spacing: 18) {
                    // Header
                    HStack(alignment: .top) {
                        GradientTitle(text: entry.title.isEmpty ? "Untitled" : entry.title, font: .title2.bold())
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                onClose()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Tags
                    if !entry.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(tag)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                            }
                        }
                    }

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    GlassRichTextViewer(text: attributedBody)
                                        .frame(maxWidth: .infinity, minHeight: 1, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .scrollBounceBehavior(.basedOnSize)

                    HStack(spacing: 10) {
                        LButton(title: "Edit", icon: "pencil", style: .secondary) {
                            onEdit(entry)
                        }

                        GradientCapsuleButton(title: "Delete", icon: "trashfill") {
                            onDelete(entry)
                        }

                        Spacer()
                    }
                }
                .padding(22)
                .frame(width: min(proxy.size.width - 40, 420), alignment: .topLeading)
                .frame(maxHeight: proxy.size.height * 0.70, alignment: .topLeading)
                .background(
                    ZStack {
                        LystariaBackground()
                        Color.black.opacity(0.28)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            attributedBody = entry.bodyAttributedText
        }
        .onChange(of: entry.bodyAttributedText.string) { _, _ in
            attributedBody = entry.bodyAttributedText
        }
    }
}

#Preview {
    let e = JournalEntry(
        title: "Preview Title",
        bodyAttributedText: NSAttributedString(string: "Full body text here..."),
        tags: ["idea", "note"]
    )
    JournalPreviewSheet(entry: e, onClose: { }, onEdit: { _ in }, onDelete: { _ in })
}
