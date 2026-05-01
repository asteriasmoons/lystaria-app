//
//  JournalBlockPreviewPage.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import SwiftUI
import SwiftData

struct JournalBlockPreviewPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let entry: JournalEntry

    @State private var showDeleteConfirmation = false
    @State private var showEditorPage = false
    @State private var isCompletingAction = false
    @State private var hasPreparedPreview = false
    @State private var mentionedBook: JournalBook? = nil
    @State private var navigateToMentionedBook = false

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Entry title
                    if !entry.title.isEmpty {
                        GradientTitle(text: entry.title, font: .title.bold())
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, entry.tags.isEmpty ? 16 : 10)
                    }

                    // Tags row
                    if !entry.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image("tagheart")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(.white)
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }

                    JournalBlockDisplayView(entry: entry, onMentionTapped: { idString in
                        print("🔥 MENTION TAPPED: \(idString)")
                        let descriptor = FetchDescriptor<JournalBook>(
                            predicate: #Predicate { $0.deletedAt == nil }
                        )
                        let books = (try? modelContext.fetch(descriptor)) ?? []
                        print("🔥 BOOKS FOUND: \(books.map { $0.uuid.uuidString })")
                        if let match = books.first(where: { $0.uuid.uuidString == idString }) {
                            print("🔥 MATCH FOUND: \(match.title)")
                            mentionedBook = match
                            navigateToMentionedBook = true
                        } else {
                            print("🔥 NO MATCH for id: \(idString)")
                        }
                    })
                }
            }
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    guard !isCompletingAction else { return }
                    isCompletingAction = true
                    dismiss()
                }
                .foregroundStyle(.white)
                .disabled(isCompletingAction)
                .opacity(isCompletingAction ? 0.5 : 1)
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Journal Entry")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    guard !isCompletingAction else { return }
                    guard entry.deletedAt == nil else { return }
                    guard entry.book != nil else { return }
                    showEditorPage = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil || entry.book == nil)
                .opacity((isCompletingAction || entry.deletedAt != nil || entry.book == nil) ? 0.5 : 1)

                Button(role: .destructive) {
                    guard !isCompletingAction else { return }
                    guard entry.deletedAt == nil else { return }
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil)
                .opacity((isCompletingAction || entry.deletedAt != nil) ? 0.5 : 1)
            }
        }
        .navigationDestination(isPresented: $showEditorPage) {
            Group {
                if let book = entry.book, entry.deletedAt == nil {
                    JournalBlockEditorPage(
                        book: book,
                        existingEntry: entry
                    )
                } else {
                    Color.clear
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .background {
            NavigationLink(
                destination: Group {
                    if let book = mentionedBook {
                        JournalBookDetailView(book: book)
                            .environmentObject(appState)
                    }
                },
                isActive: $navigateToMentionedBook
            ) { EmptyView() }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive) {
                deleteEntry()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the entry from your journal.")
        }
        .task {
            guard !hasPreparedPreview else { return }
            hasPreparedPreview = true

            if entry.book == nil {
                isCompletingAction = true
                dismiss()
                return
            }

            if entry.deletedAt != nil {
                isCompletingAction = true
                dismiss()
                return
            }

            JournalEntryBlockMigration.migrateIfNeeded(entry: entry)
            entry.ensureStarterBlock()
            entry.normalizeBlockSortOrders()
            try? modelContext.save()
        }
        .onDisappear {
            isCompletingAction = false
        }
    }

    private func deleteEntry() {
        guard !isCompletingAction else { return }
        guard entry.deletedAt == nil else { return }

        isCompletingAction = true
        showDeleteConfirmation = false
        showEditorPage = false

        entry.deletedAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
