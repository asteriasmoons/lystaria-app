//
//  NotesView.swift
//  Lystaria
//
//  Created by Asteria Moon on 4/2/26.
//

import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @State private var selectedFilter: NotesFilter = .all
    @State private var selectedNote: Note?
    @State private var viewingNote: Note?
    @State private var draftContent: String = ""
    @State private var draftColorHex: String = "#F8E58C"
    @State private var draftColor: Color = Color(red: 248 / 255, green: 229 / 255, blue: 140 / 255)
    @State private var showDeleteConfirmation = false

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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GradientTitle(text: "Notes", size: 30)

                Spacer()
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
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(filteredNotes) { note in
                    NoteStickyCard(note: note, stickyColor: color(from: note.colorHex)) {
                        open(note)
                    }
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

            if let note = selectedNote {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Details")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)

                        detailRow(label: "Created", value: longDateTime(note.createdAt))
                        detailRow(label: "Updated", value: longDateTime(note.updatedAt))
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

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(LColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Data

    private var filteredNotes: [Note] {
        switch selectedFilter {
        case .all:
            return notes
        case .pinned:
            return notes.filter(\.isPinned)
        case .favorites:
            return notes.filter(\.isFavorite)
        case .recent:
            return notes.sorted { $0.updatedAt > $1.updatedAt }
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

    private func createNote() {
        let note = Note(
            content: "",
            colorHex: "#F8E58C",
            isPinned: false,
            isFavorite: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        modelContext.insert(note)
        selectedNote = note
        draftContent = ""
        draftColorHex = note.colorHex
        draftColor = color(from: note.colorHex)
    }

    private func open(_ note: Note) {
        viewingNote = note
    }

    private func startEditing(_ note: Note) {
        viewingNote = nil
        selectedNote = note
        draftContent = note.content
        draftColorHex = note.colorHex
        draftColor = color(from: note.colorHex)
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
        draftColorHex = "#F8E58C"
        draftColor = Color(red: 248 / 255, green: 229 / 255, blue: 140 / 255)
        showDeleteConfirmation = false
    }

    private func saveChanges(for note: Note) {
        note.content = draftContent
        note.colorHex = draftColorHex
        note.touch()

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
    let action: () -> Void

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

                        if note.isPinned {
                            stickyBadge(text: "PINNED")
                        } else if note.isFavorite {
                            stickyBadge(text: "FAVORITE")
                        }
                    }

                    Text(previewText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineSpacing(2)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    Text(shortDateTime(note.updatedAt))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var previewText: String {
        let cleaned = note.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Empty note" : cleaned
    }

    private func stickyBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
