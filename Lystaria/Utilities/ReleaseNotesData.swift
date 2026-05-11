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
            id: "release-2-1-1",
            version: "Version 2.1.1",
            dateText: "May 2026",
            title: "Journal Editor Expansion",
            items: [
                "The journal editor now mirrors the documents editor, allowing for more creative expression, customization, and freedom while writing."
            ],
            sortOrder: 5
        ),
        ReleaseNoteSeed(
            id: "release-2-1",
            version: "Version 2.1",
            dateText: "May 2026",
            title: "Stability & Documents Update",
            items: [
                "Fixed calendar event scheduling issues throughout the system. Dates and times are now properly restored and notifications should no longer appear on the wrong days.",
                "Reminder history entries can now be deleted directly from the reminder history page.",
                "Expanded the documents system with inline properties including date, text, URL, number, select, multi-select, and checkbox properties.",
                "Added text highlighting inside documents. You can now select text and use the circle icon to apply one of two highlight colors.",
                "Documents now support document-level text color customization with full color selection.",
                "Added new document background options including default, gradient, solid color, and image backgrounds.",
                "Fixed document background image scrolling issues where scrolling could jump back to the beginning or unexpectedly switch tabs.",
                "Updated the dashboard consistency card so the same area can no longer appear in multiple states at once.",
                "Refined the Wellness Wall AI system to provide more supportive and emotionally aware insight responses."
            ],
            sortOrder: 4
        ),

        ReleaseNoteSeed(
            id: "release-2-0",
            version: "Version 2.0",
            dateText: "May 2026",
            title: "Updated the Latest Version",
            items: [
                "Thank you so much for downloading Lystaria. My hope is that this app becomes a comforting place you return to often and truly make your own.",
                "Lystaria is designed to be a feature-rich personal system with tools for organization, routines, wellness, journaling, reminders, reading, and more.",
                "A brand new documents system is currently being expanded with a powerful block-based editor. It is already usable now, but it will continue evolving frequently with new features and improvements.",
                "Please allow the onboarding walkthrough to fully run when you open the app. It was designed to help you discover where every page lives and what each feature is meant for so you do not miss hidden tools or systems.",
                "Reminders can now be skipped and completed reminders can be viewed inside the new reminder history view.",
                "Thank you again for supporting such a new project. If you ever have the time, leaving an honest App Store rating or review would genuinely help support the growth of Lystaria.",
                "See you around and welcome to Lystaria."
            ],
            sortOrder: 3
        ),
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
