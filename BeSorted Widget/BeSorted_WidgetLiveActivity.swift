//
//  BeSorted_WidgetLiveActivity.swift
//  BeSorted Widget
//
//  Created by Michał Wołtosz on 9/13/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BeSorted_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BeSorted_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeSorted_WidgetAttributes.self) { context in
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

extension BeSorted_WidgetAttributes {
    fileprivate static var preview: BeSorted_WidgetAttributes {
        BeSorted_WidgetAttributes(name: "World")
    }
}

extension BeSorted_WidgetAttributes.ContentState {
    fileprivate static var smiley: BeSorted_WidgetAttributes.ContentState {
        BeSorted_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BeSorted_WidgetAttributes.ContentState {
         BeSorted_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BeSorted_WidgetAttributes.preview) {
   BeSorted_WidgetLiveActivity()
} contentStates: {
    BeSorted_WidgetAttributes.ContentState.smiley
    BeSorted_WidgetAttributes.ContentState.starEyes
}
