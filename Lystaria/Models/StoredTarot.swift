//
//  StoredTarot.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation

struct StoredDailyTarotTip: Codable, Equatable {
    let dayKey: String
    let tip: DailyTarotTip
}
