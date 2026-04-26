//
//  JournalBlockDisplayView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import SwiftUI
import UIKit

struct JournalBlockDisplayView: View {
    let entry: JournalEntry
    var onMentionTapped: ((String) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleBlocks) { block in
                    render(block)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func render(_ block: JournalBlock) -> some View {
        switch block.type {
        case .paragraph:
            richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .regular), textColor: UIColor(LColors.textPrimary))

        case .heading1:
            richTextBlock(for: block, baseFont: .systemFont(ofSize: 28, weight: .bold), textColor: UIColor(LColors.textPrimary))
                .padding(.top, 2)

        case .heading2:
            richTextBlock(for: block, baseFont: .systemFont(ofSize: 22, weight: .bold), textColor: UIColor(LColors.textPrimary))

        case .heading3:
            richTextBlock(for: block, baseFont: .systemFont(ofSize: 18, weight: .semibold), textColor: UIColor(LColors.textPrimary))

        case .heading4:
            richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .semibold), textColor: UIColor(LColors.textPrimary))

        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(LGradients.blue).frame(width: 4)
                richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .regular), textColor: UIColor(LColors.textPrimary))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .callout:
            HStack(alignment: .center, spacing: 10) {
                Text(block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "✦" : block.calloutEmoji)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LGradients.blue)
                    .frame(width: 22, alignment: .center)
                richTextBlock(for: block, baseFont: .systemFont(ofSize: 15, weight: .regular), textColor: UIColor(LColors.textPrimary))
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LGradients.blue, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .toggle:
            Button { block.isExpanded.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LGradients.blue)
                        .frame(width: 22, alignment: .leading)
                    richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .regular), textColor: UIColor(LColors.textPrimary))
                }
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            }
            .buttonStyle(.plain)

        case .bulletedList:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 6)
                richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .regular), textColor: UIColor(LColors.textPrimary))
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text(numberPrefix(for: block))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 28, alignment: .leading)
                richTextBlock(for: block, baseFont: .systemFont(ofSize: 16, weight: .regular), textColor: UIColor(LColors.textPrimary))
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .divider:
            dividerView(style: DividerStyle(rawValue: block.languageHint) ?? .line)
                .padding(.vertical, 4)
                .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .code:
            VStack(alignment: .leading, spacing: 8) {
                if !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(block.languageHint.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                Text(block.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .image:
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                displayImageView(uiImage: uiImage, block: block)
                    .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
            }
        }
    }

    @ViewBuilder
    private func displayImageView(uiImage: UIImage, block: JournalBlock) -> some View {
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
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func dividerView(style: DividerStyle) -> some View {
        switch style {
        case .line:
            Capsule().fill(LGradients.blue).frame(maxWidth: .infinity).frame(height: 3)
        case .dotted:
            let dotSize: CGFloat = 4
            let gap: CGFloat = 8
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
            Capsule().fill(LGradients.blue).frame(width: nil).frame(maxWidth: .infinity).scaleEffect(x: 0.5).frame(height: 2)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(LGradients.blue).frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func richTextBlock(for block: JournalBlock, baseFont: UIFont, textColor: UIColor) -> some View {
        let hasMention = block.sortedInlineStyles.contains { $0.type == .mention }

        if hasMention, let onMentionTapped {
            return AnyView(
                MentionBlockView(
                    block: block,
                    baseFont: baseFont,
                    textColor: textColor,
                    onMentionTapped: onMentionTapped
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            )
        }

        let attributed = buildAttributedString(for: block, baseFont: baseFont, textColor: textColor)
        return AnyView(
            RichBlockTextView(attributedText: attributed, isSelectable: true, linkTintColor: UIColor.systemBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .padding(.leading, CGFloat(block.indentLevel) * 20)
        )
    }

    private func buildAttributedString(for block: JournalBlock, baseFont: UIFont, textColor: UIColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .natural

        let text = block.text
        let mutable = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ])

        let fullLength = (text as NSString).length
        guard fullLength > 0 else { return mutable }

        for style in block.sortedInlineStyles {
            let rawRange = style.safeRange
            let maxLength = max(0, fullLength - rawRange.location)
            let clampedLength = min(rawRange.length, maxLength)
            guard rawRange.location >= 0, rawRange.location < fullLength, clampedLength > 0 else { continue }
            let range = NSRange(location: rawRange.location, length: clampedLength)

            switch style.type {
            case .bold:   applyBold(to: mutable, range: range, fallbackBaseFont: baseFont)
            case .italic: applyItalic(to: mutable, range: range, fallbackBaseFont: baseFont)
            case .underline:
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .link:
                let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }
                mutable.addAttribute(.link, value: url, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .inlineCode:
                let monoFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: monoFont, range: range)
                mutable.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.1), range: range)
            case .mention:
                mutable.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        return mutable
    }

    private func applyBold(to attributed: NSMutableAttributedString, range: NSRange, fallbackBaseFont: UIFont) {
        attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? UIFont) ?? fallbackBaseFont
            let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitBold)
            if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: currentFont.pointSize), range: subrange)
            } else {
                attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold), range: subrange)
            }
        }
    }

    private func applyItalic(to attributed: NSMutableAttributedString, range: NSRange, fallbackBaseFont: UIFont) {
        attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? UIFont) ?? fallbackBaseFont
            let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitItalic)
            if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: currentFont.pointSize), range: subrange)
            } else {
                attributed.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: currentFont.pointSize), range: subrange)
            }
        }
    }

    private var visibleBlocks: [JournalBlock] {
        var hiddenParentIDs = Set<UUID>()
        var result: [JournalBlock] = []
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

    private func numberPrefix(for block: JournalBlock) -> String {
        guard block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter { $0.type == .numberedList && $0.listGroupID == groupID }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }
}

// MARK: - MentionBlockView
// Renders a block that contains mention tokens as tappable SwiftUI Buttons,
// with surrounding plain text as Text views. No URLs, no UIKit tap detection.

struct MentionBlockView: View {
    let block: JournalBlock
    let baseFont: UIFont
    let textColor: UIColor
    let onMentionTapped: (String) -> Void

    var body: some View {
        let segments = buildSegments()
        return flowing(segments: segments)
    }

    // Split block text into alternating plain / mention segments
    private func buildSegments() -> [Segment] {
        let text = block.text
        let nsText = text as NSString
        let fullLength = nsText.length

        // Collect mention styles sorted by location
        let mentions = block.sortedInlineStyles
            .filter { $0.type == .mention }
            .sorted { $0.rangeLocation < $1.rangeLocation }

        var segments: [Segment] = []
        var cursor = 0

        for mention in mentions {
            let loc = max(0, mention.rangeLocation)
            let len = min(mention.rangeLength, max(0, fullLength - loc))
            guard loc < fullLength, len > 0 else { continue }

            // Plain text before this mention
            if cursor < loc {
                let plainRange = NSRange(location: cursor, length: loc - cursor)
                if let range = Range(plainRange, in: text) {
                    segments.append(.plain(String(text[range])))
                }
            }

            // Mention token
            let mentionRange = NSRange(location: loc, length: len)
            if let range = Range(mentionRange, in: text) {
                segments.append(.mention(String(text[range]), mention.urlString))
            }

            cursor = loc + len
        }

        // Remaining plain text after last mention
        if cursor < fullLength {
            let tailRange = NSRange(location: cursor, length: fullLength - cursor)
            if let range = Range(tailRange, in: text) {
                segments.append(.plain(String(text[range])))
            }
        }

        return segments
    }

    private func flowing(segments: [Segment]) -> some View {
        let font = Font(baseFont)
        let color = Color(textColor)

        // Concatenate into a single Text with inline buttons not possible in SwiftUI,
        // so we use a wrapping HStack that reflows. For simplicity, render as one
        // Text with the mention token styled, wrapped in an overlay Button per mention.
        // Actually the simplest correct approach: render segments in a FlowLayout-style
        // using a single attributed Text where mention tokens are replaced with
        // a placeholder, plus absolute-positioned buttons — too complex.
        //
        // Simplest working approach: render the full block as a VStack of lines,
        // splitting on newlines, and within each line split on mention boundaries.
        // Use HStack(spacing:0) per line with wrapping via a custom layout.
        //
        // For now: render as plain Text (styled) + a transparent Button overlay
        // that covers just the mention token character rect. Since we can't get
        // the rect without TextKit, use the simplest approach that actually works:
        // render as a single Text but replace the mention with a clearly tappable
        // inline Button by splitting lines and using HStack with flexibleWidth.

        return SegmentedTextView(
            segments: segments,
            font: font,
            color: color,
            onMentionTapped: onMentionTapped
        )
    }

    enum Segment {
        case plain(String)
        case mention(String, String) // (displayText, urlString/id)
    }
}

// Renders segments inline. Plain text as Text, mentions as Button.
// Uses a wrapping flow layout so text wraps naturally.
struct SegmentedTextView: View {
    let segments: [MentionBlockView.Segment]
    let font: Font
    let color: Color
    let onMentionTapped: (String) -> Void

    var body: some View {
        let fullText = segments.reduce(Text("")) { result, segment in
            switch segment {
            case .plain(let text):
                return result + Text(text).font(font).foregroundStyle(color)
            case .mention(let display, _):
                return result + Text(display).font(font).foregroundStyle(Color.blue).underline()
            }
        }

        let mentionSegments = segments.compactMap { seg -> (String, String)? in
            if case .mention(let display, let id) = seg { return (display, id) }
            return nil
        }

        ZStack(alignment: .leading) {
            fullText
                .frame(maxWidth: .infinity, alignment: .leading)

            if let first = mentionSegments.first {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded {
                        onMentionTapped(first.1)
                    })
            }
        }
    }
}
