//
//  StoredHoroscope.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation

struct StoredDailyHoroscope: Codable, Equatable {
    let dayKey: String
    let horoscope: DailyHoroscope
}
