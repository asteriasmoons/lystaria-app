//
//  DocumentBlockEditorPage.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData
import PhotosUI

struct DocumentBlockEditorPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
    
    private var editorInnerPageMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : 410
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
            DocumentEntryBackground(entry: workingEntry ?? DocumentEntry())
                .ignoresSafeArea()
            
            Group {
                if let workingEntry {
                    DocumentBlockEditorView(
                        entry: workingEntry,
                        identityHeader: AnyView(
                            DocumentIdentityHeaderEditorView(
                                entry: workingEntry,
                                pageTitleDraft: $pageTitleDraft,
                                pageTagsDraft: $pageTagsDraft
                            )
                        )
                    )
                    .frame(maxWidth: editorInnerPageMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .scrollDismissesKeyboard(.interactively)
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
        .task {
            guard !hasPreparedEntry else { return }
            hasPreparedEntry = true
            if let existing = existingEntry {
                workingEntry = existing
                pageTitleDraft = existing.title
                pageTagsDraft = existing.tags.joined(separator: ", ")
                existing.ensureStarterBlock()
                existing.normalizeBlockSortOrders()
                try? modelContext.save()
            } else {
                let newEntry = DocumentEntry(title: "", tags: [], book: book, folder: defaultFolder)
                modelContext.insert(newEntry)
                newEntry.ensureStarterBlock()
                try? modelContext.save()
                workingEntry = newEntry
                createdNewEntry = true
            }
        }
        .onDisappear {
            if !hasFinishedEditorFlow && createdNewEntry, let entry = workingEntry {
                if entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    (entry.blocks?.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true) {
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
            }
            isCompletingAction = false
        }
    }
    
    private func saveAndClose() {
        guard !isCompletingAction, let entry = workingEntry else { return }
        isCompletingAction = true
        hasFinishedEditorFlow = true
        entry.touch()
        try? modelContext.save()
        dismiss()
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBlockColorSheet = false }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func hexStringFromColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
