//
//  WatchChecklistView.swift
//  Lystaria
//

import SwiftUI
import SwiftData

// =======================================================
// MARK: - MAIN CHECKLISTS VIEW
// =======================================================

struct WatchChecklistsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Checklist.sortOrder, order: .forward)
    private var checklists: [Checklist]

    @State private var selectedID: PersistentIdentifier?

    private var activeChecklist: Checklist? {
        if let selectedID,
           let match = checklists.first(where: { $0.persistentModelID == selectedID }) {
            return match
        }
        return checklists.first
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            if checklists.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("No checklists yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Create one in the app")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        // Checklist picker if multiple
                        if checklists.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(checklists, id: \.persistentModelID) { list in
                                        let isSelected = activeChecklist?.persistentModelID == list.persistentModelID
                                        Button {
                                            selectedID = list.persistentModelID
                                        } label: {
                                            Text(list.name.isEmpty ? "List" : list.name)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                                                )
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(isSelected ? 0.3 : 0.15), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // Items
                        if let checklist = activeChecklist {
                            WatchChecklistItemsView(checklist: checklist)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Checklists")
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if selectedID == nil {
                selectedID = checklists.first?.persistentModelID
            }
        }
    }
}

// =======================================================
// MARK: - CHECKLIST ITEMS VIEW
// =======================================================

struct WatchChecklistItemsView: View {
    @Environment(\.modelContext) private var modelContext
    let checklist: Checklist

    private var items: [ChecklistItem] {
        (checklist.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeItems: [ChecklistItem] {
        items.filter { !$0.isCompleted }
    }

    private var doneItems: [ChecklistItem] {
        items.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Active items
            if activeItems.isEmpty && doneItems.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.12))
                    Text("No items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 14)
                }
            } else {
                ForEach(activeItems, id: \.persistentModelID) { item in
                    WatchChecklistItemRow(item: item)
                }

                // Done section
                if !doneItems.isEmpty {
                    HStack {
                        Text("DONE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.top, 4)

                    ForEach(doneItems, id: \.persistentModelID) { item in
                        WatchChecklistItemRow(item: item)
                    }
                }
            }
        }
    }

}

// =======================================================
// MARK: - ITEM ROW
// =======================================================

struct WatchChecklistItemRow: View {
    @Environment(\.modelContext) private var modelContext
    let item: ChecklistItem

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                item.isCompleted.toggle()
                item.completedAt = item.isCompleted ? Date() : nil
                item.updatedAt = Date()
                item.needsSync = true
                item.checklist?.updatedAt = Date()
                item.checklist?.needsSync = true
            }
            try? modelContext.save()
        } label: {
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(item.isCompleted
                              ? LinearGradient(
                                  colors: [
                                      Color(red: 125/255, green: 25/255,  blue: 247/255),
                                      Color(red: 3/255,   green: 219/255, blue: 252/255)
                                  ],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing
                                )
                              : LinearGradient(
                                  colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white.opacity(item.isCompleted ? 0 : 0.25), lineWidth: 1.5)
                        )

                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(item.text.isEmpty ? "Item" : item.text)
                    .font(.system(size: 12, weight: item.isCompleted ? .regular : .semibold))
                    .foregroundStyle(item.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(item.isCompleted, color: .white.opacity(0.4))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(item.isCompleted ? 0.06 : 0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
