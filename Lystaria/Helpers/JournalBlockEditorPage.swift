//
//  JournalBlockEditorPage.swift
//  Lystaria
//

import SwiftUI
import SwiftData

struct JournalBlockEditorPage: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Environment(\.dismiss) private var dismiss

    let book: JournalBook
    let existingEntry: JournalEntry?

    @State private var workingEntry: JournalEntry?
    @State private var hasPreparedEntry = false
    @State private var createdNewEntry = false
    @State private var hasFinishedEditorFlow = false
    @State private var isCompletingAction = false
    @State private var pageTitleDraft = ""
    @State private var pageTagsDraft = ""

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            Group {
                if let workingEntry {
                    VStack(spacing: 0) {
                        pageMetaFields(entry: workingEntry)
                        JournalBlockEditorView(entry: workingEntry)
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .navigationTitle(existingEntry == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    closeWithoutSavingGhostEntry()
                }
                .foregroundStyle(.white)
                .disabled(isCompletingAction)
                .opacity(isCompletingAction ? 0.5 : 1)
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(existingEntry == nil ? "New Entry" : "Edit Entry")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text(book.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    saveAndClose()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .disabled(isCompletingAction || workingEntry == nil)
                .opacity((isCompletingAction || workingEntry == nil) ? 0.5 : 1)
            }
        }
        .task {
            guard !hasPreparedEntry else { return }
            hasPreparedEntry = true
            prepareEntry()
        }
        .onDisappear {
            guard !hasFinishedEditorFlow else { return }
            cleanupEmptyNewEntryIfNeeded()
            isCompletingAction = false
        }
    }

    @ViewBuilder
    private func pageMetaFields(entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Entry Title", text: $pageTitleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onChange(of: pageTitleDraft) {
                    entry.title = pageTitleDraft
                    entry.updatedAt = Date()
                    try? modelContext.save()
                }

            TextField("Tags (comma separated)", text: $pageTagsDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onChange(of: pageTagsDraft) {
                    let parsed = pageTagsDraft
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    entry.tags = parsed
                    entry.updatedAt = Date()
                    try? modelContext.save()
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func prepareEntry() {
        guard workingEntry == nil else { return }
        if let existingEntry {
            workingEntry = existingEntry
            if existingEntry.book == nil {
                existingEntry.book = book
            }
            JournalEntryBlockMigration.migrateIfNeeded(entry: existingEntry)
            existingEntry.ensureStarterBlock()
            existingEntry.normalizeBlockSortOrders()
            try? modelContext.save()
            createdNewEntry = false
            pageTitleDraft = existingEntry.title
            pageTagsDraft = existingEntry.tags.joined(separator: ", ")
            return
        }

        // Enforce journal entry limit (50 total for free users)
        let descriptor = FetchDescriptor<JournalEntry>()
        let existingEntries = (try? modelContext.fetch(descriptor)) ?? []
        let decision = limits.canCreate(.journalEntriesTotal, currentCount: existingEntries.count)
        guard decision.allowed else { return }

        let entry = JournalEntry()
        entry.updatedAt = Date()
        entry.book = book
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()

        modelContext.insert(entry)
        createdNewEntry = true
        try? modelContext.save()

        pageTitleDraft = entry.title
        pageTagsDraft = entry.tags.joined(separator: ", ")

        workingEntry = entry
    }

    private func saveAndClose() {
        guard !isCompletingAction else { return }
        isCompletingAction = true

        guard let workingEntry else {
            finishAndDismiss()
            return
        }

        if workingEntry.book == nil {
            workingEntry.book = book
        }

        if createdNewEntry, isEntryEffectivelyEmpty(workingEntry) {
            modelContext.delete(workingEntry)
            self.workingEntry = nil
            try? modelContext.save()
            finishAndDismiss()
            return
        }

        workingEntry.ensureStarterBlock()
        workingEntry.normalizeBlockSortOrders()
        workingEntry.updatedAt = Date()
        try? modelContext.save()

        if createdNewEntry {
            let journalEntryId = "\(workingEntry.persistentModelID)"
            _ = try? SelfCarePointsManager.awardJournalEntry(
                in: modelContext,
                journalEntryId: journalEntryId,
                title: workingEntry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Journal Entry"
                    : workingEntry.title,
                createdAt: workingEntry.createdAt
            )
        }

        finishAndDismiss()
    }

    private func closeWithoutSavingGhostEntry() {
        guard !isCompletingAction else { return }
        isCompletingAction = true

        cleanupEmptyNewEntryIfNeeded()
        finishAndDismiss()
    }

    private func cleanupEmptyNewEntryIfNeeded() {
        guard createdNewEntry, let workingEntry else { return }
        guard isEntryEffectivelyEmpty(workingEntry) else { return }

        modelContext.delete(workingEntry)
        self.workingEntry = nil
        try? modelContext.save()
    }

    private func finishAndDismiss() {
        hasFinishedEditorFlow = true
        isCompletingAction = false
        dismiss()
    }

    private func isEntryEffectivelyEmpty(_ entry: JournalEntry) -> Bool {
        let hasTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTags = !entry.tags.isEmpty

        let meaningfulBlocks = (entry.blocks ?? []).filter { block in
            switch block.type {
            case .divider:
                return false

            case .callout:
                let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty

            case .code, .paragraph, .heading1, .heading2, .heading3, .heading4, .blockquote, .toggle, .bulletedList, .numberedList:
                let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty

            case .image:
                return block.imageData != nil
            }
        }

        return !hasTitle && !hasTags && meaningfulBlocks.isEmpty
    }
}
