//
//  WatchHabitsView.swift
//  Lystaria
//

import SwiftUI
import SwiftData

// =======================================================
// MARK: - HABITS LIST
// =======================================================

struct WatchHabitsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// All active (non-archived) habits
    private var todayHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            if todayHabits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "flame.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("No habits yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(todayHabits, id: \.persistentModelID) { habit in
                            NavigationLink {
                                WatchHabitLogView(habit: habit)
                            } label: {
                                HabitRowCard(habit: habit, today: today)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Habits")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// =======================================================
// MARK: - HABIT ROW CARD
// =======================================================

private struct HabitRowCard: View {
    let habit: Habit
    let today: Date

    private var todayLog: HabitLog? {
        habit.logs?.first { Calendar.current.startOfDay(for: $0.dayStart) == today }
    }

    private var count: Int { todayLog?.count ?? 0 }
    private var goal: Int  { max(habit.timesPerDay, 1) }
    private var isDone: Bool { count >= goal }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDone ? Color.white.opacity(0.22) : Color.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isDone
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 125/255, green: 25/255,  blue: 247/255),
                                        Color(red: 3/255,   green: 219/255, blue: 252/255)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ),
                            lineWidth: isDone ? 1.5 : 1
                        )
                )

            HStack(spacing: 10) {
                // Mini progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: goal > 0 ? CGFloat(min(count, goal)) / CGFloat(goal) : 0)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 125/255, green: 25/255,  blue: 247/255),
                                    Color(red: 3/255,   green: 219/255, blue: 252/255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(count)/\(goal)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// =======================================================
// MARK: - HABIT LOG VIEW
// =======================================================

struct WatchHabitLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let habit: Habit

    @State private var showSkipConfirm = false
    @State private var didJustLog      = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var todayLog: HabitLog? {
        habit.logs?.first { Calendar.current.startOfDay(for: $0.dayStart) == today }
    }

    private var isSkipped: Bool {
        habit.skips?.contains { Calendar.current.startOfDay(for: $0.dayStart) == today } ?? false
    }

    private var count: Int { todayLog?.count ?? 0 }
    private var goal: Int  { max(habit.timesPerDay, 1) }
    private var isDone: Bool { count >= goal }

    private var progress: Double {
        goal > 0 ? min(Double(count) / Double(goal), 1.0) : 0
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            ScrollView {
                VStack(spacing: 12) {

                    // Title
                    Text(habit.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    // Bubble ring
                    HabitBubbleRing(progress: progress, isDone: isDone)

                    // Count label
                    Text(isDone ? "Goal complete! 🎉" : "\(count) of \(goal) today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(isDone ? 1 : 0.8))
                        .multilineTextAlignment(.center)

                    // Log button
                    if !isDone && !isSkipped {
                        Button {
                            logHabit()
                        } label: {
                            Text("Log")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 125/255, green: 25/255,  blue: 247/255),
                                            Color(red: 3/255,   green: 219/255, blue: 252/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Undo button (visible right after logging, if not done)
                    if didJustLog && count > 0 {
                        Button {
                            undoLog()
                        } label: {
                            Text("Undo")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    // Skip button
                    if !isDone && !isSkipped {
                        Button {
                            showSkipConfirm = true
                        } label: {
                            Text("Skip today")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }

                    if isSkipped {
                        Text("Skipped today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Skip today?", isPresented: $showSkipConfirm) {
            Button("Skip", role: .destructive) { skipHabit() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func logHabit() {
        let dayStart = today
        if let existing = todayLog {
            existing.count += 1
            existing.updatedAt = Date()
        } else {
            let log = HabitLog(habit: habit, dayStart: dayStart, count: 1)
            modelContext.insert(log)
        }
        try? modelContext.save()
        didJustLog = true

        // Dismiss automatically when goal is reached
        if (todayLog?.count ?? 1) >= goal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        }
    }

    private func undoLog() {
        guard let existing = todayLog, existing.count > 0 else { return }
        if existing.count == 1 {
            modelContext.delete(existing)
        } else {
            existing.count -= 1
            existing.updatedAt = Date()
        }
        try? modelContext.save()
        didJustLog = false
    }

    private func skipHabit() {
        let skip = HabitSkip(habit: habit, dayStart: today)
        modelContext.insert(skip)
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// =======================================================
// MARK: - BUBBLE RING
// =======================================================

private struct HabitBubbleRing: View {
    let progress: Double
    let isDone: Bool

    var body: some View {
        ZStack {
            let bubbleCount = 32
            let filledCount = Int(Double(bubbleCount) * progress)
            let radius: CGFloat = 44

            ForEach(0..<bubbleCount, id: \.self) { index in
                let angle    = Double(index) / Double(bubbleCount) * 2 * .pi - .pi / 2
                let isFilled = index < filledCount

                Circle()
                    .fill(
                        isFilled
                        ? AnyShapeStyle(LinearGradient(
                            colors: [
                                Color(red: 125/255, green: 25/255,  blue: 247/255),
                                Color(red: 3/255,   green: 219/255, blue: 252/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(Color.white.opacity(0.15))
                    )
                    .frame(width: 6, height: 6)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .frame(width: 100, height: 100)
    }
}
