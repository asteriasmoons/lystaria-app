//
//  SharedBookmarkInbox.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

enum SharedBookmarkInbox {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let fileName = "shared_bookmark.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )
    }

    static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    static func save(_ payload: SharedBookmarkPayload) throws {
        guard let fileURL else {
            throw NSError(domain: "SharedBookmarkInbox", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared container file URL."
            ])
        }

        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }

    static func load() throws -> SharedBookmarkPayload? {
        guard let fileURL else {
            throw NSError(domain: "SharedBookmarkInbox", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared container file URL."
            ])
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(SharedBookmarkPayload.self, from: data)
    }

    static func clear() throws {
        guard let fileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
