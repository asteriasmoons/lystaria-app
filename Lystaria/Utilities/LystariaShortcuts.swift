//
//  LystariaShortcuts.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import AppIntents

struct LystariaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: LogMoodIntent(),
                phrases: [
                    "Log mood in \(.applicationName)",
                    "Create mood log in \(.applicationName)"
                ],
                shortTitle: "Log Mood",
                systemImageName: "face.smiling"
            ),
            AppShortcut(
                intent: AddJournalEntryIntent(),
                phrases: [
                    "Add journal entry in \(.applicationName)",
                    "Write journal entry in \(.applicationName)",
                    "New journal entry in \(.applicationName)"
                ],
                shortTitle: "Add Journal Entry",
                systemImageName: "book.closed"
            ),
            AppShortcut(
                intent: Add8OzIntent(),
                phrases: [
                    "Add 8 oz of water in \(.applicationName)",
                    "Log 8 oz water in \(.applicationName)"
                ],
                shortTitle: "Add 8 Fl Oz",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: Add20OzIntent(),
                phrases: [
                    "Add 20 oz of water in \(.applicationName)",
                    "Log 20 oz water in \(.applicationName)"
                ],
                shortTitle: "Add 20 Fl Oz",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: AddCustomWaterIntent(),
                phrases: [
                    "Add water in \(.applicationName)",
                    "Log water in \(.applicationName)",
                    "Track water in \(.applicationName)",
                    "Add custom water in \(.applicationName)"
                ],
                shortTitle: "Add Custom Water",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: CheckInReadingIntent(),
                phrases: [
                    "Check in reading in \(.applicationName)",
                    "Check in for reading in \(.applicationName)",
                    "Log reading streak in \(.applicationName)"
                ],
                shortTitle: "Reading Check-In",
                systemImageName: "book.fill"
            ),
            AppShortcut(
                intent: SetDailyIntentionIntent(),
                phrases: [
                    "Set daily intention in \(.applicationName)",
                    "Set intention in \(.applicationName)",
                    "Update daily intention in \(.applicationName)"
                ],
                shortTitle: "Daily Intention",
                systemImageName: "sparkles"
            ),
            AppShortcut(
                intent: AddChecklistItemIntent(),
                phrases: [
                    "Add checklist item in \(.applicationName)",
                    "Add to checklist in \(.applicationName)",
                    "New checklist item in \(.applicationName)"
                ],
                shortTitle: "Add Checklist Item",
                systemImageName: "checklist"
            ),
            AppShortcut(
                intent: LogHealthMetricsIntent(),
                phrases: [
                    "Log health metrics in \(.applicationName)",
                    "Add health metrics in \(.applicationName)",
                    "Save health metrics in \(.applicationName)"
                ],
                shortTitle: "Health Metrics",
                systemImageName: "heart.text.square"
            ),
            AppShortcut(
                intent: LogExerciseIntent(),
                phrases: [
                    "Log exercise in \(.applicationName)",
                    "Add exercise in \(.applicationName)",
                    "Save exercise in \(.applicationName)"
                ],
                shortTitle: "Log Exercise",
                systemImageName: "figure.strengthtraining.traditional"
            )
        ]
    }

    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}
