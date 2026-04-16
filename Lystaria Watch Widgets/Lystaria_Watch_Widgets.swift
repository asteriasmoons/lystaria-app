//
//  Lystaria_Watch_Widgets.swift
//  Lystaria Watch Widgets
//
//  Created by Asteria Moon on 4/15/26.
//

import WidgetKit
import SwiftUI

// MARK: - Keys

private enum WatchKeys {
    static let appGroupID          = "group.com.asteriasmoons.LystariaDev"
    static let fileName            = "watch_health_data.plist"
    static let stepsToday          = "watch.stepsToday"
    static let stepGoal            = "watch.stepGoal"
    static let waterToday          = "watch.waterToday"
    static let waterGoal           = "watch.waterGoal"
    static let bodyScore           = "watch.bodyScore"
    static let bodyLabel           = "watch.bodyLabel"
    static let nervousSystemScore  = "watch.nervousSystemScore"
    static let nervousSystemLabel  = "watch.nervousSystemLabel"
    static let completionPct       = "watch.completionPct"
    static let sleepHours          = "watch.sleepHours"
    static let sleepScore          = "watch.sleepScore"
    static let sleepLabel          = "watch.sleepLabel"

    private static func readAll() -> [String: Any] {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else { return [:] }
        return dict
    }

    static func double(for key: String, fallback: Double = 0) -> Double {
        readAll()[key] as? Double ?? fallback
    }

    static func string(for key: String, fallback: String) -> String {
        readAll()[key] as? String ?? fallback
    }
}

// MARK: - Entry

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let stepsToday: Double
    let stepGoal: Double
    let waterToday: Double
    let waterGoal: Double
    let bodyScore: Double
    let bodyLabel: String
    let nervousSystemScore: Double
    let nervousSystemLabel: String
    let completionPct: Double
    let sleepHours: Double
    let sleepScore: Double
    let sleepLabel: String

    static let sample = WatchComplicationEntry(
        date:               .now,
        stepsToday:         4321,
        stepGoal:           5000,
        waterToday:         56,
        waterGoal:          80,
        bodyScore:          0.72,
        bodyLabel:          "Mellow",
        nervousSystemScore: 0.85,
        nervousSystemLabel: "Excellent",
        completionPct:      0.6,
        sleepHours:         6.5,
        sleepScore:         0.81,
        sleepLabel:         "Good"
    )
}

// MARK: - Provider

struct WatchComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchComplicationEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = makeEntry()
        let next  = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> WatchComplicationEntry {
        WatchComplicationEntry(
            date:               Date(),
            stepsToday:         WatchKeys.double(for: WatchKeys.stepsToday),
            stepGoal:           WatchKeys.double(for: WatchKeys.stepGoal,           fallback: 5000),
            waterToday:         WatchKeys.double(for: WatchKeys.waterToday),
            waterGoal:          WatchKeys.double(for: WatchKeys.waterGoal,          fallback: 80),
            bodyScore:          WatchKeys.double(for: WatchKeys.bodyScore),
            bodyLabel:          WatchKeys.string(for: WatchKeys.bodyLabel,          fallback: "Unavailable"),
            nervousSystemScore: WatchKeys.double(for: WatchKeys.nervousSystemScore),
            nervousSystemLabel: WatchKeys.string(for: WatchKeys.nervousSystemLabel, fallback: "Unavailable"),
            completionPct:      WatchKeys.double(for: WatchKeys.completionPct),
            sleepHours:         WatchKeys.double(for: WatchKeys.sleepHours),
            sleepScore:         WatchKeys.double(for: WatchKeys.sleepScore),
            sleepLabel:         WatchKeys.string(for: WatchKeys.sleepLabel, fallback: "No Data")
        )
    }
}

// MARK: - Gradients

private let lBlue   = Color(red: 3/255,   green: 219/255, blue: 252/255)
private let lPurple = Color(red: 125/255, green: 25/255,  blue: 247/255)
private let lGrad   = LinearGradient(colors: [lBlue, lPurple],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing)

private func bodyGradient(for label: String) -> LinearGradient {
    switch label {
    case "Excellent":
        return LinearGradient(
            colors: [Color(red: 255/255, green: 105/255, blue: 180/255),
                     Color(red: 255/255, green: 245/255, blue: 157/255)],
            startPoint: .leading, endPoint: .trailing)
    case "Mellow":
        return LinearGradient(
            colors: [Color(red: 64/255,  green: 224/255, blue: 208/255),
                     Color(red: 0/255,   green: 150/255, blue: 136/255)],
            startPoint: .leading, endPoint: .trailing)
    case "Elevated":
        return LinearGradient(
            colors: [Color(red: 255/255, green: 105/255, blue: 180/255),
                     Color(red: 255/255, green: 59/255,  blue: 48/255)],
            startPoint: .leading, endPoint: .trailing)
    case "Activated":
        return LinearGradient(
            colors: [Color(red: 255/255, green: 59/255,  blue: 48/255),
                     Color(red: 255/255, green: 204/255, blue: 0/255)],
            startPoint: .leading, endPoint: .trailing)
    case "Rest Needed":
        return LinearGradient(
            colors: [Color(red: 135/255, green: 206/255, blue: 250/255),
                     Color(red: 144/255, green: 238/255, blue: 144/255)],
            startPoint: .leading, endPoint: .trailing)
    default:
        return LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
            startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Shared sub-views

// Progress ring with icon in the gap at 12 o'clock
private struct WatchRing: View {
    let progress:  Double
    let ringColor: LinearGradient
    let iconName:  String
    let lineWidth: CGFloat
    let iconSize:  CGFloat

    private var clamped: Double { min(max(progress, 0), 1) }
    private let gapHalfDeg: Double = 22

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            let gapFrac = gapHalfDeg / 360
            Circle()
                .trim(from: gapFrac, to: gapFrac + (1.0 - 2 * gapFrac) * clamped)
                .stroke(
                    AnyShapeStyle(ringColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            GeometryReader { geo in
                let radius = (min(geo.size.width, geo.size.height) - lineWidth) / 2
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(.white)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - radius)
            }
        }
    }
}

// Flow bar mirroring bodyStateBar from HealthPageView
private struct WatchFlowBar: View {
    let title:    String
    let value:    Double
    let label:    String
    let gradient: LinearGradient

    private var isUnavailable: Bool { label == "Unavailable" }
    private var displayValue:  Double { isUnavailable ? 0 : max(value, 0.08) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(0.3)
                Spacer()
                Text(label)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            isUnavailable
                                ? AnyShapeStyle(Color.white.opacity(0.12))
                                : AnyShapeStyle(gradient)
                        )
                    )
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    if !isUnavailable {
                        Capsule()
                            .fill(gradient)
                            .frame(width: geo.size.width)
                            .mask(alignment: .leading) {
                                Capsule().frame(width: geo.size.width * displayValue)
                            }
                    }
                }
            }
            .frame(height: 6)
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
        }
    }
}

// MARK: - 1. Completion Circle (sparklefill)

struct LystariaCompletionCircleView: View {
    let entry: WatchComplicationEntry

    private var clamped: Double { min(max(entry.completionPct, 0), 1) }
    private let gapHalfDeg: Double = 20

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 3)
            let gapFrac = gapHalfDeg / 360
            Circle()
                .trim(from: gapFrac, to: gapFrac + (1.0 - 2 * gapFrac) * clamped)
                .stroke(
                    AnyShapeStyle(lGrad),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image("sparklefill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(.white)
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

struct Lystaria_Watch_Widgets: Widget {
    let kind: String = "Lystaria_CompletionCircle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            LystariaCompletionCircleView(entry: entry)
        }
        .configurationDisplayName("Lystaria Daily")
        .description("Daily completion at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 2. Current Flow Rectangle (Body + Nervous bars)

struct LystariaFlowRectView: View {
    let entry: WatchComplicationEntry

    var body: some View {
        VStack(spacing: 5) {
            WatchFlowBar(
                title:    "Body",
                value:    entry.bodyScore,
                label:    entry.bodyLabel,
                gradient: bodyGradient(for: entry.bodyLabel)
            )
            WatchFlowBar(
                title:    "Nervous",
                value:    entry.nervousSystemScore,
                label:    entry.nervousSystemLabel,
                gradient: bodyGradient(for: entry.nervousSystemLabel)
            )
        }
        .padding(4)
        .containerBackground(for: .widget) { Color.black }
    }
}

struct LystariaFlowRectWidget: Widget {
    let kind: String = "Lystaria_FlowRect"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            LystariaFlowRectView(entry: entry)
        }
        .configurationDisplayName("Lystaria Flow")
        .description("Body state and nervous system.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - 3. Steps Circle (shoefill + count)

struct LystariaStepsCircleView: View {
    let entry: WatchComplicationEntry

    private var progress: Double {
        entry.stepGoal > 0 ? min(entry.stepsToday / entry.stepGoal, 1) : 0
    }

    var body: some View {
        ZStack {
            WatchRing(
                progress:  progress,
                ringColor: lGrad,
                iconName:  "shoefill",
                lineWidth: 6,
                iconSize:  10
            )
            Text("\(Int(entry.stepsToday))")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 4)
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

struct LystariaStepsWidget: Widget {
    let kind: String = "Lystaria_StepsCircle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            LystariaStepsCircleView(entry: entry)
        }
        .configurationDisplayName("Lystaria Steps")
        .description("Today's step count and progress.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 4. Water Circle (glassfill + fl oz)

struct LystariaWaterCircleView: View {
    let entry: WatchComplicationEntry

    private var progress: Double {
        entry.waterGoal > 0 ? min(entry.waterToday / entry.waterGoal, 1) : 0
    }

    private var waterLabel: String {
        "\(Int(entry.waterToday.rounded()))"
    }

    var body: some View {
        ZStack {
            WatchRing(
                progress:  progress,
                ringColor: lGrad,
                iconName:  "glassfill",
                lineWidth: 6,
                iconSize:  10
            )
            Text(waterLabel)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 4)
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

struct LystariaWaterWidget: Widget {
    let kind: String = "Lystaria_WaterCircle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            LystariaWaterCircleView(entry: entry)
        }
        .configurationDisplayName("Lystaria Water")
        .description("Today's water intake and progress.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 5. Sleep Circle (moon icon + hours)

struct LystariaSleepCircleView: View {
    let entry: WatchComplicationEntry

    private var hasData: Bool { entry.sleepHours > 0 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 6)

            // Progress arc with gap at 12 o'clock for the icon
            let gapFrac = 20.0 / 360.0
            Circle()
                .trim(from: gapFrac, to: gapFrac + (1.0 - 2 * gapFrac) * entry.sleepScore)
                .stroke(
                    AnyShapeStyle(lGrad),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Moon icon at 12 o'clock
            GeometryReader { geo in
                let radius = (min(geo.size.width, geo.size.height) - 6) / 2
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - radius)
            }

            // Hours inside
            VStack(spacing: 0) {
                Text(hasData ? String(format: "%.1f", entry.sleepHours) : "--")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("hrs")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(width: 32)
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

struct LystariaSleepWidget: Widget {
    let kind: String = "Lystaria_SleepCircle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            LystariaSleepCircleView(entry: entry)
        }
        .configurationDisplayName("Lystaria Sleep")
        .description("Last night's sleep duration and score.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Previews

#Preview("Completion", as: .accessoryCircular) {
    Lystaria_Watch_Widgets()
} timeline: {
    WatchComplicationEntry.sample
}

#Preview("Flow", as: .accessoryRectangular) {
    LystariaFlowRectWidget()
} timeline: {
    WatchComplicationEntry.sample
}

#Preview("Steps", as: .accessoryCircular) {
    LystariaStepsWidget()
} timeline: {
    WatchComplicationEntry.sample
}

#Preview("Water", as: .accessoryCircular) {
    LystariaWaterWidget()
} timeline: {
    WatchComplicationEntry.sample
}
