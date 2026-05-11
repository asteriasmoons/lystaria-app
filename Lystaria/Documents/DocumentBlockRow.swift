//
//  DocumentBlockRow.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

extension Notification.Name {
    static let documentBlockRequestFocus = Notification.Name("DocumentBlockRequestFocus")
    static let documentBlockDidFocus = Notification.Name("documentBlockDidFocus")
}

struct DocumentBlockRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: DocumentBlock

    var onAddBelow: (DocumentBlock, DocumentBlockType, String) -> Void
    var onDelete: (DocumentBlock) -> Void
    var onMoveUp: (DocumentBlock) -> Void
    var onMoveDown: (DocumentBlock) -> Void
    var onTransform: (DocumentBlock, DocumentBlockType) -> Void

    var isSelectionMode: Bool = false
    var isSelectedForBatchAction: Bool = false
    var selectedBlockCount: Int = 0
    var onEnterSelectionMode: (DocumentBlock) -> Void = { _ in }
    var onToggleBatchSelection: (DocumentBlock) -> Void = { _ in }
    var onClearBatchSelection: () -> Void = {}
    var onDeleteSelectedBlocks: () -> Void = {}
    var onIndentSelectedBlocksIn: () -> Void = {}
    var onIndentSelectedBlocksOut: () -> Void = {}
    var documentTextColor: UIColor = UIColor(LColors.textPrimary)

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showLinkEditor = false
    @State private var linkDraft = ""
    @State private var showBlockColorSheet = false
    @State private var blockColor1Selection: Color = Color(LColors.accent)
    @State private var blockColor2Selection: Color = Color(LColors.accent)
    @State private var showHighlightPicker = false
    @State private var highlightForeground: Color = .white
    @State private var highlightBackground: Color = Color(red: 1, green: 0.85, blue: 0.24)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCalloutIconPicker = false
    @State private var isScrollingCalloutIconPicker = false
    @State private var isImageToolbarVisible = false

    private let maxIndentLevel = 5

    private var indentPadding: CGFloat {
        CGFloat(block.indentLevel) * 20
    }

    private var paragraphTopPadding: CGFloat {
        guard block.type == .paragraph else { return 0 }
        return block.indentLevel > 0 ? 0 : 3
    }

    private var prefixWrapperAlignmentPadding: CGFloat {
        block.isBlockquoteStyle || block.isCalloutStyle ? 12 : 0
    }
    
    @ViewBuilder
    private func transformButton(_ title: String, icon: String, type: DocumentBlockType) -> some View {
        Button {
            onTransform(block, type)
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(block.type == type)
    }

    private func toggleBlockquoteStyle() {
        guard supportsWrapperStyles else { return }
        block.isBlockquoteStyle.toggle()
        block.touch()
    }

    private func toggleCalloutStyle() {
        guard supportsWrapperStyles else { return }
        block.isCalloutStyle.toggle()
        if block.isCalloutStyle && block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            block.calloutEmoji = defaultCalloutIconID
        }
        block.touch()
    }

    // Inline property sheet state
    @State private var showInlinePropertyDefinitionSheet = false
    @State private var pendingInlinePropertyDraft: DocumentInlinePropertyDraft?
    @State private var selectedInlinePropertyForViewing: DocumentInlineProperty?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if supportsInlineFormatting && selectedRange.length > 0 {
                selectionFormatMenu
            }
            VStack(alignment: .leading, spacing: block.isListBlock ? 2 : 4) {
                contentColumn
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isSelectionMode ? 4 : 0)
        .padding(.horizontal, isSelectionMode ? 8 : 0)
        .background(batchSelectionBackground)
        .overlay(batchSelectionOverlay)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelectionMode else { return }
            onToggleBatchSelection(block)
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !isSelectionMode else { return }
            onEnterSelectionMode(block)
        }
        .padding(.top, paragraphTopPadding)
        .contextMenu {
            if isSelectionMode {
                Button {
                    onToggleBatchSelection(block)
                } label: {
                    Label(isSelectedForBatchAction ? "Deselect Block" : "Select Block", systemImage: isSelectedForBatchAction ? "checkmark.circle.fill" : "circle")
                }

                if selectedBlockCount > 0 {
                    Menu {
                        Button {
                            onIndentSelectedBlocksOut()
                        } label: {
                            Label("Indent Out", systemImage: "decrease.indent")
                        }

                        Button {
                            onIndentSelectedBlocksIn()
                        } label: {
                            Label("Indent In", systemImage: "increase.indent")
                        }

                        Divider()

                        Button(role: .destructive) {
                            onDeleteSelectedBlocks()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    } label: {
                        Label("Selected Actions", systemImage: "checklist")
                    }
                }

                Button {
                    onClearBatchSelection()
                } label: {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }

                Divider()
            } else {
                Button {
                    onEnterSelectionMode(block)
                } label: {
                    Label("Select Multiple", systemImage: "checklist")
                }

                Divider()
            }

            if canIndentBlock {
                Button {
                    indentOut()
                } label: {
                    Label("Indent Out", systemImage: "decrease.indent")
                }
                .disabled(block.indentLevel <= 0)

                Button {
                    indentIn()
                } label: {
                    Label("Indent In", systemImage: "increase.indent")
                }
                .disabled(block.indentLevel >= maxIndentLevel)

                Divider()
            }

            Menu {
                transformButton("Paragraph", icon: "text.alignleft", type: .paragraph)

                Menu {
                    transformButton("Heading 1", icon: "textformat.size.larger", type: .heading1)
                    transformButton("Heading 2", icon: "textformat.size", type: .heading2)
                    transformButton("Heading 3", icon: "textformat", type: .heading3)
                    transformButton("Heading 4", icon: "textformat", type: .heading4)
                    transformButton("Heading 5", icon: "textformat", type: .heading5)
                    transformButton("Heading 6", icon: "textformat", type: .heading6)
                } label: { Label("Headings", systemImage: "textformat.size.larger") }

                Menu {
                    transformButton("Toggle", icon: "chevron.right.square", type: .toggle)
                    transformButton("Toggle H1", icon: "chevron.right.square", type: .toggleHeading1)
                    transformButton("Toggle H2", icon: "chevron.right.square", type: .toggleHeading2)
                    transformButton("Toggle H3", icon: "chevron.right.square", type: .toggleHeading3)
                    transformButton("Toggle H4", icon: "chevron.right.square", type: .toggleHeading4)
                    transformButton("Toggle H5", icon: "chevron.right.square", type: .toggleHeading5)
                    transformButton("Toggle H6", icon: "chevron.right.square", type: .toggleHeading6)
                } label: { Label("Toggles", systemImage: "chevron.right.square") }

                transformButton("Bullet List", icon: "list.bullet", type: .bulletedList)
                transformButton("Numbered List", icon: "list.number", type: .numberedList)
                transformButton("Checklist", icon: "checklist", type: .checklist)

                Divider()

                transformButton("Code", icon: "chevron.left.forwardslash.chevron.right", type: .code)
                transformButton("Divider", icon: "minus", type: .divider)
                transformButton("Table", icon: "tablecells", type: .table)
            } label: {
                Label("Turn Into", systemImage: "wand.and.stars")
            }

            if supportsWrapperStyles {
                Menu {
                    Button {
                        toggleBlockquoteStyle()
                    } label: {
                        Label(block.isBlockquoteStyle ? "Remove Blockquote" : "Blockquote", systemImage: "quote.opening")
                    }

                    Button {
                        toggleCalloutStyle()
                    } label: {
                        Label(block.isCalloutStyle ? "Remove Callout" : "Callout", systemImage: "sparkles")
                    }
                } label: {
                    Label("Apply Style", systemImage: "paintbrush")
                }
            }

            if block.type == .divider || block.isBlockquoteStyle || block.isCalloutStyle {
                Button {
                    blockColor1Selection = block.hasCustomBlockColor ? block.blockColor1 : Color(LColors.accent)
                    blockColor2Selection = block.hasCustomBlockColor ? block.blockColor2 : Color(LColors.accent)
                    showBlockColorSheet = true
                } label: {
                    Label("Block Color", systemImage: "paintpalette")
                }
            }

            Divider()

            Button {
                onMoveUp(block)
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }

            Button {
                onMoveDown(block)
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }

            Button(role: .destructive) {
                onDelete(block)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showCalloutIconPicker) {
            calloutIconPickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBlockColorSheet) {
            blockColorSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showInlinePropertyDefinitionSheet) {
            DocumentInlinePropertyDefinitionSheet { draft in
                insertInlinePropertyBelowCurrentBlock(from: draft)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedInlinePropertyForViewing) { property in
            DocumentInlinePropertyViewSheet(property: property)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .alert("Insert Link", isPresented: $showLinkEditor) {
            TextField("https://example.com", text: $linkDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { linkDraft = "" }
            Button("Apply") { applyLinkFromDraft() }
        } message: {
            Text("Select text in the block first, then add a link.")
        }
    }

    private var batchSelectionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelectedForBatchAction ? AnyShapeStyle(LGradients.blue.opacity(0.22)) : AnyShapeStyle(Color.white.opacity(isSelectionMode ? 0.04 : 0)))
    }

    private var batchSelectionOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isSelectedForBatchAction ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.clear), lineWidth: 1)
    }

    // MARK: - Format Menu

    private var selectionFormatMenu: some View {
        HStack(spacing: 8) {
            Menu {
                Button(rangeHasStyle(.bold) ? "Remove Bold" : "Bold") { toggleInlineStyle(.bold) }
                Button(rangeHasStyle(.italic) ? "Remove Italic" : "Italic") { toggleInlineStyle(.italic) }
                Button(rangeHasStyle(.underline) ? "Remove Underline" : "Underline") { toggleInlineStyle(.underline) }
                Button(rangeHasStyle(.strikethrough) ? "Remove Strikethrough" : "Strikethrough") { toggleInlineStyle(.strikethrough) }
                Button(rangeHasStyle(.inlineCode) ? "Remove Code" : "Code") { toggleInlineStyle(.inlineCode) }
                Button(rangeHasStyle(.link) ? "Edit Link" : "Add Link") { prepareLinkEditor() }
            } label: {
                Text("Format")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LGradients.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LGradients.blue, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Highlight picker button
            Button {
                // Seed pickers from existing highlight on this range
                if let existing = (block.inlineStyles ?? []).first(where: {
                    $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
                }) {
                    let parts = existing.urlString.components(separatedBy: ":")
                    if parts.count == 2 {
                        highlightForeground = Color(uiColorFromHex(parts[0]) ?? .white)
                        highlightBackground = Color(uiColorFromHex(parts[1]) ?? UIColor(red: 1, green: 0.85, blue: 0.24, alpha: 1))
                    }
                }
                showHighlightPicker = true
            } label: {
                ZStack {
                    // Show the active highlight bg color if one exists for this range
                    let activeHex = (block.inlineStyles ?? []).first(where: {
                        $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
                    })?.urlString.components(separatedBy: ":").last ?? ""
                    Circle()
                        .fill(activeHex.isEmpty ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(Color(uiColorFromHex(activeHex) ?? .yellow)))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showHighlightPicker) {
                highlightPickerSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch block.type {
        case .divider:   dividerEditor
        case .code:      codeEditor
        case .callout:   calloutEditor
        case .image:     imageEditor
        case .table:     tableEditor
        case .toggle, .toggleHeading1, .toggleHeading2, .toggleHeading3,
             .toggleHeading4, .toggleHeading5, .toggleHeading6: textEditor
        default:         textEditor
        }
    }

    @ViewBuilder
    private func styledContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if block.isCalloutStyle {
            calloutStyleWrapper {
                if block.isBlockquoteStyle {
                    blockquoteStyleWrapper { content() }
                } else {
                    content()
                }
            }
        } else if block.isBlockquoteStyle {
            blockquoteStyleWrapper { content() }
        } else {
            content()
        }
    }

    private func blockquoteStyleWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(blockGradient)
                .frame(width: 4)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button {
                blockColor1Selection = block.hasCustomBlockColor ? block.blockColor1 : Color(LColors.accent)
                blockColor2Selection = block.hasCustomBlockColor ? block.blockColor2 : Color(LColors.accent)
                showBlockColorSheet = true
            } label: {
                Label("Blockquote Color", systemImage: "paintpalette")
            }
        }
    }

    private func calloutStyleWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            calloutIconPicker
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient, lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button {
                blockColor1Selection = block.hasCustomBlockColor ? block.blockColor1 : Color(LColors.accent)
                blockColor2Selection = block.hasCustomBlockColor ? block.blockColor2 : Color(LColors.accent)
                showBlockColorSheet = true
            } label: {
                Label("Callout Color", systemImage: "paintpalette")
            }
        }
    }

    private var calloutIconPicker: some View {
        Button {
            showCalloutIconPicker = true
        } label: {
            calloutIconView(for: activeCalloutIconItem)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var calloutIconPickerSheet: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        calloutIconSection(title: "Custom Icons", items: BookmarkAssetIconLibrary.all)
                        calloutIconSection(title: "SF Symbols", items: BookmarkIconLibrary.all)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in
                            isScrollingCalloutIconPicker = true
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                isScrollingCalloutIconPicker = false
                            }
                        }
                )
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func calloutIconSection(title: String, items: [BookmarkIconItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.id) { item in
                    calloutIconGridButton(for: item)
                }
            }
        }
    }

    private func calloutIconGridButton(for item: BookmarkIconItem) -> some View {
        let isSelected = activeCalloutIconItem.id == item.id

        return Button {
            guard !isScrollingCalloutIconPicker else { return }
            block.calloutEmoji = item.id
            block.touch()
            showCalloutIconPicker = false
        } label: {
            calloutIconView(for: item)
                .frame(width: 22, height: 22)
                .frame(width: 54, height: 54)
                .background(isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }


    private var defaultCalloutIconID: String {
        BookmarkAssetIconLibrary.all.first?.id ?? BookmarkIconLibrary.all.first?.id ?? "system:sparkles"
    }

    private var activeCalloutIconItem: BookmarkIconItem {
        let trimmed = block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        if let item = BookmarkCombinedIconLibrary.all.first(where: { $0.id == trimmed }) {
            return item
        }

        if let legacyAsset = BookmarkAssetIconLibrary.all.first(where: { $0.name == trimmed }) {
            return legacyAsset
        }

        if let legacySystem = BookmarkIconLibrary.all.first(where: { $0.name == trimmed }) {
            return legacySystem
        }

        return BookmarkAssetIconLibrary.all.first ?? BookmarkIconLibrary.all.first ?? BookmarkIconItem(name: "sparkles", source: .system)
    }

    @ViewBuilder
    private func calloutIconView(for item: BookmarkIconItem) -> some View {
        switch item.source {
        case .asset:
            Image(item.name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
        case .system:
            Image(systemName: item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }


    // MARK: - Text Editor

    private var textEditor: some View {
        Group {
            if block.type == .blockquote {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(LGradients.blue).frame(width: 4)
                    DocumentRichEditableBlockTextView(
                        block: block, selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: documentTextColor,
                        placeholder: placeholderText, isCodeBlock: false,
                        isSelectionMode: isSelectionMode,
                        onInlinePropertyTap: { property in
                            selectedInlinePropertyForViewing = property
                        },
                        onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                        onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                        onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                        onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.leading, indentPadding)
            } else if block.isToggleBlock || block.type == .bulletedList || block.type == .numberedList || block.type == .checklist {
                HStack(alignment: .top, spacing: 8) {
                    if block.isToggleBlock {
                        Button {
                            block.isExpanded.toggle()
                            block.touch()
                        } label: {
                            prefixView(for: block)
                                .frame(width: 22, alignment: .leading)
                                .padding(.top, prefixWrapperAlignmentPadding)
                        }
                        .buttonStyle(.plain)
                    } else if block.type == .checklist {
                        checklistPrefixButton
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, prefixWrapperAlignmentPadding)
                    } else {
                        prefixView(for: block)
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, prefixWrapperAlignmentPadding)
                    }
                    styledContent {
                        DocumentRichEditableBlockTextView(
                            block: block, selectedRange: $selectedRange,
                            baseUIFont: uiFontForBlockType(block.type),
                            textColor: documentTextColor,
                            placeholder: placeholderText, isCodeBlock: false,
                            isSelectionMode: isSelectionMode,
                            onInlinePropertyTap: { property in
                                selectedInlinePropertyForViewing = property
                            },
                            onCreateParagraphBelow: { suffix in onAddBelow(block, nextBlockTypeOnReturn(for: block.type), suffix) },
                            onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                            onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                            onDeleteEmptyBlock: { onDelete(block) },
                            onExitList: { onAddBelow(block, .paragraph, ""); onDelete(block) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, indentPadding)
            } else {
                styledContent {
                    DocumentRichEditableBlockTextView(
                        block: block, selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: documentTextColor,
                        placeholder: placeholderText, isCodeBlock: false,
                        isSelectionMode: isSelectionMode,
                        onInlinePropertyTap: { property in
                            selectedInlinePropertyForViewing = property
                        },
                        onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                        onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                        onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                        onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, indentPadding)
            }
        }
    }

    // MARK: - Table Editor

    private var tableEditor: some View {
        DocumentTableEditorView(block: block, documentTextColor: documentTextColor)
    }

    // MARK: - Callout Editor

    private var calloutEditor: some View {
        HStack(alignment: .center, spacing: 12) {
            calloutIconPicker
            DocumentRichEditableBlockTextView(
                block: block, selectedRange: $selectedRange,
                baseUIFont: UIFont.systemFont(ofSize: 15, weight: .regular),
                textColor: documentTextColor,
                placeholder: "Write callout...", isCodeBlock: false,
                isSelectionMode: isSelectionMode,
                onInlinePropertyTap: { property in
                    selectedInlinePropertyForViewing = property
                },
                onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient, lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.leading, indentPadding)
        .contextMenu {
            Button {
                blockColor1Selection = block.hasCustomBlockColor ? block.blockColor1 : Color(LColors.accent)
                blockColor2Selection = block.hasCustomBlockColor ? block.blockColor2 : Color(LColors.accent)
                showBlockColorSheet = true
            } label: {
                Label("Callout Color", systemImage: "paintpalette")
            }
        }
    }

    // MARK: - Divider Editor

    private var dividerEditor: some View {
        let current = DividerStyles(rawValue: block.languageHint) ?? .line
        let preview = dividerPreview(style: current)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        if isSelectionMode {
            return AnyView(preview)
        } else {
            return AnyView(preview.simultaneousGesture(TapGesture().onEnded {
                let all = DividerStyles.allCases
                let next = all[(all.firstIndex(of: current)! + 1) % all.count]
                block.languageHint = next.rawValue
                block.touch()
            }))
        }
    }

    @ViewBuilder
    private func dividerPreview(style: DividerStyles) -> some View {
        switch style {
        case .pageBreak:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.vertical, 4)
        case .line:
            Capsule().fill(blockGradient).frame(maxWidth: .infinity).frame(height: 3)
        case .dotted:
            let dotSize: CGFloat = 4; let gap: CGFloat = 8
            GeometryReader { geo in
                let count = max(1, Int(geo.size.width / (dotSize + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle().fill(blockGradient).frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).frame(height: dotSize)
        case .dash:
            Capsule().fill(blockGradient).frame(maxWidth: .infinity).scaleEffect(x: 0.5).frame(height: 2)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in Circle().fill(blockGradient).frame(width: 7, height: 7) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Code Editor

    private var codeLanguage: CodeLanguage {
        CodeLanguage.from(block.languageHint)
    }

    private var codeTheme: CodeTheme {
        CodeTheme.from(block.calloutEmoji)
    }

    private var codeEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar — language + theme pickers
            HStack(spacing: 8) {
                // Language picker
                Menu {
                    ForEach(CodeLanguage.allCases) { lang in
                        Button {
                            block.languageHint = lang.rawValue
                            block.touch()
                        } label: {
                            if codeLanguage == lang {
                                Label(lang.rawValue, systemImage: "checkmark")
                            } else {
                                Text(lang.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(codeLanguage.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Theme picker
                Menu {
                    ForEach(CodeTheme.allCases) { thm in
                        Button {
                            block.calloutEmoji = thm.rawValue
                            block.touch()
                        } label: {
                            if codeTheme == thm {
                                Label(thm.rawValue, systemImage: "checkmark")
                            } else {
                                Text(thm.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 10, weight: .semibold))
                        Text(codeTheme.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.08))

            // Code body
            HStack(alignment: .top, spacing: 0) {
                codeLineNumberGutter

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)

                DocumentRichEditableBlockTextView(
                    block: block, selectedRange: $selectedRange,
                    baseUIFont: codeEditorUIFont,
                    textColor: codeTheme.colors.text,
                    placeholder: "Write code...", isCodeBlock: true,
                    isSelectionMode: isSelectionMode,
                    codeLanguage: codeLanguage,
                    codeTheme: codeTheme,
                    onInlinePropertyTap: { property in
                        selectedInlinePropertyForViewing = property
                    },
                    onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                    onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                    onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                    onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                )
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.leading, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(codeTheme.colors.background))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var codeEditorUIFont: UIFont {
        UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
    }
    
    private var codeLineNumberGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...codeLineCount, id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: codeEditorUIFont.pointSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(LColors.textSecondary.opacity(0.58))
                    .frame(width: codeGutterWidth, height: codeEditorUIFont.lineHeight, alignment: .trailing)
            }
        }
        .padding(.top, 0)
        .padding(.trailing, 8)
    }

    private var codeLineCount: Int {
        max(1, block.text.components(separatedBy: "\n").count)
    }

    private var codeGutterWidth: CGFloat {
        let digits = String(codeLineCount).count
        return CGFloat(max(1, digits)) * 8 + 4
    }


    // MARK: - Image Editor

    private var imageEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                VStack(alignment: block.imageAlignment == .center ? .center : .leading, spacing: 8) {
                    let imageViewContent = imageView(uiImage: uiImage)
                        .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
                        .contentShape(Rectangle())

                    if isSelectionMode {
                        imageViewContent
                    } else {
                        imageViewContent
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isImageToolbarVisible.toggle()
                                }
                            }
                    }
                    if isImageToolbarVisible {
                        HStack(spacing: 8) {
                            imageControlButton(
                                icon: block.imageAlignment == .center ? "text.aligncenter" : "text.alignleft",
                                label: block.imageAlignment == .center ? "Center" : "Left"
                            ) { block.imageAlignment = block.imageAlignment == .center ? .left : .center; block.touch() }
                            imageControlButton(
                                icon: block.imageDisplayMode == .fill ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                                label: block.imageDisplayMode.label
                            ) { block.imageDisplayMode = block.imageDisplayMode == .fit ? .fill : .fit; block.touch() }
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .semibold))
                                    Text("Replace").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule()).overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 6) {
                            ForEach(ImageBlockSize.allCases, id: \.rawValue) { size in
                                let active = block.imageSize == size
                                Button {
                                    block.imageSize = size; block.touch()
                                } label: {
                                    Text(size.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(active ? .white : LColors.textPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(AnyShapeStyle(LGradients.blue))
                        Text("Add Photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AnyShapeStyle(LGradients.blue))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AnyShapeStyle(LGradients.blue), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let compressed = UIImage(data: data)
                        .flatMap { $0.jpegData(compressionQuality: 0.75) } ?? data
                    await MainActor.run { block.imageData = compressed; block.touch() }
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
    }

    @ViewBuilder
    private func imageView(uiImage: UIImage) -> some View {
        let size = block.imageSize
        let mode = block.imageDisplayMode
        if let maxH = size.maxHeight {
            if mode == .fill {
                Image(uiImage: uiImage).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: maxH)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(uiImage: uiImage).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(maxHeight: maxH)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        } else {
            Image(uiImage: uiImage).resizable().scaledToFit()
                .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func imageControlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule()).overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func insertInlinePropertyBelowCurrentBlock(from draft: DocumentInlinePropertyDraft) {
        let displayText = inlinePropertyDisplayText(from: draft)
        onAddBelow(block, .paragraph, displayText)
        pendingInlinePropertyDraft = draft

        DispatchQueue.main.async {
            guard let entry = block.entry else { return }
            guard let draft = pendingInlinePropertyDraft else { return }

            let displayText = inlinePropertyDisplayText(from: draft)
            guard let propertyBlock = entry.sortedBlocks.first(where: {
                $0.type == .paragraph &&
                $0.text == displayText &&
                ($0.inlineProperties ?? []).isEmpty
            }) else { return }

            let property = DocumentInlineProperty(
                name: draft.name,
                type: draft.type,
                valueStorage: draft.valueStorage,
                optionsStorage: draft.optionsStorage,
                colorHex: draft.colorHex,
                rangeLocation: 0,
                rangeLength: (displayText as NSString).length,
                block: propertyBlock
            )

            modelContext.insert(property)

            if propertyBlock.inlineProperties == nil {
                propertyBlock.inlineProperties = []
            }

            propertyBlock.inlineProperties?.append(property)
            propertyBlock.touch()
            pendingInlinePropertyDraft = nil
        }
    }

    private func inlinePropertyDisplayText(from draft: DocumentInlinePropertyDraft) -> String {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? draft.type.rawValue : trimmedName

        switch draft.type {
        case .boolean:
            return "\(name): \(draft.valueStorage == "true" ? "True" : "False")"
        case .checkbox:
            return "\(name): \(draft.valueStorage == "true" ? "Checked" : "Unchecked")"
        case .text, .number, .url, .select:
            let value = draft.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? name : "\(name): \(value)"
        case .date:
            if let date = ISO8601DateFormatter().date(from: draft.valueStorage) {
                return "\(name): \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return name
        case .multiSelect:
            guard let data = draft.valueStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([String].self, from: data),
                  !values.isEmpty else {
                return name
            }
            return "\(name): \(values.joined(separator: ", "))"
        }
    }

    // MARK: - Highlight

    private var highlightPickerSheet: some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $highlightForeground, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $highlightBackground, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    // Live preview — highlight text
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                            Gradient(colors: [highlightForeground, highlightBackground]),
                            startPoint: CGPoint(x: 0, y: size.height / 2),
                            endPoint: CGPoint(x: size.width, y: size.height / 2)
                        ))
                    }
                    .frame(width: 160, height: 28)
                    .mask {
                        Text("Highlight Text")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 160, height: 28)
                    }

                    Button {
                        applyHighlight()
                        showHighlightPicker = false
                    } label: {
                        Text("Apply Highlight")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LGradients.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    if rangeHasStyle(.highlight) {
                        Button {
                            removeHighlight()
                            showHighlightPicker = false
                        } label: {
                            Text("Remove Highlight")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func applyHighlight() {
        guard selectedRange.length > 0 else { return }
        removeHighlight()
        let fgHex = hexString(from: UIColor(highlightForeground))
        let bgHex = hexString(from: UIColor(highlightBackground))
        let style = DocumentInlineStyle(
            type: .highlight,
            rangeLocation: selectedRange.location,
            rangeLength: selectedRange.length,
            urlString: "\(fgHex):\(bgHex)"
        )
        style.block = block
        modelContext.insert(style)
        if block.inlineStyles == nil { block.inlineStyles = [] }
        block.inlineStyles?.append(style)
        block.touch()
    }

    private func removeHighlight() {
        guard let idx = block.inlineStyles?.firstIndex(where: {
            $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
        }) else { return }
        let old = block.inlineStyles?.remove(at: idx)
        if let old { modelContext.delete(old) }
        block.touch()
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Block Color Sheet

    private var blockColorSheet: some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    let label: String = {
                        if block.type == .divider { return "Divider Color" }
                        if block.isCalloutStyle { return "Callout Border Color" }
                        return "Blockquote Border Color"
                    }()

                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $blockColor1Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $blockColor2Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    // Live preview
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
                        let c1 = hexString(from: UIColor(blockColor1Selection))
                        let c2 = hexString(from: UIColor(blockColor2Selection))
                        block.colorHex = "\(c1):\(c2)"
                        block.touch()
                        showBlockColorSheet = false
                    } label: {
                        Text("Apply \(label)")
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
            .navigationTitle("Block Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    /// Resolves the block's custom gradient or falls back to LGradients.blue
    private var blockGradient: AnyShapeStyle {
        guard block.hasCustomBlockColor else { return AnyShapeStyle(LGradients.blue) }
        return AnyShapeStyle(LinearGradient(
            colors: [block.blockColor1, block.blockColor2],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    // MARK: - Inline Style Helpers

    private var supportsInlineFormatting: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout: return true
        case .divider, .code, .image, .table: return false
        }
    }

    private var supportsWrapperStyles: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggle, .bulletedList, .numberedList, .checklist:
            return true
        case .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .blockquote, .callout, .divider, .code, .image, .table:
            return false
        }
    }

    private func rangeHasStyle(_ style: DocumentInlineStyleType) -> Bool {
        guard selectedRange.length > 0 else { return false }
        return (block.inlineStyles ?? []).contains {
            $0.type == style && NSEqualRanges($0.safeRange, selectedRange)
        }
    }

    private func toggleInlineStyle(_ style: DocumentInlineStyleType) {
        guard selectedRange.length > 0 else { return }
        guard block.type != .code, block.type != .divider else { return }

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == style && NSEqualRanges($0.safeRange, selectedRange) }),
           let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
            let toDelete = block.inlineStyles?[idx]
            block.inlineStyles?.remove(at: idx)
            if let toDelete { modelContext.delete(toDelete) }
            block.touch()
            return
        }

        let newStyle = DocumentInlineStyle(
            type: style, rangeLocation: selectedRange.location, rangeLength: selectedRange.length, urlString: ""
        )
        newStyle.block = block
        modelContext.insert(newStyle)
        if block.inlineStyles == nil { block.inlineStyles = [] }
        block.inlineStyles?.append(newStyle)
        block.touch()
    }

    private func prepareLinkEditor() {
        guard selectedRange.length > 0 else { return }
        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == .link && NSEqualRanges($0.safeRange, selectedRange) }) {
            linkDraft = existing.urlString
        } else {
            linkDraft = ""
        }
        showLinkEditor = true
    }

    private func applyLinkFromDraft() {
        guard selectedRange.length > 0 else { linkDraft = ""; return }
        let trimmed = linkDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == .link && NSEqualRanges($0.safeRange, selectedRange) }),
           let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
            let toDelete = block.inlineStyles?[idx]
            block.inlineStyles?.remove(at: idx)
            if let toDelete { modelContext.delete(toDelete) }
        }

        if !trimmed.isEmpty {
            let newStyle = DocumentInlineStyle(
                type: .link, rangeLocation: selectedRange.location, rangeLength: selectedRange.length, urlString: trimmed
            )
            newStyle.block = block
            modelContext.insert(newStyle)
            if block.inlineStyles == nil { block.inlineStyles = [] }
            block.inlineStyles?.append(newStyle)
        }

        block.touch()
        linkDraft = ""
    }

    // MARK: - Prefix Views

    @ViewBuilder
    private func prefixView(for block: DocumentBlock) -> some View {
        switch block.type {
        case .toggle:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading1:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading2:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading3:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading4:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading5:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading6:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(LGradients.blue)
        case .bulletedList:
            Image(systemName: bulletSymbolName(for: block.indentLevel))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
                .padding(.top, 5)
        case .numberedList:
            Text(numberPrefix(for: block))
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(LColors.textPrimary)
        case .checklist:
            checklistPrefixIcon
        default: EmptyView()
        }
    }
    
    private var checklistPrefixButton: some View {
        checklistPrefixIcon
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                block.languageHint = "xmark"
                block.touch()
            }
            .onTapGesture {
                toggleChecklistCheckedState()
            }
    }

    @ViewBuilder
    private var checklistPrefixIcon: some View {
        switch checklistState {
        case "checked":
            ZStack {
                Circle()
                    .fill(LGradients.blue)
                    .frame(width: 17, height: 17)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.white)
            }
            .padding(.top, 4)

        case "xmark":
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 17, height: 17)
                    .overlay(Circle().stroke(LGradients.blue, lineWidth: 1.3))

                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.white)
            }
            .padding(.top, 4)

        default:
            Circle()
                .stroke(LColors.textSecondary, lineWidth: 1.4)
                .frame(width: 17, height: 17)
                .padding(.top, 4)
        }
    }

    private var checklistState: String {
        block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleChecklistCheckedState() {
        if checklistState == "checked" {
            block.languageHint = ""
        } else {
            block.languageHint = "checked"
        }

        block.touch()
    }

    private func numberPrefix(for block: DocumentBlock) -> String {
        guard let entry = block.entry, block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter {
            $0.type == .numberedList &&
            $0.listGroupID == groupID &&
            $0.indentLevel == block.indentLevel
        }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func nextBlockTypeOnReturn(for type: DocumentBlockType) -> DocumentBlockType {
        switch type {
        case .toggle: return .paragraph
        case .bulletedList: return .bulletedList
        case .numberedList: return .numberedList
        case .checklist: return .checklist
        default: return .paragraph
        }
    }

    private var canIndentBlock: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return true
        case .divider, .code, .image, .table:
            return false
        }
    }

    private func indentIn() {
        guard canIndentBlock else { return }
        block.indentLevel = min(maxIndentLevel, block.indentLevel + 1)
        block.touch()
    }

    private func indentOut() {
        guard canIndentBlock else { return }
        block.indentLevel = max(0, block.indentLevel - 1)
        block.touch()
    }

    private func bulletSymbolName(for indentLevel: Int) -> String {
        indentLevel % 2 == 1 ? "circle" : "circle.fill"
    }

    private func mergeWithPreviousBlock(_ currentBlock: DocumentBlock) -> Bool {
        guard let entry = currentBlock.entry else { return false }
        let sortedBlocks = entry.sortedBlocks
        guard let currentIndex = sortedBlocks.firstIndex(where: { $0.id == currentBlock.id }), currentIndex > 0 else { return false }

        let previousBlock = sortedBlocks[currentIndex - 1]
        guard canMergeText(into: previousBlock), canMergeText(from: currentBlock) else { return false }

        let previousLength = (previousBlock.text as NSString).length
        previousBlock.text += currentBlock.text

        if let currentStyles = currentBlock.inlineStyles, !currentStyles.isEmpty {
            if previousBlock.inlineStyles == nil {
                previousBlock.inlineStyles = []
            }

            for style in currentStyles {
                style.rangeLocation += previousLength
                style.block = previousBlock
                previousBlock.inlineStyles?.append(style)
            }

            currentBlock.inlineStyles?.removeAll()
        }

        if let currentProperties = currentBlock.inlineProperties, !currentProperties.isEmpty {
            if previousBlock.inlineProperties == nil {
                previousBlock.inlineProperties = []
            }

            for property in currentProperties {
                property.rangeLocation += previousLength
                property.block = previousBlock
                previousBlock.inlineProperties?.append(property)
            }

            currentBlock.inlineProperties?.removeAll()
        }

        previousBlock.touch()
        onDelete(currentBlock)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .documentBlockRequestFocus, object: previousBlock.id)
        }

        return true
    }

    private func canMergeText(into block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code:
            return true
        case .divider, .image, .table:
            return false
        }
    }

    private func canMergeText(from block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code:
            return true
        case .divider, .image, .table:
            return false
        }
    }

    private var placeholderText: String {
        switch block.type {
        case .paragraph: return "Write something..."
        case .heading1, .toggleHeading1: return "Heading 1"
        case .heading2, .toggleHeading2: return "Heading 2"
        case .heading3, .toggleHeading3: return "Heading 3"
        case .heading4, .toggleHeading4: return "Heading 4"
        case .heading5, .toggleHeading5: return "Heading 5"
        case .heading6, .toggleHeading6: return "Heading 6"
        case .toggle: return "Toggle"
        case .bulletedList: return "List item"
        case .numberedList: return "List item"
        case .checklist: return "Checklist item"
        case .blockquote: return "Quote"
        case .callout: return "Callout"
        case .divider: return ""
        case .code: return "Code"
        case .image: return ""
        case .table: return ""
        }
    }

    private func uiFontForBlockType(_ type: DocumentBlockType) -> UIFont {
        switch type {
        case .heading1, .toggleHeading1: return .systemFont(ofSize: 28, weight: .bold)
        case .heading2, .toggleHeading2: return .systemFont(ofSize: 22, weight: .bold)
        case .heading3, .toggleHeading3: return .systemFont(ofSize: 18, weight: .semibold)
        case .heading4, .toggleHeading4: return .systemFont(ofSize: 16, weight: .semibold)
        case .heading5, .toggleHeading5: return .systemFont(ofSize: 14, weight: .semibold)
        case .heading6, .toggleHeading6: return .systemFont(ofSize: 13, weight: .medium)
        case .blockquote: return .systemFont(ofSize: 16, weight: .medium)
        case .code: return .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        default: return .systemFont(ofSize: 16, weight: .regular)
        }
    }
}

// MARK: - Rich Editable Text View (UIViewRepresentable)

struct DocumentRichEditableBlockTextView: UIViewRepresentable {
    @Bindable var block: DocumentBlock
    @Binding var selectedRange: NSRange

    let baseUIFont: UIFont
    let textColor: UIColor
    let placeholder: String
    let isCodeBlock: Bool
    var isSelectionMode: Bool = false
    var codeLanguage: CodeLanguage = .plainText
    var codeTheme: CodeTheme = .lystaria
    var onInlinePropertyTap: ((DocumentInlineProperty) -> Void)? = nil
    let onCreateParagraphBelow: ((String) -> Void)?
    var onCreateTypedBlockBelow: ((DocumentBlockType, String) -> Void)? = nil
    var onMergeWithPrevious: (() -> Bool)? = nil
    let onDeleteEmptyBlock: (() -> Void)?
    let onExitList: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let fallbackHeight: CGFloat = isCodeBlock ? 64 : ceil(baseUIFont.lineHeight)

        guard let proposedWidth = proposal.width,
              proposedWidth.isFinite,
              proposedWidth > 0 else {
            return CGSize(width: 1, height: max(1, fallbackHeight))
        }

        let safeWidth = max(1, min(proposedWidth, UIScreen.main.bounds.width))
        let fitting = uiView.sizeThatFits(CGSize(width: safeWidth, height: .greatestFiniteMagnitude))
        let safeHeight = fitting.height.isFinite ? max(fallbackHeight, fitting.height) : fallbackHeight

        return CGSize(width: safeWidth, height: max(1, safeHeight))
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = DocumentPlaceholderTextView()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceHorizontal = false
        textView.showsHorizontalScrollIndicator = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.typingAttributes = baseAttributes()
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.placeholderLabel.text = placeholder
        textView.placeholderLabel.textColor = UIColor(LColors.textSecondary)
        textView.placeholderLabel.font = baseUIFont
        textView.placeholderLabel.isHidden = !block.text.isEmpty
        textView.showsCodeLineNumbers = false
        textView.codeLineNumberFont = baseUIFont
        textView.codeLineNumberColor = UIColor(LColors.textSecondary).withAlphaComponent(0.72)

        let propertyTapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleInlinePropertyTap(_:)))
        propertyTapRecognizer.cancelsTouchesInView = false
        propertyTapRecognizer.delaysTouchesBegan = false
        propertyTapRecognizer.delaysTouchesEnded = false
        propertyTapRecognizer.delegate = context.coordinator
        textView.addGestureRecognizer(propertyTapRecognizer)

        let blockID = block.id
        NotificationCenter.default.addObserver(
            forName: .documentBlockRequestFocus, object: nil, queue: .main
        ) { [weak textView] notification in
            guard let requestedID = notification.object as? UUID, requestedID == blockID else { return }
            textView?.becomeFirstResponder()
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributed = buildAttributedText()
        if let codeTextView = uiView as? DocumentPlaceholderTextView {
            codeTextView.showsCodeLineNumbers = false
            codeTextView.codeLineNumberFont = baseUIFont
            codeTextView.codeLineNumberColor = codeTheme.colors.comment
            codeTextView.textContainerInset = .zero
            codeTextView.setNeedsDisplay()
        }
        if uiView.attributedText != attributed {
            let priorSelection = uiView.selectedRange
            context.coordinator.isApplyingProgrammaticChange = true
            uiView.attributedText = attributed
            uiView.typingAttributes = baseAttributes()
            let maxLocation = max(0, min(priorSelection.location, attributed.length))
            let maxLength = max(0, min(priorSelection.length, attributed.length - maxLocation))
            uiView.selectedRange = NSRange(location: maxLocation, length: maxLength)
            context.coordinator.isApplyingProgrammaticChange = false
            uiView.invalidateIntrinsicContentSize()
        }
        if let pv = uiView as? DocumentPlaceholderTextView {
            pv.placeholderLabel.text = placeholder
            pv.placeholderLabel.font = baseUIFont
            pv.placeholderLabel.textColor = UIColor(LColors.textSecondary)
            pv.placeholderLabel.isHidden = !(block.text.isEmpty && !uiView.isFirstResponder)
        }
        uiView.isEditable = !isSelectionMode
        uiView.isSelectable = !isSelectionMode
        uiView.isUserInteractionEnabled = !isSelectionMode
        context.coordinator.parent = self
        context.coordinator.onInlinePropertyTap = self.onInlinePropertyTap
        context.coordinator.onCreateParagraphBelow = self.onCreateParagraphBelow
        context.coordinator.onCreateTypedBlockBelow = self.onCreateTypedBlockBelow
        context.coordinator.onMergeWithPrevious = self.onMergeWithPrevious
        context.coordinator.onDeleteEmptyBlock = self.onDeleteEmptyBlock
        context.coordinator.onExitList = self.onExitList
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .natural
        return [.font: baseUIFont, .foregroundColor: textColor, .paragraphStyle: paragraph]
    }

    func buildAttributedText() -> NSAttributedString {
        // Code blocks use syntax highlighting
        if isCodeBlock {
            return CodeHighlighter.highlight(block.text, language: codeLanguage, theme: codeTheme)
        }

        let mutable = NSMutableAttributedString(string: block.text, attributes: baseAttributes())
        let fullLength = (block.text as NSString).length
        guard fullLength > 0 else { return mutable }

        // Inline property styling
        for property in block.inlineProperties ?? [] {
            let rawRange = property.safeRange
            let maxLength = max(0, fullLength - rawRange.location)
            let clampedLength = min(rawRange.length, maxLength)
            guard rawRange.location >= 0, rawRange.location < fullLength, clampedLength > 0 else { continue }

            let range = NSRange(location: rawRange.location, length: clampedLength)
            applyInlinePropertyStyling(to: mutable, property: property, range: range)
        }

        for style in block.sortedInlineStyles {
            let rawRange = style.safeRange
            let maxLength = max(0, fullLength - rawRange.location)
            let clampedLength = min(rawRange.length, maxLength)
            guard rawRange.location >= 0, rawRange.location < fullLength, clampedLength > 0 else { continue }
            let range = NSRange(location: rawRange.location, length: clampedLength)
            switch style.type {
            case .bold:
                mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let f = (value as? UIFont) ?? baseUIFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitBold)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: subrange)
                    }
                }
            case .italic:
                mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let f = (value as? UIFont) ?? baseUIFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: subrange)
                    }
                }
            case .underline:
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .strikethrough:
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .link:
                let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }
                mutable.addAttribute(.link, value: url, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .inlineCode:
                let monoFont = UIFont.monospacedSystemFont(ofSize: baseUIFont.pointSize * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: monoFont, range: range)
                mutable.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.1), range: range)
            case .highlight:
                let parts = style.urlString.components(separatedBy: ":")
                guard parts.count == 2,
                      let color1 = uiColorFromHex(parts[0]),
                      let color2 = uiColorFromHex(parts[1]),
                      range.length > 0 else { continue }
                var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
                color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                let count = CGFloat(range.length)
                for i in 0..<range.length {
                    let t = count > 1 ? CGFloat(i) / (count - 1) : 0
                    let blended = UIColor(
                        red:   r1 + (r2 - r1) * t,
                        green: g1 + (g2 - g1) * t,
                        blue:  b1 + (b2 - b1) * t,
                        alpha: 1
                    )
                    mutable.addAttribute(.foregroundColor, value: blended,
                        range: NSRange(location: range.location + i, length: 1))
                }
            }
        }
        if block.type == .checklist && !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }

        return mutable
    }

    private func applyInlinePropertyStyling(
        to mutable: NSMutableAttributedString,
        property: DocumentInlineProperty,
        range: NSRange
    ) {
        let fullText = mutable.string as NSString
        let propertyText = fullText.substring(with: range)
        let trimmedName = property.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? property.type.rawValue : trimmedName

        if property.type == .checkbox {
            applyCheckboxInlinePropertyStyling(to: mutable, property: property, range: range, propertyText: propertyText, name: name)
            return
        }

        let value = inlinePropertyValueText(for: property)

        let nameRangeInPropertyText = (propertyText as NSString).range(of: name)
        if nameRangeInPropertyText.location != NSNotFound {
            let absoluteNameRange = NSRange(
                location: range.location + nameRangeInPropertyText.location,
                length: nameRangeInPropertyText.length
            )
            mutable.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: baseUIFont.pointSize, weight: .bold),
                range: absoluteNameRange
            )
        }

        applyInlinePropertyValueColors(to: mutable, property: property, value: value, fullText: propertyText, baseLocation: range.location)
    }

    private func applyCheckboxInlinePropertyStyling(
        to mutable: NSMutableAttributedString,
        property: DocumentInlineProperty,
        range: NSRange,
        propertyText: String,
        name: String
    ) {
        let nsPropertyText = propertyText as NSString
        let nameRangeInPropertyText = nsPropertyText.range(of: name)

        if nameRangeInPropertyText.location != NSNotFound {
            let absoluteNameRange = NSRange(
                location: range.location + nameRangeInPropertyText.location,
                length: nameRangeInPropertyText.length
            )
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: absoluteNameRange)
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: baseUIFont.pointSize, weight: .regular), range: absoluteNameRange)
        }

        let checkedValue = property.valueStorage == "true" ? "Checked" : "Unchecked"
        let valueRangeInPropertyText = nsPropertyText.range(of: checkedValue)
        guard valueRangeInPropertyText.location != NSNotFound else { return }

        let absoluteValueRange = NSRange(
            location: range.location + valueRangeInPropertyText.location,
            length: valueRangeInPropertyText.length
        )

        let symbol = property.valueStorage == "true" ? "●" : "○"
        let replacement = NSAttributedString(string: symbol, attributes: [
            .font: UIFont.systemFont(ofSize: baseUIFont.pointSize + 2, weight: .regular),
            .foregroundColor: property.valueStorage == "true" ? UIColor(LColors.accent) : UIColor(LColors.textSecondary)
        ])

        mutable.replaceCharacters(in: absoluteValueRange, with: replacement)
    }

    private func applyInlinePropertyValueColors(
        to attributed: NSMutableAttributedString,
        property: DocumentInlineProperty,
        value: String,
        fullText: String,
        baseLocation: Int
    ) {
        guard !value.isEmpty else { return }

        let nsText = fullText as NSString

        if property.type == .multiSelect {
            let selectedValues = decodeStringArray(property.valueStorage)
            let options = decodePropertyOptions(property.optionsStorage)

            for selectedValue in selectedValues {
                let valueRange = nsText.range(of: selectedValue)
                guard valueRange.location != NSNotFound else { continue }

                let optionColor = options.first(where: { $0.name == selectedValue })?.colorHex ?? property.colorHex
                let absoluteRange = NSRange(location: baseLocation + valueRange.location, length: valueRange.length)
                attributed.addAttribute(
                    .foregroundColor,
                    value: inlinePropertyValueColor(hex: optionColor),
                    range: absoluteRange
                )
            }

            return
        }

        let valueRange = nsText.range(of: value)
        guard valueRange.location != NSNotFound else { return }

        let absoluteRange = NSRange(location: baseLocation + valueRange.location, length: valueRange.length)

        if property.type == .select {
            let options = decodePropertyOptions(property.optionsStorage)
            let optionColor = options.first(where: { $0.name == value })?.colorHex ?? property.colorHex
            attributed.addAttribute(.foregroundColor, value: inlinePropertyValueColor(hex: optionColor), range: absoluteRange)
        } else {
            attributed.addAttribute(.foregroundColor, value: inlinePropertyValueColor(hex: property.colorHex), range: absoluteRange)
        }
    }

    private func inlinePropertyValueText(for property: DocumentInlineProperty) -> String {
        switch property.type {
        case .boolean:
            return property.valueStorage == "true" ? "True" : "False"
        case .checkbox:
            return property.valueStorage == "true" ? "Checked" : "Unchecked"
        case .text, .number, .url, .select:
            return property.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date:
            guard let date = ISO8601DateFormatter().date(from: property.valueStorage) else { return "" }
            return date.formatted(date: .abbreviated, time: .omitted)
        case .multiSelect:
            guard let data = property.valueStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([String].self, from: data) else {
                return ""
            }
            return values.joined(separator: ", ")
        }
    }

    private func inlinePropertyValueColor(hex: String) -> UIColor {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let color = UIColor(hexString: trimmed) else {
            return textColor
        }

        return color
    }

    private func decodeStringArray(_ storage: String) -> [String] {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return decoded
    }

    private func decodePropertyOptions(_ storage: String) -> [DocumentPropertyOptionDraft] {
        guard let data = storage.data(using: .utf8) else { return [] }

        if let decoded = try? JSONDecoder().decode([DocumentPropertyOptionDraft].self, from: data) {
            return decoded
        }

        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            return legacy.map { DocumentPropertyOptionDraft(name: $0, colorHex: "") }
        }

        return []
    }

    final class DocumentPlaceholderTextView: UITextView {
        let placeholderLabel = UILabel()
        var showsCodeLineNumbers = false
        var codeLineNumberFont: UIFont = .monospacedSystemFont(ofSize: 16, weight: .regular)
        var codeLineNumberColor: UIColor = .secondaryLabel
        private let codeLineNumberWidth: CGFloat = 34

        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
            setup()
        }
        required init?(coder: NSCoder) { super.init(coder: coder); setup() }

        private func setup() {
            placeholderLabel.numberOfLines = 0
            placeholderLabel.backgroundColor = .clear
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainerInset.left),
                placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
            ])
        }

        // Allow the parent ScrollView to scroll while this text view handles selection
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: self)
                // If mostly vertical and not selecting, let ScrollView handle it
                if abs(velocity.y) > abs(velocity.x) * 2 && !isFirstResponder {
                    return false
                }
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            setNeedsDisplay()
        }

        override func setNeedsDisplay() {
            super.setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            super.draw(rect)
            guard showsCodeLineNumbers else { return }
            drawVisualCodeLineNumbers()
        }

        private func drawVisualCodeLineNumbers() {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.saveGState()
            defer { context.restoreGState() }

            layoutManager.ensureLayout(for: textContainer)

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            var visualLineNumber = 1

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: codeLineNumberFont,
                .foregroundColor: codeLineNumberColor,
                .paragraphStyle: paragraphStyle
            ]

            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                let numberString = "\(visualLineNumber)" as NSString
                let drawRect = CGRect(
                    x: 0,
                    y: usedRect.minY + self.textContainerInset.top,
                    width: self.codeLineNumberWidth,
                    height: max(self.codeLineNumberFont.lineHeight, usedRect.height)
                )
                numberString.draw(in: drawRect, withAttributes: attributes)
                visualLineNumber += 1
            }

            if glyphRange.length == 0 {
                ("1" as NSString).draw(
                    in: CGRect(x: 0, y: textContainerInset.top, width: codeLineNumberWidth, height: codeLineNumberFont.lineHeight),
                    withAttributes: attributes
                )
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.isCodeBlock == false else { return false }
            guard let textView = gestureRecognizer.view as? UITextView else { return false }
            return inlinePropertyByRect(at: touch.location(in: textView), in: textView) != nil
        }
        var parent: DocumentRichEditableBlockTextView
        var isApplyingProgrammaticChange = false
        var onInlinePropertyTap: ((DocumentInlineProperty) -> Void)?
        var onCreateParagraphBelow: ((String) -> Void)?
        var onCreateTypedBlockBelow: ((DocumentBlockType, String) -> Void)?
        var onMergeWithPrevious: (() -> Bool)?
        var onDeleteEmptyBlock: (() -> Void)?
        var onExitList: (() -> Void)?

        init(parent: DocumentRichEditableBlockTextView) {
            self.parent = parent
            self.onInlinePropertyTap = parent.onInlinePropertyTap
            self.onCreateParagraphBelow = parent.onCreateParagraphBelow
            self.onCreateTypedBlockBelow = parent.onCreateTypedBlockBelow
            self.onMergeWithPrevious = parent.onMergeWithPrevious
            self.onDeleteEmptyBlock = parent.onDeleteEmptyBlock
            self.onExitList = parent.onExitList
        }
        @objc func handleInlinePropertyTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            guard parent.isCodeBlock == false else { return }
            guard let textView = recognizer.view as? UITextView else { return }
            guard let property = inlinePropertyByRect(at: recognizer.location(in: textView), in: textView) else { return }
            onInlinePropertyTap?(property)
        }

        private func inlinePropertyByRect(at point: CGPoint, in textView: UITextView) -> DocumentInlineProperty? {
            guard let properties = parent.block.inlineProperties, !properties.isEmpty else { return nil }

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let textStorage = textView.textStorage
            guard textStorage.length > 0 else { return nil }

            layoutManager.ensureLayout(for: textContainer)

            var adjustedPoint = point
            adjustedPoint.x -= textView.textContainerInset.left
            adjustedPoint.y -= textView.textContainerInset.top

            for property in properties {
                let range = property.safeRange
                guard range.location >= 0,
                      range.length > 0,
                      range.location < textStorage.length else { continue }

                let safeLength = min(range.length, textStorage.length - range.location)
                let safeRange = NSRange(location: range.location, length: safeLength)
                let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
                let propertyRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).insetBy(dx: -4, dy: -6)

                if propertyRect.contains(adjustedPoint) {
                    return property
                }
            }

            return nil
        }

        private func inlineProperty(at point: CGPoint, in textView: UITextView) -> DocumentInlineProperty? {
            guard let properties = parent.block.inlineProperties, !properties.isEmpty else { return nil }

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let textStorage = textView.textStorage
            guard textStorage.length > 0 else { return nil }

            layoutManager.ensureLayout(for: textContainer)

            var adjustedPoint = point
            adjustedPoint.x -= textView.textContainerInset.left
            adjustedPoint.y -= textView.textContainerInset.top

            let glyphIndex = layoutManager.glyphIndex(for: adjustedPoint, in: textContainer)
            guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

            let tappedGlyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textContainer
            ).insetBy(dx: -3, dy: -4)

            guard tappedGlyphRect.contains(adjustedPoint) else { return nil }

            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            for property in properties {
                let range = property.safeRange
                guard range.location >= 0,
                      range.length > 0,
                      range.location < textStorage.length else { continue }

                let safeLength = min(range.length, textStorage.length - range.location)
                let safeRange = NSRange(location: range.location, length: safeLength)
                guard characterIndex >= safeRange.location,
                      characterIndex < safeRange.location + safeRange.length else { continue }

                let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
                let propertyRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).insetBy(dx: -3, dy: -4)

                if propertyRect.contains(adjustedPoint) {
                    return property
                }
            }

            return nil
        }

        private struct PastedBlockPayload {
            let type: DocumentBlockType
            let text: String
            let languageHint: String

            init(type: DocumentBlockType, text: String, languageHint: String = "") {
                self.type = type
                self.text = text
                self.languageHint = languageHint
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            parent.selectedRange = textView.selectedRange
            guard textView.isFirstResponder else { return }
            NotificationCenter.default.post(
                name: .documentBlockDidFocus,
                object: ["id": parent.block.id, "cursor": textView.selectedRange.location] as [String: Any]
            )
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingProgrammaticChange else { return true }
            if text.isEmpty && range.length == 0 && range.location == 0 {
                if onMergeWithPrevious?() == true {
                    return false
                }
            }
            if text.isEmpty {
                if deleteInlinePropertyIfNeeded(in: textView, range: range) {
                    return false
                }

                let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isEmpty { onDeleteEmptyBlock?(); return false }
            }
            guard !parent.isCodeBlock else { return true }

            if text.contains("\n") && text != "\n" {
                adjustInlinePropertyRangesForTextChange(in: range, replacementText: text)
                return handleMultilinePaste(in: textView, range: range, replacementText: text)
            }

            adjustInlinePropertyRangesForTextChange(in: range, replacementText: text)

            guard text == "\n", range.length == 0 else { return true }

            let isListBlock = parent.block.type == .bulletedList || parent.block.type == .numberedList
            let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isListBlock && isEmpty { onExitList?(); return false }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let prefixText = nsText.substring(to: range.location)
            let suffixText = nsText.substring(from: range.location)

            isApplyingProgrammaticChange = true
            parent.block.text = prefixText
            parent.block.touch()
            textView.attributedText = NSAttributedString(string: prefixText, attributes: parent.baseAttributes())
            textView.invalidateIntrinsicContentSize()
            isApplyingProgrammaticChange = false

            let newLength = (prefixText as NSString).length
            if var styles = parent.block.inlineStyles {
                styles = styles.filter { $0.rangeLocation < newLength }
                for style in styles where style.rangeLocation + style.rangeLength > newLength {
                    style.rangeLength = newLength - style.rangeLocation
                }
                parent.block.inlineStyles = styles
            }

            if var properties = parent.block.inlineProperties {
                properties = properties.filter { $0.rangeLocation < newLength }
                for property in properties where property.rangeLocation + property.rangeLength > newLength {
                    property.rangeLength = newLength - property.rangeLocation
                    property.touch()
                }
                parent.block.inlineProperties = properties
            }

            onCreateParagraphBelow?(suffixText)
            return false
        }

        private func deleteInlinePropertyIfNeeded(in textView: UITextView, range: NSRange) -> Bool {
            guard var properties = parent.block.inlineProperties, !properties.isEmpty else { return false }
            let textLength = ((textView.text ?? "") as NSString).length
            guard textLength > 0 else { return false }

            let deletionStart = max(0, min(range.location, textLength))
            let deletionLength = max(0, min(range.length, textLength - deletionStart))
            let deletionEnd = deletionStart + deletionLength

            let matchingProperty = properties.first { property in
                let propertyRange = property.safeRange
                let propertyStart = propertyRange.location
                let propertyEnd = propertyRange.location + propertyRange.length

                guard propertyStart >= 0,
                      propertyRange.length > 0,
                      propertyStart < textLength else { return false }

                let safePropertyEnd = min(propertyEnd, textLength)

                if deletionLength > 0 {
                    return deletionStart < safePropertyEnd && deletionEnd > propertyStart
                }

                return deletionStart == propertyStart || deletionStart == safePropertyEnd
            }

            guard let property = matchingProperty else { return false }

            let propertyRange = property.safeRange
            let propertyStart = max(0, min(propertyRange.location, textLength))
            let propertyLength = max(0, min(propertyRange.length, textLength - propertyStart))
            guard propertyLength > 0 else { return false }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let deleteRange = NSRange(location: propertyStart, length: propertyLength)
            let updatedText = nsText.replacingCharacters(in: deleteRange, with: "")
            let delta = -propertyLength

            properties.removeAll { $0.id == property.id }

            for remainingProperty in properties where remainingProperty.rangeLocation > propertyStart {
                remainingProperty.rangeLocation = max(0, remainingProperty.rangeLocation + delta)
                remainingProperty.touch()
            }

            property.block = nil
            parent.block.inlineProperties = properties
            parent.block.text = updatedText
            parent.block.touch()

            isApplyingProgrammaticChange = true
            textView.attributedText = parent.buildAttributedText()
            textView.typingAttributes = parent.baseAttributes()
            textView.selectedRange = NSRange(location: propertyStart, length: 0)
            textView.invalidateIntrinsicContentSize()
            isApplyingProgrammaticChange = false

            return true
        }

        private func adjustInlinePropertyRangesForTextChange(in range: NSRange, replacementText text: String) {
            guard var properties = parent.block.inlineProperties, !properties.isEmpty else { return }

            let replacementLength = (text as NSString).length
            let delta = replacementLength - range.length
            let changeStart = range.location
            let changeEnd = range.location + range.length
            var propertyIDsToRemove: Set<UUID> = []

            for property in properties {
                let propertyStart = property.rangeLocation
                let propertyEnd = property.rangeLocation + property.rangeLength

                if changeEnd <= propertyStart {
                    property.rangeLocation = max(0, property.rangeLocation + delta)
                    property.touch()
                    continue
                }

                if changeStart >= propertyEnd {
                    continue
                }

                if range.length == 0 && changeStart > propertyStart && changeStart < propertyEnd {
                    propertyIDsToRemove.insert(property.id)
                    continue
                }

                if range.length == 0 && changeStart == propertyStart {
                    property.rangeLocation = max(0, property.rangeLocation + delta)
                    property.touch()
                    continue
                }

                if range.length == 0 && changeStart == propertyEnd {
                    continue
                }

                propertyIDsToRemove.insert(property.id)
            }

            guard !propertyIDsToRemove.isEmpty else { return }

            properties.removeAll { propertyIDsToRemove.contains($0.id) }
            parent.block.inlineProperties = properties
            parent.block.touch()
        }

        private func handleMultilinePaste(in textView: UITextView, range: NSRange, replacementText text: String) -> Bool {
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")

            let pastedBlocks = parsePastedBlocks(from: normalized)

            guard let firstBlock = pastedBlocks.first else { return true }

            let shouldHandleSingleParsedBlock = pastedBlocks.count == 1 && (
                firstBlock.type != .paragraph ||
                !firstBlock.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                normalized.contains("```")
            )

            guard pastedBlocks.count > 1 || shouldHandleSingleParsedBlock else { return true }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let safeLocation = max(0, min(range.location, nsText.length))
            let safeLength = max(0, min(range.length, nsText.length - safeLocation))
            let safeRange = NSRange(location: safeLocation, length: safeLength)

            let prefixText = nsText.substring(to: safeRange.location)
            let suffixText = nsText.substring(from: safeRange.location + safeRange.length)

            let currentBlockText = prefixText + firstBlock.text
            let trailingSuffix = suffixText.trimmingCharacters(in: .whitespacesAndNewlines)

            var blocksToInsert = Array(pastedBlocks.dropFirst())
            if !trailingSuffix.isEmpty, let last = blocksToInsert.indices.last {
                blocksToInsert[last] = PastedBlockPayload(
                    type: blocksToInsert[last].type,
                    text: blocksToInsert[last].text + "\n" + trailingSuffix,
                    languageHint: blocksToInsert[last].languageHint
                )
            } else if !trailingSuffix.isEmpty {
                blocksToInsert.append(PastedBlockPayload(type: .paragraph, text: trailingSuffix))
            }

            isApplyingProgrammaticChange = true
            parent.block.text = currentBlockText

            if prefixText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parent.block.type = firstBlock.type

                if !firstBlock.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parent.block.languageHint = firstBlock.languageHint
                }
            }

            parent.block.touch()
            textView.attributedText = parent.buildAttributedText()
            let newCursorLocation = (currentBlockText as NSString).length
            textView.selectedRange = NSRange(location: newCursorLocation, length: 0)
            textView.invalidateIntrinsicContentSize()
            isApplyingProgrammaticChange = false

            if var styles = parent.block.inlineStyles {
                let newLength = (currentBlockText as NSString).length
                styles = styles.filter { $0.rangeLocation < newLength }
                for style in styles where style.rangeLocation + style.rangeLength > newLength {
                    style.rangeLength = newLength - style.rangeLocation
                }
                parent.block.inlineStyles = styles
            }
            if var properties = parent.block.inlineProperties {
                let newLength = (currentBlockText as NSString).length
                properties = properties.filter { $0.rangeLocation < newLength }
                for property in properties where property.rangeLocation + property.rangeLength > newLength {
                    property.rangeLength = newLength - property.rangeLocation
                    property.touch()
                }
                parent.block.inlineProperties = properties
            }

            for payload in blocksToInsert.reversed() {
                if let onCreateTypedBlockBelow {
                    onCreateTypedBlockBelow(payload.type, payload.text)

                    if payload.type == .code, !payload.languageHint.isEmpty {
                        DispatchQueue.main.async {
                            self.parent.block.entry?.sortedBlocks.first(where: {
                                $0.type == .code && $0.text == payload.text && $0.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            })?.languageHint = payload.languageHint
                        }
                    }
                } else {
                    onCreateParagraphBelow?(payload.text)
                }
            }

            return false
        }

        private func normalizedCodeFenceLanguageHint(from fenceLine: String) -> String {
            let rawHint = fenceLine
                .dropFirst(3)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch rawHint {
            case "swift", "swiftui":
                return "Swift"
            case "js", "javascript":
                return "JavaScript"
            case "ts", "typescript":
                return "TypeScript"
            case "html":
                return "HTML"
            case "css":
                return "CSS"
            case "json":
                return "JSON"
            case "md", "markdown":
                return "Markdown"
            case "bash", "sh", "shell", "zsh":
                return "Shell"
            case "python", "py":
                return "Python"
            case "java":
                return "Java"
            case "csharp", "cs":
                return "C#"
            case "cpp", "c++":
                return "C++"
            case "c":
                return "C"
            case "sql":
                return "SQL"
            case "xml":
                return "XML"
            case "yaml", "yml":
                return "YAML"
            default:
                return ""
            }
        }

        private func parsePastedBlocks(from text: String) -> [PastedBlockPayload] {
            let lines = text.components(separatedBy: "\n")
            var payloads: [PastedBlockPayload] = []
            var codeBuffer: [String] = []
            var codeFenceLanguageHint = ""
            var isInsideCodeFence = false
            var tableBuffer: [[String]] = []

            func flushTable() {
                guard !tableBuffer.isEmpty else { return }
                let cols = tableBuffer.map(\.count).max() ?? 1
                var data = DocumentTableData(cols: cols, rows: tableBuffer)
                payloads.append(PastedBlockPayload(type: .table, text: data.toJSON()))
                tableBuffer.removeAll()
            }

            for rawLine in lines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.hasPrefix("```") {
                    flushTable()
                    if isInsideCodeFence {
                        payloads.append(PastedBlockPayload(
                            type: .code,
                            text: codeBuffer.joined(separator: "\n"),
                            languageHint: codeFenceLanguageHint
                        ))
                        codeBuffer.removeAll()
                        codeFenceLanguageHint = ""
                        isInsideCodeFence = false
                    } else {
                        isInsideCodeFence = true
                        codeBuffer.removeAll()
                        codeFenceLanguageHint = normalizedCodeFenceLanguageHint(from: trimmed)
                    }
                    continue
                }

                if isInsideCodeFence {
                    codeBuffer.append(rawLine)
                    continue
                }

                guard !trimmed.isEmpty else {
                    flushTable()
                    continue
                }

                // Detect tab-separated table rows
                if rawLine.contains("\t") {
                    let cells = rawLine.components(separatedBy: "\t").map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    tableBuffer.append(cells)
                    continue
                }

                // Detect markdown pipe tables: | col | col |
                if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    // Skip separator rows like |---|---|
                    let isSeparator = trimmed.replacingOccurrences(of: "|", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: ":", with: "")
                        .replacingOccurrences(of: " ", with: "")
                        .isEmpty
                    if isSeparator { continue }
                    let cells = trimmed
                        .split(separator: "|", omittingEmptySubsequences: false)
                        .dropFirst().dropLast()
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    tableBuffer.append(Array(cells))
                    continue
                }

                flushTable()
                payloads.append(classifyPastedLine(trimmed))
            }

            flushTable()

            if isInsideCodeFence, !codeBuffer.isEmpty {
                payloads.append(PastedBlockPayload(
                    type: .code,
                    text: codeBuffer.joined(separator: "\n"),
                    languageHint: codeFenceLanguageHint
                ))
            }

            return payloads
        }

        private func classifyPastedLine(_ line: String) -> PastedBlockPayload {
            if line == "---" || line == "***" || line == "___" {
                return PastedBlockPayload(type: .divider, text: "")
            }

            if line.hasPrefix("#### ") {
                return PastedBlockPayload(type: .heading4, text: String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("### ") {
                return PastedBlockPayload(type: .heading3, text: String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("## ") {
                return PastedBlockPayload(type: .heading2, text: String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("# ") {
                return PastedBlockPayload(type: .heading1, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("> ") {
                return PastedBlockPayload(type: .blockquote, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("! ") {
                return PastedBlockPayload(type: .callout, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("[!NOTE]") {
                return PastedBlockPayload(type: .callout, text: String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            if line.hasPrefix("- [ ] ") || line.hasPrefix("* [ ] ") {
                return PastedBlockPayload(type: .checklist, text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") || line.hasPrefix("* [x] ") || line.hasPrefix("* [X] ") {
                return PastedBlockPayload(type: .checklist, text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                return PastedBlockPayload(type: .bulletedList, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if let range = line.range(of: #"^\d+[\.)]\ +"#, options: .regularExpression) {
                return PastedBlockPayload(type: .numberedList, text: String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return PastedBlockPayload(type: .paragraph, text: line)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let pv = textView as? DocumentPlaceholderTextView { pv.placeholderLabel.isHidden = true }
            NotificationCenter.default.post(
                name: .documentBlockDidFocus,
                object: ["id": parent.block.id, "cursor": textView.selectedRange.location] as [String: Any]
            )
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            let newText = textView.text ?? ""
            if parent.block.text != newText {
                parent.block.text = newText
                parent.block.touch()
                textView.invalidateIntrinsicContentSize()
            }
            if let pv = textView as? DocumentPlaceholderTextView { pv.placeholderLabel.isHidden = !newText.isEmpty }

            // Re-apply syntax highlighting for code blocks on every keystroke
            if parent.isCodeBlock {
                let highlighted = CodeHighlighter.highlight(newText, language: parent.codeLanguage, theme: parent.codeTheme)
                let cursor = textView.selectedRange
                isApplyingProgrammaticChange = true
                textView.attributedText = highlighted
                let safeLocation = min(cursor.location, highlighted.length)
                textView.selectedRange = NSRange(location: safeLocation, length: 0)
                isApplyingProgrammaticChange = false
                textView.invalidateIntrinsicContentSize()
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            if (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isApplyingProgrammaticChange = true
                parent.block.text = ""
                parent.block.touch()
                textView.attributedText = parent.buildAttributedText()
                textView.typingAttributes = parent.baseAttributes()
                isApplyingProgrammaticChange = false
                textView.invalidateIntrinsicContentSize()
            }
            if let pv = textView as? DocumentPlaceholderTextView {
                pv.placeholderLabel.isHidden = !parent.block.text.isEmpty
            }
        }
    }
}


extension DocumentBlock {
    var blockColor1: Color {
        let parts = colorHex.components(separatedBy: ":")
        guard parts.count >= 1, let c = uiColorFromHex(parts[0]) else { return Color(LColors.accent) }
        return Color(c)
    }
    var blockColor2: Color {
        let parts = colorHex.components(separatedBy: ":")
        guard parts.count >= 2, let c = uiColorFromHex(parts[1]) else { return blockColor1 }
        return Color(c)
    }
}

private extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        guard hex.count == 6,
              let value = Int(hex, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
