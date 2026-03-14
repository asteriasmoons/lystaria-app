import SwiftUI
import SwiftData
import Foundation

// MARK: - ChecklistsView (Items Screen)

struct ChecklistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Using your existing container model.
    @Query(sort: \Checklist.createdAt, order: .forward)
    private var checklists: [Checklist]

    @State private var tab: ChecklistTab = .active

    // Pagination
    @State private var visibleCount: Int = 6
    private let pageSize: Int = 6

    // Single default container for now.
    private var activeChecklist: Checklist? { checklists.first }

    private var itemsSorted: [ChecklistItem] {
        guard let c = activeChecklist else { return [] }
        return c.items.sorted { $0.sortOrder < $1.sortOrder }
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 14) {
                    tabs

                    if activeChecklist == nil {
                        GlassCard {
                            EmptyState(
                                icon: "checklist",
                                message: "No checklist yet.\nTap + to add your first item.",
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
                        VStack(spacing: 12) {
                            ForEach(visibleItems, id: \.persistentModelID) { item in
                                ChecklistItemCard(item: item)
                            }

                            if canLoadMore {
                                LoadMoreButton {
                                    visibleCount += pageSize
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    // Extra scroll room so the last card is never clipped by the tab bar / FAB.
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GradientTitle(text: "Checklists", font: .title2.bold())
                Spacer()
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
            return "No active items.\nTap + to add one."
        case .done:
            return "No completed items yet.\nFinish something first."
        case .all:
            return "No items yet.\nTap + to add one."
        }
    }

    // MARK: - Actions

    private func ensureDefaultChecklistIfNeeded() {
        if activeChecklist == nil {
            let c = Checklist(name: "My Checklist", sortOrder: 0)
            modelContext.insert(c)
            try? modelContext.save()
        }
    }

    private func addNewItem() {
        guard let c = activeChecklist else { return }
        let nextOrder = (c.items.map { $0.sortOrder }.max() ?? -1) + 1

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
    @Bindable var item: ChecklistItem

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

                    Button {
                        deleteItem()
                    } label: {
                        Image(systemName: "trash")
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
