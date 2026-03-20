//
//  SharedFolderExportManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

enum SharedFolderExportManager {
    static func exportFolders(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<BookmarkFolder>()
            let folders = try modelContext.fetch(descriptor)

            let options = folders.map { folder in
                SharedFolderOption(
                    id: String(describing: folder.persistentModelID),
                    name: folder.name,
                    systemKey: folder.systemKey,
                    iconName: folder.systemKey == "inbox"
                        ? "tray.full.fill"
                        : (folder.iconName.isEmpty ? "folder.fill" : folder.iconName)
                )
            }
            .sorted {
                if $0.systemKey == "inbox" && $1.systemKey != "inbox" { return true }
                if $1.systemKey == "inbox" && $0.systemKey != "inbox" { return false }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            try SharedFolderStore.save(options)
        } catch {
            print("Shared folder export failed: \(error)")
        }
    }
}
