//
//  SelfCarePointsResetLog.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import Foundation
import SwiftData

@Model
final class SelfCarePointsResetLog {
    var id: UUID = UUID()
    var userId: String = ""
    var weekStartDayKey: String = ""
    var resetAt: Date = Date()
    var pointsBeforeReset: Int = 0
    var levelBeforeReset: Int = 0
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        userId: String = "",
        weekStartDayKey: String = "",
        resetAt: Date = Date(),
        pointsBeforeReset: Int = 0,
        levelBeforeReset: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.weekStartDayKey = weekStartDayKey
        self.resetAt = resetAt
        self.pointsBeforeReset = max(0, pointsBeforeReset)
        self.levelBeforeReset = max(0, levelBeforeReset)
        self.createdAt = createdAt
    }
}
