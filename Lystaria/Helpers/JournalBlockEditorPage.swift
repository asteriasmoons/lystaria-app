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
    @State private var showBackgroundSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white
    // Focused block tracking for paintbrush menu
    @State private var focusedBlockID: UUID? = nil
    // Block accent color sheets
    @State private var showDividerColorSheet = false
    @State private var showBlockquoteColorSheet = false
    @State private var showCalloutColorSheet = false
    @State private var blockAccentColor1: Color = Color(red: 0.32, green: 0.27, blue: 0.96)
    @State private var blockAccentColor2: Color = Color(red: 0.71, green: 0.45, blue: 0.98)

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            Group {
                if let workingEntry {
                    VStack(spacing: 0) {
                        pageMetaFields(entry: workingEntry)
                        JournalBlockEditorView(entry: workingEntry, focusedBlockID: $focusedBlockID)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .navigationTitle(existingEntry == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(existingEntry == nil ? "New Entry" : "Edit Entry")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(book.title)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Menu {
                        // Entry-level
                        Button {
                            showBackgroundSettingsSheet = true
                        } label: {
                            Label("Background", systemImage: "photo")
                        }
                        Button {
                            if let hex = workingEntry?.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines),
                               !hex.isEmpty,
                               let r = UInt8(hex.prefix(2), radix: 16),
                               let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
                               let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) {
                                textColorPickerSelection = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
                            } else {
                                textColorPickerSelection = .white
                            }
                            showTextColorSheet = true
                        } label: {
                            Label("Text Color", systemImage: "textformat")
                        }

                        // Block-level accent colors — shown only when relevant block is focused
                        if let block = focusedBlock {
                            if block.type == .divider {
                                Divider()
                                Button {
                                    loadBlockColors(from: block.dividerColorHex)
                                    showDividerColorSheet = true
                                } label: {
                                    Label("Divider Color", systemImage: "paintpalette")
                                }
                            }
                            if block.isBlockquoteStyle || block.type == .blockquote {
                                Divider()
                                Button {
                                    loadBlockColors(from: block.blockquoteColorHex)
                                    showBlockquoteColorSheet = true
                                } label: {
                                    Label("Blockquote Color", systemImage: "paintpalette")
                                }
                            }
                            if block.isCalloutStyle || block.type == .callout {
                                Divider()
                                Button {
                                    loadBlockColors(from: block.calloutColorHex)
                                    showCalloutColorSheet = true
                                } label: {
                                    Label("Callout Color", systemImage: "paintpalette")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "paintbrush.fill").foregroundStyle(.white)
                    }
                    .disabled(isCompletingAction || workingEntry == nil)
                    .opacity((isCompletingAction || workingEntry == nil) ? 0.5 : 1)

                    Button("Done") { saveAndClose() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .disabled(isCompletingAction || workingEntry == nil)
                        .opacity((isCompletingAction || workingEntry == nil) ? 0.5 : 1)
                }
            }
        }
        .sheet(isPresented: $showDividerColorSheet) {
            if let block = focusedBlock {
                blockAccentColorPickerSheet(
                    title: "Divider Color",
                    hasCustom: !block.dividerColorHex.isEmpty,
                    onApply: {
                        block.dividerColorHex = hexGradient(blockAccentColor1, blockAccentColor2)
                        block.touch()
                        showDividerColorSheet = false
                    },
                    onReset: {
                        block.dividerColorHex = ""
                        block.touch()
                        showDividerColorSheet = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showBlockquoteColorSheet) {
            if let block = focusedBlock {
                blockAccentColorPickerSheet(
                    title: "Blockquote Color",
                    hasCustom: !block.blockquoteColorHex.isEmpty,
                    onApply: {
                        block.blockquoteColorHex = hexGradient(blockAccentColor1, blockAccentColor2)
                        block.touch()
                        showBlockquoteColorSheet = false
                    },
                    onReset: {
                        block.blockquoteColorHex = ""
                        block.touch()
                        showBlockquoteColorSheet = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showCalloutColorSheet) {
            if let block = focusedBlock {
                blockAccentColorPickerSheet(
                    title: "Callout Color",
                    hasCustom: !block.calloutColorHex.isEmpty,
                    onApply: {
                        block.calloutColorHex = hexGradient(blockAccentColor1, blockAccentColor2)
                        block.touch()
                        showCalloutColorSheet = false
                    },
                    onReset: {
                        block.calloutColorHex = ""
                        block.touch()
                        showCalloutColorSheet = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showBackgroundSettingsSheet) {
            if let entry = workingEntry {
                JournalBackgroundSettingsSheet(entry: entry)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showTextColorSheet) {
            if let entry = workingEntry {
                NavigationStack {
                    ZStack {
                        LystariaBackground().ignoresSafeArea()
                        VStack(spacing: 24) {
                            ColorPicker("Text Color", selection: $textColorPickerSelection, supportsOpacity: false)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, LSpacing.pageHorizontal)
                            if !entry.textColorHex.isEmpty {
                                Button {
                                    entry.textColorHex = ""
                                    entry.touch()
                                    showTextColorSheet = false
                                } label: {
                                    Text("Reset to Default")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(.top, 24)
                    }
                    .navigationTitle("Text Color")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Apply") {
                                let uiColor = UIColor(textColorPickerSelection)
                                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                                entry.textColorHex = String(format: "%02X%02X%02X",
                                    Int(r * 255), Int(g * 255), Int(b * 255))
                                entry.touch()
                                showTextColorSheet = false
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
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
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
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
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
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
            if existingEntry.book == nil { existingEntry.book = book }
            JournalEntryBlockMigration.migrateIfNeeded(entry: existingEntry)
            existingEntry.ensureStarterBlock()
            existingEntry.normalizeBlockSortOrders()
            try? modelContext.save()
            createdNewEntry = false
            pageTitleDraft = existingEntry.title
            pageTagsDraft = existingEntry.tags.joined(separator: ", ")
            return
        }

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

        guard let workingEntry else { finishAndDismiss(); return }
        if workingEntry.book == nil { workingEntry.book = book }

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

    // MARK: - Focused Block

    private var focusedBlock: JournalBlock? {
        guard let id = focusedBlockID,
              let entry = workingEntry else { return nil }
        return (entry.blocks ?? []).first(where: { $0.id == id })
    }

    // MARK: - Block Accent Color Helpers

    private func loadBlockColors(from hex: String) {
        let parts = hex.components(separatedBy: ":")
        if parts.count == 2,
           let r = UInt8(parts[0].prefix(2), radix: 16),
           let g = UInt8(parts[0].dropFirst(2).prefix(2), radix: 16),
           let b = UInt8(parts[0].dropFirst(4).prefix(2), radix: 16),
           let r2 = UInt8(parts[1].prefix(2), radix: 16),
           let g2 = UInt8(parts[1].dropFirst(2).prefix(2), radix: 16),
           let b2 = UInt8(parts[1].dropFirst(4).prefix(2), radix: 16) {
            blockAccentColor1 = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
            blockAccentColor2 = Color(red: Double(r2)/255, green: Double(g2)/255, blue: Double(b2)/255)
        } else {
            blockAccentColor1 = Color(red: 0.32, green: 0.27, blue: 0.96)
            blockAccentColor2 = Color(red: 0.71, green: 0.45, blue: 0.98)
        }
    }

    private func hexGradient(_ c1: Color, _ c2: Color) -> String {
        func hex(_ c: Color) -> String {
            let ui = UIColor(c)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
        }
        return "\(hex(c1)):\(hex(c2))"
    }

    private func blockAccentColorPickerSheet(
        title: String,
        hasCustom: Bool,
        onApply: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $blockAccentColor1, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $blockAccentColor2, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    LinearGradient(
                        colors: [blockAccentColor1, blockAccentColor2],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(maxWidth: .infinity).frame(height: 6)
                    .clipShape(Capsule())
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Button(action: onApply) {
                        Text("Apply")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LGradients.blue).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).padding(.horizontal, LSpacing.pageHorizontal)

                    if hasCustom {
                        Button(action: onReset) {
                            Text("Reset to Default")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func isEntryEffectivelyEmpty(_ entry: JournalEntry) -> Bool {
        let hasTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTags = !entry.tags.isEmpty
        let meaningfulBlocks = (entry.blocks ?? []).filter { block in
            switch block.type {
            case .divider, .table:
                return false
            case .image:
                return block.imageData != nil
            default:
                return !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        return !hasTitle && !hasTags && meaningfulBlocks.isEmpty
    }
}
