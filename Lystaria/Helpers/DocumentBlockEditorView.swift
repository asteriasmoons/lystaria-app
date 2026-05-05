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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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

                ForEach(Array(visibleBlocks.enumerated()), id: \.element.id) { i, block in
                    DocumentBlockRow(
                        block: block,
                        onAddBelow: { b, type, initialText in insertBlockBelow(b, type, initialText) },
                        onDelete: deleteBlock,
                        onMoveUp: moveBlockUp,
                        onMoveDown: moveBlockDown,
                        onTransform: transformBlock
                    )
                    .opacity(draggingBlock?.id == block.id ? 0.4 : 1)
                    .contextMenu {
                        Button(role: .destructive) { deleteBlock(block) } label: {
                            Label("Delete Block", systemImage: "trash")
                        }
                        Button { moveBlockUp(block) } label: {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        Button { moveBlockDown(block) } label: {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                    }
                    .onDrag {
                        draggingBlock = block
                        dragOverIndex = nil
                        return NSItemProvider(object: block.id.uuidString as NSString)
                    }
                    .padding(.vertical, 6)

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
            .padding(.horizontal)
            .padding(.top)
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
            addBlockMenu
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            calloutEmoji: type == .callout ? "✦" : "",
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
            calloutEmoji: type == .callout ? "✦" : "",
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

        if type == .bulletedList || type == .numberedList {
            if block.listGroupID == nil { block.listGroupID = UUID() }
        } else {
            block.listGroupID = nil
        }

        if type == .toggle { block.isExpanded = true }
        else if !block.isToggleBlock { block.parentBlockID = nil }

        switch type {
        case .callout:
            block.parentBlockID = nil; block.indentLevel = 0
            if block.calloutEmoji.isEmpty { block.calloutEmoji = "✦" }
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
        }

        block.touch()
        entry.normalizeBlockSortOrders()
        save()
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
