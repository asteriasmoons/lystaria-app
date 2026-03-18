//
// JournalEditorSheet.swift
//
// Created by Asteria Moon
//


import SwiftUI
import SwiftData

struct JournalEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    
    // Editing target (optional) and required book
    let entry: JournalEntry?
    let book: JournalBook
    private var entryReloadKey: PersistentIdentifier? {
        entry?.persistentModelID
    }
    var onClose: (() -> Void)? = nil
    
    // Local form state
    @State private var title: String = ""
    @State private var tagsText: String = ""
    @State private var bodyRichText: NSAttributedString = NSAttributedString(string: "")
    
    private var titleTrimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var closeAction: () -> Void {
        onClose ?? {}
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.82,
            header: {
                HStack {
                    GradientTitle(text: entry == nil ? "New Entry" : "Edit Entry", font: .title2.bold())
                    Spacer()
                    Button {
                        closeAction()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassTextField(placeholder: "Entry title", text: $title)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassTextField(placeholder: "e.g. gratitude, focus", text: $tagsText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("BODY")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassRichTextField(placeholder: "Write your thoughts…", text: $bodyRichText, minHeight: 220)
                }
            },
            footer: {
                Button {
                    save()
                } label: {
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
        )
        .id(entryReloadKey)
        .onAppear { load() }
        .onChange(of: entryReloadKey) { _, _ in
            load()
        }
    }

    private func load() {
        guard let e = entry else {
            title = ""
            bodyRichText = NSAttributedString(string: "")
            tagsText = ""
            return
        }

        title = e.title
        tagsText = e.tags.joined(separator: ", ")
        bodyRichText = e.bodyAttributedText.copy() as? NSAttributedString ?? NSAttributedString(string: e.bodyAttributedText.string)
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
            e.updatedAt = Date()
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
            e.updatedAt = Date()
            modelContext.insert(e)
        }

        try? modelContext.save()
        closeAction()
    }
}

private struct JournalEditorSheetPreviewHost: View {
    let container: ModelContainer
    let sampleBook: JournalBook

    var body: some View {
        JournalEditorSheet(entry: nil, book: sampleBook)
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
