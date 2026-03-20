//
//  Lystaria_Widgets.swift
//  Lystaria Widgets
//
//  Created by Asteria Moon on 3/20/26.
//

import WidgetKit
import SwiftUI

private enum MoodWidgetShared {
    static let appGroupID = "group.com.asteriasmoons.LystariaDev"
    static let lastMoodLogDateKey = "lastMoodLogDate"
    static let openMoodLoggerKey = "openMoodLoggerFromWidget"

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func lastMoodLogDate() -> Date? {
        defaults?.object(forKey: lastMoodLogDateKey) as? Date
    }

    static func hasMoodLoggedToday(now: Date = Date()) -> Bool {
        guard let lastMoodLogDate = lastMoodLogDate() else { return false }
        return calendar.isDate(lastMoodLogDate, inSameDayAs: now)
    }

    static func nextMidnight(after date: Date = Date()) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(86_400)
    }
}

struct LystariaWidgetEntry: TimelineEntry {
    let date: Date
    let questionText: String
    let progress: Double
    let hasLoggedMood: Bool
}

struct LystariaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LystariaWidgetEntry {
        LystariaWidgetEntry(
            date: Date(),
            questionText: "How are you feeling today?",
            progress: 1.0,
            hasLoggedMood: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LystariaWidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LystariaWidgetEntry>) -> Void) {
        let now = Date()
        let currentEntry = makeEntry(for: now)
        let midnight = MoodWidgetShared.nextMidnight(after: now)
        let midnightEntry = makeEntry(for: midnight)
        let timeline = Timeline(entries: [currentEntry, midnightEntry], policy: .after(midnight))
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> LystariaWidgetEntry {
        let hasLoggedMood = MoodWidgetShared.hasMoodLoggedToday(now: date)

        return LystariaWidgetEntry(
            date: date,
            questionText: "How are you feeling today?",
            progress: hasLoggedMood ? 1.0 : 0.0,
            hasLoggedMood: hasLoggedMood
        )
    }
}

struct LystariaMoodProgressRing: View {
    let progress: Double
    let hasLoggedMood: Bool

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 10)

            Circle()
                .trim(from: 0, to: hasLoggedMood ? clampedProgress : 0)
                .stroke(
                    AnyShapeStyle(LGradients.blue),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: hasLoggedMood ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 96, height: 96)
    }
}

struct Lystaria_WidgetsEntryView: View {
    let entry: LystariaWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                GradientTitle(text: entry.questionText, size: 24)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(entry.hasLoggedMood ? "Mood logged" : "No mood logged yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LystariaMoodProgressRing(
                progress: entry.progress,
                hasLoggedMood: entry.hasLoggedMood
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .containerBackground(for: .widget) {
            LystariaBackground()
        }
        .widgetURL(URL(string: "lystaria://mood")!)
    }
}

struct Lystaria_Widgets: Widget {
    let kind: String = "Lystaria_Widgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LystariaWidgetProvider()) { entry in
            Lystaria_WidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Log")
        .description("Shows your daily mood logging status.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    Lystaria_Widgets()
} timeline: {
    LystariaWidgetEntry(
        date: .now,
        questionText: "How are you feeling today?",
        progress: 1.0,
        hasLoggedMood: true
    )
}
