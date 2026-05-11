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
    @State private var searchText = ""
    @State private var previewEntryTarget: DocumentEntry? = nil
    @State private var navigateToPreviewPage = false

    private var sortedBooks: [DocumentBook] {
        books.sorted { lhs, rhs in
            let lp = lhs.pinOrder > 0, rp = rhs.pinOrder > 0
            if lp != rp { return lp && !rp }
            if lp && rp, lhs.pinOrder != rhs.pinOrder { return lhs.pinOrder < rhs.pinOrder }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var filteredBooks: [DocumentBook] {
        guard isSearching else { return sortedBooks }

        let query = trimmedSearchText.lowercased()

        return sortedBooks.filter { book in
            book.title.lowercased().contains(query)
        }
    }

    private var matchingDocuments: [(book: DocumentBook, entry: DocumentEntry)] {
        guard isSearching else { return [] }

        let query = trimmedSearchText.lowercased()

        return sortedBooks.flatMap { book in
            (book.entries ?? [])
                .filter { entry in
                    entry.deletedAt == nil &&
                    (
                        entry.title.lowercased().contains(query) ||
                        entry.blockPreviewText.lowercased().contains(query)
                    )
                }
                .map { entry in
                    (book: book, entry: entry)
                }
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    DocumentSearchBar(text: $searchText, placeholder: "Search books and documents")
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.top, 14)

                    if isSearching {
                        matchingDocumentsSection
                    }

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
        .navigationDestination(isPresented: $navigateToPreviewPage) {
            Group {
                if let entry = previewEntryTarget {
                    DocumentBlockPreviewPage(entry: entry)
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
        .onChange(of: navigateToPreviewPage) { _, isPresented in
            if !isPresented {
                previewEntryTarget = nil
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

    // MARK: - Matching Documents Section

    private var matchingDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !matchingDocuments.isEmpty {
                Text("Matching Documents")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.5)
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    ForEach(Array(matchingDocuments.prefix(6)), id: \.entry.persistentModelID) { match in
                        Button {
                            previewEntryTarget = match.entry
                            navigateToPreviewPage = true
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: match.book.coverHex).opacity(0.85))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(match.entry.title.isEmpty ? "Untitled" : match.entry.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(LColors.textPrimary)
                                        .lineLimit(1)

                                    Text(match.book.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Bookshelf

    private var bookshelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            if books.isEmpty {
                EmptyState(icon: "doc.text", message: "No document books yet.\nTap + to create your first book.")
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)
            } else if filteredBooks.isEmpty {
                EmptyState(icon: "magnifyingglass", message: "No matching books found.")
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(filteredBooks, id: \.persistentModelID) { book in
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
    @State private var allBooks: [DocumentBook] = []
    @State private var folders: [DocumentFolder] = []
    let book: DocumentBook

    @State private var entries: [DocumentEntry] = []
    @State private var hasLoadedEntries = false

    @State private var navigateToEditorPage = false
    @State private var navigateToPreviewPage = false
    @State private var editorEntryTarget: DocumentEntry? = nil
    @State private var previewEntryTarget: DocumentEntry? = nil
    @State private var visibleEntryCount: Int = 12
    @State private var searchText = ""
    @State private var selectedFolder: DocumentFolder? = nil
    @State private var navigateToSelectedFolder = false
    @State private var showFolderEditor = false
    @State private var editingFolder: DocumentFolder? = nil

    init(book: DocumentBook) {
        self.book = book
        print("📗 DocumentBookDetailView init: title=\(book.title), id=\(book.persistentModelID), uuid=\(book.uuid), relationshipCount=\(book.entries?.count ?? -1)")
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var visibleEntries: [DocumentEntry] {
        entries.filter { entry in
            entry.folder == nil
        }
    }

    private var filteredEntries: [DocumentEntry] {
        guard isSearching else { return visibleEntries }

        let query = trimmedSearchText.lowercased()

        return visibleEntries.filter { entry in
            entry.title.lowercased().contains(query) ||
            entry.blockPreviewText.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        DocumentSearchBar(text: $searchText, placeholder: "Search this book")
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.top, 14)
                        Spacer().frame(height: 16)

                        foldersSection
                            .padding(.bottom, folders.isEmpty ? 0 : 18)

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
        .navigationDestination(isPresented: $navigateToSelectedFolder) {
            Group {
                if let selectedFolder {
                    DocumentFolderView(book: book, folder: selectedFolder)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }
        .onChange(of: navigateToSelectedFolder) { _, isPresented in
            if !isPresented {
                selectedFolder = nil
                reloadFolders()
                reloadEntries()
            }
        }
        .overlay {
            if showFolderEditor {
                DocumentFolderEditorSheet(
                    book: book,
                    folder: editingFolder,
                    onClose: {
                        showFolderEditor = false
                        editingFolder = nil
                    },
                    onSave: {
                        reloadFolders()
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showFolderEditor)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    GradientTitle(text: book.title, font: .system(size: 20, weight: .bold))
                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }

                Spacer()

                Button {
                    editingFolder = nil
                    showFolderEditor = true
                } label: {
                    Image("wavyplus")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.vertical, 14)

            Rectangle().fill(LColors.glassBorder).frame(height: 1)
        }
    }

    private var headerSubtitle: String {
        let folderText = folders.count == 1 ? "1 folder" : "\(folders.count) folders"
        let documentText = visibleEntries.count == 1 ? "1 unfiled document" : "\(visibleEntries.count) unfiled documents"
        return "\(folderText) • \(documentText)"
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !folders.isEmpty {
                HStack {
                    Text("Folders")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    Spacer()
                }
                .padding(.horizontal, LSpacing.pageHorizontal)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(folders, id: \.persistentModelID) { folder in
                        Button {
                            selectedFolder = folder
                            searchText = ""
                            visibleEntryCount = 12
                            navigateToSelectedFolder = true
                        } label: {
                            DocumentFolderCard(
                                folder: folder,
                                bookCoverHex: book.coverHex,
                                documentCount: folderDocumentCount(folder)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit Folder") {
                                editingFolder = folder
                                showFolderEditor = true
                            }

                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Text("Delete Folder")
                            }
                        }
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
            }
        }
    }

    @ViewBuilder
    private var documentGrid: some View {
        if entries.isEmpty && folders.isEmpty {
            EmptyState(icon: "doc.text", message: "No documents or folders yet.\nTap the folder + to create a folder or the bottom + to create a document.")
                .padding(.top, 20)
                .padding(.horizontal, LSpacing.pageHorizontal)
        } else if filteredEntries.isEmpty {
            EmptyState(
                icon: isSearching ? "magnifyingglass" : "doc.text",
                message: isSearching ? "No matching documents found." : "No unfiled documents yet."
            )
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(Array(filteredEntries.prefix(visibleEntryCount)), id: \.persistentModelID) { entry in
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

                            Menu("Move To Book") {
                                ForEach(allBooks.filter { $0.persistentModelID != book.persistentModelID }, id: \.persistentModelID) { targetBook in
                                    Button {
                                        moveEntry(entry, to: targetBook)
                                    } label: {
                                        HStack {
                                            Text(targetBook.title)

                                            if targetBook.pinOrder > 0 {
                                                Image("pinfill")
                                            }
                                        }
                                    }
                                }
                            }

                            if !folders.isEmpty {
                                Menu("Move To Folder") {
                                    if entry.folder != nil {
                                        Button("Remove From Folder") {
                                            moveEntryToRoot(entry)
                                        }
                                    }

                                    ForEach(folders, id: \.persistentModelID) { folder in
                                        Button {
                                            moveEntry(entry, to: folder)
                                        } label: {
                                            Label(folder.title, systemImage: "folder.fill")
                                        }
                                    }
                                }
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

            if filteredEntries.count > visibleEntryCount {
                LoadMoreButton { visibleEntryCount += 12 }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 4)
            }
        }
    }

    private func moveEntry(_ entry: DocumentEntry, to targetBook: DocumentBook) {
        entry.book = targetBook
        entry.folder = nil
        entry.updatedAt = Date()

        try? modelContext.save()

        reloadEntries()
        reloadFolders()
    }

    private func moveEntry(_ entry: DocumentEntry, to folder: DocumentFolder) {
        entry.book = book
        entry.folder = folder
        entry.updatedAt = Date()

        try? modelContext.save()

        reloadEntries()
        reloadFolders()
    }

    private func moveEntryToRoot(_ entry: DocumentEntry) {
        entry.folder = nil
        entry.updatedAt = Date()

        try? modelContext.save()

        reloadEntries()
        reloadFolders()
    }

    private func loadEntriesIfNeeded() {
        guard !hasLoadedEntries else { return }

        hasLoadedEntries = true

        loadBooks()
        reloadFolders()
        reloadEntries()
    }

    private func loadBooks() {
        var descriptor = FetchDescriptor<DocumentBook>(
            predicate: #Predicate<DocumentBook> { book in
                book.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        descriptor.fetchLimit = 200

        do {
            allBooks = try modelContext.fetch(descriptor)
        } catch {
            allBooks = []
            print("❌ Failed to load books: \(error.localizedDescription)")
        }
    }

    private func reloadFolders() {
        let targetBookID = book.persistentModelID

        var descriptor = FetchDescriptor<DocumentFolder>(
            predicate: #Predicate<DocumentFolder> { folder in
                folder.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200

        do {
            let fetchedFolders = try modelContext.fetch(descriptor)
            folders = fetchedFolders.filter { folder in
                folder.book?.persistentModelID == targetBookID
            }
        } catch {
            folders = []
            print("❌ Failed to load document folders: \(error.localizedDescription)")
        }
    }

    private func folderDocumentCount(_ folder: DocumentFolder) -> Int {
        entries.filter { entry in
            entry.deletedAt == nil &&
            entry.folder?.persistentModelID == folder.persistentModelID
        }.count
    }

    private func deleteFolder(_ folder: DocumentFolder) {
        for entry in entries where entry.folder?.persistentModelID == folder.persistentModelID {
            entry.folder = nil
            entry.updatedAt = Date()
        }

        folder.deletedAt = Date()
        folder.updatedAt = Date()

        try? modelContext.save()
        selectedFolder = nil
        reloadFolders()
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
            visibleEntryCount = 12
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
                        colors: [bookColor.opacity(0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.multiply)
                .opacity(0.45)

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
                    .foregroundStyle(Color.white.opacity(0.94))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 24)

                Group {
                    if !entry.blockPreviewText.isEmpty {
                        previewContent
                    } else {
                        Text("Blank document")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 104, alignment: .topLeading)
                .clipped()

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                    Text(entry.updatedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.58))
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

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(previewBlocks.prefix(6), id: \.persistentModelID) { block in
                switch block.type {
                case .checklist:
                    previewChecklistRow(
                        text: block.text,
                        state: previewChecklistState(for: block)
                    )

                default:
                    Text(block.text)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewBlocks: [DocumentBlock] {
        Array(
            entry.sortedBlocks
                .filter {
                    !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                .prefix(6)
        )
    }

    private func previewChecklistState(for block: DocumentBlock) -> PreviewChecklistState {
        switch block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "checked":
            return .checked
        case "xmark":
            return .xmark
        default:
            return .unchecked
        }
    }

    private enum PreviewChecklistState {
        case unchecked
        case checked
        case xmark
    }

    private func previewChecklistRow(text: String, state: PreviewChecklistState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            previewChecklistIcon(state: state)

            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(state == .unchecked ? 0.70 : 0.45))
                .strikethrough(state != .unchecked)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func previewChecklistIcon(state: PreviewChecklistState) -> some View {
        switch state {
        case .unchecked:
            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 1.2)
                .frame(width: 11, height: 11)

        case .checked:
            ZStack {
                Circle()
                    .fill(LGradients.blue)
                    .frame(width: 11, height: 11)

                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(.white)
            }

        case .xmark:
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 11, height: 11)
                    .overlay(
                        Circle()
                            .stroke(bookColor.opacity(0.9), lineWidth: 1)
                    )

                Image(systemName: "xmark")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.82))
            }
        }
    }

    private var paperGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bookColor.opacity(0.70), location: 0),
                .init(color: bookColor.opacity(0.56), location: 0.42),
                .init(color: bookColor.opacity(0.44), location: 1)
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

// MARK: - Document Search Bar

private struct DocumentSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private extension String {
    var docTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Document Folder Card

struct DocumentFolderCard: View {
    let folder: DocumentFolder
    let bookCoverHex: String
    let documentCount: Int

    private var bookColor: Color { Color(hex: bookCoverHex) }
    private var iconItem: BookmarkIconItem { DocumentFolderIconHelpers.item(from: folder.iconName) }

    var body: some View {
        VStack(spacing: 12) {
            folderGraphic
                .frame(height: 124)

            VStack(spacing: 3) {
                Text(folder.title.isEmpty ? "Untitled Folder" : folder.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)

                Text(documentCount == 1 ? "1 document" : "\(documentCount) documents")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    private var folderGraphic: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let tabW: CGFloat = w * 0.44
            let tabH: CGFloat = h * 0.155
            let bodyY: CGFloat = tabH * 0.75
            let bodyH: CGFloat = h - bodyY
            let cornerR: CGFloat = 14

            let backShape = Path { p in
                p.move(to: CGPoint(x: cornerR, y: h))
                p.addQuadCurve(to: CGPoint(x: 0, y: h - cornerR), control: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: cornerR))
                p.addQuadCurve(to: CGPoint(x: cornerR, y: 0), control: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: w - cornerR, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: cornerR), control: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: h - cornerR))
                p.addQuadCurve(to: CGPoint(x: w - cornerR, y: h), control: CGPoint(x: w, y: h))
                p.closeSubpath()
            }

            // Front panel shape — flat top, rounded bottom
            let frontY: CGFloat = bodyY + tabH * 1.1
            let frontH: CGFloat = h - frontY
            let frontShape = Path { p in
                p.move(to: CGPoint(x: 0, y: frontY))
                p.addLine(to: CGPoint(x: w, y: frontY))
                p.addLine(to: CGPoint(x: w, y: h - cornerR))
                p.addQuadCurve(to: CGPoint(x: w - cornerR, y: h), control: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: cornerR, y: h))
                p.addQuadCurve(to: CGPoint(x: 0, y: h - cornerR), control: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }

            ZStack {
                // Drop shadow
                backShape
                    .fill(Color.black.opacity(0.28))
                    .blur(radius: 12)
                    .offset(x: 5, y: 10)

                // Back panel — slightly darker/deeper
                backShape
                    .fill(LinearGradient(
                        colors: [bookColor.darker(by: 0.14), bookColor.darker(by: 0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                // Back panel inner highlight
                backShape
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    ))

                // Seam line where front panel meets back
                Path { p in
                    p.move(to: CGPoint(x: 0, y: frontY))
                    p.addLine(to: CGPoint(x: w, y: frontY))
                }
                .stroke(Color.black.opacity(0.20), lineWidth: 1)

                // Front panel
                frontShape
                    .fill(LinearGradient(
                        colors: [bookColor.lighter(by: 0.14), bookColor.darker(by: 0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                // Front panel sheen
                frontShape
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    ))

                // Front panel top highlight edge
                Path { p in
                    p.move(to: CGPoint(x: 0, y: frontY + 0.5))
                    p.addLine(to: CGPoint(x: w, y: frontY + 0.5))
                }
                .stroke(Color.white.opacity(0.30), lineWidth: 1)

                // Content
                VStack(spacing: 9) {
                    DocumentFolderIconView(item: iconItem, size: 30, color: .white)
                        .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)

                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 40, height: 3)
                }
                .frame(width: w, height: frontH)
                .offset(y: (h - frontH) / 2 + frontH * 0.08)

                // Outer border
                backShape
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)

                // Bottom depth
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * 0.72, height: 8)
                    .blur(radius: 7)
                    .offset(y: h * 0.50)
            }
            .frame(width: w, height: h)
        }
    }
}

private extension Color {
    func lighter(by amount: Double) -> Color {
        adjustBrightness(by: abs(amount))
    }

    func darker(by amount: Double) -> Color {
        adjustBrightness(by: -abs(amount))
    }

    private func adjustBrightness(by amount: Double) -> Color {
#if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return self
        }

        return Color(
            red: min(max(Double(red) + amount, 0), 1),
            green: min(max(Double(green) + amount, 0), 1),
            blue: min(max(Double(blue) + amount, 0), 1),
            opacity: Double(alpha)
        )
#else
        return self
#endif
    }
}

// MARK: - Document Folder Icon Helpers

private enum DocumentFolderIconHelpers {
    static let fallback = BookmarkIconItem(name: "folder.fill", source: .system)

    static func storageValue(for item: BookmarkIconItem) -> String {
        "\(item.source.rawValue):\(item.name)"
    }

    static func item(from storage: String) -> BookmarkIconItem {
        let trimmed = storage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if let match = BookmarkCombinedIconLibrary.all.first(where: { storageValue(for: $0) == trimmed }) {
            return match
        }

        if let match = BookmarkCombinedIconLibrary.all.first(where: { $0.name == trimmed }) {
            return match
        }

        if trimmed.hasPrefix("asset:") {
            let name = String(trimmed.dropFirst("asset:".count))
            return BookmarkIconItem(name: name, source: .asset)
        }

        if trimmed.hasPrefix("system:") {
            let name = String(trimmed.dropFirst("system:".count))
            return BookmarkIconItem(name: name, source: .system)
        }

        return fallback
    }
}

private struct DocumentFolderIconView: View {
    let item: BookmarkIconItem
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            switch item.source {
            case .system:
                Image(systemName: item.name)
                    .font(.system(size: size, weight: .bold))
            case .asset:
                Image(item.name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .foregroundStyle(color)
    }
}

// MARK: - Document Folder Editor Sheet

private struct DocumentFolderEditorSheet: View {
    @Environment(\.modelContext) private var modelContext

    let book: DocumentBook
    let folder: DocumentFolder?
    let onClose: () -> Void
    let onSave: () -> Void

    @State private var title = ""
    @State private var selectedIcon = DocumentFolderIconHelpers.fallback
    @State private var iconSearchText = ""
    @State private var isIconScrolling = false

    private var filteredIcons: [BookmarkIconItem] {
        let query = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return BookmarkCombinedIconLibrary.all }

        return BookmarkCombinedIconLibrary.all.filter { item in
            item.name.lowercased().contains(query) ||
            item.source.rawValue.lowercased().contains(query)
        }
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: onClose,
            width: 680,
            heightRatio: 0.82,
            header: {
                HStack {
                    GradientTitle(text: folder == nil ? "New Folder" : "Edit Folder", font: .title2.bold())
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
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

                    LystariaTextField(placeholder: "Folder title", text: $title)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ICON")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: book.coverHex).opacity(0.75))
                                .frame(width: 58, height: 58)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.16), lineWidth: 1))

                            DocumentFolderIconView(item: selectedIcon, size: 28, color: .white)
                        }

                        DocumentSearchBar(text: $iconSearchText, placeholder: "Search icons")
                    }

                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(filteredIcons) { icon in
                                Button {
                                    guard !isIconScrolling else { return }
                                    selectedIcon = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(selectedIcon.id == icon.id ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(selectedIcon.id == icon.id ? Color.white.opacity(0.28) : Color.white.opacity(0.10), lineWidth: 1)
                                            )

                                        DocumentFolderIconView(item: icon, size: 23, color: .white)
                                    }
                                    .frame(height: 54)
                                    .contentShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 310)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { _ in
                                isIconScrolling = true
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                    isIconScrolling = false
                                }
                            }
                    )
                }
            },
            footer: {
                Button { saveFolder() } label: {
                    Text(folder == nil ? "Create Folder" : "Save Changes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(title.docTrimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: title.docTrimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(title.docTrimmed.isEmpty)
            }
        )
        .onAppear {
            if let folder {
                title = folder.title
                selectedIcon = DocumentFolderIconHelpers.item(from: folder.iconName)
            } else {
                title = ""
                selectedIcon = DocumentFolderIconHelpers.fallback
            }
        }
    }

    private func saveFolder() {
        let cleanTitle = title.docTrimmed
        guard !cleanTitle.isEmpty else { return }

        if let folder {
            folder.title = cleanTitle
            folder.iconName = DocumentFolderIconHelpers.storageValue(for: selectedIcon)
            folder.colorHex = book.coverHex
            folder.book = book
            folder.updatedAt = Date()
        } else {
            let newFolder = DocumentFolder(
                title: cleanTitle,
                iconName: DocumentFolderIconHelpers.storageValue(for: selectedIcon),
                colorHex: book.coverHex
            )
            newFolder.book = book
            newFolder.updatedAt = Date()
            modelContext.insert(newFolder)
        }

        try? modelContext.save()
        onSave()
        onClose()
    }
}
