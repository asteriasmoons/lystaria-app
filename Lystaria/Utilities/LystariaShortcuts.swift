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
                shortTitle: "Add 8 fl oz",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: Add20OzIntent(),
                phrases: [
                    "Add 20 oz of water in \(.applicationName)",
                    "Log 20 oz water in \(.applicationName)"
                ],
                shortTitle: "Add 20 fl oz",
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
            )
        ]
    }

    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}
