//
//  OnboardingModels.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//

import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let targetID: String
    let title: String
    let message: String
}

struct OnboardingPage {
    let pageID: String
    let steps: [OnboardingStep]
}
