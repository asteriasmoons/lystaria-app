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

    let entry: JournalEntry

    @State private var showDeleteConfirmation = false
    @State private var showEditorPage = false
    @State private var isCompletingAction = false
    @State private var hasPreparedPreview = false

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            JournalBlockDisplayView(entry: entry)
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
