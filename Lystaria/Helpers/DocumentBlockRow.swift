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

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showLinkEditor = false
    @State private var linkDraft = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if supportsInlineFormatting && selectedRange.length > 0 {
                selectionFormatMenu
            }
            VStack(alignment: .leading, spacing: 6) {
                contentColumn
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Format Menu

    private var selectionFormatMenu: some View {
        Menu {
            Button(rangeHasStyle(.bold) ? "Remove Bold" : "Bold") { toggleInlineStyle(.bold) }
            Button(rangeHasStyle(.italic) ? "Remove Italic" : "Italic") { toggleInlineStyle(.italic) }
            Button(rangeHasStyle(.underline) ? "Remove Underline" : "Underline") { toggleInlineStyle(.underline) }
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
                        onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if block.type == .toggle || block.type == .bulletedList || block.type == .numberedList {
                HStack(alignment: .top, spacing: 10) {
                    if block.type == .toggle {
                        Button {
                            block.isExpanded.toggle()
                            block.touch()
                        } label: {
                            prefixView(for: block).frame(width: 22, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    } else {
                        prefixView(for: block).frame(width: 22, alignment: .leading)
                    }
                    DocumentRichEditableBlockTextView(
                        block: block, selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: UIColor(LColors.textPrimary),
                        placeholder: placeholderText, isCodeBlock: false,
                        onCreateParagraphBelow: { suffix in onAddBelow(block, nextBlockTypeOnReturn(for: block.type), suffix) },
                        onDeleteEmptyBlock: { onDelete(block) },
                        onExitList: { onAddBelow(block, .paragraph, ""); onDelete(block) }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            } else {
                DocumentRichEditableBlockTextView(
                    block: block, selectedRange: $selectedRange,
                    baseUIFont: uiFontForBlockType(block.type),
                    textColor: UIColor(LColors.textPrimary),
                    placeholder: placeholderText, isCodeBlock: false,
                    onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                    onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            }
        }
    }

    // MARK: - Callout Editor

    private var calloutEditor: some View {
        HStack(alignment: .center, spacing: 6) {
            TextField("✦", text: $block.calloutEmoji)
                .textFieldStyle(.plain)
                .frame(width: 22)
                .onChange(of: block.calloutEmoji) { block.touch() }
            DocumentRichEditableBlockTextView(
                block: block, selectedRange: $selectedRange,
                baseUIFont: UIFont.systemFont(ofSize: 15, weight: .regular),
                textColor: UIColor(LColors.textPrimary),
                placeholder: "Write callout...", isCodeBlock: false,
                onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Divider Editor

    private var dividerEditor: some View {
        let current = DividerStyle(rawValue: block.languageHint) ?? .line
        return dividerPreview(style: current)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                let all = DividerStyle.allCases
                let next = all[(all.firstIndex(of: current)! + 1) % all.count]
                block.languageHint = next.rawValue
                block.touch()
            }
    }

    @ViewBuilder
    private func dividerPreview(style: DividerStyle) -> some View {
        switch style {
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
            DocumentRichEditableBlockTextView(
                block: block, selectedRange: $selectedRange,
                baseUIFont: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular),
                textColor: UIColor(LColors.textPrimary),
                placeholder: "Write code...", isCodeBlock: true,
                onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil
            )
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
             .toggle, .bulletedList, .numberedList, .blockquote, .callout: return true
        case .divider, .code, .image: return false
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
            Image(systemName: "circle.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(LColors.textPrimary).padding(.top, 6)
        case .numberedList:
            Text(numberPrefix(for: block))
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(LColors.textPrimary)
        default: EmptyView()
        }
    }

    private func numberPrefix(for block: DocumentBlock) -> String {
        guard let entry = block.entry, block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter { $0.type == .numberedList && $0.listGroupID == groupID }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func nextBlockTypeOnReturn(for type: DocumentBlockType) -> DocumentBlockType {
        switch type {
        case .toggle: return .paragraph
        case .bulletedList: return .bulletedList
        case .numberedList: return .numberedList
        default: return .paragraph
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
        return mutable
    }

    final class DocumentPlaceholderTextView: UITextView {
        let placeholderLabel = UILabel()
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
                placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
            ])
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DocumentRichEditableBlockTextView
        var isApplyingProgrammaticChange = false
        var onCreateParagraphBelow: ((String) -> Void)?
        var onDeleteEmptyBlock: (() -> Void)?
        var onExitList: (() -> Void)?

        init(parent: DocumentRichEditableBlockTextView) {
            self.parent = parent
            self.onCreateParagraphBelow = parent.onCreateParagraphBelow
            self.onDeleteEmptyBlock = parent.onDeleteEmptyBlock
            self.onExitList = parent.onExitList
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            parent.selectedRange = textView.selectedRange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingProgrammaticChange else { return true }
            if text.isEmpty {
                let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isEmpty { onDeleteEmptyBlock?(); return false }
            }
            guard text == "\n", range.length == 0 else { return true }
            if parent.isCodeBlock { return true }

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
