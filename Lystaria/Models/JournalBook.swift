//
//  JournalBook.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/3/26.
//

// JournalBook.swift
// Lystaria

import Foundation
import SwiftData

@Model
final class JournalBook {
    // MARK: - Sync metadata (Supabase)
    var serverId: String?          // Supabase row id
    var userId: String?            // auth.uid() owner
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var deletedAt: Date?           // soft delete for sync

    // MARK: - Fields
    var title: String
    /// Store as hex so it’s stable + easy to sync later.
    var coverHex: String

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync helpers
    func markDirty() {
        self.updatedAt = Date()
        self.needsSync = true
    }

    init(
        title: String,
        coverHex: String = "#6A5CFF",
        serverId: String? = nil,
        userId: String? = nil,
        needsSync: Bool = true,
        lastSyncedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.coverHex = coverHex
        self.serverId = serverId
        self.userId = userId
        self.needsSync = needsSync
        self.lastSyncedAt = lastSyncedAt
        self.deletedAt = deletedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
