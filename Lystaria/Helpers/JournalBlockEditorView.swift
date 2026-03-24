//
//  JournalBlockEditorView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import SwiftUI
import SwiftData

struct JournalBlockEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: JournalEntry
    @State private var isMutatingBlocks = false

    var body: some View {
        ScrollView {
            // Block to Block Spacing is 12 
            VStack(alignment: .leading, spacing: 12) {
                ForEach(visibleBlocks) { block in
                    JournalBlockRow(
                        block: block,
                        onAddBelow: insertBlockBelow,
                        onDelete: deleteBlock,
                        onMoveUp: moveBlockUp,
                        onMoveDown: moveBlockDown,
                        onTransform: transformBlock
                    )
                }
            }
            .padding()
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAddBlockBar
        }
    }

    /// Mirrors the same logic as JournalBlockDisplayView.visibleBlocks —
    /// hides child blocks whose toggle parent is collapsed.
    private var visibleBlocks: [JournalBlock] {
        var hiddenParentIDs = Set<UUID>()
        var result: [JournalBlock] = []

        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                // This block is hidden inside a collapsed toggle.
                // If it's itself a toggle, also hide its children.
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
            ForEach(JournalBlockType.allCases, id: \.self) { type in
                Button(labelForType(type)) {
                    appendBlock(type: type)
                }
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
            .overlay(
                Capsule().stroke(LGradients.blue, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func appendBlock(type: JournalBlockType) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let newBlock = JournalBlock(
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
        if entry.blocks == nil {
            entry.blocks = []
        }
        entry.blocks?.append(newBlock)
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func insertBlockBelow(_ block: JournalBlock, _ type: JournalBlockType) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard sorted.contains(where: { $0.id == block.id }) else { return }

        // Capture the current block's sortOrder before any mutations
        let insertAfterOrder = block.sortOrder

        let shouldContinueSameList = block.type == type && block.isListBlock && type == .bulletedList || block.type == type && block.isListBlock && type == .numberedList
        let inheritedListGroupID: UUID? = {
            if shouldContinueSameList {
                return block.listGroupID
            }
            if type == .bulletedList || type == .numberedList {
                return UUID()
            }
            return nil
        }()

        let inheritedParentBlockID: UUID? = {
            if block.isToggleBlock {
                // Pressing return on the toggle header → child goes inside the toggle
                return block.id
            }
            // Pressing return on a child block → new block stays in the same toggle
            return block.parentBlockID
        }()

        let inheritedIndentLevel: Int = {
            if block.isToggleBlock {
                return block.indentLevel + 1
            }
            return block.indentLevel
        }()

        let newBlock = JournalBlock(
            type: type,
            text: "",
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
        if entry.blocks == nil {
            entry.blocks = []
        }
        entry.blocks?.append(newBlock)

        // Shift all blocks that came after the insertion point
        for laterBlock in (entry.blocks ?? []) where laterBlock.id != newBlock.id && laterBlock.sortOrder > insertAfterOrder {
            laterBlock.sortOrder += 1
            laterBlock.touch()
        }

        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()

        let newBlockID = newBlock.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(
                name: .journalBlockRequestFocus,
                object: newBlockID
            )
        }
    }

    private func deleteBlock(_ block: JournalBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let blockID = block.id
        let blockSortOrder = block.sortOrder

        for inlineStyle in (block.inlineStyles ?? []) {
            modelContext.delete(inlineStyle)
        }

        if let index = entry.blocks?.firstIndex(where: { $0.id == blockID }) {
            entry.blocks?.remove(at: index)
        }

        modelContext.delete(block)

        // If the entry is now empty, insert a starter paragraph.
        if entry.blocks?.isEmpty != false {
            if entry.blocks == nil {
                entry.blocks = []
            }
            let replacement = JournalBlock(type: .paragraph, text: "", sortOrder: 0)
            replacement.entry = entry
            replacement.touch()
            entry.blocks?.append(replacement)
        }

        entry.normalizeBlockSortOrders()
        save()

        // Focus the block that now occupies the deleted block's position,
        // or the one just before it — this is the "exit list" landing spot.
        let sorted = entry.sortedBlocks
        let focusTarget = sorted.first(where: { $0.sortOrder >= blockSortOrder }) ?? sorted.last
        if let target = focusTarget {
            let targetID = target.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: .journalBlockRequestFocus,
                    object: targetID
                )
            }
        }
    }

    private func moveBlockUp(_ block: JournalBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard let index = sorted.firstIndex(where: { $0.id == block.id }), index > 0 else { return }

        let above = sorted[index - 1]
        let currentOrder = block.sortOrder
        block.sortOrder = above.sortOrder
        above.sortOrder = currentOrder

        block.touch()
        above.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func moveBlockDown(_ block: JournalBlock) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        let sorted = entry.sortedBlocks
        guard let index = sorted.firstIndex(where: { $0.id == block.id }), index < sorted.count - 1 else { return }

        let below = sorted[index + 1]
        let currentOrder = block.sortOrder
        block.sortOrder = below.sortOrder
        below.sortOrder = currentOrder

        block.touch()
        below.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func transformBlock(_ block: JournalBlock, _ type: JournalBlockType) {
        guard !isMutatingBlocks else { return }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }

        block.type = type

        if type == .bulletedList || type == .numberedList {
            if block.listGroupID == nil {
                block.listGroupID = UUID()
            }
        } else {
            block.listGroupID = nil
        }

        if type == .toggle {
            block.isExpanded = true
        } else if !block.isToggleBlock {
            block.parentBlockID = nil
        }

        switch type {
        case .callout:
            block.parentBlockID = nil
            block.indentLevel = 0
            if block.calloutEmoji.isEmpty {
                block.calloutEmoji = "✦"
            }
        case .divider:
            block.parentBlockID = nil
            block.indentLevel = 0
            block.text = ""
            block.languageHint = DividerStyle.line.rawValue
            for inlineStyle in (block.inlineStyles ?? []) {
                modelContext.delete(inlineStyle)
            }
            block.inlineStyles = []
        case .code:
            block.parentBlockID = nil
            block.indentLevel = 0
            for inlineStyle in (block.inlineStyles ?? []) {
                modelContext.delete(inlineStyle)
            }
            block.inlineStyles = []
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .blockquote:
            block.parentBlockID = nil
            block.indentLevel = 0
            block.languageHint = ""
        case .toggle:
            block.parentBlockID = nil
            block.indentLevel = 0
            block.languageHint = ""
            block.isExpanded = true
        case .bulletedList, .numberedList:
            block.parentBlockID = nil
            block.indentLevel = 0
            block.languageHint = ""
        }

        block.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func labelForType(_ type: JournalBlockType) -> String {
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

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save journal blocks: \(error)")
        }
    }
}
