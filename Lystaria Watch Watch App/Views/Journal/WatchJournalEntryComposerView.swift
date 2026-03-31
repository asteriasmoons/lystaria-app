//
//  WatchJournalEntryComposerView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import SwiftUI
import SwiftData

struct WatchJournalEntryComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: JournalBook

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var errorText: String?
    @State private var isSaving = false

    private let titleLimit = 60
    private let bodyLimit = 500

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedBody.isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .frame(height: 42)
                        .overlay(
                            Text(book.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                        )

                    WatchJournalInputCard(
                        label: "Title",
                        text: $title,
                        placeholder: "Entry title",
                        axis: .horizontal,
                        lineLimit: 1,
                        limit: titleLimit
                    )

                    WatchJournalInputCard(
                        label: "Body",
                        text: $bodyText,
                        placeholder: "Write here",
                        axis: .vertical,
                        lineLimit: 5,
                        limit: bodyLimit,
                        minHeight: 92
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
                            saveEntry()
                        } label: {
                            Text("Save Entry")
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
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("New Entry")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func saveEntry() {
        errorText = nil

        guard !trimmedTitle.isEmpty else {
            errorText = "Add a title."
            return
        }

        guard !trimmedBody.isEmpty else {
            errorText = "Write something first."
            return
        }

        isSaving = true

        let entry = JournalEntry(
            title: String(trimmedTitle.prefix(titleLimit))
        )
        entry.body = String(trimmedBody.prefix(bodyLimit))

        // CHANGE THIS LINE IF YOUR RELATIONSHIP PROPERTY HAS A DIFFERENT NAME
        entry.book = book

        modelContext.insert(entry)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorText = "Unable to save."
            isSaving = false
        }
    }
}
