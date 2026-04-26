//
//  CalendarEventSyncHelper.swift
//  Lystaria
//
//  Static helpers called at every save/delete site to keep sync state
//  consistent without duplicating the logic across views.
//

import Foundation
import SwiftData

enum CalendarEventSyncHelper {

    // MARK: - Mark modified

    /// Call this whenever a user edits an existing event.
    /// Sets needsSync + syncState and bumps updatedAt.
    static func markModified(_ event: CalendarEvent) {
        guard event.syncState != .newLocal else { return }
        event.needsSync = true
        event.syncState = .modifiedLocal
        event.updatedAt = Date()
    }

    // MARK: - Mark pending delete

    /// Call this before deleting a synced event so the sync manager can push
    /// the deletion to Apple Calendar on the next sync run.
    ///
    /// Returns `true` if the event has been synced to Apple Calendar and must
    /// NOT be deleted from the model context yet — the sync manager will remove
    /// it from EventKit first, then the pending record can be cleaned up.
    ///
    /// Returns `false` if the event was never pushed to Apple Calendar — the
    /// caller should just call modelContext.delete() immediately.
    @discardableResult
    static func markPendingDelete(_ event: CalendarEvent) -> Bool {
        guard event.appleCalendarItemIdentifier != nil else {
            return false
        }
        event.needsSync = true
        event.syncState = .pendingDeleteLocal
        event.updatedAt = Date()
        return true
    }

    // MARK: - Mark exception pending delete

    /// For recurring cancellation exceptions. An exception may not have its own
    /// appleCalendarItemIdentifier but still needs to be exported as a delete
    /// to EventKit (via its parent series). Flags it for the sync manager.
    @discardableResult
    static func markExceptionPendingDelete(_ exception: CalendarEvent) -> Bool {
        guard exception.appleCalendarItemIdentifier != nil ||
              exception.parentSeriesLocalId != nil else {
            return false
        }
        exception.needsSync = true
        exception.syncState = .pendingDeleteLocal
        exception.updatedAt = Date()
        return true
    }

    // MARK: - Conflict resolution

    /// Accept the local version of a conflicted event.
    /// The next sync will push local changes to Apple Calendar.
    static func resolveConflictKeepLocal(_ event: CalendarEvent) {
        event.syncState = .modifiedLocal
        event.needsSync = true
        event.updatedAt = Date()
    }

    /// Accept the external (Apple Calendar) version of a conflicted event.
    /// Clears local hash so the next import overwrites with external data cleanly.
    static func resolveConflictUseExternal(_ event: CalendarEvent) {
        event.syncState = .synced
        event.needsSync = false
        event.lastSyncedHash = nil
        event.updatedAt = Date()
    }

    // MARK: - Pending summary

    struct PendingSummary {
        let pendingExports: Int   // newLocal + modifiedLocal
        let pendingDeletes: Int   // pendingDeleteLocal
        let conflicts: Int        // conflicted
    }

    static func pendingSummary(from events: [CalendarEvent]) -> PendingSummary {
        var exports = 0
        var deletes = 0
        var conflicts = 0
        for e in events {
            switch e.syncState {
            case .newLocal, .modifiedLocal: exports += 1
            case .pendingDeleteLocal:       deletes += 1
            case .conflicted:               conflicts += 1
            default: break
            }
        }
        return PendingSummary(pendingExports: exports, pendingDeletes: deletes, conflicts: conflicts)
    }
}
