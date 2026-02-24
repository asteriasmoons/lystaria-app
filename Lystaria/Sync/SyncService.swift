//
//  SyncService.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/6/26.
//

import Foundation
import SwiftData
import Supabase
import Auth

struct RemoteBook: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let author: String?
    let status: String?
    let current_page: Int?
    let total_pages: Int?
    let summary: String?
    let rating: Int?
    let created_at: String?
    let updated_at: String?
    let deleted_at: String?
}

struct RemoteReminder: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let details: String?
    let status_raw: String?
    let next_run_at: String?
    let acknowledged_at: String?
    let pending_next_run_at: String?
    let run_day_key: String?
    let sent_times_of_day: [String]?
    let schedule: String?
    let timezone: String?
    let last_run_at: String?
    let created_at: String?
    let updated_at: String?
    let deleted_at: String?
    let linked_kind_raw: String?
    let linked_habit_id: String?
}

struct InsertRemoteBookRow: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let author: String?
    let status: String?
    let current_page: Int?
    let total_pages: Int?
    let summary: String?
    let rating: Int?
    let deleted_at: String?
    let updated_at: String
}

struct InsertRemoteReminderRow: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let details: String?
    let status_raw: String?
    let next_run_at: String?
    let acknowledged_at: String?
    let pending_next_run_at: String?
    let run_day_key: String?
    let sent_times_of_day: [String]?
    let schedule: String?
    let timezone: String?
    let last_run_at: String?
    let created_at: String
    let updated_at: String
    let deleted_at: String?
    let linked_kind_raw: String?
    let linked_habit_id: String?
}

struct UpdateRemoteBookRow: Encodable {
    let title: String
    let author: String?
    let status: String?
    let current_page: Int?
    let total_pages: Int?
    let summary: String?
    let rating: Int?
    let deleted_at: String?
    let updated_at: String
}

struct UpdateRemoteReminderRow: Encodable {
    let title: String
    let details: String?
    let status_raw: String?
    let next_run_at: String?
    let acknowledged_at: String?
    let pending_next_run_at: String?
    let run_day_key: String?
    let sent_times_of_day: [String]?
    let schedule: String?
    let timezone: String?
    let last_run_at: String?
    let deleted_at: String?
    let updated_at: String
    let linked_kind_raw: String?
    let linked_habit_id: String?
}

struct RemoteJournalBook: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let cover_hex: String?
    let created_at: String?
    let updated_at: String?
    let deleted_at: String?
}

struct InsertRemoteJournalBookRow: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let cover_hex: String?
    let created_at: String
    let updated_at: String
    let deleted_at: String?
}

struct UpdateRemoteJournalBookRow: Encodable {
    let title: String
    let cover_hex: String?
    let updated_at: String
    let deleted_at: String?
}

struct RemoteJournalEntry: Codable {
    let id: UUID
    let user_id: UUID
    let book_id: UUID?
    let title: String
    let body: String?
    let body_data: String?
    let tags: [String]?
    let created_at: String?
    let updated_at: String?
    let deleted_at: String?
}

struct InsertRemoteJournalEntryRow: Encodable {
    let id: UUID
    let user_id: UUID
    let book_id: UUID?
    let title: String
    let body: String?
    let body_data: Data?
    let tags: [String]?
    let created_at: String
    let updated_at: String
    let deleted_at: String?
}

struct UpdateRemoteJournalEntryRow: Encodable {
    let book_id: UUID?
    let title: String
    let body: String?
    let body_data: Data?
    let tags: [String]?
    let updated_at: String
    let deleted_at: String?
}

struct RemoteMoodLog: Codable {
    let id: UUID
    let user_id: UUID
    let moods: [String]
    let activities: [String]
    let note: String?
    let score: Double
    let created_at: String?
    let updated_at: String?
}

struct InsertRemoteMoodLogRow: Encodable {
    let id: UUID
    let user_id: UUID
    let moods: [String]
    let activities: [String]
    let note: String?
    let score: Double
    let created_at: String
    let updated_at: String
}

struct UpdateRemoteMoodLogRow: Encodable {
    let moods: [String]
    let activities: [String]
    let note: String?
    let score: Double
    let updated_at: String
}

@MainActor
final class SyncService {
    static let shared = SyncService()

    private init() {}

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let supabaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        return formatter
    }()

    private func parseSupabaseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let date = supabaseDateFormatter.date(from: value) {
            return date
        }
        if value.hasSuffix("+00") {
            let normalized = String(value.dropLast(3)) + "Z"
            let isoLike = normalized.replacingOccurrences(of: " ", with: "T")
            if let date = isoFormatter.date(from: isoLike) {
                return date
            }
        }
        let isoLike = value.replacingOccurrences(of: " ", with: "T")
        if let date = isoFormatter.date(from: isoLike) {
            return date
        }
        return nil
    }

    private func encodeReminderSchedule(_ schedule: ReminderSchedule?) -> String? {
        guard let schedule else { return nil }
        do {
            let data = try JSONEncoder().encode(schedule)
            return String(data: data, encoding: .utf8)
        } catch {
            print("[SyncService] Failed to encode reminder schedule: \(error)")
            return nil
        }
    }

    private func decodeReminderSchedule(_ raw: String?) -> ReminderSchedule? {
        guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(ReminderSchedule.self, from: data)
        } catch {
            print("[SyncService] Failed to decode reminder schedule: \(error)")
            return nil
        }
    }

    private func decodeSupabaseBytea(_ raw: String?) -> Data? {
        guard let raw, !raw.isEmpty else { return nil }

        // Postgres bytea commonly comes back as hex like "\\xDEADBEEF"
        if raw.hasPrefix("\\x") {
            let hex = String(raw.dropFirst(2))
            return dataFromHexString(hex)
        }

        // Fallback if a provider ever returns Base64 instead.
        return Data(base64Encoded: raw)
    }

    private func dataFromHexString(_ hex: String) -> Data? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = next
        }

        return data
    }

    func pullBooks(into context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let remoteBooks: [RemoteBook] = try await SupabaseManager.shared.client
            .from("books")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let localBooks = try context.fetch(FetchDescriptor<Book>())

        for remote in remoteBooks {
            if let existing = localBooks.first(where: { $0.serverId == remote.id.uuidString }) {
                existing.title = remote.title
                existing.author = remote.author ?? ""
                existing.shortSummary = remote.summary ?? ""
                existing.status = BookStatus(rawValue: remote.status ?? "tbr") ?? .tbr
                existing.rating = remote.rating ?? 0
                existing.currentPage = remote.current_page
                existing.totalPages = remote.total_pages
                existing.updatedAt = Date()
                existing.lastSyncedAt = Date()
                existing.needsSync = false
            } else {
                let newBook = Book(
                    title: remote.title,
                    author: remote.author ?? "",
                    shortSummary: remote.summary ?? "",
                    rating: remote.rating ?? 0,
                    status: BookStatus(rawValue: remote.status ?? "tbr") ?? .tbr,
                    totalPages: remote.total_pages,
                    currentPage: remote.current_page,
                    serverId: remote.id.uuidString,
                    needsSync: false,
                    lastSyncedAt: Date()
                )

                context.insert(newBook)
            }
        }

        try context.save()
    }

    func pushBooks(from context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let localBooks = try context.fetch(FetchDescriptor<Book>())
        let dirtyBooks = localBooks.filter { $0.needsSync }

        for book in dirtyBooks {
            let deletedAtString = book.deletedAt.map { isoFormatter.string(from: $0) }
            let updatedAtString = isoFormatter.string(from: book.updatedAt)

            if let serverId = book.serverId, UUID(uuidString: serverId) != nil {
                let row = UpdateRemoteBookRow(
                    title: book.title,
                    author: book.author.isEmpty ? nil : book.author,
                    status: book.status.rawValue,
                    current_page: book.currentPage,
                    total_pages: book.totalPages,
                    summary: book.shortSummary.isEmpty ? nil : book.shortSummary,
                    rating: book.rating,
                    deleted_at: deletedAtString,
                    updated_at: updatedAtString
                )

                try await SupabaseManager.shared.client
                    .from("books")
                    .update(row)
                    .eq("id", value: serverId)
                    .eq("user_id", value: userID.uuidString)
                    .execute()
            } else {
                let newID = UUID()

                let row = InsertRemoteBookRow(
                    id: newID,
                    user_id: userID,
                    title: book.title,
                    author: book.author.isEmpty ? nil : book.author,
                    status: book.status.rawValue,
                    current_page: book.currentPage,
                    total_pages: book.totalPages,
                    summary: book.shortSummary.isEmpty ? nil : book.shortSummary,
                    rating: book.rating,
                    deleted_at: deletedAtString,
                    updated_at: updatedAtString
                )

                try await SupabaseManager.shared.client
                    .from("books")
                    .insert(row)
                    .execute()

                book.serverId = newID.uuidString
            }

            book.needsSync = false
            book.lastSyncedAt = Date()
        }

        try context.save()
    }

    func syncBooks(context: ModelContext) async throws {
        try await pushBooks(from: context)
        try await pullBooks(into: context)
    }

    func pullReminders(into context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let remoteReminders: [RemoteReminder] = try await SupabaseManager.shared.client
            .from("reminders")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let localReminders = try context.fetch(FetchDescriptor<LystariaReminder>())

        for remote in remoteReminders {
            if let existing = localReminders.first(where: { $0.serverId == remote.id.uuidString }) {

                // Only overwrite local data if the remote record is strictly newer.
                // This prevents a stale Supabase row (e.g. from before table columns were added)
                // from clobbering correct local data that hasn't been pushed yet.
                let remoteUpdatedAt = parseSupabaseDate(remote.updated_at)
                let localUpdatedAt = existing.updatedAt
                let remoteIsNewer = remoteUpdatedAt.map { $0 > localUpdatedAt } ?? false

                guard remoteIsNewer else {
                    print("[SyncService] pullReminders: skipping '\(existing.title)' — local is newer or same")
                    continue
                }

                existing.serverId = remote.id.uuidString
                existing.userId = remote.user_id.uuidString
                existing.title = remote.title
                if let remoteDetails = remote.details {
                    existing.details = remoteDetails
                }
                existing.statusRaw = remote.status_raw ?? existing.statusRaw
                if let date = parseSupabaseDate(remote.next_run_at) {
                    existing.nextRunAt = date
                }
                // Only overwrite acknowledgedAt if server explicitly has a value.
                // Never let a non-nil server value restore a nil we just set locally.
                if remote.acknowledged_at != nil {
                    existing.acknowledgedAt = parseSupabaseDate(remote.acknowledged_at)
                }
                if remote.pending_next_run_at != nil {
                    existing.pendingNextRunAt = parseSupabaseDate(remote.pending_next_run_at)
                }
                if let remoteRunDayKey = remote.run_day_key {
                    existing.runDayKey = remoteRunDayKey
                }
                if let remoteSentTimes = remote.sent_times_of_day, !remoteSentTimes.isEmpty {
                    existing.sentTimesOfDay = remoteSentTimes
                }
                // Only overwrite schedule if server has a non-nil, decodable value.
                // A null server schedule (from before the column existed) must never
                // replace a valid local schedule.
                if let decodedSchedule = decodeReminderSchedule(remote.schedule) {
                    existing.schedule = decodedSchedule
                } else {
                    print("[SyncService] pullReminders: server schedule is null/invalid for '\(existing.title)' — keeping local schedule (\(existing.schedule?.kind.rawValue ?? "nil"))")
                }
                existing.timezone = remote.timezone ?? existing.timezone
                if remote.last_run_at != nil {
                    existing.lastRunAt = parseSupabaseDate(remote.last_run_at)
                }
                if let created = parseSupabaseDate(remote.created_at) {
                    existing.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    existing.updatedAt = updated
                }
                existing.deletedAt = parseSupabaseDate(remote.deleted_at)
                if let remoteLinkedKind = remote.linked_kind_raw {
                    existing.linkedKindRaw = remoteLinkedKind
                }
                if let remoteLinkedHabit = remote.linked_habit_id {
                    existing.linkedHabitId = UUID(uuidString: remoteLinkedHabit)
                }
                existing.lastSyncedAt = Date()
                existing.needsSync = false
            } else {
                if parseSupabaseDate(remote.deleted_at) != nil {
                    continue
                }
                let newReminder = LystariaReminder(
                    title: remote.title,
                    nextRunAt: parseSupabaseDate(remote.next_run_at) ?? Date(),
                    schedule: decodeReminderSchedule(remote.schedule)
                )

                newReminder.userId = remote.user_id.uuidString
                newReminder.details = remote.details
                newReminder.statusRaw = remote.status_raw ?? newReminder.statusRaw
                newReminder.acknowledgedAt = parseSupabaseDate(remote.acknowledged_at)
                newReminder.pendingNextRunAt = parseSupabaseDate(remote.pending_next_run_at)
                newReminder.runDayKey = remote.run_day_key
                newReminder.sentTimesOfDay = remote.sent_times_of_day ?? []
                newReminder.timezone = remote.timezone ?? newReminder.timezone
                newReminder.lastRunAt = parseSupabaseDate(remote.last_run_at)
                if let created = parseSupabaseDate(remote.created_at) {
                    newReminder.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    newReminder.updatedAt = updated
                }
                newReminder.deletedAt = parseSupabaseDate(remote.deleted_at)
                newReminder.linkedKindRaw = remote.linked_kind_raw
                newReminder.linkedHabitId = remote.linked_habit_id.flatMap(UUID.init(uuidString:))
                newReminder.serverId = remote.id.uuidString
                newReminder.needsSync = false
                newReminder.lastSyncedAt = Date()

                context.insert(newReminder)
            }
        }

        try context.save()
    }

    func pushReminders(from context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let localReminders = try context.fetch(FetchDescriptor<LystariaReminder>())
        let dirtyReminders = localReminders.filter { $0.needsSync }

        for reminder in dirtyReminders {
            let deletedAtString = reminder.deletedAt.map { isoFormatter.string(from: $0) }
            let updatedAtString = isoFormatter.string(from: reminder.updatedAt)
            let createdAtString = isoFormatter.string(from: reminder.createdAt)
            let nextRunString = isoFormatter.string(from: reminder.nextRunAt)
            let acknowledgedAtString = reminder.acknowledgedAt.map { isoFormatter.string(from: $0) }
            let pendingNextRunAtString = reminder.pendingNextRunAt.map { isoFormatter.string(from: $0) }
            let lastRunAtString = reminder.lastRunAt.map { isoFormatter.string(from: $0) }
            let scheduleString = encodeReminderSchedule(reminder.schedule)
            let sentTimes = reminder.sentTimesOfDay.isEmpty ? nil : reminder.sentTimesOfDay

            if let serverId = reminder.serverId, UUID(uuidString: serverId) != nil {
                let existingRemote: [RemoteReminder] = try await SupabaseManager.shared.client
                    .from("reminders")
                    .select()
                    .eq("id", value: serverId)
                    .eq("user_id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if !existingRemote.isEmpty {
                    let row = UpdateRemoteReminderRow(
                        title: reminder.title,
                        details: reminder.details,
                        status_raw: reminder.statusRaw,
                        next_run_at: nextRunString,
                        acknowledged_at: acknowledgedAtString,
                        pending_next_run_at: pendingNextRunAtString,
                        run_day_key: reminder.runDayKey,
                        sent_times_of_day: sentTimes,
                        schedule: scheduleString,
                        timezone: reminder.timezone,
                        last_run_at: lastRunAtString,
                        deleted_at: deletedAtString,
                        updated_at: updatedAtString,
                        linked_kind_raw: reminder.linkedKindRaw,
                        linked_habit_id: reminder.linkedHabitId?.uuidString
                    )

                    try await SupabaseManager.shared.client
                        .from("reminders")
                        .update(row)
                        .eq("id", value: serverId)
                        .eq("user_id", value: userID.uuidString)
                        .execute()
                } else {
                    let row = InsertRemoteReminderRow(
                        id: UUID(uuidString: serverId)!,
                        user_id: userID,
                        title: reminder.title,
                        details: reminder.details,
                        status_raw: reminder.statusRaw,
                        next_run_at: nextRunString,
                        acknowledged_at: acknowledgedAtString,
                        pending_next_run_at: pendingNextRunAtString,
                        run_day_key: reminder.runDayKey,
                        sent_times_of_day: sentTimes,
                        schedule: scheduleString,
                        timezone: reminder.timezone,
                        last_run_at: lastRunAtString,
                        created_at: createdAtString,
                        updated_at: updatedAtString,
                        deleted_at: deletedAtString,
                        linked_kind_raw: reminder.linkedKindRaw,
                        linked_habit_id: reminder.linkedHabitId?.uuidString
                    )

                    try await SupabaseManager.shared.client
                        .from("reminders")
                        .insert(row)
                        .execute()

                    reminder.userId = userID.uuidString
                }
            } else {
                let newID = UUID()

                let row = InsertRemoteReminderRow(
                    id: newID,
                    user_id: userID,
                    title: reminder.title,
                    details: reminder.details,
                    status_raw: reminder.statusRaw,
                    next_run_at: nextRunString,
                    acknowledged_at: acknowledgedAtString,
                    pending_next_run_at: pendingNextRunAtString,
                    run_day_key: reminder.runDayKey,
                    sent_times_of_day: sentTimes,
                    schedule: scheduleString,
                    timezone: reminder.timezone,
                    last_run_at: lastRunAtString,
                    created_at: createdAtString,
                    updated_at: updatedAtString,
                    deleted_at: deletedAtString,
                    linked_kind_raw: reminder.linkedKindRaw,
                    linked_habit_id: reminder.linkedHabitId?.uuidString
                )

                try await SupabaseManager.shared.client
                    .from("reminders")
                    .insert(row)
                    .execute()

                reminder.serverId = newID.uuidString
                reminder.userId = userID.uuidString
            }

            reminder.needsSync = false
            reminder.lastSyncedAt = Date()
        }

        try context.save()
    }

    func forceReminderResync(context: ModelContext) throws {
        let reminders = try context.fetch(FetchDescriptor<LystariaReminder>())

        for reminder in reminders {
            reminder.markDirty()
        }

        try context.save()
    }

    func syncReminders(context: ModelContext) async throws {
        try await pushReminders(from: context)
        try await pullReminders(into: context)
    }

    func pullJournalBooks(into context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let remoteBooks: [RemoteJournalBook] = try await SupabaseManager.shared.client
            .from("journal_books")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let localBooks = try context.fetch(FetchDescriptor<JournalBook>())

        for remote in remoteBooks {
            if let existing = localBooks.first(where: { $0.serverId == remote.id.uuidString }) {
                existing.serverId = remote.id.uuidString
                existing.userId = remote.user_id.uuidString
                existing.title = remote.title
                existing.coverHex = remote.cover_hex ?? existing.coverHex
                if let created = parseSupabaseDate(remote.created_at) {
                    existing.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    existing.updatedAt = updated
                }
                existing.deletedAt = parseSupabaseDate(remote.deleted_at)
                existing.lastSyncedAt = Date()
                existing.needsSync = false
            } else {
                if parseSupabaseDate(remote.deleted_at) != nil {
                    continue
                }

                let newBook = JournalBook(
                    title: remote.title,
                    coverHex: remote.cover_hex ?? "#6A5CFF",
                    serverId: remote.id.uuidString,
                    userId: remote.user_id.uuidString,
                    needsSync: false,
                    lastSyncedAt: Date(),
                    deletedAt: parseSupabaseDate(remote.deleted_at)
                )

                if let created = parseSupabaseDate(remote.created_at) {
                    newBook.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    newBook.updatedAt = updated
                }

                context.insert(newBook)
            }
        }

        try context.save()
    }

    func pushJournalBooks(from context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let localBooks = try context.fetch(FetchDescriptor<JournalBook>())
        let dirtyBooks = localBooks.filter { $0.needsSync }

        for book in dirtyBooks {
            let deletedAtString = book.deletedAt.map { isoFormatter.string(from: $0) }
            let updatedAtString = isoFormatter.string(from: book.updatedAt)
            let createdAtString = isoFormatter.string(from: book.createdAt)

            if let serverId = book.serverId, UUID(uuidString: serverId) != nil {
                let existingRemote: [RemoteJournalBook] = try await SupabaseManager.shared.client
                    .from("journal_books")
                    .select()
                    .eq("id", value: serverId)
                    .eq("user_id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if !existingRemote.isEmpty {
                    let row = UpdateRemoteJournalBookRow(
                        title: book.title,
                        cover_hex: book.coverHex,
                        updated_at: updatedAtString,
                        deleted_at: deletedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("journal_books")
                        .update(row)
                        .eq("id", value: serverId)
                        .eq("user_id", value: userID.uuidString)
                        .execute()
                } else {
                    let row = InsertRemoteJournalBookRow(
                        id: UUID(uuidString: serverId)!,
                        user_id: userID,
                        title: book.title,
                        cover_hex: book.coverHex,
                        created_at: createdAtString,
                        updated_at: updatedAtString,
                        deleted_at: deletedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("journal_books")
                        .insert(row)
                        .execute()

                    book.userId = userID.uuidString
                }
            } else {
                let newID = UUID()

                let row = InsertRemoteJournalBookRow(
                    id: newID,
                    user_id: userID,
                    title: book.title,
                    cover_hex: book.coverHex,
                    created_at: createdAtString,
                    updated_at: updatedAtString,
                    deleted_at: deletedAtString
                )

                try await SupabaseManager.shared.client
                    .from("journal_books")
                    .insert(row)
                    .execute()

                book.serverId = newID.uuidString
                book.userId = userID.uuidString
            }

            book.needsSync = false
            book.lastSyncedAt = Date()
        }

        try context.save()
    }

    func forceJournalBookResync(context: ModelContext) throws {
        let books = try context.fetch(FetchDescriptor<JournalBook>())

        for book in books {
            book.markDirty()
        }

        try context.save()
    }

    func syncJournalBooks(context: ModelContext) async throws {
        try await pushJournalBooks(from: context)
        try await pullJournalBooks(into: context)
    }

    func pullJournalEntries(into context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let remoteEntries: [RemoteJournalEntry] = try await SupabaseManager.shared.client
            .from("journal_entries")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let localEntries = try context.fetch(FetchDescriptor<JournalEntry>())
        let localBooks = try context.fetch(FetchDescriptor<JournalBook>())

        for remote in remoteEntries {
            let resolvedBook: JournalBook? = {
                guard let remoteBookId = remote.book_id else { return nil }
                return localBooks.first(where: { $0.serverId == remoteBookId.uuidString })
            }()

            if let existing = localEntries.first(where: { $0.serverId == remote.id.uuidString }) {
                // If the remote entry is deleted, remove it locally and move on
                if parseSupabaseDate(remote.deleted_at) != nil {
                    context.delete(existing)
                    continue
                }
                existing.serverId = remote.id.uuidString
                existing.userId = remote.user_id.uuidString
                existing.title = remote.title
                if let remoteBody = remote.body {
                    existing.body = remoteBody
                }
                if let remoteBodyData = decodeSupabaseBytea(remote.body_data),
                   let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: remoteBodyData) {
                    unarchiver.requiresSecureCoding = false
                    let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
                    unarchiver.finishDecoding()
                    if let decoded {
                        existing.bodyAttributedText = decoded
                    }
                }
                if let remoteTags = remote.tags {
                    existing.tags = remoteTags
                }
                existing.book = resolvedBook
                if let created = parseSupabaseDate(remote.created_at) {
                    existing.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    existing.updatedAt = updated
                }
                existing.deletedAt = parseSupabaseDate(remote.deleted_at)
                existing.lastSyncedAt = Date()
                existing.needsSync = false
            } else {
                if parseSupabaseDate(remote.deleted_at) != nil {
                    continue
                }

                let attributedBody: NSAttributedString
                if let remoteBodyData = decodeSupabaseBytea(remote.body_data),
                   let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: remoteBodyData) {
                    unarchiver.requiresSecureCoding = false
                    let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
                    unarchiver.finishDecoding()
                    attributedBody = decoded ?? NSAttributedString(string: remote.body ?? "")
                } else {
                    attributedBody = NSAttributedString(string: remote.body ?? "")
                }

                let newEntry = JournalEntry(
                    title: remote.title,
                    bodyAttributedText: attributedBody,
                    tags: remote.tags ?? [],
                    book: resolvedBook,
                    serverId: remote.id.uuidString,
                    userId: remote.user_id.uuidString,
                    needsSync: false,
                    lastSyncedAt: Date(),
                    deletedAt: parseSupabaseDate(remote.deleted_at)
                )

                if let created = parseSupabaseDate(remote.created_at) {
                    newEntry.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    newEntry.updatedAt = updated
                }

                context.insert(newEntry)
            }
        }

        try context.save()
    }

    func pushJournalEntries(from context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let localEntries = try context.fetch(FetchDescriptor<JournalEntry>())
        let dirtyEntries = localEntries.filter { $0.needsSync }

        for entry in dirtyEntries {
            let deletedAtString = entry.deletedAt.map { isoFormatter.string(from: $0) }
            let updatedAtString = isoFormatter.string(from: entry.updatedAt)
            let createdAtString = isoFormatter.string(from: entry.createdAt)
            let remoteBookId = entry.book?.serverId.flatMap(UUID.init(uuidString:))

            if let serverId = entry.serverId, UUID(uuidString: serverId) != nil {
                let existingRemote: [RemoteJournalEntry] = try await SupabaseManager.shared.client
                    .from("journal_entries")
                    .select()
                    .eq("id", value: serverId)
                    .eq("user_id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if !existingRemote.isEmpty {
                    let row = UpdateRemoteJournalEntryRow(
                        book_id: remoteBookId,
                        title: entry.title,
                        body: entry.body,
                        body_data: entry.bodyData,
                        tags: entry.tags,
                        updated_at: updatedAtString,
                        deleted_at: deletedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("journal_entries")
                        .update(row)
                        .eq("id", value: serverId)
                        .eq("user_id", value: userID.uuidString)
                        .execute()
                } else {
                    let row = InsertRemoteJournalEntryRow(
                        id: UUID(uuidString: serverId)!,
                        user_id: userID,
                        book_id: remoteBookId,
                        title: entry.title,
                        body: entry.body,
                        body_data: entry.bodyData,
                        tags: entry.tags,
                        created_at: createdAtString,
                        updated_at: updatedAtString,
                        deleted_at: deletedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("journal_entries")
                        .insert(row)
                        .execute()

                    entry.userId = userID.uuidString
                }
            } else {
                let newID = UUID()

                let row = InsertRemoteJournalEntryRow(
                    id: newID,
                    user_id: userID,
                    book_id: remoteBookId,
                    title: entry.title,
                    body: entry.body,
                    body_data: entry.bodyData,
                    tags: entry.tags,
                    created_at: createdAtString,
                    updated_at: updatedAtString,
                    deleted_at: deletedAtString
                )

                try await SupabaseManager.shared.client
                    .from("journal_entries")
                    .insert(row)
                    .execute()

                entry.serverId = newID.uuidString
                entry.userId = userID.uuidString
            }

            entry.needsSync = false
            entry.lastSyncedAt = Date()
        }

        try context.save()
    }

    func forceJournalEntryResync(context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<JournalEntry>())

        for entry in entries {
            entry.markDirty()
        }

        try context.save()
    }

    func syncJournalEntries(context: ModelContext) async throws {
        try await pushJournalEntries(from: context)
        try await pullJournalEntries(into: context)
    }

    func pullMoodLogs(into context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let remoteLogs: [RemoteMoodLog] = try await SupabaseManager.shared.client
            .from("mood_logs")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let localLogs = try context.fetch(FetchDescriptor<MoodLog>())

        for remote in remoteLogs {
            if let existing = localLogs.first(where: { $0.serverId == remote.id.uuidString }) {
                existing.moods = remote.moods
                existing.activities = remote.activities
                existing.note = remote.note
                existing.score = remote.score
                if let created = parseSupabaseDate(remote.created_at) {
                    existing.createdAt = created
                }
                if let updated = parseSupabaseDate(remote.updated_at) {
                    existing.updatedAt = updated
                }
                existing.serverId = remote.id.uuidString
                existing.lastSyncedAt = Date()
                existing.needsSync = false
            } else {
                let newLog = MoodLog(
                    moods: remote.moods,
                    activities: remote.activities,
                    note: remote.note,
                    score: remote.score,
                    createdAt: parseSupabaseDate(remote.created_at) ?? Date(),
                    updatedAt: parseSupabaseDate(remote.updated_at) ?? Date(),
                    serverId: remote.id.uuidString,
                    lastSyncedAt: Date(),
                    needsSync: false
                )

                context.insert(newLog)
            }
        }

        try context.save()
    }

    func pushMoodLogs(from context: ModelContext) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let localLogs = try context.fetch(FetchDescriptor<MoodLog>())
        let dirtyLogs = localLogs.filter { $0.needsSync }

        for log in dirtyLogs {
            let createdAtString = isoFormatter.string(from: log.createdAt)
            let updatedAtString = isoFormatter.string(from: log.updatedAt)

            if let serverId = log.serverId, UUID(uuidString: serverId) != nil {
                let existingRemote: [RemoteMoodLog] = try await SupabaseManager.shared.client
                    .from("mood_logs")
                    .select()
                    .eq("id", value: serverId)
                    .eq("user_id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if !existingRemote.isEmpty {
                    let row = UpdateRemoteMoodLogRow(
                        moods: log.moods,
                        activities: log.activities,
                        note: log.note,
                        score: log.score,
                        updated_at: updatedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("mood_logs")
                        .update(row)
                        .eq("id", value: serverId)
                        .eq("user_id", value: userID.uuidString)
                        .execute()
                } else {
                    let row = InsertRemoteMoodLogRow(
                        id: UUID(uuidString: serverId)!,
                        user_id: userID,
                        moods: log.moods,
                        activities: log.activities,
                        note: log.note,
                        score: log.score,
                        created_at: createdAtString,
                        updated_at: updatedAtString
                    )

                    try await SupabaseManager.shared.client
                        .from("mood_logs")
                        .insert(row)
                        .execute()
                }
            } else {
                let newID = UUID()

                let row = InsertRemoteMoodLogRow(
                    id: newID,
                    user_id: userID,
                    moods: log.moods,
                    activities: log.activities,
                    note: log.note,
                    score: log.score,
                    created_at: createdAtString,
                    updated_at: updatedAtString
                )

                try await SupabaseManager.shared.client
                    .from("mood_logs")
                    .insert(row)
                    .execute()

                log.serverId = newID.uuidString
            }

            log.lastSyncedAt = Date()
            log.needsSync = false
        }

        try context.save()
    }

    func forceMoodLogResync(context: ModelContext) throws {
        let logs = try context.fetch(FetchDescriptor<MoodLog>())

        for log in logs {
            log.markDirty()
        }

        try context.save()
    }

    func syncMoodLogs(context: ModelContext) async throws {
        try await pushMoodLogs(from: context)
        try await pullMoodLogs(into: context)
    }
}
