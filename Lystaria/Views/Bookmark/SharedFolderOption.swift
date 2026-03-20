//
//  SharedFolderOption.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation

struct SharedFolderOption: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var systemKey: String = ""
    var iconName: String = "folder.fill"
}
