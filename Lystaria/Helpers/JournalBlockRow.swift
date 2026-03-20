//
//  JournalBlockRow.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//


import SwiftUI
import SwiftData
import UIKit

private extension Notification.Name {
    static let journalBlockRequestFocusNextParagraph = Notification.Name("JournalBlockRequestFocusNextParagraph")
}

struct JournalBlockRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: JournalBlock

    var onAddBelow: (JournalBlock, JournalBlockType) -> Void
    var onDelete: (JournalBlock) -> Void
    var onMoveUp: (JournalBlock) -> Void
    var onMoveDown: (JournalBlock) -> Void
    var onTransform: (JournalBlock, JournalBlockType) -> Void

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showLinkEditor = false
    @State private var linkDraft = ""

    @FocusState private var isFocused: Bool

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
        .padding(.vertical, 1)
        .alert("Insert Link", isPresented: $showLinkEditor) {
            TextField("https://example.com", text: $linkDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                linkDraft = ""
            }

            Button("Apply") {
                applyLinkFromDraft()
            }
        } message: {
            Text("Select text in the block first, then add a link.")
        }
    }



    private var selectionFormatMenu: some View {
        Menu {
            Button(rangeHasStyle(.bold) ? "Remove Bold" : "Bold") {
                toggleInlineStyle(.bold)
            }

            Button(rangeHasStyle(.italic) ? "Remove Italic" : "Italic") {
                toggleInlineStyle(.italic)
            }

            Button(rangeHasStyle(.underline) ? "Remove Underline" : "Underline") {
                toggleInlineStyle(.underline)
            }

            Button(rangeHasStyle(.link) ? "Edit Link" : "Add Link") {
                prepareLinkEditor()
            }
        } label: {
            Text("Format")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LGradients.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(LGradients.blue, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }


    @ViewBuilder
    private var contentColumn: some View {
        switch block.type {
        case .divider:
            dividerEditor

        case .code:
            codeEditor

        case .callout:
            calloutEditor

        case .paragraph, .heading1, .heading2, .heading3, .heading4, .toggle, .bulletedList, .numberedList, .blockquote:
            textEditor
        }
    }

    private var textEditor: some View {
        Group {
            if block.type == .blockquote {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LGradients.blue)
                        .frame(width: 4)

                    RichEditableBlockTextView(
                        block: block,
                        selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: uiColorForBlockType(block.type),
                        placeholder: placeholderText,
                        isCodeBlock: false,
                        onCreateParagraphBelow: { onAddBelow(block, .paragraph) },
                        onDeleteEmptyBlock: { onDelete(block) }
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
                            prefixView(for: block)
                                .frame(width: 22, alignment: .leading)
                                .padding(.top, 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        prefixView(for: block)
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, 10)
                    }

                    RichEditableBlockTextView(
                        block: block,
                        selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: uiColorForBlockType(block.type),
                        placeholder: placeholderText,
                        isCodeBlock: false,
                        onCreateParagraphBelow: { onAddBelow(block, nextBlockTypeOnReturn(for: block.type)) },
                        onDeleteEmptyBlock: { onDelete(block) }
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            } else {
                RichEditableBlockTextView(
                    block: block,
                    selectedRange: $selectedRange,
                    baseUIFont: uiFontForBlockType(block.type),
                    textColor: uiColorForBlockType(block.type),
                    placeholder: placeholderText,
                    isCodeBlock: false,
                    onCreateParagraphBelow: { onAddBelow(block, .paragraph) },
                    onDeleteEmptyBlock: { onDelete(block) }
                )
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundForBlockType(block.type))
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            }
        }
    }

    private var calloutEditor: some View {
        HStack(alignment: .top, spacing: 6) {
            TextField("✦", text: $block.calloutEmoji)
                .textFieldStyle(.plain)
                .frame(width: 22)
                .onChange(of: block.calloutEmoji) {
                    block.touch()
                }

            RichEditableBlockTextView(
                block: block,
                selectedRange: $selectedRange,
                baseUIFont: UIFont.systemFont(ofSize: 15, weight: .regular),
                textColor: UIColor(LColors.textPrimary),
                placeholder: "Write callout...",
                isCodeBlock: false,
                onCreateParagraphBelow: { onAddBelow(block, .paragraph) }
                , onDeleteEmptyBlock: { onDelete(block) }
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LGradients.blue, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var dividerEditor: some View {
        HStack {
            Capsule()
                .fill(LGradients.blue)
                .frame(height: 3)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
    }

    private var codeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Language", text: $block.languageHint)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .onChange(of: block.languageHint) {
                    block.touch()
                }

            RichEditableBlockTextView(
                block: block,
                selectedRange: $selectedRange,
                baseUIFont: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular),
                textColor: UIColor(LColors.textPrimary),
                placeholder: "Write code...",
                isCodeBlock: true,
                onCreateParagraphBelow: nil
                , onDeleteEmptyBlock: { onDelete(block) }
            )
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }


    private var supportsInlineFormatting: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .toggle, .bulletedList, .numberedList, .blockquote, .callout:
            return true
        case .divider, .code:
            return false
        }
    }

    private func inlineToolButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(selectedRange.length == 0)
        .opacity(selectedRange.length == 0 ? 0.45 : 1)
    }

    private func inlineToolIconButton(_ systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(selectedRange.length == 0)
        .opacity(selectedRange.length == 0 ? 0.45 : 1)
    }

    private func rangeHasStyle(_ style: JournalInlineStyleType) -> Bool {
        guard selectedRange.length > 0 else { return false }

        return (block.inlineStyles ?? []).contains {
            $0.type == style && NSEqualRanges($0.safeRange, selectedRange)
        }
    }

    private func toggleInlineStyle(_ style: JournalInlineStyleType) {
        guard selectedRange.length > 0 else { return }
        guard block.type != .code, block.type != .divider else { return }

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == style && NSEqualRanges($0.safeRange, selectedRange) }) {
            if let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
                let styleToDelete = block.inlineStyles?[idx]
                block.inlineStyles?.remove(at: idx)
                if let styleToDelete {
                    modelContext.delete(styleToDelete)
                }
                block.touch()
                return
            }
        }

        let newStyle = JournalInlineStyle(
            type: style,
            rangeLocation: selectedRange.location,
            rangeLength: selectedRange.length,
            urlString: ""
        )
        newStyle.block = block
        modelContext.insert(newStyle)
        if block.inlineStyles == nil {
            block.inlineStyles = []
        }
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
        guard selectedRange.length > 0 else {
            linkDraft = ""
            return
        }

        let trimmed = linkDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == .link && NSEqualRanges($0.safeRange, selectedRange) }),
           let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
            let styleToDelete = block.inlineStyles?[idx]
            block.inlineStyles?.remove(at: idx)
            if let styleToDelete {
                modelContext.delete(styleToDelete)
            }
        }

        if !trimmed.isEmpty {
            let newStyle = JournalInlineStyle(
                type: .link,
                rangeLocation: selectedRange.location,
                rangeLength: selectedRange.length,
                urlString: trimmed
            )
            newStyle.block = block
            modelContext.insert(newStyle)
            if block.inlineStyles == nil {
                block.inlineStyles = []
            }
            block.inlineStyles?.append(newStyle)
        }

        block.touch()
        linkDraft = ""
    }
    private func insertOrReplaceCurrentBlock(with type: JournalBlockType) {
        if isCurrentBlockEffectivelyEmpty {
            onTransform(block, type)
        } else {
            onAddBelow(block, type)
        }
    }

    private var isCurrentBlockEffectivelyEmpty: Bool {
        switch block.type {
        case .divider:
            return true
        case .callout:
            return block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .toggle, .bulletedList, .numberedList, .blockquote, .code:
            return block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func uiFontForBlockType(_ type: JournalBlockType) -> UIFont {
        switch type {
        case .heading1:
            return .systemFont(ofSize: 26, weight: .bold)
        case .heading2:
            return .systemFont(ofSize: 20, weight: .bold)
        case .heading3:
            return .systemFont(ofSize: 17, weight: .semibold)
        case .heading4:
            return .systemFont(ofSize: 15, weight: .semibold)
        case .blockquote:
            return .systemFont(ofSize: 16, weight: .medium)
        case .paragraph, .toggle, .bulletedList, .numberedList, .callout:
            return .systemFont(ofSize: 16, weight: .regular)
        case .divider:
            return .systemFont(ofSize: 16, weight: .regular)
        case .code:
            return .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        }
    }

    private func uiColorForBlockType(_ type: JournalBlockType) -> UIColor {
        switch type {
        case .heading1, .heading2, .heading3, .heading4, .paragraph, .toggle, .bulletedList, .numberedList, .callout, .code:
            return UIColor(LColors.textPrimary)
        case .blockquote:
            return UIColor(LColors.textPrimary)
        case .divider:
            return .clear
        }
    }

    private struct RichEditableBlockTextView: UIViewRepresentable {
        @Bindable var block: JournalBlock
        @Binding var selectedRange: NSRange

        let baseUIFont: UIFont
        let textColor: UIColor
        let placeholder: String
        let isCodeBlock: Bool
        let onCreateParagraphBelow: (() -> Void)?
        let onDeleteEmptyBlock: (() -> Void)?

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
            let width = proposal.width ?? uiView.bounds.width
            let targetWidth = max(0, width)
            let fitting = uiView.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
            let minimumHeight: CGFloat = isCodeBlock ? 64 : 44
            return CGSize(width: targetWidth, height: max(minimumHeight, fitting.height))
        }

        func makeUIView(context: Context) -> UITextView {
            let textView = PlaceholderTextView()
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

            if let placeholderTextView = uiView as? PlaceholderTextView {
                placeholderTextView.placeholderLabel.text = placeholder
                placeholderTextView.placeholderLabel.font = baseUIFont
                placeholderTextView.placeholderLabel.textColor = UIColor(LColors.textSecondary)
                placeholderTextView.placeholderLabel.isHidden = !(block.text.isEmpty && !uiView.isFirstResponder)
            }

            context.coordinator.parent = self
            context.coordinator.onCreateParagraphBelow = self.onCreateParagraphBelow
            context.coordinator.onDeleteEmptyBlock = self.onDeleteEmptyBlock
        }

        private func baseAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.alignment = .natural

            return [
                .font: baseUIFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph
            ]
        }

        private func buildAttributedText() -> NSAttributedString {
            let mutable = NSMutableAttributedString(
                string: block.text,
                attributes: baseAttributes().merging([
                    .foregroundColor: textColor
                ]) { _, new in new }
            )

            guard !isCodeBlock else { return mutable }

            let fullLength = (block.text as NSString).length
            guard fullLength > 0 else { return mutable }

            for style in block.sortedInlineStyles {
                let rawRange = style.safeRange
                let maxLength = max(0, fullLength - rawRange.location)
                let clampedLength = min(rawRange.length, maxLength)

                guard rawRange.location >= 0,
                      rawRange.location < fullLength,
                      clampedLength > 0 else { continue }

                let range = NSRange(location: rawRange.location, length: clampedLength)

                switch style.type {
                case .bold:
                    applyBold(to: mutable, range: range)
                case .italic:
                    applyItalic(to: mutable, range: range)
                case .underline:
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .link:
                    let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }
                    mutable.addAttribute(.link, value: url, range: range)
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            }

            return mutable
        }
        final class PlaceholderTextView: UITextView {
            let placeholderLabel = UILabel()

            override init(frame: CGRect, textContainer: NSTextContainer?) {
                super.init(frame: frame, textContainer: textContainer)
                configurePlaceholderLabel()
            }

            required init?(coder: NSCoder) {
                super.init(coder: coder)
                configurePlaceholderLabel()
            }

            private func configurePlaceholderLabel() {
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

        private func applyBold(to attributed: NSMutableAttributedString, range: NSRange) {
            attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let currentFont = (value as? UIFont) ?? baseUIFont
                let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitBold)
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: currentFont.pointSize), range: subrange)
                }
            }
        }

        private func applyItalic(to attributed: NSMutableAttributedString, range: NSRange) {
            attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let currentFont = (value as? UIFont) ?? baseUIFont
                let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitItalic)
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: currentFont.pointSize), range: subrange)
                }
            }
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            var parent: RichEditableBlockTextView
            var isApplyingProgrammaticChange = false

            // Stored separately so they always reflect the current block,
            // not the block captured when makeUIView was called.
            var onCreateParagraphBelow: (() -> Void)?
            var onDeleteEmptyBlock: (() -> Void)?

            init(parent: RichEditableBlockTextView) {
                self.parent = parent
                self.onCreateParagraphBelow = parent.onCreateParagraphBelow
                self.onDeleteEmptyBlock = parent.onDeleteEmptyBlock
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                guard !isApplyingProgrammaticChange else { return }
                parent.selectedRange = textView.selectedRange
            }

            func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
                guard !isApplyingProgrammaticChange else { return true }
                if text.isEmpty {
                    let currentText = textView.text ?? ""
                    let isEffectivelyEmpty = currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if isEffectivelyEmpty {
                        onDeleteEmptyBlock?()
                        return false
                    }
                }
                guard text == "\n", !parent.isCodeBlock else { return true }
                guard range.length == 0 else { return true }

                let currentText = textView.text ?? ""
                let nsText = currentText as NSString
                let isAtEnd = range.location == nsText.length
                guard isAtEnd else { return true }

                let priorIsNewline = range.location > 0 && nsText.substring(with: NSRange(location: range.location - 1, length: 1)) == "\n"
                guard priorIsNewline else { return true }

                var trimmed = currentText
                while trimmed.hasSuffix("\n") {
                    trimmed.removeLast()
                }

                isApplyingProgrammaticChange = true
                parent.block.text = trimmed
                parent.block.touch()
                textView.attributedText = parent.buildAttributedText()
                textView.typingAttributes = parent.baseAttributes()
                textView.selectedRange = NSRange(location: (trimmed as NSString).length, length: 0)
                if let placeholderTextView = textView as? PlaceholderTextView {
                    placeholderTextView.placeholderLabel.isHidden = !trimmed.isEmpty
                }
                isApplyingProgrammaticChange = false

                NotificationCenter.default.post(
                    name: .journalBlockRequestFocusNextParagraph,
                    object: parent.block.id
                )
                onCreateParagraphBelow?()
                return false
            }

            func textViewDidBeginEditing(_ textView: UITextView) {
                if let placeholderTextView = textView as? PlaceholderTextView {
                    placeholderTextView.placeholderLabel.isHidden = true
                }
            }

            func textViewDidChange(_ textView: UITextView) {
                guard !isApplyingProgrammaticChange else { return }

                let newText = textView.text ?? ""
                if parent.block.text != newText {
                    parent.block.text = newText
                    parent.block.touch()
                    textView.invalidateIntrinsicContentSize()
                }

                if let placeholderTextView = textView as? PlaceholderTextView {
                    placeholderTextView.placeholderLabel.isHidden = !newText.isEmpty
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

                if let placeholderTextView = textView as? PlaceholderTextView {
                    placeholderTextView.placeholderLabel.isHidden = !(parent.block.text.isEmpty)
                }
            }
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
        }
    }

    private func typeLabel(_ type: JournalBlockType) -> String {
        switch type {
        case .paragraph: return "Paragraph"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .toggle: return "Toggle"
        case .bulletedList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .blockquote: return "Blockquote"
        case .callout: return "Callout"
        case .divider: return "Divider"
        case .code: return "Code Block"
        }
    }

    private func fontForBlockType(_ type: JournalBlockType) -> Font {
        switch type {
        case .heading1:
            return .system(size: 26, weight: .bold)
        case .heading2:
            return .system(size: 20, weight: .bold)
        case .heading3:
            return .system(size: 17, weight: .semibold)
        case .heading4:
            return .system(size: 15, weight: .semibold)
        case .blockquote:
            return .system(size: 16)
        case .paragraph, .toggle, .bulletedList, .numberedList, .callout:
            return .system(size: 16)
        case .divider:
            return .system(size: 16)
        case .code:
            return .system(.body, design: .monospaced)
        }
    }

    private func textColorForBlockType(_ type: JournalBlockType) -> Color {
        switch type {
        case .heading1, .heading2, .heading3, .heading4, .paragraph, .toggle, .bulletedList, .numberedList, .callout, .code:
            return LColors.textPrimary
        case .blockquote:
            return LColors.textPrimary
        case .divider:
            return .clear
        }
    }

    private func prefixText(for block: JournalBlock) -> String {
        switch block.type {
        case .toggle:
            return block.isExpanded ? "▾" : "▸"
        case .bulletedList:
            return "•"
        case .numberedList:
            return numberPrefix(for: block)
        default:
            return ""
        }
    }

    @ViewBuilder
    private func prefixView(for block: JournalBlock) -> some View {
        switch block.type {
        case .toggle:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LGradients.blue)
        case .bulletedList:
            Image(systemName: "circle.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(textColorForBlockType(block.type))
                .padding(.top, 6)
        case .numberedList:
            Text(numberPrefix(for: block))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(textColorForBlockType(block.type))
        default:
            EmptyView()
        }
    }

    private func nextBlockTypeOnReturn(for type: JournalBlockType) -> JournalBlockType {
        switch type {
        case .toggle:
            return .paragraph
        case .bulletedList:
            return .bulletedList
        case .numberedList:
            return .numberedList
        default:
            return .paragraph
        }
    }

    private func numberPrefix(for block: JournalBlock) -> String {
        guard let entry = block.entry else { return "1." }
        guard block.type == .numberedList else { return "" }
        guard let groupID = block.listGroupID else { return "1." }

        let siblings = entry.sortedBlocks.filter {
            $0.type == .numberedList && $0.listGroupID == groupID
        }

        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else {
            return "1."
        }

        return "\(index + 1)."
    }

    @ViewBuilder
    private func backgroundForBlockType(_ type: JournalBlockType) -> some View {
        switch type {
        case .blockquote:
            Color.white.opacity(0.04)
        default:
            Color.clear
        }
    }
}
