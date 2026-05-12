//
//  DocumentBlockPreviewPage.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData
import UIKit

struct DocumentBlockPreviewPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: DocumentEntry

    @State private var showDeleteConfirmation = false
    @State private var showEditorPage = false
    @State private var isCompletingAction = false
    @State private var hasPreparedPreview = false
    @State private var showBackgroundSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white

    var body: some View {
        ZStack {
            DocumentEntryBackground(entry: entry)

            ScrollView {
                DocumentPagedContentView(entry: entry)
                    .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showBackgroundSettingsSheet = true
                    } label: {
                        Label("Background", systemImage: "photo")
                    }
                    Button {
                        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !hex.isEmpty,
                           let r = UInt8(hex.prefix(2), radix: 16),
                           let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
                           let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) {
                            textColorPickerSelection = Color(
                                red: Double(r) / 255,
                                green: Double(g) / 255,
                                blue: Double(b) / 255
                            )
                        } else {
                            textColorPickerSelection = .white
                        }
                        showTextColorSheet = true
                    } label: {
                        Label("Text Color", systemImage: "textformat")
                    }
                } label: {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil || entry.book == nil)
                .opacity((isCompletingAction || entry.deletedAt != nil || entry.book == nil) ? 0.5 : 1)

                Button {
                    guard !isCompletingAction, entry.deletedAt == nil, entry.book != nil else { return }
                    showEditorPage = true
                } label: {
                    Text("Edit").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil || entry.book == nil)
                .opacity((isCompletingAction || entry.deletedAt != nil || entry.book == nil) ? 0.5 : 1)

                Button(role: .destructive) {
                    guard !isCompletingAction, entry.deletedAt == nil else { return }
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash").foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil)
                .opacity((isCompletingAction || entry.deletedAt != nil) ? 0.5 : 1)
            }
        }
        .navigationDestination(isPresented: $showEditorPage) {
            Group {
                if let book = entry.book, entry.deletedAt == nil {
                    DocumentBlockEditorPage(book: book, existingEntry: entry)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }
        .sheet(isPresented: $showBackgroundSettingsSheet) {
            DocumentBackgroundSettingsSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTextColorSheet) {
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
        .confirmationDialog("Delete this document?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Document", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the document from your book.")
        }
        .task {
            guard !hasPreparedPreview else { return }
            hasPreparedPreview = true
            if entry.book == nil || entry.deletedAt != nil {
                isCompletingAction = true
                dismiss()
                return
            }
            entry.ensureStarterBlock()
            entry.normalizeBlockSortOrders()
            try? modelContext.save()
        }
        .onDisappear { isCompletingAction = false }
    }

    private func deleteEntry() {
        guard !isCompletingAction, entry.deletedAt == nil else { return }
        isCompletingAction = true
        showDeleteConfirmation = false
        showEditorPage = false
        entry.deletedAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Unified paged content view
// Identity (cover + title + tags) + first content page share ONE glass card.
// Subsequent pages each get their own glass card, matching the editor exactly.

private struct DocumentPagedContentView: View {
    let entry: DocumentEntry

    private var blockPages: [[DocumentBlock]] {
        var pages: [[DocumentBlock]] = [[]]
        var hiddenParentIDs = Set<UUID>()
        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                if block.isToggleBlock { hiddenParentIDs.insert(block.id) }
                continue
            }
            if block.isToggleBlock && !block.isExpanded { hiddenParentIDs.insert(block.id) }
            if block.type == .divider,
               (DividerStyles(rawValue: block.languageHint) ?? .line) == .pageBreak {
                pages.append([])
            } else {
                pages[pages.count - 1].append(block)
            }
        }
        return pages
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.34))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
    }

    var body: some View {
        let pages = blockPages
        VStack(alignment: .leading, spacing: 0) {
            // First card: identity + first page of content in ONE glass card
            glassCard {
                VStack(alignment: .leading, spacing: 0) {
                    DocumentIdentityHeaderView(entry: entry)
                    if let firstPage = pages.first, !firstPage.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(firstPage) { block in
                                DocumentBlockDisplayView(entry: entry, singleBlock: block)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .padding(.top, 16)

            // Subsequent pages: each get their own glass card
            if pages.count > 1 {
                ForEach(Array(pages.dropFirst().enumerated()), id: \.offset) { _, page in
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(page) { block in
                                DocumentBlockDisplayView(entry: entry, singleBlock: block)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Document Block Display View

struct DocumentBlockDisplayView: View {
    let entry: DocumentEntry
    /// When set, renders just this one block (used by DocumentPagedContentView).
    var singleBlock: DocumentBlock? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var selectedInlinePropertyForViewing: DocumentInlineProperty?

    private var resolvedTextColor: UIColor {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hex.isEmpty,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else {
            return UIColor(LColors.textPrimary)
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    private func blockGradient(for block: DocumentBlock) -> AnyShapeStyle {
        guard block.hasCustomBlockColor else { return AnyShapeStyle(LGradients.blue) }
        return AnyShapeStyle(LinearGradient(
            colors: [block.blockColor1, block.blockColor2],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    private func indentPadding(for block: DocumentBlock) -> CGFloat {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return CGFloat(block.indentLevel) * 20
        case .divider, .code, .image, .table:
            return 0
        }
    }

    private var wrapperSupportedTypes: [DocumentBlockType] {
        [.paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
         .toggle, .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
         .bulletedList, .numberedList, .checklist]
    }

    private func prefixWrapperAlignmentPadding(for block: DocumentBlock) -> CGFloat {
        block.isBlockquoteStyle || block.isCalloutStyle ? 12 : 0
    }

    // Split visible blocks into pages at .pageBreak dividers
    private var blockPages: [[DocumentBlock]] {
        var pages: [[DocumentBlock]] = [[]]
        for block in visibleBlocks {
            if block.type == .divider,
               (DividerStyles(rawValue: block.languageHint) ?? .line) == .pageBreak {
                pages.append([])
            } else {
                pages[pages.count - 1].append(block)
            }
        }
        return pages
    }

    var body: some View {
        if let block = singleBlock {
            // Single block mode — no card wrapping, used by DocumentPagedContentView
            renderBlock(block)
                .sheet(item: $selectedInlinePropertyForViewing) { property in
                    DocumentInlinePropertyViewSheet(property: property)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .preferredColorScheme(.dark)
                }
        } else {
            // Full paged mode — each page gets its own glass card
            let pages = blockPages
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(page) { block in
                                renderBlock(block)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(0.34))
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                    if index < pages.count - 1 {
                        Color.clear.frame(maxWidth: .infinity).frame(height: 8)
                    }
                }
            }
            .sheet(item: $selectedInlinePropertyForViewing) { property in
                DocumentInlinePropertyViewSheet(property: property)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: DocumentBlock) -> some View {
        switch block.type {
        case .paragraph:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading1:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 28, weight: .bold))
                    .padding(.top, 2)
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading2:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 22, weight: .bold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading3:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 18, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading4:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading5:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 14, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading6:
            styledContent(block) {
                documentTextBlock(block, font: .systemFont(ofSize: 13, weight: .medium))
                    .padding(.leading, indentPadding(for: block))
            }
        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(blockGradient(for: block)).frame(width: 4)
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, indentPadding(for: block))
        case .callout:
            HStack(alignment: .center, spacing: 12) {
                calloutIconView(for: activeCalloutIconItem(for: block))
                    .frame(width: 20, height: 20, alignment: .center)
                documentTextBlock(block, font: .systemFont(ofSize: 15, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient(for: block), lineWidth: 5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, indentPadding(for: block))
        case .toggle:
            Button { block.isExpanded.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LGradients.blue)
                        .frame(width: 22, alignment: .leading)
                        .padding(.top, prefixWrapperAlignmentPadding(for: block))

                    styledContent(block) {
                        documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                    }
                }
                .padding(.leading, indentPadding(for: block))
            }
            .buttonStyle(.plain)
        case .toggleHeading1:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 28, weight: .bold))
        case .toggleHeading2:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 22, weight: .bold))
        case .toggleHeading3:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 18, weight: .semibold))
        case .toggleHeading4:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 16, weight: .semibold))
        case .toggleHeading5:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 14, weight: .semibold))
        case .toggleHeading6:
            toggleHeadingBlock(block, font: .systemFont(ofSize: 13, weight: .medium))
        case .bulletedList:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: bulletSymbolName(for: block.indentLevel))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 6 + prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text(numberPrefix(for: block))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 28, alignment: .leading)
                    .padding(.top, prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .checklist:
            HStack(alignment: .top, spacing: 10) {
                checklistPrefixButton(for: block)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 4 + prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .divider:
            dividerView(block: block, style: DividerStyles(rawValue: block.languageHint) ?? .line)
        case .code:
            let lang = CodeLanguage.from(block.languageHint)
            let theme = CodeTheme.from(block.calloutEmoji)
            let highlighted = CodeHighlighter.highlight(block.text, language: lang, theme: theme)
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(block.text.components(separatedBy: "\n").enumerated()), id: \.offset) { i, _ in
                            Text("\(i + 1)")
                                .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(theme.colors.comment))
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 8)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)

                    Text(AttributedString(highlighted))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                }
                .padding(12)

                Button {
                    UIPasteboard.general.string = block.text
                } label: {
                    Image("copyfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.white)
                        .frame(width: 15, height: 15)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(theme.colors.background))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        case .image:
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                let size = block.imageSize; let mode = block.imageDisplayMode
                Group {
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
                .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
            }
        case .table:
            DocumentTablePreviewView(block: block, resolvedTextColor: resolvedTextColor)
        }
    }

    @ViewBuilder
    private func dividerView(block: DocumentBlock, style: DividerStyles) -> some View {
        let grad = blockGradient(for: block)
        switch style {
        case .pageBreak:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity).frame(height: 1)
                Color.black.opacity(0.4)
                    .frame(maxWidth: .infinity).frame(height: 28)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity).frame(height: 1)
            }
            .padding(.vertical, 8)
        case .line:
            Capsule()
                .fill(grad)
                .frame(maxWidth: .infinity).frame(height: 3)
                .padding(.vertical, 4)
        case .dotted:
            let dotSize: CGFloat = 4
            let gap: CGFloat = 8
            GeometryReader { geo in
                let count = max(1, Int(geo.size.width / (dotSize + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle().fill(grad).frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).frame(height: dotSize)
            .padding(.vertical, 4)
        case .dash:
            Capsule()
                .fill(grad)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 0.5)
                .frame(height: 2)
                .padding(.vertical, 4)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(grad).frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func toggleHeadingBlock(_ block: DocumentBlock, font: UIFont) -> some View {
        Button { block.isExpanded.toggle() } label: {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: font.pointSize * 0.7, weight: .bold))
                    .foregroundStyle(LGradients.blue)
                    .frame(width: 16, alignment: .center)

                documentTextBlock(block, font: font)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, indentPadding(for: block))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func styledContent<Content: View>(_ block: DocumentBlock, @ViewBuilder content: () -> Content) -> some View {
        if !wrapperSupportedTypes.contains(block.type) {
            content()
        } else if block.isCalloutStyle {
            calloutStyleWrapper(block) {
                if block.isBlockquoteStyle {
                    blockquoteStyleWrapper(block) { content() }
                } else {
                    content()
                }
            }
        } else if block.isBlockquoteStyle {
            blockquoteStyleWrapper(block) { content() }
        } else {
            content()
        }
    }

    private func blockquoteStyleWrapper<Content: View>(_ block: DocumentBlock, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(blockGradient(for: block))
                .frame(width: 4)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func calloutStyleWrapper<Content: View>(_ block: DocumentBlock, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            calloutIconView(for: activeCalloutIconItem(for: block))
                .frame(width: 20, height: 20, alignment: .center)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient(for: block), lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func activeCalloutIconItem(for block: DocumentBlock) -> BookmarkIconItem {
        let trimmed = block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item = BookmarkCombinedIconLibrary.all.first(where: { $0.id == trimmed }) { return item }
        if let legacyAsset = BookmarkAssetIconLibrary.all.first(where: { $0.name == trimmed }) { return legacyAsset }
        if let legacySystem = BookmarkIconLibrary.all.first(where: { $0.name == trimmed }) { return legacySystem }
        return BookmarkAssetIconLibrary.all.first ?? BookmarkIconLibrary.all.first ?? BookmarkIconItem(name: "sparkles", source: .system)
    }

    @ViewBuilder
    private func calloutIconView(for item: BookmarkIconItem) -> some View {
        switch item.source {
        case .asset:
            Image(item.name).renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color.white)
        case .system:
            Image(systemName: item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.white)
        }
    }

    private func documentTextBlock(_ block: DocumentBlock, font: UIFont) -> AnyView {
        if let onlyProperty = block.inlineProperties?.first,
           block.inlineProperties?.count == 1,
           onlyProperty.type == .url,
           onlyProperty.rangeLocation == 0,
           onlyProperty.rangeLength == (block.text as NSString).length {
            return AnyView(urlPropertyButton(for: onlyProperty, font: font))
        }
        let mutable = NSMutableAttributedString(string: block.text, attributes: [
            .font: font,
            .foregroundColor: resolvedTextColor
        ])
        let fullLength = (block.text as NSString).length
        var propertyTapRanges: [InlinePropertyTapRange] = []
        if fullLength > 0 {
            let sortedProperties = (block.inlineProperties ?? []).sorted { $0.rangeLocation > $1.rangeLocation }
            for property in sortedProperties {
                let raw = property.safeRange
                let currentLength = (mutable.string as NSString).length
                let maxLen = max(0, currentLength - raw.location)
                let clamped = min(raw.length, maxLen)
                guard raw.location >= 0, raw.location < currentLength, clamped > 0 else { continue }
                let range = NSRange(location: raw.location, length: clamped)
                let replacement = attributedInlinePropertyText(for: property, baseFont: font)
                mutable.replaceCharacters(in: range, with: replacement)
                propertyTapRanges.append(InlinePropertyTapRange(property: property, range: NSRange(location: raw.location, length: replacement.length)))
            }
            for style in block.sortedInlineStyles {
                let raw = style.safeRange
                let maxLen = max(0, fullLength - raw.location)
                let clamped = min(raw.length, maxLen)
                guard raw.location >= 0, raw.location < fullLength, clamped > 0 else { continue }
                let range = NSRange(location: raw.location, length: clamped)
                switch style.type {
                case .bold:
                    mutable.enumerateAttribute(.font, in: range) { v, r, _ in
                        let f = (v as? UIFont) ?? font
                        if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitBold)) {
                            mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: r)
                        }
                    }
                case .italic:
                    mutable.enumerateAttribute(.font, in: range) { v, r, _ in
                        let f = (v as? UIFont) ?? font
                        if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                            mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: r)
                        }
                    }
                case .underline:
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .strikethrough:
                    mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .link:
                    let t = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty, let url = URL(string: t) {
                        mutable.addAttribute(.link, value: url, range: range)
                        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    }
                case .inlineCode:
                    let mono = UIFont.monospacedSystemFont(ofSize: font.pointSize * 0.9, weight: .regular)
                    mutable.addAttribute(.font, value: mono, range: range)
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
                        let blended = UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
                        mutable.addAttribute(.foregroundColor, value: blended, range: NSRange(location: range.location + i, length: 1))
                    }
                }
            }
        }
        if block.type == .checklist && !checklistState(for: block).isEmpty && fullLength > 0 {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }
        return AnyView(
            TappableRichBlockTextView(
                attributedText: mutable,
                isSelectable: true,
                linkTintColor: UIColor.systemBlue,
                propertyTapRanges: propertyTapRanges,
                onPropertyTap: { property in selectedInlinePropertyForViewing = property }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        )
    }

    private func urlPropertyButton(for property: DocumentInlineProperty, font: UIFont) -> some View {
        let trimmedName = property.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? property.type.rawValue : trimmedName
        let value = property.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = value.isEmpty ? name : "\(name): Open"
        return Button {
            if let url = normalizedURL(from: value) { UIApplication.shared.open(url) }
            else { selectedInlinePropertyForViewing = property }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: max(10, font.pointSize * 0.68), weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .fixedSize(horizontal: true, vertical: false)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    private func attributedInlinePropertyText(for property: DocumentInlineProperty, baseFont: UIFont) -> NSAttributedString {
        let trimmedName = property.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? property.type.rawValue : trimmedName
        let value = inlinePropertyValueText(for: property)
        if property.type == .checkbox { return attributedCheckboxInlinePropertyText(for: property, name: name, baseFont: baseFont) }
        let fullText = value.isEmpty ? name : "\(name): \(value)"
        let attributed = NSMutableAttributedString(string: fullText, attributes: [.font: baseFont, .foregroundColor: resolvedTextColor])
        let nsText = fullText as NSString
        let boldRange = nsText.range(of: name)
        if boldRange.location != NSNotFound {
            attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold), range: boldRange)
        }
        applyInlinePropertyValueColors(to: attributed, property: property, value: value, fullText: fullText)
        return attributed
    }

    private func attributedCheckboxInlinePropertyText(for property: DocumentInlineProperty, name: String, baseFont: UIFont) -> NSAttributedString {
        let symbol = property.valueStorage == "true" ? "●" : "○"
        let fullText = "\(name)    \(symbol)"
        let attributed = NSMutableAttributedString(string: fullText, attributes: [.font: baseFont, .foregroundColor: UIColor(LColors.textSecondary)])
        let symbolRange = (fullText as NSString).range(of: symbol)
        if symbolRange.location != NSNotFound {
            attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: baseFont.pointSize + 2, weight: .regular), range: symbolRange)
            attributed.addAttribute(.foregroundColor, value: property.valueStorage == "true" ? UIColor(LColors.accent) : UIColor(LColors.textSecondary), range: symbolRange)
        }
        return attributed
    }

    private func applyInlinePropertyValueColors(to attributed: NSMutableAttributedString, property: DocumentInlineProperty, value: String, fullText: String) {
        guard !value.isEmpty else { return }
        let nsText = fullText as NSString
        if property.type == .multiSelect {
            let selectedValues = decodeStringArray(property.valueStorage)
            let options = decodePropertyOptions(property.optionsStorage)
            for selectedValue in selectedValues {
                let valueRange = nsText.range(of: selectedValue)
                guard valueRange.location != NSNotFound else { continue }
                let optionColor = options.first(where: { $0.name == selectedValue })?.colorHex ?? property.colorHex
                attributed.addAttribute(.foregroundColor, value: inlinePropertyValueColor(hex: optionColor), range: valueRange)
            }
            return
        }
        let valueRange = nsText.range(of: value)
        guard valueRange.location != NSNotFound else { return }
        if property.type == .select {
            let options = decodePropertyOptions(property.optionsStorage)
            let optionColor = options.first(where: { $0.name == value })?.colorHex ?? property.colorHex
            attributed.addAttribute(.foregroundColor, value: inlinePropertyValueColor(hex: optionColor), range: valueRange)
        } else {
            attributed.addAttribute(.foregroundColor, value: inlinePropertyValueColor(hex: property.colorHex), range: valueRange)
        }
    }

    private func inlinePropertyValueText(for property: DocumentInlineProperty) -> String {
        switch property.type {
        case .boolean: return property.valueStorage == "true" ? "True" : "False"
        case .checkbox: return property.valueStorage == "true" ? "Checked" : "Unchecked"
        case .text, .number, .url, .select: return property.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date:
            guard let date = ISO8601DateFormatter().date(from: property.valueStorage) else { return "" }
            return date.formatted(date: .abbreviated, time: .omitted)
        case .multiSelect:
            guard let data = property.valueStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([String].self, from: data) else { return "" }
            return values.joined(separator: ", ")
        }
    }

    private func uiColorFromHex(_ hex: String) -> UIColor? {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return UIColor(red: CGFloat((val >> 16) & 0xFF) / 255, green: CGFloat((val >> 8) & 0xFF) / 255, blue: CGFloat(val & 0xFF) / 255, alpha: 1)
    }

    private func inlinePropertyValueColor(hex: String) -> UIColor {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let color = UIColor(hexString: trimmed) else { return resolvedTextColor }
        return color
    }

    private func decodeStringArray(_ storage: String) -> [String] {
        guard let data = storage.data(using: .utf8), let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return decoded
    }

    private func decodePropertyOptions(_ storage: String) -> [DocumentPropertyOptionDraft] {
        guard let data = storage.data(using: .utf8) else { return [] }
        if let decoded = try? JSONDecoder().decode([DocumentPropertyOptionDraft].self, from: data) { return decoded }
        if let legacy = try? JSONDecoder().decode([String].self, from: data) { return legacy.map { DocumentPropertyOptionDraft(name: $0, colorHex: "") } }
        return []
    }

    private var visibleBlocks: [DocumentBlock] {
        var hiddenParentIDs = Set<UUID>()
        var result: [DocumentBlock] = []
        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                if block.isToggleBlock { hiddenParentIDs.insert(block.id) }
                continue
            }
            result.append(block)
            if block.isToggleBlock && !block.isExpanded { hiddenParentIDs.insert(block.id) }
        }
        return result
    }

    private func numberPrefix(for block: DocumentBlock) -> String {
        guard block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter { $0.type == .numberedList && $0.listGroupID == groupID && $0.indentLevel == block.indentLevel }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func checklistPrefixButton(for block: DocumentBlock) -> some View {
        checklistPrefixIcon(for: block)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                block.languageHint = "xmark"; block.touch(); try? modelContext.save()
            }
            .onTapGesture {
                let state = checklistState(for: block)
                block.languageHint = state == "checked" ? "" : "checked"
                block.touch(); try? modelContext.save()
            }
    }

    @ViewBuilder
    private func checklistPrefixIcon(for block: DocumentBlock) -> some View {
        switch checklistState(for: block) {
        case "checked":
            ZStack {
                Circle().fill(LGradients.blue).frame(width: 17, height: 17)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.white)
            }
        case "xmark":
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 17, height: 17).overlay(Circle().stroke(LGradients.blue, lineWidth: 1.3))
                Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundStyle(Color.white)
            }
        default:
            Circle().stroke(LColors.textSecondary, lineWidth: 1.4).frame(width: 17, height: 17)
        }
    }

    private func checklistState(for block: DocumentBlock) -> String {
        block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bulletSymbolName(for indentLevel: Int) -> String {
        indentLevel % 2 == 1 ? "circle" : "circle.fill"
    }
}

private struct InlinePropertyTapRange {
    let property: DocumentInlineProperty
    let range: NSRange
}

private struct TappableRichBlockTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let isSelectable: Bool
    let linkTintColor: UIColor
    let propertyTapRanges: [InlinePropertyTapRange]
    let onPropertyTap: (DocumentInlineProperty) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = isSelectable
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.linkTextAttributes = [.foregroundColor: linkTintColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.translatesAutoresizingMaskIntoConstraints = false
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        textView.addGestureRecognizer(tapRecognizer)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.isSelectable = isSelectable
        uiView.linkTextAttributes = [.foregroundColor: linkTintColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
        context.coordinator.propertyTapRanges = propertyTapRanges
        context.coordinator.onPropertyTap = onPropertyTap
        uiView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator { Coordinator(propertyTapRanges: propertyTapRanges, onPropertyTap: onPropertyTap) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 else {
            return CGSize(width: 1, height: max(1, ceil(uiView.font?.lineHeight ?? 18)))
        }
        let safeWidth = max(1, min(proposedWidth, UIScreen.main.bounds.width))
        let containerWidth = max(1, safeWidth - uiView.textContainerInset.left - uiView.textContainerInset.right)
        uiView.bounds = CGRect(x: 0, y: 0, width: safeWidth, height: 1)
        uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
        let measuredHeight = ceil(usedRect.height + uiView.textContainerInset.top + uiView.textContainerInset.bottom)
        let safeHeight = measuredHeight.isFinite ? max(1, measuredHeight) : max(1, ceil(uiView.font?.lineHeight ?? 18))
        return CGSize(width: safeWidth, height: safeHeight)
    }

    final class Coordinator: NSObject {
        var propertyTapRanges: [InlinePropertyTapRange]
        var onPropertyTap: (DocumentInlineProperty) -> Void
        init(propertyTapRanges: [InlinePropertyTapRange], onPropertyTap: @escaping (DocumentInlineProperty) -> Void) {
            self.propertyTapRanges = propertyTapRanges
            self.onPropertyTap = onPropertyTap
        }
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            guard let textView = recognizer.view as? UITextView else { return }
            guard let property = inlineProperty(at: recognizer.location(in: textView), in: textView) else { return }
            onPropertyTap(property)
        }
        private func inlineProperty(at point: CGPoint, in textView: UITextView) -> DocumentInlineProperty? {
            guard !propertyTapRanges.isEmpty, textView.textStorage.length > 0 else { return nil }
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let textStorage = textView.textStorage
            layoutManager.ensureLayout(for: textContainer)
            var adjustedPoint = point
            adjustedPoint.x -= textView.textContainerInset.left
            adjustedPoint.y -= textView.textContainerInset.top
            let glyphIndex = layoutManager.glyphIndex(for: adjustedPoint, in: textContainer)
            guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }
            let tappedGlyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer).insetBy(dx: -3, dy: -4)
            guard tappedGlyphRect.contains(adjustedPoint) else { return nil }
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            for tapRange in propertyTapRanges {
                guard tapRange.range.location >= 0, tapRange.range.length > 0, tapRange.range.location < textStorage.length else { continue }
                let safeLength = min(tapRange.range.length, textStorage.length - tapRange.range.location)
                let safeRange = NSRange(location: tapRange.range.location, length: safeLength)
                guard characterIndex >= safeRange.location, characterIndex < safeRange.location + safeRange.length else { continue }
                let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
                let propertyRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).insetBy(dx: -3, dy: -4)
                if propertyRect.contains(adjustedPoint) { return tapRange.property }
            }
            return nil
        }
    }
}

private extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255.0, green: CGFloat((value >> 8) & 0xFF) / 255.0, blue: CGFloat(value & 0xFF) / 255.0, alpha: 1.0)
    }
}

// MARK: - Table Preview

struct DocumentTablePreviewView: View {
    let block: DocumentBlock
    let resolvedTextColor: UIColor

    private var tableData: DocumentTableData { DocumentTableData.from(block.text) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<tableData.rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<tableData.colCount, id: \.self) { col in
                            let isHeader = row == 0
                            let baseFont: UIFont = isHeader ? .systemFont(ofSize: 13, weight: .bold) : .systemFont(ofSize: 13, weight: .regular)
                            let attributed = tableData.attributedText(row: row, col: col, baseFont: baseFont, textColor: resolvedTextColor)
                            AttributedTextView(attributed: attributed)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .frame(minWidth: 80, maxWidth: 200, alignment: .leading)
                                .background({
                                    let bgHex = tableData.cellBgColor(row: row, col: col)
                                    if !bgHex.isEmpty, let bg = uiColorFromHex(bgHex) { return Color(bg) }
                                    else if isHeader { return Color.white.opacity(0.06) }
                                    else { return Color.clear }
                                }())
                            if col < tableData.colCount - 1 {
                                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if row < tableData.rowCount - 1 {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func uiColorFromHex(_ hex: String) -> UIColor? {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return UIColor(red: CGFloat((val >> 16) & 0xFF) / 255, green: CGFloat((val >> 8) & 0xFF) / 255, blue: CGFloat(val & 0xFF) / 255, alpha: 1)
    }
}

private struct AttributedTextView: UIViewRepresentable {
    let attributed: NSAttributedString
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear; tv.isEditable = false; tv.isScrollEnabled = false
        tv.textContainerInset = .zero; tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributed { uiView.attributedText = attributed; uiView.invalidateIntrinsicContentSize() }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = min(proposal.width ?? 120, 200)
        let fitting = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: max(80, w), height: max(1, fitting.height))
    }
}
