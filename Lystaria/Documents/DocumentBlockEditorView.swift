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
    /// Optional header injected at the top of the first page card (used by the editor page for identity)
    var identityHeader: AnyView? = nil
    @State private var isMutatingBlocks = false
    @State private var draggingBlock: DocumentBlock? = nil
    @State private var dragOverIndex: Int? = nil
    @State private var selectedBlockIDs: Set<UUID> = []
    @State private var focusedBlockID: UUID? = nil
    @State private var isKeyboardVisible: Bool = false
    @State private var showInlinePropertyDefinitionSheet = false

    // Split visible blocks into page segments at .pageBreak dividers
    private var blockPages: [(blocks: [(Int, DocumentBlock)], breakBlock: DocumentBlock?)] {
        var pages: [(blocks: [(Int, DocumentBlock)], breakBlock: DocumentBlock?)] = [([], nil)]
        for item in Array(visibleBlocks.enumerated()) {
            let block = item.element
            if block.type == .divider,
               (DividerStyles(rawValue: block.languageHint) ?? .line) == .pageBreak {
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
        ZStack(alignment: .topTrailing) {
            DocumentEntryBackground(entry: entry)

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

                        VStack(alignment: .leading, spacing: 0) {
                            // Inject identity header at top of first page card only
                            if pageIndex == 0, let header = identityHeader {
                                header
                            }

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
                                        onIndentSelectedBlocksOut: indentSelectedBlocksOut,
                                        documentTextColor: resolvedDocumentTextColor
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
                            .padding(.bottom, 28)
                            .padding(.top, (pageIndex == 0 && identityHeader != nil) ? 8 : 28)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(0.34))
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                                .overlay(
                                    PageSheetTapOverlay {
                                        guard !isSelectionMode else { return }
                                        if let last = page.last?.1 {
                                            if last.type == .paragraph && last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

                        // Page break block between sheets
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
                                onIndentSelectedBlocksOut: indentSelectedBlocksOut,
                                documentTextColor: resolvedDocumentTextColor
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 140)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAddBlockBar
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .documentBlockDidFocus)) { note in
            if let info = note.object as? [String: Any],
               let id = info["id"] as? UUID {
                focusedBlockID = id
            }
        }
        .sheet(isPresented: $showInlinePropertyDefinitionSheet) {
            DocumentInlinePropertyDefinitionSheet { draft in
                appendInlineProperty(draft)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    private var resolvedDocumentTextColor: UIColor {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hex.isEmpty,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else {
            return UIColor(LColors.textPrimary)
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
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
            if isSelectionMode { batchSelectionBar }
            else if isKeyboardVisible { keyboardBar }
            else { addBlockMenu }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var keyboardBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(DocumentBlockType.allCases, id: \.self) { type in
                    Button(labelForType(type)) { appendBlock(type: type) }
                }
                Divider()
                Button { showInlinePropertyDefinitionSheet = true } label: {
                    Label("Property", systemImage: "tag.fill")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Block")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LGradients.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LGradients.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.36))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }

    private var isSelectionMode: Bool { !selectedBlockIDs.isEmpty }

    private var batchSelectionBar: some View {
        HStack(spacing: 10) {
            Button { clearBlockSelection() } label: {
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

            Button { indentSelectedBlocksOut() } label: {
                Image(systemName: "decrease.indent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button { indentSelectedBlocksIn() } label: {
                Image(systemName: "increase.indent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) { deleteSelectedBlocks() } label: {
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

    private func enterSelectionMode(_ block: DocumentBlock) { selectedBlockIDs = [block.id] }
    private func toggleBlockSelection(_ block: DocumentBlock) {
        if selectedBlockIDs.contains(block.id) { selectedBlockIDs.remove(block.id) }
        else { selectedBlockIDs.insert(block.id) }
    }
    private func clearBlockSelection() { selectedBlockIDs.removeAll() }
    private func selectedBlocksInOrder() -> [DocumentBlock] {
        entry.sortedBlocks.filter { selectedBlockIDs.contains($0.id) }
    }

    private func deleteSelectedBlocks() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        clearBlockSelection()
        for block in blocks { deleteBlock(block) }
    }

    private func indentSelectedBlocksIn() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        for block in blocks where canIndentBatchBlock(block) {
            block.indentLevel = min(5, block.indentLevel + 1); block.touch()
        }
        save()
    }

    private func indentSelectedBlocksOut() {
        let blocks = selectedBlocksInOrder()
        guard !blocks.isEmpty else { return }
        for block in blocks where canIndentBatchBlock(block) {
            block.indentLevel = max(0, block.indentLevel - 1); block.touch()
        }
        save()
    }

    private func canIndentBatchBlock(_ block: DocumentBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return true
        case .divider, .code, .image, .table:
            return false
        }
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(DocumentBlockType.allCases, id: \.self) { type in
                Button(labelForType(type)) { appendBlock(type: type) }
            }
            Divider()
            Button { showInlinePropertyDefinitionSheet = true } label: {
                Label("Property", systemImage: "tag.fill")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add Block")
            }
            .frame(maxWidth: .infinity)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minWidth: 180)
            .background(LGradients.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func appendBlock(type: DocumentBlockType) {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        if let focusedID = focusedBlockID,
           let focusedBlock = entry.sortedBlocks.first(where: { $0.id == focusedID }) {
            insertBlockBelow(focusedBlock, type, "")
            return
        }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }
        let newBlock = DocumentBlock(
            type: type,
            text: type == .table ? DocumentTableData().toJSON() : "",
            sortOrder: entry.sortedBlocks.count,
            parentBlockID: nil,
            listGroupID: type == .bulletedList || type == .numberedList ? UUID() : nil,
            isExpanded: type == .toggle || type.isToggleHeading,
            indentLevel: 0,
            calloutEmoji: type == .callout ? defaultCalloutIconID : "",
            languageHint: type == .divider ? DividerStyle.line.rawValue : ""
        )
        newBlock.entry = entry; newBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(newBlock)
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func appendInlineProperty(_ draft: DocumentInlinePropertyDraft) {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        let displayText = inlinePropertyDisplayText(from: draft)
        if let focusedID = focusedBlockID,
           let focusedBlock = entry.sortedBlocks.first(where: { $0.id == focusedID }) {
            insertInlinePropertyBelow(focusedBlock, draft: draft, displayText: displayText)
            return
        }
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }
        let propertyBlock = DocumentBlock(type: .paragraph, text: displayText, sortOrder: entry.sortedBlocks.count, parentBlockID: nil, listGroupID: nil, isExpanded: false, indentLevel: 0, calloutEmoji: "", languageHint: "")
        propertyBlock.entry = entry; propertyBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(propertyBlock)
        attachInlineProperty(draft, to: propertyBlock, displayText: displayText)
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()
    }

    private func insertInlinePropertyBelow(_ block: DocumentBlock, draft: DocumentInlinePropertyDraft, displayText: String) {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }
        let sorted = entry.sortedBlocks
        guard sorted.contains(where: { $0.id == block.id }) else { return }
        let insertAfterOrder = block.sortOrder
        let inheritedParentBlockID: UUID? = block.isToggleBlock ? block.id : block.parentBlockID
        let inheritedIndentLevel: Int = block.isToggleBlock ? block.indentLevel + 1 : block.indentLevel
        let propertyBlock = DocumentBlock(type: .paragraph, text: displayText, sortOrder: insertAfterOrder + 1, parentBlockID: inheritedParentBlockID, listGroupID: nil, isExpanded: false, indentLevel: inheritedIndentLevel, calloutEmoji: "", languageHint: "")
        propertyBlock.entry = entry; propertyBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(propertyBlock)
        for laterBlock in (entry.blocks ?? []) where laterBlock.id != propertyBlock.id && laterBlock.sortOrder > insertAfterOrder {
            laterBlock.sortOrder += 1; laterBlock.touch()
        }
        attachInlineProperty(draft, to: propertyBlock, displayText: displayText)
        entry.ensureStarterBlock()
        entry.normalizeBlockSortOrders()
        save()
        let newBlockID = propertyBlock.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .documentBlockRequestFocus, object: newBlockID)
        }
    }

    private func attachInlineProperty(_ draft: DocumentInlinePropertyDraft, to block: DocumentBlock, displayText: String) {
        let property = DocumentInlineProperty(name: draft.name, type: draft.type, valueStorage: draft.valueStorage, optionsStorage: draft.optionsStorage, colorHex: draft.colorHex, rangeLocation: 0, rangeLength: (displayText as NSString).length, block: block)
        modelContext.insert(property)
        if block.inlineProperties == nil { block.inlineProperties = [] }
        block.inlineProperties?.append(property)
        block.touch()
    }

    private func inlinePropertyDisplayText(from draft: DocumentInlinePropertyDraft) -> String {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? draft.type.rawValue : trimmedName
        switch draft.type {
        case .boolean: return "\(name): \(draft.valueStorage == "true" ? "True" : "False")"
        case .checkbox: return "\(name): \(draft.valueStorage == "true" ? "Checked" : "Unchecked")"
        case .text, .number, .url, .select:
            let value = draft.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? name : "\(name): \(value)"
        case .date:
            if let date = ISO8601DateFormatter().date(from: draft.valueStorage) {
                return "\(name): \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return name
        case .multiSelect:
            guard let data = draft.valueStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([String].self, from: data), !values.isEmpty else { return name }
            return "\(name): \(values.joined(separator: ", "))"
        }
    }

    private func insertBlockBelow(_ block: DocumentBlock, _ type: DocumentBlockType, _ initialText: String = "") {
        guard !isMutatingBlocks else { return }
        clearBlockSelection()
        isMutatingBlocks = true
        defer { isMutatingBlocks = false }
        let sorted = entry.sortedBlocks
        guard sorted.contains(where: { $0.id == block.id }) else { return }
        let insertAfterOrder = block.sortOrder
        let shouldContinueSameList = (block.type == type && block.isListBlock && type == .bulletedList) || (block.type == type && block.isListBlock && type == .numberedList)
        let inheritedListGroupID: UUID? = {
            if shouldContinueSameList { return block.listGroupID }
            if type == .bulletedList || type == .numberedList { return UUID() }
            return nil
        }()
        let inheritedParentBlockID: UUID? = block.isToggleBlock ? block.id : block.parentBlockID
        let inheritedIndentLevel: Int = block.isToggleBlock ? block.indentLevel + 1 : block.indentLevel
        let newBlock = DocumentBlock(
            type: type,
            text: type == .table ? (initialText.isEmpty ? DocumentTableData().toJSON() : initialText) : initialText,
            sortOrder: insertAfterOrder + 1,
            parentBlockID: inheritedParentBlockID,
            listGroupID: inheritedListGroupID,
            isExpanded: type == .toggle || type.isToggleHeading,
            indentLevel: inheritedIndentLevel,
            calloutEmoji: type == .callout ? defaultCalloutIconID : "",
            languageHint: type == .divider ? DividerStyle.line.rawValue : ""
        )
        newBlock.entry = entry; newBlock.touch()
        if entry.blocks == nil { entry.blocks = [] }
        entry.blocks?.append(newBlock)
        for laterBlock in (entry.blocks ?? []) where laterBlock.id != newBlock.id && laterBlock.sortOrder > insertAfterOrder {
            laterBlock.sortOrder += 1; laterBlock.touch()
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
        if let index = entry.blocks?.firstIndex(where: { $0.id == blockID }) { entry.blocks?.remove(at: index) }
        modelContext.delete(block)
        if entry.blocks?.isEmpty != false {
            if entry.blocks == nil { entry.blocks = [] }
            let replacement = DocumentBlock(type: .paragraph, text: "", sortOrder: 0)
            replacement.entry = entry; replacement.touch()
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
        block.sortOrder = above.sortOrder; above.sortOrder = currentOrder
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
        block.sortOrder = below.sortOrder; below.sortOrder = currentOrder
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
        } else { block.listGroupID = nil }
        if type == .toggle || type.isToggleHeading { block.isExpanded = true }
        else if !block.isToggleBlock { block.parentBlockID = nil }
        let wasToggleChild = block.parentBlockID != nil
        switch type {
        case .callout:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            if block.calloutEmoji.isEmpty { block.calloutEmoji = defaultCalloutIconID }
        case .divider:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            block.text = ""; block.languageHint = DividerStyle.line.rawValue
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .code:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .image:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            block.text = ""
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6, .blockquote:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            block.languageHint = ""
        case .toggle, .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            block.languageHint = ""; block.isExpanded = true
        case .bulletedList, .numberedList:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            block.languageHint = ""
        case .checklist:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = wasToggleChild ? block.indentLevel : 0
            if block.languageHint != "checked" && block.languageHint != "xmark" { block.languageHint = "" }
        case .table:
            if !wasToggleChild { block.parentBlockID = nil }
            block.indentLevel = 0
            block.text = DocumentTableData().toJSON()
            for s in (block.inlineStyles ?? []) { modelContext.delete(s) }
            block.inlineStyles = []
        }
        block.touch()
        entry.normalizeBlockSortOrders()
        save()
    }

    private var defaultCalloutIconID: String { "asset:sparkle" }

    private func labelForType(_ type: DocumentBlockType) -> String {
        switch type {
        case .paragraph: return "Paragraph"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .heading5: return "Heading 5"
        case .heading6: return "Heading 6"
        case .toggleHeading1: return "Toggle H1"
        case .toggleHeading2: return "Toggle H2"
        case .toggleHeading3: return "Toggle H3"
        case .toggleHeading4: return "Toggle H4"
        case .toggleHeading5: return "Toggle H5"
        case .toggleHeading6: return "Toggle H6"
        case .toggle: return "Toggle"
        case .bulletedList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .checklist: return "Checklist"
        case .blockquote: return "Blockquote"
        case .callout: return "Callout"
        case .divider: return "Divider"
        case .code: return "Code Block"
        case .image: return "Image"
        case .table: return "Table"
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
        for (i, block) in reordered.enumerated() { block.sortOrder = i; block.touch() }
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

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.onTap = onTap }
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
