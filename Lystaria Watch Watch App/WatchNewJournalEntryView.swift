//
//  WatchNewJournalEntryView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import SwiftUI
import SwiftData

struct WatchNewJournalEntryView: View {

    @Query(sort: \JournalBook.createdAt, order: .forward)
    private var books: [JournalBook]

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 10) {

                if books.isEmpty {
                    VStack(spacing: 10) {
                        Text("No Journal Books")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))

                        NavigationLink {
                            WatchNewJournalBookView()
                        } label: {
                            WatchJournalFlowButton(
                                title: "Create Book",
                                iconName: "wavyplus" // CHANGE to your real asset name if needed
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {

                            NavigationLink {
                                WatchNewJournalBookView()
                            } label: {
                                WatchJournalFlowButton(
                                    title: "Create Book",
                                    iconName: "wavyplus" // CHANGE to your real asset name if needed
                                )
                            }
                            .buttonStyle(.plain)

                            ForEach(books) { book in
                                NavigationLink {
                                    WatchJournalEntryComposerView(book: book)
                                } label: {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.white.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                        )
                                        .frame(height: 56)
                                        .overlay(
                                            Text(book.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Select Book")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct WatchNewJournalBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var errorText: String?
    @State private var isSaving = false

    private let titleLimit = 60

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 10) {
                WatchJournalInputCard(
                    label: "Book Title",
                    text: $title,
                    placeholder: "Journal book",
                    axis: .horizontal,
                    lineLimit: 1,
                    limit: titleLimit
                )

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 4)
                } else {
                    Button {
                        saveBook()
                    } label: {
                        Text("Save Book")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 125/255, green: 25/255, blue: 247/255),
                                        Color(red: 3/255, green: 219/255, blue: 252/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.55)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("New Book")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func saveBook() {
        errorText = nil

        guard !trimmedTitle.isEmpty else {
            errorText = "Add a title."
            return
        }

        isSaving = true

        let book = JournalBook(title: String(trimmedTitle.prefix(titleLimit)))
        modelContext.insert(book)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorText = "Unable to save."
            isSaving = false
        }
    }
}


struct WatchJournalFlowButton: View {
    let title: String
    let iconName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 62)
    }
}

struct WatchJournalInputCard: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let axis: Axis
    let lineLimit: Int
    let limit: Int
    var minHeight: CGFloat = 58

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(text.count)/\(limit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .frame(minHeight: minHeight)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                }

                TextField(
                    "",
                    text: limitedBinding,
                    axis: axis
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(lineLimit...)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
            }
        }
    }

    private var limitedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                text = String(newValue.prefix(limit))
            }
        )
    }
}

#Preview {
    NavigationStack {
        WatchNewJournalEntryView()
    }
}
