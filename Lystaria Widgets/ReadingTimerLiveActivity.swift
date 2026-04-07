//
//  ReadingTimerLiveActivity.swift
//  Lystaria
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ReadingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingTimerActivityAttributes.self) { context in
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image("booksfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white)

                        Text("Reading Timer")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.bookTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("\(context.state.minutesTotal) min session")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Spacer()
                    }
                }
                .padding(18)
            }
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
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        Text(context.state.bookTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
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
