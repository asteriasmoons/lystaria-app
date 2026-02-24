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
        resetAllOnboarding()
    }

    @Published var activePage: OnboardingPage?
    @Published var currentStepIndex: Int = 0
    @Published var isShowing: Bool = false

    func start(page: OnboardingPage) {
        guard !UserDefaults.standard.bool(forKey: page.pageID) else { return }

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
    }
}
