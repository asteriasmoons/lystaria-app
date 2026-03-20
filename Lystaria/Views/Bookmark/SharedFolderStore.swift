//
//  SharedFolderStore.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

enum SharedFolderStore {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let fileName = "shared_folders.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )
    }

    static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    static func save(_ folders: [SharedFolderOption]) throws {
        guard let fileURL else {
            throw NSError(domain: "SharedFolderStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared folder file URL."
            ])
        }

        let data = try JSONEncoder().encode(folders)
        try data.write(to: fileURL, options: .atomic)
    }

    static func load() throws -> [SharedFolderOption] {
        guard let fileURL else {
            throw NSError(domain: "SharedFolderStore", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not resolve shared folder file URL."
            ])
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SharedFolderOption].self, from: data)
    }
}
