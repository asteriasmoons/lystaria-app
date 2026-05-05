//
//  DocumentsView.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData

// MARK: - Main Documents View

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<DocumentBook> { $0.deletedAt == nil }, sort: \DocumentBook.createdAt, order: .reverse)
    private var books: [DocumentBook]

    @State private var showBookEditor = false
    @State private var editingBook: DocumentBook? = nil
    @State private var selectedBook: DocumentBook? = nil
    @State private var navigateToSelectedBook = false

    private var sortedBooks: [DocumentBook] {
        books.sorted { lhs, rhs in
            let lp = lhs.pinOrder > 0, rp = rhs.pinOrder > 0
            if lp != rp { return lp && !rp }
            if lp && rp, lhs.pinOrder != rhs.pinOrder { return lhs.pinOrder < rhs.pinOrder }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    bookshelf
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton {
                editingBook = nil
                showBookEditor = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 100)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            if showBookEditor {
                DocumentBookEditorSheet(
                    book: editingBook,
                    onClose: {
                        showBookEditor = false
                        editingBook = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookEditor)
        .navigationDestination(isPresented: $navigateToSelectedBook) {
            Group {
                if let selectedBook {
                    DocumentBookDetailView(book: selectedBook)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }
        .onChange(of: navigateToSelectedBook) { _, isPresented in
            if !isPresented {
                selectedBook = nil
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Documents", font: .system(size: 28, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 16)

            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    // MARK: - Bookshelf

    private var bookshelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            if books.isEmpty {
                EmptyState(icon: "doc.text", message: "No document books yet.\nTap + to create your first book.")
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(sortedBooks, id: \.persistentModelID) { book in
                        Button {
                            print("📘 DocumentsView: selected book title=\(book.title), id=\(book.persistentModelID), uuid=\(book.uuid), entriesRelationshipCount=\(book.entries?.count ?? -1)")
                            selectedBook = book
                            navigateToSelectedBook = true
                        } label: {
                            DocumentBookCard(
                                title: book.title,
                                coverHex: book.coverHex,
                                entryCount: entryCount(for: book),
                                lastDate: lastEntryDate(for: book),
                                isPinned: book.pinOrder > 0
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if book.pinOrder > 0 {
                                Button("Unpin Book") { unpinBook(book) }
                            } else {
                                Button("Pin Book") { pinBook(book) }
                            }
                            Button("Edit Book") { editingBook = book; showBookEditor = true }
                            Button(role: .destructive) { deleteBook(book) } label: { Text("Delete Book") }
                        }
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 16)
            }
        }
    }

    private func entryCount(for book: DocumentBook) -> Int {
        (book.entries ?? []).filter { $0.deletedAt == nil }.count
    }

    private func lastEntryDate(for book: DocumentBook) -> Date? {
        (book.entries ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .first?.createdAt
    }

    private func deleteBook(_ book: DocumentBook) {
        for e in (book.entries ?? []) { e.deletedAt = Date() }
        book.deletedAt = Date()
        try? modelContext.save()
    }

    private func pinBook(_ book: DocumentBook) {
        let nextPin = (books.filter { $0.pinOrder > 0 }.map(\.pinOrder).max() ?? 0) + 1
        book.pinOrder = nextPin
        try? modelContext.save()
    }

    private func unpinBook(_ book: DocumentBook) {
        book.pinOrder = 0
        try? modelContext.save()
    }
}

// MARK: - Document Book Card

struct DocumentBookCard: View {
    let title: String
    let coverHex: String
    let entryCount: Int
    let lastDate: Date?
    let isPinned: Bool

    private var coverColor: Color { Color(hex: coverHex) }

    var body: some View {
        bookGraphic
            .frame(height: 230)
            .scaleEffect(0.85)
            .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var bookGraphic: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.28))
                    .blur(radius: 14)
                    .offset(x: 10, y: 12)

                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.18, height: h * 0.88)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<14, id: \.self) { _ in
                                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10).opacity(0.55)
                    )
                    .offset(x: w * 0.34, y: 0)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 8, y: 8)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [coverColor.opacity(0.92), coverColor], startPoint: .topLeading, endPoint: .bottomTrailing))

                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 0.16)
                        .overlay(
                            VStack(spacing: 6) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.10)).frame(height: 3)
                                }
                            }
                            .padding(.vertical, 14).padding(.leading, 10)
                            .frame(maxHeight: .infinity, alignment: .top).opacity(0.7)
                        )

                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .topLeading, endPoint: .center))
                        .blendMode(.screen).opacity(0.75)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(title)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if isPinned {
                                Image("pinfill")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .frame(width: 16, height: 16).foregroundStyle(.white).padding(.top, 2)
                            }
                        }

                        Text("\(entryCount) documents")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.88))

                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 28)
                            .overlay(
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.8))
                                    Text(lastDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "New")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                            )
                    }
                    .padding(.leading, 16).padding(.trailing, 18).padding(.top, 16).padding(.bottom, 12)
                }
                .frame(width: w * 0.86, height: h)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 14, x: 10, y: 12)
                .rotation3DEffect(.degrees(-10), axis: (x: 0, y: 1, z: 0))
                .offset(x: -w * 0.06)
            }
        }
    }
}

// MARK: - Document Book Detail View

struct DocumentBookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let book: DocumentBook

    @State private var entries: [DocumentEntry] = []
    @State private var hasLoadedEntries = false

    @State private var navigateToEditorPage = false
    @State private var navigateToPreviewPage = false
    @State private var editorEntryTarget: DocumentEntry? = nil
    @State private var previewEntryTarget: DocumentEntry? = nil
    @State private var visibleEntryCount: Int = 12

    init(book: DocumentBook) {
        self.book = book
        print("📗 DocumentBookDetailView init: title=\(book.title), id=\(book.persistentModelID), uuid=\(book.uuid), relationshipCount=\(book.entries?.count ?? -1)")
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        Spacer().frame(height: 16)
                        documentGrid
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)

                FloatingActionButton {
                    editorEntryTarget = nil
                    navigateToEditorPage = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            loadEntriesIfNeeded()
        }
        .onChange(of: navigateToEditorPage) { _, isPresented in
            if !isPresented {
                reloadEntries()
            }
        }
        .onChange(of: navigateToPreviewPage) { _, isPresented in
            if !isPresented {
                reloadEntries()
            }
        }
        .navigationDestination(isPresented: $navigateToEditorPage) {
            DocumentBlockEditorPage(book: book, existingEntry: editorEntryTarget)
        }
        .navigationDestination(isPresented: $navigateToPreviewPage) {
            Group {
                if let entry = previewEntryTarget {
                    DocumentBlockPreviewPage(entry: entry)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    GradientTitle(text: book.title, font: .system(size: 20, weight: .bold))
                    Text(entries.count == 1 ? "1 document" : "\(entries.count) documents")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 14)

            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    @ViewBuilder
    private var documentGrid: some View {
        if entries.isEmpty {
            EmptyState(icon: "doc.text", message: "No documents yet.\nTap + to create one.")
                .padding(.top, 20)
                .padding(.horizontal, LSpacing.pageHorizontal)
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(Array(entries.prefix(visibleEntryCount)), id: \.persistentModelID) { entry in
                    DocumentPageCard(entry: entry, bookCoverHex: book.coverHex)
                        .onAppear {
                            print("📃 DocumentPageCard appeared: title=\(entry.title), id=\(entry.persistentModelID), blockPreviewLength=\(entry.blockPreviewText.count), updatedAt=\(entry.updatedAt)")
                        }
                        .onTapGesture {
                            print("📖 Document entry tapped for preview: title=\(entry.title), id=\(entry.persistentModelID), blockPreviewLength=\(entry.blockPreviewText.count)")
                            previewEntryTarget = entry
                            navigateToPreviewPage = true
                        }
                        .contextMenu {
                            Button("Edit") {
                                editorEntryTarget = entry
                                navigateToEditorPage = true
                            }
                            Button(role: .destructive) {
                                entry.deletedAt = Date()
                                entry.updatedAt = Date()
                                try? modelContext.save()
                                reloadEntries()
                            } label: {
                                Text("Delete")
                            }
                        }
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)

            if entries.count > visibleEntryCount {
                LoadMoreButton { visibleEntryCount += 12 }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 4)
            }
        }
    }

    private func loadEntriesIfNeeded() {
        guard !hasLoadedEntries else { return }
        hasLoadedEntries = true
        reloadEntries()
    }

    private func reloadEntries() {
        let targetBookID = book.persistentModelID
        print("📚 DocumentBookDetailView reloadEntries started: title=\(book.title), id=\(targetBookID)")

        var descriptor = FetchDescriptor<DocumentEntry>(
            predicate: #Predicate<DocumentEntry> { entry in
                entry.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500

        do {
            let fetchedEntries = try modelContext.fetch(descriptor)
            print("📚 DocumentBookDetailView fetched undeleted entries count=\(fetchedEntries.count)")

            entries = fetchedEntries.filter { entry in
                entry.book?.persistentModelID == targetBookID
            }

            print("📚 DocumentBookDetailView filtered entries count=\(entries.count) for title=\(book.title)")
        } catch {
            entries = []
            print("❌ DocumentBookDetailView failed to reload entries: \(error.localizedDescription)")
        }
    }
}

// MARK: - Document Page Card

struct DocumentPageCard: View {
    let entry: DocumentEntry
    let bookCoverHex: String

    private var bookColor: Color { Color(hex: bookCoverHex) }

    private let cardCornerRadius: CGFloat = 12
    private let foldSize: CGFloat = 38

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(paperGradient)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bookColor.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.multiply)
                .opacity(0.9)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
                .opacity(0.55)

            VStack(alignment: .leading, spacing: 10) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 24)

                if !entry.blockPreviewText.isEmpty {
                    Text(entry.blockPreviewText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.56))
                        .lineLimit(10)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Blank document")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.32))
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                    Text(entry.updatedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.black.opacity(0.38))
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)

            foldCorner
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.13), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var paperGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bookColor.opacity(0.34), location: 0),
                .init(color: bookColor.opacity(0.24), location: 0.42),
                .init(color: bookColor.opacity(0.16), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var foldCorner: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let f = foldSize

            ZStack(alignment: .topTrailing) {
                Path { path in
                    path.move(to: CGPoint(x: w - f, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: f))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.18))
                .blur(radius: 5)
                .offset(x: -2, y: 4)

                Path { path in
                    path.move(to: CGPoint(x: w - f, y: 0))
                    path.addLine(to: CGPoint(x: w, y: f))
                    path.addLine(to: CGPoint(x: w - f, y: f))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            bookColor.opacity(0.50),
                            bookColor.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 4, x: -2, y: 3)

                Path { path in
                    path.move(to: CGPoint(x: w - f, y: 0))
                    path.addLine(to: CGPoint(x: w, y: f))
                }
                .stroke(Color.black.opacity(0.32), lineWidth: 1.15)

                Path { path in
                    path.move(to: CGPoint(x: w - f + 7, y: 4))
                    path.addLine(to: CGPoint(x: w - 4, y: f - 7))
                }
                .stroke(Color.white.opacity(0.40), lineWidth: 1)
            }
        }
    }
}

// MARK: - Document Book Editor Sheet

struct DocumentBookEditorSheet: View {
    @Environment(\.modelContext) private var modelContext

    let book: DocumentBook?
    var onClose: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var coverColor: Color = Color(hex: "#6A5CFF")

    private var closeAction: () -> Void { onClose ?? {} }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 640,
            heightRatio: 0.78,
            header: {
                HStack {
                    GradientTitle(text: book != nil ? "Edit Book" : "New Book", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaTextField(placeholder: "Book title", text: $title)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("COVER COLOR")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassCard {
                        HStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(coverColor)
                                .frame(width: 48, height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
                            ColorPicker("Choose color", selection: $coverColor, supportsOpacity: false)
                                .foregroundStyle(LColors.textPrimary)
                            Spacer()
                        }
                    }
                }
            },
            footer: {
                Button { saveBook() } label: {
                    Text(book != nil ? "Save Changes" : "Create Book")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(title.docTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: title.docTrimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(title.docTrimmed.isEmpty)
            }
        )
        .onAppear {
            if let book { title = book.title; coverColor = Color(hex: book.coverHex) }
        }
    }

    private func saveBook() {
        let t = title.docTrimmed
        guard !t.isEmpty else { return }
        let hex = coverColor.toHex() ?? "#6A5CFF"
        if let book {
            book.title = t
            book.coverHex = hex
            book.updatedAt = Date()
        } else {
            let newBook = DocumentBook(title: t, coverHex: hex)
            newBook.updatedAt = Date()
            modelContext.insert(newBook)
        }
        try? modelContext.save()
        closeAction()
    }
}

private extension String {
    var docTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
