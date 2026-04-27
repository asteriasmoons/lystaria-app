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
                targetID: "clockIcon",
                title: "Time Blocking",
                message: "Tap here to view your reminders in time blocking view. You can edit reminders from here and mark them as complete. Auto scrolls to the current time it is."
             ),
            OnboardingStep(
                targetID: "boardIcon",
                title: "Kanban View",
                message: "Tap here to view all your reminders in cards in kanban view. You can also mark reminders done from the kanban view."
            )
        ]
    )

    static let calendar = OnboardingPage(
        pageID: "onboarding_calendar",
        steps: [
            OnboardingStep(
                targetID: "calendarSettingsIcon",
                title: "Settings Menu",
                message: "Open calendar settings here. This is for things like syncing your local calendar and managing your calendars or joining a shared event."
            )
        ]
    )

    static let dashboard = OnboardingPage(
        pageID: "onboarding_dashboard",
        steps: [
            OnboardingStep(
                targetID: "healthIcon",
                title: "Health",
                message: "Tap here to view your health metrics and exercise logs and to log your health metrics and exercises to your day."
                ),
            OnboardingStep(
                targetID: "loveIcon",
                title: "Self-Care Points",
                message: "Tap here to see all your self care points and track your progress. You can also see your history here and what you earned on. Your level is also here."
            ),
            OnboardingStep(
                targetID: "toolboxIcon",
                title: "Toolbox",
                message: "Tap the pause icon to open the Toolbox. Inside you'll find a breathing timer with a calming animation to help you reset, and a burn card where you can type anything weighing on you and press \"Burn\" to watch it disappear in a flame."
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
    static let reading = OnboardingPage(
        pageID: "onboarding_reading",
        steps: [
            OnboardingStep(
                targetID: "bookmarkIcon",
                title: "Bookmarks",
                message: "Find and save links to folders or the inbox in the Bookmarks manager. You can also add them through the share sheet."
                ),
            OnboardingStep(
                targetID: "notesIcon",
                title: "Sticky Notes",
                message: "Create colorful sticky notes in the app and view them. Pick your own color, pin or favorite your note and filter them by views too."
               ),
            OnboardingStep(
                targetID: "readingMenuIcon",
                title: "Reading Menu",
                message: "Group up to read books together and chat about your interests and progress in buddy reads or do reading sprints with people globally."
              )
            ]
        )
    static let health = OnboardingPage(
        pageID: "onboarding_health",
        steps: [
            OnboardingStep(
                targetID: "medsIcon",
                title: "Medications",
                message: "Manage all of your medications in this tab. Includes adding dosing and other metrics for each medication and see your inventory at a glance with progress wheels."
            ),
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
    static let buddyReading = OnboardingPage(
        pageID: "onboarding_buddyReading",
        steps: [
            OnboardingStep(
                targetID: "buddyChangeNameIcon",
                title: "Display Name",
                message: "Change the display name others see when you post an announcement or join a buddy read group."
            ),
            OnboardingStep(
                targetID: "buddyRefreshIcon",
                title: "Refresh Board",
                message: "Refresh the announcement board to see the latest posts from other readers looking for a buddy."
            )
        ]
    )

    static let sprintRoom = OnboardingPage(
        pageID: "onboarding_sprintRoom",
        steps: [
            OnboardingStep(
                targetID: "sprintMenuIcon",
                title: "Sprint Menu",
                message: "Access the leaderboard, view your personal sprint points, change your display name, refresh the room, or clear the chat if you're an admin."
            )
        ]
    )

    static let medicine = OnboardingPage(
    pageID: "onboarding_medicine",
    steps: [
        OnboardingStep(
            targetID: "starIcon",
            title: "Symptom Tracker",
            message: "Track all of your symptoms on this page. Log when you have a headache, feel nauseous or anything else you need to keep track of. Displayed nicely on a card view."
        )
     ]
   )
}
