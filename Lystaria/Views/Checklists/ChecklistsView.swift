//
// ChecklistsView.swift
//
// Created By Asteria Moon
//

import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers

// MARK: - ChecklistsView (Items Screen)

struct ChecklistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Using your existing container model.
    @Query(sort: \Checklist.createdAt, order: .forward)
    private var checklists: [Checklist]

    @State private var tab: ChecklistTab = .active
    @State private var selectedChecklistID: PersistentIdentifier?
    @State private var draggedItem: ChecklistItem?
    // In-memory reorder buffer — mutated during drag, flushed to SwiftData on drop
    @State private var dragBuffer: [ChecklistItem] = []
    @State private var renamingChecklistID: PersistentIdentifier?
    @State private var renameDraft: String = ""

    // Pagination
    @State private var visibleCount: Int = 4
    private let pageSize: Int = 4

    private var activeChecklist: Checklist? {
        if let selectedChecklistID,
           let selected = checklists.first(where: { $0.persistentModelID == selectedChecklistID }) {
            return selected
        }
        return checklists.first
    }

    private var itemsSorted: [ChecklistItem] {
        // During a drag use the in-memory buffer so the UI reflects reordering
        // without any SwiftData writes happening mid-drag.
        if !dragBuffer.isEmpty { return dragBuffer }
        guard let c = activeChecklist else { return [] }
        return (c.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filteredItems: [ChecklistItem] {
        switch tab {
        case .active:
            return itemsSorted.filter { !$0.isCompleted }
        case .done:
            return itemsSorted.filter { $0.isCompleted }
        case .all:
            return itemsSorted
        }
    }

    private var visibleItems: [ChecklistItem] {
        Array(filteredItems.prefix(visibleCount))
    }

    private var canLoadMore: Bool {
        filteredItems.count > visibleCount
    }

    private var checklistTabs: [Checklist] {
        checklists.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var selectedChecklistName: String {
        activeChecklist?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (activeChecklist?.name ?? "Checklist")
            : "Checklist"
    }

    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        // Prevent scroll-to-dismiss keyboard gestures from delaying taps/focus.
        .scrollDismissesKeyboard(.immediately)
        .background(
            LystariaBackground()
                .ignoresSafeArea()
        )
        // Keep FAB above the tab bar without blocking taps on content.
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                FloatingActionButton {
                    ensureDefaultChecklistIfNeeded()
                    addNewItem()
                }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 96)
            // Lift above your bottom navigation/tab bar.
            .padding(.top, 10)
            .background(Color.clear)
        }
        .onChange(of: tab) { _, _ in
            visibleCount = pageSize
            resetDragState()
        }
        .onChange(of: filteredItems.count) { _, newValue in
            // If the list shrinks (deletes / tab change), keep visibleCount in range.
            if visibleCount > newValue {
                visibleCount = max(pageSize, newValue)
            }
            if visibleCount < pageSize {
                visibleCount = pageSize
            }
        }
        .onAppear {
            syncSelectedChecklistIfNeeded()
        }
        .onChange(of: checklists.count) { _, _ in
            resetDragState()
            syncSelectedChecklistIfNeeded()
        }
        .onChange(of: selectedChecklistID) { _, _ in
            resetDragState()
            if renamingChecklistID != selectedChecklistID {
                renamingChecklistID = nil
                renameDraft = ""
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            checklistContainerTabs

            VStack(spacing: 14) {
                tabs
                mainContent

                // Extra scroll room so the last card is never clipped by the tab bar / FAB.
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if activeChecklist == nil {
            GlassCard {
                EmptyState(
                    icon: "checklist",
                    message: "No checklist yet.\nTap + in the header to add your first checklist.",
                    actionLabel: "Add Item"
                ) {
                    ensureDefaultChecklistIfNeeded()
                    addNewItem()
                }
            }
        } else if filteredItems.isEmpty {
            GlassCard {
                EmptyState(
                    icon: "checklist",
                    message: emptyMessage,
                    actionLabel: tab == .done ? "View Active" : "Add Item"
                ) {
                    if tab == .done {
                        tab = .active
                    } else {
                        addNewItem()
                    }
                }
            }
        } else {
            checklistItemsSection
        }
    }

    private var checklistItemsSection: some View {
        VStack(spacing: 12) {
            ForEach(visibleItems, id: \.persistentModelID) { item in
                draggableChecklistCard(for: item)
            }

            if canLoadMore {
                LoadMoreButton {
                    visibleCount += pageSize
                }
                .padding(.top, 4)
            }
        }
    }

    private func draggableChecklistCard(for item: ChecklistItem) -> some View {
        let isDragging = draggedItem?.persistentModelID == item.persistentModelID

        return ChecklistItemCard(item: item, isDragging: isDragging)
            .onDrag {
                draggedItem = item
                // Seed the buffer once when the drag starts so all mid-drag
                // reorders mutate only in-memory state.
                if dragBuffer.isEmpty {
                    dragBuffer = itemsSorted
                }
                return NSItemProvider(object: NSString(string: String(describing: item.persistentModelID)))
            }
            .onDrop(
                of: [.text],
                delegate: ChecklistItemDropDelegate(
                    targetItem: item,
                    draggedItem: $draggedItem,
                    dragBuffer: $dragBuffer,
                    reorderAction: reorderInBuffer,
                    commitAction: commitDrop
                )
            )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GradientTitle(text: "Checklists", font: .title2.bold())
                Spacer()

                Button {
                    addNewChecklist()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 6)
        }
    }

    private var checklistContainerTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(checklistTabs, id: \.persistentModelID) { checklist in
                    checklistContainerTab(for: checklist)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.top, 12)
        }
    }

    private func checklistContainerTab(for checklist: Checklist) -> some View {
        let isSelected = activeChecklist?.persistentModelID == checklist.persistentModelID
        let isRenaming = renamingChecklistID == checklist.persistentModelID
        let title = checklist.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Checklist" : checklist.name

        return VStack(spacing: 0) {
            if isRenaming {
                TextField("Checklist name", text: $renameDraft)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit {
                        commitRename(for: checklist)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            } else {
                Button {
                    selectedChecklistID = checklist.persistentModelID
                    visibleCount = pageSize
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color.white.opacity(0.28) : LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename") {
                        beginRenaming(checklist)
                    }
                }
            }
        }
    }

    // MARK: - Tabs

    private var tabs: some View {
        Picker("", selection: $tab) {
            ForEach(ChecklistTab.allCases, id: \.self) { t in
                Text(t.label).tag(t)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyMessage: String {
        switch tab {
        case .active:
            return "No active items in \(selectedChecklistName).\nTap + below to add one."
        case .done:
            return "No completed items in \(selectedChecklistName) yet.\nFinish something first."
        case .all:
            return "No items in \(selectedChecklistName) yet.\nTap + below to add one."
        }
    }

    // MARK: - Actions

    private func syncSelectedChecklistIfNeeded() {
        if let selectedChecklistID,
           checklists.contains(where: { $0.persistentModelID == selectedChecklistID }) {
            return
        }

        selectedChecklistID = checklistTabs.first?.persistentModelID
    }

    private func addNewChecklist() {
        let nextSortOrder = (checklistTabs.map { $0.sortOrder }.max() ?? -1) + 1
        let checklistNumber = checklistTabs.count + 1
        let newChecklist = Checklist(name: "Checklist \(checklistNumber)", sortOrder: nextSortOrder)
        modelContext.insert(newChecklist)
        try? modelContext.save()

        selectedChecklistID = newChecklist.persistentModelID
        visibleCount = pageSize
        tab = .active
        beginRenaming(newChecklist)
    }
    
    private func beginRenaming(_ checklist: Checklist) {
        renamingChecklistID = checklist.persistentModelID
        let currentName = checklist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        renameDraft = currentName.isEmpty ? "Checklist" : checklist.name
    }

    private func commitRename(for checklist: Checklist) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        checklist.name = trimmed.isEmpty ? "Checklist" : trimmed
        checklist.updatedAt = Date()
        checklist.needsSync = true
        try? modelContext.save()
        renamingChecklistID = nil
        renameDraft = ""
    }

    private func resetDragState() {
        draggedItem = nil
        dragBuffer = []
    }

    // Called on every dropEntered — pure in-memory swap, zero I/O.
    private func reorderInBuffer(_ item: ChecklistItem, before target: ChecklistItem) {
        guard item.persistentModelID != target.persistentModelID else { return }
        guard !dragBuffer.isEmpty else { return }

        guard let fromIndex = dragBuffer.firstIndex(where: { $0.persistentModelID == item.persistentModelID }),
              let toIndex   = dragBuffer.firstIndex(where: { $0.persistentModelID == target.persistentModelID }) else {
            return
        }

        var reordered = dragBuffer
        let movingItem = reordered.remove(at: fromIndex)
        let adjustedIndex = fromIndex < toIndex ? max(toIndex - 1, 0) : toIndex
        reordered.insert(movingItem, at: adjustedIndex)
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
            dragBuffer = reordered
        }
    }

    // Called once on performDrop — flushes sortOrder to SwiftData.
    private func commitDrop() {
        guard !dragBuffer.isEmpty else {
            draggedItem = nil
            return
        }

        for (index, item) in dragBuffer.enumerated() {
            item.sortOrder = index
        }
        activeChecklist?.updatedAt = Date()
        activeChecklist?.needsSync = true
        try? modelContext.save()
        draggedItem = nil
        dragBuffer = []
    }

    private func ensureDefaultChecklistIfNeeded() {
        if activeChecklist == nil {
            let c = Checklist(name: "Checklist 1", sortOrder: 0)
            modelContext.insert(c)
            try? modelContext.save()
            selectedChecklistID = c.persistentModelID
        }
    }

    private func addNewItem() {
        guard let c = activeChecklist else {
            ensureDefaultChecklistIfNeeded()
            guard let checklist = activeChecklist else { return }
            let nextOrder = ((checklist.items ?? []).map { $0.sortOrder }.max() ?? -1) + 1

            let item = ChecklistItem(
                text: "",
                sortOrder: nextOrder,
                checklist: checklist
            )
            modelContext.insert(item)
            checklist.updatedAt = Date()
            checklist.needsSync = true
            try? modelContext.save()
            tab = .active
            return
        }
        let nextOrder = ((c.items ?? []).map { $0.sortOrder }.max() ?? -1) + 1

        let item = ChecklistItem(
            text: "",
            sortOrder: nextOrder,
            checklist: c
        )
        modelContext.insert(item)
        c.updatedAt = Date()
        c.needsSync = true
        try? modelContext.save()

        // Always show Active tab after adding.
        tab = .active
    }
}

// MARK: - Tab Enum

private enum ChecklistTab: CaseIterable {
    case active
    case done
    case all

    var label: String {
        switch self {
        case .active: return "Active"
        case .done: return "Done"
        case .all: return "All"
        }
    }
}

// MARK: - Checklist Item Card

private struct ChecklistItemCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.sortOrder, order: .forward) private var allChecklists: [Checklist]
    @Bindable var item: ChecklistItem
    let isDragging: Bool

    @State private var isEditing: Bool = false

    private enum Field: Hashable {
        case text
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        GlassCard {
            VStack {
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        toggleComplete()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.isCompleted ? LColors.success : Color.white.opacity(0.06))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().stroke(item.isCompleted ? LColors.success : LColors.glassBorder, lineWidth: 2)
                                )

                            if item.isCompleted {
                                Image("checkfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        if isEditing {
                            TextField("Checklist item…", text: $item.text)
                                .focused($focusedField, equals: .text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .submitLabel(.done)
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(false)
                                .textFieldStyle(.plain)
                                .allowsHitTesting(true)
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        focusedField = .text
                                    }
                                )
                                .onSubmit {
                                    isEditing = false
                                    focusedField = nil
                                    // Ensure the keyboard dismisses immediately.
                                    DispatchQueue.main.async {
                                        isEditing = false
                                        focusedField = nil
                                    }
                                    persistTouch()
                                }
                                .onChange(of: item.text) { _, _ in
                                    // Mark parent dirty, but do NOT save on every keystroke.
                                    item.checklist?.updatedAt = Date()
                                    item.checklist?.needsSync = true
                                }
                        } else {
                            // Show full text on card (wrap) when not editing.
                            let displayText = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(displayText.isEmpty ? "Checklist item…" : item.text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(displayText.isEmpty ? LColors.textSecondary : LColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .contentShape(Rectangle())
                                // High-priority tap avoids the ScrollView delay and feels instant.
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        beginEditing()
                                    }
                                )
                        }

                        if item.isCompleted {
                            Text("Completed")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    Menu {
                        if moveTargets.isEmpty {
                            Text("No other checklists")
                        } else {
                            ForEach(moveTargets, id: \.persistentModelID) { checklist in
                                Button(moveTitle(for: checklist)) {
                                    moveItem(to: checklist)
                                }
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteItem()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .opacity(isDragging ? 0.6 : 1)
        .onAppear {
            // Auto-focus newly created blank items.
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { @MainActor in
                    // Nearly immediate focus so the keyboard feels instant for new items.
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    beginEditing()
                }
            }
        }
    }

    private var moveTargets: [Checklist] {
        allChecklists.filter { $0.persistentModelID != item.checklist?.persistentModelID }
    }

    private func moveTitle(for checklist: Checklist) -> String {
        let name = checklist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Move to Checklist" : "Move to \(name)"
    }

    private func moveItem(to checklist: Checklist) {
        guard let currentChecklist = item.checklist else { return }

        let nextOrder = ((checklist.items ?? []).map { $0.sortOrder }.max() ?? -1) + 1
        item.checklist = checklist
        item.sortOrder = nextOrder

        currentChecklist.updatedAt = Date()
        currentChecklist.needsSync = true
        checklist.updatedAt = Date()
        checklist.needsSync = true

        try? modelContext.save()
    }

    private func beginEditing() {
        // Edit mode is separate from focus so nested containers/gestures don't break typing.
        isEditing = true
        focusedField = .text
        DispatchQueue.main.async {
            isEditing = true
            focusedField = .text
        }
    }

    private func toggleComplete() {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isCompleted.toggle()
            item.completedAt = item.isCompleted ? Date() : nil
        }
        persistTouch()
    }

    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func persistTouch() {
        item.checklist?.updatedAt = Date()
        item.checklist?.needsSync = true
        try? modelContext.save()
    }
}

#Preview {
    ChecklistsView()
}

private struct ChecklistItemDropDelegate: DropDelegate {
    let targetItem: ChecklistItem
    @Binding var draggedItem: ChecklistItem?
    @Binding var dragBuffer: [ChecklistItem]
    let reorderAction: (ChecklistItem, ChecklistItem) -> Void
    let commitAction: () -> Void

    func dropEntered(info: DropInfo) {
        // Pure in-memory reorder — no SwiftData writes here.
        guard let draggedItem, draggedItem.persistentModelID != targetItem.persistentModelID else { return }
        reorderAction(draggedItem, targetItem)
    }

    func validateDrop(info: DropInfo) -> Bool {
        true
    }

    func performDrop(info: DropInfo) -> Bool {
        // Flush sortOrder to SwiftData exactly once, when the user lets go.
        commitAction()
        draggedItem = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
