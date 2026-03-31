//
//  BubbleDistractionView.swift
//  Lystaria
//

import SwiftUI

struct BubbleDistractionView: View {

    @State private var bubbles: [DistractionBubble] = []
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            // Bubbles Layer
            GeometryReader { geo in
                ZStack {
                    ForEach(bubbles) { bubble in
                        bubbleView(bubble, in: geo.size)
                    }
                }
            }
        }
        .onAppear {
            generateInitialBubbles()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Bubble View

    private func bubbleView(_ bubble: DistractionBubble, in size: CGSize) -> some View {
        let x = CGFloat(bubble.xPosition) * size.width
        let y = CGFloat(bubble.yPosition) * size.height

        return Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color(red: 0.22, green: 0.60, blue: 1.0).opacity(0.10),
                        Color(red: 0.48, green: 0.26, blue: 1.0).opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 2)
                    .blur(radius: 1)
            )
            .overlay(
                Ellipse()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: CGFloat(bubble.size) * 0.25, height: CGFloat(bubble.size) * 0.18)
                    .offset(x: -CGFloat(bubble.size) * 0.2, y: -CGFloat(bubble.size) * 0.25)
                    .blur(radius: 0.3)
            )
            .frame(width: CGFloat(bubble.size), height: CGFloat(bubble.size))
            .scaleEffect(CGFloat(bubble.scale))
            .opacity(bubble.isPopping ? 0 : bubble.opacity)
            .contentShape(Rectangle())
            .position(x: x, y: y)
            .highPriorityGesture(
                TapGesture().onEnded {
                    popBubble(bubble)
                }
            )
    }

    // MARK: - Logic

    private func generateInitialBubbles() {
        bubbles = (0..<28).map { _ in
            DistractionBubble.random()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateBubbles()
        }
    }

    private func updateBubbles() {
        var updatedBubbles = bubbles

        for i in updatedBubbles.indices {
            updatedBubbles[i].yPosition -= (updatedBubbles[i].speed * 1.8)
            updatedBubbles[i].xPosition += updatedBubbles[i].drift

            if updatedBubbles[i].xPosition < 0 { updatedBubbles[i].xPosition = 1 }
            if updatedBubbles[i].xPosition > 1 { updatedBubbles[i].xPosition = 0 }

            if updatedBubbles[i].yPosition < -0.2 {
                updatedBubbles[i] = DistractionBubble.random()
            }
        }

        bubbles = updatedBubbles
    }

    private func popBubble(_ bubble: DistractionBubble) {
        guard let index = bubbles.firstIndex(of: bubble), !bubbles[index].isPopping else { return }

        triggerHaptic(for: bubble)

        var updatedBubbles = bubbles
        updatedBubbles[index].isPopping = true
        updatedBubbles[index].scale = 1.4
        bubbles = updatedBubbles

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard index < bubbles.count else { return }

            var respawnedBubbles = bubbles
            respawnedBubbles[index] = DistractionBubble.random()
            bubbles = respawnedBubbles
        }
    }

    private func triggerHaptic(for bubble: DistractionBubble) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            bubble.size > 60 ? .medium : .light

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
