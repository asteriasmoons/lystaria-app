//
//  Lystaria_WidgetsLiveActivity.swift
//  Lystaria Widgets
//
//  Created by Asteria Moon on 3/20/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Lystaria_WidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Lystaria_WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Lystaria_WidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Lystaria_WidgetsAttributes {
    fileprivate static var preview: Lystaria_WidgetsAttributes {
        Lystaria_WidgetsAttributes(name: "World")
    }
}

extension Lystaria_WidgetsAttributes.ContentState {
    fileprivate static var smiley: Lystaria_WidgetsAttributes.ContentState {
        Lystaria_WidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Lystaria_WidgetsAttributes.ContentState {
         Lystaria_WidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Lystaria_WidgetsAttributes.preview) {
   Lystaria_WidgetsLiveActivity()
} contentStates: {
    Lystaria_WidgetsAttributes.ContentState.smiley
    Lystaria_WidgetsAttributes.ContentState.starEyes
}
