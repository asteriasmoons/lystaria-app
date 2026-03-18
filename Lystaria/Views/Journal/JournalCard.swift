import SwiftUI
import SwiftData

struct JournalCard: View {
    let entry: JournalEntry
    let onView: (JournalEntry) -> Void
    let onTagSelect: (String) -> Void

    private var snippet: String {
        let attributed = entry.bodyAttributedText
        guard attributed.length > 0 else { return "" }

        let mutable = NSMutableAttributedString(attributedString: attributed)
        let full = NSRange(location: 0, length: mutable.length)

        // Convert divider blocks to "- - -"
        mutable.enumerateAttribute(NSAttributedString.Key("lystariaDivider"), in: full, options: []) { value, range, _ in
            guard let isDivider = value as? Bool, isDivider else { return }
            mutable.replaceCharacters(in: range, with: NSAttributedString(string: "- - -"))
        }

        // Convert blockquote paragraphs to a plain-text "> " prefix
        let quoteKey = NSAttributedString.Key("lystariaBlockquote")
        let nsString = mutable.string as NSString
        var paragraphRanges: [NSRange] = []
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: nsString.length), options: [.byParagraphs, .substringNotRequired]) { _, subRange, _, _ in
            paragraphRanges.append(subRange)
        }

        for paragraphRange in paragraphRanges.reversed() {
            guard paragraphRange.location < mutable.length else { continue }
            let isQuote = (mutable.attribute(quoteKey, at: paragraphRange.location, effectiveRange: nil) as? Bool) == true
            guard isQuote else { continue }

            let paragraphText = (mutable.string as NSString).substring(with: paragraphRange)
            let trimmedNewlineText = paragraphText.hasSuffix("\n") ? String(paragraphText.dropLast()) : paragraphText
            let replacement = "> " + trimmedNewlineText + (paragraphText.hasSuffix("\n") ? "\n" : "")
            mutable.replaceCharacters(in: paragraphRange, with: NSAttributedString(string: replacement))
        }

        // Convert to plain string
        let s = mutable.string
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if s.isEmpty { return "" }
        return String(s.prefix(200))
    }

    private var dateLabel: String {
        entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    var body: some View {
        Button { onView(entry) } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Text(dateLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    if !snippet.isEmpty {
                        Text(snippet)
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(3)
                    }

                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entry.tags, id: \.self) { tag in
                                    Button { onTagSelect(tag) } label: {
                                        Text("#\(tag)")
                                            .font(.system(size: 12, weight: .bold))
                                            .lineLimit(1)
                                            .foregroundStyle(LGradients.tag)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(LGradients.tag, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let e = JournalEntry(
        title: "A day in the mountains",
        bodyAttributedText: NSAttributedString(string: "It was peaceful and calm..."),
        tags: ["dev", "family", "health"]
    )
    ZStack {
        LystariaBackground()
        JournalCard(entry: e, onView: { _ in }, onTagSelect: { _ in })
            .padding()
    }
}
