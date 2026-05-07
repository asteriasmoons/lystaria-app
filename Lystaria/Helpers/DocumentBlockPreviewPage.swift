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

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !entry.title.isEmpty {
                        GradientTitle(text: entry.title, font: .title.bold())
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, entry.tags.isEmpty ? 16 : 10)
                    }

                    if !entry.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image("tagsparkle")
                                        .resizable().renderingMode(.template)
                                        .scaledToFit().frame(width: 16, height: 16)
                                        .foregroundStyle(.white)
                                    Text(tag).font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }

                    DocumentBlockDisplayView(entry: entry)
                }
            }
        }
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Document")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
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

// MARK: - Document Block Display View

struct DocumentBlockDisplayView: View {
    let entry: DocumentEntry
    @Environment(\.modelContext) private var modelContext

    private func indentPadding(for block: DocumentBlock) -> CGFloat {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return CGFloat(block.indentLevel) * 20
        case .divider, .code, .image:
            return 0
        }
    }

    private var wrapperSupportedTypes: [DocumentBlockType] {
        [.paragraph, .heading1, .heading2, .heading3, .heading4, .toggle, .bulletedList, .numberedList, .checklist]
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
        let pages = blockPages
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in

                // Outer page spacing
                VStack(spacing: 0) {
                    // Floating page sheet
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
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                // Page break gap
                if index < pages.count - 1 {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                }
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
        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(LGradients.blue).frame(width: 4)
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, indentPadding(for: block))
        case .callout:
            HStack(alignment: .center, spacing: 12) {
                calloutIconView(for: activeCalloutIconItem(for: block))
                    .frame(width: 20, height: 20, alignment: .center)
                documentTextBlock(block, font: .systemFont(ofSize: 15, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
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
            dividerView(style: DividerStyles(rawValue: block.languageHint) ?? .line)
        case .code:
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    if !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(block.languageHint.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.trailing, 40)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(codeLines(for: block).enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(index + 1)")
                                    .font(.system(size: codePreviewUIFont.pointSize, weight: .regular, design: .monospaced))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.58))
                                    .frame(width: codeGutterWidth(for: block), alignment: .trailing)
                                    .padding(.trailing, 8)

                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)

                                Text(line.isEmpty ? " " : line)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(LColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 36)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                .accessibilityLabel("Copy code")
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
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
        }
    }
    
    
    @ViewBuilder
    private func dividerView(style: DividerStyles) -> some View {
        switch style {
        case .pageBreak:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)

                Color.black.opacity(0.4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

        case .line:
            Capsule()
                .fill(LGradients.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 3)
                .padding(.vertical, 4)

        case .dotted:
            let dotSize: CGFloat = 4
            let gap: CGFloat = 8

            GeometryReader { geo in
                let count = max(1, Int(geo.size.width / (dotSize + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(LGradients.blue)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dotSize)
            .padding(.vertical, 4)

        case .dash:
            Capsule()
                .fill(LGradients.blue)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 0.5)
                .frame(height: 2)
                .padding(.vertical, 4)

        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(LGradients.blue)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private var codePreviewUIFont: UIFont {
        UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
    }

    private func codeLines(for block: DocumentBlock) -> [String] {
        let lines = block.text.components(separatedBy: "\n")
        return lines.isEmpty ? [""] : lines
    }

    private func codeLineCount(for block: DocumentBlock) -> Int {
        max(1, codeLines(for: block).count)
    }

    private func codeGutterWidth(for block: DocumentBlock) -> CGFloat {
        let digits = String(codeLineCount(for: block)).count
        return CGFloat(max(1, digits)) * 8 + 4
    }

    @ViewBuilder
    private func styledContent<Content: View>(_ block: DocumentBlock, @ViewBuilder content: () -> Content) -> some View {
        if !wrapperSupportedTypes.contains(block.type) {
            content()
        } else if block.isCalloutStyle {
            calloutStyleWrapper(block) {
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

    private func calloutStyleWrapper<Content: View>(_ block: DocumentBlock, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            calloutIconView(for: activeCalloutIconItem(for: block))
                .frame(width: 20, height: 20, alignment: .center)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func activeCalloutIconItem(for block: DocumentBlock) -> BookmarkIconItem {
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

    private func documentTextBlock(_ block: DocumentBlock, font: UIFont) -> some View {
        let mutable = NSMutableAttributedString(string: block.text, attributes: [
            .font: font,
            .foregroundColor: UIColor(LColors.textPrimary)
        ])
        let fullLength = (block.text as NSString).length
        if fullLength > 0 {
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
                }
            }
        }
        if block.type == .checklist && !checklistState(for: block).isEmpty && fullLength > 0 {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }
        return RichBlockTextView(attributedText: mutable, isSelectable: true, linkTintColor: UIColor.systemBlue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
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
        let siblings = entry.sortedBlocks.filter {
            $0.type == .numberedList &&
            $0.listGroupID == groupID &&
            $0.indentLevel == block.indentLevel
        }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func checklistPrefixButton(for block: DocumentBlock) -> some View {
        checklistPrefixIcon(for: block)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                block.languageHint = "xmark"
                block.touch()
                try? modelContext.save()
            }
            .onTapGesture {
                let state = checklistState(for: block)
                block.languageHint = state == "checked" ? "" : "checked"
                block.touch()
                try? modelContext.save()
            }
    }

    @ViewBuilder
    private func checklistPrefixIcon(for block: DocumentBlock) -> some View {
        switch checklistState(for: block) {
        case "checked":
            ZStack {
                Circle()
                    .fill(LGradients.blue)
                    .frame(width: 17, height: 17)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.white)
            }
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
        default:
            Circle()
                .stroke(LColors.textSecondary, lineWidth: 1.4)
                .frame(width: 17, height: 17)
        }
    }

    private func checklistState(for block: DocumentBlock) -> String {
        block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bulletSymbolName(for indentLevel: Int) -> String {
        indentLevel % 2 == 1 ? "circle" : "circle.fill"
    }
}

private struct CodeBlockPreviewTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let lineNumberColor: UIColor

    func makeUIView(context: Context) -> CodeLineNumberTextView {
        let textView = CodeLineNumberTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 42, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.alwaysBounceHorizontal = false
        textView.showsHorizontalScrollIndicator = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.font = font
        textView.textColor = textColor
        textView.codeLineNumberFont = font
        textView.codeLineNumberColor = lineNumberColor
        textView.text = text.isEmpty ? " " : text
        return textView
    }

    func updateUIView(_ uiView: CodeLineNumberTextView, context: Context) {
        uiView.font = font
        uiView.textColor = textColor
        uiView.codeLineNumberFont = font
        uiView.codeLineNumberColor = lineNumberColor
        uiView.textContainerInset = UIEdgeInsets(top: 0, left: 42, bottom: 0, right: 0)
        uiView.textContainer.lineBreakMode = .byCharWrapping

        let newText = text.isEmpty ? " " : text
        if uiView.text != newText {
            uiView.text = newText
        }

        uiView.invalidateIntrinsicContentSize()
        uiView.setNeedsDisplay()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CodeLineNumberTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        uiView.bounds.size.width = width
        uiView.textContainer.size = CGSize(
            width: max(1, width - uiView.textContainerInset.left - uiView.textContainerInset.right),
            height: .greatestFiniteMagnitude
        )
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)

        let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
        let height = ceil(usedRect.height + uiView.textContainerInset.top + uiView.textContainerInset.bottom)

        return CGSize(width: width, height: max(height, uiView.font?.lineHeight ?? 18))
    }

    final class CodeLineNumberTextView: UITextView {
        var codeLineNumberFont: UIFont = .monospacedSystemFont(ofSize: 16, weight: .regular)
        var codeLineNumberColor: UIColor = .secondaryLabel
        private let codeLineNumberWidth: CGFloat = 34

        override var intrinsicContentSize: CGSize {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            return CGSize(width: UIView.noIntrinsicMetric, height: ceil(usedRect.height + textContainerInset.top + textContainerInset.bottom))
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            super.draw(rect)
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

            if glyphRange.length == 0 {
                ("1" as NSString).draw(
                    in: CGRect(x: 0, y: textContainerInset.top, width: codeLineNumberWidth, height: codeLineNumberFont.lineHeight),
                    withAttributes: attributes
                )
                return
            }

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
        }
    }
}
