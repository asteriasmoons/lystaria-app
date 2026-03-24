//
//  Lystaria_JournalEntriesWidget.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/22/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared UserDefaults keys (must match what JournalTabView writes)

enum JournalWidgetShared {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let booksKey   = "journalWidget.books"   // [{ id, title, coverHex }]
    static let entriesKey = "journalWidget.entries" // { bookID: [{ id, title }] }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    struct BookSnapshot: Codable, Identifiable {
        let id: String
        let title: String
        let coverHex: String
    }

    struct EntrySnapshot: Codable, Identifiable {
        let id: String
        let title: String
    }

    static func books() -> [BookSnapshot] {
        guard let data = defaults?.data(forKey: booksKey),
              let decoded = try? JSONDecoder().decode([BookSnapshot].self, from: data)
        else { return [] }
        return decoded
    }

    static func entries(for bookID: String) -> [EntrySnapshot] {
        guard let data = defaults?.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([String: [EntrySnapshot]].self, from: data)
        else { return [] }
        return decoded[bookID] ?? []
    }
}

// MARK: - AppIntent

struct JournalWidgetBookEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journal Book")
    static var defaultQuery = JournalWidgetBookEntityQuery()

    let id: String
    let title: String
    let coverHex: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct JournalWidgetBookEntityQuery: EntityQuery {
    func entities(for identifiers: [JournalWidgetBookEntity.ID]) async throws -> [JournalWidgetBookEntity] {
        JournalWidgetShared.books()
            .filter { identifiers.contains($0.id) }
            .map { JournalWidgetBookEntity(id: $0.id, title: $0.title, coverHex: $0.coverHex) }
    }

    func suggestedEntities() async throws -> [JournalWidgetBookEntity] {
        JournalWidgetShared.books()
            .map { JournalWidgetBookEntity(id: $0.id, title: $0.title, coverHex: $0.coverHex) }
    }

    func defaultResult() async -> JournalWidgetBookEntity? {
        guard let first = JournalWidgetShared.books().first else { return nil }
        return JournalWidgetBookEntity(id: first.id, title: first.title, coverHex: first.coverHex)
    }
}

struct JournalEntriesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Journal Book"
    static var description = IntentDescription("Choose which journal book to display.")

    @Parameter(title: "Book")
    var book: JournalWidgetBookEntity?
}

// MARK: - Timeline Entry

struct JournalEntriesWidgetEntry: TimelineEntry {
    let date: Date
    let bookID: String?
    let bookTitle: String
    let coverHex: String
    let entries: [JournalWidgetShared.EntrySnapshot]
    let deepLinkURL: URL?
}

// MARK: - Provider

struct JournalEntriesWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = JournalEntriesWidgetEntry
    typealias Intent = JournalEntriesWidgetIntent

    func placeholder(in context: Context) -> JournalEntriesWidgetEntry {
        JournalEntriesWidgetEntry(
            date: Date(),
            bookID: nil,
            bookTitle: "Journal Book",
            coverHex: "#6A5CFF",
            entries: [
                .init(id: "1", title: "Untitled Entry"),
                .init(id: "2", title: "Morning Thoughts"),
                .init(id: "3", title: "A Quiet Reflection"),
                .init(id: "4", title: "Things I Needed Today")
            ],
            deepLinkURL: nil
        )
    }

    func snapshot(for configuration: JournalEntriesWidgetIntent, in context: Context) async -> JournalEntriesWidgetEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: JournalEntriesWidgetIntent, in context: Context) async -> Timeline<JournalEntriesWidgetEntry> {
        let entry = makeEntry(for: configuration)
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func makeEntry(for configuration: JournalEntriesWidgetIntent) -> JournalEntriesWidgetEntry {
        let books = JournalWidgetShared.books()

        // Pick book from intent, fall back to first
        let selectedBook: JournalWidgetShared.BookSnapshot? = {
            if let intentID = configuration.book?.id,
               let match = books.first(where: { $0.id == intentID }) {
                return match
            }
            return books.first
        }()

        guard let book = selectedBook else {
            return JournalEntriesWidgetEntry(
                date: Date(), bookID: nil,
                bookTitle: "No Journal Books", coverHex: "#6A5CFF",
                entries: [], deepLinkURL: nil
            )
        }

        let entries = Array(JournalWidgetShared.entries(for: book.id).prefix(4))
        let url = URL(string: "lystaria://journal-book?id=\(book.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? book.id)")

        return JournalEntriesWidgetEntry(
            date: Date(),
            bookID: book.id,
            bookTitle: book.title,
            coverHex: book.coverHex,
            entries: entries,
            deepLinkURL: url
        )
    }
}

// MARK: - View

struct Lystaria_JournalEntriesWidgetEntryView: View {
    let entry: JournalEntriesWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.entries.isEmpty {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("No entries yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.entries) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .frame(width: 18)
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LystariaBackground()
        }
        .widgetURL(entry.deepLinkURL)
    }
}

// MARK: - Widget

struct Lystaria_JournalEntriesWidget: Widget {
    let kind: String = "Lystaria_JournalEntriesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: JournalEntriesWidgetIntent.self,
            provider: JournalEntriesWidgetProvider()
        ) { entry in
            Lystaria_JournalEntriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Journal Entries")
        .description("Shows recent entries from a selected journal book.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    Lystaria_JournalEntriesWidget()
} timeline: {
    JournalEntriesWidgetEntry(
        date: .now,
        bookID: "preview-book",
        bookTitle: "Shadow Work",
        coverHex: "#6A5CFF",
        entries: [
            .init(id: "1", title: "Untitled Entry"),
            .init(id: "2", title: "Morning Thoughts"),
            .init(id: "3", title: "A Quiet Reflection"),
            .init(id: "4", title: "Things I Needed Today")
        ],
        deepLinkURL: URL(string: "lystaria://journal-book?id=preview-book")
    )
}
