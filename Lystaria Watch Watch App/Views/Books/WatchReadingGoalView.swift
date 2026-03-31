//
//  WatchReadingGoalView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/29/26.
//

import SwiftUI
import SwiftData

struct WatchReadingGoalView: View {

    @Query(sort: \ReadingGoal.updatedAt, order: .reverse)
    private var goals: [ReadingGoal]

    private var activeGoal: ReadingGoal? {
        goals.first(where: { $0.isActive })
    }

    private var currentAmount: Double {
        Double(activeGoal?.progressValue ?? 0)
    }

    private var goalAmount: Double {
        Double(activeGoal?.targetValue ?? 0)
    }

    private var goalLabel: String {
        guard let activeGoal else { return "No Active Goal" }
        return "\(activeGoal.metric.label) • \(activeGoal.period.label)"
    }

    private var progress: Double {
        guard goalAmount > 0 else { return 0 }
        return min(currentAmount / goalAmount, 1.0)
    }

    private var bubbleFillStates: [Double] {
        let bubbleCount = 12
        let total = progress * Double(bubbleCount)

        return (0..<bubbleCount).map { index in
            let value = total - Double(index)
            return min(max(value, 0), 1)
        }
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            VStack(spacing: 12) {
                Spacer()

                if activeGoal == nil {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )

                        VStack(spacing: 8) {
                            Text("No Goal Yet")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Set a reading goal in the app.")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 140)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )

                        VStack(spacing: 10) {
                            ZStack {
                                WatchReadingGoalBubbleArc(
                                    fillStates: bubbleFillStates,
                                    size: 150
                                )

                                VStack(spacing: 4) {
                                    Text("\(Int(currentAmount)) / \(Int(goalAmount))")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(goalLabel)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(height: 120)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                    }
                    .frame(height: 170)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Goal")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Bubble Arc

private struct WatchReadingGoalBubbleArc: View {
    let fillStates: [Double]
    let size: CGFloat

    private let bubbleSize: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 18)
            let radius = size * 0.38
            let startAngle = Double.pi * 1.0
            let endAngle = Double.pi * 2.0
            let count = max(fillStates.count, 1)

            ZStack {
                ForEach(Array(fillStates.enumerated()), id: \.offset) { index, fill in
                    let percent = count == 1 ? 0 : Double(index) / Double(count - 1)
                    let angle = startAngle + ((endAngle - startAngle) * percent)
                    let x = center.x + CGFloat(cos(angle)) * radius
                    let y = center.y + CGFloat(sin(angle)) * radius

                    WatchReadingGoalBubble(fill: fill)
                        .frame(width: bubbleSize, height: bubbleSize)
                        .position(x: x, y: y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size, height: size * 0.82)
    }
}

private struct WatchReadingGoalBubble: View {
    let fill: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 125/255, green: 25/255, blue: 247/255),
                            Color(red: 3/255, green: 219/255, blue: 252/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(
                                width: geo.size.width,
                                height: geo.size.height * CGFloat(min(max(fill, 0), 1)),
                                alignment: .bottom
                            )
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                )
                .opacity(fill > 0 ? 1 : 0)
        }
    }
}
