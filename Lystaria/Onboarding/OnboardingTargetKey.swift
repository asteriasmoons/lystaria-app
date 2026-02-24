//
//  OnboardingTargetKey.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//

//
//  OnboardingTargetKey.swift
//  Lystaria
//
//  This PreferenceKey allows views marked with
//  `.onboardingTarget("id")` to report their frame
//  (position and size) up the SwiftUI view tree.
//
//  The onboarding overlay then reads these frames
//  so it knows exactly where to place the highlight.
//

import SwiftUI

// MARK: - OnboardingTargetKey
//
// A SwiftUI PreferenceKey used to collect the positions
// of onboarding targets (icon buttons).
//
// Each target reports an Anchor<CGRect> representing
// its bounds.
//
struct OnboardingTargetKey: PreferenceKey {

    // MARK: Default Value
    //
    // Dictionary mapping target IDs → frame anchors
    //
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    // MARK: Reduce Function
    //
    // SwiftUI calls this whenever multiple views
    // report values for the same key.
    //
    // We merge them into one dictionary.
    //
    static func reduce(
        value: inout [String : Anchor<CGRect>],
        nextValue: () -> [String : Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
