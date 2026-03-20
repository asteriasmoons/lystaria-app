//
//  SharedBookmarkPayload.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

struct SharedBookmarkPayload: Codable {
    var title: String = ""
    var bookmarkDescription: String = ""
    var url: String = ""
    var tagsRaw: String = ""
    var targetFolderSystemKey: String = "inbox"
    var targetFolderName: String = "Inbox"
    var sharedAt: Date = Date()
}
