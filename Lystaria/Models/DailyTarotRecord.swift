//
//  DailyTarotRecord.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/16/26.
//

//
//  DailyTarotRecord.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class DailyTarotRecord {
    var dayKey: String = ""
    var tipId: String = ""
    var title: String = ""
    var keywordsStorage: String = "[]"
    var message: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var keywords: [String] {
        get {
            guard let data = keywordsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                keywordsStorage = encoded
            } else {
                keywordsStorage = "[]"
            }
        }
    }

    init(
        dayKey: String,
        tipId: String,
        title: String,
        keywords: [String],
        message: String
    ) {
        self.dayKey = dayKey
        self.tipId = tipId
        self.title = title
        self.keywordsStorage = "[]"
        self.message = message
        self.createdAt = Date()
        self.updatedAt = Date()
        self.keywords = keywords
    }
}
