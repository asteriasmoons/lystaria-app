//
//  SharedBookmarkInbox.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

enum SharedBookmarkInbox {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let payloadKey = "shared_bookmark_payload"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ payload: SharedBookmarkPayload) throws {
        guard let sharedDefaults else {
            throw NSError(domain: "SharedBookmarkInbox", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared App Group user defaults."
            ])
        }

        let data = try JSONEncoder().encode(payload)
        sharedDefaults.set(data, forKey: payloadKey)
        sharedDefaults.synchronize()
    }

    static func load() throws -> SharedBookmarkPayload? {
        guard let sharedDefaults else {
            throw NSError(domain: "SharedBookmarkInbox", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared App Group user defaults."
            ])
        }

        guard let data = sharedDefaults.data(forKey: payloadKey) else {
            return nil
        }

        return try JSONDecoder().decode(SharedBookmarkPayload.self, from: data)
    }

    static func clear() throws {
        guard let sharedDefaults else { return }
        sharedDefaults.removeObject(forKey: payloadKey)
        sharedDefaults.synchronize()
    }
}
