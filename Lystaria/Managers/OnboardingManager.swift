//
//  OnboardingManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//

import Foundation
import Combine


class OnboardingManager: ObservableObject {

    // Development helper so onboarding always appears when running the app.
    // Remove this initializer once onboarding design is finalized.
    init() {
        // resetAllOnboarding()  // DEV MODE (disabled for production)
    }

    @Published var activePage: OnboardingPage?
    @Published var currentStepIndex: Int = 0
    @Published var isShowing: Bool = false

    func start(page: OnboardingPage) {
        let defaults = UserDefaults.standard

        // Settings toggle allows onboarding tours to run again once
        let shouldForceRun = defaults.bool(forKey: "settings.showOnboardingNextLaunch")

        if shouldForceRun {
            // Clear previous completion flags so onboarding can run again
            resetAllOnboarding()

            // Turn the setting back off so it only runs once
            defaults.set(false, forKey: "settings.showOnboardingNextLaunch")
        }

        // Normal behaviour: do not run if this page was already completed
        if !shouldForceRun && defaults.bool(forKey: page.pageID) {
            return
        }

        activePage = page
        currentStepIndex = 0
        isShowing = true
    }

    func next() {
        guard let page = activePage else { return }

        if currentStepIndex + 1 < page.steps.count {
            currentStepIndex += 1
        } else {
            finish()
        }
    }

    func dismiss() {
        finish()
    }

    private func finish() {
        if let page = activePage {
            UserDefaults.standard.set(true, forKey: page.pageID)
        }

        activePage = nil
        isShowing = false
    }

    var currentStep: OnboardingStep? {
        guard let page = activePage else { return nil }
        guard page.steps.indices.contains(currentStepIndex) else { return nil }
        return page.steps[currentStepIndex]
    }
    // Clears all onboarding completion flags so tours can be tested repeatedly during development.
    func resetAllOnboarding() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "onboarding_reminders")
        defaults.removeObject(forKey: "onboarding_calendar")
        defaults.removeObject(forKey: "onboarding_journal")
        defaults.removeObject(forKey: "onboarding_dashboard")
        defaults.removeObject(forKey: "onboarding_reading")
    }
}
