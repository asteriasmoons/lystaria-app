//
//  EventCalendar.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/21/26.
//

import Foundation
import SwiftData

@Model
final class EventCalendar {
    var serverId: String = UUID().uuidString
    var name: String = ""
    var color: String = "#5b8def"
    var sortOrder: Int = 0
    var isDefault: Bool = false
    var isSelectedInCalendarView: Bool = true

    @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.calendar)
    var events: [CalendarEvent]? = []

    init(
        serverId: String = UUID().uuidString,
        name: String = "",
        color: String = "#5b8def",
        sortOrder: Int = 0,
        isDefault: Bool = false,
        isSelectedInCalendarView: Bool = true,
        events: [CalendarEvent]? = []
    ) {
        self.serverId = serverId
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.isSelectedInCalendarView = isSelectedInCalendarView
        self.events = events
    }
}
