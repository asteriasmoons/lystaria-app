//
//  WatchWaterView.swift
//  Lystaria
//

import SwiftUI

struct WatchWaterView: View {
    @StateObject private var water = WaterHealthKitManager.shared
    @StateObject private var watchSession = WatchSessionManager.shared
    @State private var customAmountText = ""

    private var waterGoal: Double {
        watchSession.waterGoal
    }

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            TabView {
                // Page 1 — Ring
                ringPage
                    .tag(0)

                // Page 2 — Custom (swipe left)
                customPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .navigationTitle("Water")
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await water.requestAuthorization()
            await water.fetchTodayWater()
        }
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
                    WaterBubbleRing(
                        current: water.todayWaterFlOz,
                        goal: waterGoal
                    )

                    Text("\(Int(water.todayWaterFlOz)) / \(Int(waterGoal)) FL OZ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Custom Page

    private var customPage: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Text("Custom Amount")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    TextField("FL OZ", text: $customAmountText)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        let cleaned = customAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let value = Double(cleaned), value > 0 {
                            Task {
                                await water.addWater(flOz: value)
                                await water.fetchTodayWater()
                            }
                            customAmountText = ""
                        }
                    } label: {
                        Text("Add")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Bubble Ring

private struct WaterBubbleRing: View {
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
        WatchWaterView()
    }
}
