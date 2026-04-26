//
//  Lystaria_WatchApp.swift
//  Lystaria Watch Watch App
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct Lystaria_Watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    MoodLog.self,
                    JournalBook.self,
                    JournalEntry.self,
                    Habit.self,
                    HabitLog.self,
                    HabitSkip.self,
                    ReadingStats.self,
                    DailyReadingProgress.self,
                    ReadingGoal.self,
                    ReadingSession.self,
                    Checklist.self,
                    ChecklistItem.self,
                    LystariaReminder.self,
                    RoutineChecklistItem.self,
                    ReminderMedicationLink.self,
                    KanbanBoard.self,
                    KanbanColumn.self,
                    CalendarEvent.self,
                    EventCalendar.self,
                    EventAttendee.self
                ])
                .onAppear {
                    WatchSessionManager.shared.activate()
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
