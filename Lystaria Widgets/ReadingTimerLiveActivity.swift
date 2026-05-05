//
//  ReadingTimerLiveActivity.swift
//  Lystaria
//

import ActivityKit
import WidgetKit
import SwiftUI

private let lystariaGradient = LinearGradient(
    colors: [
        Color(red: 0.012, green: 0.859, blue: 0.988), // #03dbfc cyan
        Color(red: 0.490, green: 0.098, blue: 0.969)  // #7d19f7 purple
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

struct ReadingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingTimerActivityAttributes.self) { context in

            // MARK: - Lock Screen / Banner
            HStack(spacing: 14) {
                Image("booksfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.bookTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Reading Timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(lystariaGradient)
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("booksfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                        .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(context.state.bookTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }

            } compactLeading: {
                Image("booksfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(.white)

            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

            } minimal: {
                Image("booksfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(.white)
            }
            .widgetURL(URL(string: "lystaria://reading-timer"))
            .keylineTint(.white)
        }
    }
}
