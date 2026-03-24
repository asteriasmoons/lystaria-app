//
//  Lystaria_WidgetsBundle.swift
//  Lystaria Widgets
//
//  Created by Asteria Moon on 3/20/26.
//

import WidgetKit
import SwiftUI

@main
struct Lystaria_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        Lystaria_Widgets()
        Lystaria_SmallWidget()
        Lystaria_JournalEntriesWidget()
        Lystaria_HealthWidget()
    }
}
