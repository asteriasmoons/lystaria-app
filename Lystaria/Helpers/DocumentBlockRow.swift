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

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showLinkEditor = false
    @State private var linkDraft = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCalloutIconPicker = false
    @State private var isScrollingCalloutIconPicker = false

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
                transformButton("Heading 1", icon: "textformat.size.larger", type: .heading1)
                transformButton("Heading 2", icon: "textformat.size", type: .heading2)
                transformButton("Heading 3", icon: "textformat", type: .heading3)
                transformButton("Heading 4", icon: "textformat", type: .heading4)

                Divider()

                transformButton("Bullet List", icon: "list.bullet", type: .bulletedList)
                transformButton("Numbered List", icon: "list.number", type: .numberedList)
                transformButton("Checklist", icon: "checklist", type: .checklist)
                transformButton("Toggle", icon: "chevron.right.square", type: .toggle)

                Divider()

                transformButton("Code", icon: "chevron.left.forwardslash.chevron.right", type: .code)
                transformButton("Divider", icon: "minus", type: .divider)
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
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch block.type {
        case .divider:   dividerEditor
        case .code:      codeEditor
        case .callout:   calloutEditor
        case .image:     imageEditor
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
                .fill(LGradients.blue)
                .frame(width: 4)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func calloutStyleWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            calloutIconPicker

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        textColor: UIColor(LColors.textPrimary),
                        placeholder: placeholderText, isCodeBlock: false,
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
            } else if block.type == .toggle || block.type == .bulletedList || block.type == .numberedList || block.type == .checklist {
                HStack(alignment: .top, spacing: 8) {
                    if block.type == .toggle {
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
                            textColor: UIColor(LColors.textPrimary),
                            placeholder: placeholderText, isCodeBlock: false,
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
                        textColor: UIColor(LColors.textPrimary),
                        placeholder: placeholderText, isCodeBlock: false,
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

    // MARK: - Callout Editor

    private var calloutEditor: some View {
        HStack(alignment: .center, spacing: 12) {
            calloutIconPicker
            DocumentRichEditableBlockTextView(
                block: block, selectedRange: $selectedRange,
                baseUIFont: UIFont.systemFont(ofSize: 15, weight: .regular),
                textColor: UIColor(LColors.textPrimary),
                placeholder: "Write callout...", isCodeBlock: false,
                onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.leading, indentPadding)
    }

    // MARK: - Divider Editor

    private var dividerEditor: some View {
        let current = DividerStyles(rawValue: block.languageHint) ?? .line
        return dividerPreview(style: current)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                let all = DividerStyles.allCases
                let next = all[(all.firstIndex(of: current)! + 1) % all.count]
                block.languageHint = next.rawValue
                block.touch()
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
            Capsule().fill(LGradients.blue).frame(maxWidth: .infinity).frame(height: 3)
        case .dotted:
            let dotSize: CGFloat = 4; let gap: CGFloat = 8
            GeometryReader { geo in
                let count = max(1, Int(geo.size.width / (dotSize + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle().fill(LGradients.blue).frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).frame(height: dotSize)
        case .dash:
            Capsule().fill(LGradients.blue).frame(maxWidth: .infinity).scaleEffect(x: 0.5).frame(height: 2)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in Circle().fill(LGradients.blue).frame(width: 7, height: 7) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Code Editor

    private var codeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Language", text: $block.languageHint)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .onChange(of: block.languageHint) { block.touch() }

            HStack(alignment: .top, spacing: 0) {
                codeLineNumberGutter

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)

                DocumentRichEditableBlockTextView(
                    block: block, selectedRange: $selectedRange,
                    baseUIFont: codeEditorUIFont,
                    textColor: UIColor(LColors.textPrimary),
                    placeholder: "Write code...", isCodeBlock: true,
                    onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                    onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                    onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                    onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                )
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.leading, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
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
                    imageView(uiImage: uiImage)
                        .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
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

    // MARK: - Inline Style Helpers

    private var supportsInlineFormatting: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
                .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout: return true
        case .divider, .code, .image: return false
        }
    }

    private var supportsWrapperStyles: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
                .toggle, .bulletedList, .numberedList, .checklist:
            return true
        case .blockquote, .callout, .divider, .code, .image:
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
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
                .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return true
        case .divider, .code, .image:
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

        previousBlock.touch()
        onDelete(currentBlock)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .documentBlockRequestFocus, object: previousBlock.id)
        }

        return true
    }

    private func canMergeText(into block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
                .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code:
            return true
        case .divider, .image:
            return false
        }
    }

    private func canMergeText(from block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
                .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code:
            return true
        case .divider, .image:
            return false
        }
    }

    private var placeholderText: String {
        switch block.type {
        case .paragraph: return "Write something..."
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .toggle: return "Toggle"
        case .bulletedList: return "List item"
        case .numberedList: return "List item"
        case .checklist: return "Checklist item"
        case .blockquote: return "Quote"
        case .callout: return "Callout"
        case .divider: return ""
        case .code: return "Code"
        case .image: return ""
        }
    }

    private func uiFontForBlockType(_ type: DocumentBlockType) -> UIFont {
        switch type {
        case .heading1: return .systemFont(ofSize: 26, weight: .bold)
        case .heading2: return .systemFont(ofSize: 20, weight: .bold)
        case .heading3: return .systemFont(ofSize: 17, weight: .semibold)
        case .heading4: return .systemFont(ofSize: 15, weight: .semibold)
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
    let onCreateParagraphBelow: ((String) -> Void)?
    var onCreateTypedBlockBelow: ((DocumentBlockType, String) -> Void)? = nil
    var onMergeWithPrevious: (() -> Bool)? = nil
    let onDeleteEmptyBlock: (() -> Void)?
    let onExitList: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let targetWidth = max(0, width)
        let fitting = uiView.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        let minimumHeight: CGFloat = isCodeBlock ? 64 : ceil(baseUIFont.lineHeight)
        return CGSize(width: targetWidth, height: max(minimumHeight, fitting.height))
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
            codeTextView.codeLineNumberColor = UIColor(LColors.textSecondary).withAlphaComponent(0.72)
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
        context.coordinator.parent = self
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
        let mutable = NSMutableAttributedString(string: block.text, attributes: baseAttributes())
        guard !isCodeBlock else { return mutable }
        let fullLength = (block.text as NSString).length
        guard fullLength > 0 else { return mutable }

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
            }
        }
        if block.type == .checklist && !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }

        return mutable
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

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DocumentRichEditableBlockTextView
        var isApplyingProgrammaticChange = false
        var onCreateParagraphBelow: ((String) -> Void)?
        var onCreateTypedBlockBelow: ((DocumentBlockType, String) -> Void)?
        var onMergeWithPrevious: (() -> Bool)?
        var onDeleteEmptyBlock: (() -> Void)?
        var onExitList: (() -> Void)?

        init(parent: DocumentRichEditableBlockTextView) {
            self.parent = parent
            self.onCreateParagraphBelow = parent.onCreateParagraphBelow
            self.onCreateTypedBlockBelow = parent.onCreateTypedBlockBelow
            self.onMergeWithPrevious = parent.onMergeWithPrevious
            self.onDeleteEmptyBlock = parent.onDeleteEmptyBlock
            self.onExitList = parent.onExitList
        }

        private struct PastedBlockPayload {
            let type: DocumentBlockType
            let text: String
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            parent.selectedRange = textView.selectedRange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingProgrammaticChange else { return true }
            if text.isEmpty && range.length == 0 && range.location == 0 {
                if onMergeWithPrevious?() == true {
                    return false
                }
            }
            if text.isEmpty {
                let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isEmpty { onDeleteEmptyBlock?(); return false }
            }
            guard !parent.isCodeBlock else { return true }

            if text.contains("\n") && text != "\n" {
                return handleMultilinePaste(in: textView, range: range, replacementText: text)
            }

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

            onCreateParagraphBelow?(suffixText)
            return false
        }

        private func handleMultilinePaste(in textView: UITextView, range: NSRange, replacementText text: String) -> Bool {
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")

            let pastedBlocks = parsePastedBlocks(from: normalized)

            guard pastedBlocks.count > 1 else { return true }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let safeLocation = max(0, min(range.location, nsText.length))
            let safeLength = max(0, min(range.length, nsText.length - safeLocation))
            let safeRange = NSRange(location: safeLocation, length: safeLength)

            let prefixText = nsText.substring(to: safeRange.location)
            let suffixText = nsText.substring(from: safeRange.location + safeRange.length)

            let firstBlock = pastedBlocks[0]
            let currentBlockText = prefixText + firstBlock.text
            let trailingSuffix = suffixText.trimmingCharacters(in: .whitespacesAndNewlines)

            var blocksToInsert = Array(pastedBlocks.dropFirst())
            if !trailingSuffix.isEmpty, let last = blocksToInsert.indices.last {
                blocksToInsert[last] = PastedBlockPayload(
                    type: blocksToInsert[last].type,
                    text: blocksToInsert[last].text + "\n" + trailingSuffix
                )
            } else if !trailingSuffix.isEmpty {
                blocksToInsert.append(PastedBlockPayload(type: .paragraph, text: trailingSuffix))
            }

            isApplyingProgrammaticChange = true
            parent.block.text = currentBlockText
            parent.block.touch()
            textView.attributedText = NSAttributedString(string: currentBlockText, attributes: parent.baseAttributes())
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

            for payload in blocksToInsert.reversed() {
                if let onCreateTypedBlockBelow {
                    onCreateTypedBlockBelow(payload.type, payload.text)
                } else {
                    onCreateParagraphBelow?(payload.text)
                }
            }

            return false
        }

        private func parsePastedBlocks(from text: String) -> [PastedBlockPayload] {
            let lines = text.components(separatedBy: "\n")
            var payloads: [PastedBlockPayload] = []
            var codeBuffer: [String] = []
            var isInsideCodeFence = false

            for rawLine in lines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.hasPrefix("```") {
                    if isInsideCodeFence {
                        payloads.append(PastedBlockPayload(type: .code, text: codeBuffer.joined(separator: "\n")))
                        codeBuffer.removeAll()
                        isInsideCodeFence = false
                    } else {
                        isInsideCodeFence = true
                        codeBuffer.removeAll()
                    }
                    continue
                }

                if isInsideCodeFence {
                    codeBuffer.append(rawLine)
                    continue
                }

                guard !trimmed.isEmpty else { continue }
                payloads.append(classifyPastedLine(trimmed))
            }

            if isInsideCodeFence, !codeBuffer.isEmpty {
                payloads.append(PastedBlockPayload(type: .code, text: codeBuffer.joined(separator: "\n")))
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

            if let range = line.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) {
                return PastedBlockPayload(type: .numberedList, text: String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return PastedBlockPayload(type: .paragraph, text: line)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let pv = textView as? DocumentPlaceholderTextView { pv.placeholderLabel.isHidden = true }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            let newText = textView.text ?? ""
            if parent.block.text != newText { parent.block.text = newText; parent.block.touch(); textView.invalidateIntrinsicContentSize() }
            if let pv = textView as? DocumentPlaceholderTextView { pv.placeholderLabel.isHidden = !newText.isEmpty }
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
