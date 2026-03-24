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

    var body: some View {
        ScrollView {
            // Block to Block Spacing is 10
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
            richTextBlock(
                for: block,
                baseFont: .systemFont(ofSize: 16, weight: .regular),
                textColor: UIColor(LColors.textPrimary)
            )

        case .heading1:
            richTextBlock(
                for: block,
                baseFont: .systemFont(ofSize: 28, weight: .bold),
                textColor: UIColor(LColors.textPrimary)
            )
            .padding(.top, 2)

        case .heading2:
            richTextBlock(
                for: block,
                baseFont: .systemFont(ofSize: 22, weight: .bold),
                textColor: UIColor(LColors.textPrimary)
            )

        case .heading3:
            richTextBlock(
                for: block,
                baseFont: .systemFont(ofSize: 18, weight: .semibold),
                textColor: UIColor(LColors.textPrimary)
            )

        case .heading4:
            richTextBlock(
                for: block,
                baseFont: .systemFont(ofSize: 16, weight: .semibold),
                textColor: UIColor(LColors.textPrimary)
            )

        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LGradients.blue)
                    .frame(width: 4)

                richTextBlock(
                    for: block,
                    baseFont: .systemFont(ofSize: 16, weight: .regular),
                    textColor: UIColor(LColors.textPrimary)
                )
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

                richTextBlock(
                    for: block,
                    baseFont: .systemFont(ofSize: 15, weight: .regular),
                    textColor: UIColor(LColors.textPrimary)
                )
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LGradients.blue, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .toggle:
            Button {
                block.isExpanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LGradients.blue)
                        .frame(width: 22, alignment: .leading)

                    richTextBlock(
                        for: block,
                        baseFont: .systemFont(ofSize: 16, weight: .regular),
                        textColor: UIColor(LColors.textPrimary)
                    )
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

                richTextBlock(
                    for: block,
                    baseFont: .systemFont(ofSize: 16, weight: .regular),
                    textColor: UIColor(LColors.textPrimary)
                )
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text(numberPrefix(for: block))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 28, alignment: .leading)

                richTextBlock(
                    for: block,
                    baseFont: .systemFont(ofSize: 16, weight: .regular),
                    textColor: UIColor(LColors.textPrimary)
                )
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
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)
        }
    }

    @ViewBuilder
    private func dividerView(style: DividerStyle) -> some View {
        switch style {
        case .line:
            Capsule()
                .fill(LGradients.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 3)

        case .dotted:
            GeometryReader { geo in
                let dotWidth: CGFloat = 6
                let gap: CGFloat = 8
                let count = max(1, Int(geo.size.width / (dotWidth + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Capsule()
                            .fill(LGradients.blue)
                            .frame(width: dotWidth, height: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 3)

        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(LGradients.blue)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func richTextBlock(
        for block: JournalBlock,
        baseFont: UIFont,
        textColor: UIColor
    ) -> some View {
        let attributed = buildAttributedString(
            for: block,
            baseFont: baseFont,
            textColor: textColor
        )

        return RichBlockTextView(
            attributedText: attributed,
            isSelectable: true,
            linkTintColor: UIColor.systemBlue
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .padding(.leading, CGFloat(block.indentLevel) * 20)
    }

    private func buildAttributedString(
        for block: JournalBlock,
        baseFont: UIFont,
        textColor: UIColor
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .natural
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.paragraphSpacingBefore = 0

        let text = block.text
        let mutable = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        let fullLength = (text as NSString).length
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
                applyBold(to: mutable, range: range, fallbackBaseFont: baseFont)

            case .italic:
                applyItalic(to: mutable, range: range, fallbackBaseFont: baseFont)

            case .underline:
                mutable.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: range
                )

            case .link:
                let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }

                mutable.addAttribute(.link, value: url, range: range)
                mutable.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: range
                )
            case .inlineCode:
                let monoFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: monoFont, range: range)
                mutable.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.1), range: range)
            }
        }

        return mutable
    }

    private func applyBold(
        to attributed: NSMutableAttributedString,
        range: NSRange,
        fallbackBaseFont: UIFont
    ) {
        attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? UIFont) ?? fallbackBaseFont
            let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitBold)

            if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                let updatedFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                attributed.addAttribute(.font, value: updatedFont, range: subrange)
            } else {
                let updatedFont = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
                attributed.addAttribute(.font, value: updatedFont, range: subrange)
            }
        }
    }

    private func applyItalic(
        to attributed: NSMutableAttributedString,
        range: NSRange,
        fallbackBaseFont: UIFont
    ) {
        attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let currentFont = (value as? UIFont) ?? fallbackBaseFont
            let traits = currentFont.fontDescriptor.symbolicTraits.union(.traitItalic)

            if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                let updatedFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                attributed.addAttribute(.font, value: updatedFont, range: subrange)
            } else {
                let updatedFont = UIFont.italicSystemFont(ofSize: currentFont.pointSize)
                attributed.addAttribute(.font, value: updatedFont, range: subrange)
            }
        }
    }

    private var visibleBlocks: [JournalBlock] {
        var hiddenParentIDs = Set<UUID>()
        var result: [JournalBlock] = []

        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                if block.isToggleBlock {
                    hiddenParentIDs.insert(block.id)
                }
                continue
            }

            result.append(block)

            if block.isToggleBlock && !block.isExpanded {
                hiddenParentIDs.insert(block.id)
            }
        }

        return result
    }

    private func numberPrefix(for block: JournalBlock) -> String {
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
}
