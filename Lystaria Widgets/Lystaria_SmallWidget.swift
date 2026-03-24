//
//  Lystaria_SmallWidget.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/21/26.
//

import WidgetKit
import SwiftUI

struct Lystaria_SmallWidgetEntryView: View {
    let entry: LystariaWidgetEntry

    var body: some View {
        ZStack {
            LystariaMoodProgressRing(
                progress: entry.progress,
                hasLoggedMood: entry.hasLoggedMood
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LystariaBackground()
        }
        .widgetURL(URL(string: "lystaria://mood")!)
    }
}

struct Lystaria_SmallWidget: Widget {
    let kind: String = "Lystaria_SmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LystariaWidgetProvider()) { entry in
            Lystaria_SmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Ring")
        .description("Quick mood logging widget.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    Lystaria_SmallWidget()
} timeline: {
    LystariaWidgetEntry(
        date: .now,
        questionText: "How are you feeling today?",
        progress: 1.0,
        hasLoggedMood: true
    )
}
