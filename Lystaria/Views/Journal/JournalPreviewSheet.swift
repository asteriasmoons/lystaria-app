import SwiftUI
import UIKit
import SwiftData

struct JournalPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entry: JournalEntry
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void

    // Load attributed text once into state so SwiftData fully faults the
    // Data blob before the viewer renders. Accessing bodyAttributedText
    // directly in the SwiftUI body can return an unfaulted (empty) value.
    @State private var attributedBody: NSAttributedString = NSAttributedString(string: "")

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        GradientTitle(text: entry.title.isEmpty ? "Untitled" : entry.title, font: .title2.bold())
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

                    // Tags
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entry.tags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Image(systemName: "tag.fill").font(.system(size: 10, weight: .bold))
                                        Text(tag)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                }
                            }
                        }
                    }

                    // Body
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            GlassRichTextViewer(text: attributedBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Actions
                    HStack(spacing: 10) {
                        LButton(title: "Edit", icon: "pencil", style: .secondary) {
                            onEdit(entry)
                        }
                        LButton(title: "Delete", icon: "trash", style: .gradient) {
                            onDelete(entry)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
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
    JournalPreviewSheet(entry: e, onEdit: { _ in }, onDelete: { _ in })
}
