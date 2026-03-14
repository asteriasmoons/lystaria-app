//
// JournalEditorSheet.swift
//
// Created by Asteria Moon
//


import SwiftUI
import SwiftData

struct JournalEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editing target (optional) and required book
    let entry: JournalEntry?
    let book: JournalBook

    // Local form state
    @State private var title: String = ""
    @State private var tagsText: String = ""
    @State private var bodyRichText: NSAttributedString = NSAttributedString(string: "")

    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    HStack {
                        GradientTitle(text: entry == nil ? "New Entry" : "Edit Entry", font: .title2.bold())
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        GlassTextField(placeholder: "Entry title", text: $title)
                    }

                    // Tags (comma separated)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        GlassTextField(placeholder: "e.g. gratitude, focus", text: $tagsText)
                    }

                    // Body
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BODY")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        GlassRichTextField(placeholder: "Write your thoughts…", text: $bodyRichText, minHeight: 140)
                    }

                    Button { save() } label: {
                        Text(entry == nil ? "Save Entry" : "Save Changes")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(titleTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                            .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                            .shadow(color: titleTrimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(titleTrimmed.isEmpty)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        if let e = entry {
            title = e.title
            bodyRichText = e.bodyAttributedText
            tagsText = e.tags.joined(separator: ", ")
        } else {
            title = ""
            bodyRichText = NSAttributedString(string: "")
            tagsText = ""
        }
    }

    private func save() {
        let cleanedTitle = titleTrimmed
        guard !cleanedTitle.isEmpty else { return }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let e = entry {
            e.title = cleanedTitle
            e.bodyAttributedText = bodyRichText
            e.tags = tags
            e.markDirty()
            if e.book?.persistentModelID != book.persistentModelID {
                e.book = book
            }
        } else {
            let e = JournalEntry(
                title: cleanedTitle,
                bodyAttributedText: bodyRichText,
                tags: tags,
                book: book
            )
            e.markDirty()
            modelContext.insert(e)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct JournalEditorSheetPreviewHost: View {
    let container: ModelContainer
    let sampleBook: JournalBook

    var body: some View {
        ZStack {
            LystariaBackground()
            JournalEditorSheet(entry: nil, book: sampleBook)
        }
        .modelContainer(container)
    }
}

private let journalEditorPreviewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalBook.self, JournalEntry.self, configurations: config)
    let ctx = container.mainContext
    let sampleBook = JournalBook(title: "General Journal", coverHex: "#6A5CFF")
    ctx.insert(sampleBook)
    return container
}()

private let journalEditorPreviewBook: JournalBook = {
    let ctx = journalEditorPreviewContainer.mainContext
    let descriptor = FetchDescriptor<JournalBook>()
    return (try? ctx.fetch(descriptor).first) ?? JournalBook(title: "General Journal", coverHex: "#6A5CFF")
}()

#Preview {
    JournalEditorSheetPreviewHost(
        container: journalEditorPreviewContainer,
        sampleBook: journalEditorPreviewBook
    )
}
