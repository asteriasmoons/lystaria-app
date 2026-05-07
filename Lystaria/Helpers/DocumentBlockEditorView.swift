//
//  DocumentBlockEditorView.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentBlockEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: DocumentEntry
    @State private var isMutatingBlocks = false
    @State private var draggingBlock: DocumentBlock? = nil
    @State private var dragOverIndex: Int? = nil
    @State private var selectedBlockIDs: Set<UUID> = []

    // Split visible blocks into page segments at .pageBreak dividers
    // Each entry: (page blocks, optional page break block that follows it)
    private var blockPages: [(blocks: [(Int, DocumentBlock)], breakBlock: DocumentBlock?)] {
        var pages: [(blocks: [(Int, DocumentBlock)], breakBlock: DocumentBlock?)] = [([], nil)]
        for item in Array(visibleBlocks.enumerated()) {
            let block = item.element
            if block.type == .divider,
               (DividerStyles(rawValue: block.languageHint) ?? .line) == .pageBreak {
                // Close current page with this break block, open new page
                let last = pages[pages.count - 1]
                pages[pages.count - 1] = (last.blocks, block)
                pages.append(([], nil))
            } else {
                pages[pages.count - 1].blocks.append((item.offset, block))
            }
        }
        return pages
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let pages = blockPages

                // Drop zone before everything
                if draggingBlock != nil {
                    DocumentBlockDropZone(index: 0, dragOverIndex: $dragOverIndex)
                        .onDrop(of: [.plainText], delegate: DocumentIndexedDropDelegate(
                            index: 0,
                            draggingBlock: $draggingBlock,
                            dragOverIndex: $dragOverIndex,
                            visibleBlocks: visibleBlocks,
                            onMove: reorderBlockToIndex
                        ))
                }

                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageEntry in
                    let page = pageEntry.blocks
                    // Floating page sheet
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(page, id: \.1.id) { (i, block) in
                            DocumentBlockRow(
                                block: block,
                                onAddBelow: { b, type, initialText in insertBlockBelow(b, type, initialText) },
                                onDelete: deleteBlock,
                                onMoveUp: moveBlockUp,
                                onMoveDown: moveBlockDown,
                                onTransform: transformBlock,
                                isSelectionMode: isSelectionMode,
                                isSelectedForBatchAction: selectedBlockIDs.contains(block.id),
                                selectedBlockCount: selectedBlockIDs.count,
                                onEnterSelectionMode: enterSelectionMode,
                                onToggleBatchSelection: toggleBlockSelection,
                                onClearBatchSelection: clearBlockSelection,
                                onDeleteSelectedBlocks: deleteSelectedBlocks,
                                onIndentSelectedBlocksIn: indentSelectedBlocksIn,
                                onIndentSelectedBlocksOut: indentSelectedBlocksOut
                            )
                            .opacity(draggingBlock?.id == block.id ? 0.4 : 1)
                            .onDrag {
                                draggingBlock = block
                                dragOverIndex = nil
                                return NSItemProvider(object: block.id.uuidString as NSString)
                            }
                            .padding(.vertical, isSelectionMode ? 3 : 6)

                            if draggingBlock != nil {
                                DocumentBlockDropZone(index: i + 1, dragOverIndex: $dragOverIndex)
                                    .onDrop(of: [.plainText], delegate: DocumentIndexedDropDelegate(
                                        index: i + 1,
                                        draggingBlock: $draggingBlock,
                                        dragOverIndex: $dragOverIndex,
                                        visibleBlocks: visibleBlocks,
                                        onMove: reorderBlockToIndex
                                    ))
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .overlay(
                                PageSheetTapOverlay {
                                    guard !isSelectionMode else { return }
                                    if let last = page.last?.1 {
                                        if last.type == .paragraph && last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            // Already a blank paragraph — just focus it
                                            let id = last.id
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                NotificationCenter.default.post(name: .documentBlockRequestFocus, object: id)
                                            }
                                        } else {
                                            insertBlockBelow(last, .paragraph, "")
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Render the page break block between sheets so it's tappable
                    if let breakBlock = pageEntry.breakBlock {
                        DocumentBlockRow(
                            block: breakBlock,
                            onAddBelow: { b, type, initialText in insertBlockBelow(b, type, initialText) },
                            onDelete: deleteBlock,
                            onMoveUp: moveBlockUp,
                            onMoveDown: moveBlockDown,
                            onTransform: transformBlock,
                            isSelectionMode: isSelectionMode,
                            isSelectedForBatchAction: selectedBlockIDs.contains(breakBlock.id),
                            selectedBlockCount: selectedBlockIDs.count,
                            onEnterSelectionMode: enterSelectionMode,
                            onToggleBatchSelection: toggleBlockSelection,
                            onClearBatchSelection: clearBlockSelection,
                            onDeleteSelectedBlocks: deleteSelectedBlocks,
                            onIndentSelectedBlocksIn: indentSelectedBlocksIn,
                            onIndentSelectedBlocksOut: indentSelectedBlocksOut
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAddBlockBar
        }
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

    private var bottomAddBlockBar: some View {
        HStack {
            Spacer(minLength: 0)

            if isSelectionMode {
                batchSelectionBar
            } else {
                addBlockMenu
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var isSelectionMode: Bool {
        !selectedBlockIDs.isEmpty
    }

    private var batchSelectionBar: some View {
        HStack(spacing: 10) {
            Button {
                clearBlockSelection()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("\(selectedBlockIDs.count) Selected")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                indentSelectedBlocksOut()
            } label: {
                Image(systemName: "decrease.indent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                indentSelectedBlocksIn()
            } label: {
                Image(systemName: "increase.indent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                deleteSelectedBlocks()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.red.opacity(0.26))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.36))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }
    private func enterSelectionMode(_ block: DocumentBlock) {
        selectedBlockIDs = [block.id]
    }

    private func toggleBlockSelection(_ block: DocumentBlock) {
        if selectedBlockIDs.contains(block.id) {
            selectedBlockIDs.remove(block.id)
        } else {
            selectedBlockIDs.insert(block.id)
        }
    }

    private func clearBlockSelection() {
        selectedBlockIDs.removeAll()
    }

    private func selectedBlocksInOrder() -> [DocumentBlock] {
        entry.sortedBlocks.filter { selectedBlockIDs.contains($0.id) }
    }

    private func deleteSelectedBlocks() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        clearBlockSelection()
        for block in blocks {
            deleteBlock(block)
        }
    }

    private func indentSelectedBlocksIn() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        for block in blocks where canIndentBatchBlock(block) {
            block.indentLevel = min(5, block.indentLevel + 1)
            block.touch()
        }
        save()
    }

    private func indentSelectedBlocksOut() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        for block in blocks where canIndentBatchBlock(block) {
            block.indentLevel = max(0, block.indentLevel - 1)
            block.touch()
        }
        save()
    }

    private func canIndentBatchBlock(_ block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return true
        case .divider, .code, .image:
            return false
        }
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(DocumentBlockType.allCases, id: \.self) { type in
                Button(labelForType(type)) { appendBlock(type: type) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add Block")
            }
            .frame(maxWidth: .infinity)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(LGradients.blue)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minWidth: 180)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LGradients.blue, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func appendBlock(type: DocumentBlockType) {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let newBlock = DocumentBlock(
            type: type,
            text: "",
            sortOrder: entry.sortedBlocks.count,
            parentBlockID: nil,
            listGroupID: type == .bulletedList || type == .numberedList ? UUID() : nil,
            isExpanded: type == .toggle,
            indentLevel: 0,
            calloutEmoji: type == .callout ? defaultCalloutIconID : "",
            languageHint: type == .divider ? DividerStyle.line.rawValue : ""
        )
        newBlock.entry = entry
        newBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(newBlock)
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func insertBlockBelow(_ block: DocumentBlock, _ type: DocumentBlockType, _ initialText: String = "") {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard sorted.contains(where: { $0.id == block.id }) else { return }

        let insertAfterOrder = block.sortOrder

        let shouldContinueSameList = (block.type == type && block.isListBlock && type == .bulletedList)
            || (block.type == type && block.isListBlock && type == .numberedList)

        let inheritedListGroupID: UUID? = {
            if shouldContinueSameList { return block.listGroupID }
            if type == .bulletedList || type == .numberedList { return UUID() }
            return nil
        }()

        let inheritedParentBlockID: UUID? = {
            if block.isToggleBlock { return block.id }
            return block.parentBlockID
        }()

        let inheritedIndentLevel: Int = block.isToggleBlock ? block.indentLevel + 1 : block.indentLevel

        let newBlock = DocumentBlock(
            type: type,
            text: initialText,
            sortOrder: insertAfterOrder + 1,
            parentBlockID: inheritedParentBlockID,
            listGroupID: inheritedListGroupID,
            isExpanded: type == .toggle,
            indentLevel: inheritedIndentLevel,
            calloutEmoji: type == .callout ? defaultCalloutIconID : "",
            languageHint: type == .divider ? DividerStyle.line.rawValue : ""
        )
        newBlock.entry = entry
        newBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(newBlock)

        for laterBlock in (entry.blocks ?? []) where laterBlock.id != newBlock.id && laterBlock.sortOrder > insertAfterOrder {
            laterBlock.sortOrder += 1
            laterBlock.touch()
        }

        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()

        let newBlockID = newBlock.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .documentBlockRequestFocus, object: newBlockID)
        }
    }

    private func deleteBlock(_ block: DocumentBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let blockID = block.id
        selectedBlockIDs.remove(blockID)
        let blockSortOrder = block.sortOrder

        for inlineStyle in (block.inlineStyles ?? []) { modelContext.delete(inlineStyle) }

        if let index = entry.blocks?.firstIndex(where: { $0.id == blockID }) {
            entry.blocks?.remove(at: index)
        }
        modelContext.delete(block)

        if entry.blocks?.isEmpty != false {
            if entry.blocks == nil { entry.blocks = [] }
            let replacement = DocumentBlock(type: .paragraph, text: "", sortOrder: 0)
            replacement.entry = entry
            replacement.touch()
            entry.blocks?.append(replacement)
        }

        entry.normalizeBlockSortOrders()
        save()

        let sorted = entry.sortedBlocks
        let focusTarget = sorted.first(where: { $0.sortOrder >= blockSortOrder }) ?? sorted.last
        if let target = focusTarget {
            let targetID = target.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: .documentBlockRequestFocus, object: targetID)
            }
        }
    }

    private func moveBlockUp(_ block: DocumentBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard let index = sorted.firstIndex(where: { $0.id == block.id }), index > 0 else { return }

        let above = sorted[index - 1]
        let currentOrder = block.sortOrder
        block.sortOrder = above.sortOrder
        above.sortOrder = currentOrder
        block.touch(); above.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func moveBlockDown(_ block: DocumentBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard let index = sorted.firstIndex(where: { $0.id == block.id }), index < sorted.count - 1 else { return }

        let below = sorted[index + 1]
        let currentOrder = block.sortOrder
        block.sortOrder = below.sortOrder
        below.sortOrder = currentOrder
        block.touch(); below.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func transformBlock(_ block: DocumentBlock, _ type: DocumentBlockType) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        block.type = type

        if type == .bulletedList || type == .numberedList || type == .checklist {
            if block.listGroupID == nil { block.listGroupID = UUID() }
        } else {
            block.listGroupID = nil
        }

        if type == .toggle { block.isExpanded = true }
        else if !block.isToggleBlock { block.parentBlockID = nil }

        switch type {
        case .callout:
            block.parentBlockID = nil; block.indentLevel = 0
            if block.calloutEmoji.isEmpty { block.calloutEmoji = defaultCalloutIconID }
        case .divider:
            block.parentBlockID = nil; block.indentLevel = 0
            block.text = ""; block.languageHint = DividerStyle.line.rawValue
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .code:
            block.parentBlockID = nil; block.indentLevel = 0
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .image:
            block.parentBlockID = nil; block.indentLevel = 0
            block.text = ""
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .blockquote:
            block.parentBlockID = nil; block.indentLevel = 0; block.languageHint = ""
        case .toggle:
            block.parentBlockID = nil; block.indentLevel = 0; block.languageHint = ""; block.isExpanded = true
        case .bulletedList, .numberedList:
            block.parentBlockID = nil; block.indentLevel = 0; block.languageHint = ""
        case .checklist:
            block.parentBlockID = nil; block.indentLevel = 0
            if block.languageHint != "checked" && block.languageHint != "xmark" {
                block.languageHint = ""
            }
        }

        block.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private var defaultCalloutIconID: String {
        "asset:sparkle"
    }

    private func labelForType(_ type: DocumentBlockType) -> String {
        switch type {
        case .paragraph: return "Paragraph"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .toggle: return "Toggle"
        case .bulletedList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .checklist: return "Checklist"
        case .blockquote: return "Blockquote"
        case .callout: return "Callout"
        case .divider: return "Divider"
        case .code: return "Code Block"
        case .image: return "Image"
        }
    }

    private func reorderBlockToIndex(source: DocumentBlock, toIndex: Int) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard let fromIndex = sorted.firstIndex(where: { $0.id == source.id }) else { return }

        var reordered = sorted
        let clampedTo = min(toIndex, reordered.count)
        reordered.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: clampedTo > fromIndex ? clampedTo : clampedTo)

        for (i, block) in reordered.enumerated() {
            block.sortOrder = i
            block.touch()
        }

        entry.normalizeBlockSortOrders()
        save()
    }

    private func save() {
        do { try modelContext.save() } catch { print("Failed to save document blocks: \(error)") }
    }
}

// MARK: - Drop Zone

struct DocumentBlockDropZone: View {
    let index: Int
    @Binding var dragOverIndex: Int?

    var body: some View {
        ZStack {
            if dragOverIndex == index {
                Capsule().fill(LGradients.blue).frame(height: 3).padding(.horizontal, 8)
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Passthrough Tap Recognizer

struct PageSheetTapOverlay: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func tapped() { onTap() }
    }
}

struct DocumentIndexedDropDelegate: DropDelegate {
    let index: Int
    @Binding var draggingBlock: DocumentBlock?
    @Binding var dragOverIndex: Int?
    let visibleBlocks: [DocumentBlock]
    let onMove: (DocumentBlock, Int) -> Void

    func dropEntered(info: DropInfo) { dragOverIndex = index }
    func dropUpdated(info: DropInfo) -> DropProposal? { dragOverIndex = index; return DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { if dragOverIndex == index { dragOverIndex = nil } }
    func performDrop(info: DropInfo) -> Bool {
        guard let source = draggingBlock else { draggingBlock = nil; dragOverIndex = nil; return false }
        onMove(source, index)
        draggingBlock = nil; dragOverIndex = nil
        return true
    }
}
