//
//  OnboardingPages.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//

import Foundation

struct OnboardingPages {

    static let reminders = OnboardingPage(
        pageID: "onboarding_reminders",
        steps: [
            OnboardingStep(
                targetID: "stepsIcon",
                title: "Steps Tracker",
                message: "Tap here to view your step progress. You can track how many steps you have for the day and see your monthly progress as well."
            ),
            OnboardingStep(
                targetID: "waterIcon",
                title: "Water Tracker",
                message: "Track how much water you've logged, add water, and see your monthly progress as well."
            )
        ]
    )

    static let calendar = OnboardingPage(
        pageID: "onboarding_calendar",
        steps: [
            OnboardingStep(
                targetID: "calendarSettingsIcon",
                title: "Calendar Settings",
                message: "Open calendar settings here. This is for things like syncing your local calendar and other cool settings."
            )
        ]
    )

    static let journal = OnboardingPage(
        pageID: "onboarding_journal",
        steps: [
            OnboardingStep(
                targetID: "moodLogsIcon",
                title: "Mood Logs",
                message: "Open your mood tracking history. See stats after seven days and track patterns across moods and activities."
            ),
            OnboardingStep(
                targetID: "habitsIcon",
                title: "Habits",
                message: "Track routines and consistency. See how many days you've completed a habit in a row. Visualize your progress, add and remove habits."
            ),
            OnboardingStep(
                targetID: "checklistsIcon",
                title: "Checklists",
                message: "Create check list items. This page acts like one giant checklist with cards for each check list item you add. Mark them as done and switch between views."
            )
        ]
    )
}
