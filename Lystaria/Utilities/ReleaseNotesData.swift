//
//  ReleaseNotesData.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/3/26.
//

import Foundation

struct ReleaseNotesData {

    static let notes: [ReleaseNoteSeed] = [

        ReleaseNoteSeed(
            id: "release-1-2",
            version: "Version 1.2",
            dateText: "May 2026",
            title: "Updated the Latest Version",
            items: [
                "Added the new release notes feature",
                "Reminders are now able to be skipped",
                "Added a reminder history view for skipped and completed"
            ],
            sortOrder: 2
        ),
        ReleaseNoteSeed(
            id: "release-1-0",
            version: "Version 1.0",
            dateText: "May 2026",
            title: "The First Lystaria Release",
            items: [
                "Added the new Info tab with documentation, feedback, projects, socials, and release notes.",
                "Created a centralized place to keep Lystaria’s resources easier to find.",
                "Added polished glass cards, soft dividers, and branded link rows for external resources."
            ],
            sortOrder: 1
        ),

        ReleaseNoteSeed(
            id: "release-0-9",
            version: "Early Build Notes",
            dateText: "Spring 2026",
            title: "Foundation Build",
            items: [
                "Built the foundation for reminders, journaling, reading, dashboard, and health tools.",
                "Expanded the app into a full personal care system.",
                "Refined the visual style with gradient headings and glass UI."
            ],
            sortOrder: 0
        )
    ]
}

// MARK: - Seed Model (NOT SwiftData)

struct ReleaseNoteSeed: Identifiable {
    let id: String
    let version: String
    let dateText: String
    let title: String
    let items: [String]
    let sortOrder: Int
}
