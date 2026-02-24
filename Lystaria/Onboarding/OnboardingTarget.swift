//
//  OnboardingTarget.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//

import SwiftUI

struct OnboardingTarget: ViewModifier {

    let id: String

    func body(content: Content) -> some View {
        content.anchorPreference(
            key: OnboardingTargetKey.self,
            value: .bounds
        ) {
            [id: $0]
        }
    }
}

extension View {
    func onboardingTarget(_ id: String) -> some View {
        modifier(OnboardingTarget(id: id))
    }
}
