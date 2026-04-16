//
//  Lystaria_Watch_WidgetsBundle.swift
//  Lystaria Watch Widgets
//
//  Created by Asteria Moon on 4/15/26.
//

import WidgetKit
import SwiftUI

@main
struct Lystaria_Watch_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        Lystaria_Watch_Widgets()     // accessoryCircular   — sparklefill completion
        LystariaFlowRectWidget()     // accessoryRectangular — body + nervous bars
        LystariaStepsWidget()        // accessoryCircular   — steps ring
        LystariaWaterWidget()        // accessoryCircular   — water ring
        LystariaSleepWidget()        // accessoryCircular   — sleep ring
    }
}
