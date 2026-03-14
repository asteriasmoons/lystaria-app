//
//  DailyHoroscope.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import Foundation

struct DailyHoroscope: Codable, Equatable, Hashable {
    let sign: String
    let message: String
}
