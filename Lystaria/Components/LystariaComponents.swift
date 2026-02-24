// LystariaComponents.swift
// Lystaria
//
// Reusable UI components matching the glass morphism design


import SwiftUI
import UIKit
import Combine

private extension NSAttributedString.Key {
    static let lystariaBlockquote = NSAttributedString.Key("lystariaBlockquote")
}

// MARK: - Animated Background

struct LystariaBackground: View {
    var body: some View {
        ZStack {
            LColors.bg.ignoresSafeArea()

            // Ambient glow layers using the updated teal / purple palette
            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.30),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.24),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.14),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Gradient Overlay Background (softened version for layering)

struct GradientOverlayBackground: View {
    var body: some View {
        ZStack {
            // Softer ambient glow layers intended to sit *over* another background
            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.12),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.10),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.06),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.07),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Reusable Gradient Overlay Layering

struct GradientOverlayLayer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
            GradientOverlayBackground()
                .allowsHitTesting(false)
        }
    }
}

struct GradientOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            GradientOverlayBackground()
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func gradientOverlay() -> some View {
        modifier(GradientOverlayModifier())
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var padding: CGFloat = LSpacing.cardPadding
    var radius: CGFloat = LSpacing.cardRadius
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .padding(padding)
            .background(
                ZStack {
                    // Glass surface
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                    
                    RoundedRectangle(cornerRadius: radius)
                        .fill(LColors.glassSurface)
                    
                    // Glass edge shine (matches ::before in CSS)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .opacity(0.55)
                        .blendMode(.screen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 20, y: 14)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    var onAdd: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(LColors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(LColors.accent)
            }
            
            Spacer()
            
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 3/255, green: 219/255, blue: 252/255),
                                    Color(red: 125/255, green: 25/255, blue: 247/255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }
}

// MARK: - Gradient Header Text

struct GradientTitle: View {
    let text: String
    private let size: CGFloat

    /// Preferred initializer: pass the desired point size and Rochester will be applied automatically.
    init(text: String, size: CGFloat = 28) {
        self.text = text
        self.size = size
    }

    /// Backwards-compatible initializer for existing call sites that still pass `font:`.
    /// Uses a sensible default size while enforcing Rochester for consistent headers.
    init(text: String, font: Font = .title.bold()) {
        self.text = text
        self.size = 28
    }

    var body: some View {
        Text(text)
            .font(.custom("LilyScriptOne-Regular", size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 3/255, green: 219/255, blue: 252/255),
                        Color(red: 125/255, green: 25/255, blue: 247/255)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - Primary Button

struct LButton: View {
    let title: String
    var icon: String? = nil
    var style: LButtonStyle = .primary
    var action: () -> Void
    
    enum LButtonStyle {
        case primary, secondary, success, danger, gradient
    }
    
    private var bgColor: AnyShapeStyle {
        switch style {
        case .primary: return AnyShapeStyle(LColors.accent)
        case .secondary: return AnyShapeStyle(Color.white.opacity(0.1))
        case .success: return AnyShapeStyle(LColors.success)
        case .danger: return AnyShapeStyle(LColors.danger)
        case .gradient: return AnyShapeStyle(LGradients.blue)
        }
    }
    
    private var fgColor: Color {
        switch style {
        case .secondary: return LColors.textPrimary
        default: return .white
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(fgColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bgColor, in: RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                    .stroke(
                        style == .secondary ? LColors.glassBorder : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge

struct LBadge: View {
    let text: String
    var color: Color = LColors.accent
    
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Tag Pill (gradient)

struct TagPill: View {
    let text: String
    
    var body: some View {
        Text("#\(text)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 3/255, green: 219/255, blue: 252/255),
                        Color(red: 125/255, green: 25/255, blue: 247/255)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LColors.accent.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: LColors.accent.opacity(0.18), radius: 5, y: 4)
    }
}

// MARK: - Glass Input Field

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    
    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .foregroundStyle(LColors.textPrimary)
            .padding(12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Glass TextEditor

struct GlassTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(LColors.textSecondary.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .foregroundStyle(LColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
        .overlay(
            RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Rich Text Editor (Glass Styled)

final class GlassRichTextController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    weak var textView: UITextView?

    func focus() {
        textView?.becomeFirstResponder()
    }

    func toggleBold() {
        applyTrait(.traitBold)
    }

    func toggleItalic() {
        applyTrait(.traitItalic)
    }

    func toggleUnderline() {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        let targetRange = selectedRange.length > 0
            ? selectedRange
            : NSRange(location: max(0, selectedRange.location - 1), length: min(1, mutable.length > 0 ? 1 : 0))

        guard targetRange.length > 0 else { return }

        var existing: Int = 0
        if let value = mutable.attribute(.underlineStyle, at: targetRange.location, effectiveRange: nil) as? NSNumber {
            existing = value.intValue
        }
        let newValue = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
        mutable.addAttribute(.underlineStyle, value: newValue, range: targetRange)

        textView.attributedText = mutable
        textView.selectedRange = selectedRange
        textView.delegate?.textViewDidChange?(textView)
    }

    func toggleBulletList() {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        let nsText = mutable.string as NSString
        let paragraphRange = nsText.paragraphRange(for: selectedRange)
        let fullText = mutable.string as NSString
        let selectedText = fullText.substring(with: paragraphRange)
        let lines = selectedText.components(separatedBy: "\n")

        let allBulleted = lines.allSatisfy { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix("• ")
        }

        let transformed = lines.map { line -> String in
            if line.isEmpty { return line }
            if allBulleted {
                return line.replacingOccurrences(of: "• ", with: "", options: .anchored)
            } else {
                return line.hasPrefix("• ") ? line : "• " + line
            }
        }.joined(separator: "\n")

        mutable.replaceCharacters(in: paragraphRange, with: transformed)
        textView.attributedText = mutable
        textView.selectedRange = NSRange(location: paragraphRange.location, length: (transformed as NSString).length)
        textView.typingAttributes = textView.typingAttributes.merging(defaultTypingAttributes()) { _, new in new }
        textView.delegate?.textViewDidChange?(textView)
    }

    func toggleNumberedList() {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        let nsText = mutable.string as NSString
        let paragraphRange = nsText.paragraphRange(for: selectedRange)
        let fullText = mutable.string as NSString
        let selectedText = fullText.substring(with: paragraphRange)
        let lines = selectedText.components(separatedBy: "\n")

        let numberRegex = try? NSRegularExpression(pattern: "^\\d+\\.\\s")
        let allNumbered = lines.allSatisfy { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return true }
            let range = NSRange(location: 0, length: line.utf16.count)
            return numberRegex?.firstMatch(in: line, options: [], range: range) != nil
        }

        var counter = 1
        let transformed = lines.map { line -> String in
            if line.isEmpty { return line }
            if allNumbered {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = numberRegex?.firstMatch(in: line, options: [], range: range),
                   let swiftRange = Range(match.range, in: line) {
                    return String(line[swiftRange.upperBound...])
                }
                return line
            } else {
                defer { counter += 1 }
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = numberRegex?.firstMatch(in: line, options: [], range: range),
                   let swiftRange = Range(match.range, in: line) {
                    return "\(counter). " + String(line[swiftRange.upperBound...])
                }
                return "\(counter). " + line
            }
        }.joined(separator: "\n")

        mutable.replaceCharacters(in: paragraphRange, with: transformed)
        textView.attributedText = mutable
        textView.selectedRange = NSRange(location: paragraphRange.location, length: (transformed as NSString).length)
        textView.typingAttributes = textView.typingAttributes.merging(defaultTypingAttributes()) { _, new in new }
        textView.delegate?.textViewDidChange?(textView)
    }

    func toggleQuoteBlock() {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        let nsText = mutable.string as NSString
        let paragraphRange = nsText.paragraphRange(for: selectedRange)
        guard paragraphRange.length > 0 else { return }

        var allQuoted = true
        nsText.enumerateSubstrings(in: paragraphRange, options: [.byParagraphs, .substringNotRequired]) { _, subRange, _, _ in
            let quoted = mutable.attribute(.lystariaBlockquote, at: subRange.location, effectiveRange: nil) as? Bool == true
            if !quoted { allQuoted = false }
        }

        nsText.enumerateSubstrings(in: paragraphRange, options: [.byParagraphs, .substringNotRequired]) { _, subRange, _, _ in
            let currentParagraphStyle = (mutable.attribute(.paragraphStyle, at: subRange.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? (self.defaultTypingAttributes()[.paragraphStyle] as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()

            if allQuoted {
                currentParagraphStyle.firstLineHeadIndent = 0
                currentParagraphStyle.headIndent = 0
                currentParagraphStyle.paragraphSpacingBefore = 0
                currentParagraphStyle.paragraphSpacing = 0
                mutable.removeAttribute(.lystariaBlockquote, range: subRange)
                mutable.addAttribute(.paragraphStyle, value: currentParagraphStyle, range: subRange)
            } else {
                currentParagraphStyle.firstLineHeadIndent = 22
                currentParagraphStyle.headIndent = 22
                currentParagraphStyle.paragraphSpacingBefore = 4
                currentParagraphStyle.paragraphSpacing = 6
                mutable.addAttribute(.lystariaBlockquote, value: true, range: subRange)
                mutable.addAttribute(.paragraphStyle, value: currentParagraphStyle, range: subRange)
            }
        }

        textView.attributedText = mutable
        textView.selectedRange = selectedRange
        textView.typingAttributes = textView.typingAttributes.merging(defaultTypingAttributes()) { current, _ in current }
        textView.setNeedsDisplay()
        textView.delegate?.textViewDidChange?(textView)
    }

    func insertLink() {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        if selectedRange.length > 0,
           let pasted = UIPasteboard.general.string,
           let url = URL(string: pasted),
           url.scheme != nil {
            mutable.addAttribute(.link, value: url, range: selectedRange)
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.accent), range: selectedRange)
            textView.attributedText = mutable
            textView.selectedRange = selectedRange
            textView.delegate?.textViewDidChange?(textView)
            return
        }

        let linkText = "https://"
        let attrs = defaultTypingAttributes().merging([
            .foregroundColor: UIColor(LColors.accent),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ] as [NSAttributedString.Key: Any]) { _, new in new }
        let attributed = NSAttributedString(string: linkText, attributes: attrs)
        mutable.replaceCharacters(in: selectedRange, with: attributed)
        textView.attributedText = mutable
        textView.selectedRange = NSRange(location: selectedRange.location + linkText.count, length: 0)
        textView.delegate?.textViewDidChange?(textView)
    }

    func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .natural

        return [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(LColors.textPrimary),
            .paragraphStyle: paragraph
        ]
    }

    private func applyTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let textView else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let selectedRange = textView.selectedRange
        guard selectedRange.location != NSNotFound else { return }

        let targetRange = selectedRange.length > 0
            ? selectedRange
            : NSRange(location: max(0, selectedRange.location - 1), length: min(1, mutable.length > 0 ? 1 : 0))

        if targetRange.length == 0 {
            var attrs = textView.typingAttributes
            let currentFont = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            let newTraits: UIFontDescriptor.SymbolicTraits = currentTraits.contains(trait)
                ? currentTraits.subtracting(trait)
                : currentTraits.union(trait)
            let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) ?? currentFont.fontDescriptor
            attrs[.font] = UIFont(descriptor: descriptor, size: currentFont.pointSize)
            attrs[.foregroundColor] = UIColor(LColors.textPrimary)
            attrs[.paragraphStyle] = defaultTypingAttributes()[.paragraphStyle]
            textView.typingAttributes = attrs
            return
        }

        mutable.enumerateAttribute(.font, in: targetRange, options: []) { value, range, _ in
            let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let currentTraits = font.fontDescriptor.symbolicTraits
            let newTraits: UIFontDescriptor.SymbolicTraits = currentTraits.contains(trait)
                ? currentTraits.subtracting(trait)
                : currentTraits.union(trait)
            let descriptor = font.fontDescriptor.withSymbolicTraits(newTraits) ?? font.fontDescriptor
            let updatedFont = UIFont(descriptor: descriptor, size: font.pointSize)
            mutable.addAttribute(.font, value: updatedFont, range: range)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textPrimary), range: range)
            if let paragraph = defaultTypingAttributes()[.paragraphStyle] {
                mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
            }
        }

        textView.attributedText = mutable
        textView.selectedRange = selectedRange
        textView.delegate?.textViewDidChange?(textView)
    }
}

final class GlassRichTextView: UITextView {
    override func draw(_ rect: CGRect) {
        drawQuoteBlocks(in: rect)
        super.draw(rect)
    }

    private func drawQuoteBlocks(in rect: CGRect) {
        guard let attributedText, attributedText.length > 0,
              let ctx = UIGraphicsGetCurrentContext() else { return }

        let fullRange = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.lystariaBlockquote, in: fullRange, options: []) { value, range, _ in
            guard let isQuoted = value as? Bool, isQuoted == true else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var minY: CGFloat?
            var maxY: CGFloat?

            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, lineGlyphRange, _ in
                let charRange = self.layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
                guard charRange.location < attributedText.length else { return }
                let lineIsQuoted = attributedText.attribute(.lystariaBlockquote, at: charRange.location, effectiveRange: nil) as? Bool == true
                guard lineIsQuoted else { return }

                let top = usedRect.minY + self.textContainerInset.top - 4
                let bot = usedRect.maxY + self.textContainerInset.top + 4

                if let curMin = minY { minY = min(curMin, top) } else { minY = top }
                if let curMax = maxY { maxY = max(curMax, bot) } else { maxY = bot }
            }

            guard let top = minY, let bot = maxY else { return }

            // Container spans the full usable width from the left inset edge
            let leftEdge = self.textContainerInset.left
            let drawRect = CGRect(
                x: leftEdge,
                y: top,
                width: bounds.width - leftEdge - self.textContainerInset.right,
                height: max(0, bot - top)
            )

            let backgroundPath = UIBezierPath(roundedRect: drawRect, cornerRadius: 12)
            ctx.saveGState()
            UIColor.white.withAlphaComponent(0.08).setFill()
            backgroundPath.fill()
            ctx.restoreGState()

            // Strip: flush left edge of container, clipped to container shape so corners match
            let stripWidth: CGFloat = 5
            let stripRect = CGRect(x: drawRect.minX, y: drawRect.minY, width: stripWidth, height: drawRect.height)
            ctx.saveGState()
            backgroundPath.addClip() // clip to container so left corners are rounded identically

            let colors = [
                UIColor(red: 3/255, green: 219/255, blue: 252/255, alpha: 1).cgColor,
                UIColor(red: 125/255, green: 25/255, blue: 247/255, alpha: 1).cgColor
            ] as CFArray

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.clip(to: stripRect)
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: stripRect.minX, y: stripRect.minY),
                    end: CGPoint(x: stripRect.minX, y: stripRect.maxY),
                    options: []
                )
            }
            ctx.restoreGState()
        }
    }
}

struct GlassRichTextEditor: UIViewRepresentable {
    let placeholder: String
    @Binding var text: NSAttributedString
    var minHeight: CGFloat = 140
    var onHeightChange: ((CGFloat) -> Void)? = nil
    @ObservedObject var controller: GlassRichTextController

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = GlassRichTextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.adjustsFontForContentSizeCategory = true
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = context.coordinator.defaultTypingAttributes
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(LColors.accent),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.attributedText = text
        controller.textView = textView

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = UIColor(LColors.textSecondary.opacity(0.6))
        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.tag = 999
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -16)
        ])

        context.coordinator.updatePlaceholder(in: textView)
        context.coordinator.updateMeasuredHeight(for: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        controller.textView = textView

        // Force the text container to use the actual editor width so text wraps
        // inside the glass field instead of continuing horizontally.
        let usableWidth = max(textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right, 0)
        textView.textContainer.size = CGSize(width: usableWidth, height: CGFloat.greatestFiniteMagnitude)

        if !textView.attributedText.isEqual(to: text) {
            let selected = textView.selectedRange

            let mutable = NSMutableAttributedString(attributedString: text)
            let fullRange = NSRange(location: 0, length: mutable.length)
            if fullRange.length > 0 {
                mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
                    if value == nil {
                        mutable.addAttribute(
                            .paragraphStyle,
                            value: context.coordinator.defaultTypingAttributes[.paragraphStyle] as Any,
                            range: range
                        )
                    }
                }
            }

            textView.attributedText = mutable
            textView.typingAttributes = context.coordinator.defaultTypingAttributes
            textView.selectedRange = NSRange(location: min(selected.location, mutable.length), length: 0)
        }

        context.coordinator.updatePlaceholder(in: textView)
        context.coordinator.updateMeasuredHeight(for: textView)
        textView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GlassRichTextEditor

        init(_ parent: GlassRichTextEditor) {
            self.parent = parent
        }

        var defaultTypingAttributes: [NSAttributedString.Key: Any] {
            parent.controller.defaultTypingAttributes()
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.attributedText
            updatePlaceholder(in: textView)
            updateMeasuredHeight(for: textView)
            textView.setNeedsDisplay()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            updatePlaceholder(in: textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            let nsText = textView.text as NSString? ?? "" as NSString

            // Auto-convert "- " typed at the start of a line into a bullet.
            if replacement == " " {
                guard range.location > 0, range.location <= nsText.length else { return true }

                let lineRange = nsText.lineRange(for: NSRange(location: max(0, range.location - 1), length: 0))
                let prefixRange = NSRange(location: lineRange.location, length: range.location - lineRange.location)
                guard prefixRange.location != NSNotFound, prefixRange.length >= 1 else { return true }

                let prefix = nsText.substring(with: prefixRange)
                guard prefix == "-" else { return true }

                let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                let bulletAttrs = defaultTypingAttributes
                let bullet = NSAttributedString(string: "• ", attributes: bulletAttrs)

                // Replace the typed dash with a bullet + space.
                mutable.replaceCharacters(in: prefixRange, with: bullet)
                textView.attributedText = mutable
                textView.typingAttributes = defaultTypingAttributes
                textView.selectedRange = NSRange(location: prefixRange.location + 2, length: 0)

                textViewDidChange(textView)
                return false
            }

            // Continue / exit lists on Return.
            // Exit quote blocks on Return so the next paragraph returns to normal formatting.
            if replacement == "\n" {
                let safeLocation = min(max(range.location, 0), nsText.length)
                let probeLocation = max(0, min(nsText.length == 0 ? 0 : nsText.length - 1, max(0, safeLocation - 1)))
                let paragraphRange = nsText.paragraphRange(for: NSRange(location: probeLocation, length: 0))

                if paragraphRange.length > 0,
                   (textView.attributedText.attribute(.lystariaBlockquote, at: paragraphRange.location, effectiveRange: nil) as? Bool) == true {
                    let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                    let insertion = NSAttributedString(string: "\n", attributes: defaultTypingAttributes)
                    mutable.replaceCharacters(in: range, with: insertion)
                    textView.attributedText = mutable
                    textView.typingAttributes = defaultTypingAttributes
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    textViewDidChange(textView)
                    return false
                }
            }
            if replacement == "\n" {
                let safeLocation = min(max(range.location, 0), nsText.length)
                let lineProbeLocation = max(0, min(nsText.length == 0 ? 0 : nsText.length - 1, max(0, safeLocation - 1)))
                let lineRange = nsText.lineRange(for: NSRange(location: lineProbeLocation, length: 0))
                let lineText = nsText.substring(with: lineRange)
                let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)

                let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                let attrs = defaultTypingAttributes

                // Bullet list behavior
                if trimmed == "•" {
                    // Empty bullet item: remove bullet and exit list.
                    mutable.replaceCharacters(in: lineRange, with: "")
                    textView.attributedText = mutable
                    textView.typingAttributes = attrs
                    textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                    textViewDidChange(textView)
                    return false
                }

                if lineText.hasPrefix("• ") {
                    let insertion = NSAttributedString(string: "\n• ", attributes: attrs)
                    mutable.replaceCharacters(in: range, with: insertion)
                    textView.attributedText = mutable
                    textView.typingAttributes = attrs
                    textView.selectedRange = NSRange(location: range.location + 3, length: 0)
                    textViewDidChange(textView)
                    return false
                }

                // Numbered list behavior
                let numberRegex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s")
                let fullLineRange = NSRange(location: 0, length: lineText.utf16.count)
                if let match = numberRegex?.firstMatch(in: lineText, options: [], range: fullLineRange),
                   let numberRange = Range(match.range(at: 1), in: lineText) {

                    let currentNumber = Int(lineText[numberRange]) ?? 1
                    let prefixRange = match.range(at: 0)
                    let afterPrefixLocation = prefixRange.location + prefixRange.length
                    let afterPrefix = (lineText as NSString).substring(from: min(afterPrefixLocation, (lineText as NSString).length))
                    let afterPrefixTrimmed = afterPrefix.trimmingCharacters(in: .whitespacesAndNewlines)

                    if afterPrefixTrimmed.isEmpty {
                        // Empty numbered item: remove numbering and exit list.
                        mutable.replaceCharacters(in: lineRange, with: "")
                        textView.attributedText = mutable
                        textView.typingAttributes = attrs
                        textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                        textViewDidChange(textView)
                        return false
                    } else {
                        let nextPrefix = "\n\(currentNumber + 1). "
                        let insertion = NSAttributedString(string: nextPrefix, attributes: attrs)
                        mutable.replaceCharacters(in: range, with: insertion)
                        textView.attributedText = mutable
                        textView.typingAttributes = attrs
                        textView.selectedRange = NSRange(location: range.location + (nextPrefix as NSString).length, length: 0)
                        textViewDidChange(textView)
                        return false
                    }
                }
            }

            return true
        }

        func updatePlaceholder(in textView: UITextView) {
            guard let label = textView.viewWithTag(999) as? UILabel else { return }
            label.isHidden = !textView.attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func updateMeasuredHeight(for textView: UITextView) {
            let usableWidth = max(
                textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right,
                0
            )
            let fittingSize = CGSize(width: usableWidth, height: .greatestFiniteMagnitude)
            let measured = max(parent.minHeight, textView.sizeThatFits(fittingSize).height)
            DispatchQueue.main.async {
                self.parent.onHeightChange?(measured)
            }
        }
    }
}

// MARK: - Rich Text Display (Viewer)

struct GlassRichTextDisplay: UIViewRepresentable {
    let text: NSAttributedString
    var minHeight: CGFloat = 40
    var onHeightChange: ((CGFloat) -> Void)? = nil

    /// Preserve editor formatting for preview, but enforce readable colors and
    /// restore quote paragraph styling if it exists in custom attributes.
    private func sanitised(_ source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let full = NSRange(location: 0, length: mutable.length)
        guard full.length > 0 else { return mutable }

        let white = UIColor(LColors.textPrimary)
        let accent = UIColor(LColors.accent)

        // Preserve all existing fonts / traits. Only fill missing fonts.
        mutable.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
            }
        }

        // Force readable colors in preview while preserving links.
        mutable.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            if attrs[.link] != nil {
                mutable.addAttribute(.foregroundColor, value: accent, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                mutable.addAttribute(.foregroundColor, value: white, range: range)
            }
        }

        // Re-apply paragraph styling so quotes render properly and normal text stays flush left.
        (mutable.string as NSString).enumerateSubstrings(in: full, options: [.byParagraphs, .substringNotRequired]) { _, subRange, _, _ in
            guard subRange.location < mutable.length else { return }

            let existing = (mutable.attribute(.paragraphStyle, at: subRange.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            existing.lineBreakMode = .byWordWrapping
            existing.alignment = .natural

            let isQuoted = (mutable.attribute(.lystariaBlockquote, at: subRange.location, effectiveRange: nil) as? Bool) == true
            if isQuoted {
                existing.firstLineHeadIndent = 22
                existing.headIndent = 22
                existing.paragraphSpacingBefore = 4
                existing.paragraphSpacing = 6
            } else {
                existing.firstLineHeadIndent = 0
                existing.headIndent = 0
                existing.paragraphSpacingBefore = 0
                existing.paragraphSpacing = 0
            }

            mutable.addAttribute(.paragraphStyle, value: existing, range: subRange)
        }

        return mutable
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = GlassRichTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        // Must be false — true lets UIKit silently replace stored fonts with
        // dynamic-type scaled variants, wiping bold/italic traits on display.
        textView.adjustsFontForContentSizeCategory = false
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(LColors.accent),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.attributedText = sanitised(text)
        DispatchQueue.main.async {
            updateMeasuredHeight(for: textView)
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Always re-apply sanitised text. NSAttributedString.isEqual(to:) is unreliable
        // with custom attributes (lystariaBlockquote) and causes SwiftUI to silently skip
        // updates, leaving stale formatting.
        textView.attributedText = sanitised(text)
        textView.setNeedsDisplay()
        DispatchQueue.main.async {
            updateMeasuredHeight(for: textView)
        }
    }

    private func updateMeasuredHeight(for textView: UITextView) {
        let insets = textView.textContainerInset
        let screenWidth = textView.window?.windowScene?.screen.bounds.width ?? textView.bounds.width
        let width = max(textView.bounds.width, screenWidth - 64)
        let fittingSize = CGSize(width: width - insets.left - insets.right, height: .greatestFiniteMagnitude)
        let contentHeight = textView.sizeThatFits(CGSize(width: fittingSize.width, height: .greatestFiniteMagnitude)).height
        let measured = max(minHeight, contentHeight)
        onHeightChange?(measured)
    }
}

struct GlassRichTextViewer: View {
    let text: NSAttributedString
    var minHeight: CGFloat = 40
    @State private var measuredHeight: CGFloat = 40

    var body: some View {
        GlassRichTextDisplay(text: text, minHeight: minHeight, onHeightChange: { measuredHeight = $0 })
            .frame(height: max(minHeight, measuredHeight))
    }
}

struct GlassRichTextField: View {
    let placeholder: String
    @Binding var text: NSAttributedString
    var minHeight: CGFloat = 140
    @State private var measuredHeight: CGFloat = 140
    @StateObject private var controller = GlassRichTextController()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                richToolButton("B") { controller.toggleBold() }
                richToolButton("I") { controller.toggleItalic() }
                richToolButton("U") { controller.toggleUnderline() }
                richToolButton("•") { controller.toggleBulletList() }
                richToolButton("1.") { controller.toggleNumberedList() }
                richToolIconButton("quote.bubble") { controller.toggleQuoteBlock() }
                richToolIconButton("link") { controller.insertLink() }
                Spacer()
            }

            GlassRichTextEditor(
                placeholder: placeholder,
                text: $text,
                minHeight: minHeight,
                onHeightChange: { measuredHeight = $0 },
                controller: controller
            )
            .frame(minHeight: max(minHeight, measuredHeight))
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func richToolButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 3/255, green: 219/255, blue: 252/255),
                                Color(red: 125/255, green: 25/255, blue: 247/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func richToolIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 3/255, green: 219/255, blue: 252/255),
                                Color(red: 125/255, green: 25/255, blue: 247/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyState: View {
    let icon: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(LColors.textSecondary.opacity(0.3))
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
            
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(LColors.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - FAB (Floating Action Button)

struct FloatingActionButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 3/255, green: 219/255, blue: 252/255),
                            Color(red: 125/255, green: 25/255, blue: 247/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: LColors.accent.opacity(0.38), radius: 15, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Bar

struct GlassProgressBar: View {
    let progress: Double
    var height: CGFloat = 10
    var gradient: LinearGradient = LinearGradient(
        colors: [
            Color(red: 3/255, green: 219/255, blue: 252/255),
            Color(red: 125/255, green: 25/255, blue: 247/255)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, geo.size.width * min(progress, 1.0)))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}
// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 36
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
