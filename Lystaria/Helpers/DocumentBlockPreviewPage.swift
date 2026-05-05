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
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    guard !isCompletingAction else { return }
                    isCompletingAction = true
                    dismiss()
                }
                .foregroundStyle(.white)
                .disabled(isCompletingAction)
                .opacity(isCompletingAction ? 0.5 : 1)
            }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleBlocks) { block in
                    renderBlock(block)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: DocumentBlock) -> some View {
        switch block.type {
        case .paragraph:
            documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))

        case .heading1:
            documentTextBlock(block, font: .systemFont(ofSize: 28, weight: .bold)).padding(.top, 2)

        case .heading2:
            documentTextBlock(block, font: .systemFont(ofSize: 22, weight: .bold))

        case .heading3:
            documentTextBlock(block, font: .systemFont(ofSize: 18, weight: .semibold))

        case .heading4:
            documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .semibold))

        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(LGradients.blue).frame(width: 4)
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .callout:
            HStack(alignment: .center, spacing: 10) {
                Text(block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "✦" : block.calloutEmoji)
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(LGradients.blue)
                    .frame(width: 22, alignment: .center)
                documentTextBlock(block, font: .systemFont(ofSize: 15, weight: .regular))
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
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(LGradients.blue).frame(width: 22, alignment: .leading)
                    documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
                }
                .padding(.leading, CGFloat(block.indentLevel) * 20)
            }
            .buttonStyle(.plain)

        case .bulletedList:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(LColors.textPrimary)
                    .frame(width: 22, alignment: .leading).padding(.top, 6)
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text(numberPrefix(for: block))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                    .frame(width: 28, alignment: .leading)
                documentTextBlock(block, font: .systemFont(ofSize: 16, weight: .regular))
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)

        case .divider:
            Capsule().fill(LGradients.blue).frame(maxWidth: .infinity).frame(height: 3).padding(.vertical, 4)

        case .code:
            VStack(alignment: .leading, spacing: 8) {
                if !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(block.languageHint.uppercased())
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }
                Text(block.text)
                    .font(.system(.body, design: .monospaced)).foregroundStyle(LColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, CGFloat(block.indentLevel) * 20)

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
        let siblings = entry.sortedBlocks.filter { $0.type == .numberedList && $0.listGroupID == groupID }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }
}
