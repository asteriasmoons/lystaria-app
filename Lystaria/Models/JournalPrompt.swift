//
//  JournalPrompt.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/16/26.
//

import Foundation
import SwiftData

@Model
final class JournalPrompt {
    // MARK: - Sync metadata (Supabase)
    var serverId: String?
    var userId: String?
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var deletedAt: Date?

    // MARK: - Relationship
    var book: JournalBook?

    // MARK: - Fields
    var text: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Sync helpers
    func markDirty() {
        self.updatedAt = Date()
        self.needsSync = true
    }

    init(
        text: String,
        book: JournalBook? = nil,
        serverId: String? = nil,
        userId: String? = nil,
        needsSync: Bool = true,
        lastSyncedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.text = text
        self.book = book
        self.serverId = serverId
        self.userId = userId
        self.needsSync = needsSync
        self.lastSyncedAt = lastSyncedAt
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
