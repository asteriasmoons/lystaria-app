//
//  SharedBookmarkInbox.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

enum SharedBookmarkInbox {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let payloadKey = "shared_bookmark_payload_queue"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ payload: SharedBookmarkPayload) throws {
        guard let sharedDefaults else {
            throw NSError(domain: "SharedBookmarkInbox", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared App Group user defaults."
            ])
        }

        var queue = (try? loadAll()) ?? []
        queue.append(payload)
        let data = try JSONEncoder().encode(queue)
        sharedDefaults.set(data, forKey: payloadKey)
        sharedDefaults.synchronize()
    }

    static func loadAll() throws -> [SharedBookmarkPayload] {
        guard let sharedDefaults else {
            throw NSError(domain: "SharedBookmarkInbox", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared App Group user defaults."
            ])
        }

        guard let data = sharedDefaults.data(forKey: payloadKey) else {
            return []
        }

        // Support legacy single-payload format gracefully.
        if let single = try? JSONDecoder().decode(SharedBookmarkPayload.self, from: data) {
            return [single]
        }

        return (try? JSONDecoder().decode([SharedBookmarkPayload].self, from: data)) ?? []
    }

    static func clear() throws {
        guard let sharedDefaults else { return }
        sharedDefaults.removeObject(forKey: payloadKey)
        // Also clear old single-payload key if present from a previous install.
        sharedDefaults.removeObject(forKey: "shared_bookmark_payload")
        sharedDefaults.synchronize()
    }
}
