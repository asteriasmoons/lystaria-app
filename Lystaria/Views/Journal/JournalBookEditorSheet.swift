//
//  JournalBookEditorSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/3/26.
//

import SwiftUI
import SwiftData

struct JournalBookEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: JournalBook?

    @State private var title: String = ""
    @State private var coverColor: Color = Color(hex: "#6A5CFF")

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        GradientTitle(text: book != nil ? "Edit Book" : "New Book", font: .title2.bold())
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        LystariaTextField(placeholder: "Book title", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("COVER COLOR")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        GlassCard {
                            HStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(coverColor)
                                    .frame(width: 48, height: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))

                                ColorPicker("Choose color", selection: $coverColor, supportsOpacity: false)
                                    .foregroundStyle(LColors.textPrimary)

                                Spacer()
                            }
                        }
                    }

                    Button { saveBook() } label: {
                        Text(book != nil ? "Save Changes" : "Create Book")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(title.trimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                            .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                            .shadow(color: title.trimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(title.trimmed.isEmpty)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if let book {
                title = book.title
                coverColor = Color(hex: book.coverHex)
            }
        }
    }

    private func saveBook() {
        let t = title.trimmed
        guard !t.isEmpty else { return }

        let hex = coverColor.toHex() ?? "#6A5CFF"

        if let book {
            book.title = t
            book.coverHex = hex
            book.markDirty()
        } else {
            let newBook = JournalBook(title: t, coverHex: hex)
            newBook.markDirty()
            modelContext.insert(newBook)
        }

        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalBook.self, configurations: config)

    // Seed a sample book
    let ctx = container.mainContext
    let sampleBook = JournalBook(title: "General Journal", coverHex: "#6A5CFF")
    ctx.insert(sampleBook)

    return ZStack {
        LystariaBackground()
        JournalBookEditorSheet(book: sampleBook)
    }
    .modelContainer(container)
}
