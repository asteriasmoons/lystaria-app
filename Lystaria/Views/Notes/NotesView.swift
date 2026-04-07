//
//  NotesView.swift
//  Lystaria
//
//  Created by Asteria Moon on 4/2/26.
//

import SwiftUI
import SwiftData
import Foundation

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @Query(sort: \NotesTab.createdAt, order: .forward)
    private var tabs: [NotesTab]

    @State private var selectedFilter: NotesFilter = .all
    @State private var selectedNote: Note?
    @State private var viewingNote: Note?
    @State private var draftContent: String = ""
    @State private var draftLabel1: String = ""
    @State private var draftLabel2: String = ""
    @State private var draftColorHex: String = "#F8E58C"
    @State private var draftColor: Color = Color(red: 248 / 255, green: 229 / 255, blue: 140 / 255)
    @State private var draftDate: Date = Date()
    @State private var isCreatingNote: Bool = false
    @State private var showDeleteConfirmation = false
    @State private var visibleCount: Int = 6
    
    @State private var selectedTab: String = ""
    @State private var newTabName: String = ""
    @State private var renamingTabName: String = ""
    @State private var renamedTabName: String = ""
    @State private var showDeleteTabConfirmation: Bool = false
    @State private var tabPendingDeletion: String = ""
    @State private var showingTabPopup: Bool = false
    @State private var tabPopupMode: TabPopupMode = .create
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTabFieldFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LystariaBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    filterSection
                    tabsSection
                    notesSection
                }
                .padding(.top, 16)
                .padding(.bottom, 110)
            }

            FloatingActionButton {
                createNote()
            }
            .padding(.trailing, LSpacing.pageHorizontal)
            .padding(.bottom, 24)
        }
        .overlay {
            if showingTabPopup {
                LystariaOverlayPopup(
                    onClose: {
                        showingTabPopup = false
                        newTabName = ""
                        renamedTabName = ""
                        renamingTabName = ""
                    },
                    width: 520,
                    heightRatio: 0.70
                ) {
                    HStack {
                        GradientTitle(
                            text: tabPopupMode == .create ? "New Tab" : "Rename Tab",
                            size: 26
                        )
                        Spacer()
                    }
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tab Name")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                GlassTextField(
                                    placeholder: "Enter name",
                                    text: tabPopupMode == .create ? $newTabName : $renamedTabName
                                )
                                .focused($isTabFieldFocused)
                            }
                        }
                    }
                } footer: {
                    HStack(spacing: 10) {
                        Spacer()
                        LButton(title: "Cancel", style: .secondary) {
                            showingTabPopup = false
                            newTabName = ""
                            renamedTabName = ""
                            renamingTabName = ""
                        }
                        LButton(title: "Save", style: .gradient) {
                            if tabPopupMode == .create {
                                createTab()
                            } else {
                                renameTab()
                            }
                            showingTabPopup = false
                        }
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
            if showDeleteTabConfirmation {
                LystariaOverlayPopup(
                    onClose: {
                        showDeleteTabConfirmation = false
                        tabPendingDeletion = ""
                    },
                    width: 520,
                    heightRatio: 0.70
                ) {
                    HStack {
                        GradientTitle(text: "Delete Tab", size: 26)
                        Spacer()
                    }
                } content: {
                    Text("Notes in this tab will be moved to All Notes.")
                        .font(.system(size: 14))
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } footer: {
                    HStack(spacing: 10) {
                        Spacer()
                        LButton(title: "Cancel", style: .secondary) {
                            showDeleteTabConfirmation = false
                        }
                        LButton(title: "Delete", style: .gradient) {
                            deleteTab()
                            showDeleteTabConfirmation = false
                        }
                    }
                }
            }
            if let note = selectedNote {
                LystariaOverlayPopup(
                    onClose: closeEditor,
                    width: 720,
                    heightRatio: 0.70
                ) {
                    popupHeader(for: note)
                } content: {
                    popupContent
                } footer: {
                    popupFooter(for: note)
                }
                .modifier(
                    LystariaConfirmDialog(
                        isPresented: $showDeleteConfirmation,
                        title: "Delete Note?",
                        message: "This note will be permanently removed.",
                        confirmTitle: "Delete",
                        confirmRole: .destructive
                    ) {
                        delete(note)
                    }
                )
            } else if let note = viewingNote {
                LystariaOverlayPopup(
                    onClose: closeViewer,
                    width: 720,
                    heightRatio: 0.70
                ) {
                    viewerHeader(for: note)
                } content: {
                    viewerContent(for: note)
                } footer: {
                    viewerFooter(for: note)
                }
                .modifier(
                    LystariaConfirmDialog(
                        isPresented: $showDeleteConfirmation,
                        title: "Delete Note?",
                        message: "This note will be permanently removed.",
                        confirmTitle: "Delete",
                        confirmRole: .destructive
                    ) {
                        delete(note)
                    }
                )
            }
        }
        .onAppear {
            ensureRootTabExists()
            if selectedTab.isEmpty {
                selectedTab = rootTabName
            }
        }
        .onChange(of: tabs) { _, _ in
            // If the selected tab was deleted or renamed, fall back to root
            if !notesTabs.contains(selectedTab) {
                selectedTab = rootTabName
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isEditorFocused = false
                    isTabFieldFocused = false
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GradientTitle(text: "Notes", size: 30)

                Spacer()

                Button {
                    newTabName = ""
                    tabPopupMode = .create
                    showingTabPopup = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("wavyplus")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)

            Text("Quick thoughts, fragments, and things you want to keep nearby.")
                .font(.subheadline)
                .foregroundStyle(LColors.textSecondary)
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    // MARK: - Filters

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NotesFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedFilter == filter {
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                            .fill(AnyShapeStyle(LGradients.blue))
                                    } else {
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                            .fill(LColors.glassSurface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                                    .stroke(LColors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }
    
    // MARK: - Tabs Section
    
    private var tabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(notesTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        visibleCount = 6
                    } label: {
                        Text(tab)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .fill(Color.white.opacity(selectedTab == tab ? 0.22 : 0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                            .stroke(Color.white.opacity(selectedTab == tab ? 0.24 : 0.16), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename") {
                            renamingTabName = tab
                            renamedTabName = tab
                            tabPopupMode = .rename
                            showingTabPopup = true
                        }

                        if tab != (notesTabs.first ?? "All Notes") {
                            Button("Delete", role: .destructive) {
                                tabPendingDeletion = tab
                                showDeleteTabConfirmation = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        if filteredNotes.isEmpty {
            GlassCard {
                VStack(spacing: 14) {
                    Image("editnote")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    Text(emptyMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                        .multilineTextAlignment(.center)

                    LButton(title: "Create Note", style: .gradient) {
                        createNote()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(visibleNotes) { note in
                        NoteStickyCard(
                            note: note,
                            stickyColor: color(from: note.colorHex),
                            availableTabs: notesTabs,
                            action: {
                                open(note)
                            },
                            onMoveToTab: { tab in
                                move(note, to: tab)
                            }
                        )
                    }
                }

                if filteredNotes.count > visibleCount {
                    HStack {
                        Spacer()
                        LoadMoreButton {
                            visibleCount += 6
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }

    // MARK: - Popup

    private func popupHeader(for note: Note) -> some View {
        HStack(alignment: .center, spacing: 12) {
            GradientTitle(text: "Note", size: 28)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    togglePinned(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("pinfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(note.isPinned ? .white : LColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    toggleFavorite(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("starfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(note.isFavorite ? .white : LColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewerHeader(for note: Note) -> some View {
        HStack(alignment: .center, spacing: 12) {
            GradientTitle(text: "Note", size: 28)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    togglePinned(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("pinfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(note.isPinned ? .white : LColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    toggleFavorite(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("starfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(note.isFavorite ? .white : LColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewerContent(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Content")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)

                    Text(note.trimmedContent.isEmpty ? "Empty note" : note.content)
                        .font(.system(size: 15))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 240, alignment: .topLeading)
                }
            }
        }
    }

    private func viewerFooter(for note: Note) -> some View {
        HStack(spacing: 10) {
            LButton(title: "Delete", style: .gradient) {
                showDeleteConfirmation = true
            }

            Spacer()

            LButton(title: "Close", style: .secondary) {
                closeViewer()
            }

            LButton(title: "Edit", style: .gradient) {
                startEditing(note)
            }
        }
    }

    private var popupContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Content")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)

                    GlassTextEditor(
                        placeholder: "Write anything...",
                        text: $draftContent,
                        minHeight: 240
                    )
                    .focused($isEditorFocused)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sticky Note Color")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)

                        HStack(spacing: 12) {
                            ColorPicker("", selection: $draftColor, supportsOpacity: false)
                                .labelsHidden()
                                .onChange(of: draftColor) { _, newColor in
                                    draftColorHex = hexString(from: newColor)
                                }

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(draftColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )

                            Text(draftColorHex)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }
                }
            }
            
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Label 1")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)

                        GlassTextField(
                            placeholder: "Add a label",
                            text: $draftLabel1
                        )
                    }

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Label 2")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)

                        GlassTextField(
                            placeholder: "Add a label",
                            text: $draftLabel2
                        )
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("DATE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                        DatePicker("", selection: $draftDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.white)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Text("TIME")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                        DatePicker("", selection: $draftDate, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.white)
                        Spacer()
                    }
                }
            }
        }
    }

    private func popupFooter(for note: Note) -> some View {
        HStack(spacing: 10) {
            LButton(title: "Delete", style: .gradient) {
                showDeleteConfirmation = true
            }

            Spacer()

            LButton(title: "Close", style: .secondary) {
                closeEditor()
            }

            LButton(title: "Save", style: .gradient) {
                saveChanges(for: note)
            }
        }
    }


    // MARK: - Data

    private var visibleNotes: [Note] {
        Array(filteredNotes.prefix(visibleCount))
    }

    private var filteredNotes: [Note] {
        let root = rootTabName

        let tabbedNotes = notes.filter { note in
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = noteTab.isEmpty ? root : noteTab
            return resolved == (selectedTab.isEmpty ? root : selectedTab)
        }

        switch selectedFilter {
        case .all:
            return tabbedNotes.sorted { $0.isPinned && !$1.isPinned }
        case .pinned:
            return tabbedNotes.filter(\.isPinned)
        case .favorites:
            return tabbedNotes.filter(\.isFavorite).sorted { $0.isPinned && !$1.isPinned }
        case .recent:
            return tabbedNotes.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all:
            return "Your notes will appear here."
        case .pinned:
            return "Pinned notes will appear here."
        case .favorites:
            return "Favorite notes will appear here."
        case .recent:
            return "Recent notes will appear here."
        }
    }
    
    /// The canonical name of the root/default tab.
    private var rootTabName: String {
        tabs.first(where: { $0.isRootTab })?.trimmedName
            ?? tabs.first?.trimmedName
            ?? "All Notes"
    }

    private var notesTabs: [String] {
        // Root tab always first; remaining stored tabs in creation order.
        var merged: [String] = []

        // 1. Root tab
        let root = rootTabName
        merged.append(root)

        // 2. Other stored tabs (non-root, non-empty, not already added)
        for tab in tabs {
            let name = tab.trimmedName
            guard !name.isEmpty, !merged.contains(name) else { continue }
            merged.append(name)
        }

        // 3. Any tab names referenced by notes that aren't in stored tabs yet
        //    (handles legacy data or migration edge cases)
        for note in notes {
            let name = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = name.isEmpty ? root : name
            if !merged.contains(resolved) {
                merged.append(resolved)
            }
        }

        return merged
    }

    private func tabModel(named name: String) -> NotesTab? {
        tabs.first { $0.trimmedName == name }
    }

    private func ensureRootTabExists() {
        guard tabs.first(where: { $0.isRootTab }) == nil else { return }
        let existingFirst = tabs.first
        if let existingFirst {
            existingFirst.isRootTab = true
        } else {
            let root = NotesTab(name: "All Notes", isRootTab: true)
            modelContext.insert(root)
        }
        try? modelContext.save()
    }
    
    private func createTab() {
        ensureRootTabExists()
        let trimmed = newTabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !notesTabs.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newTabName = ""
            return
        }

        let tab = NotesTab(name: trimmed, isRootTab: false)
        modelContext.insert(tab)

        do {
            try modelContext.save()
        } catch {
            print("Failed to create tab: \(error)")
        }

        selectedTab = trimmed
        visibleCount = 6
        newTabName = ""
    }

    private func renameTab() {
        ensureRootTabExists()
        let trimmed = renamedTabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !renamingTabName.isEmpty, !trimmed.isEmpty else { return }
        guard !notesTabs.contains(where: {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame &&
            $0.caseInsensitiveCompare(renamingTabName) != .orderedSame
        }) else {
            renamedTabName = ""
            renamingTabName = ""
            return
        }

        let isRenamingRoot = renamingTabName == rootTabName

        if let tab = tabModel(named: renamingTabName) {
            // Update the existing stored tab
            tab.name = trimmed
            tab.touch()
        } else if isRenamingRoot {
            // Root tab exists in memory but not yet persisted — create and mark as root
            let tab = NotesTab(name: trimmed, isRootTab: true)
            modelContext.insert(tab)
        }

        // Reassign notes: match exact name OR empty string if renaming root
        for note in notes {
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesOld = noteTab == renamingTabName
            let matchesEmpty = isRenamingRoot && noteTab.isEmpty
            if matchesOld || matchesEmpty {
                note.tabName = trimmed
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to rename tab: \(error)")
        }

        if selectedTab == renamingTabName {
            selectedTab = trimmed
        }

        renamedTabName = ""
        renamingTabName = ""
    }

    private func deleteTab() {
        let rootTabName = self.rootTabName
        guard !tabPendingDeletion.isEmpty, tabPendingDeletion != rootTabName else { return }

        if let tab = tabModel(named: tabPendingDeletion) {
            modelContext.delete(tab)
        }

        for note in notes where note.tabName == tabPendingDeletion {
            note.tabName = rootTabName
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete tab: \(error)")
        }

        if selectedTab == tabPendingDeletion {
            selectedTab = rootTabName
        }

        tabPendingDeletion = ""
        visibleCount = 6
    }

    private func move(_ note: Note, to tab: String) {
        note.tabName = tab
        note.touch()

        do {
            try modelContext.save()
        } catch {
            print("Failed to move note: \(error)")
        }
    }

    private func createNote() {
        let note = Note(
            content: "",
            colorHex: "#F8E58C",
            label: "",
            label2: "",
            tabName: selectedTab.isEmpty ? (notesTabs.first ?? "All Notes") : selectedTab,
            isPinned: false,
            isFavorite: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        modelContext.insert(note)
        selectedNote = note
        draftContent = ""
        draftLabel1 = note.label
        draftLabel2 = note.label2
        draftColorHex = note.colorHex
        draftColor = color(from: note.colorHex)
        draftDate = note.createdAt
        isCreatingNote = true
    }

    private func open(_ note: Note) {
        viewingNote = note
    }

    private func startEditing(_ note: Note) {
        viewingNote = nil
        selectedNote = note
        draftContent = note.content
        draftLabel1 = note.label
        draftLabel2 = note.label2
        draftColorHex = note.colorHex
        draftColor = color(from: note.colorHex)
        draftDate = note.updatedAt
        isCreatingNote = false
        showDeleteConfirmation = false
    }

    private func closeViewer() {
        viewingNote = nil
        showDeleteConfirmation = false
    }

    private func closeEditor() {
        selectedNote = nil
        viewingNote = nil
        draftContent = ""
        draftLabel1 = ""
        draftLabel2 = ""
        draftColorHex = "#F8E58C"
        draftColor = Color(red: 248 / 255, green: 229 / 255, blue: 140 / 255)
        draftDate = Date()
        isCreatingNote = false
        showDeleteConfirmation = false
    }

    private func saveChanges(for note: Note) {
        note.content = draftContent
        note.label = draftLabel1.trimmingCharacters(in: .whitespacesAndNewlines)
        note.label2 = draftLabel2.trimmingCharacters(in: .whitespacesAndNewlines)
        note.colorHex = draftColorHex

        if isCreatingNote {
            note.createdAt = draftDate
            note.updatedAt = draftDate
        } else {
            note.updatedAt = draftDate
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save note: \(error)")
        }

        closeEditor()
    }
    private func color(from hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            return Color(red: 248 / 255, green: 229 / 255, blue: 140 / 255)
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        return Color(red: red, green: green, blue: blue)
    }

    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#F8E58C"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }

    private func togglePinned(_ note: Note) {
        note.isPinned.toggle()
        note.touch()

        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }

    private func toggleFavorite(_ note: Note) {
        note.isFavorite.toggle()
        note.touch()

        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }

    private func delete(_ note: Note) {
        selectedNote = nil
        viewingNote = nil
        visibleCount = max(6, visibleCount - 1)
        modelContext.delete(note)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete note: \(error)")
        }

        closeEditor()
    }

    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func longDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Sticky Note Card

private struct NoteStickyCard: View {
    let note: Note
    let stickyColor: Color
    let availableTabs: [String]
    let action: () -> Void
    let onMoveToTab: (String) -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(stickyColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 8) {
                            if note.isPinned {
                                Image("pinfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                            }

                            if note.isFavorite {
                                Image("starfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 5) {
                            if note.isPinned {
                                stickyBadge(text: "PINNED")
                            }

                            if note.isFavorite {
                                stickyBadge(text: "FAVORITE")
                            }

                            ForEach(note.activeLabels, id: \.self) { lbl in
                                stickyBadge(text: lbl.uppercased())
                            }
                        }
                    }

                    Text(previewText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineSpacing(2)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created: \(shortDateTime(note.createdAt))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))

                        Text("Updated: \(shortDateTime(note.updatedAt))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu("Move to Tab") {
                ForEach(availableTabs, id: \.self) { tab in
                    Button(tab) {
                        onMoveToTab(tab)
                    }
                }
            }
        }
    }

    private var previewText: String {
        let cleaned = note.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Empty note" : cleaned
    }

    private func stickyBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .fixedSize()
    }

    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Filter Enum

private enum NotesFilter: String, CaseIterable, Identifiable {
    case all
    case pinned
    case favorites
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        }
    }
}


#Preview {
    NotesView()
}

// MARK: - Tab Popup Mode

private enum TabPopupMode {
    case create
    case rename
}
