//
//  DocumentBlockEditorPage.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData

struct DocumentBlockEditorPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: DocumentBook
    let existingEntry: DocumentEntry?
    let defaultFolder: DocumentFolder?

    @State private var workingEntry: DocumentEntry?
    @State private var hasPreparedEntry = false
    @State private var createdNewEntry = false
    @State private var hasFinishedEditorFlow = false
    @State private var isCompletingAction = false
    @State private var pageTitleDraft = ""
    @State private var pageTagsDraft = ""
    @State private var showBackgroundSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white
    @State private var focusedBlockID: UUID? = nil
    @State private var showBlockColorSheet = false
    @State private var blockColor1Selection: Color = Color(LColors.accent)
    @State private var blockColor2Selection: Color = Color(LColors.accent)

    init(book: DocumentBook, existingEntry: DocumentEntry? = nil, defaultFolder: DocumentFolder? = nil) {
        self.book = book
        self.existingEntry = existingEntry
        self.defaultFolder = defaultFolder
    }

    private var focusedBlock: DocumentBlock? {
        guard let id = focusedBlockID else { return nil }
        return workingEntry?.sortedBlocks.first { $0.id == id }
    }

    private var focusedBlockSupportsColor: Bool {
        guard let b = focusedBlock else { return false }
        return b.type == .divider || b.type == .callout || b.type == .blockquote || b.isBlockquoteStyle || b.isCalloutStyle
    }

    private var focusedBlockColorLabel: String {
        guard let b = focusedBlock else { return "Block Color" }
        if b.type == .divider { return "Divider Color" }
        if b.type == .callout || b.isCalloutStyle { return "Callout Color" }
        return "Blockquote Color"
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            Group {
                if let workingEntry {
                    VStack(spacing: 0) {
                        pageMetaFields(entry: workingEntry)
                        DocumentBlockEditorView(entry: workingEntry)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .navigationTitle(existingEntry == nil ? "New Document" : "Edit Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(existingEntry == nil ? "New Document" : "Edit Document")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(book.title)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Menu {
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
                        if focusedBlockSupportsColor, let block = focusedBlock {
                            Button {
                                blockColor1Selection = block.hasCustomBlockColor ? block.blockColor1 : Color(LColors.accent)
                                blockColor2Selection = block.hasCustomBlockColor ? block.blockColor2 : Color(LColors.accent)
                                showBlockColorSheet = true
                            } label: {
                                Label(focusedBlockColorLabel, systemImage: "paintpalette")
                            }
                        }
                    } label: {
                        Image(systemName: "paintbrush.fill")
                            .foregroundStyle(.white)
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
        .sheet(isPresented: $showBackgroundSettingsSheet) {
            if let entry = workingEntry {
                DocumentBackgroundSettingsSheet(entry: entry)
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
        .sheet(isPresented: $showBlockColorSheet) {
            if let block = focusedBlock {
                blockColorSheet(for: block)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .documentBlockDidFocus)) { note in
            if let info = note.object as? [String: Any], let id = info["id"] as? UUID {
                focusedBlockID = id
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
    private func pageMetaFields(entry: DocumentEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Document Title", text: $pageTitleDraft)
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

    private func blockColorSheet(for block: DocumentBlock) -> some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $blockColor1Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $blockColor2Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                            Gradient(colors: [blockColor1Selection, blockColor2Selection]),
                            startPoint: CGPoint(x: 0, y: size.height / 2),
                            endPoint: CGPoint(x: size.width, y: size.height / 2)
                        ))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
                    .clipShape(Capsule())
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Button {
                        let c1 = hexStringFromColor(UIColor(blockColor1Selection))
                        let c2 = hexStringFromColor(UIColor(blockColor2Selection))
                        block.colorHex = "\(c1):\(c2)"
                        block.touch()
                        showBlockColorSheet = false
                    } label: {
                        Text("Apply Color")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LGradients.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    if block.hasCustomBlockColor {
                        Button {
                            block.colorHex = ""
                            block.touch()
                            showBlockColorSheet = false
                        } label: {
                            Text("Reset to Default")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle(focusedBlockColorLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func hexStringFromColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func prepareEntry() {
        guard workingEntry == nil else { return }

        if let existingEntry {
            workingEntry = existingEntry
            if existingEntry.book == nil { existingEntry.book = book }
            existingEntry.ensureStarterBlock()
            existingEntry.normalizeBlockSortOrders()
            try? modelContext.save()
            createdNewEntry = false
            pageTitleDraft = existingEntry.title
            pageTagsDraft = existingEntry.tags.joined(separator: ", ")
            return
        }

        let entry = DocumentEntry()
        entry.updatedAt = Date()
        entry.book = book
        entry.folder = defaultFolder
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
        if createdNewEntry, workingEntry.folder == nil {
            workingEntry.folder = defaultFolder
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

    private func isEntryEffectivelyEmpty(_ entry: DocumentEntry) -> Bool {
        let hasTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTags = !entry.tags.isEmpty
        let meaningfulBlocks = (entry.blocks ?? []).filter { block in
            switch block.type {
            case .divider: return false
            case .image: return block.imageData != nil
            default:
                return !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        return !hasTitle && !hasTags && meaningfulBlocks.isEmpty
    }
}
