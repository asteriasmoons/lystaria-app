//
//  DailyTarot.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation

struct DailyTarotTip: Codable, Equatable, Hashable {
    let id: String
    let title: String
    let keywords: [String]
    let message: String
}
