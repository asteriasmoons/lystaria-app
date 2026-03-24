//
//  Lystaria_HealthWidget.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/22/26.
//

import WidgetKit
import SwiftUI

private enum HealthWidgetShared {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"

    static let stepsTodayKey = "healthWidget.stepsToday"
    static let stepGoalKey = "healthWidget.stepGoal"
    static let waterTodayKey = "healthWidget.waterToday"
    static let waterGoalKey = "healthWidget.waterGoal"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func readDouble(for key: String, fallback: Double) -> Double {
        guard let defaults else { return fallback }
        let value = defaults.double(forKey: key)
        return value == 0 ? fallbackIfNeeded(for: key, value: value, fallback: fallback) : value
    }

    private static func fallbackIfNeeded(for key: String, value: Double, fallback: Double) -> Double {
        // If no value exists yet, UserDefaults returns 0. For "today" values, 0 is valid.
        // For goal values, fall back to defaults if the key hasn't been written yet.
        guard let defaults else { return fallback }

        switch key {
        case stepGoalKey, waterGoalKey:
            if defaults.object(forKey: key) == nil {
                return fallback
            }
            return value
        default:
            return value
        }
    }
}

struct LystariaHealthWidgetEntry: TimelineEntry {
    let date: Date
    let stepsToday: Double
    let stepGoal: Double
    let waterToday: Double
    let waterGoal: Double
}

struct LystariaHealthWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LystariaHealthWidgetEntry {
        LystariaHealthWidgetEntry(
            date: Date(),
            stepsToday: 4321,
            stepGoal: 5000,
            waterToday: 56,
            waterGoal: 80
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LystariaHealthWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LystariaHealthWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let refreshDate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry() -> LystariaHealthWidgetEntry {
        let stepsToday = HealthWidgetShared.readDouble(
            for: HealthWidgetShared.stepsTodayKey,
            fallback: 0
        )

        let stepGoal = HealthWidgetShared.readDouble(
            for: HealthWidgetShared.stepGoalKey,
            fallback: 5000
        )

        let waterToday = HealthWidgetShared.readDouble(
            for: HealthWidgetShared.waterTodayKey,
            fallback: 0
        )

        let waterGoal = HealthWidgetShared.readDouble(
            for: HealthWidgetShared.waterGoalKey,
            fallback: 80
        )

        return LystariaHealthWidgetEntry(
            date: Date(),
            stepsToday: stepsToday,
            stepGoal: stepGoal,
            waterToday: waterToday,
            waterGoal: waterGoal
        )
    }
}

private struct HealthMiniProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AnyShapeStyle(LGradients.blue),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct HealthMetricRow: View {
    let iconName: String
    let title: String
    let currentValue: String
    let goalValue: String
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                    )
                    .frame(width: 34, height: 34)

                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                Text("\(currentValue) / \(goalValue)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            ZStack {
                HealthMiniProgressRing(progress: progress, lineWidth: 6)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 14, height: 14)
            }
        }
    }
}

struct Lystaria_HealthWidgetEntryView: View {
    let entry: LystariaHealthWidgetEntry

    private var stepsProgress: Double {
        guard entry.stepGoal > 0 else { return 0 }
        return min(max(entry.stepsToday / entry.stepGoal, 0), 1)
    }

    private var waterProgress: Double {
        guard entry.waterGoal > 0 else { return 0 }
        return min(max(entry.waterToday / entry.waterGoal, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HealthMetricRow(
                iconName: "shoefill",
                title: "Steps",
                currentValue: "\(Int(entry.stepsToday))",
                goalValue: "\(Int(entry.stepGoal))",
                progress: stepsProgress
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HealthMetricRow(
                iconName: "glassfill",
                title: "Water",
                currentValue: "\(Int(entry.waterToday))",
                goalValue: "\(Int(entry.waterGoal))",
                progress: waterProgress
            )

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LystariaBackground()
        }
    }
}

struct Lystaria_HealthWidget: Widget {
    let kind: String = "Lystaria_HealthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LystariaHealthWidgetProvider()) { entry in
            Lystaria_HealthWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Health Snapshot")
        .description("Shows today’s steps and water progress.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    Lystaria_HealthWidget()
} timeline: {
    LystariaHealthWidgetEntry(
        date: .now,
        stepsToday: 4321,
        stepGoal: 5000,
        waterToday: 56,
        waterGoal: 80
    )
}
