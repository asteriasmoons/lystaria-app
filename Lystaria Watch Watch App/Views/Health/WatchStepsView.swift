//
//  WatchStepsView.swift
//  Lystaria Watch Watch App
//

import SwiftUI

struct WatchStepsView: View {
    @StateObject private var session = WatchSessionManager.shared

    private var stepsToday: Double {
        WatchSessionManager.readAll()[WatchSessionManager.Keys.stepsToday] as? Double ?? 0
    }

    private var stepGoal: Double {
        let v = WatchSessionManager.readAll()[WatchSessionManager.Keys.stepGoal] as? Double ?? 5000
        return v == 0 ? 5000 : v
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            TabView {
                ringPage
                    .tag(0)

                statsPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .navigationTitle("Steps")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Ring Page

    private var ringPage: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    StepBubbleRing(
                        current: stepsToday,
                        goal: stepGoal
                    )

                    Text("\(Int(stepsToday)) / \(Int(stepGoal)) STEPS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Page

    private var statsPage: some View {
        let remaining = max(stepGoal - stepsToday, 0)
        let pct = stepGoal > 0 ? min(stepsToday / stepGoal * 100, 100) : 0
        // ~2000 steps per mile
        let miles = stepsToday / 2000

        return VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Text("Today's Stats")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    VStack(spacing: 6) {
                        StepStatRow(label: "Remaining", value: remaining == 0 ? "Goal met! 🎉" : "\(Int(remaining)) steps")
                        StepStatRow(label: "Progress",  value: String(format: "%.0f%%", pct))
                        StepStatRow(label: "Distance",  value: String(format: "%.2f mi", miles))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Stat Row

private struct StepStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Bubble Ring

private struct StepBubbleRing: View {
    let current: Double
    let goal: Double

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        ZStack {
            let bubbleCount = 32
            let filledCount = Int(Double(bubbleCount) * progress)
            let radius: CGFloat = 44

            ForEach(0..<bubbleCount, id: \.self) { index in
                let angle = Double(index) / Double(bubbleCount) * 2 * Double.pi - Double.pi / 2
                let isFilled = index < filledCount
                let xOffset = cos(angle) * radius
                let yOffset = sin(angle) * radius

                Circle()
                    .fill(
                        isFilled ?
                        AnyShapeStyle(LinearGradient(
                            colors: [
                                Color(red: 125/255, green: 25/255, blue: 247/255),
                                Color(red: 3/255, green: 219/255, blue: 252/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )) :
                        AnyShapeStyle(Color.white.opacity(0.15))
                    )
                    .frame(width: 6, height: 6)
                    .offset(x: xOffset, y: yOffset)
            }
        }
        .frame(width: 100, height: 100)
    }
}

#Preview {
    NavigationStack {
        WatchStepsView()
    }
}
