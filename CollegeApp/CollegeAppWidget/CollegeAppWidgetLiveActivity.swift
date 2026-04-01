//
//  CollegeAppWidgetLiveActivity.swift
//  CollegeAppWidget
//
//  Created by Wesley Wang on 2026/4/1.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CollegeAppWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CollegeAppWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CollegeAppWidgetAttributes.self) { context in
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

extension CollegeAppWidgetAttributes {
    fileprivate static var preview: CollegeAppWidgetAttributes {
        CollegeAppWidgetAttributes(name: "World")
    }
}

extension CollegeAppWidgetAttributes.ContentState {
    fileprivate static var smiley: CollegeAppWidgetAttributes.ContentState {
        CollegeAppWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CollegeAppWidgetAttributes.ContentState {
         CollegeAppWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CollegeAppWidgetAttributes.preview) {
   CollegeAppWidgetLiveActivity()
} contentStates: {
    CollegeAppWidgetAttributes.ContentState.smiley
    CollegeAppWidgetAttributes.ContentState.starEyes
}
